--!strict
-- Minimal development HUD: server balances, planet stats, growth buttons and stage-up toasts.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Big = require(Shared.BigNumber)
local Planet = require(Shared.Planet)
local Config = require(Shared.config.economy)
local PlanetConfig = require(Shared.config.planet)
local Janitor = require(Shared.Janitor)
local SLATE = Color3.fromRGB(59, 88, 102)
local BORDER = Color3.fromRGB(24, 30, 34)
local TEXT = Color3.fromRGB(238, 246, 249)
local CYAN = Color3.fromRGB(120, 220, 240)
local LIME = Color3.fromRGB(170, 220, 90)
local SILVER = Color3.fromRGB(150, 160, 166)
local ROW = 26
export type Hud = {
	update: (view: any) -> (),
	stageUp: (stage: number) -> (),
	onClick: (callback: () -> ()) -> (),
	onGrow: (callback: (id: string) -> ()) -> (),
	-- Placeholder region panel (Phase 3): nil hides it.
	showRegion: (info: { id: number, terrain: string, population: number }?) -> (),
	onRegionClose: (callback: () -> ()) -> (),
	destroy: () -> (),
}
local Hud = {}

local function round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function panel(gui: ScreenGui, name: string, anchorX: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(anchorX, 0)
	frame.Position = UDim2.new(anchorX, if anchorX == 0 then 16 else -16, 0, 16)
	frame.Size = UDim2.new(0.5, -24, 1, -32)
	frame.BackgroundColor3 = SLATE
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(380, 390)
	limit.Parent = frame
	round(frame, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = BORDER
	stroke.Thickness = 3
	stroke.Parent = frame
	return frame
end

local function label(
	parent: Instance,
	name: string,
	text: string,
	y: number,
	size: number
): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = UDim2.fromOffset(16, y)
	item.Size = UDim2.new(1, -32, 0, ROW)
	item.Font = Enum.Font.GothamBold
	item.TextSize = size
	item.TextColor3 = TEXT
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Text = text
	item.Parent = parent
	return item
end

local function list(parent: Frame, rows: number, bottom: number): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "Rows"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromOffset(0, 72)
	frame.Size = UDim2.new(1, 0, 1, -(72 + bottom))
	frame.CanvasSize = UDim2.fromOffset(0, rows * ROW)
	frame.ScrollBarThickness = 4
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.Parent = parent
	return frame
end

local function button(parent: Frame, name: string, offsetFromBottom: number): TextButton
	local item = Instance.new("TextButton")
	item.Name = name
	item.AnchorPoint = Vector2.new(0, 1)
	item.Position = UDim2.new(0, 16, 1, -offsetFromBottom)
	item.Size = UDim2.new(1, -32, 0, 48)
	item.BackgroundColor3 = SILVER
	item.TextColor3 = BORDER
	item.Font = Enum.Font.GothamBlack
	item.TextSize = 16
	item.TextWrapped = true
	item.Text = "Loading…"
	item.Active = false
	item.AutoButtonColor = false
	item.Parent = parent
	round(item, 8)
	return item
end

local function setEnabled(item: TextButton, enabled: boolean)
	item.Active = enabled
	item.AutoButtonColor = enabled
	item.BackgroundColor3 = if enabled then LIME else SILVER
end

function Hud.new(playerGui: Instance, planetId: string): Hud
	local definition = Planet.definition(planetId)
	local janitor = Janitor.new()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GrowAPlanetHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	janitor.add(function()
		gui:Destroy()
	end)

	-- Planet panel (left): authoritative stats and growth purchases.
	local planetPanel = panel(gui, "Planet", 0)
	label(planetPanel, "Title", "PLANET", 12, 18).Font = Enum.Font.GothamBlack
	local stageLabel = label(planetPanel, "Stage", "Loading…", 40, 16)
	stageLabel.TextColor3 = CYAN
	local planetRows = list(planetPanel, 4, 128)
	local planetLabels: { [string]: TextLabel } = {}
	for i, key in { "EarthMass", "WaterMass", "TotalSize", "Income" } do
		planetLabels[key] = label(planetRows, key, "—", (i - 1) * ROW, 16)
		planetLabels[key].Position = UDim2.fromOffset(16, (i - 1) * ROW)
	end
	local growButtons: { [string]: TextButton } = {}
	for i, id in definition.growthIds do
		growButtons[id] = button(planetPanel, "Add" .. id, 16 + (#definition.growthIds - i) * 56)
	end

	-- Resource panel (right): balances and the Growth Point button.
	local resourcePanel = panel(gui, "Resources", 1)
	label(resourcePanel, "Title", "GROW A PLANET", 12, 18).Font = Enum.Font.GothamBlack
	local status = label(resourcePanel, "Status", "Loading your saved world…", 40, 14)
	local resourceRows = list(resourcePanel, #Config.resourceIds, 72)
	local resourceLabels: { [string]: TextLabel } = {}
	for i, id in Config.resourceIds do
		local title = if id == "GrowthPoints" then "Growth Points" else id
		resourceLabels[id] = label(resourceRows, id, title .. "   —", (i - 1) * ROW, 16)
		resourceLabels[id].Position = UDim2.fromOffset(16, (i - 1) * ROW)
	end
	local clickButton = button(resourcePanel, "Grow", 16)

	-- Region panel (bottom centre) and the controls hint shown when nothing is selected.
	local regionPanel = Instance.new("Frame")
	regionPanel.Name = "Region"
	regionPanel.AnchorPoint = Vector2.new(0.5, 1)
	regionPanel.Position = UDim2.new(0.5, 0, 1, -16)
	regionPanel.Size = UDim2.fromOffset(300, 112)
	regionPanel.BackgroundColor3 = SLATE
	regionPanel.BorderSizePixel = 0
	regionPanel.Visible = false
	regionPanel.Parent = gui
	round(regionPanel, 10)
	local regionStroke = Instance.new("UIStroke")
	regionStroke.Color = BORDER
	regionStroke.Thickness = 3
	regionStroke.Parent = regionPanel
	local regionTitle = label(regionPanel, "Title", "REGION", 12, 18)
	regionTitle.Font = Enum.Font.GothamBlack
	regionTitle.Size = UDim2.new(1, -76, 0, ROW)
	local regionTerrain = label(regionPanel, "Terrain", "", 44, 16)
	regionTerrain.TextColor3 = CYAN
	local regionPopulation = label(regionPanel, "Population", "", 72, 16)
	local closeRegion = Instance.new("TextButton")
	closeRegion.Name = "Close"
	closeRegion.AnchorPoint = Vector2.new(1, 0)
	closeRegion.Position = UDim2.new(1, -10, 0, 10)
	closeRegion.Size = UDim2.fromOffset(44, 44)
	closeRegion.BackgroundColor3 = BORDER
	closeRegion.TextColor3 = TEXT
	closeRegion.Font = Enum.Font.GothamBlack
	closeRegion.TextSize = 20
	closeRegion.Text = "X"
	closeRegion.Parent = regionPanel
	round(closeRegion, 8)
	local hint = Instance.new("TextLabel")
	hint.Name = "ControlsHint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -16)
	hint.Size = UDim2.fromOffset(420, 28)
	hint.BackgroundColor3 = BORDER
	hint.BackgroundTransparency = 0.25
	hint.TextColor3 = TEXT
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 14
	hint.Text = "Drag to rotate • Scroll, pinch or Q/E to zoom • Click a region"
	hint.Parent = gui
	round(hint, 8)
	local closeCallbacks: { () -> () } = {}
	local closed = closeRegion.Activated:Connect(function()
		for _, callback in closeCallbacks do
			callback()
		end
	end)
	janitor.add(function()
		closed:Disconnect()
	end)

	-- Stage-up toast (top centre).
	local toast = Instance.new("TextLabel")
	toast.Name = "StageToast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 16)
	toast.Size = UDim2.fromOffset(300, 56)
	toast.BackgroundColor3 = BORDER
	toast.TextColor3 = CYAN
	toast.Font = Enum.Font.GothamBlack
	toast.TextSize = 20
	toast.TextWrapped = true
	toast.Visible = false
	toast.ZIndex = 10
	toast.Parent = gui
	round(toast, 10)
	local toastToken = 0

	local ready = false
	local affordable: { [string]: boolean } = {}
	local clickCallbacks: { () -> () } = {}
	local growCallbacks: { (string) -> () } = {}
	local clicked = clickButton.Activated:Connect(function()
		if ready then
			for _, callback in clickCallbacks do
				callback()
			end
		end
	end)
	janitor.add(function()
		clicked:Disconnect()
	end)
	for id, item in growButtons do
		local connection = item.Activated:Connect(function()
			if ready and affordable[id] then
				for _, callback in growCallbacks do
					callback(id)
				end
			end
		end)
		janitor.add(function()
			connection:Disconnect()
		end)
	end
	gui.Parent = playerGui

	local hud = {}
	function hud.update(view: any)
		for _, id in Config.resourceIds do
			local title = if id == "GrowthPoints" then "Growth Points" else id
			resourceLabels[id].Text = title .. "   " .. Big.format(view.resources[id])
		end
		local planet = view.planet
		local stage = definition.stages[planet.stage]
		stageLabel.Text =
			string.format("Stage %d/%d • %s", planet.stage, #definition.stages, stage.name)
		planetLabels.EarthMass.Text = "Earth Mass   " .. Big.format(Big.new(planet.earthMass))
		planetLabels.WaterMass.Text = "Water Mass   " .. Big.format(Big.new(planet.waterMass))
		planetLabels.TotalSize.Text = "Total Size   "
			.. Big.format(Big.new(planet.totalSize))
			.. " km"
		planetLabels.Income.Text = "Growth   +"
			.. Big.format(Big.new(planet.income.GrowthPoints))
			.. " / s"
		for id, item in growButtons do
			local growth = Planet.growth(definition, id) :: PlanetConfig.Growth
			if planet.stage < growth.unlockStage then
				affordable[id] = false
				setEnabled(item, false)
				item.Text = growth.label
					.. " unlocks at "
					.. definition.stages[growth.unlockStage].name
			else
				local cost = planet.costs[id]
				affordable[id] = Big.compare(view.resources.GrowthPoints, cost) >= 0
				setEnabled(item, affordable[id])
				item.Text = string.format(
					"ADD %s  +%s mass • %s GP",
					string.upper(growth.label),
					Big.format(Big.new(growth.massPerLevel)),
					Big.format(cost)
				)
			end
		end
		status.Text = "Autosaving • passive Growth Points"
		clickButton.Text = "+" .. tostring(Config.clickGrowth) .. " GROWTH POINT"
		setEnabled(clickButton, true)
		ready = true
	end
	function hud.stageUp(stage: number)
		local entry = definition.stages[stage]
		if entry == nil then
			return
		end
		toastToken += 1
		local token = toastToken
		toast.Text = "STAGE UP • " .. string.upper(entry.name)
		toast.TextTransparency = 0
		toast.BackgroundTransparency = 0.1
		toast.Visible = true
		task.delay(3, function()
			if token ~= toastToken or toast.Parent == nil then
				return
			end
			local fade = TweenService:Create(
				toast,
				TweenInfo.new(0.4),
				{ TextTransparency = 1, BackgroundTransparency = 1 }
			)
			fade:Play()
			fade.Completed:Wait()
			if token == toastToken then
				toast.Visible = false
			end
		end)
	end
	function hud.showRegion(info: { id: number, terrain: string, population: number }?)
		regionPanel.Visible = info ~= nil
		hint.Visible = info == nil
		if info then
			regionTitle.Text = "REGION #" .. info.id
			regionTerrain.Text = "Terrain   " .. info.terrain
			regionPopulation.Text = "Population   " .. Big.format(Big.new(info.population))
		end
	end
	function hud.onRegionClose(callback: () -> ())
		table.insert(closeCallbacks, callback)
	end
	function hud.onClick(callback: () -> ())
		table.insert(clickCallbacks, callback)
	end
	function hud.onGrow(callback: (id: string) -> ())
		table.insert(growCallbacks, callback)
	end
	function hud.destroy()
		janitor.cleanup()
	end
	return hud :: Hud
end

return table.freeze(Hud)
