--!strict
-- Region panel: terrain and city details, founding a city, and building/upgrading buildings.
-- Prices are previews from shared config; the server re-validates every intent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Civilization = require(Shared.Civilization)
local Terrain = require(Shared.Terrain)
local Buildings = require(Shared.config.buildings)
local Cities = require(Shared.config.cities)
local Janitor = require(Shared.Janitor)
local Ui = require(script.Parent.Ui)
export type Panel = {
	show: (regionId: number?) -> (),
	update: (view: any) -> (),
	onClose: (callback: () -> ()) -> (),
	visible: () -> boolean,
	destroy: () -> (),
}
local RegionPanel = {}
local buildable: { [string]: boolean } = {}
for _, id in Cities.buildableTerrainIds do
	buildable[id] = true
end

function RegionPanel.new(gui: ScreenGui, emit: (intent: string, a: any?, b: any?) -> ()): Panel
	local janitor = Janitor.new()
	local frame = Ui.frame(gui, "Region", Ui.SLATE)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -12)
	frame.Size = UDim2.new(0, 440, 0.55, 0)
	frame.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(300, 150)
	limit.MaxSize = Vector2.new(440, 300)
	limit.Parent = frame
	local title = Ui.label(frame, "Title", "REGION", 18)
	title.Font = Enum.Font.GothamBlack
	title.Position = UDim2.fromOffset(14, 10)
	title.Size = UDim2.new(1, -80, 0, Ui.ROW)
	local terrainLabel = Ui.label(frame, "Terrain", "", 14)
	terrainLabel.TextColor3 = Ui.CYAN
	terrainLabel.Position = UDim2.fromOffset(14, 36)
	terrainLabel.Size = UDim2.new(1, -80, 0, 20)
	local statsLabel = Ui.label(frame, "Stats", "", 13)
	statsLabel.Position = UDim2.fromOffset(14, 56)
	statsLabel.Size = UDim2.new(1, -28, 0, 20)
	local productionLabel = Ui.label(frame, "Production", "", 13)
	productionLabel.TextColor3 = Ui.GOLD
	productionLabel.Position = UDim2.fromOffset(14, 76)
	productionLabel.Size = UDim2.new(1, -28, 0, 20)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(44, 44)
	close.BackgroundColor3 = Ui.BORDER
	close.TextColor3 = Ui.TEXT
	close.Font = Enum.Font.GothamBlack
	close.TextSize = 20
	close.Text = "X"
	close.Parent = frame
	Ui.round(close, 8)
	local list = Ui.list(frame, "Actions", 6)
	list.Position = UDim2.fromOffset(14, 102)
	list.Size = UDim2.new(1, -28, 1, -112)

	local found = Ui.button(list, "FoundCity", "")
	found.Size = UDim2.new(1, -8, 0, 52)
	found.LayoutOrder = 0
	local rows: { [string]: TextButton } = {}
	for index, building in Buildings.list do
		local item = Ui.button(list, building.id, building.name)
		item.Size = UDim2.new(1, -8, 0, 52)
		item.LayoutOrder = index
		item.Visible = false
		rows[building.id] = item
	end

	local regionId: number? = nil
	local lastView: any = nil
	local enabled: { [Instance]: boolean } = {}
	local closeCallbacks: { () -> () } = {}
	local function set(item: TextButton, on: boolean, text: string)
		enabled[item] = on
		Ui.setEnabled(item, on)
		item.Text = text
	end
	local foundConnection = found.Activated:Connect(function()
		if enabled[found] and regionId then
			emit("FoundCity", regionId)
		end
	end)
	janitor.add(function()
		foundConnection:Disconnect()
	end)
	for id, item in rows do
		local connection = item.Activated:Connect(function()
			if enabled[item] and regionId then
				emit("Build", regionId, id)
			end
		end)
		janitor.add(function()
			connection:Disconnect()
		end)
	end
	local closed = close.Activated:Connect(function()
		for _, callback in closeCallbacks do
			callback()
		end
	end)
	janitor.add(function()
		closed:Disconnect()
	end)

	local function render()
		local id = regionId
		local view = lastView
		frame.Visible = id ~= nil and view ~= nil
		if id == nil or view == nil then
			return
		end
		local regions = view.regions
		local state = view.civilization
		local look = Terrain.fromCode(string.sub(regions.terrain, id, id))
		local terrainId = if look then look.id else ""
		title.Text = "REGION #" .. id
		local levels = regions.buildings[tostring(id)]
		local city = if levels then Civilization.cityStats(regions, state, id) else nil
		if city then
			terrainLabel.Text = (if look then look.name else "Unknown")
				.. " • "
				.. Cities.stages[city.stage].name
				.. " city"
			statsLabel.Text = string.format(
				"Population %s • Development %d",
				Ui.number(city.population),
				city.development
			)
			productionLabel.Text = Ui.rates(city.production)
		else
			terrainLabel.Text = (if look then look.name else "Unknown") .. " • no city"
			statsLabel.Text = if buildable[terrainId]
				then "Cities can be founded on this terrain."
				else "Cities need Grassland, Forest, Desert or Mountains."
			productionLabel.Text = ""
		end
		found.Visible = levels == nil
		if levels == nil then
			if not buildable[terrainId] then
				set(
					found,
					false,
					"Cannot found a city on " .. (if look then look.name else "this terrain")
				)
			else
				local cost = Civilization.foundingCost(regions)
				set(
					found,
					Civilization.canAfford(view.resources, cost),
					"FOUND CITY\n" .. Ui.cost(cost)
				)
			end
		end
		-- Buildings of later ages stay hidden (no dead buttons); the Civilization tab shows the path.
		for _, building in Buildings.list do
			local item = rows[building.id]
			local show = levels ~= nil
				and state.age >= building.age
				and table.find(building.allowedTerrainIds, terrainId) ~= nil
			item.Visible = show
			if show and levels then
				local level = levels[building.id] or 0
				local header =
					string.format("%s  Lv %d/%d", building.name, level, building.maxLevel)
				if level >= building.maxLevel then
					set(item, false, header .. "\nMax level")
				else
					local cost = Civilization.buildingCost(building, level)
					set(
						item,
						Civilization.canAfford(view.resources, cost),
						header
							.. "\n"
							.. (if level == 0 then "BUILD • " else "UPGRADE • ")
							.. Ui.cost(cost)
					)
				end
			end
		end
	end

	local panel = {}
	function panel.show(id: number?)
		regionId = id
		render()
	end
	function panel.update(view: any)
		lastView = view
		render()
	end
	function panel.onClose(callback: () -> ())
		table.insert(closeCallbacks, callback)
	end
	function panel.visible(): boolean
		return frame.Visible
	end
	panel.destroy = janitor.cleanup
	return panel :: Panel
end

return table.freeze(RegionPanel)
