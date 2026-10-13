--!strict
-- Bot playthrough on fresh in-memory data using the real shared rules (never a profile).
-- Results are SIMULATED pacing, not human-verified. Pure: safe to require in Edit mode.
-- A cloned Bot may carry a "SharedOverride" ObjectValue pointing at cloned shared modules, so
-- Edit-mode tuning runs get fresh (uncached) config each time.
local override = script:FindFirstChild("SharedOverride") :: ObjectValue?
local Shared: any = if override and override.Value
	then override.Value
	else game:GetService("ReplicatedStorage").GrowAPlanet
local Big = (require :: any)(Shared.BigNumber)
local Civilization = (require :: any)(Shared.Civilization)
local Economy = (require :: any)(Shared.Economy)
local Planet = (require :: any)(Shared.Planet)
local Terrain = (require :: any)(Shared.Terrain)
local AgesConfig = (require :: any)(Shared.config.ages)
local Buildings = (require :: any)(Shared.config.buildings)
local Cities = (require :: any)(Shared.config.cities)
local KardashevConfig = (require :: any)(Shared.config.kardashev)
local Regions = (require :: any)(Shared.config.regions)
local Bot = {}
local PREFERRED_TERRAIN = { Land = 4, Forest = 3, Mountains = 2, Desert = 1 }

local function amount(balances: any, id: string): number
	local value = balances[id]
	return value.m * 10 ^ value.e
end

export type Options = {
	seconds: number,
	clicksPerSecond: number,
	seed: number?,
	maxCities: number?,
}

