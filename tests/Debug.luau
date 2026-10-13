--!strict
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService").GrowAPlanet
local Shared = game:GetService("ReplicatedStorage").GrowAPlanet
local Service = require(Server.Service)
local Config = require(Shared.config.economy)
local Planet = require(Shared.Planet)
local Big = require(Shared.BigNumber)
local Schema = require(Server.ProfileSchema)
local Session = require(Server.Session)
local ServerConfig = require(Server.config)
local ProfileStore = require(game:GetService("ServerStorage").GrowAPlanetDependencies.ProfileStore)
local Bot = require(script.Parent.Bot)
local Debug = {}
function Debug.inspect(player: Player): any
	assert(RunService:IsStudio(), "Debug tools require Studio")
	return Service.inspect(player)
end
function Debug.skip(player: Player, seconds: number): boolean
	assert(RunService:IsStudio(), "Debug tools require Studio")
	assert(
		seconds == seconds and seconds >= 0 and seconds <= Config.maxSimulationSeconds,
		"Invalid skip"
	)
	return Service.advance(player, seconds)
end
-- Studio-namespace test data only: jump the planet to given growth levels (for stage screenshots).
function Debug.setGrowth(player: Player, earthLevel: number, waterLevel: number): boolean
	assert(RunService:IsStudio(), "Debug tools require Studio")
	local planet = Service.studioData(player)
	local definition = Planet.definition(ServerConfig.planetId)
	local state = { earthLevel = earthLevel, waterLevel = waterLevel }
	assert(planet ~= nil and Planet.valid(definition, state), "Invalid growth levels")
	planet.growth = state
	Service.studioRefresh(player)
	print(string.format("[GrowAPlanet:Debug] SET_GROWTH earth=%d water=%d", earthLevel, waterLevel))
	return true
end
-- Studio-namespace test data only: add resources so purchase paths can be exercised quickly.
function Debug.grant(player: Player, resource: string, amount: number): boolean
	assert(RunService:IsStudio(), "Debug tools require Studio")
	local planet = Service.studioData(player)
	assert(
		planet ~= nil and planet.resources[resource] ~= nil and resource ~= "Population",
		"Invalid grant"
	)
	planet.resources[resource] = Big.add(planet.resources[resource], Big.new(amount))
	Service.studioRefresh(player)
	print(string.format("[GrowAPlanet:Debug] GRANT %s %s", resource, Big.format(Big.new(amount))))
	return true
end
-- Simulate having been away `secondsAway` seconds: runs the real offline-income path.
function Debug.offline(player: Player, secondsAway: number): number
	assert(RunService:IsStudio(), "Debug tools require Studio")
	local planet = Service.studioData(player)
	assert(planet ~= nil and secondsAway >= 0, "Invalid offline test")
	local now = os.time()
	planet.civilization.lastOnline = now - secondsAway
	return Service.applyOffline(player, now)
end
-- The same server path as the client's purchase intents (validation included).
function Debug.act(player: Player, intent: string, a: any, b: any): (boolean, string?)
	assert(RunService:IsStudio(), "Debug tools require Studio")
	return Service.act(player, intent, a, b)
end
function Debug.grow(player: Player, id: string): (boolean, string?)
	assert(RunService:IsStudio(), "Debug tools require Studio")
	return Service.grow(player, id)
end
-- Bot playthrough on fresh in-memory data (never a profile). Results are SIMULATED pacing.
function Debug.simulate(seconds: number, clicksPerSecond: number): any
	assert(RunService:IsStudio(), "Debug tools require Studio")
	assert(
		seconds >= 0 and seconds <= Config.maxBotSeconds and seconds % 1 == 0,
		"Invalid simulation duration"
	)
	assert(
		clicksPerSecond >= 0
			and clicksPerSecond <= Config.clicksPerSecond
			and clicksPerSecond % 1 == 0,
		"Invalid click rate"
	)
	return Bot.run({ seconds = seconds, clicksPerSecond = clicksPerSecond })
end
-- Real API acceptance test on a dedicated test key. Never uses the mock backend or player keys.
function Debug.persistence(): any
	assert(RunService:IsStudio(), "Debug tools require Studio")
	assert(ProfileStore.DataStoreState == "Access", "Real DataStore access required")
	local store = ProfileStore.New(ServerConfig.studioStore, Schema.new())
	local key = "Acceptance_" .. game:GetService("HttpService"):GenerateGUID(false)
	local deadline = os.clock() + ServerConfig.loadTimeout
	local profile = store:StartSessionAsync(key, {
		Cancel = function()
			return os.clock() > deadline
		end,
	})
	assert(profile ~= nil, "Acceptance profile failed to load")
	profile.Data.planets.home.resources.GrowthPoints = Big.new(42)
	local saved = false
	local connection = profile.OnAfterSave:Connect(function()
		saved = true
	end)
	profile:EndSession()
	while not saved and os.clock() < deadline do
		task.wait(0.1)
	end
	connection:Disconnect()
	assert(saved, "Final save was not observed")
	local before = store:GetAsync(key)
	assert(before ~= nil, "Saved record not readable")
	local attempts = 0
	local failed, reason = Session.load(function()
		attempts += 1
		return nil -- Inject a transport/session-acquisition failure before granting a profile.
	end, function()
		return false
	end)
	assert(failed == nil and reason == "load_failed", "Forced failure granted a session")
	local after = store:GetAsync(key)
	assert(after ~= nil, "Record disappeared after forced failure")
	assert(
		Big.compare(after.Data.planets.home.resources.GrowthPoints, Big.new(42)) == 0,
		"Forced failure overwrote saved data"
	)
	deadline = os.clock() + ServerConfig.loadTimeout
	local reopened = store:StartSessionAsync(key, {
		Cancel = function()
			return os.clock() > deadline
		end,
	})
	assert(reopened ~= nil, "Could not reopen saved profile")
	local retained = Big.compare(reopened.Data.planets.home.resources.GrowthPoints, Big.new(42))
		== 0
	reopened:EndSession()
	assert(retained, "Reopened profile lost resources")
	return {
		realDataStore = true,
		saved = 42,
		afterFailedLoad = 42,
		reopened = retained,
		injectedFailures = attempts,
		key = key,
	}
end
return Debug
