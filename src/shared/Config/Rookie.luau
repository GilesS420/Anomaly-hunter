--!strict
-- The rookie hour (Giles 2026-11-05: new players left after about 5 minutes). Right after the
-- tutorial a new player gets RookieMinutes of play time with a Collector bonus, and their
-- LuckyHunt-th hunt has a monster of LuckyRarity waiting for them, reserved like a Bait Bell's.
-- Only saves that start the tutorial get it; older players never do (server RookieService).

return {
	Minutes = 30, -- play time (online only) after the tutorial, not clock time
	SellBonusPercent = 100, -- +100% at the Collector: x2 sell money
	LuckyHunt = 3, -- the third trip into a zone after the tutorial
	LuckyRarity = "Rare", -- the waiting monster is the zone's monster of this rarity
}
