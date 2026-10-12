--!strict
export type RegionId = string
export type State = { terrainId: string, population: number, buildingLevels: { [string]: number } }
export type Definition = { count: number, topologyVersion: number }
local definitions: { [string]: Definition } = {}
return table.freeze(definitions)
