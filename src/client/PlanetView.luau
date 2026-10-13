--!strict
-- Renders the local player's planet as one model driven by its attributes:
-- Stage rebuilds the stage look; TotalSize scales the whole model. Values come from the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Planet = require(Shared.Planet)
local PlanetConfig = require(Shared.config.planet)
local Janitor = require(Shared.Janitor)
export type View = { model: Model, destroy: () -> () }
local PlanetView = {}

-- Deterministic, evenly spread unit directions (Fibonacci sphere with a fixed seeded jitter).
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
local LAND = directions(14, 11)
local SPOTS = directions(22, 23)
local CLOUDS = directions(30, 37)

local function ball(
	model: Model,
	name: string,
	center: Vector3,
	radius: number,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = Vector3.one * radius * 2
	part.CFrame = CFrame.new(center)
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Builds a stage look at unit scale (model radius R) around the model pivot.
local function build(model: Model, origin: Vector3, look: PlanetConfig.Look, radius: number)
	local R = radius
	ball(model, "Core", origin, R, look.coreColor, look.coreMaterial)
	if look.craters then
		for i, direction in SPOTS do
			if i % 2 == 0 then
				local size = R * (0.12 + (i % 5) * 0.03)
				ball(
					model,
					"Crater",
					origin + direction * (R - size * 0.8),
					size,
					Color3.fromRGB(84, 78, 74),
					Enum.Material.Slate
				)
			end
		end
	end
	if look.oceanLevel then
		local ocean = ball(
			model,
			"Ocean",
			origin,
			R * look.oceanLevel,
			look.oceanColor,
			Enum.Material.SmoothPlastic
		)
		ocean.Reflectance = 0.08
	end
	if look.landHeight then
		for i, direction in LAND do
			local size = R * (0.45 + (i % 4) * 0.12)
			ball(
				model,
				"Land",
				origin + direction * (R * look.landHeight - size),
				size,
				look.landColor,
				look.landMaterial
			)
		end
	end
	if look.lava then
		for i, direction in SPOTS do
			local size = R * (0.05 + (i % 3) * 0.025)
			ball(
				model,
				"Lava",
				origin + direction * (R * 1.01 - size * 0.5),
				size,
				Color3.fromRGB(255, 110, 30),
				Enum.Material.Neon
			)
		end
	end
	if look.ice then
		local top = R * (look.landHeight or 1) + R * 0.01
		for _, sign in { 1, -1 } do
			local size = R * 0.42
			ball(
				model,
				"Ice",
				origin + Vector3.yAxis * sign * (top - size),
				size,
				Color3.fromRGB(240, 248, 255),
				Enum.Material.Glacier
			)
		end
	end
	if look.clouds then
		-- Flattened ellipsoid sheets lying tangent to the surface (a sphere mesh fitted to a block).
		local random = Random.new(41)
		for i, direction in CLOUDS do
			local width = R * (0.34 + (i % 3) * 0.12)
			local center = origin + direction * R * 1.12
			local cloud = Instance.new("Part")
			cloud.Name = "Cloud"
			cloud.Anchored = true
			cloud.CanCollide = false
			cloud.CanTouch = false
			cloud.CanQuery = false
			cloud.CastShadow = false
			cloud.Color = Color3.new(1, 1, 1)
			cloud.Material = Enum.Material.SmoothPlastic
			cloud.Transparency = 0.12
			cloud.Size = Vector3.new(width, width * 0.45, R * 0.035)
			cloud.CFrame = CFrame.lookAt(center, center + direction)
				* CFrame.Angles(0, 0, random:NextNumber(0, math.pi))
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = cloud
			cloud.Parent = model
		end
	end
	if look.atmosphereColor then
		ball(model, "Atmosphere", origin, R * 1.17, look.atmosphereColor, Enum.Material.ForceField)
	end
end

function PlanetView.new(parent: Instance, planetId: string): View
	local definition = Planet.definition(planetId)
	local janitor = Janitor.new()
	local model = Instance.new("Model")
	model.Name = "HomePlanet"
	model.WorldPivot = CFrame.new(definition.viewCenter)
	model.Parent = parent
	janitor.add(function()
		model:Destroy()
	end)
	local scale = Instance.new("NumberValue")
	scale.Value = 1
	local currentStage = 0
	local tween: Tween? = nil

	local function targetScale(): number
		local size = model:GetAttribute("TotalSize")
		if type(size) ~= "number" or size <= 0 then
			return 1
		end
		return size * definition.studsPerKm / definition.modelRadius
	end
	local function rebuild(stage: number)
		local look = definition.stages[stage].look
		model:ScaleTo(1)
		model:ClearAllChildren()
		build(model, definition.viewCenter, look, definition.modelRadius)
		model:ScaleTo(math.max(scale.Value, 0.01))
		currentStage = stage
	end
	local scaled = scale.Changed:Connect(function(value: number)
		if currentStage > 0 then
			model:ScaleTo(math.max(value, 0.01))
		end
	end)
	janitor.add(function()
		scaled:Disconnect()
		if tween then
			tween:Cancel()
		end
		scale:Destroy()
	end)
	local function apply()
		local stage = model:GetAttribute("Stage")
		if type(stage) ~= "number" or definition.stages[stage] == nil then
			return
		end
		if stage ~= currentStage then
			if tween then
				tween:Cancel()
			end
			scale.Value = targetScale()
			rebuild(stage)
			return
		end
		if tween then
			tween:Cancel()
		end
		tween = TweenService:Create(
			scale,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad),
			{ Value = targetScale() }
		);
		(tween :: Tween):Play()
	end
	local changed = model.AttributeChanged:Connect(function(name: string)
		if name == "Stage" or name == "TotalSize" then
			apply()
		end
	end)
	janitor.add(function()
		changed:Disconnect()
	end)
	return { model = model, destroy = janitor.cleanup }
end

return table.freeze(PlanetView)
