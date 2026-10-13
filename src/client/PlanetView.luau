--!strict
-- Renders the local player's planet as one model driven by its attributes and region terrain:
-- Stage rebuilds the stage layers, TotalSize scales the whole model, Terrain recolours regions.
-- The surface is the real region map: each region is a Model of flat triangles (two wedges each).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Planet = require(Shared.Planet)
local RegionTopology = require(Shared.RegionTopology)
local Terrain = require(Shared.Terrain)
local PlanetConfig = require(Shared.config.planet)
local Regions = require(Shared.config.regions)
local Janitor = require(Shared.Janitor)
export type View = {
	model: Model,
	regionsFolder: Folder,
	topology: RegionTopology.Topology,
	regionAt: (part: Instance) -> number?,
	regionModel: (id: number) -> Model?,
	terrainOf: (id: number) -> string?,
	-- World-space radius and centre of the current planet.
	radius: () -> number,
	center: () -> Vector3,
	destroy: () -> (),
}
local PlanetView = {}
local THICKNESS = 0.02 -- of the model radius
local BORDER_LIFT = 1.004
local BORDER_COLOR = Color3.fromRGB(20, 26, 30)

local function directions(count: number, seed: number): { Vector3 }
	local random = Random.new(seed)
	local result = {}
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 0, count - 1 do
		local y = 1 - (i + 0.5) / count * 2
		local ring = math.sqrt(1 - y * y)
		local theta = golden * i + random:NextNumber(-0.4, 0.4)
		table.insert(result, Vector3.new(math.cos(theta) * ring, y, math.sin(theta) * ring).Unit)
	end
	return result
end
local CLOUDS = directions(30, 37)

