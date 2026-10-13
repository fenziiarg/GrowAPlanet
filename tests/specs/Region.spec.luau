--!strict
local Shared = game:GetService("ReplicatedStorage").GrowAPlanet
local Server = game:GetService("ServerScriptService").GrowAPlanet
local RegionTopology = require(Shared.RegionTopology)
local Terrain = require(Shared.Terrain)
local Regions = require(Shared.config.regions)
local Terrains = require(Shared.config.terrain)
local Economy = require(Shared.Economy)
local Planet = require(Shared.Planet)
local Schema = require(Server.ProfileSchema)
return function()
	local it = getfenv().it
	local definition = Regions.home
	local topology = RegionTopology.get(definition.frequency)
	local planet = Planet.definition("home")

	it("has the configured region count (10f^2 + 2) with 12 pentagons", function()
		assert(topology.count == definition.count, "count")
		assert(topology.count == 10 * definition.frequency ^ 2 + 2, "Goldberg count")
		local pentagons = 0
		for _, ring in topology.cells do
			assert(#ring == 5 or #ring == 6, "cells are pentagons or hexagons")
			if #ring == 5 then
				pentagons += 1
			end
		end
		assert(pentagons == 12, "12 pentagons")
	end)

	it(
		"forms a closed sphere: every border shared by exactly two regions, V - E + F = 2",
		function()
			local uses: { [string]: number } = {}
			for _, ring in topology.cells do
				for k = 1, #ring do
					local a, b = ring[k], ring[k % #ring + 1]
					local key = if a < b then a .. ":" .. b else b .. ":" .. a
					uses[key] = (uses[key] or 0) + 1
				end
			end
			local edges = 0
			for _, n in uses do
				assert(n == 2, "border shared by two regions")
				edges += 1
			end
			assert(edges == #topology.edges, "edge list complete")
			assert(#topology.corners - edges + topology.count == 2, "Euler characteristic")
		end
	)

	it("covers the sphere exactly once (region areas sum to 4*pi)", function()
		local total = 0
		for id = 1, topology.count do
			local area = RegionTopology.area(topology, id)
			assert(area > 0, "positive area")
			total += area
		end
		assert(math.abs(total - 4 * math.pi) < 1e-6, "total area " .. total)
	end)

	it("gives every region a symmetric neighbour list", function()
		for id, list in topology.neighbors do
			assert(#list == #topology.cells[id], "one neighbour per side")
			for _, other in list do
				assert(table.find(topology.neighbors[other], id) ~= nil, "symmetric")
			end
		end
	end)

	it("keeps region IDs stable across rebuilds", function()
		-- A fresh build (bypassing the cache) must reproduce identical centres in identical order.
		local fresh = RegionTopology.build(definition.frequency)
		assert(fresh ~= topology and fresh.count == topology.count, "independent build")
		for id, center in topology.centers do
			assert(fresh.centers[id] == center, "region " .. id .. " moved")
		end
		for id, ring in topology.cells do
			assert(
				table.concat(fresh.cells[id], ",") == table.concat(ring, ","),
				"region " .. id .. " shape"
			)
		end
		-- Known anchors: region 1 is the first icosahedron vertex, poles map to fixed regions.
		local expectedFirst = Vector3.new(-1, (1 + math.sqrt(5)) / 2, 0).Unit
		assert(topology.centers[1]:FuzzyEq(expectedFirst, 1e-9), "region 1 anchor")
		for id, center in topology.centers do
			assert(RegionTopology.nearest(topology, center) == id, "centre owned by its region")
		end
	end)

	it("generates deterministic terrain with exact ocean share from Water Mass", function()
		local a = Terrain.generate("home", 42, 4, 2600, 1400)
		local b = Terrain.generate("home", 42, 4, 2600, 1400)
		assert(a == b and #a == topology.count, "deterministic")
		assert(Terrain.generate("home", 43, 4, 2600, 1400) ~= a, "seed changes the map")
		local function share(terrain: string, code: string): number
			local n = 0
			for i = 1, #terrain do
				if string.sub(terrain, i, i) == code then
					n += 1
				end
			end
			return n / #terrain
		end
		assert(share(Terrain.generate("home", 42, 1, 0, 0), "O") == 0, "no ocean without water")
		local oceanic = Terrain.generate("home", 42, 3, 1600, 600)
		local want = Terrain.oceanShare(definition, 1600, 600)
		assert(math.abs(share(oceanic, "O") - want) <= 1 / topology.count + 1e-9, "ocean share")
		local wetter = Terrain.generate("home", 42, 3, 1600, 1200)
		assert(share(wetter, "O") > share(oceanic, "O"), "more water, more ocean")
	end)

	it(
		"uses at least land, ocean and desert on a habitable planet, and stage-specific types",
		function()
			local habitable = Terrain.generate("home", 7, 4, 2600, 1400)
			for _, code in { "L", "O", "D", "I", "M" } do
				assert(string.find(habitable, code, 1, true) ~= nil, "habitable has " .. code)
			end
			local volcanic = Terrain.generate("home", 7, 2, 800, 0)
			assert(
				string.find(volcanic, "V", 1, true) and not string.find(volcanic, "O", 1, true),
				"volcanic"
			)
			assert(
				not string.find(Terrain.generate("home", 7, 1, 0, 0), "[^R]"),
				"barren is all rock"
			)
			assert(
				string.find(Terrain.generate("home", 7, 5, 4200, 2800), "F", 1, true),
				"mature forests"
			)
		end
	)

	it("keeps pinned (developed) regions' terrain", function()
		local base = Terrain.generate("home", 9, 4, 2600, 1400)
		local wet = Terrain.generate("home", 9, 4, 2600, 4000, { [5] = string.sub(base, 5, 5) })
		assert(string.sub(wet, 5, 5) == string.sub(base, 5, 5), "pinned")
	end)

	it("defines every terrain with a unique code", function()
		local seen: { [string]: boolean } = {}
		for _, terrain in Terrains do
			assert(#terrain.code == 1 and not seen[terrain.code], "unique code")
			seen[terrain.code] = true
		end
	end)

	it("initializes region data on upgrade and validates region records", function()
		local v2 = {
			schemaVersion = 2,
			planets = {
				home = {
					resources = Economy.initial(),
					growth = { earthLevel = 16, waterLevel = 6 },
				},
			},
		}
		local upgraded = Schema.upgrade(v2, 555) :: any
		assert(upgraded ~= nil and upgraded.schemaVersion == 3, "upgraded to v3")
		local regions = upgraded.planets.home.regions
		assert(regions.seed == 555 and #regions.terrain == topology.count, "seeded terrain")
		local stats = Planet.stats(planet, upgraded.planets.home.growth)
		assert(
			regions.terrain
				== Terrain.generate("home", 555, stats.stage, stats.earthMass, stats.waterMass),
			"terrain"
		)
		assert(Schema.upgrade(upgraded, 999) == upgraded, "current records pass through unchanged")
		local bad: any = table.clone(regions)
		bad.population = { ["0"] = 5 }
		assert(not Schema.validRegions("home", bad), "region 0 rejected")
		bad.population = { [tostring(topology.count + 1)] = 5 }
		assert(not Schema.validRegions("home", bad), "out-of-range region rejected")
		bad.population = { ["7"] = -1 }
		assert(not Schema.validRegions("home", bad), "negative population rejected")
		bad.population = { ["7"] = 12 }
		assert(Schema.validRegions("home", bad), "valid sparse population")
		bad.terrain = string.rep("Z", topology.count)
		assert(not Schema.validRegions("home", bad), "unknown terrain code rejected")
	end)
end
