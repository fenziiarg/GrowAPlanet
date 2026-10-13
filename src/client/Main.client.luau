--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Big = require(Shared.BigNumber)
local Civilization = require(Shared.Civilization)
local Config = require(Shared.config.economy)
local AgesConfig = require(Shared.config.ages)
local Kardashev = require(Shared.config.kardashev)
local Planet = require(Shared.Planet)
local Janitor = require(Shared.Janitor)
local ClientRegistry = require(script.Parent.ClientRegistry)
local Hud = require(script.Parent.Hud)
local PlanetView = require(script.Parent.PlanetView)
local RegionPanel = require(script.Parent.RegionPanel)
local RegionPicker = require(script.Parent.RegionPicker)
local StrategicCamera = require(script.Parent.StrategicCamera)
local Ui = require(script.Parent.Ui)
local PLANET_ID = "home"
local definition = Planet.definition(PLANET_ID)
local janitor = Janitor.new()
local hud = Hud.new(Players.LocalPlayer:WaitForChild("PlayerGui"), PLANET_ID)
janitor.add(hud.destroy)
local view = PlanetView.new(workspace, PLANET_ID)
janitor.add(view.destroy)
local camera = StrategicCamera.new(view.center, view.radius)
janitor.add(camera.destroy)
local picker = RegionPicker.new(view, camera)
janitor.add(picker.destroy)
ClientRegistry.view = view
ClientRegistry.camera = camera
ClientRegistry.picker = picker
local remotes = ReplicatedStorage:WaitForChild("GrowAPlanetRemotes")
local request = remotes:WaitForChild("Request") :: RemoteEvent
local snapshot = remotes:WaitForChild("Snapshot") :: RemoteEvent
local notify = remotes:WaitForChild("Notify") :: RemoteEvent

-- Intents carry exactly their own arguments; the server rejects any other argument count.
local function send(intent: string, a: any?, b: any?)
	if b ~= nil then
		request:FireServer(intent, a, b)
	elseif a ~= nil then
		request:FireServer(intent, a)
	else
		request:FireServer(intent)
	end
end
local regionPanel = RegionPanel.new(hud.gui, send)
janitor.add(regionPanel.destroy)

local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge and n >= 0
end
-- Server payloads are trusted for values but still shape-checked before touching UI.
local function valid(payload: any): boolean
	if
		type(payload) ~= "table"
		or type(payload.resources) ~= "table"
		or type(payload.planet) ~= "table"
		or type(payload.civilization) ~= "table"
	then
		return false
	end
	for _, id in Config.resourceIds do
		if not Big.valid(payload.resources[id]) then
			return false
		end
	end
	local planet = payload.planet
	if
		not finite(planet.earthMass)
		or not finite(planet.waterMass)
		or not finite(planet.totalSize)
		or definition.stages[planet.stage] == nil
		or type(planet.costs) ~= "table"
		or type(planet.income) ~= "table"
		or not finite(planet.income.GrowthPoints)
	then
		return false
	end
	for _, id in definition.growthIds do
		if not Big.valid(planet.costs[id]) then
			return false
		end
	end
	local regions = payload.regions
	if
		type(regions) ~= "table"
		or type(regions.terrain) ~= "string"
		or #regions.terrain ~= view.topology.count
		or type(regions.population) ~= "table"
		or type(regions.buildings) ~= "table"
	then
		return false
	end
	local civilization = payload.civilization
	return finite(civilization.age)
		and finite(civilization.kardashev)
		and type(civilization.upgrades) == "table"
end

-- City markers: "id:stage" for every city, sorted so the attribute only changes when cities do.
local function encodeCities(payload: any): string
	local entries = {}
	for key in payload.regions.buildings do
		local id = tonumber(key)
		local stats = if id
			then Civilization.cityStats(payload.regions, payload.civilization, id)
			else nil
		if id and stats then
			table.insert(entries, { id = id, stage = stats.stage })
		end
	end
	table.sort(entries, function(a, b)
		return a.id < b.id
	end)
	local parts = {}
	for _, item in entries do
		table.insert(parts, item.id .. ":" .. item.stage)
	end
	return table.concat(parts, ";")
end

picker.onSelect(function(id: number?)
	regionPanel.show(id)
	hud.setHintVisible(id == nil)
end)
regionPanel.onClose(function()
	picker.select(nil)
end)

local received = snapshot.OnClientEvent:Connect(function(payload: any)
	if not valid(payload) then
		return
	end
	hud.update(payload)
	regionPanel.update(payload)
	-- The planet model is driven only by these attributes.
	view.model:SetAttribute("EarthMass", payload.planet.earthMass)
	view.model:SetAttribute("WaterMass", payload.planet.waterMass)
	view.model:SetAttribute("TotalSize", payload.planet.totalSize)
	view.model:SetAttribute("Stage", payload.planet.stage)
	view.model:SetAttribute("Terrain", payload.regions.terrain)
	view.model:SetAttribute("Cities", encodeCities(payload))
	view.model:SetAttribute("Kardashev", payload.civilization.kardashev)
end)
janitor.add(function()
	received:Disconnect()
end)
local notified = notify.OnClientEvent:Connect(function(message: any)
	if type(message) ~= "table" then
		return
	end
	if message.kind == "AgeUp" and type(message.age) == "number" then
		local age = AgesConfig.ages[message.age]
		if age then
			hud.toast("AGE UP • " .. string.upper(age.name))
		end
	elseif message.kind == "Kardashev" and type(message.type) == "number" then
		local milestone = Kardashev.milestones[message.type]
		if milestone then
			hud.toast(string.upper("Kardashev " .. milestone.name .. " • " .. milestone.project))
		end
	elseif message.kind == "Offline" and finite(message.seconds) then
		hud.toast(
			string.format(
				"WELCOME BACK • %s OF OFFLINE INCOME%s",
				string.upper(Ui.duration(message.seconds)),
				if message.capped then " (CAPPED)" else ""
			)
		)
	end
end)
janitor.add(function()
	notified:Disconnect()
end)
hud.onClick(function()
	request:FireServer("Click")
end)
hud.onGrow(function(id: string)
	request:FireServer("Grow", id)
end)
hud.onAction(function(intent: string, a: any?)
	send(intent, a)
end)
local destroying = script.Destroying:Connect(janitor.cleanup)
janitor.add(function()
	destroying:Disconnect()
end)
request:FireServer("Ready")
