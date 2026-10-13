--!strict
local Shared = game:GetService("ReplicatedStorage").GrowAPlanet
local Big = require(Shared.BigNumber)
local Economy = require(Shared.Economy)
local Planet = require(Shared.Planet)
local Terrain = require(Shared.Terrain)
local Config = require(Shared.config.economy)
local Regions = require(Shared.config.regions)
local ServerConfig = require(script.Parent.config)
-- Sparse per-region data keyed by region ID string; absent means zero / no buildings.
export type RegionData = {
	topologyVersion: number,
	seed: number,
	terrain: string,
	population: { [string]: number },
	buildings: { [string]: { [string]: number } },
}
export type PlanetData = { resources: Economy.Balances, growth: Planet.State, regions: RegionData }
export type Data = { schemaVersion: number, planets: { [string]: PlanetData } }
local Schema = {}
local MAX_SEED = 2 ^ 31 - 2

-- ProfileStore template. seed 0 / empty terrain mark a planet that is initialized after load.
function Schema.new(): Data
	return {
		schemaVersion = ServerConfig.schemaVersion,
		planets = {
			home = {
				resources = Economy.initial(),
				growth = Planet.initial(),
				regions = {
					topologyVersion = Regions.home.topologyVersion,
					seed = 0,
					terrain = "",
					population = {},
					buildings = {},
				},
			},
		},
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

local function regionKey(key: any, count: number): boolean
	if type(key) ~= "string" then
		return false
	end
	local id = tonumber(key)
	return id ~= nil and id % 1 == 0 and id >= 1 and id <= count and tostring(id) == key
end

local function count(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and n < math.huge and n % 1 == 0
end

function Schema.validRegions(planetId: string, regions: any): boolean
	local definition = Regions[planetId]
	if
		type(regions) ~= "table"
		or definition == nil
		or regions.topologyVersion ~= definition.topologyVersion
		or not count(regions.seed)
		or regions.seed < 1
		or regions.seed > MAX_SEED
		or not Terrain.valid(planetId, regions.terrain)
		or type(regions.population) ~= "table"
		or type(regions.buildings) ~= "table"
	then
		return false
	end
	for key, value in regions.population do
		if not regionKey(key, definition.count) or not count(value) then
			return false
		end
	end
	for key, levels in regions.buildings do
		if not regionKey(key, definition.count) or type(levels) ~= "table" then
			return false
		end
		for building, level in levels do
			if type(building) ~= "string" or not count(level) then
				return false
			end
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
		and Schema.validRegions(ServerConfig.planetId, home.regions)
end

-- Regions with any building keep their terrain when water or stage changes.
function Schema.pinnedTerrain(regions: RegionData): { [number]: string }
	local keep: { [number]: string } = {}
	for key, levels in regions.buildings do
		if next(levels) ~= nil then
			local id = tonumber(key) :: number
			keep[id] = string.sub(regions.terrain, id, id)
		end
	end
	return keep
end

function Schema.terrainFor(planetId: string, home: PlanetData): string
	local stats = Planet.stats(Planet.definition(planetId), home.growth)
	local keep = if Terrain.valid(planetId, home.regions.terrain)
		then Schema.pinnedTerrain(home.regions)
		else nil
	return Terrain.generate(
		planetId,
		home.regions.seed,
		stats.stage,
		stats.earthMass,
		stats.waterMass,
		keep
	)
end

-- Returns a validated current-version copy, or nil. Never mutates the stored record, so a
-- rejected or unknown profile is released unchanged instead of being overwritten.
-- `seed` initializes planets that have no regions yet (new profiles and v1/v2 records).
function Schema.upgrade(data: any, seed: number): Data?
	assert(count(seed) and seed >= 1 and seed <= MAX_SEED, "Invalid seed")
	if type(data) ~= "table" or type(data.planets) ~= "table" then
		return nil
	end
	local version = data.schemaVersion
	if version == ServerConfig.schemaVersion and Schema.validate(data) then
		return data -- already current; nothing to apply
	end
	if version ~= 1 and version ~= 2 and version ~= ServerConfig.schemaVersion then
		return nil
	end
	local source = data.planets[ServerConfig.planetId]
	if type(source) ~= "table" or not validResources(source.resources) then
		return nil
	end
	local growth = if version == 1 then Planet.initial() else source.growth
	if not Planet.valid(Planet.definition(ServerConfig.planetId), growth) then
		return nil
	end
	local home: PlanetData = {
		resources = table.clone(source.resources),
		growth = table.clone(growth),
		regions = if version == ServerConfig.schemaVersion
			then table.clone(source.regions)
			else nil :: any,
	}
	local regions = home.regions
	if
		regions == nil or (type(regions) == "table" and regions.seed == 0 and regions.terrain == "")
	then
		home.regions = {
			topologyVersion = Regions.home.topologyVersion,
			seed = seed,
			terrain = "",
			population = if regions then regions.population else {},
			buildings = if regions then regions.buildings else {},
		}
		home.regions.terrain = Schema.terrainFor(ServerConfig.planetId, home)
	end
	local planets = table.clone(data.planets)
	planets[ServerConfig.planetId] = home
	local upgraded: Data = { schemaVersion = ServerConfig.schemaVersion, planets = planets }
	return if Schema.validate(upgraded) then upgraded else nil
end

return Schema
