--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Big = require(Shared.BigNumber)
local Config = require(Shared.config.economy)
local Janitor = require(Shared.Janitor)
local janitor = Janitor.new()
local gui = Instance.new("ScreenGui")
gui.Name = "GrowAPlanetHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local panel = Instance.new("Frame")
panel.Name = "Resources"
panel.Size = UDim2.new(1, -32, 1, -32)
panel.Position = UDim2.fromOffset(16, 16)
panel.BackgroundColor3 = Color3.fromRGB(59, 88, 102)
panel.BorderSizePixel = 0
panel.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(420, 390)
limit.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(24, 30, 34)
stroke.Thickness = 3
stroke.Parent = panel
local function label(name: string, text: string, y: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = UDim2.fromOffset(16, y)
	item.Size = UDim2.new(1, -32, 0, 30)
	item.Font = Enum.Font.GothamBold
	item.TextSize = 18
	item.TextColor3 = Color3.fromRGB(238, 246, 249)
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Text = text
	item.Parent = panel
	return item
end
label("Title", "GROW A PLANET", 12).Font = Enum.Font.GothamBlack
local status = label("Status", "Loading your saved world…", 44)
status.TextSize = 14
local labels: { [string]: TextLabel } = {}
local resourceList = Instance.new("ScrollingFrame")
resourceList.Name = "Balances"
resourceList.BackgroundTransparency = 1
resourceList.BorderSizePixel = 0
resourceList.Position = UDim2.fromOffset(16, 76)
resourceList.Size = UDim2.new(1, -32, 1, -156)
resourceList.CanvasSize = UDim2.fromOffset(0, #Config.resourceIds * 26)
resourceList.ScrollBarThickness = 4
resourceList.ScrollingDirection = Enum.ScrollingDirection.Y
resourceList.Parent = panel
for i, id in Config.resourceIds do
	local title = if id == "GrowthPoints" then "Growth Points" else id
	local row = label(id, title .. "   —", (i - 1) * 26)
	row.Position = UDim2.fromOffset(0, (i - 1) * 26)
	row.Size = UDim2.new(1, -8, 0, 26)
	row.Parent = resourceList
	labels[id] = row
end
local button = Instance.new("TextButton")
button.Name = "Grow"
button.Size = UDim2.new(1, -32, 0, 56)
button.Position = UDim2.new(0, 16, 1, -72)
button.BackgroundColor3 = Color3.fromRGB(170, 220, 90)
button.TextColor3 = Color3.fromRGB(24, 30, 34)
button.Font = Enum.Font.GothamBlack
button.TextSize = 20
button.Text = "Loading…"
button.Active = false
button.AutoButtonColor = false
button.Parent = panel
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = button
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
janitor.add(function()
	gui:Destroy()
end)
local remotes = ReplicatedStorage:WaitForChild("GrowAPlanetRemotes")
local request = remotes:WaitForChild("Request") :: RemoteEvent
local snapshot = remotes:WaitForChild("Snapshot") :: RemoteEvent
local ready = false
local received = snapshot.OnClientEvent:Connect(function(resources: any)
	if type(resources) ~= "table" then
		return
	end
	for _, id in Config.resourceIds do
		if not Big.valid(resources[id]) then
			return
		end
	end
	for _, id in Config.resourceIds do
		local title = if id == "GrowthPoints" then "Growth Points" else id
		labels[id].Text = title .. "   " .. Big.format(resources[id])
	end
	ready = true
	status.Text = "Autosaving • +"
		.. tostring(Config.productionPerSecond.GrowthPoints)
		.. " Growth Point / second"
	button.Text = "+" .. tostring(Config.clickGrowth) .. " GROWTH POINT"
	button.Active = true
	button.AutoButtonColor = true
end)
janitor.add(function()
	received:Disconnect()
end)
local clicked = button.Activated:Connect(function()
	if ready then
		request:FireServer("Click")
	end
end)
janitor.add(function()
	clicked:Disconnect()
end)
local destroying = script.Destroying:Connect(janitor.cleanup)
janitor.add(function()
	destroying:Disconnect()
end)
request:FireServer("Ready")
