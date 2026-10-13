--!strict
local Big = require(script.Parent.BigNumber)
local Config = require(script.Parent.config.economy)
export type Balances = { [string]: Big.Value }
local Economy = {}
function Economy.initial(): Balances
	local result: Balances = {}
	for _, id in Config.resourceIds do
		result[id] = Big.new(Config.initial[id])
	end
	return result
end
-- Compute a new table first: overflow cannot partially reward a player.
function Economy.advance(
	balances: Balances,
	seconds: number,
	rates: { [string]: number }?
): Balances
	assert(seconds == seconds and seconds >= 0 and seconds < math.huge, "Invalid elapsed time")
	local perSecond = rates or Config.productionPerSecond
	local result: Balances = {}
	for _, id in Config.resourceIds do
		result[id] = Big.add(balances[id], Big.scale(Big.new(perSecond[id]), seconds))
	end
	return result
end
function Economy.click(balances: Balances): Balances
	local result = table.clone(balances)
	result.GrowthPoints = Big.add(balances.GrowthPoints, Big.new(Config.clickGrowth))
	return result
end
return table.freeze(Economy)
