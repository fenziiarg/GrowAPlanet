--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Shared = ReplicatedStorage.GrowAPlanet
local Config = require(Shared.config.economy)
local Economy = require(Shared.Economy)
local Janitor = require(Shared.Janitor)
local Limiter = require(script.Parent.RateLimiter)
local Schema = require(script.Parent.ProfileSchema)
local Session = require(script.Parent.Session)
local ServerConfig = require(script.Parent.config)
local ProfileStore = require(ServerStorage.GrowAPlanetDependencies.ProfileStore)
type Entry = {
	profile: any,
	requests: Limiter.Bucket,
	clicks: Limiter.Bucket,
	cleanup: () -> (),
	lastTick: number,
	lastSnapshot: number,
	lastWarning: { [string]: number },
	stats: { [string]: number },
}
local Service = {}
local entries: { [Player]: Entry } = {}
local loading: { [Player]: boolean } = {}
local closing = false
local started = false
local lifetime = Janitor.new()
local request: RemoteEvent
local snapshot: RemoteEvent

local function send(player: Player, entry: Entry)
	if player.Parent ~= Players or not entry.profile:IsActive() then
		return
	end
	entry.lastSnapshot = os.clock()
	snapshot:FireClient(player, entry.profile.Data.planets[ServerConfig.planetId].resources)
end

local function reject(entry: Entry, reason: string)
	entry.stats[reason] = (entry.stats[reason] or 0) + 1
	local now = os.clock()
	if now - (entry.lastWarning[reason] or -math.huge) >= Config.logInterval then
		entry.lastWarning[reason] = now
		warn("[GrowAPlanet] REJECT " .. reason)
	end
end

function Service.advance(player: Player, seconds: number): boolean
	local entry = entries[player]
	if not entry or not entry.profile:IsActive() then
		return false
	end
	local planet = entry.profile.Data.planets[ServerConfig.planetId]
	local ok, resources = pcall(Economy.advance, planet.resources, seconds)
	if not ok then
		reject(entry, "number_range")
		return false
	end
	planet.resources = resources
	return true
end

function Service.inspect(player: Player): any
	local entry = entries[player]
	if not entry then
		return nil
	end
	return {
		resources = entry.profile.Data.planets[ServerConfig.planetId].resources,
		stats = table.clone(entry.stats),
		active = entry.profile:IsActive(),
		lastSaved = entry.profile.LastSavedData,
	}
end

function Service.release(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end
	-- Commit remaining online time before releasing the session; no offline income in Phase 1.
	Service.advance(player, math.max(0, os.clock() - entry.lastTick))
	entries[player] = nil
	entry.profile:EndSession()
	entry.cleanup()
end

function Service.start()
	assert(not started, "Service already started")
	started = true
	local remotes = Instance.new("Folder")
	remotes.Name = "GrowAPlanetRemotes"
	request = Instance.new("RemoteEvent")
	request.Name = "Request"
	request.Parent = remotes
	snapshot = Instance.new("RemoteEvent")
	snapshot.Name = "Snapshot"
	snapshot.Parent = remotes
	remotes.Parent = ReplicatedStorage
	lifetime.add(function()
		remotes:Destroy()
	end)
	local store = ProfileStore.New(
		if RunService:IsStudio() then ServerConfig.studioStore else ServerConfig.liveStore,
		Schema.new()
	)
	local function loadPlayer(player: Player)
		if entries[player] or loading[player] or closing then
			return
		end
		loading[player] = true
		local deadline = os.clock() + ServerConfig.loadTimeout
		local function cancelled(): boolean
			return closing or player.Parent ~= Players or os.clock() >= deadline
		end
		while ProfileStore.DataStoreState == "NotReady" and not cancelled() do
			task.wait(0.1)
		end
		-- ProfileStore can silently use its mock backend without API access. Disallow that here.
		if ProfileStore.DataStoreState ~= "Access" or cancelled() then
			loading[player] = nil
			if player.Parent == Players then
				player:Kick(
					"Saving is unavailable. Please rejoin when data services are available."
				)
			end
			warn("[GrowAPlanet] LOAD_FAILED data_services_unavailable; no default profile created")
			return
		end
		local profile, reason = Session.load(function()
			return store:StartSessionAsync(
				ServerConfig.keyPrefix .. tostring(player.UserId),
				{ Cancel = cancelled }
			)
		end, cancelled)
		loading[player] = nil
		if not profile then
			warn("[GrowAPlanet] LOAD_FAILED " .. tostring(reason) .. "; no defaults written")
			if player.Parent == Players then
				player:Kick("Your data could not be safely loaded. Please rejoin.")
			end
			return
		end
		profile:AddUserId(player.UserId)
		local janitor = Janitor.new()
		local now = os.clock()
		local entry: Entry = {
			profile = profile,
			cleanup = janitor.cleanup,
			lastTick = now,
			lastSnapshot = now,
			requests = Limiter.new(Config.requestsPerSecond, Config.requestBurst, now),
			clicks = Limiter.new(Config.clicksPerSecond, Config.clickBurst, now),
			lastWarning = {},
			stats = {},
		}
		entries[player] = entry
		local ended = profile.OnSessionEnd:Connect(function()
			if entries[player] == entry then
				entries[player] = nil
				janitor.cleanup()
				if not closing and player.Parent == Players then
					player:Kick("Your save session ended. Please rejoin.")
				end
			end
		end)
		janitor.add(function()
			ended:Disconnect()
		end)
		print("[GrowAPlanet] PROFILE_READY schema=1 namespace=" .. store.Name)
		send(player, entry)
	end
	local incoming = request.OnServerEvent:Connect(function(player: Player, ...: any)
		local entry = entries[player]
		if not entry or not entry.profile:IsActive() or closing then
			return
		end
		local now = os.clock()
		if not Limiter.take(entry.requests, now) then
			reject(entry, "request_rate")
			return
		end
		local args = table.pack(...)
		if args.n ~= 1 or (args[1] ~= "Click" and args[1] ~= "Ready") then
			reject(entry, "malformed_intent")
			return
		end
		if args[1] == "Ready" then
			if now - entry.lastSnapshot >= Config.snapshotInterval then
				send(player, entry)
			end
			return
		end
		if not Limiter.take(entry.clicks, now) then
			reject(entry, "click_rate")
			return
		end
		local planet = entry.profile.Data.planets[ServerConfig.planetId]
		local ok, resources = pcall(Economy.click, planet.resources)
		if not ok then
			reject(entry, "number_range")
			return
		end
		planet.resources = resources
		entry.stats.accepted = (entry.stats.accepted or 0) + 1
	end)
	lifetime.add(function()
		incoming:Disconnect()
	end)
	local added = Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)
	local removed = Players.PlayerRemoving:Connect(Service.release)
	lifetime.add(function()
		added:Disconnect()
		removed:Disconnect()
	end)
	game:BindToClose(function()
		closing = true
		for player in entries do
			Service.release(player)
		end
		lifetime.cleanup()
		-- ProfileStore also binds shutdown and waits for its pending final writes.
		local deadline = os.clock() + ServerConfig.shutdownTimeout
		while next(loading) and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	task.spawn(function()
		while not closing do
			task.wait(Config.tickInterval)
			local now = os.clock()
			for player, entry in entries do
				Service.advance(player, math.max(0, now - entry.lastTick))
				entry.lastTick = now
				if now - entry.lastSnapshot >= Config.snapshotInterval then
					send(player, entry)
				end
			end
		end
	end)
end
return Service
