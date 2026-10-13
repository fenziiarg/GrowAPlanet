--!strict
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService").GrowAPlanet
local Shared = game:GetService("ReplicatedStorage").GrowAPlanet
local Service = require(Server.Service)
local Config = require(Shared.config.economy)
local Economy = require(Shared.Economy)
local Big = require(Shared.BigNumber)
local Schema = require(Server.ProfileSchema)
local Session = require(Server.Session)
local ServerConfig = require(Server.config)
local ProfileStore = require(game:GetService("ServerStorage").GrowAPlanetDependencies.ProfileStore)
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
function Debug.simulate(seconds: number, clicksPerSecond: number): any
	assert(RunService:IsStudio(), "Debug tools require Studio")
	assert(
		seconds >= 0 and seconds <= Config.maxSimulationSeconds and seconds % 1 == 0,
		"Invalid simulation duration"
	)
	assert(
		clicksPerSecond >= 0
			and clicksPerSecond <= Config.clicksPerSecond
			and clicksPerSecond % 1 == 0,
		"Invalid click rate"
	)
	local resources = Economy.initial()
	for _ = 1, seconds do
		resources = Economy.advance(resources, 1)
		for _ = 1, clicksPerSecond do
			resources = Economy.click(resources)
		end
	end
	return {
		simulated = true,
		seconds = seconds,
		clicksPerSecond = clicksPerSecond,
		resources = resources,
	}
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
