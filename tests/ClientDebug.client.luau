--!strict
-- Studio-only client test bridge (development mapping only). Exposes the live camera and picker
-- through a client-side BindableFunction so Studio MCP scripts can run region tests.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local RegionTopology = require(Shared.RegionTopology)
local client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("GrowAPlanet")
local Registry = require(client:WaitForChild("ClientRegistry")) :: any
while Registry.picker == nil do
	task.wait(0.1)
end
local view, camera, picker = Registry.view, Registry.camera, Registry.picker
local topology = view.topology

-- Independent expectation: intersect the view ray with the planet sphere, then take the
-- region whose centre is nearest (spherical Voronoi owner). `margin` is the dot-product gap
-- to the runner-up; small margins sit on a border where flat facets may legitimately differ.
local function expected(ray: Ray): (number?, number)
	local center, radius = view.center(), view.radius()
	local origin = ray.Origin - center
	local direction = ray.Direction.Unit
	local b = origin:Dot(direction)
	local c = origin:Dot(origin) - radius * radius
	local discriminant = b * b - c
	if discriminant < 0 then
		return nil, 0
	end
	local hit = (origin + direction * (-b - math.sqrt(discriminant))).Unit
	local best, second, bestId = -math.huge, -math.huge, nil
	for id, regionCenter in topology.centers do
		local d = regionCenter:Dot(hit)
		if d > best then
			second, best, bestId = best, d, id
		elseif d > second then
			second = d
		end
	end
	return bestId, best - second
end

local commands: { [string]: (...any) -> any } = {}
function commands.State(): any
	local viewport = workspace.CurrentCamera.ViewportSize
	return {
		zoom = camera.getZoom(),
		look = tostring(camera.getRotation().LookVector),
		radius = view.radius(),
		hovered = picker.hovered(),
		selected = picker.selected(),
		viewport = { viewport.X, viewport.Y },
		regions = topology.count,
		parts = #view.regionsFolder:GetDescendants(),
	}
end
function commands.Focus(id: number, zoom: number): boolean
	camera.setZoom(zoom, true)
	camera.focus(topology.centers[id], true)
	return true
end
function commands.Pick(x: number, y: number): any
	local ray = workspace.CurrentCamera:ViewportPointToRay(x, y)
	local want, margin = expected(ray)
	return { picked = picker.pickViewport(Vector2.new(x, y)), expected = want, margin = margin }
end
-- Visible region centres projected to viewport pixels, for choosing click targets.
function commands.Targets(limit: number): any
	local cam = workspace.CurrentCamera
	local result = {}
	for id, direction in topology.centers do
		local world = view.center() + direction * view.radius()
		local toCamera = (cam.CFrame.Position - world).Unit
		if direction:Dot(toCamera) > 0.45 then
			local point, onScreen = cam:WorldToViewportPoint(world)
			if onScreen then
				table.insert(
					result,
					{ id = id, x = math.floor(point.X + 0.5), y = math.floor(point.Y + 0.5) }
				)
			end
		end
	end
	table.sort(result, function(a, b)
		return a.id < b.id
	end)
	local picked = {}
	local stride = math.max(1, math.floor(#result / limit))
	for i = 1, #result, stride do
		table.insert(picked, result[i])
		if #picked >= limit then
			break
		end
	end
	return picked
end
-- Every region: turn the camera to face it and raycast through the screen centre.
function commands.Reachability(zoom: number): any
	local cam = workspace.CurrentCamera
	local failures = {}
	for id, direction in topology.centers do
		camera.setZoom(zoom, true)
		camera.focus(direction, true)
		local size = cam.ViewportSize
		local got = picker.pickViewport(Vector2.new(size.X / 2, size.Y / 2))
		if got ~= id then
			table.insert(failures, { id = id, got = got })
		end
	end
	local poles = {
		north = RegionTopology.nearest(topology, Vector3.yAxis),
		south = RegionTopology.nearest(topology, -Vector3.yAxis),
	}
	return {
		regions = topology.count,
		reached = topology.count - #failures,
		failures = failures,
		poles = poles,
	}
end
-- Random directions: a ray from outside toward the centre must hit a region (no gaps), and the
-- region must be that direction's Voronoi owner except within `borderMargin` of a border.
function commands.Coverage(samples: number, borderMargin: number): any
	local random = Random.new(2026)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { view.regionsFolder }
	local center, radius = view.center(), view.radius()
	local misses, mismatches, borderMismatches = 0, 0, 0
	for _ = 1, samples do
		local direction = random:NextUnitVector()
		local origin = center + direction * radius * 3
		local result = workspace:Raycast(origin, -direction * radius * 3, params)
		local got = result and view.regionAt(result.Instance)
		if got == nil then
			misses += 1
		else
			local best, second, bestId = -math.huge, -math.huge, nil
			for id, regionCenter in topology.centers do
				local d = regionCenter:Dot(direction)
				if d > best then
					second, best, bestId = best, d, id
				elseif d > second then
					second = d
				end
			end
			if got ~= bestId then
				if best - second < borderMargin then
					borderMismatches += 1
				else
					mismatches += 1
				end
			end
		end
	end
	return {
		samples = samples,
		misses = misses,
		mismatches = mismatches,
		borderMismatches = borderMismatches,
	}
end
-- Pin the camera at a fixed world pose (after the strategic camera's step) for same-camera
-- comparison screenshots; Unfreeze returns control to the strategic camera.
local FREEZE = "GrowAPlanetTestFreeze"
function commands.Freeze(position: Vector3, lookAt: Vector3): boolean
	RunService:UnbindFromRenderStep(FREEZE)
	RunService:BindToRenderStep(FREEZE, Enum.RenderPriority.Camera.Value + 1, function()
		workspace.CurrentCamera.CFrame = CFrame.lookAt(position, lookAt)
	end)
	return true
end
function commands.Unfreeze(): boolean
	RunService:UnbindFromRenderStep(FREEZE)
	return true
end
-- Average and worst frame time while the camera spins continuously.
function commands.Fps(seconds: number): any
	local times = {}
	local spinning = true
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		table.insert(times, dt)
	end)
	task.spawn(function()
		while spinning do
			camera.setRotation(
				camera.getRotation() * CFrame.fromAxisAngle(Vector3.new(0.3, 1, 0.2).Unit, 0.02)
			)
			RunService.RenderStepped:Wait()
		end
	end)
	task.wait(seconds)
	spinning = false
	connection:Disconnect()
	table.sort(times)
	local total = 0
	for _, dt in times do
		total += dt
	end
	return {
		frames = #times,
		averageFps = #times / total,
		p95FrameMs = times[math.max(1, math.floor(#times * 0.95))] * 1000,
		worstFrameMs = times[#times] * 1000,
	}
end

local bridge = Instance.new("BindableFunction")
bridge.Name = "GrowAPlanetClientControl"
bridge.OnInvoke = function(command: string, ...: any): any
	local handler = commands[command]
	assert(handler ~= nil, "Unknown client command")
	return handler(...)
end
bridge.Parent = ReplicatedStorage
