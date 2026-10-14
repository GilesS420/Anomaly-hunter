--!strict
-- Two shops in the main area. Each restocks every RestockSeconds; restockChance is the
-- percent chance an item is in stock after a restock.
-- Prices and restock chances are set by the balance sheet, docs in /mnt/project-files/balance.
-- The upgrade order is Phantom Vac, Spirit Siphon, Library, Ballroom, Banshee Blower, Moon Vac,
-- Void Vac, each taking about 2-3x as long to afford as the one before. The Phantom Vac is in
-- stock in 80% of restocks, so the first purchase doesn't stall on luck.

export type Item = {
	id: string,
	name: string,
	kind: "Food" | "Vacuum" | "Lure" | "Charm",
	price: number,
	restockChance: number,
	tier: number?, -- vacuum tier for size limits
	grantsEffect: string?,
	singleUse: boolean?,
	maxRarity: string?, -- Bait Bell: the rarest rarity it can bring
	familiarity: number?, -- Bakery treats: how much of the Familiarity bar it fills (0 to 1)
}

local Shop = {}

Shop.RestockSeconds = 5 * 60

-- How many of one single-use item (Bait Bell, Return Charm, a treat) a player can buy per restock.
-- Vacuums are bought once and kept forever.
Shop.ConsumablesPerRestock = 3

-- Selling a monster of this rarity or rarer at the Collector asks "are you sure?" first.
Shop.ConfirmSellFrom = "Legendary"

-- Haunted Bakery treats. Each one feeds one monster, fills part of its Familiarity bar and
-- gives it the treat's effect (a monster can't get an effect twice, and holds at most
-- Effects.MaxSlots), so treats are for your best monsters. Prices are x100 like the monsters
-- so they keep the same size relative to what a monster sells for. Everyday feeding is free
-- (Feed all), see Config/Care.
Shop.Bakery = {
	{
		id = "PumpkinCandy",
		name = "Pumpkin Candy",
		kind = "Food",
		price = 50_000,
		restockChance = 80,
		grantsEffect = "PumpkinHead",
		familiarity = 0.1,
	},
	{
		id = "EctoplasmPie",
		name = "Ectoplasm Pie",
		kind = "Food",
		price = 2_500_000,
		restockChance = 30,
		grantsEffect = "Slimed",
		familiarity = 0.25,
	},
	{
		id = "CursedCake",
		name = "Cursed Cake",
		kind = "Food",
		price = 250_000_000,
		restockChance = 2,
		grantsEffect = "Cursed",
		familiarity = 0.5,
	},
} :: { Item }

Shop.Workshop = {
	{ id = "DustBuster", name = "Dust Buster", kind = "Vacuum", price = 0, restockChance = 100, tier = 1 },
	{
		id = "BaitBell",
		name = "Bait Bell",
		kind = "Lure",
		price = 10_000,
		restockChance = 50,
		singleUse = true,
		maxRarity = "Legendary",
	},
	{
		id = "PhantomVac",
		name = "Phantom Vac",
		kind = "Vacuum",
		price = 50_000,
		restockChance = 80,
		tier = 2,
	},
	{
		id = "SpiritSiphon",
		name = "Spirit Siphon",
		kind = "Vacuum",
		price = 250_000,
		restockChance = 60,
		tier = 2,
	},
	{
		id = "BansheeBlower",
		name = "Banshee Blower",
		kind = "Vacuum",
		price = 70_000_000,
		restockChance = 25,
		tier = 2,
	},
	{ id = "MoonVac", name = "Moon Vac", kind = "Vacuum", price = 150_000_000, restockChance = 15, tier = 2 },
	{ id = "VoidVac", name = "Void Vac", kind = "Vacuum", price = 400_000_000, restockChance = 6, tier = 3 },
	-- A convenience: it pays for itself in time saved once you hunt in zone 3.
	{
		id = "ReturnCharm",
		name = "Return Charm",
		kind = "Charm",
		price = 50_000,
		restockChance = 60,
		singleUse = true,
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
