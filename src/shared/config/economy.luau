--!strict
export type ResourceId =
	"GrowthPoints"
	| "Population"
	| "Food"
	| "Materials"
	| "Energy"
	| "Money"
	| "Research"
local ids: { ResourceId } =
	{ "GrowthPoints", "Population", "Food", "Materials", "Energy", "Money", "Research" }
local initial: { [string]: number } = {}
local rates: { [string]: number } = {}
for _, id in ids do
	initial[id] = 0
	rates[id] = 0
end
rates.GrowthPoints = 1
return table.freeze({
	resourceIds = table.freeze(ids),
	initial = table.freeze(initial),
	productionPerSecond = table.freeze(rates),
	clickGrowth = 1,
	clicksPerSecond = 8,
	clickBurst = 8,
	-- City, building, age, upgrade and Kardashev purchases share one action rate limit.
	actionsPerSecond = 6,
	actionBurst = 10,
	-- Offline income: production at logout, credited for at most offlineCapSeconds at this rate.
	offlineCapSeconds = 8 * 3600,
	offlineEfficiency = 0.5,
	-- Bot pacing runs (Studio debug simulate) may cover more time than a live time-skip.
	maxBotSeconds = 12 * 3600,
	growthPerSecond = 6,
	growthBurst = 10,
	requestsPerSecond = 12,
	requestBurst = 16,
	snapshotInterval = 0.25,
	tickInterval = 0.1,
	logInterval = 5,
	maxSimulationSeconds = 3600,
})
