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
	ItemTier1 = { id = 0, price = 19, name = "Shop item: small" },
	ItemTier2 = { id = 0, price = 49, name = "Shop item: medium" },
	ItemTier3 = { id = 0, price = 99, name = "Shop item: large" },
	ItemTier4 = { id = 0, price = 199, name = "Shop item: huge" },
	ItemTier5 = { id = 0, price = 399, name = "Shop item: legendary" },
	-- New Bakery and Workshop stock for the buyer only, until the next restock.
	ShopReroll = { id = 0, price = 29, name = "Shop Reroll" },
	-- One more daily mission reroll, used straight away on the mission tapped.
	MissionReroll = { id = 0, price = 15, name = "Mission Reroll" },
	-- Finishes one daily mission (it still has to be claimed).
	MissionSkip = { id = 0, price = 39, name = "Mission Skip" },
	-- Once per player.
	StarterPack = { id = 0, price = 49, name = "Starter Pack" },
} :: { [string]: Product }

-- Which item product a shop item uses: the first tier whose maxCash its cash price fits under.
Robux.ItemTiers = {
	{ product = "ItemTier1", maxCash = 1_000_000 },
	{ product = "ItemTier2", maxCash = 50_000_000 },
	{ product = "ItemTier3", maxCash = 1_000_000_000 },
	{ product = "ItemTier4", maxCash = 20_000_000_000 },
	{ product = "ItemTier5", maxCash = math.huge },
}

-- Game Passes: bought once, kept forever. Owning one sets the player attribute Pass<Key>.
Robux.Passes = {
	BigStorage = { id = 0, price = 149, name = "Big Storage" },
	LuckyHunter = { id = 0, price = 399, name = "Lucky Hunter" },
	VIP = { id = 0, price = 299, name = "VIP Hunter" },
	CakePlate = { id = 0, price = 249, name = "Extra Cake Plate" },
} :: { [string]: Product }

-- The order passes are listed in the Store window, with what each one does.
Robux.PassOrder = { "BigStorage", "LuckyHunter", "VIP", "CakePlate" }
Robux.PassText = {
	BigStorage = "Storage holds 120 monsters instead of 50",
	LuckyHunter = "Silver, Gold, Shiny and Rainbow catches x1.5, forever. Stacks with potions",
	VIP = "Gold VIP tag, +10% at the Collector, 1 extra free mission reroll a day and x1.5 Silver, Gold, Shiny and Rainbow catches",
	CakePlate = "6 cakes out per wing instead of 5",
} :: { [string]: string }

-- What the passes do (server/Perks reads these).
Robux.BigStorageSlots = 120
Robux.LuckyHunterBoost = 1.5 -- on variant chances; stacks with VIP and potions
Robux.VipLuckBoost = 1.5
Robux.VipSellBoost = 1.1 -- the Collector pays 10% more
Robux.VipRerolls = 1 -- extra free mission rerolls a day
Robux.CakePlatePerWing = 6

Robux.MissionRerollsPerDay = 5 -- most Mission Rerolls one player can buy a day

Robux.StarterPack = { SilverBell = 3, LuckyTonic = 1, ReturnCharm = 5 } :: { [string]: number }
Robux.StarterText = "3 Silver Bells, 1 Lucky Tonic and 5 Return Charms. Once per player."

Robux.ReceiptsKept = 100 -- purchase ids remembered per player, so a retry never pays out twice

return Robux
