--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("GrowAPlanet")
local Big = require(Shared.BigNumber)
local Config = require(Shared.config.economy)
local Planet = require(Shared.Planet)
local Janitor = require(Shared.Janitor)
local Terrain = require(Shared.Terrain)
local ClientRegistry = require(script.Parent.ClientRegistry)
local Hud = require(script.Parent.Hud)
local PlanetView = require(script.Parent.PlanetView)
local RegionPicker = require(script.Parent.RegionPicker)
local StrategicCamera = require(script.Parent.StrategicCamera)
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
local population: { [string]: number } = {}
local remotes = ReplicatedStorage:WaitForChild("GrowAPlanetRemotes")
local request = remotes:WaitForChild("Request") :: RemoteEvent
local snapshot = remotes:WaitForChild("Snapshot") :: RemoteEvent
local notify = remotes:WaitForChild("Notify") :: RemoteEvent

local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge and n >= 0
end
-- Server payloads are trusted for values but still shape-checked before touching UI.
local function valid(payload: any): boolean
	if
		type(payload) ~= "table"
		or type(payload.resources) ~= "table"
		or type(payload.planet) ~= "table"
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
	local regions = payload.regions
	if
		type(regions) ~= "table"
		or type(regions.terrain) ~= "string"
		or #regions.terrain ~= view.topology.count
		or type(regions.population) ~= "table"
	then
		return false
	end
	for _, id in definition.growthIds do
		if not Big.valid(planet.costs[id]) then
			return false
		end
	end
	return true
end

local function showSelected(id: number?)
	if id == nil then
		hud.showRegion(nil)
		return
	end
	local terrain = view.model:GetAttribute("Terrain")
	local code = if type(terrain) == "string" then string.sub(terrain, id, id) else ""
	local look = Terrain.fromCode(code)
	hud.showRegion({
		id = id,
		terrain = if look then look.name else "Unknown",
		population = population[tostring(id)] or 0,
	})
end
picker.onSelect(showSelected)
hud.onRegionClose(function()
	picker.select(nil)
end)

local received = snapshot.OnClientEvent:Connect(function(payload: any)
	if not valid(payload) then
		return
	end
	hud.update(payload)
	population = payload.regions.population
	-- The planet model is driven only by these attributes.
	view.model:SetAttribute("EarthMass", payload.planet.earthMass)
	view.model:SetAttribute("WaterMass", payload.planet.waterMass)
	view.model:SetAttribute("TotalSize", payload.planet.totalSize)
	view.model:SetAttribute("Stage", payload.planet.stage)
	view.model:SetAttribute("Terrain", payload.regions.terrain)
	showSelected(picker.selected())
end)
janitor.add(function()
	received:Disconnect()
end)
local notified = notify.OnClientEvent:Connect(function(message: any)
	if
		type(message) == "table"
		and message.kind == "StageUp"
		and type(message.stage) == "number"
	then
		hud.stageUp(message.stage)
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
local destroying = script.Destroying:Connect(janitor.cleanup)
janitor.add(function()
	destroying:Disconnect()
end)
request:FireServer("Ready")