local function decorate(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

-- Flat triangle a-b-c from two WedgeParts, outer face flush with the triangle plane.
local function triangle(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	outward: Vector3,
	thickness: number
)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local inset = -outward * thickness / 2
	for side = 1, 2 do
		local wedge = Instance.new("WedgePart")
		decorate(wedge)
		wedge.CanQuery = true
		if side == 1 then
			wedge.Size = Vector3.new(thickness, height, math.abs(ab:Dot(back)))
			wedge.CFrame = CFrame.fromMatrix((a + b) / 2 + inset, right, up, back)
		else
			wedge.Size = Vector3.new(thickness, height, math.abs(ac:Dot(back)))
			wedge.CFrame = CFrame.fromMatrix((a + c) / 2 + inset, -right, up, -back)
		end
		wedge.Parent = parent
	end
end

local function ball(
	parent: Instance,
	name: string,
	center: Vector3,
	radius: number,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	decorate(part)
	part.CanQuery = false
	part.Size = Vector3.one * radius * 2
	part.CFrame = CFrame.new(center)
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

function PlanetView.new(parent: Instance, planetId: string): View
	local definition = Planet.definition(planetId)
	local regionDefinition = Regions[planetId]
	local topology = RegionTopology.get(regionDefinition.frequency)
	local origin = definition.viewCenter
	local R = definition.modelRadius
	local janitor = Janitor.new()
	local model = Instance.new("Model")
	model.Name = "HomePlanet"
	model.WorldPivot = CFrame.new(origin)
	janitor.add(function()
		model:Destroy()
	end)

	-- Border lines live on an invisible anchor part so they follow the model's pivot.
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	decorate(anchor)
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(origin)
	anchor.Parent = model
	local borders = Instance.new("WireframeHandleAdornment")
	borders.Name = "Borders"
	borders.Color3 = BORDER_COLOR
	borders.Transparency = 0.15
	borders.AlwaysOnTop = false
	borders.Adornee = anchor
	borders.Parent = anchor

	local regionsFolder = Instance.new("Folder")
	regionsFolder.Name = "Regions"
	regionsFolder.Parent = model
	local regionByPart: { [Instance]: number } = {}
	local regionModels: { Model } = {}
	local codes: { string } = {}
	for id, ring in topology.cells do
		local region = Instance.new("Model")
		region.Name = "Region_" .. id
		region:SetAttribute("RegionId", id)
		local outward = topology.centers[id]
		local first = origin + topology.corners[ring[1]] * R
		for k = 2, #ring - 1 do
			local b = origin + topology.corners[ring[k]] * R
			local c = origin + topology.corners[ring[k + 1]] * R
			triangle(region, first, b, c, outward, R * THICKNESS)
		end
		for _, part in region:GetChildren() do
			regionByPart[part] = id
		end
		region.Parent = regionsFolder
		regionModels[id] = region
	end
	local layers = Instance.new("Folder")
	layers.Name = "Layers"
	layers.Parent = model
	model.Parent = parent

	local scale = 1
	local currentStage = 0
	local function drawBorders()
		borders:Clear()
		local points: { Vector3 } = {}
		for _, edge in topology.edges do
			table.insert(points, topology.corners[edge[1]] * R * scale * BORDER_LIFT)
			table.insert(points, topology.corners[edge[2]] * R * scale * BORDER_LIFT)
		end
		borders:AddLines(points)
	end
	local function applyTerrain()
		local terrain = model:GetAttribute("Terrain")
		if type(terrain) ~= "string" or #terrain ~= topology.count then
			return
		end
		for id, region in regionModels do
			local code = string.sub(terrain, id, id)
			if codes[id] ~= code then
				local look = Terrain.fromCode(code)
				if look then
					codes[id] = code
					for _, part in region:GetChildren() do
						local wedge = part :: BasePart
						wedge.Color = look.color
						wedge.Material = look.material
						wedge.Reflectance = if code == "O" then 0.06 else 0
					end
				end
			end
		end
	end
	-- Stage layers (atmosphere, clouds) are built at unit scale and never take raycasts.
	local function buildLayers(look: PlanetConfig.Look)
		layers:ClearAllChildren()
		local center = model:GetPivot().Position
		local current = R * scale
		if look.clouds then
			local random = Random.new(41)
			for i, direction in CLOUDS do
				local width = current * (0.3 + (i % 3) * 0.1)
				local at = center + direction * current * 1.06
				local cloud = Instance.new("Part")
				cloud.Name = "Cloud"
				decorate(cloud)
				cloud.CanQuery = false
				cloud.Color = Color3.new(1, 1, 1)
				cloud.Material = Enum.Material.SmoothPlastic
				cloud.Transparency = 0.18
				cloud.Size = Vector3.new(width, width * 0.45, current * 0.02)
				cloud.CFrame = CFrame.lookAt(at, at + direction)
					* CFrame.Angles(0, 0, random:NextNumber(0, math.pi))
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = cloud
				cloud.Parent = layers
			end
		end
		if look.atmosphereColor then
			ball(
				layers,
				"Atmosphere",
				center,
				current * 1.12,
				look.atmosphereColor,
				Enum.Material.ForceField
			)
		end
	end
	local function applyStage()
		local stage = model:GetAttribute("Stage")
		if type(stage) ~= "number" or definition.stages[stage] == nil or stage == currentStage then
			return
		end
		currentStage = stage
		buildLayers(definition.stages[stage].look)
	end
	local function applySize()
		local size = model:GetAttribute("TotalSize")
		if type(size) ~= "number" or size <= 0 then
			return
		end
		local target = size * definition.studsPerKm / R
		if math.abs(target - scale) < 1e-6 then
			return
		end
		model:ScaleTo(target)
		scale = target
		drawBorders()
	end
	drawBorders()
	local changed = model.AttributeChanged:Connect(function(name: string)
		if name == "TotalSize" then
			applySize()
		elseif name == "Stage" then
			applyStage()
		elseif name == "Terrain" then
			applyTerrain()
		end
	end)
	janitor.add(function()
		changed:Disconnect()
	end)

	return {
		model = model,
		regionsFolder = regionsFolder,
		topology = topology,
		regionAt = function(part: Instance): number?
			return regionByPart[part]
		end,
		regionModel = function(id: number): Model?
			return regionModels[id]
		end,
		terrainOf = function(id: number): string?
			local code = codes[id]
			local look = code and Terrain.fromCode(code)
			return if look then look.name else nil
		end,
		radius = function(): number
			return R * scale
		end,
		center = function(): Vector3
			return model:GetPivot().Position
		end,
		destroy = janitor.cleanup,
	}
end

return table.freeze(PlanetView)
