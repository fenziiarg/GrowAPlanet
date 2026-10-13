--!strict
-- Shared UI building blocks in the Check-UI-inspired slate/cyan/gold/lime style (UI_NOTES.md).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Big = require(Shared.BigNumber)
local Ui = {}
Ui.SLATE = Color3.fromRGB(59, 88, 102)
Ui.RECESSED = Color3.fromRGB(26, 44, 52)
Ui.BORDER = Color3.fromRGB(24, 30, 34)
Ui.TEXT = Color3.fromRGB(238, 246, 249)
Ui.MUTED = Color3.fromRGB(170, 190, 198)
Ui.CYAN = Color3.fromRGB(120, 220, 240)
Ui.GOLD = Color3.fromRGB(255, 205, 80)
Ui.LIME = Color3.fromRGB(170, 220, 90)
Ui.SILVER = Color3.fromRGB(150, 160, 166)
Ui.ROW = 26
-- Display names for resources (Growth Points are shortened in costs).
Ui.RESOURCE_NAMES = table.freeze({
	GrowthPoints = "Growth Points",
	Population = "Population",
	Food = "Food",
	Materials = "Materials",
	Energy = "Energy",
	Money = "Money",
	Research = "Research",
})
local SHORT = { GrowthPoints = "GP" }
local ORDER = { "GrowthPoints", "Food", "Materials", "Energy", "Money", "Research" }

function Ui.round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function Ui.frame(parent: Instance, name: string, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Ui.round(frame, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Ui.BORDER
	stroke.Thickness = 3
	stroke.Parent = frame
	return frame
end

function Ui.label(parent: Instance, name: string, text: string, size: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Size = UDim2.new(1, 0, 0, Ui.ROW)
	item.Font = Enum.Font.GothamBold
	item.TextSize = size
	item.TextColor3 = Ui.TEXT
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Text = text
	item.Parent = parent
	return item
end

function Ui.button(parent: Instance, name: string, text: string): TextButton
	local item = Instance.new("TextButton")
	item.Name = name
	item.BackgroundColor3 = Ui.SILVER
	item.TextColor3 = Ui.BORDER
	item.Font = Enum.Font.GothamBlack
	item.TextSize = 14
	item.TextWrapped = true
	item.Text = text
	item.Active = false
	item.AutoButtonColor = false
	item.Parent = parent
	Ui.round(item, 8)
	return item
end

function Ui.setEnabled(item: TextButton, enabled: boolean)
	item.Active = enabled
	item.AutoButtonColor = enabled
	item.BackgroundColor3 = if enabled then Ui.LIME else Ui.SILVER
end

-- Vertical scrolling list whose canvas grows with its contents.
function Ui.list(parent: Instance, name: string, padding: number): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	layout.Parent = frame
	return frame
end

function Ui.number(n: number): string
	return Big.format(Big.new(math.max(0, n)))
end

-- "1.2K Food • 300 Materials" in a stable resource order.
function Ui.cost(cost: { [string]: number }): string
	local parts = {}
	for _, id in ORDER do
		local amount = cost[id]
		if amount and amount > 0 then
			table.insert(parts, Ui.number(amount) .. " " .. (SHORT[id] or id))
		end
	end
	return if #parts == 0 then "Free" else table.concat(parts, " • ")
end

-- "+12 Food/s +3 Money/s" for non-zero rates.
function Ui.rates(rates: { [string]: number }): string
	local parts = {}
	for _, id in ORDER do
		local amount = rates[id]
		if amount and amount > 0 then
			table.insert(parts, "+" .. Ui.number(amount) .. " " .. (SHORT[id] or id) .. "/s")
		end
	end
	return if #parts == 0 then "No production yet" else table.concat(parts, "  ")
end

function Ui.duration(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return if hours > 0
		then string.format("%dh %02dm", hours, minutes)
		else string.format("%dm", minutes)
end

return table.freeze(Ui)
