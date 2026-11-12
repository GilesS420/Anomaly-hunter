--!strict
-- The Lucky Spin (thread "Add fresh content to match the market", 2026-11-11): a prize wheel,
-- the daily "come back tomorrow" hook most top Roblox games have. Rules in Util/Spin,
-- server/Services/SpinService spins it, client/Controllers/SpinController draws the wheel.
--
-- Extra spins can be bought for Robux (Giles 2026-11-12, thread "Turn lucky spin into a real
-- wheel"; products Spins1 and Spins5 in Config/Robux). Roblox's rules for paid random items:
-- every slice shows its odds on the wheel, and players whose country restricts paid random
-- items (PolicyService.ArePaidRandomItemsRestricted) don't see the Robux buttons at all.
-- Bought spins keep: they don't run out at the end of the day like the free ones.
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
	monster: string?, -- a monster of this rarity from a zone the player has opened (Util/Spin)
	jackpot: boolean?, -- the big one: a gold slice, and everyone in the server hears of it
}

local Spin = {}

Spin.FreePerDay = 1
Spin.PlayMinutes = { 15, 45 } -- one more spin after this many minutes of play today

-- Clockwise round the wheel from the top; every slice is drawn the same size, with its odds
-- (weight %) written on it. Weights add up to 100. Monster slices alternate with the rest so
-- they're spread round the wheel, each in its rarity's colour (as in MonsterModel).
-- Monster prizes stay rare (19% in all, a Mythic 1%) so they're still a moment, and the
-- Legendary or Mythic comes about once every 8 days on free spins (Giles wants rarities grindy;
-- he asked for more monster slices on 2026-11-12).
Spin.Prizes = {
	{ id = "Cash", weight = 24, color = { 90, 170, 110 }, share = 0.02, floor = 2_000 },
	{ id = "Rare", weight = 9, color = { 70, 140, 255 }, monster = "Rare" },
	{ id = "Cake", weight = 14, color = { 220, 120, 160 }, pick = "Cake" },
	{ id = "Charms", weight = 10, color = { 90, 190, 200 }, item = "ReturnCharm", count = 2 },
	{ id = "Epic", weight = 6, color = { 170, 80, 255 }, monster = "Epic" },
	{ id = "BigCash", weight = 12, color = { 50, 120, 80 }, share = 0.05, floor = 5_000 },
	{ id = "Bell", weight = 11, color = { 200, 150, 80 }, pick = "Bell" },
	{ id = "Legendary", weight = 3, color = { 255, 150, 30 }, monster = "Legendary" },
	{ id = "Tonic", weight = 5, color = { 120, 200, 120 }, item = "LuckyTonic" },
	{ id = "GoldBell", weight = 3, color = { 230, 190, 60 }, item = "GoldBell" },
	{ id = "Mythic", weight = 1, color = { 255, 55, 55 }, monster = "Mythic" },
	{ id = "Jackpot", weight = 2, color = { 255, 211, 107 }, share = 0.25, floor = 25_000, jackpot = true },
} :: { Prize }

-- Bought spins (Robux products Spins1 and Spins5): how many each product gives.
Spin.Bundles = { Spins1 = 1, Spins5 = 5 } :: { [string]: number }

return Spin
