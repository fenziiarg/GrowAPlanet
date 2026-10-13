--!strict
local Shared = game:GetService("ReplicatedStorage").GrowAPlanet
local Server = game:GetService("ServerScriptService").GrowAPlanet
local Big = require(Shared.BigNumber)
local Civilization = require(Shared.Civilization)
local Economy = require(Shared.Economy)
local AgesConfig = require(Shared.config.ages)
local Buildings = require(Shared.config.buildings)
local Cities = require(Shared.config.cities)
local Kardashev = require(Shared.config.kardashev)
local Regions = require(Shared.config.regions)
local Terrains = require(Shared.config.terrain)
local EconomyConfig = require(Shared.config.economy)
local Schema = require(Server.ProfileSchema)
return function()
	local it = getfenv().it
	local count = Regions.home.count
	-- Fixture planet: region 1 Grassland, 2 Mountains, 3 Desert, 4 Forest, everything else Ocean.
	local function fixture(): Civilization.RegionData
		local terrain = "LMDF" .. string.rep("O", count - 4)
		return { topologyVersion = 1, seed = 1, terrain = terrain, population = {}, buildings = {} }
	end
	local function rich(): Economy.Balances
		local balances = Economy.initial()
		for id in balances do
			if id ~= "Population" then
				balances[id] = Big.new(1, 30)
			end
		end
		return balances
	end
	local function near(a: number, b: number, what: string)
		assert(math.abs(a - b) <= 1e-9 * math.max(1, math.abs(b)), what .. ": " .. a .. " ~= " .. b)
	end
	local function withCity(
		regions: Civilization.RegionData,
		id: number,
		levels: { [string]: number }
	)
		local copy = table.clone(regions)
		copy.buildings = table.clone(regions.buildings)
		copy.buildings[tostring(id)] = levels
		return copy
	end
	local paleolithic: Civilization.State =
		{ age = 1, upgrades = {}, kardashev = 0, lastOnline = 0 }

	it("computes city production from buildings, terrain, stage and age", function()
		local regions = withCity(fixture(), 1, { HuntingCamp = 3 })
		local stats = Civilization.cityStats(regions, paleolithic, 1) :: Civilization.CityStats
		local base = Cities.baseProduction.Food + 3 * Buildings.byId.HuntingCamp.production.Food
		near(stats.production.Food, base * Terrains.Land.productionMultipliers.Food, "Food")
		assert(stats.development == 3 * Buildings.byId.HuntingCamp.development, "development")
		assert(stats.stage == 1, "Hunter-Gatherer")
	end)

	it("produces different outputs on different terrains per the table", function()
		local levels = { HuntingCamp = 5, Mine = 0 }
		local state: Civilization.State = { age = 4, upgrades = {}, kardashev = 0, lastOnline = 0 }
		local regions = fixture()
		for id = 1, 4 do
			regions = withCity(regions, id, table.clone(levels))
			regions.buildings[tostring(id)].Mine = 4
		end
		local land = Civilization.cityStats(regions, state, 1) :: Civilization.CityStats
		local mountains = Civilization.cityStats(regions, state, 2) :: Civilization.CityStats
		local desert = Civilization.cityStats(regions, state, 3) :: Civilization.CityStats
		local forest = Civilization.cityStats(regions, state, 4) :: Civilization.CityStats
		assert(land.production.Food > forest.production.Food, "Grassland out-farms Forest")
		assert(forest.production.Food > mountains.production.Food, "Forest out-farms Mountains")
		assert(mountains.production.Materials > forest.production.Materials, "Mountains mine most")
		assert(land.population > desert.population, "Grassland houses more than Desert")
		local ratio = mountains.production.Materials / land.production.Materials
		near(
			ratio,
			Terrains.Mountains.productionMultipliers.Materials
				/ Terrains.Land.productionMultipliers.Materials,
			"materials ratio follows the table"
		)
	end)

	it("moves cities through socioeconomic stages by development", function()
		for index, stage in Cities.stages do
			local farms =
				math.ceil(stage.minimumDevelopment / Buildings.byId.HuntingCamp.development)
			local regions =
				withCity(fixture(), 1, if farms > 0 then { HuntingCamp = farms } else {})
			local stats = Civilization.cityStats(regions, paleolithic, 1) :: Civilization.CityStats
			assert(
				stats.stage == index,
				"stage " .. stage.id .. " at development " .. stats.development
			)
		end
	end)

	it("sums planet totals across cities and applies age multipliers", function()
		local regions =
			withCity(withCity(fixture(), 1, { HuntingCamp = 2 }), 4, { HuntingCamp = 2 })
		local rates, population = Civilization.totals(regions, paleolithic)
		local a = Civilization.cityStats(regions, paleolithic, 1) :: Civilization.CityStats
		local b = Civilization.cityStats(regions, paleolithic, 4) :: Civilization.CityStats
		near(rates.Food, a.production.Food + b.production.Food, "sum")
		assert(population == a.population + b.population, "population sum")
		local neolithic = table.clone(paleolithic)
		neolithic.age = 3
		local boosted = Civilization.totals(regions, neolithic)
		near(boosted.Food / rates.Food, AgesConfig.ages[3].incomeMultiplier, "age multiplier")
	end)

	it("rejects invalid region IDs for every region action", function()
		local state = Civilization.initial()
		local cases: { any } = { 0, -1, count + 1, 1.5, 0 / 0, math.huge, "1", {}, false }
		local _, _, _, missing = Civilization.found("home", rich(), fixture(), state, nil)
		assert(missing == "invalid_region", "found nil")
		for _, bad in cases do
			local _, _, _, reason = Civilization.found("home", rich(), fixture(), state, bad)
			assert(reason == "invalid_region", "found " .. tostring(bad))
			local _, _, _, buildReason =
				Civilization.build("home", rich(), fixture(), paleolithic, bad, "Hut")
			assert(buildReason == "invalid_region", "build " .. tostring(bad))
		end
	end)

	it("validates founding: terrain, duplicates, cost, first age", function()
		local state = Civilization.initial()
		local _, _, _, ocean = Civilization.found("home", rich(), fixture(), state, 5)
		assert(ocean == "terrain_not_buildable", "no cities at sea")
		local _, _, _, poor = Civilization.found("home", Economy.initial(), fixture(), state, 1)
		assert(poor == "insufficient_funds", "founding costs Growth Points")
		local balances, regions, civ = Civilization.found("home", rich(), fixture(), state, 1)
		assert(balances and regions and civ, "founded")
		assert((civ :: any).age == 1, "first city starts the Paleolithic")
		assert((regions :: any).buildings["1"] ~= nil, "city recorded")
		local _, _, _, again = Civilization.found("home", rich(), regions :: any, civ :: any, 1)
		assert(again == "city_exists", "one city per region")
		local second = Civilization.foundingCost(regions :: any)
		near(
			second.GrowthPoints,
			Cities.foundingCost.GrowthPoints * Cities.foundingGrowth,
			"escalates"
		)
	end)

	it("validates building: unknown, no city, age, terrain, max level, funds", function()
		local regions = withCity(withCity(fixture(), 1, {}), 3, {})
		local function reason(...: any): string?
			local _, _, _, r = Civilization.build("home", ...)
			return r
		end
		assert(
			reason(rich(), regions, paleolithic, 1, "Spaceport") == "unknown_building",
			"unknown"
		)
		assert(reason(rich(), regions, paleolithic, 1, 42) == "unknown_building", "non-string id")
		assert(reason(rich(), regions, paleolithic, 2, "Hut") == "no_city", "no city")
		assert(
			reason(rich(), regions, paleolithic, 1, "Farm") == "age_locked",
			"Farm needs Neolithic"
		)
		local neolithic = table.clone(paleolithic)
		neolithic.age = 3
		assert(
			reason(rich(), regions, neolithic, 3, "Farm") == "terrain_not_allowed",
			"no farms in Desert"
		)
		assert(
			reason(Economy.initial(), regions, paleolithic, 1, "Hut") == "insufficient_funds",
			"funds"
		)
		local maxed = withCity(fixture(), 1, { Hut = Buildings.byId.Hut.maxLevel })
		assert(reason(rich(), maxed, paleolithic, 1, "Hut") == "max_level", "max level")
		local balances, built = Civilization.build("home", rich(), regions, paleolithic, 1, "Hut")
		assert(balances and (built :: any).buildings["1"].Hut == 1, "built level 1")
		assert((built :: any).population["1"] > 0, "population refreshed")
		local cost = Civilization.buildingCost(Buildings.byId.Hut, 1)
		near(
			cost.Food,
			Buildings.byId.Hut.baseCost.Food * Buildings.byId.Hut.costGrowth,
			"next level cost"
		)
	end)

	it("advances ages only at the configured population and cost", function()
		local nextAge = AgesConfig.ages[2]
		local huts = 0
		local regions = withCity(fixture(), 1, {})
		while
			(Civilization.cityStats(regions, paleolithic, 1) :: any).population < nextAge.population
		do
			huts += 1
			regions = withCity(fixture(), 1, { Hut = huts })
		end
		local fewer = withCity(fixture(), 1, { Hut = huts - 1 })
		local _, _, _, low = Civilization.advanceAge(rich(), fewer, paleolithic)
		assert(low == "population_required", "population gate")
		local _, _, _, poor = Civilization.advanceAge(Economy.initial(), regions, paleolithic)
		assert(poor == "insufficient_funds", "cost gate")
		local balances, _, state = Civilization.advanceAge(rich(), regions, paleolithic)
		assert(balances and (state :: any).age == 2, "advanced")
		local _, _, _, none = Civilization.advanceAge(rich(), regions, Civilization.initial())
		assert(none == "no_city", "no age before the first city")
		local final = table.clone(paleolithic)
		final.age = #AgesConfig.ages
		local _, _, _, done = Civilization.advanceAge(rich(), regions, final)
		assert(done == "max_age", "Silicon and AI is the last v1 age")
	end)

	it("defines strictly increasing age requirements and multipliers", function()
		for index = 2, #AgesConfig.ages do
			local previous, age = AgesConfig.ages[index - 1], AgesConfig.ages[index]
			assert(age.population > previous.population, age.id .. " population")
			assert(age.incomeMultiplier > previous.incomeMultiplier, age.id .. " multiplier")
		end
		local perAge: { [string]: number } = {}
		for _, building in Buildings.list do
			local group = AgesConfig.ages[building.age].group
			perAge[group] = (perAge[group] or 0) + 1
		end
		for _, age in AgesConfig.ages do
			assert((perAge[age.group] or 0) >= 2, "at least 2 buildings in " .. age.group)
		end
	end)

	it("enforces the upgrade tree and applies upgrade effects", function()
		local regions = withCity(fixture(), 1, { HuntingCamp = 4 })
		local copper = table.clone(paleolithic)
		copper.age = 4
		local _, _, _, needs = Civilization.buyUpgrade(rich(), regions, copper, "Smelting")
		assert(needs == "requires_upgrade", "Smelting needs Stone Tools")
		local _, _, _, locked = Civilization.buyUpgrade(rich(), regions, paleolithic, "Smelting")
		assert(locked == "age_locked", "age gate")
		local before = (Civilization.cityStats(regions, copper, 1) :: any).production.Food
		local _, _, owned = Civilization.buyUpgrade(rich(), regions, copper, "StoneTools")
		assert(owned and (owned :: any).upgrades.StoneTools, "owned")
		local after = (Civilization.cityStats(regions, owned :: any, 1) :: any).production.Food
		near(after / before, 1.25, "Stone Tools effect")
		local _, _, _, twice = Civilization.buyUpgrade(rich(), regions, owned :: any, "StoneTools")
		assert(twice == "already_owned", "no double purchase")
		local _, _, _, unknown = Civilization.buyUpgrade(rich(), regions, copper, "Teleporter")
		assert(unknown == "unknown_upgrade", "unknown upgrade")
	end)

	it("reaches each Kardashev milestone only after its age, in order", function()
		local regions = withCity(fixture(), 1, {})
		for index, milestone in Kardashev.milestones do
			local state: Civilization.State =
				{ age = milestone.age - 1, upgrades = {}, kardashev = index - 1, lastOnline = 0 }
			local _, _, _, locked = Civilization.advanceKardashev(rich(), regions, state)
			assert(locked == "age_locked", milestone.name .. " age gate")
			state.age = milestone.age
			local _, _, _, poor = Civilization.advanceKardashev(Economy.initial(), regions, state)
			assert(poor == "insufficient_funds", milestone.name .. " cost")
			local _, _, reached = Civilization.advanceKardashev(rich(), regions, state)
			assert(reached and (reached :: any).kardashev == index, milestone.name .. " reached")
		end
		local done: Civilization.State = {
			age = #AgesConfig.ages,
			upgrades = {},
			kardashev = #Kardashev.milestones,
			lastOnline = 0,
		}
		local _, _, _, max = Civilization.advanceKardashev(rich(), regions, done)
		assert(max == "max_kardashev", "Type III is the last v1 milestone")
	end)

	it("credits offline income below, at and past the cap", function()
		local cap = EconomyConfig.offlineCapSeconds
		local rates: { [string]: number } = { Food = 10, Money = 4, GrowthPoints = 2 }
		local function credited(lastOnline: number, now: number): (number, number)
			local balances, seconds =
				Civilization.offline(Economy.initial(), rates, lastOnline, now)
			return balances.Food.m * 10 ^ balances.Food.e, seconds
		end
		local start = 1_700_000_000
		local food, seconds = credited(start, start + 3600)
		assert(seconds == 3600, "below cap: full time")
		near(food, 10 * 3600 * EconomyConfig.offlineEfficiency, "below cap amount")
		food, seconds = credited(start, start + cap)
		assert(seconds == cap, "at cap")
		near(food, 10 * cap * EconomyConfig.offlineEfficiency, "at cap amount")
		food, seconds = credited(start, start + cap * 3)
		assert(seconds == cap, "past cap is clamped")
		near(food, 10 * cap * EconomyConfig.offlineEfficiency, "past cap amount")
		local _, skew = credited(start, start - 500)
		assert(skew == 0, "clock moving backwards credits nothing")
		local _, unset = credited(0, start)
		assert(unset == 0, "no credit before the first saved session")
		local balances = Civilization.offline(Economy.initial(), rates, start, start + 60)
		assert(balances.Population.m == 0, "population is never credited")
	end)

	it("migrates v3 profiles to v4 with derived population and validates v4 records", function()
		local v3: any = Schema.upgrade(Schema.new(), 77)
		v3.schemaVersion = 3
		v3.planets.home.civilization = nil
		v3.planets.home.regions.population = { ["207"] = 1234 }
		local upgraded: any = Schema.upgrade(v3, 99)
		assert(upgraded and upgraded.schemaVersion == 4, "upgraded")
		assert(upgraded.planets.home.civilization.age == 0, "civilization initialized")
		assert(
			next(upgraded.planets.home.regions.population) == nil,
			"population re-derived from cities"
		)
		assert(upgraded.planets.home.regions.seed == 77, "seed kept")
		local bad: any = table.clone(upgraded.planets.home.regions)
		bad.buildings = { ["1"] = { Spaceport = 1 } }
		assert(not Schema.validRegions("home", bad), "unknown building rejected")
		bad.buildings = { ["1"] = { Hut = Buildings.byId.Hut.maxLevel + 1 } }
		assert(not Schema.validRegions("home", bad), "level above max rejected")
		local tampered = table.clone(upgraded)
		tampered.planets = table.clone(upgraded.planets)
		tampered.planets.home = table.clone(upgraded.planets.home)
		tampered.planets.home.regions = table.clone(upgraded.planets.home.regions)
		tampered.planets.home.regions.population = { ["3"] = 999 }
		assert(not Schema.validate(tampered), "population must match cities")
		local badCiv = table.clone(upgraded.planets.home.civilization)
		badCiv.upgrades = { Teleporter = true }
		assert(not Civilization.valid(badCiv), "unknown upgrade rejected")
	end)
end
