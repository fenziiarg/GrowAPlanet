--!strict
local Shared = game:GetService("ReplicatedStorage").GrowAPlanet
local Big = require(Shared.BigNumber)
local Economy = require(Shared.Economy)
local Config = require(Shared.config.economy)
local ServerConfig = require(script.Parent.config)
export type Data = { schemaVersion: number, planets: { [string]: { resources: Economy.Balances } } }
local Schema = {}
function Schema.new(): Data
	return {
		schemaVersion = ServerConfig.schemaVersion,
		planets = { home = { resources = Economy.initial() } },
	}
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
	if type(home) ~= "table" or type(home.resources) ~= "table" then
		return false
	end
	for _, id in Config.resourceIds do
		if not Big.valid(home.resources[id]) then
			return false
		end
	end
	return true
end
return Schema
