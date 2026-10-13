--!strict
-- HOI4-style strategic camera around the planet. Orientation is a free rotation (trackball):
-- drags rotate about the camera's own axes, so passing over the poles never gimbal-locks.
-- Zoom is a 0..1 log-space fraction between radius multiples, so framing adapts to planet size.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Config = require(Shared.config.camera)
local Janitor = require(Shared.Janitor)
export type Camera = {
	-- Immediate state changes (used by focus animations' end state and development tests).
	setRotation: (rotation: CFrame) -> (),
	getRotation: () -> CFrame,
	setZoom: (zoom: number, immediate: boolean?) -> (),
	getZoom: () -> number,
	-- Turn the camera so `direction` (unit, planet space) faces the viewer.
	focus: (direction: Vector3, immediate: boolean?) -> (),
	-- Called with (screenPosition, isTouch) when a press-release did not drag.
	onTap: (callback: (position: Vector2, viewport: boolean) -> ()) -> (),
	destroy: () -> (),
}
local StrategicCamera = {}
-- Keys move the view (camera) in their direction, the same as dragging the map the other way.
local ROTATE_KEYS: { [Enum.KeyCode]: Vector2 } = {
	[Enum.KeyCode.A] = Vector2.new(1, 0),
	[Enum.KeyCode.Left] = Vector2.new(1, 0),
	[Enum.KeyCode.D] = Vector2.new(-1, 0),
	[Enum.KeyCode.Right] = Vector2.new(-1, 0),
	[Enum.KeyCode.W] = Vector2.new(0, 1),
	[Enum.KeyCode.Up] = Vector2.new(0, 1),
	[Enum.KeyCode.S] = Vector2.new(0, -1),
	[Enum.KeyCode.Down] = Vector2.new(0, -1),
}
local ZOOM_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.E] = -1,
	[Enum.KeyCode.Equals] = -1,
	[Enum.KeyCode.KeypadPlus] = -1,
	[Enum.KeyCode.Q] = 1,
	[Enum.KeyCode.Minus] = 1,
	[Enum.KeyCode.KeypadMinus] = 1,
}

local function orthonormal(rotation: CFrame): CFrame
	return rotation.Rotation:Orthonormalize()
end

