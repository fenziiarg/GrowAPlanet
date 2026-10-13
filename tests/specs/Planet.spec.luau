--!strict
local Shared = game:GetService("ReplicatedStorage").GrowAPlanet
local Server = game:GetService("ServerScriptService").GrowAPlanet
local Big = require(Shared.BigNumber)
local Economy = require(Shared.Economy)
local Planet = require(Shared.Planet)
local Schema = require(Server.ProfileSchema)
local Session = require(Server.Session)
return function()
	local it = getfenv().it
	local definition = Planet.definition("home")
	local function rich(): Economy.Balances
		local balances = Economy.initial()
		balances.GrowthPoints = Big.new(1, 200)
		return balances
	end
	local function levelsFor(mass: number, id: "Earth" | "Water"): number
		return math.ceil(mass / (Planet.growth(definition, id) :: any).massPerLevel)
	end

	it("starts as a Barren Rock at base size", function()
		local stats = Planet.stats(definition, Planet.initial())
		assert(stats.stage == 1 and stats.stageId == "BarrenRock", "stage 1")
		assert(stats.earthMass == 0 and stats.waterMass == 0, "zero mass")
		assert(stats.totalSize == definition.baseSizeKm, "base size")
	end)

	it("triggers every stage exactly at its configured thresholds", function()
		for index = 2, #definition.stages do
			local stage = definition.stages[index]
			local at = {
				earthLevel = levelsFor(stage.minimumEarthMass, "Earth"),
				waterLevel = levelsFor(stage.minimumWaterMass, "Water"),
			}
			assert(Planet.stats(definition, at).stage == index, stage.id .. " at threshold")
			if at.earthLevel > 0 then
				local belowEarth = { earthLevel = at.earthLevel - 1, waterLevel = at.waterLevel }
				assert(
					Planet.stats(definition, belowEarth).stage == index - 1,
					stage.id .. " below earth"
				)
			end
			if at.waterLevel > 0 then
				local belowWater = { earthLevel = at.earthLevel, waterLevel = at.waterLevel - 1 }
				assert(
					Planet.stats(definition, belowWater).stage < index,
					stage.id .. " below water"
				)
			end
		end
	end)

	it("increases every stat monotonically with growth", function()
		local state = Planet.initial()
		local balances = rich()
		local previous = Planet.stats(definition, state)
		for step = 1, 120 do
			local id = if step % 3 == 0
					and previous.stage >= definition.growth.Water.unlockStage
				then "Water"
				else "Earth"
			local nextBalances, nextState = Planet.grow(definition, balances, state, id)
			assert(nextBalances ~= nil and nextState ~= nil, "growth accepted")
			balances, state = nextBalances :: any, nextState :: any
			local stats = Planet.stats(definition, state)
			assert(
				stats.earthMass >= previous.earthMass and stats.waterMass >= previous.waterMass,
				"mass"
			)
			assert(stats.totalSize > previous.totalSize, "size grows")
			assert(stats.stage >= previous.stage, "stage never drops")
			previous = stats
		end
		assert(previous.stage == #definition.stages, "reaches final stage")
	end)

	it("charges the configured exponential cost", function()
		local state = { earthLevel = 5, waterLevel = 0 }
		local expected = definition.growth.Earth.baseCost * definition.growth.Earth.costGrowth ^ 5
		local cost = Planet.cost(definition, state, "Earth")
		assert(math.abs(cost.m * 10 ^ cost.e - expected) < 1e-9, "cost formula")
		local balances = rich()
		local after = Planet.grow(definition, balances, state, "Earth")
		assert(after ~= nil, "grow ok")
		assert(
			Big.compare(Big.add((after :: any).GrowthPoints, cost), balances.GrowthPoints) == 0,
			"paid cost"
		)
	end)

	it("rejects unaffordable growth without changing inputs", function()
		local balances = Economy.initial()
		local state = Planet.initial()
		local a, b, reason = Planet.grow(definition, balances, state, "Earth")
		assert(a == nil and b == nil and reason == "insufficient_funds", "rejected")
		assert(state.earthLevel == 0 and balances.GrowthPoints.m == 0, "unchanged")
	end)

	it("locks water until its unlock stage and rejects unknown growth", function()
		local _, _, reason = Planet.grow(definition, rich(), Planet.initial(), "Water")
		assert(reason == "locked", "water locked")
		local _, _, unknown = Planet.grow(definition, rich(), Planet.initial(), "Lava" :: any)
		assert(unknown == "unknown_growth", "unknown growth")
	end)

	it("stops at the maximum level", function()
		local state = { earthLevel = definition.maxLevel, waterLevel = 0 }
		local _, _, reason = Planet.grow(definition, rich(), state, "Earth")
		assert(reason == "max_level", "max level")
	end)

	it("adds growth-level income to Growth Points only", function()
		local rates = Planet.production(definition, { earthLevel = 3, waterLevel = 2 })
		local expected = 1
			+ 3 * definition.growth.Earth.incomePerLevel
			+ 2 * definition.growth.Water.incomePerLevel
		assert(rates.GrowthPoints == expected, "income")
		assert(rates.Money == 0, "other resources unchanged")
	end)

	it("rejects malformed growth state", function()
		local cases: { any } = {
			{ earthLevel = -1, waterLevel = 0 },
			{ earthLevel = 1.5, waterLevel = 0 },
			{ earthLevel = 0 },
			{ earthLevel = 0 / 0, waterLevel = 0 },
		}
		for _, bad in cases do
			assert(not Planet.valid(definition, bad), "invalid state accepted")
		end
	end)

	it("migrates a valid v1 profile without mutating the stored record", function()
		local v1 = {
			schemaVersion = 1,
			planets = { home = { resources = Economy.initial() } },
		}
		v1.planets.home.resources.GrowthPoints = Big.new(42)
		local upgraded = Schema.upgrade(v1, 123)
		assert(upgraded ~= nil and upgraded.schemaVersion == 3, "upgraded")
		assert((upgraded :: any).planets.home.growth.earthLevel == 0, "growth added")
		assert(
			Big.compare((upgraded :: any).planets.home.resources.GrowthPoints, Big.new(42)) == 0,
			"kept balance"
		)
		assert(v1.schemaVersion == 1 and (v1.planets.home :: any).growth == nil, "source untouched")
	end)

	it("applies the migration to the loaded profile and keeps balances", function()
		local data: any =
			{ schemaVersion = 1, planets = { home = { resources = Economy.initial() } } }
		data.planets.home.resources.GrowthPoints = Big.new(7)
		local fake = {
			Data = data,
			IsActive = function()
				return true
			end,
			EndSession = function() end,
		}
		local profile = Session.load(function()
			return fake
		end, function()
			return false
		end)
		assert(profile == fake and data.schemaVersion == 3, "migrated in place")
		assert(
			Big.compare(data.planets.home.resources.GrowthPoints, Big.new(7)) == 0,
			"balance kept"
		)
	end)

	it("rejects a malformed v1 profile and a corrupt v2 growth record", function()
		local v1 = { schemaVersion = 1, planets = { home = { resources = { GrowthPoints = 5 } } } }
		assert(Schema.upgrade(v1, 123) == nil, "malformed v1")
		local v2 = Schema.new()
		v2.planets.home.growth.earthLevel = -3
		assert(Schema.upgrade(v2, 123) == nil, "corrupt growth")
	end)
end
