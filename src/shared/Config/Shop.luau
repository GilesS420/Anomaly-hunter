--!strict
-- Two shops in the main area. Each restocks every RestockSeconds; restockChance is the
-- percent chance an item is in stock after a restock.
-- Prices and restock chances are set by the balance sheet, docs in /mnt/project-files/balance.
-- The upgrade order is Phantom Vac, Spirit Siphon, Library, Ballroom, Banshee Blower, Moon Vac,
-- Void Vac, each taking about 2-3x as long to afford as the one before. Vacuums are always in
-- stock (Util/Workshop.inStock), so their restockChance is not used. Slappers too.

export type Item = {
	id: string,
	name: string,
	kind: "Food" | "Vacuum" | "Lure" | "Charm" | "Tag" | "Potion" | "Slapper",
	price: number,
	restockChance: number,
	rarity: string, -- the tag in the shop window: a Config/Rarities id, or "Event" for event treats
	tier: number?, -- vacuum tier for size limits
	grantsEffect: string?,
	singleUse: boolean?,
	maxRarity: string?, -- Bait Bell: the rarest rarity it can bring
	lureSteps: number?, -- Bait Bell: how many rarities up from a normal roll (1 if not set)
	lureOdds: { [string]: number }?, -- Bait Bell: fixed odds per rarity instead (percent)
	-- Bakery chance cakes: tried in order, the first that hits (and fits) is the effect.
	effectChances: { EffectChance }?,
	event: string?, -- Bakery event treat: only sold while this Watcher event is live
	stockMin: number?, -- how many a player can buy per restock, instead of StockMin..StockMax
	stockMax: number?,
	potionBoost: number?, -- luck potion: multiplies the vacuum's variant chances
	potionSeconds: number?, -- luck potion: how long it lasts (only counts down while online)
}
export type EffectChance = { effect: string, chance: number } -- chance in percent

local Shop = {}

Shop.RestockSeconds = 5 * 60

-- How many of one single-use item (Bait Bell, Return Charm, a cake) a player can buy per
-- restock: a random number from StockMin to StockMax, new every restock and the same in every
-- server (Util/Workshop.limit; Giles 2026-10-21, it used to be always 3).
-- Vacuums are bought once and kept forever.
Shop.StockMin = 1
Shop.StockMax = 6

-- Selling a monster of this rarity or rarer at the Collector asks "are you sure?" first.
Shop.ConfirmSellFrom = "Legendary"

