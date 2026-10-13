--!strict
-- Kardashev milestones (GAME_SPEC section 5). Type 0 is the starting state. Each later type is a
-- megaproject: it needs an age (and the previous type), costs resources, multiplies production
-- and changes the planet's look. Type IV and above are not in v1.
export type Milestone = {
	type: number,
	name: string,
	project: string,
	age: number,
	cost: { [string]: number },
	effects: { [string]: number },
	visual: string,
}
local milestones: { Milestone } = {
	{
		type = 1,
		name = "Type I",
		project = "Orbital Habitat Ring",
		age = 10,
		cost = { Materials = 5e7, Energy = 2e7, Money = 3e7 },
		effects = { Energy = 2, Money = 1.5 },
		visual = "OrbitalRing",
	},
	{
		type = 2,
		name = "Type II",
		project = "Stellar Lattice",
		age = 11,
		cost = { Energy = 1e11, Research = 4e10, Materials = 1.5e9 },
		effects = { Energy = 3, Research = 2 },
		visual = "StellarLattice",
	},
	{
		type = 3,
		name = "Type III",
		project = "Galactic Rings",
		age = 11,
		cost = { Research = 1.2e14, Energy = 5e13, Money = 4e13 },
		effects = { Money = 2, Research = 2, Materials = 2, Energy = 2, Food = 2 },
		visual = "GalacticRings",
	},
}
return table.freeze({ milestones = table.freeze(milestones) })
