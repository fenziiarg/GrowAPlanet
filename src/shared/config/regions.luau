--!strict
export type RegionId = number
export type State = { terrainId: string, population: number, buildingLevels: { [string]: number } }
export type Definition = {
	-- Goldberg-polyhedron frequency: count = 10 * frequency^2 + 2 hexagonal/pentagonal regions.
	frequency: number,
	count: number,
	-- Bump when frequency or ID ordering changes; saved region data must then be migrated.
	topologyVersion: number,
	-- Elevation/moisture noise: number of seeded Gaussian bumps and their sharpness range.
	noiseBumps: number,
	noiseSharpness: NumberRange,
	-- Ocean share of regions = clamp(oceanScale * Water / (Earth + Water), 0, maxOcean).
	oceanScale: number,
	maxOcean: number,
	rules: TerrainRules,
}
-- Shares are fractions of all regions, chosen by rank so coverage is exact and seed-independent.
export type TerrainRules = {
	volcanicLavaShare: number,
	oceanicLavaShare: number,
	mountainShare: number,
	iceLatitude: number,
	desertMoistureMax: number,
	desertLatitudeMax: number,
	forestMoistureMin: number,
}
local definitions: { [string]: Definition } = {
	home = {
		frequency = 5,
		count = 252,
		topologyVersion = 1,
		noiseBumps = 28,
		noiseSharpness = NumberRange.new(2.5, 9),
		oceanScale = 2,
		maxOcean = 0.62,
		rules = {
			volcanicLavaShare = 0.18,
			oceanicLavaShare = 0.05,
			mountainShare = 0.1,
			iceLatitude = 66,
			desertMoistureMax = 0.3,
			desertLatitudeMax = 38,
			forestMoistureMin = 0.62,
		},
	},
}
return table.freeze(definitions)