function StrategicCamera.new(center: () -> Vector3, radius: () -> number): Camera
	local janitor = Janitor.new()
	local camera = workspace.CurrentCamera
	local lighting = game:GetService("Lighting")
	local previousAmbient, previousOutdoor = lighting.Ambient, lighting.OutdoorAmbient
	lighting.Ambient = Config.ambient
	lighting.OutdoorAmbient = Config.outdoorAmbient
	janitor.add(function()
		lighting.Ambient = previousAmbient
		lighting.OutdoorAmbient = previousOutdoor
	end)
	local rotation = CFrame.new()
	local targetRotation = rotation
	local zoom = Config.initialZoom
	local targetZoom = zoom
	local tapCallbacks: { (Vector2, boolean) -> () } = {}
	-- Active pointer drag: start position, last position, travelled distance, whether it is touch.
	local drag: { last: Vector2, travelled: number, touch: boolean, input: InputObject? }? = nil
	local pinching = false
	local pinchScale = 1

	local function distance(fraction: number): number
		local r = radius()
		local low, high = math.log(Config.minDistance * r), math.log(Config.maxDistance * r)
		return math.exp(low + (high - low) * fraction)
	end
	-- Rotation per pixel shrinks near the surface so a drag moves the map at a steady visual pace.
	local function radiansPerPixel(): number
		local r = radius()
		local height = (distance(zoom) - r) / ((Config.maxDistance - 1) * r)
		return Config.dragRadiansPerPixel * math.clamp(height, 0.08, 1)
	end
	local function rotateBy(pixels: Vector2)
		local angle = radiansPerPixel()
		-- Post-multiplying rotates about the camera's current local axes (no fixed world up).
		targetRotation = orthonormal(
			targetRotation
				* CFrame.fromAxisAngle(Vector3.yAxis, -pixels.X * angle)
				* CFrame.fromAxisAngle(Vector3.xAxis, -pixels.Y * angle)
		)
	end
	local function setZoomTarget(value: number)
		targetZoom = math.clamp(value, 0, 1)
	end

	local function render(dt: number)
		local step = math.min(dt, 0.1)
		for key, direction in ROTATE_KEYS do
			if UserInputService:IsKeyDown(key) and not UserInputService:GetFocusedTextBox() then
				rotateBy(direction * Config.keyRadiansPerSecond * step / radiansPerPixel())
			end
		end
		for key, direction in ZOOM_KEYS do
			if UserInputService:IsKeyDown(key) and not UserInputService:GetFocusedTextBox() then
				setZoomTarget(targetZoom + direction * Config.keyZoomPerSecond * step)
			end
		end
		zoom += (targetZoom - zoom) * (1 - math.exp(-Config.zoomSmoothing * step))
		rotation =
			orthonormal(rotation:Lerp(targetRotation, 1 - math.exp(-Config.rotateSmoothing * step)))
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = Config.fieldOfView
		camera.CFrame = CFrame.new(center()) * rotation * CFrame.new(0, 0, distance(zoom))
	end
	RunService:BindToRenderStep("GrowAPlanetCamera", Enum.RenderPriority.Camera.Value, render)
	janitor.add(function()
		RunService:UnbindFromRenderStep("GrowAPlanetCamera")
	end)

	local function finishDrag(position: Vector2, viewport: boolean)
		local current = drag
		drag = nil
		if current and current.travelled <= Config.clickSlop and not pinching then
			for _, callback in tapCallbacks do
				callback(position, viewport)
			end
		end
	end
	local began = UserInputService.InputBegan:Connect(
		function(input: InputObject, processed: boolean)
			if processed then
				return
			end
			local kind = input.UserInputType
			if
				kind == Enum.UserInputType.MouseButton1
				or kind == Enum.UserInputType.MouseButton2
			then
				drag = {
					last = UserInputService:GetMouseLocation(),
					travelled = 0,
					touch = false,
					input = nil,
				}
			elseif kind == Enum.UserInputType.Touch and drag == nil then
				drag = {
					last = Vector2.new(input.Position.X, input.Position.Y),
					travelled = 0,
					touch = true,
					input = input,
				}
			end
		end
	)
	local changed = UserInputService.InputChanged:Connect(
		function(input: InputObject, processed: boolean)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseWheel then
				if not processed then
					setZoomTarget(targetZoom - input.Position.Z * Config.wheelStep)
				end
				return
			end
			local current = drag
			if current == nil or pinching then
				return
			end
			local position: Vector2
			if kind == Enum.UserInputType.MouseMovement and not current.touch then
				position = UserInputService:GetMouseLocation()
			elseif kind == Enum.UserInputType.Touch and current.input == input then
				position = Vector2.new(input.Position.X, input.Position.Y)
			else
				return
			end
			local delta = position - current.last
			current.last = position
			current.travelled += delta.Magnitude
			if current.travelled > Config.clickSlop then
				rotateBy(delta)
			end
		end
	)
	local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		local current = drag
		if current == nil then
			return
		end
		if
			(kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2)
			and not current.touch
		then
			-- Only the primary button selects; the secondary button only rotates.
			if kind == Enum.UserInputType.MouseButton1 then
				finishDrag(UserInputService:GetMouseLocation(), true)
			else
				drag = nil
			end
		elseif kind == Enum.UserInputType.Touch and current.input == input then
			finishDrag(Vector2.new(input.Position.X, input.Position.Y), false)
			pinching = false
		end
	end)
	local pinch = UserInputService.TouchPinch:Connect(
		function(
			_positions: { Vector2 },
			scale: number,
			_velocity: number,
			state: Enum.UserInputState,
			processed: boolean
		)
			if processed then
				return
			end
			if state == Enum.UserInputState.Begin then
				pinching = true
				pinchScale = math.max(scale, 1e-3)
			elseif state == Enum.UserInputState.Change and scale > 0 then
				-- `scale` is cumulative for the gesture; zoom by the change since the last event.
				setZoomTarget(targetZoom - math.log(scale / pinchScale) * Config.pinchSensitivity)
				pinchScale = scale
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				pinching = false
			end
		end
	)
	janitor.add(function()
		began:Disconnect()
		changed:Disconnect()
		ended:Disconnect()
		pinch:Disconnect()
	end)

	local api = {}
	function api.setRotation(value: CFrame)
		rotation = orthonormal(value)
		targetRotation = rotation
	end
	function api.getRotation(): CFrame
		return rotation
	end
	function api.setZoom(value: number, immediate: boolean?)
		setZoomTarget(value)
		if immediate then
			zoom = targetZoom
		end
	end
	function api.getZoom(): number
		return zoom
	end
	function api.focus(direction: Vector3, immediate: boolean?)
		local up = targetRotation.UpVector
		if math.abs(up:Dot(direction)) > 0.99 then
			up = targetRotation.LookVector
		end
		-- The camera sits on the +Z side of its rotation, so ZVector must point along `direction`.
		local goal = CFrame.lookAt(Vector3.zero, -direction, up).Rotation
		targetRotation = goal
		if immediate then
			rotation = goal
			render(0)
		end
	end
	function api.onTap(callback: (Vector2, boolean) -> ())
		table.insert(tapCallbacks, callback)
	end
	api.destroy = janitor.cleanup
	render(0)
	return api :: Camera
end

return table.freeze(StrategicCamera)
