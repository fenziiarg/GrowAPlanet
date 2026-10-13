--!strict
-- Pure planet growth rules. The server is the only caller that commits results.
local Big = require(script.Parent.BigNumber)
local Economy = require(script.Parent.Economy)
local Definitions = require(script.Parent.config.planet)
local EconomyConfig = require(script.Parent.config.economy)
export type State = { earthLevel: number, waterLevel: number }
export type Stats = {
	earthMass: number,
	waterMass: number,
	totalSize: number,
	stage: number,
	stageId: string,
}
local Planet = {}

local function level(state: State, id: string): number
	return if id == "Earth" then state.earthLevel else state.waterLevel
end

-- Resolves a growth id; nil for anything that is not a configured growth.
function Planet.growth(definition: Definitions.Definition, id: string): Definitions.Growth?
	return if id == "Earth"
		then definition.growth.Earth
		elseif id == "Water" then definition.growth.Water
		else nil
end

function Planet.definition(planetId: string): Definitions.Definition
	local definition = Definitions[planetId]
	assert(definition ~= nil, "Unknown planet")
	return definition
end

function Planet.initial(): State
	return { earthLevel = 0, waterLevel = 0 }
end

function Planet.valid(definition: Definitions.Definition, state: any): boolean
	if type(state) ~= "table" then
		return false
	end
	for _, key in { "earthLevel", "waterLevel" } do
		local n = state[key]
		if type(n) ~= "number" or n ~= n or n % 1 ~= 0 or n < 0 or n > definition.maxLevel then
			return false
		end
	end
	return true
end

function Planet.stats(definition: Definitions.Definition, state: State): Stats
	local earthMass = state.earthLevel * definition.growth.Earth.massPerLevel
	local waterMass = state.waterLevel * definition.growth.Water.massPerLevel
	local stage = 1
	for i, candidate in definition.stages do
		if earthMass >= candidate.minimumEarthMass and waterMass >= candidate.minimumWaterMass then
			stage = i
		end
	end
	return {
		earthMass = earthMass,
		waterMass = waterMass,
		totalSize = definition.baseSizeKm
			* (1 + (earthMass + waterMass) / definition.sizeMassStep) ^ (1 / 3),
		stage = stage,
		stageId = definition.stages[stage].id,
	}
end

function Planet.cost(definition: Definitions.Definition, state: State, id: string): Big.Value
	local growth = Planet.growth(definition, id)
	assert(growth ~= nil, "Unknown growth")
	return Big.scale(Big.new(growth.baseCost), growth.costGrowth ^ level(state, id))
end

-- Production rates for the economy tick: config baseline plus growth-level bonuses.
function Planet.production(definition: Definitions.Definition, state: State): { [string]: number }
	local rates = table.clone(EconomyConfig.productionPerSecond)
	for _, id in definition.growthIds do
		local growth = Planet.growth(definition, id)
		if growth then
			rates.GrowthPoints += growth.incomePerLevel * level(state, id)
		end
	end
	return rates
end

-- Returns new balances and state, or nil and a rejection reason. Inputs are never mutated.
function Planet.grow(
	definition: Definitions.Definition,
	balances: Economy.Balances,
	state: State,
	id: string
): (Economy.Balances?, State?, string?)
	local growth = Planet.growth(definition, id)
	if growth == nil then
		return nil, nil, "unknown_growth"
	end
	if Planet.stats(definition, state).stage < growth.unlockStage then
		return nil, nil, "locked"
	end
	if level(state, id) >= definition.maxLevel then
		return nil, nil, "max_level"
	end
	local price = Planet.cost(definition, state, id)
	if Big.compare(balances.GrowthPoints, price) < 0 then
		return nil, nil, "insufficient_funds"
	end
	local resources = table.clone(balances)
	resources.GrowthPoints = Big.subtract(balances.GrowthPoints, price)
	local nextState = table.clone(state)
	if id == "Earth" then
		nextState.earthLevel += 1
	else
		nextState.waterLevel += 1
	end
	return resources, nextState, nil
end

return table.freeze(Planet)
