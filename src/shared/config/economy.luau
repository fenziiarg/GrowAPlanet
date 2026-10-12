--!strict
export type ResourceId =
	"Population"
	| "Food"
	| "Materials"
	| "Energy"
	| "Money"
	| "Research"
	| "GrowthPoints"
export type ResourceAmounts = { [ResourceId]: number }
export type Definition = {
	initialResources: ResourceAmounts,
	clickGrowth: number,
	clicksPerSecond: number,
	offlineCapSeconds: number,
}

-- Intentionally unpopulated in Phase 0. No economy is active.
local definitions: { [string]: Definition } = {}
return table.freeze(definitions)
