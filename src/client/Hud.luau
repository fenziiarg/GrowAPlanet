--!strict
-- Development HUD: Planet / Civilization tabs (left), resources with income (right), toasts and
-- the controls hint. The region panel lives in RegionPanel; the civilization tab in CivPanel.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Big = require(Shared.BigNumber)
local Planet = require(Shared.Planet)
local Config = require(Shared.config.economy)
local PlanetConfig = require(Shared.config.planet)
local Janitor = require(Shared.Janitor)
local Ui = require(script.Parent.Ui)
local CivPanel = require(script.Parent.CivPanel)
export type Hud = {
	gui: ScreenGui,
	update: (view: any) -> (),
	toast: (text: string) -> (),
	setHintVisible: (visible: boolean) -> (),
	onClick: (callback: () -> ()) -> (),
	onGrow: (callback: (id: string) -> ()) -> (),
	onAction: (callback: (intent: string, a: any?) -> ()) -> (),
	destroy: () -> (),
}
local Hud = {}

local function sidePanel(gui: ScreenGui, name: string, anchorX: number): Frame
	local frame = Ui.frame(gui, name, Ui.SLATE)
	frame.AnchorPoint = Vector2.new(anchorX, 0)
	frame.Position = UDim2.new(anchorX, if anchorX == 0 then 16 else -16, 0, 16)
	frame.Size = UDim2.new(0.5, -24, 1, -32)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(380, 390)
	limit.Parent = frame
	return frame
end

