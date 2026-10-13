--!strict
-- Cities: one per region, founded on buildable terrain. A city's development level is the sum
-- of (building level * building development); it selects the socioeconomic stage, which scales
-- the city's money, research and population.
export type Stage = {
	id: string,
	name: string,
	minimumDevelopment: number,
	money: number,
	research: number,
	population: number,
}
local stages: { Stage } = {
	{
		id = "HunterGatherer",
		name = "Hunter-Gatherer",
		minimumDevelopment = 0,
		money = 0.5,
		research = 0.5,
		population = 1,
	},
	{
		id = "HorticulturalPastoral",
		name = "Horticultural and Pastoral",
		minimumDevelopment = 12,
		money = 0.8,
		research = 0.7,
		population = 1.25,
	},
	{
		id = "Agricultural",
		name = "Agricultural",
		minimumDevelopment = 35,
		money = 1,
		research = 1,
		population = 1.5,
	},
	{
		id = "Industrial",
		name = "Industrial",
		minimumDevelopment = 110,
		money = 1.6,
		research = 1.5,
		population = 2,
	},
	{
		id = "PostIndustrial",
		name = "Post-Industrial",
		minimumDevelopment = 260,
		money = 2.5,
		research = 2.5,
		population = 2.5,
	},
}
return table.freeze({
	stages = table.freeze(stages),
	buildableTerrainIds = table.freeze({ "Land", "Forest", "Desert", "Mountains" }),
	-- Founding the n-th city (n = cities already founded) costs foundingCost * foundingGrowth^n.
	foundingCost = table.freeze({ GrowthPoints = 300 }),
	foundingGrowth = 1.8,
	-- Each city also produces this much per second before multipliers (a settlement's baseline).
	baseProduction = table.freeze({ Food = 0.5 }),
	baseHousing = 4,
})
