--!strict
-- Pure civilization rules: cities, buildings, production, ages, upgrades, Kardashev milestones
-- and offline income. Inputs are never mutated; actions return new tables or a rejection reason.
-- The server is the only caller that commits results.
local Big = require(script.Parent.BigNumber)
local Economy = require(script.Parent.Economy)
local Terrain = require(script.Parent.Terrain)
local AgesConfig = require(script.Parent.config.ages)
local Buildings = require(script.Parent.config.buildings)
local Cities = require(script.Parent.config.cities)
local Kardashev = require(script.Parent.config.kardashev)
local Regions = require(script.Parent.config.regions)
local EconomyConfig = require(script.Parent.config.economy)
export type Cost = { [string]: number }
export type State = {
	age: number,
	upgrades: { [string]: boolean },
	kardashev: number,
	-- Server os.time() of the last online tick; 0 until the first session saves it.
	lastOnline: number,
}
export type RegionData = {
	topologyVersion: number,
	seed: number,
	terrain: string,
	population: { [string]: number },
	-- A key's presence means the region has a city; values are building levels.
	buildings: { [string]: { [string]: number } },
}
export type CityStats = {
	development: number,
	stage: number,
	population: number,
	production: { [string]: number },
}
local Civilization = {}
local PRODUCED = { "Food", "Materials", "Energy", "Money", "Research" }
local upgradeById: { [string]: AgesConfig.Upgrade } = {}
for _, upgrade in AgesConfig.upgrades do
	upgradeById[upgrade.id] = upgrade
end
local buildable: { [string]: boolean } = {}
for _, id in Cities.buildableTerrainIds do
	buildable[id] = true
end

function Civilization.initial(): State
	return { age = 0, upgrades = {}, kardashev = 0, lastOnline = 0 }
end

