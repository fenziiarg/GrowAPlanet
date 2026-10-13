--!strict
-- Deterministic terrain from a planet seed, the planet stage and its Earth/Water Mass.
-- Pure: the server generates and saves the result; clients only receive the saved string.
local RegionTopology = require(script.Parent.RegionTopology)
local Regions = require(script.Parent.config.regions)
local Terrains = require(script.Parent.config.terrain)
local Terrain = {}
local byCode: { [string]: Terrains.Definition } = {}
for _, definition in Terrains do
	byCode[definition.code] = definition
end

-- Sum of seeded Gaussian bumps on the sphere, ranked to 0..1 so shares are exact.
local function field(
	topology: RegionTopology.Topology,
	definition: Regions.Definition,
	seed: number
): { number }
	local random = Random.new(seed)
	local bumps = {}
	for _ = 1, definition.noiseBumps do
		table.insert(bumps, {
			center = random:NextUnitVector(),
			amplitude = random:NextNumber(-1, 1),
			sharpness = random:NextNumber(
				definition.noiseSharpness.Min,
				definition.noiseSharpness.Max
			),
		})
	end
	local raw: { number } = {}
	local order: { number } = {}
	for id, direction in topology.centers do
		local value = 0
		for _, bump in bumps do
			value += bump.amplitude * math.exp(bump.sharpness * (direction:Dot(bump.center) - 1))
		end
		raw[id] = value
		order[id] = id
	end
	table.sort(order, function(a, b)
		if raw[a] == raw[b] then
			return a < b
		end
		return raw[a] < raw[b]
	end)
	local ranked: { number } = {}
	for rank, id in order do
		ranked[id] = (rank - 1) / math.max(1, #order - 1)
	end
	return ranked
end

function Terrain.oceanShare(
	definition: Regions.Definition,
	earthMass: number,
	waterMass: number
): number
	if waterMass <= 0 then
		return 0
	end
	return math.clamp(
		definition.oceanScale * waterMass / (earthMass + waterMass),
		0,
		definition.maxOcean
	)
end

-- Returns one terrain code per region. `keep` pins codes (for example developed regions).
function Terrain.generate(
	planetId: string,
	seed: number,
	stage: number,
	earthMass: number,
	waterMass: number,
	keep: { [number]: string }?
): string
	local definition = Regions[planetId]
	assert(definition ~= nil, "Unknown region definition")
	local topology = RegionTopology.get(definition.frequency)
	local rules = definition.rules
	local elevation = field(topology, definition, seed)
	local moisture = field(topology, definition, seed + 7919)
	local ocean = Terrain.oceanShare(definition, earthMass, waterMass)
	local codes: { string } = {}
	for id, direction in topology.centers do
		local e = elevation[id]
		local latitude = math.deg(math.asin(math.clamp(direction.Y, -1, 1)))
		local terrainId: string
		if stage >= 4 and math.abs(latitude) >= rules.iceLatitude then
			terrainId = "Ice" -- polar caps cover land and sea from Habitable onward
		elseif e < ocean then
			terrainId = "Ocean"
		elseif stage <= 1 then
			terrainId = "Rock"
		elseif stage == 2 then
			terrainId = if e >= 1 - rules.volcanicLavaShare then "Lava" else "Basalt"
		elseif stage == 3 then
			terrainId = if e >= 1 - rules.oceanicLavaShare then "Lava" else "Basalt"
		elseif e >= 1 - rules.mountainShare then
			terrainId = "Mountains"
		elseif
			moisture[id] <= rules.desertMoistureMax
			and math.abs(latitude) <= rules.desertLatitudeMax
		then
			terrainId = "Desert"
		elseif stage >= 5 and moisture[id] >= rules.forestMoistureMin then
			terrainId = "Forest"
		else
			terrainId = "Land"
		end
		local pinned = keep and keep[id]
		codes[id] = if pinned and byCode[pinned] then pinned else Terrains[terrainId].code
	end
	return table.concat(codes)
end

function Terrain.fromCode(code: string): Terrains.Definition?
	return byCode[code]
end

function Terrain.valid(planetId: string, terrain: any): boolean
	local definition = Regions[planetId]
	if type(terrain) ~= "string" or definition == nil or #terrain ~= definition.count then
		return false
	end
	for i = 1, #terrain do
		if byCode[string.sub(terrain, i, i)] == nil then
			return false
		end
	end
	return true
end

return table.freeze(Terrain)
