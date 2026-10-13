--!strict
export type Definition = {
	id: string,
	-- One character per region in the saved terrain string.
	code: string,
	name: string,
	color: Color3,
	material: Enum.Material,
	-- Terrain-to-production table (Phase 4 proposal). Missing resources default to 1.
	-- "Housing" scales city population. Only buildable terrains (config/cities) host cities.
	productionMultipliers: { [string]: number },
}
local PRODUCTION: { [string]: { [string]: number } } = {
	Land = { Food = 1.4, Materials = 0.9, Energy = 1, Money = 1.1, Research = 1, Housing = 1.25 },
	Forest = { Food = 1.1, Materials = 1.4, Energy = 0.9, Money = 0.9, Research = 1.1, Housing = 1 },
	Desert = { Food = 0.5, Materials = 1.1, Energy = 1.6, Money = 1, Research = 1, Housing = 0.75 },
	Mountains = {
		Food = 0.6,
		Materials = 1.7,
		Energy = 1.2,
		Money = 0.9,
		Research = 1.2,
		Housing = 0.7,
	},
}
local function terrain(
	id: string,
	code: string,
	name: string,
	color: Color3,
	material: Enum.Material
): Definition
	return {
		id = id,
		code = code,
		name = name,
		color = color,
		material = material,
		productionMultipliers = PRODUCTION[id] or {},
	}
end
local definitions: { [string]: Definition } = {
	Rock = terrain("Rock", "R", "Barren Rock", Color3.fromRGB(128, 118, 108), Enum.Material.Slate),
	Basalt = terrain(
		"Basalt",
		"B",
		"Basalt Plain",
		Color3.fromRGB(58, 50, 50),
		Enum.Material.Basalt
	),
	Lava = terrain("Lava", "V", "Lava Field", Color3.fromRGB(255, 104, 28), Enum.Material.Neon),
	Ocean = terrain(
		"Ocean",
		"O",
		"Ocean",
		Color3.fromRGB(36, 104, 186),
		Enum.Material.SmoothPlastic
	),
	Land = terrain("Land", "L", "Grassland", Color3.fromRGB(104, 168, 72), Enum.Material.Grass),
	Desert = terrain("Desert", "D", "Desert", Color3.fromRGB(222, 196, 128), Enum.Material.Sand),
	Forest = terrain("Forest", "F", "Forest", Color3.fromRGB(46, 112, 52), Enum.Material.Grass),
	Mountains = terrain(
		"Mountains",
		"M",
		"Mountains",
		Color3.fromRGB(122, 108, 96),
		Enum.Material.Rock
	),
	Ice = terrain("Ice", "I", "Ice Sheet", Color3.fromRGB(236, 246, 255), Enum.Material.Glacier),
}
return table.freeze(definitions)
