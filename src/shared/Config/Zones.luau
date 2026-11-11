--!strict
-- Haunted zones, reached through the Zone Gates. Each opens with the matching wing.
-- `id` is what saves and Studio folders use; `name` is what players see.

local Names = require("./Names")

export type Zone = {
	id: string,
	index: number,
	name: string,
	wing: string,
	launch: boolean,
	-- Left out of Breach Storm's monster mix (newer zones are worth 4x more each, so a storm
	-- would pay far more than the other events).
	noBreach: boolean?,
}

local Zones: { Zone } = {
	{ id = "PumpkinGraveyard", index = 1, name = "Pumpkin Graveyard", wing = "Foyer", launch = true },
	{ id = "MurkyBayou", index = 2, name = Names.MurkyBayou, wing = "Library", launch = true },
	{ id = "AbandonedCarnival", index = 3, name = "Abandoned Carnival", wing = "Ballroom", launch = true },
	-- Opened 2026-11-11 (thread "Add fresh content to match the market").
	{
		id = "SpookySchool",
		index = 4,
		name = "Spooky School",
		wing = "Attic",
		launch = true,
		noBreach = true,
	},
	{ id = "GhostShip", index = 5, name = "Ghost Ship", wing = "Crypt", launch = false },
}

-- One monster per trip. Losing all hearts drops the carried monster.
return {
	List = Zones,
	MaxHearts = 3,
	CarryLimit = 1,
	-- Monsters roaming a zone at once: clamp(AliveBase + AlivePerHunter x hunters in the zone,
	-- MaxAlive, MaxAliveCap), so 18 for 1-4 hunters and up to 30 when a zone is crowded
	-- (Spawning.aliveTarget). Raised from 12/24 (Giles 2026-10-22: more monsters roaming).
	MaxAlive = 18,
	AliveBase = 10,
	AlivePerHunter = 2,
	MaxAliveCap = 30,
	RespawnSeconds = 5, -- delay before a caught monster is replaced (was 8)
}
