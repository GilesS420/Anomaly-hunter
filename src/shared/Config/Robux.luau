--!strict
-- Everything sold for Robux (Sprint E, Giles picked these on 2026-10-29). Paying players get
-- the same things as everyone else, only faster; VIP Hunter is the one perk money alone buys.
-- Monsters are never sold for Robux, except by stealing one from another player (Steal1-6),
-- and the 3% Legendary slice on a bought Lucky Spin (Giles asked for it, 2026-11-12).
--
-- The ids come from the Creator Dashboard: Developer Products under Monetization >
-- Developer Products, Game Passes under Monetization > Passes. Paste each id over the 0.
-- Anything still at 0 shows "Robux · soon" in the game and can't be bought. The Robux price
-- shown in the game is read from Roblox, so the dashboard decides it; `price` here is only
-- what the dashboard should be set to (and what shows if Roblox can't be asked).

-- `tier` is set on an item's own product (see ItemProducts): the shared ItemTier product it
-- falls back to while its own id is still 0.
export type Product = { id: number, price: number, name: string, tier: string? }

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
	-- Items with a product of their own (Giles 2026-11-04), so Roblox's purchase prompt shows
	-- that item's own picture and name instead of a shared "Shop item" one. While an id is
	-- still 0 the item is sold through its `tier` product instead, so nothing breaks before
	-- they're made on the dashboard.
	ItemPhantomVac = { id = 3728313540, price = 19, name = "Phantom Vac", tier = "ItemTier1" },
	ItemSpiritSiphon = { id = 3728313835, price = 39, name = "Spirit Siphon", tier = "ItemTier2" },
	ItemBansheeBlower = { id = 3728314073, price = 49, name = "Banshee Blower", tier = "ItemTier3" },
	ItemMoonVac = { id = 3728314254, price = 199, name = "Moon Vac", tier = "ItemTier4" },
	ItemVoidVac = { id = 3728314987, price = 399, name = "Void Vac", tier = "ItemTier5" },
	ItemCobwebMitt = { id = 3728316774, price = 19, name = "Cobweb Mitt", tier = "ItemTier1" },
	ItemRubberGlove = { id = 3728317505, price = 19, name = "Rubber Glove", tier = "ItemTier1" },
	ItemBoneHand = { id = 3728317640, price = 49, name = "Bone Hand", tier = "ItemTier2" },
	ItemGhoulClaw = { id = 3728317896, price = 99, name = "Ghoul Claw", tier = "ItemTier3" },
	ItemWitchPaddle = { id = 3728318189, price = 199, name = "Witch's Paddle", tier = "ItemTier4" },
	ItemTitanHand = { id = 3728318321, price = 399, name = "Titan Hand", tier = "ItemTier5" },
	ItemEclipseEclair = { id = 3728320070, price = 399, name = "Eclipse Éclair", tier = "ItemTier5" },
	ItemPrismDraught = { id = 3728320624, price = 199, name = "Prism Draught", tier = "ItemTier4" },
	-- New Bakery and Workshop stock for the buyer only, until the next restock.
	ShopReroll = { id = 3723585894, price = 29, name = "Shop Reroll" },
	-- Swaps every daily mission that isn't done yet (Giles 2026-10-29).
	MissionReroll = { id = 3723585979, price = 15, name = "Mission Reroll" },
	-- Finishes one daily mission (it still has to be claimed).
	MissionSkip = { id = 3723586069, price = 39, name = "Mission Skip" },
	-- Lucky Spins (Giles 2026-11-12): spins that keep until used. The wheel shows every
	-- slice's odds, and players whose country restricts paid random items can't buy them.
	Spins1 = { id = 0, price = 19, name = "Lucky Spin" },
	Spins5 = { id = 0, price = 79, name = "5 Lucky Spins" },
	-- Once per player.
	StarterPack = { id = 3723586118, price = 30, name = "Starter Pack" },
	-- Stealing a monster from another player's mansion (Config/Heists, Giles 2026-10-30):
	-- hold E on it. The price goes by what it's worth; a hearted one costs a step more.
	-- Prices lowered by Giles on the dashboard (2026-11-04).
	Steal1 = { id = 3728028014, price = 9, name = "Steal a monster (up to $1M)" },
	Steal2 = { id = 3728028069, price = 29, name = "Steal a monster (up to $50M)" },
	Steal3 = { id = 3728028116, price = 39, name = "Steal a monster (up to $1B)" },
	Steal4 = { id = 3728028179, price = 99, name = "Steal a monster (up to $20B)" },
	Steal5 = { id = 3728028284, price = 119, name = "Steal a monster (over $20B)" },
	Steal6 = { id = 3728028373, price = 299, name = "Steal a hearted monster (over $20B)" },
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
-- weaker one. Each has its own product (above) so the purchase prompt shows its picture.
Robux.ItemProducts = {
	PhantomVac = "ItemPhantomVac", -- 19
	SpiritSiphon = "ItemSpiritSiphon", -- 39 (Giles lowered it, 2026-11-04)
	BansheeBlower = "ItemBansheeBlower", -- 49 (Giles lowered it, 2026-11-04)
	MoonVac = "ItemMoonVac", -- 199
	VoidVac = "ItemVoidVac", -- 399
	CobwebMitt = "ItemCobwebMitt", -- 19
	RubberGlove = "ItemRubberGlove", -- 19
	BoneHand = "ItemBoneHand", -- 49
	GhoulClaw = "ItemGhoulClaw", -- 99
	WitchPaddle = "ItemWitchPaddle", -- 199
	TitanHand = "ItemTitanHand", -- 399
	EclipseEclair = "ItemEclipseEclair", -- 399
	PrismDraught = "ItemPrismDraught", -- 199
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
