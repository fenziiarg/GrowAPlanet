--!strict
-- Hover and selection by a real raycast onto the region surface. One ray per frame at most,
-- filtered to region parts, then an indexed part -> region lookup. No per-frame region scans.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Janitor = require(Shared.Janitor)
local PlanetView = require(script.Parent.PlanetView)
local StrategicCamera = require(script.Parent.StrategicCamera)
export type Picker = {
	pickViewport: (position: Vector2) -> number?,
	pickScreen: (position: Vector2) -> number?,
	hovered: () -> number?,
	selected: () -> number?,
	select: (id: number?) -> (),
	onSelect: (callback: (id: number?) -> ()) -> (),
	destroy: () -> (),
}
local RegionPicker = {}
local RAY_LENGTH = 1e5
local HOVER = Color3.fromRGB(255, 255, 255)
local SELECT = Color3.fromRGB(255, 205, 80)

local function highlight(name: string, color: Color3, fill: number, parent: Instance): Highlight
	local item = Instance.new("Highlight")
	item.Name = name
	item.FillColor = color
	item.FillTransparency = fill
	item.OutlineColor = color
	item.OutlineTransparency = 0
	item.DepthMode = Enum.HighlightDepthMode.Occluded
	item.Enabled = false
	item.Parent = parent
	return item
end

function RegionPicker.new(view: PlanetView.View, camera: StrategicCamera.Camera): Picker
	local janitor = Janitor.new()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { view.regionsFolder }
	local hoverHighlight = highlight("RegionHover", HOVER, 0.8, view.model)
	local selectHighlight = highlight("RegionSelection", SELECT, 0.55, view.model)
	janitor.add(function()
		hoverHighlight:Destroy()
		selectHighlight:Destroy()
	end)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local hoveredId: number? = nil
	local selectedId: number? = nil
	local callbacks: { (number?) -> () } = {}

	local function cast(ray: Ray): number?
		local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
		return if result then view.regionAt(result.Instance) else nil
	end
	local function pickViewport(position: Vector2): number?
		return cast(workspace.CurrentCamera:ViewportPointToRay(position.X, position.Y))
	end
	local function pickScreen(position: Vector2): number?
		return cast(workspace.CurrentCamera:ScreenPointToRay(position.X, position.Y))
	end
	local function show(item: Highlight, id: number?)
		local region = if id then view.regionModel(id) else nil
		item.Adornee = region
		item.Enabled = region ~= nil
	end
	local function selectRegion(id: number?)
		selectedId = id
		show(selectHighlight, id)
		for _, callback in callbacks do
			callback(id)
		end
	end

	-- Hover follows the mouse and also updates while the camera turns under a still pointer.
	local stepped = RunService.RenderStepped:Connect(function()
		local id: number? = nil
		if UserInputService.MouseEnabled and not UserInputService:GetFocusedTextBox() then
			local location = UserInputService:GetMouseLocation()
			-- Panels sit above the planet; a pointer over UI must not hover regions behind it.
			local inset = GuiService:GetGuiInset()
			local overGui = #playerGui:GetGuiObjectsAtPosition(
				location.X - inset.X,
				location.Y - inset.Y
			) > 0
			if not overGui then
				id = pickViewport(location)
			end
		end
		if id ~= hoveredId then
			hoveredId = id
			show(hoverHighlight, if id ~= selectedId then id else nil)
		end
	end)
	janitor.add(function()
		stepped:Disconnect()
	end)
	camera.onTap(function(position: Vector2, viewport: boolean)
		selectRegion(if viewport then pickViewport(position) else pickScreen(position))
	end)

	return {
		pickViewport = pickViewport,
		pickScreen = pickScreen,
		hovered = function(): number?
			return hoveredId
		end,
		selected = function(): number?
			return selectedId
		end,
		select = selectRegion,
		onSelect = function(callback: (number?) -> ())
			table.insert(callbacks, callback)
		end,
		destroy = janitor.cleanup,
	}
end

return table.freeze(RegionPicker)