-- Haunted Bakery cakes. You set one out in your mansion (Config/Cakes) and monsters come for
-- a bite; a bite may give the cake's effect (a monster can't get an effect twice). Chance cakes (effectChances) may give one of several effects.
-- Prices are x100 like the monsters so they keep the same size relative to what a monster
-- sells for. Event treats (`event`) are only in stock while their Watcher event is live, so
-- an event's effect can be had after it's over. The Epic and rarer cakes are in stock about
-- twice as often as at first (Giles 2026-10-24: "a bit less rare").
Shop.Bakery = {
	-- Gives a Critter effect, so only cheap monsters (Config/Effects.CritterMaxValue) can get it.
	{
		id = "MoldyMuffin",
		name = "Moldy Muffin",
		kind = "Food",
		price = 5_000,
		restockChance = 90,
		rarity = "Common",
		grantsEffect = "Moldy",
	},
	{
		id = "PumpkinCandy",
		name = "Pumpkin Candy",
		kind = "Food",
		price = 50_000,
		restockChance = 80,
		rarity = "Common",
		grantsEffect = "PumpkinHead",
	},
	{
		id = "WebWaffle",
		name = "Web Waffle",
		kind = "Food",
		price = 500_000,
		restockChance = 100,
		rarity = "Event",
		grantsEffect = "Cobwebbed",
		event = "SpiderSeason",
	},
	{
		id = "FangFudge",
		name = "Fang Fudge",
		kind = "Food",
		price = 800_000,
		restockChance = 45,
		rarity = "Uncommon",
		effectChances = { { effect = "Vampire", chance = 35 } },
	},
	{
		id = "StaticCupcake",
		name = "Static Cupcake",
		kind = "Food",
		price = 2_000_000,
		restockChance = 100,
		rarity = "Event",
		grantsEffect = "Poltergeist",
		event = "Flicker",
	},
	{
		id = "EctoplasmPie",
		name = "Ectoplasm Pie",
		kind = "Food",
		price = 2_500_000,
		restockChance = 30,
		rarity = "Rare",
		grantsEffect = "Slimed",
	},
	{
		id = "PumpkinSpiceRoll",
		name = "Pumpkin Spice Roll",
		kind = "Food",
		price = 6_000_000,
		restockChance = 100,
		rarity = "Event",
		grantsEffect = "Harvested",
		event = "HarvestMoon",
	},
	{
		id = "BoneBiscuit",
		name = "Bone Biscuit",
		kind = "Food",
		price = 7_000_000,
		restockChance = 100,
		rarity = "Event",
		grantsEffect = "Skeletal",
		event = "BoneRattle",
	},
	{
		id = "FrostTart",
		name = "Frost Tart",
		kind = "Food",
		price = 8_000_000,
		restockChance = 100,
		rarity = "Event",
		grantsEffect = "Frostbitten",
		event = "FrostFog",
	},
	{
		id = "CauldronCupcake",
		name = "Cauldron Cupcake",
		kind = "Food",
		price = 20_000_000,
		restockChance = 100,
		rarity = "Event",
		grantsEffect = "Bewitched",
		event = "WitchingHour",
	},
	{
		id = "GildedTruffle",
		name = "Gilded Truffle",
		kind = "Food",
		price = 25_000_000,
		restockChance = 100,
		rarity = "Event",
		grantsEffect = "Gilded",
		event = "GoldRush",
	},
	{
		id = "SpiderStrudel",
		name = "Spider Strudel",
		kind = "Food",
		price = 9_000_000,
		restockChance = 35,
		rarity = "Rare",
		effectChances = { { effect = "Possessed", chance = 40 }, { effect = "Cobwebbed", chance = 100 } },
	},
	{
		id = "StitchCupcake",
		name = "Stitch Cupcake",
		kind = "Food",
		price = 30_000_000,
		restockChance = 15,
		rarity = "Epic",
		grantsEffect = "Stitched",
	},
	{
		id = "CursedCake",
		name = "Cursed Cake",
		kind = "Food",
		price = 250_000_000,
		restockChance = 4,
		rarity = "Legendary",
		grantsEffect = "Cursed",
	},
	{
		id = "BloodMoonPie",
		name = "Blood Moon Pie",
		kind = "Food",
		price = 300_000_000,
		restockChance = 100,
		rarity = "Event",
		grantsEffect = "Bloodmoon",
		event = "BloodMoon",
	},
	{
		id = "RiftRoll",
		name = "Rift Roll",
		kind = "Food",
		price = 350_000_000,
		restockChance = 100,
		rarity = "Event",
		grantsEffect = "Rifted",
		event = "BreachStorm",
	},
	{
		id = "BoneMarrowMousse",
		name = "Bone Marrow Mousse",
		kind = "Food",
		price = 400_000_000,
		restockChance = 5,
		rarity = "Legendary",
		effectChances = { { effect = "Mummy", chance = 25 }, { effect = "Batty", chance = 100 } },
	},
	{
		id = "GraveGateau",
		name = "Grave Gâteau",
		kind = "Food",
		price = 800_000_000,
		restockChance = 4,
		rarity = "Legendary",
		grantsEffect = "Buried",
	},
	{
		id = "MimicMacaron",
		name = "Mimic Macaron",
		kind = "Food",
		price = 1_500_000_000,
		restockChance = 100,
		rarity = "Event",
		grantsEffect = "Mimic",
		event = "MimicNight",
	},
	{
		id = "WitchsBrewTart",
		name = "Witch's Brew Tart",
		kind = "Food",
		price = 2_000_000_000,
		restockChance = 1.5,
		rarity = "Mythic",
		grantsEffect = "Hexed",
	},
	{
		id = "PhantomPavlova",
		name = "Phantom Pavlova",
		kind = "Food",
		price = 5_000_000_000,
		restockChance = 1,
		rarity = "Mythic",
		grantsEffect = "Spectral",
	},
	{
		id = "EclipseEclair",
		name = "Eclipse Éclair",
		kind = "Food",
		price = 15_000_000_000,
		restockChance = 0.4,
		rarity = "Divine",
		grantsEffect = "Eclipsed",
	},
	{
		id = "VoidVelvet",
		name = "Void Velvet Cake",
		kind = "Food",
		price = 60_000_000_000,
		restockChance = 0.25,
		rarity = "Divine",
		grantsEffect = "Voidtouched",
	},
} :: { Item }