local function placed(item: GuiObject, x: number, y: number, width: UDim, height: number): GuiObject
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.new(width.Scale, width.Offset, 0, height)
	return item
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
	local actionCallbacks: { (string, any?) -> () } = {}
	local function emit(intent: string, a: any?)
		for _, callback in actionCallbacks do
			callback(intent, a)
		end
	end

	-- Left panel with two tabs.
	local left = sidePanel(gui, "Planet", 0)
	local tabs: { [string]: TextButton } = {}
	local pages: { [string]: Frame } = {}
	for i, id in { "Planet", "Civilization" } do
		local tab = Ui.button(left, id .. "Tab", string.upper(id))
		tab.Position = UDim2.new((i - 1) * 0.5, if i == 1 then 12 else 6, 0, 10)
		tab.Size = UDim2.new(0.5, -18, 0, 36)
		tabs[id] = tab
		local page = Instance.new("Frame")
		page.Name = id .. "Page"
		page.BackgroundTransparency = 1
		page.Position = UDim2.fromOffset(16, 54)
		page.Size = UDim2.new(1, -32, 1, -66)
		page.Parent = left
		pages[id] = page
	end
	local function showTab(id: string)
		for key, page in pages do
			page.Visible = key == id
			tabs[key].BackgroundColor3 = if key == id then Ui.CYAN else Ui.RECESSED
			tabs[key].TextColor3 = if key == id then Ui.BORDER else Ui.TEXT
			tabs[key].Active = true
			tabs[key].AutoButtonColor = true
		end
	end
	for id, tab in tabs do
		local connection = tab.Activated:Connect(function()
			showTab(id)
		end)
		janitor.add(function()
			connection:Disconnect()
		end)
	end

	-- Planet page: Earth Mass, Water Mass, Total Size, growth income, growth purchases.
	local planetPage = pages.Planet
	local planetLabels: { [string]: TextLabel } = {}
	for i, key in { "EarthMass", "WaterMass", "TotalSize", "Income" } do
		local row = Ui.label(planetPage, key, "—", 16)
		placed(row, 0, (i - 1) * Ui.ROW, UDim.new(1, 0), Ui.ROW)
		planetLabels[key] = row
	end
	local growButtons: { [string]: TextButton } = {}
	for i, id in definition.growthIds do
		local item = Ui.button(planetPage, "Add" .. id, "Loading…")
		item.AnchorPoint = Vector2.new(0, 1)
		item.Position = UDim2.new(0, 0, 1, -(#definition.growthIds - i) * 56)
		item.Size = UDim2.new(1, 0, 0, 48)
		growButtons[id] = item
	end
	local civ = CivPanel.new(pages.Civilization, emit)
	janitor.add(civ.destroy)
	showTab("Planet")

	-- Resources (right): balances with income per second, and the Growth Point button.
	local right = sidePanel(gui, "Resources", 1)
	local title = Ui.label(right, "Title", "GROW A PLANET", 18)
	title.Font = Enum.Font.GothamBlack
	placed(title, 16, 12, UDim.new(1, -32), Ui.ROW)
	local status = Ui.label(right, "Status", "Loading your saved world…", 14)
	placed(status, 16, 40, UDim.new(1, -32), Ui.ROW)
	local rows = Ui.list(right, "Balances", 0)
	rows.Position = UDim2.fromOffset(16, 72)
	rows.Size = UDim2.new(1, -32, 1, -144)
	local resourceLabels: { [string]: TextLabel } = {}
	for i, id in Config.resourceIds do
		local row = Ui.label(rows, id, Ui.RESOURCE_NAMES[id] .. "   —", 16)
		row.LayoutOrder = i
		resourceLabels[id] = row
	end
	local clickButton = Ui.button(right, "Grow", "Loading…")
	clickButton.AnchorPoint = Vector2.new(0, 1)
	clickButton.Position = UDim2.new(0, 16, 1, -16)
	clickButton.Size = UDim2.new(1, -32, 0, 48)

	-- Controls hint (bottom centre) and toast (top centre).
	local hint = Instance.new("TextLabel")
	hint.Name = "ControlsHint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -16)
	hint.Size = UDim2.fromOffset(420, 28)
	hint.BackgroundColor3 = Ui.BORDER
	hint.BackgroundTransparency = 0.25
	hint.TextColor3 = Ui.TEXT
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 14
	hint.Text = "Drag to rotate • Scroll, pinch or Q/E to zoom • Click a region"
	hint.Parent = gui
	Ui.round(hint, 8)
	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 16)
	toast.Size = UDim2.fromOffset(340, 56)
	toast.BackgroundColor3 = Ui.BORDER
	toast.TextColor3 = Ui.CYAN
	toast.Font = Enum.Font.GothamBlack
	toast.TextSize = 18
	toast.TextWrapped = true
	toast.Visible = false
	toast.ZIndex = 10
	toast.Parent = gui
	Ui.round(toast, 10)
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

	local hud = { gui = gui }
	function hud.update(view: any)
		local income = view.planet.income
		for _, id in Config.resourceIds do
			local text = Ui.RESOURCE_NAMES[id] .. "   " .. Big.format(view.resources[id])
			local rate = income[id]
			if rate and rate > 0 then
				text ..= "  (+" .. Ui.number(rate) .. "/s)"
			end
			resourceLabels[id].Text = text
		end
		local planet = view.planet
		planetLabels.EarthMass.Text = "Earth Mass   " .. Ui.number(planet.earthMass)
		planetLabels.WaterMass.Text = "Water Mass   " .. Ui.number(planet.waterMass)
		planetLabels.TotalSize.Text = "Total Size   " .. Ui.number(planet.totalSize) .. " km"
		planetLabels.Income.Text = "Growth   +" .. Ui.number(income.GrowthPoints) .. " / s"
		for id, item in growButtons do
			local growth = Planet.growth(definition, id) :: PlanetConfig.Growth
			if planet.stage < growth.unlockStage then
				affordable[id] = false
				Ui.setEnabled(item, false)
				item.Text = string.format(
					"%s unlocks at %s Earth Mass",
					growth.label,
					Ui.number(definition.stages[growth.unlockStage].minimumEarthMass)
				)
			else
				local cost = planet.costs[id]
				affordable[id] = Big.compare(view.resources.GrowthPoints, cost) >= 0
				Ui.setEnabled(item, affordable[id])
				item.Text = string.format(
					"ADD %s  +%s mass • %s GP",
					string.upper(growth.label),
					Ui.number(growth.massPerLevel),
					Big.format(cost)
				)
			end
		end
		civ.update(view)
		status.Text = "Autosaving • income shown per second"
		clickButton.Text = "+" .. tostring(Config.clickGrowth) .. " GROWTH POINT"
		Ui.setEnabled(clickButton, true)
		ready = true
	end
	function hud.toast(text: string)
		toastToken += 1
		local token = toastToken
		toast.Text = text
		toast.TextTransparency = 0
		toast.BackgroundTransparency = 0.1
		toast.Visible = true
		task.delay(3.5, function()
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
	function hud.setHintVisible(visible: boolean)
		hint.Visible = visible
	end
	function hud.onClick(callback: () -> ())
		table.insert(clickCallbacks, callback)
	end
	function hud.onGrow(callback: (id: string) -> ())
		table.insert(growCallbacks, callback)
	end
	function hud.onAction(callback: (intent: string, a: any?) -> ())
		table.insert(actionCallbacks, callback)
	end
	function hud.destroy()
		janitor.cleanup()
	end
	return hud :: Hud
end

return table.freeze(Hud)
