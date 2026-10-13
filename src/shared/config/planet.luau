--!strict
-- Stage-wide layers drawn above the region surface; terrain colours live in config/terrain.
export type Look = {
	clouds: boolean,
	atmosphereColor: Color3?,
}
export type Stage = {
	id: string,
	name: string,
	minimumEarthMass: number,
	minimumWaterMass: number,
	look: Look,
}
export type Growth = {
	id: string,
	label: string,
	baseCost: number,
	costGrowth: number,
	massPerLevel: number,
	-- Extra Growth Points per second for each level bought.
	incomePerLevel: number,
	-- Stage index (1-based) required before this growth can be bought.
	unlockStage: number,
}
export type Definition = {
	id: string,
	stages: { Stage },
	growth: { Earth: Growth, Water: Growth },
	growthIds: { string },
	maxLevel: number,
	baseSizeKm: number,
	-- Total Size = baseSizeKm * (1 + (Earth Mass + Water Mass) / sizeMassStep) ^ (1/3).
	sizeMassStep: number,
	studsPerKm: number,
	modelRadius: number,
	viewCenter: Vector3,
}

local definitions: { [string]: Definition } = {
	home = {
		id = "home",
		maxLevel = 1000,
		baseSizeKm = 1000,
		sizeMassStep = 100,
		studsPerKm = 0.02,
		modelRadius = 50,
		viewCenter = Vector3.new(0, 2000, 0),
		growthIds = { "Earth", "Water" },
		growth = {
			Earth = {
				id = "Earth",
				label = "Earth",
				baseCost = 10,
				costGrowth = 1.18,
				massPerLevel = 100,
				incomePerLevel = 1,
				unlockStage = 1,
			},
			Water = {
				id = "Water",
				label = "Water",
				baseCost = 20,
				costGrowth = 1.18,
				massPerLevel = 100,
				incomePerLevel = 1,
				unlockStage = 2,
			},
		},
		stages = {
			{
				id = "BarrenRock",
				name = "Barren Rock",
				minimumEarthMass = 0,
				minimumWaterMass = 0,
				look = {
					clouds = false,
				},
			},
			{
				id = "Volcanic",
				name = "Volcanic",
				minimumEarthMass = 800,
				minimumWaterMass = 0,
				look = {
					clouds = false,
					atmosphereColor = Color3.fromRGB(255, 120, 60),
				},
			},
			{
				id = "Oceanic",
				name = "Oceanic",
				minimumEarthMass = 1600,
				minimumWaterMass = 600,
				look = {
					clouds = false,
					atmosphereColor = Color3.fromRGB(150, 190, 230),
				},
			},
			{
				id = "Habitable",
				name = "Habitable",
				minimumEarthMass = 2600,
				minimumWaterMass = 1400,
				look = {
					clouds = false,
					atmosphereColor = Color3.fromRGB(130, 190, 255),
				},
			},
			{
				id = "MatureWorld",
				name = "Mature World",
				minimumEarthMass = 4200,
				minimumWaterMass = 2800,
				look = {
					clouds = true,
					atmosphereColor = Color3.fromRGB(120, 200, 255),
				},
			},
		},
	},
}
return table.freeze(definitions)
