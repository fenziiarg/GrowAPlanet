--!strict
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService").GrowAPlanet
local Shared = game:GetService("ReplicatedStorage").GrowAPlanet
local Service = require(Server.Service)
local Config = require(Shared.config.economy)
local Economy = require(Shared.Economy)
local Planet = require(Shared.Planet)
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
-- Studio-namespace test data only: give one region a population to prove region data persists.
function Debug.setPopulation(player: Player, regionId: number, population: number): boolean
	assert(RunService:IsStudio(), "Debug tools require Studio")
	local planet = Service.studioData(player)
	assert(planet ~= nil, "No active session")
	local data = table.clone(planet.regions)
	data.population = table.clone(data.population)
	data.population[tostring(regionId)] = population
	assert(Schema.validRegions(ServerConfig.planetId, data), "Invalid region data")
	planet.regions = data
	Service.studioRefresh(player)
	print(
		string.format(
			"[GrowAPlanet:Debug] SET_POPULATION region=%d population=%d",
			regionId,
			population
		)
	)
	return true
end
function Debug.grow(player: Player, id: string): (boolean, string?)
	assert(RunService:IsStudio(), "Debug tools require Studio")
	return Service.grow(player, id)
end
-- Bot playthrough on fresh in-memory data (never a profile): click at a fixed rate and buy the
-- growth the next stage still needs, cheapest first. Results are simulated, not human-verified.
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
	local definition = Planet.definition(ServerConfig.planetId)
	local resources = Economy.initial()
	local state = Planet.initial()
	local stageSeconds: { [string]: number } = { [definition.stages[1].id] = 0 }
	for second = 1, seconds do
		resources = Economy.advance(resources, 1, Planet.production(definition, state))
		for _ = 1, clicksPerSecond do
			resources = Economy.click(resources)
		end
		while true do
			local stats = Planet.stats(definition, state)
			local target = definition.stages[math.min(stats.stage + 1, #definition.stages)]
			local best: string? = nil
			local bestCost = nil
			for _, id in definition.growthIds do
				local needed = if id == "Earth"
					then stats.earthMass < target.minimumEarthMass
					else stats.waterMass < target.minimumWaterMass
				local unlocked = stats.stage >= (Planet.growth(definition, id) :: any).unlockStage
				if unlocked and (needed or stats.stage == #definition.stages) then
					local cost = Planet.cost(definition, state, id)
					if bestCost == nil or Big.compare(cost, bestCost) < 0 then
						best, bestCost = id, cost
					end
				end
			end
			if best == nil then
				break
			end
			local nextResources, nextState = Planet.grow(definition, resources, state, best :: any)
			if nextResources == nil or nextState == nil then
				break
			end
			resources, state = nextResources, nextState
			local stage = definition.stages[Planet.stats(definition, state).stage].id
			stageSeconds[stage] = stageSeconds[stage] or second
		end
	end
	return {
		simulated = true,
		seconds = seconds,
		clicksPerSecond = clicksPerSecond,
		stageSeconds = stageSeconds,
		final = Planet.stats(definition, state),
		growthPoints = Big.format(resources.GrowthPoints),
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
