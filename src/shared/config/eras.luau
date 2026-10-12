--!strict
export type Definition = {
	id: string,
	requirements: { [string]: number },
	incomeMultiplier: number,
	buildingIds: { string },
}
local definitions: { [string]: Definition } = {}
return table.freeze(definitions)
