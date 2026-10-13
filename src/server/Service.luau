--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Shared = ReplicatedStorage.GrowAPlanet
local Big = require(Shared.BigNumber)
local Civilization = require(Shared.Civilization)
local Config = require(Shared.config.economy)
local AgesConfig = require(Shared.config.ages)
local KardashevConfig = require(Shared.config.kardashev)
local Economy = require(Shared.Economy)
local Janitor = require(Shared.Janitor)
local Planet = require(Shared.Planet)
local Limiter = require(script.Parent.RateLimiter)
local Schema = require(script.Parent.ProfileSchema)
local Session = require(script.Parent.Session)
local ServerConfig = require(script.Parent.config)
local ProfileStore = require(ServerStorage.GrowAPlanetDependencies.ProfileStore)
type Entry = {
	profile: any,
	requests: Limiter.Bucket,
	clicks: Limiter.Bucket,
	growths: Limiter.Bucket,
	actions: Limiter.Bucket,
	-- Cached production; cleared whenever growth, cities or civilization state change.
	rates: { [string]: number }?,
	population: number,
	cleanup: () -> (),
	lastTick: number,
	lastSnapshot: number,
	lastWarning: { [string]: number },
	stats: { [string]: number },
}
local Service = {}
local definition = Planet.definition(ServerConfig.planetId)
local entries: { [Player]: Entry } = {}
local loading: { [Player]: boolean } = {}
local closing = false
local started = false
local lifetime = Janitor.new()
local request: RemoteEvent
local snapshot: RemoteEvent
local notify: RemoteEvent

local function home(entry: Entry): Schema.PlanetData
	return entry.profile.Data.planets[ServerConfig.planetId]
end

local function rates(entry: Entry): { [string]: number }
	local cached = entry.rates
	if cached then
		return cached
	end
	local planet = home(entry)
	local computed, population = Civilization.rates(
		Planet.production(definition, planet.growth),
		planet.regions,
		planet.civilization
	)
	entry.rates = computed
	entry.population = population
	return computed
end

-- Balances, rates and stats come from the server. The client only formats them and previews
-- config-derived prices; every purchase is re-validated here.
local function view(entry: Entry): any
	local planet = home(entry)
	local stats = Planet.stats(definition, planet.growth)
	local costs = {}
	for _, id in definition.growthIds do
		costs[id] = Planet.cost(definition, planet.growth, id)
	end
	return {
		resources = planet.resources,
		regions = {
			terrain = planet.regions.terrain,
			population = planet.regions.population,
			buildings = planet.regions.buildings,
		},
		planet = {
			earthLevel = planet.growth.earthLevel,
			waterLevel = planet.growth.waterLevel,
			earthMass = stats.earthMass,
			waterMass = stats.waterMass,
			totalSize = stats.totalSize,
			stage = stats.stage,
			costs = costs,
			income = rates(entry),
		},
		civilization = {
			age = planet.civilization.age,
			upgrades = planet.civilization.upgrades,
			kardashev = planet.civilization.kardashev,
			population = entry.population,
		},
	}
end

local function send(player: Player, entry: Entry)
	if player.Parent ~= Players or not entry.profile:IsActive() then
		return
	end
	entry.lastSnapshot = os.clock()
	snapshot:FireClient(player, view(entry))
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
	local planet = home(entry)
	local perSecond = rates(entry)
	local ok, resources = pcall(Economy.advance, planet.resources, seconds, perSecond)
	if not ok then
		reject(entry, "number_range")
		return false
	end
	resources.Population = Big.new(entry.population)
	planet.resources = resources
	return true
end

-- City, building, age, upgrade and Kardashev purchases. All validation lives in Civilization;
-- this only routes intents, commits accepted results and logs.
local ACTIONS: { [string]: (Schema.PlanetData, any, any) -> (any, any, any, any) } = {
	FoundCity = function(planet: Schema.PlanetData, a: any)
		return Civilization.found(
			ServerConfig.planetId,
			planet.resources,
			planet.regions,
			planet.civilization,
			a
		)
	end,
	Build = function(planet: Schema.PlanetData, a: any, b: any)
		return Civilization.build(
			ServerConfig.planetId,
			planet.resources,
			planet.regions,
			planet.civilization,
			a,
			b
		)
	end,
	AdvanceAge = function(planet: Schema.PlanetData)
		return Civilization.advanceAge(planet.resources, planet.regions, planet.civilization)
	end,
	BuyUpgrade = function(planet: Schema.PlanetData, a: any)
		return Civilization.buyUpgrade(planet.resources, planet.regions, planet.civilization, a)
	end,
	Kardashev = function(planet: Schema.PlanetData)
		return Civilization.advanceKardashev(planet.resources, planet.regions, planet.civilization)
	end,
}
-- Exact argument counts per intent (including the intent name).
local ARITY: { [string]: number } =
	{ FoundCity = 2, Build = 3, AdvanceAge = 1, BuyUpgrade = 2, Kardashev = 1 }

