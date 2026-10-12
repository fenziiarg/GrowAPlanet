--!strict
export type Stage = {
	id: string,
	minimumEarthMass: number,
	minimumWaterMass: number,
	radius: number,
}
export type Definition = { id: string, stages: { Stage } }
local definitions: { [string]: Definition } = {}
return table.freeze(definitions)
