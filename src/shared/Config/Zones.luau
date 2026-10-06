--!strict
-- Haunted zones, reached through the Zone Gates. Each opens with the matching wing.

export type Zone = {
	id: string,
	index: number,
	name: string,
	wing: string,
	launch: boolean,
}

local Zones: { Zone } = {
	{ id = "PumpkinGraveyard", index = 1, name = "Pumpkin Graveyard", wing = "Foyer", launch = true },
	{ id = "MurkyBayou", index = 2, name = "Murky Bayou", wing = "Library", launch = true },
	{ id = "AbandonedCarnival", index = 3, name = "Abandoned Carnival", wing = "Ballroom", launch = true },
	{ id = "SpookySchool", index = 4, name = "Spooky School", wing = "Attic", launch = false },
	{ id = "GhostShip", index = 5, name = "Ghost Ship", wing = "Crypt", launch = false },
}

-- One monster per trip. Losing all hearts drops the carried monster.
return {
	List = Zones,
	MaxHearts = 3,
	CarryLimit = 1,
	-- Monsters roaming a zone at once: clamp(AliveBase + AlivePerHunter x hunters in the zone,
	-- MaxAlive, MaxAliveCap), so 12 for 1-3 hunters and up to 24 when a zone is crowded
	-- (Spawning.aliveTarget). Set by the balance sheet, docs in /mnt/project-files/balance.
	MaxAlive = 12,
	AliveBase = 6,
	AlivePerHunter = 2,
	MaxAliveCap = 24,
	RespawnSeconds = 8, -- delay before a caught monster is replaced (balance sheet input)
}