Shop.Workshop = {
	{
		id = "DustBuster",
		name = "Dust Buster",
		kind = "Vacuum",
		price = 0,
		restockChance = 100,
		rarity = "Common",
		tier = 1,
	},
	{
		id = "BaitBell",
		name = "Bait Bell",
		kind = "Lure",
		price = 10_000,
		restockChance = 50,
		rarity = "Uncommon",
		singleUse = true,
		maxRarity = "Legendary",
	},
	-- Better bells (Giles 2026-10-22: more Bait Bell types). Mythic and Divine need a Void Vac,
	-- so with a weaker vacuum these bring the best rarity it can catch.
	{
		id = "SilverBell",
		name = "Silver Bell",
		kind = "Lure",
		price = 250_000,
		restockChance = 25,
		rarity = "Rare",
		singleUse = true,
		lureSteps = 2,
		maxRarity = "Mythic",
	},
	{
		id = "GoldBell",
		name = "Gold Bell",
		kind = "Lure",
		price = 5_000_000,
		restockChance = 8,
		rarity = "Epic",
		singleUse = true,
		lureOdds = { Legendary = 85, Mythic = 14, Divine = 1 },
	},
	{
		id = "PhantomVac",
		name = "Phantom Vac",
		kind = "Vacuum",
		price = 50_000,
		restockChance = 80,
		rarity = "Common",
		tier = 2,
	},
	{
		id = "SpiritSiphon",
		name = "Spirit Siphon",
		kind = "Vacuum",
		price = 250_000,
		restockChance = 60,
		rarity = "Uncommon",
		tier = 2,
	},
	{
		id = "BansheeBlower",
		name = "Banshee Blower",
		kind = "Vacuum",
		price = 70_000_000,
		restockChance = 25,
		rarity = "Rare",
		tier = 2,
	},
	{
		id = "MoonVac",
		name = "Moon Vac",
		kind = "Vacuum",
		price = 150_000_000,
		restockChance = 15,
		rarity = "Epic",
		tier = 2,
	},
	{
		id = "VoidVac",
		name = "Void Vac",
		kind = "Vacuum",
		price = 400_000_000,
		restockChance = 6,
		rarity = "Legendary",
		tier = 3,
	},
	-- Slappers (Giles 2026-10-28): nobody starts with one. Each is bought once and kept, always
	-- in stock; the best one you own is the one you slap with. Reach, push and how long a slapped
	-- thief can't steal are in Config/Slap.
	{
		id = "RubberGlove",
		name = "Rubber Glove",
		kind = "Slapper",
		price = 5_000,
		restockChance = 100,
		rarity = "Common",
	},
	{
		id = "BoneHand",
		name = "Bone Hand",
		kind = "Slapper",
		price = 100_000,
		restockChance = 100,
		rarity = "Uncommon",
	},
	{
		id = "GhoulClaw",
		name = "Ghoul Claw",
		kind = "Slapper",
		price = 2_500_000,
		restockChance = 100,
		rarity = "Rare",
	},
	{
		id = "WitchPaddle",
		name = "Witch's Paddle",
		kind = "Slapper",
		price = 60_000_000,
		restockChance = 100,
		rarity = "Epic",
	},
	{
		id = "TitanHand",
		name = "Titan Hand",
		kind = "Slapper",
		price = 500_000_000,
		restockChance = 100,
		rarity = "Legendary",
	},
	-- A convenience: it pays for itself in time saved once you hunt in zone 3.
	{
		id = "ReturnCharm",
		name = "Return Charm",
		kind = "Charm",
		price = 50_000,
		restockChance = 60,
		rarity = "Uncommon",
		singleUse = true,
	},
	-- Gives one of your monsters a name of your own (Giles 2026-10-22: for more attachment).
	-- Only sometimes in stock, 2 to 5 at a time. Naming gives no bonus.
	{
		id = "NameTag",
		name = "Name Tag",
		kind = "Tag",
		price = 100_000,
		restockChance = 35,
		rarity = "Rare",
		singleUse = true,
		stockMin = 2,
		stockMax = 5,
	},
	-- Luck potions (Giles 2026-10-23): drink one from the hotbar and your vacuum's chances of
	-- Silver, Gold, Shiny and Rainbow are multiplied while it lasts (Util/Potions). Super rare
	-- in the restock, one at a time. They don't stack: a stronger one replaces a weaker one.
	{
		id = "LuckyTonic",
		name = "Lucky Tonic",
		kind = "Potion",
		price = 2_000_000,
		restockChance = 15,
		rarity = "Epic",
		singleUse = true,
		stockMin = 1,
		stockMax = 1,
		potionBoost = 2,
		potionSeconds = 10 * 60,
	},
	{
		id = "GildedElixir",
		name = "Gilded Elixir",
		kind = "Potion",
		price = 50_000_000,
		restockChance = 5,
		rarity = "Legendary",
		singleUse = true,
		stockMin = 1,
		stockMax = 1,
		potionBoost = 3,
		potionSeconds = 10 * 60,
	},
	{
		id = "PrismDraught",
		name = "Prism Draught",
		kind = "Potion",
		price = 1_000_000_000,
		restockChance = 1.5,
		rarity = "Mythic",
		singleUse = true,
		stockMin = 1,
		stockMax = 1,
		potionBoost = 5,
		potionSeconds = 15 * 60,
	},
} :: { Item }

-- Tools that are no longer sold (flashlights and the Spirit Lens, replaced by vacuums in
-- 2026-10). Saves that own one get its price back in cash when they load.
Shop.Retired = {
	CandleLamp = 0,
	StrobeLight = 20_000,
	SpiritLens = 250_000,
	Moonbeam = 100_000_000,
} :: { [string]: number }

return Shop
