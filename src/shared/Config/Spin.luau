--!strict
-- The Lucky Spin (thread "Add fresh content to match the market", 2026-11-11): a free prize
-- wheel, the daily "come back tomorrow" hook most top Roblox games have. Free only: spins are
-- never sold for Robux (no paid gambling). Rules in Util/Spin, server/Services/SpinService
-- spins it, client/Controllers/SpinController draws the wheel.
--
-- A player gets FreePerDay spins when the day starts (the same day as the daily missions,
-- Config/Missions.ResetOffset) and one more after each of PlayMinutes minutes of play that
-- day. Spins don't carry over to the next day.
--
-- Cash prizes are a share of the same "base" as the playtime gifts (worth plus a share of what
-- wings and tools cost, Util/Playtime.base), so they stay worth having late in the game. A
-- spin pays about 2% of base in cash on average (plus the items), so even all three spins a
-- day are well under the playtime gifts (17% of base a day).

export type Prize = {
	id: string,
	weight: number, -- chance, out of the total of all weights
	color: { number }, -- the slice's colour on the wheel
	share: number?, -- cash: this share of base, at least `floor`
	floor: number?,
	item: string?, -- a fixed Workshop item
	count: number?, -- how many of the item (default 1)
	pick: ("Bell" | "Cake")?, -- an item picked for their progress, like the playtime gifts
	jackpot: boolean?, -- the big one: a gold slice, and everyone in the server hears of it
}

local Spin = {}

Spin.FreePerDay = 1
Spin.PlayMinutes = { 15, 45 } -- one more spin after this many minutes of play today

-- Clockwise round the wheel from the top. Weights add up to 100.
Spin.Prizes = {
	{ id = "Cash", weight = 30, color = { 90, 170, 110 }, share = 0.02, floor = 2_000 },
	{ id = "Cake", weight = 18, color = { 220, 120, 160 }, pick = "Cake" },
	{ id = "Charms", weight = 12, color = { 110, 150, 230 }, item = "ReturnCharm", count = 2 },
	{ id = "BigCash", weight = 15, color = { 60, 140, 90 }, share = 0.05, floor = 5_000 },
	{ id = "Bell", weight = 14, color = { 200, 160, 80 }, pick = "Bell" },
	{ id = "Tonic", weight = 6, color = { 150, 100, 220 }, item = "LuckyTonic" },
	{ id = "GoldBell", weight = 3, color = { 230, 190, 60 }, item = "GoldBell" },
	{ id = "Jackpot", weight = 2, color = { 255, 211, 107 }, share = 0.25, floor = 25_000, jackpot = true },
} :: { Prize }

return Spin
