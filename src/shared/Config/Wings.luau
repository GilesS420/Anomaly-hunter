--!strict
-- Mansion wings, bought in order. Each owned wing adds a small sell-value boost.

export type Wing = {
	id: string,
	order: number,
	price: number,
	capacity: number,
	unlocksZone: number?,
	launch: boolean,
}

local Wings = {}

Wings.ValueBoostPerWing = 0.05 -- placeholder, tune in playtesting

Wings.List = {
	{ id = "Foyer", order = 1, price = 0, capacity = 8, unlocksZone = 1, launch = true },
	{ id = "Library", order = 2, price = 1_000_000, capacity = 8, unlocksZone = 2, launch = true },
	{ id = "Ballroom", order = 3, price = 8_000_000, capacity = 10, unlocksZone = 3, launch = true },
	{ id = "Attic", order = 4, price = 65_000_000, capacity = 10, unlocksZone = 4, launch = false },
	{ id = "Crypt", order = 5, price = 500_000_000, capacity = 12, unlocksZone = 5, launch = false },
	{ id = "Garden", order = 6, price = 5_000_000_000, capacity = 20, launch = false },
} :: { Wing }

Wings.VaultSlots = 3

return Wings
