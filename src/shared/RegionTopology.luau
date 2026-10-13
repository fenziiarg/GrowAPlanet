--!strict
-- Goldberg-polyhedron regions on the unit sphere: the dual of a frequency-f geodesic icosphere.
-- Region IDs are the icosphere vertex insertion order. Points are de-duplicated by integer keys,
-- never by float comparison, so IDs are deterministic and stable for a given frequency.
export type Topology = {
	frequency: number,
	count: number,
	centers: { Vector3 },
	-- Polygon corners (unit vectors). Neighbouring cells share the same corner index.
	corners: { Vector3 },
	-- Corner indices per region, ordered around the region centre.
	cells: { { number } },
	neighbors: { { number } },
	-- Unique border segments as corner index pairs.
	edges: { { number } },
}
local RegionTopology = {}
local cache: { [number]: Topology } = {}

local T = (1 + math.sqrt(5)) / 2
local ICOSA: { Vector3 } = {
	Vector3.new(-1, T, 0),
	Vector3.new(1, T, 0),
	Vector3.new(-1, -T, 0),
	Vector3.new(1, -T, 0),
	Vector3.new(0, -1, T),
	Vector3.new(0, 1, T),
	Vector3.new(0, -1, -T),
	Vector3.new(0, 1, -T),
	Vector3.new(T, 0, -1),
	Vector3.new(T, 0, 1),
	Vector3.new(-T, 0, -1),
	Vector3.new(-T, 0, 1),
}
local FACES: { { number } } = {
	{ 1, 12, 6 },
	{ 1, 6, 2 },
	{ 1, 2, 8 },
	{ 1, 8, 11 },
	{ 1, 11, 12 },
	{ 2, 6, 10 },
	{ 6, 12, 5 },
	{ 12, 11, 3 },
	{ 11, 8, 7 },
	{ 8, 2, 9 },
	{ 4, 10, 5 },
	{ 4, 5, 3 },
	{ 4, 3, 7 },
	{ 4, 7, 9 },
	{ 4, 9, 10 },
	{ 5, 10, 6 },
	{ 3, 5, 12 },
	{ 7, 3, 11 },
	{ 9, 7, 8 },
	{ 10, 9, 2 },
}

local function edgeKey(a: number, b: number, k: number, f: number): string
	if a < b then
		return "e" .. a .. ":" .. b .. ":" .. k
	end
	return "e" .. b .. ":" .. a .. ":" .. (f - k)
end

local function build(f: number): Topology
	assert(f >= 1 and f % 1 == 0, "Invalid frequency")
	local centers: { Vector3 } = {}
	local ids: { [string]: number } = {}
	local function point(face: number, i: number, j: number): number
		local tri = FACES[face]
		local a, b, c = tri[1], tri[2], tri[3]
		local key
		if i == 0 and j == 0 then
			key = "v" .. a
		elseif i == f then
			key = "v" .. b
		elseif j == f then
			key = "v" .. c
		elseif j == 0 then
			key = edgeKey(a, b, i, f)
		elseif i == 0 then
			key = edgeKey(a, c, j, f)
		elseif i + j == f then
			key = edgeKey(b, c, j, f)
		else
			key = "f" .. face .. ":" .. i .. ":" .. j
		end
		local existing = ids[key]
		if existing then
			return existing
		end
		local A, B, C = ICOSA[a], ICOSA[b], ICOSA[c]
		table.insert(centers, (A + (B - A) * (i / f) + (C - A) * (j / f)).Unit)
		ids[key] = #centers
		return #centers
	end
	local triangles: { { number } } = {}
	for face = 1, #FACES do
		for i = 0, f - 1 do
			for j = 0, f - 1 - i do
				table.insert(
					triangles,
					{ point(face, i, j), point(face, i + 1, j), point(face, i, j + 1) }
				)
				if i + j < f - 1 then
					table.insert(
						triangles,
						{ point(face, i + 1, j), point(face, i + 1, j + 1), point(face, i, j + 1) }
					)
				end
			end
		end
	end
	-- Each icosphere triangle becomes one polygon corner shared by its three regions.
	local corners: { Vector3 } = {}
	local incident: { { number } } = {}
	local neighborSets: { { [number]: boolean } } = {}
	for id = 1, #centers do
		incident[id] = {}
		neighborSets[id] = {}
	end
	for index, tri in triangles do
		corners[index] = (centers[tri[1]] + centers[tri[2]] + centers[tri[3]]).Unit
		for k = 1, 3 do
			local id, nextId = tri[k], tri[k % 3 + 1]
			table.insert(incident[id], index)
			neighborSets[id][nextId] = true
			neighborSets[nextId][id] = true
		end
	end
	local cells: { { number } } = {}
	local neighbors: { { number } } = {}
	local edges: { { number } } = {}
	local seen: { [string]: boolean } = {}
	for id, normal in centers do
		local reference = if math.abs(normal.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
		local u = normal:Cross(reference).Unit
		local v = normal:Cross(u)
		local ring = table.clone(incident[id])
		local angles: { [number]: number } = {}
		for _, corner in ring do
			local c = corners[corner]
			angles[corner] = math.atan2(c:Dot(v), c:Dot(u))
		end
		table.sort(ring, function(x, y)
			return angles[x] < angles[y]
		end)
		cells[id] = ring
		for k = 1, #ring do
			local x, y = ring[k], ring[k % #ring + 1]
			local key = if x < y then x .. ":" .. y else y .. ":" .. x
			if not seen[key] then
				seen[key] = true
				table.insert(edges, { x, y })
			end
		end
		local list = {}
		for other in neighborSets[id] do
			table.insert(list, other)
		end
		table.sort(list)
		neighbors[id] = list
	end
	return {
		frequency = f,
		count = #centers,
		centers = centers,
		corners = corners,
		cells = cells,
		neighbors = neighbors,
		edges = edges,
	}
end

-- Uncached build; `get` should be used everywhere except tests that compare two builds.
RegionTopology.build = build

function RegionTopology.get(frequency: number): Topology
	local topology = cache[frequency]
	if topology == nil then
		topology = build(frequency)
		cache[frequency] = topology
	end
	return topology
end

-- Region whose centre is angularly nearest to a unit direction (the spherical Voronoi owner).
-- Used for validation and independent test expectations; live picking uses raycasts.
function RegionTopology.nearest(topology: Topology, direction: Vector3): number
	local best, bestDot = 1, -math.huge
	for id, center in topology.centers do
		local d = center:Dot(direction)
		if d > bestDot then
			best, bestDot = id, d
		end
	end
	return best
end

-- Spherical area of a region polygon (fan from the centre), for coverage tests.
function RegionTopology.area(topology: Topology, id: number): number
	local center = topology.centers[id]
	local ring = topology.cells[id]
	local total = 0
	for k = 1, #ring do
		local b, c = topology.corners[ring[k]], topology.corners[ring[k % #ring + 1]]
		local triple = math.abs(center:Dot(b:Cross(c)))
		total += 2 * math.atan2(triple, 1 + center:Dot(b) + b:Dot(c) + c:Dot(center))
	end
	return total
end

return table.freeze(RegionTopology)
