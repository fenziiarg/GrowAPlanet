--!strict
-- Civilization tab: current age, age advancement, the upgrade tree and Kardashev projects.
-- Prices and requirements are previews from shared config; the server re-validates every intent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Civilization = require(Shared.Civilization)
local AgesConfig = require(Shared.config.ages)
local Kardashev = require(Shared.config.kardashev)
local Janitor = require(Shared.Janitor)
local Ui = require(script.Parent.Ui)
export type Panel = { update: (view: any) -> (), destroy: () -> () }
local CivPanel = {}
local ROW_BUTTON = 52

local function effects(map: { [string]: number }): string
	local parts = {}
	for id, factor in map do
		table.insert(parts, id .. " ×" .. string.format("%g", factor))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

function CivPanel.new(page: Frame, emit: (intent: string, a: any?) -> ()): Panel
	local janitor = Janitor.new()
	local list = Ui.list(page, "Civilization", 6)
	list.Size = UDim2.fromScale(1, 1)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local ageLabel = Ui.label(list, "Age", "No civilization yet", 16)
	ageLabel.TextColor3 = Ui.GOLD
	ageLabel.LayoutOrder = nextOrder()
	local populationLabel = Ui.label(list, "Population", "", 14)
	populationLabel.LayoutOrder = nextOrder()
	local advance = Ui.button(list, "AdvanceAge", "")
	advance.Size = UDim2.new(1, -8, 0, ROW_BUTTON)
	advance.LayoutOrder = nextOrder()
	local upgradesHeader = Ui.label(list, "UpgradesHeader", "UPGRADES", 14)
	upgradesHeader.TextColor3 = Ui.CYAN
	upgradesHeader.LayoutOrder = nextOrder()
	local upgradeButtons: { [string]: TextButton } = {}
	for _, upgrade in AgesConfig.upgrades do
		local item = Ui.button(list, upgrade.id, upgrade.name)
		item.Size = UDim2.new(1, -8, 0, ROW_BUTTON)
		item.LayoutOrder = nextOrder()
		item.Visible = false
		upgradeButtons[upgrade.id] = item
	end
	local kardashevHeader = Ui.label(list, "KardashevHeader", "KARDASHEV", 14)
	kardashevHeader.TextColor3 = Ui.CYAN
	kardashevHeader.LayoutOrder = nextOrder()
	local kardashevLabel = Ui.label(list, "KardashevType", "", 14)
	kardashevLabel.LayoutOrder = nextOrder()
	local kardashevButton = Ui.button(list, "Kardashev", "")
	kardashevButton.Size = UDim2.new(1, -8, 0, ROW_BUTTON)
	kardashevButton.LayoutOrder = nextOrder()

	local enabled: { [Instance]: boolean } = {}
	local function bind(item: TextButton, intent: string, a: any?)
		local connection = item.Activated:Connect(function()
			if enabled[item] then
				emit(intent, a)
			end
		end)
		janitor.add(function()
			connection:Disconnect()
		end)
	end
	local function set(item: TextButton, on: boolean, text: string)
		enabled[item] = on
		Ui.setEnabled(item, on)
		item.Text = text
	end
	bind(advance, "AdvanceAge")
	bind(kardashevButton, "Kardashev")
	for id, item in upgradeButtons do
		bind(item, "BuyUpgrade", id)
	end

	local panel = {}
	function panel.update(view: any)
		local state = view.civilization
		local balances = view.resources
		local population = state.population or 0
		local age = AgesConfig.ages[state.age]
		if age then
			ageLabel.Text = string.format(
				"%s • %s   ×%s income",
				age.name,
				age.group,
				string.format("%g", age.incomeMultiplier)
			)
		else
			ageLabel.Text = "Found your first city to begin the Paleolithic"
		end
		populationLabel.Text = "Planet population   " .. Ui.number(population)
		local nextAge = AgesConfig.ages[state.age + 1]
		advance.Visible = state.age > 0
		if nextAge == nil then
			set(advance, false, "Final age reached")
		elseif state.age > 0 then
			local requirement =
				string.format("%s pop • %s", Ui.number(nextAge.population), Ui.cost(nextAge.cost))
			local ok = population >= nextAge.population
				and Civilization.canAfford(balances, nextAge.cost)
			set(advance, ok, "ADVANCE TO " .. string.upper(nextAge.name) .. "\n" .. requirement)
		end
		for _, upgrade in AgesConfig.upgrades do
			local item = upgradeButtons[upgrade.id]
			item.Visible = state.age >= upgrade.age
			if state.upgrades[upgrade.id] then
				set(
					item,
					false,
					"✓ " .. upgrade.name .. "   (" .. effects(upgrade.effects) .. ")"
				)
				item.BackgroundColor3 = Ui.RECESSED
				item.TextColor3 = Ui.MUTED
			else
				item.TextColor3 = Ui.BORDER
				local missing = nil
				for _, required in upgrade.requires do
					if not state.upgrades[required] then
						local spec = Civilization.upgrade(required)
						missing = if spec then spec.name else required
					end
				end
				if missing then
					set(item, false, upgrade.name .. "\nRequires " .. missing)
				else
					set(
						item,
						Civilization.canAfford(balances, upgrade.cost),
						upgrade.name
							.. "  ("
							.. effects(upgrade.effects)
							.. ")\n"
							.. Ui.cost(upgrade.cost)
					)
				end
			end
		end
		local reached = Kardashev.milestones[state.kardashev]
		kardashevLabel.Text = "Current: "
			.. (if reached then reached.name .. " • " .. reached.project else "Type 0")
		local milestone = Kardashev.milestones[state.kardashev + 1]
		if milestone == nil then
			set(kardashevButton, false, "All v1 Kardashev milestones reached")
		elseif state.age < milestone.age then
			set(
				kardashevButton,
				false,
				string.format(
					"%s: %s\nRequires the %s",
					milestone.name,
					milestone.project,
					AgesConfig.ages[milestone.age].name
				)
			)
		else
			set(
				kardashevButton,
				Civilization.canAfford(balances, milestone.cost),
				string.format(
					"BUILD %s (%s)\n%s",
					string.upper(milestone.project),
					milestone.name,
					Ui.cost(milestone.cost)
				)
			)
		end
	end
	panel.destroy = janitor.cleanup
	return panel :: Panel
end

return table.freeze(CivPanel)