function Service.act(player: Player, intent: string, a: any, b: any): (boolean, string?)
	local entry = entries[player]
	if not entry or not entry.profile:IsActive() or closing then
		return false, "no_session"
	end
	local action = ACTIONS[intent]
	if action == nil then
		reject(entry, "malformed_intent")
		return false, "malformed_intent"
	end
	local planet = home(entry)
	local before = planet.civilization
	local ok, resources, regions, civilization, reason = pcall(action, planet, a, b)
	if not ok then
		reject(entry, "number_range")
		return false, "number_range"
	end
	if resources == nil or regions == nil or civilization == nil then
		reject(entry, reason or "rejected")
		return false, reason
	end
	planet.resources = resources
	planet.regions = regions
	planet.civilization = civilization
	entry.rates = nil
	rates(entry)
	planet.resources.Population = Big.new(entry.population)
	entry.stats[intent] = (entry.stats[intent] or 0) + 1
	print(
		string.format(
			"[GrowAPlanet] %s %s %s",
			string.upper(intent),
			tostring(a or ""),
			tostring(b or "")
		)
	)
	if civilization.age > before.age then
		local age = AgesConfig.ages[civilization.age]
		print("[GrowAPlanet] AGE_UP " .. age.id)
		notify:FireClient(player, { kind = "AgeUp", age = civilization.age })
	end
	if civilization.kardashev > before.kardashev then
		print("[GrowAPlanet] KARDASHEV " .. KardashevConfig.milestones[civilization.kardashev].name)
		notify:FireClient(player, { kind = "Kardashev", type = civilization.kardashev })
	end
	send(player, entry)
	return true, nil
end

-- Shared by the Grow remote intent and Studio debug tools; validation happens here.
function Service.grow(player: Player, id: string): (boolean, string?)
	local entry = entries[player]
	if not entry or not entry.profile:IsActive() or closing then
		return false, "no_session"
	end
	if id ~= "Earth" and id ~= "Water" then
		reject(entry, "malformed_intent")
		return false, "malformed_intent"
	end
	local planet = home(entry)
	local before = Planet.stats(definition, planet.growth).stage
	local ok, resources, growth, reason =
		pcall(Planet.grow, definition, planet.resources, planet.growth, id)
	if not ok then
		reject(entry, "number_range")
		return false, "number_range"
	end
	if resources == nil or growth == nil then
		reject(entry, reason or "rejected")
		return false, reason
	end
	planet.resources = resources
	planet.growth = growth
	planet.regions.terrain = Schema.terrainFor(ServerConfig.planetId, planet)
	entry.rates = nil
	entry.stats.grown = (entry.stats.grown or 0) + 1
	local stats = Planet.stats(definition, growth)
	if stats.stage > before then
		-- Growth tiers are internal (terrain and atmosphere); they have no player-facing name.
		print("[GrowAPlanet] GROWTH_TIER " .. stats.stage)
	end
	send(player, entry)
	return true, nil
end

-- Studio-only access for development tools; never reachable from a remote.
function Service.studioData(player: Player): Schema.PlanetData?
	assert(RunService:IsStudio(), "Studio only")
	local entry = entries[player]
	return if entry and entry.profile:IsActive() then home(entry) else nil
end

-- Studio-only: re-derive terrain after a development edit and push a snapshot.
function Service.studioRefresh(player: Player)
	assert(RunService:IsStudio(), "Studio only")
	local entry = entries[player]
	if entry and entry.profile:IsActive() then
		local planet = home(entry)
		planet.regions.terrain = Schema.terrainFor(ServerConfig.planetId, planet)
		planet.regions = Civilization.refreshPopulation(planet.regions, planet.civilization)
		entry.rates = nil
		send(player, entry)
	end
