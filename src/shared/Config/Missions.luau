--!strict
-- Daily missions (Giles 2026-10-28, proposal page https://claude.ai/artifact/KPa8CLxWeQmdq9dTp4EXL3).
-- Every day at 00:00 UTC each player is dealt one Easy, one Medium and one Hard mission from
-- the pool below, and finishing all three opens a bonus chest. Rewards follow the player's
-- worth (cash plus what all their monsters would sell for), measured once when the day's
-- missions are dealt, so selling or buying right before the reset doesn't change them.
-- A streak of days with at least one claimed mission adds StreakStep per day, up to
-- StreakMax. Util/Missions has the rules, server/Services/MissionService runs them and
-- client/Controllers/MissionController draws the window. Placeholders, tune in playtesting.

export type Tier = { id: string, share: number, floor: number }

-- How a mission counts, see Util/Missions.progress:
--   Catch        any catch (zone: only in that zone; minRarity: that rarity or better;
--                variant: only Silver, Gold, Shiny or Rainbow; lucky: Perfect Catches;
--                hub: event monsters in the main area)
--   Species      different monsters caught in the zone (count of them)
--   ZoneSet      every monster of the zone up to maxRarity
--   Sell         money earned at the Collector (target = moneyShare of worth, at least moneyFloor)
--   PlaceCake    cakes placed in the mansion
--   Effect       effects picked up by mansion monsters (haunting, events, cakes)
--   Combo        a combo turning up on a monster
--   Merge        merges tried (won: only ones that worked)
--   Grow         monsters put in the Growth Chamber
--   GoldenGhost  Golden Ghosts caught
export type Mission = {
	id: string,
	tier: string,
	kind: string,
	text: string, -- {n} is the target, {zone} the zone's name, {money} the money target
	count: number?, -- target (money targets come from moneyShare instead)
	zone: boolean?, -- picks one of the player's open zones
	minRarity: string?,
	maxRarity: string?,
	variant: boolean?,
	lucky: boolean?,
	hub: boolean?,
	won: boolean?,
	moneyShare: number?,
	moneyFloor: number?,
	-- How much work it is next to the other missions of its tier: the reward is the tier's
	-- share of worth times this (1 when left out).
	effort: number?,
	-- Money missions: the reward is at least this share of the money target, so it grows
	-- with the task (Giles 2026-10-29: selling $1.4B for $420M felt far too low).
	targetPay: number?,
}

local Missions = {}

-- Seconds after 00:00 UTC that the day turns over (0: midnight UTC, 01:00 in Belgium in winter).
Missions.ResetOffset = 0

-- Each tier pays `share` of the player's worth (times the mission's effort), at least `floor`.
Missions.Tiers = {
	{ id = "Easy", share = 0.03, floor = 2_000 },
	{ id = "Medium", share = 0.06, floor = 4_000 },
	{ id = "Hard", share = 0.10, floor = 8_000 },
} :: { Tier }

-- The bonus chest for finishing all three: cash plus a Bakery cake costing up to
-- ChestCakeTimesCash times the cash (the cheapest one if none is that cheap).
Missions.ChestShare = 0.06
Missions.ChestFloor = 5_000
Missions.ChestCakeTimesCash = 3

Missions.StreakStep = 0.10 -- +10% on every reward per day of streak
Missions.StreakMax = 0.50

Missions.Rerolls = 1 -- free rerolls a day

Missions.Pool = {
	-- Easy
	{ id = "Catch8", tier = "Easy", kind = "Catch", count = 8, text = "Catch {n} monsters" },
	{
		id = "SellSmall",
		tier = "Easy",
		kind = "Sell",
		moneyShare = 0.05,
		moneyFloor = 5_000,
		targetPay = 0.8,
		text = "Sell monsters for {money}",
	},
	{ id = "Cakes2", tier = "Easy", kind = "PlaceCake", count = 2, text = "Place {n} cakes in your mansion" },
	{
		id = "Effects2",
		tier = "Easy",
		kind = "Effect",
		count = 2,
		text = "Let your monsters pick up {n} effects",
	},
	{
		id = "Zone3",
		tier = "Easy",
		kind = "Catch",
		count = 3,
		zone = true,
		text = "Catch {n} monsters in {zone}",
	},

	-- Medium
	{
		id = "Species4",
		effort = 1.3,
		tier = "Medium",
		kind = "Species",
		count = 4,
		zone = true,
		text = "Catch {n} different monsters in {zone}",
	},
	{ id = "Merge2", effort = 1.2, tier = "Medium", kind = "Merge", count = 2, text = "Merge {n} times" },
	{
		id = "Grow1",
		effort = 1.2,
		tier = "Medium",
		kind = "Grow",
		count = 1,
		text = "Put a monster in the Growth Chamber",
	},
	{
		id = "Effects5",
		effort = 1.2,
		tier = "Medium",
		kind = "Effect",
		count = 5,
		text = "Let your monsters pick up {n} effects",
	},
	{
		id = "Rare1",
		tier = "Medium",
		kind = "Catch",
		count = 1,
		minRarity = "Rare",
		text = "Catch a Rare or better",
	},
	{
		id = "Perfect3",
		effort = 1.3,
		tier = "Medium",
		kind = "Catch",
		count = 3,
		lucky = true,
		text = "Land {n} Perfect Catches",
	},
	{
		id = "Event1",
		effort = 1.3,
		tier = "Medium",
		kind = "Catch",
		count = 1,
		hub = true,
		text = "Catch an event monster in the main area",
	},

	-- Hard
	{
		id = "ZoneSet",
		effort = 2,
		tier = "Hard",
		kind = "ZoneSet",
		zone = true,
		maxRarity = "Rare",
		text = "Catch every Common, Uncommon and Rare in {zone}",
	},
	{
		id = "SellBig",
		tier = "Hard",
		kind = "Sell",
		moneyShare = 0.30,
		moneyFloor = 25_000,
		targetPay = 0.8,
		text = "Earn {money} selling monsters",
	},
	{
		id = "MergeWin",
		effort = 1.3,
		tier = "Hard",
		kind = "Merge",
		count = 1,
		won = true,
		text = "Win a merge",
	},
	{
		id = "Epic1",
		effort = 1.3,
		tier = "Hard",
		kind = "Catch",
		count = 1,
		minRarity = "Epic",
		text = "Catch an Epic or better",
	},
	{
		id = "Variant1",
		effort = 1.5,
		tier = "Hard",
		kind = "Catch",
		count = 1,
		variant = true,
		text = "Catch a Silver, Gold, Shiny or Rainbow monster",
	},
	{
		id = "Combo1",
		effort = 1.5,
		tier = "Hard",
		kind = "Combo",
		count = 1,
		text = "Make a combo appear on a monster",
	},
	{
		id = "Ghost1",
		effort = 1.5,
		tier = "Hard",
		kind = "GoldenGhost",
		count = 1,
		text = "Catch the Golden Ghost",
	},
} :: { Mission }

return Missions
