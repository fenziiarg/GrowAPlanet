--!strict
export type Definition = { id: string, productionMultipliers: { [string]: number } }
local definitions: { [string]: Definition } = {}
return table.freeze(definitions)