end

-- Credit offline production for the time since `lastOnline` (capped), then mark online now.
-- Studio debug tools call this with a simulated `now` to test the cap without waiting.
function Service.applyOffline(player: Player, now: number): number
	local entry = entries[player]
	if not entry or not entry.profile:IsActive() then
		return 0
	end
	local planet = home(entry)
	local credited, seconds =
		Civilization.offline(planet.resources, rates(entry), planet.civilization.lastOnline, now)
	planet.resources = credited
	planet.civilization.lastOnline = now
	if seconds > 0 then
		print(
			string.format(
				"[GrowAPlanet] OFFLINE_INCOME seconds=%d cap=%d",
				seconds,
				Config.offlineCapSeconds
			)
		)
		notify:FireClient(player, {
			kind = "Offline",
			seconds = seconds,
			capped = seconds >= Config.offlineCapSeconds,
		})
		send(player, entry)
	end
	return seconds
end

function Service.inspect(player: Player): any
	local entry = entries[player]
	if not entry then
		return nil
	end
	local result = view(entry)
	result.stats = table.clone(entry.stats)
	result.active = entry.profile:IsActive()
	result.lastSaved = entry.profile.LastSavedData
	return result
end

function Service.release(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end
	-- Commit remaining online time and stamp the logout time for offline income.
	Service.advance(player, math.max(0, os.clock() - entry.lastTick))
	if entry.profile:IsActive() then
		home(entry).civilization.lastOnline = os.time()
	end
	entries[player] = nil
	entry.profile:EndSession()
	entry.cleanup()
end

function Service.start()
	assert(not started, "Service already started")
	started = true
	-- The strategic planet view replaces avatars; no character is spawned.
	Players.CharacterAutoLoads = false
	local remotes = Instance.new("Folder")
	remotes.Name = "GrowAPlanetRemotes"
	request = Instance.new("RemoteEvent")
	request.Name = "Request"
	request.Parent = remotes
	snapshot = Instance.new("RemoteEvent")
	snapshot.Name = "Snapshot"
	snapshot.Parent = remotes
	notify = Instance.new("RemoteEvent")
	notify.Name = "Notify"
	notify.Parent = remotes
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
		end, cancelled, Random.new():NextInteger(1, 2 ^ 31 - 2))
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
			growths = Limiter.new(Config.growthPerSecond, Config.growthBurst, now),
			actions = Limiter.new(Config.actionsPerSecond, Config.actionBurst, now),
			rates = nil,
			population = 0,
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
		local growth = home(entry).growth
		Service.applyOffline(player, os.time())
		print(
			string.format(
				"[GrowAPlanet] PROFILE_READY schema=%d namespace=%s stage=%s earth=%d water=%d regions=%d",
				profile.Data.schemaVersion,
				store.Name,
				Planet.stats(definition, growth).stageId,
				growth.earthLevel,
				growth.waterLevel,
				#home(entry).regions.terrain
			)
		)
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
		local intent = args[1]
		if type(intent) == "string" and ARITY[intent] ~= nil then
			if args.n ~= ARITY[intent] then
				reject(entry, "malformed_intent")
				return
			end
			if not Limiter.take(entry.actions, now) then
				reject(entry, "action_rate")
				return
			end
			Service.act(player, intent, args[2], args[3])
			return
		end
		if intent == "Grow" and args.n == 2 then
			if not Limiter.take(entry.growths, now) then
				reject(entry, "growth_rate")
				return
			end
			Service.grow(player, args[2])
			return
		end
		if args.n ~= 1 or (intent ~= "Click" and intent ~= "Ready") then
			reject(entry, "malformed_intent")
			return
		end
		if intent == "Ready" then
			if now - entry.lastSnapshot >= Config.snapshotInterval then
				send(player, entry)
			end
			return
		end
		if not Limiter.take(entry.clicks, now) then
			reject(entry, "click_rate")
			return
		end
		local planet = home(entry)
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
			local wallClock = os.time()
			for player, entry in entries do
				Service.advance(player, math.max(0, now - entry.lastTick))
				entry.lastTick = now
				if entry.profile:IsActive() then
					home(entry).civilization.lastOnline = wallClock
				end
				if now - entry.lastSnapshot >= Config.snapshotInterval then
					send(player, entry)
				end
			end
		end
	end)
end
return Service
