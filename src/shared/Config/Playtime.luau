--!strict
-- Playtime gifts (Giles 2026-11-05): a gift after 2, 5, 10, 20, 40 and 60 minutes of play a day,
-- scaled to the player's economy, open zones and tools. The clock only runs while they're
-- online and past the tutorial, is saved (rejoining keeps it, so it can't be farmed) and starts
-- over when the daily missions do (Config/Missions.ResetOffset). Rules in Util/Playtime,
-- server/Services/PlaytimeService runs them, client/Controllers/PlaytimeController draws them.
--
-- "Base" for cash and cakes: worth (cash plus what every monster would sell for, like the daily
-- missions) plus InvestShare of what their wings and tools cost, so buying a wing doesn't make
-- the gifts smaller.

export type Step = {
	minutes: number,
	share: number?, -- cash: this share of base, at least `floor`
	floor: number?,
	item: string?, -- a fixed Workshop item
	pick: ("Bell" | "Cake")?, -- an item picked for their progress (Util/Playtime.reward)
}

local Playtime = {}

Playtime.Steps = {
	{ minutes = 2, share = 0.02, floor = 2_000 },
	{ minutes = 5, pick = "Bell" },
	{ minutes = 10, pick = "Cake" },
	{ minutes = 20, share = 0.05, floor = 5_000 },
	{ minutes = 40, item = "LuckyTonic" },
	{ minutes = 60, item = "GoldBell", share = 0.10, floor = 10_000 },
} :: { Step }

Playtime.InvestShare = 0.10
-- The cake gift: the priciest Bakery cake up to this share of base (the cheapest if none is).
Playtime.CakeShare = 0.04
-- The bell gift: a Silver Bell once this many wings are owned (Ballroom opens zone 3), else a
-- Bait Bell.
Playtime.SilverBellWings = 3

return Playtime