local function count(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and n < math.huge and n % 1 == 0
end

function Civilization.valid(state: any): boolean
	if
		type(state) ~= "table"
		or not count(state.age)
		or state.age > #AgesConfig.ages
		or not count(state.kardashev)
		or state.kardashev > #Kardashev.milestones
		or not count(state.lastOnline)
		or type(state.upgrades) ~= "table"
	then
		return false
	end
	for id, owned in state.upgrades do
		if upgradeById[id] == nil or owned ~= true then
			return false
		end
	end
	return true
end

-- Region IDs from clients must be integers within the planet's region range.
function Civilization.validRegion(planetId: string, regionId: any): boolean
	local definition = Regions[planetId]
	return definition ~= nil
		and type(regionId) == "number"
		and regionId == regionId
		and regionId % 1 == 0
		and regionId >= 1
		and regionId <= definition.count
end

function Civilization.terrainAt(regions: RegionData, regionId: number): string?
	local look = Terrain.fromCode(string.sub(regions.terrain, regionId, regionId))
	return if look then look.id else nil
end

function Civilization.cityCount(regions: RegionData): number
	local n = 0
	for _ in regions.buildings do
		n += 1
	end
	return n
end

function Civilization.scaled(cost: Cost, factor: number): Cost
	local result: Cost = {}
	for id, amount in cost do
		result[id] = amount * factor
	end
	return result
end

function Civilization.foundingCost(regions: RegionData): Cost
	return Civilization.scaled(
		Cities.foundingCost,
		Cities.foundingGrowth ^ Civilization.cityCount(regions)
	)
end

function Civilization.buildingCost(building: Buildings.Definition, level: number): Cost
	return Civilization.scaled(building.baseCost, building.costGrowth ^ level)
end

function Civilization.canAfford(balances: Economy.Balances, cost: Cost): boolean
	for id, amount in cost do
		local balance = balances[id]
		if balance == nil or Big.compare(balance, Big.new(amount)) < 0 then
			return false
		end
	end
	return true
end

local function pay(balances: Economy.Balances, cost: Cost): Economy.Balances
	local result = table.clone(balances)
	for id, amount in cost do
		result[id] = Big.subtract(balances[id], Big.new(amount))
	end
	return result
end

-- Product of an effect key over owned upgrades and reached Kardashev milestones.
function Civilization.multiplier(state: State, key: string): number
	local total = 1
	for id in state.upgrades do
		total *= upgradeById[id].effects[key] or 1
	end
	for index = 1, state.kardashev do
		total *= Kardashev.milestones[index].effects[key] or 1
	end
	return total
end

function Civilization.ageMultiplier(state: State): number
	local age = AgesConfig.ages[state.age]
	return if age then age.incomeMultiplier else 1
end

function Civilization.cityStats(regions: RegionData, state: State, regionId: number): CityStats?
	local levels = regions.buildings[tostring(regionId)]
	local terrainId = Civilization.terrainAt(regions, regionId)
	if levels == nil or terrainId == nil then
		return nil
	end
	local terrain = Terrain.fromCode(string.sub(regions.terrain, regionId, regionId)) :: any
	local terrainMultipliers = terrain.productionMultipliers
	local development, housing = 0, Cities.baseHousing
	local raw: { [string]: number } = table.clone(Cities.baseProduction)
	for id, level in levels do
		local building = Buildings.byId[id]
		if building then
			development += building.development * level
			housing += building.housing * level
			for resource, amount in building.production do
				raw[resource] = (raw[resource] or 0) + amount * level
			end
		end
	end
	local stageIndex = 1
	for index, stage in Cities.stages do
		if development >= stage.minimumDevelopment then
			stageIndex = index
		end
	end
	local stage = Cities.stages[stageIndex]
	local ageMultiplier = Civilization.ageMultiplier(state)
	local production: { [string]: number } = {}
	for _, resource in PRODUCED do
		local social = if resource == "Money"
			then stage.money
			elseif resource == "Research" then stage.research
			else 1
		production[resource] = (raw[resource] or 0)
			* (terrainMultipliers[resource] or 1)
			* social
			* ageMultiplier
			* Civilization.multiplier(state, resource)
	end
	return {
		development = development,
		stage = stageIndex,
		population = math.floor(
			housing
				* (terrainMultipliers.Housing or 1)
				* stage.population
				* Civilization.multiplier(state, "Housing")
		),
		production = production,
	}
end

-- Planet totals: the sum of all cities (age, upgrade and Kardashev multipliers included).
function Civilization.totals(regions: RegionData, state: State): ({ [string]: number }, number)
	local rates: { [string]: number } = {}
	for _, resource in PRODUCED do
		rates[resource] = 0
	end
	local population = 0
	for key in regions.buildings do
		local stats = Civilization.cityStats(regions, state, tonumber(key) :: number)
		if stats then
			population += stats.population
			for resource, amount in stats.production do
				rates[resource] += amount
			end
		end
	end
	return rates, population
end

-- Full per-second rates for every resource: `base` (planet growth income) plus all cities.
-- Population is a level, not a flow, so its rate is always 0; the caller sets it from totals.
function Civilization.rates(
	base: { [string]: number },
	regions: RegionData,
	state: State
): ({ [string]: number }, number)
	local cities, population = Civilization.totals(regions, state)
	local rates: { [string]: number } = {}
	for _, id in EconomyConfig.resourceIds do
		rates[id] = if id == "Population" then 0 else (base[id] or 0) + (cities[id] or 0)
	end
	return rates, population
end

local function refreshPopulation(regions: RegionData, state: State): RegionData
	local result = table.clone(regions)
	result.population = {}
	for key in regions.buildings do
		local stats = Civilization.cityStats(regions, state, tonumber(key) :: number)
		if stats then
			result.population[key] = stats.population
		end
	end
	return result
end
Civilization.refreshPopulation = refreshPopulation

function Civilization.found(
	planetId: string,
	balances: Economy.Balances,
	regions: RegionData,
	state: State,
	regionId: any
): (Economy.Balances?, RegionData?, State?, string?)
	if not Civilization.validRegion(planetId, regionId) then
		return nil, nil, nil, "invalid_region"
	end
	local key = tostring(regionId)
	if regions.buildings[key] ~= nil then
		return nil, nil, nil, "city_exists"
	end
	local terrainId = Civilization.terrainAt(regions, regionId)
	if terrainId == nil or not buildable[terrainId] then
		return nil, nil, nil, "terrain_not_buildable"
	end
	local cost = Civilization.foundingCost(regions)
	if not Civilization.canAfford(balances, cost) then
		return nil, nil, nil, "insufficient_funds"
	end
	local nextRegions = table.clone(regions)
	nextRegions.buildings = table.clone(regions.buildings)
	nextRegions.buildings[key] = {}
	local nextState = table.clone(state)
	if nextState.age == 0 then
		nextState.age = 1 -- founding the first settlement starts the Paleolithic
	end
	return pay(balances, cost), refreshPopulation(nextRegions, nextState), nextState, nil
end

function Civilization.build(
	planetId: string,
	balances: Economy.Balances,
	regions: RegionData,
	state: State,
	regionId: any,
	buildingId: any
): (Economy.Balances?, RegionData?, State?, string?)
	if not Civilization.validRegion(planetId, regionId) then
		return nil, nil, nil, "invalid_region"
	end
	local building = type(buildingId) == "string" and Buildings.byId[buildingId] or nil
	if building == nil then
		return nil, nil, nil, "unknown_building"
	end
	local key = tostring(regionId)
	local levels = regions.buildings[key]
	if levels == nil then
		return nil, nil, nil, "no_city"
	end
	if state.age < building.age then
		return nil, nil, nil, "age_locked"
	end
	if
		not table.find(building.allowedTerrainIds, Civilization.terrainAt(regions, regionId) or "")
	then
		return nil, nil, nil, "terrain_not_allowed"
	end
	local level = levels[building.id] or 0
	if level >= building.maxLevel then
		return nil, nil, nil, "max_level"
	end
	local cost = Civilization.buildingCost(building, level)
	if not Civilization.canAfford(balances, cost) then
		return nil, nil, nil, "insufficient_funds"
	end
	local nextRegions = table.clone(regions)
	nextRegions.buildings = table.clone(regions.buildings)
	local nextLevels = table.clone(levels)
	nextLevels[building.id] = level + 1
	nextRegions.buildings[key] = nextLevels
	return pay(balances, cost), refreshPopulation(nextRegions, state), state, nil
end

function Civilization.advanceAge(
	balances: Economy.Balances,
	regions: RegionData,
	state: State
): (Economy.Balances?, RegionData?, State?, string?)
	local nextAge = AgesConfig.ages[state.age + 1]
	if state.age == 0 then
		return nil, nil, nil, "no_city"
	end
	if nextAge == nil then
		return nil, nil, nil, "max_age"
	end
	local _, population = Civilization.totals(regions, state)
	if population < nextAge.population then
		return nil, nil, nil, "population_required"
	end
	if not Civilization.canAfford(balances, nextAge.cost) then
		return nil, nil, nil, "insufficient_funds"
	end
	local nextState = table.clone(state)
	nextState.age += 1
	return pay(balances, nextAge.cost), refreshPopulation(regions, nextState), nextState, nil
end

function Civilization.buyUpgrade(
	balances: Economy.Balances,
	regions: RegionData,
	state: State,
	upgradeId: any
): (Economy.Balances?, RegionData?, State?, string?)
	local upgrade = type(upgradeId) == "string" and upgradeById[upgradeId] or nil
	if upgrade == nil then
		return nil, nil, nil, "unknown_upgrade"
	end
	if state.upgrades[upgrade.id] then
		return nil, nil, nil, "already_owned"
	end
	if state.age < upgrade.age then
		return nil, nil, nil, "age_locked"
	end
	for _, required in upgrade.requires do
		if not state.upgrades[required] then
			return nil, nil, nil, "requires_upgrade"
		end
	end
	if not Civilization.canAfford(balances, upgrade.cost) then
		return nil, nil, nil, "insufficient_funds"
	end
	local nextState = table.clone(state)
	nextState.upgrades = table.clone(state.upgrades)
	nextState.upgrades[upgrade.id] = true
	return pay(balances, upgrade.cost), refreshPopulation(regions, nextState), nextState, nil
end

function Civilization.nextMilestone(state: State): Kardashev.Milestone?
	return Kardashev.milestones[state.kardashev + 1]
end

function Civilization.advanceKardashev(
	balances: Economy.Balances,
	regions: RegionData,
	state: State
): (Economy.Balances?, RegionData?, State?, string?)
	local milestone = Civilization.nextMilestone(state)
	if milestone == nil then
		return nil, nil, nil, "max_kardashev"
	end
	if state.age < milestone.age then
		return nil, nil, nil, "age_locked"
	end
	if not Civilization.canAfford(balances, milestone.cost) then
		return nil, nil, nil, "insufficient_funds"
	end
	local nextState = table.clone(state)
	nextState.kardashev += 1
	return pay(balances, milestone.cost), refreshPopulation(regions, nextState), nextState, nil
end

function Civilization.upgrade(id: string): AgesConfig.Upgrade?
	return upgradeById[id]
end

-- Seconds of offline production to credit: elapsed server time, never negative, capped.
function Civilization.offlineSeconds(lastOnline: number, now: number): number
	if lastOnline <= 0 or now <= lastOnline then
		return 0
	end
	return math.min(now - lastOnline, EconomyConfig.offlineCapSeconds)
end

-- Balances after crediting offline production at the configured efficiency.
function Civilization.offline(
	balances: Economy.Balances,
	rates: { [string]: number },
	lastOnline: number,
	now: number
): (Economy.Balances, number)
	local seconds = Civilization.offlineSeconds(lastOnline, now)
	if seconds <= 0 then
		return balances, 0
	end
	local credited: { [string]: number } = {}
	for _, id in EconomyConfig.resourceIds do
		credited[id] = if id == "Population"
			then 0
			else (rates[id] or 0) * EconomyConfig.offlineEfficiency
	end
	return Economy.advance(balances, seconds, credited), seconds
end

return table.freeze(Civilization)
