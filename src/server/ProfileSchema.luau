--!strict
local Shared = game:GetService("ReplicatedStorage").GrowAPlanet
local Big = require(Shared.BigNumber)
local Economy = require(Shared.Economy)
local Planet = require(Shared.Planet)
local Config = require(Shared.config.economy)
local ServerConfig = require(script.Parent.config)
export type PlanetData = { resources: Economy.Balances, growth: Planet.State }
export type Data = { schemaVersion: number, planets: { [string]: PlanetData } }
local Schema = {}
function Schema.new(): Data
	return {
		schemaVersion = ServerConfig.schemaVersion,
		planets = { home = { resources = Economy.initial(), growth = Planet.initial() } },
	}
end
local function validResources(resources: any): boolean
	if type(resources) ~= "table" then
		return false
	end
	for _, id in Config.resourceIds do
		if not Big.valid(resources[id]) then
			return false
		end
	end
	return true
end
function Schema.validate(data: any): boolean
	if
		type(data) ~= "table"
		or data.schemaVersion ~= ServerConfig.schemaVersion
		or type(data.planets) ~= "table"
	then
		return false
	end
	local home = data.planets[ServerConfig.planetId]
	return type(home) == "table"
		and validResources(home.resources)
		and Planet.valid(Planet.definition(ServerConfig.planetId), home.growth)
end
-- Returns a validated current-version copy, or nil. Never mutates the stored record, so a
-- rejected or unknown profile is released unchanged instead of being overwritten.
function Schema.upgrade(data: any): Data?
	if type(data) ~= "table" then
		return nil
	end
	if data.schemaVersion == 1 then
		local home = type(data.planets) == "table" and data.planets[ServerConfig.planetId]
		if type(home) ~= "table" or not validResources(home.resources) then
			return nil
		end
		local planets = table.clone(data.planets)
		planets[ServerConfig.planetId] =
			{ resources = table.clone(home.resources), growth = Planet.initial() }
		local upgraded = { schemaVersion = 2, planets = planets }
		return if Schema.validate(upgraded) then upgraded else nil
	end
	return if Schema.validate(data) then data else nil
end
return Schema