function Bot.run(options: Options): any
	local planetId = "home"
	local definition = Planet.definition(planetId)
	local seed = options.seed or 12345
	local resources = Economy.initial()
	local growth = Planet.initial()
	local civ = Civilization.initial()
	local regions: any = {
		topologyVersion = Regions[planetId].topologyVersion,
		seed = seed,
		terrain = "",
		population = {},
		buildings = {},
	}
	local function regenerateTerrain()
		local stats = Planet.stats(definition, growth)
		local keep: { [number]: string } = {}
		for key in regions.buildings do
			local id = tonumber(key) :: number
			keep[id] = string.sub(regions.terrain, id, id)
		end
		regions.terrain =
			Terrain.generate(planetId, seed, stats.stage, stats.earthMass, stats.waterMass, keep)
	end
	regenerateTerrain()
	local log: { string } = {}
	local ageSeconds: { [string]: number } = {}
	local kardashevSeconds: { [string]: number } = {}
	local purchases = { growth = 0, cities = 0, buildings = 0, upgrades = 0 }
	local rates: { [string]: number } = {}
	local population = 0
	local function refresh()
		rates, population = Civilization.rates(Planet.production(definition, growth), regions, civ)
	end
	refresh()
	local function commit(r: any, g: any, c: any, _reason: any): boolean
		if r == nil then
			return false
		end
		resources, regions, civ = r, g, c
		refresh()
		return true
	end
	local function bestRegion(): number?
		local best, bestScore = nil, 0
		for id = 1, #regions.terrain do
			if regions.buildings[tostring(id)] == nil then
				local terrain = Civilization.terrainAt(regions, id)
				local score = terrain and PREFERRED_TERRAIN[terrain] or 0
				if score > bestScore then
					best, bestScore = id, score
				end
			end
		end
		return best
	end
	-- Resources the next goal needs, held back only when that goal is within reach (30 minutes
	-- at current rates); otherwise the bot keeps investing so production can catch up.
	local function within(cost: any): boolean
		for id, value in cost do
			local short = value - amount(resources, id)
			if short > 0 and short > (rates[id] or 0) * 1800 then
				return false
			end
		end
		return true
	end
	local function reserve(): any
		local nextAge = AgesConfig.ages[civ.age + 1]
		if nextAge and population >= nextAge.population and within(nextAge.cost) then
			return nextAge.cost
		end
		local milestone = Civilization.nextMilestone(civ)
		if milestone and civ.age >= milestone.age and within(milestone.cost) then
			return milestone.cost
		end
		return {}
	end
	local function keepsReserve(cost: any, held: any): boolean
		for id, value in cost do
			if held[id] and amount(resources, id) - value < held[id] then
				return false
			end
		end
		return true
	end
	local function step(second: number)
		for _ = 1, 40 do
			local nextAge = AgesConfig.ages[civ.age + 1]
			local beforeAge, beforeK = civ.age, civ.kardashev
			if commit(Civilization.advanceAge(resources, regions, civ)) then
				local age = AgesConfig.ages[civ.age]
				ageSeconds[age.id] = second
				table.insert(log, string.format("%6ds AGE %s (pop %d)", second, age.id, population))
				continue
			end
			if commit(Civilization.advanceKardashev(resources, regions, civ)) then
				local milestone = KardashevConfig.milestones[civ.kardashev]
				kardashevSeconds[milestone.name] = second
				table.insert(log, string.format("%6ds KARDASHEV %s", second, milestone.name))
				continue
			end
			local bought = false
			for _, upgrade in AgesConfig.upgrades do
				if not civ.upgrades[upgrade.id] and keepsReserve(upgrade.cost, reserve()) then
					if commit(Civilization.buyUpgrade(resources, regions, civ, upgrade.id)) then
						purchases.upgrades += 1
						bought = true
						break
					end
				end
			end
			if bought then
				continue
			end
			local cityCount = Civilization.cityCount(regions)
			local wantCities = math.min(options.maxCities or 14, 1 + math.ceil(civ.age * 1.2))
			local region = bestRegion()
			if region and cityCount < wantCities then
				if commit(Civilization.found(planetId, resources, regions, civ, region)) then
					purchases.cities += 1
					if beforeAge == 0 then
						ageSeconds[AgesConfig.ages[1].id] = second
						table.insert(
							log,
							string.format("%6ds AGE Paleolithic (first city)", second)
						)
					end
					continue
				end
			end
			-- Planet growth: needed until buildable land exists, then only with spare Growth Points.
			local growthTarget = region == nil and cityCount == 0
			local spare = amount(resources, "GrowthPoints")
				> 3 * (Civilization.foundingCost(regions).GrowthPoints or 0)
			if growthTarget or spare or cityCount >= wantCities then
				local stats = Planet.stats(definition, growth)
				local pick, pickCost = nil, math.huge
				for _, id in definition.growthIds do
					local cost = Planet.cost(definition, growth, id)
					local value = cost.m * 10 ^ cost.e
					local unlocked = stats.stage
						>= (Planet.growth(definition, id) :: any).unlockStage
					if unlocked and value < pickCost then
						pick, pickCost = id, value
					end
				end
				if pick and (growthTarget or spare) then
					local r, g = Planet.grow(definition, resources, growth, pick)
					if r and g then
						resources, growth = r, g
						regenerateTerrain()
						refresh()
						purchases.growth += 1
						continue
					end
				end
			end
			-- Buildings: housing first while population blocks the next age, else cheapest by wait time.
			local held = reserve()
			local needHousing = nextAge ~= nil and population < nextAge.population
			local best, bestKey, bestScore = nil, nil, math.huge
			for key, levels in regions.buildings do
				local terrain = Civilization.terrainAt(regions, tonumber(key) :: number) or ""
				for _, building in Buildings.list do
					local level = levels[building.id] or 0
					if
						civ.age >= building.age
						and level < building.maxLevel
						and table.find(building.allowedTerrainIds, terrain)
					then
						local cost = Civilization.buildingCost(building, level)
						if Civilization.canAfford(resources, cost) and keepsReserve(cost, held) then
							local score = 0
							for id, value in cost do
								score += value / math.max(rates[id] or 0, 1)
							end
							if needHousing and building.housing > 0 then
								score *= 0.3
							end
							if score < bestScore then
								best, bestKey, bestScore = building, key, score
							end
						end
					end
				end
			end
			if best and bestKey then
				if
					commit(
						Civilization.build(
							planetId,
							resources,
							regions,
							civ,
							tonumber(bestKey),
							best.id
						)
					)
				then
					purchases.buildings += 1
					continue
				end
			end
			if beforeAge == civ.age and beforeK == civ.kardashev then
				break
			end
		end
	end
	for second = 1, options.seconds do
		resources = Economy.advance(resources, 1, rates)
		resources.Population = Big.new(population)
		for _ = 1, options.clicksPerSecond do
			resources = Economy.click(resources)
		end
		step(second)
		if civ.age == #AgesConfig.ages and civ.kardashev == #KardashevConfig.milestones then
			table.insert(log, string.format("%6ds DONE all ages and milestones", second))
			break
		end
	end
	local stats = Planet.stats(definition, growth)
	local stageCounts: { [string]: number } = {}
	for key in regions.buildings do
		local city = Civilization.cityStats(regions, civ, tonumber(key) :: number)
		if city then
			local name = Cities.stages[city.stage].id
			stageCounts[name] = (stageCounts[name] or 0) + 1
		end
	end
	return {
		simulated = true,
		seconds = options.seconds,
		clicksPerSecond = options.clicksPerSecond,
		ageSeconds = ageSeconds,
		kardashevSeconds = kardashevSeconds,
		age = civ.age,
		kardashev = civ.kardashev,
		cities = Civilization.cityCount(regions),
		cityStages = stageCounts,
		population = population,
		planet = {
			earth = growth.earthLevel,
			water = growth.waterLevel,
			totalSize = stats.totalSize,
		},
		purchases = purchases,
		rates = rates,
		balances = (function()
			local out = {}
			for id, value in resources do
				out[id] = Big.format(value)
			end
			return out
		end)(),
		log = log,
	}
end

return table.freeze(Bot)
