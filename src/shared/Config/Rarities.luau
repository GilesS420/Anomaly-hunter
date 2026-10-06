--!strict
-- Rarity ladder. Regular rarities spawn in zones; event rarities only spawn in the
-- main area during Watcher events (their monsters have fixed values instead).

export type Rarity = {
	id: string,
	order: number,
	spawnChance: number?, -- share of zone spawns, in percent (regular rarities only)
	valueMultiplier: number?, -- times the zone's Common value (regular rarities only)
	eventOnly: boolean,
	vacuumTier: number?, -- minimum vacuum tier needed to catch (Void Vac = 3)
}

local Rarities: { [string]: Rarity } = {
	Common = { id = "Common", order = 1, spawnChance = 45, valueMultiplier = 1, eventOnly = false },
	Uncommon = { id = "Uncommon", order = 2, spawnChance = 30, valueMultiplier = 3, eventOnly = false },
	Rare = { id = "Rare", order = 3, spawnChance = 15, valueMultiplier = 10, eventOnly = false },
	Epic = { id = "Epic", order = 4, spawnChance = 7, valueMultiplier = 40, eventOnly = false },
	Legendary = { id = "Legendary", order = 5, spawnChance = 2.5, valueMultiplier = 200, eventOnly = false },
	Mythic = {
		id = "Mythic",
		order = 6,
		spawnChance = 0.45,
		valueMultiplier = 1500,
		eventOnly = false,
		vacuumTier = 3,
	},
	Divine = {
		id = "Divine",
		order = 7,
		spawnChance = 0.05,
		valueMultiplier = 15000,
		eventOnly = false,
		vacuumTier = 3,
	},
	Phantom = { id = "Phantom", order = 8, eventOnly = true },
	-- Event rarities with big fixed values need a better vacuum, so their jackpots go to
	-- players who have progressed (set by the balance sheet, docs in /mnt/project-files/balance).
	Nightmare = { id = "Nightmare", order = 9, eventOnly = true, vacuumTier = 2 },
	Eldritch = { id = "Eldritch", order = 10, eventOnly = true, vacuumTier = 3 },
}

return Rarities
