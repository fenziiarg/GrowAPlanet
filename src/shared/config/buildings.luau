--!strict
export type Level = { cost: { [string]: number }, productionPerSecond: { [string]: number } }
export type Definition = {
	id: string,
	eraId: string,
	allowedTerrainIds: { string },
	levels: { Level },
}
local definitions: { [string]: Definition } = {}
return table.freeze(definitions)
