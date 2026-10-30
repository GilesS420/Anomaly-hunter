--!strict
-- Everything sold for Robux (Sprint E, Giles picked these on 2026-10-29). Paying players get
-- the same things as everyone else, only faster; VIP Hunter is the one perk money alone buys.
-- Monsters are never sold for Robux.
--
-- The ids come from the Creator Dashboard: Developer Products under Monetization >
-- Developer Products, Game Passes under Monetization > Passes. Paste each id over the 0.
-- Anything still at 0 shows "Robux · soon" in the game and can't be bought. The Robux price
-- shown in the game is read from Roblox, so the dashboard decides it; `price` here is only
-- what the dashboard should be set to (and what shows if Roblox can't be asked).

export type Product = { id: number, price: number, name: string }

local Robux = {}

-- Developer Products: bought again and again.
Robux.Products = {
	-- A shop item paid in Robux. Every Bakery, Workshop and Vault item falls into one of these by
	-- its cash price (Robux.ItemTiers), so 5 products cover the whole shop.
	ItemTier1 = { id = 3723585400, price = 19, name = "Shop item: small" },
	ItemTier2 = { id = 3723585507, price = 49, name = "Shop item: medium" },
	ItemTier3 = { id = 3723585595, price = 99, name = "Shop item: large" },
	ItemTier4 = { id = 3723585744, price = 199, name = "Shop item: huge" },
	ItemTier5 = { id = 3723585809, price = 399, name = "Shop item: legendary" },
	-- New Bakery and Workshop stock for the buyer only, until the next restock.
	ShopReroll = { id = 3723585894, price = 29, name = "Shop Reroll" },
	-- Swaps every daily mission that isn't done yet (Giles 2026-10-29).
	MissionReroll = { id = 3723585979, price = 15, name = "Mission Reroll" },
	-- Finishes one daily mission (it still has to be claimed).
	MissionSkip = { id = 3723586069, price = 39, name = "Mission Skip" },
	-- Once per player.
	StarterPack = { id = 3723586118, price = 49, name = "Starter Pack" },
} :: { [string]: Product }

-- Which item product a shop item uses: the first tier whose maxCash its cash price fits under.
Robux.ItemTiers = {
	{ product = "ItemTier1", maxCash = 1_000_000 },
	{ product = "ItemTier2", maxCash = 50_000_000 },
	{ product = "ItemTier3", maxCash = 1_000_000_000 },
	{ product = "ItemTier4", maxCash = 20_000_000_000 },
	{ product = "ItemTier5", maxCash = math.huge },
}

-- Items whose Robux price doesn't follow their cash price (Giles 2026-10-30): every vacuum
-- and slapper costs more than the one before it, so the best isn't the same price as a
-- weaker one.
Robux.ItemProducts = {
	PhantomVac = "ItemTier1", -- 19
	SpiritSiphon = "ItemTier2", -- 49
	BansheeBlower = "ItemTier3", -- 99
	MoonVac = "ItemTier4", -- 199
	VoidVac = "ItemTier5", -- 399
	CobwebMitt = "ItemTier1", -- 19
	RubberGlove = "ItemTier1", -- 19
	BoneHand = "ItemTier2", -- 49
	GhoulClaw = "ItemTier3", -- 99
	WitchPaddle = "ItemTier4", -- 199
	TitanHand = "ItemTier5", -- 399
	EclipseEclair = "ItemTier5", -- 399
	PrismDraught = "ItemTier4", -- 199: a $1B potion (Giles 2026-10-30)
} :: { [string]: string }

-- Game Passes: bought once, kept forever. Owning one sets the player attribute Pass<Key>.
Robux.Passes = {
	BigStorage = { id = 2060795150, price = 149, name = "Big Storage" },
	LuckyHunter = { id = 2060705121, price = 399, name = "Lucky Hunter" },
	VIP = { id = 2058107865, price = 599, name = "VIP Hunter" },
	CakePlate = { id = 2061580544, price = 149, name = "Extra Cake Plate" },
	-- Giles added this one himself (2026-10-29): twice the walking speed everywhere.
	FastWalk = { id = 2061754519, price = 149, name = "Faster walking speed" },
} :: { [string]: Product }

-- The order passes are listed in the Store window, with what each one does.
Robux.PassOrder = { "BigStorage", "LuckyHunter", "VIP", "CakePlate", "FastWalk" }
Robux.PassText = {
	BigStorage = "Storage holds 120 monsters instead of 50",
	LuckyHunter = "Silver, Gold, Shiny and Rainbow catches x1.5, forever. Stacks with potions",
	VIP = "Gold VIP tag, +10% at the Collector, 1 extra free mission reroll a day and x1.5 Silver, Gold, Shiny and Rainbow catches",
	CakePlate = "6 cakes out per wing instead of 5",
	FastWalk = "Walk twice as fast, in the hub, the zones and your mansion",
} :: { [string]: string }

-- What the passes do (server/Perks reads these).
Robux.BigStorageSlots = 120
Robux.LuckyHunterBoost = 1.5 -- on variant chances; stacks with VIP and potions
Robux.VipLuckBoost = 1.5
Robux.VipSellBoost = 1.1 -- the Collector pays 10% more
Robux.VipRerolls = 1 -- extra free mission rerolls a day
Robux.CakePlatePerWing = 6
Robux.FastWalkMultiplier = 2 -- on WalkSpeed (not while a monster has you slowed)

Robux.MissionRerollsPerDay = 5 -- most Mission Rerolls one player can buy a day

Robux.StarterPack = { SilverBell = 3, LuckyTonic = 1, ReturnCharm = 5 } :: { [string]: number }
Robux.StarterText = "3 Silver Bells, 1 Lucky Tonic and 5 Return Charms. Once per player."

Robux.ReceiptsKept = 100 -- purchase ids remembered per player, so a retry never pays out twice

return Robux
