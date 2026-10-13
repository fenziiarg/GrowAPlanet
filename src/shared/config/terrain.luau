--!strict
export type Definition = {
	id: string,
	-- One character per region in the saved terrain string.
	code: string,
	name: string,
	color: Color3,
	material: Enum.Material,
	-- Filled by the Phase 4 terrain-to-production table; empty until then.
	productionMultipliers: { [string]: number },
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
		productionMultipliers = {},
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
