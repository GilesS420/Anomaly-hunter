--!strict
-- Two shops in the main area. Each restocks every RestockSeconds; restockChance is the
-- percent chance an item is in stock after a restock.
-- Prices and restock chances are set by the balance sheet, docs in /mnt/project-files/balance.
-- The upgrade order is Strobe Light, Phantom Vac, Spirit Lens, Library, Ballroom, Moonbeam,
-- Void Vac, each taking about 2-3x as long to afford as the one before. The Strobe Light is
-- always in stock and the Phantom Vac in 80% of restocks, so first purchases don't stall on luck.

export type Item = {
	id: string,
	name: string,
	kind: "Food" | "Vacuum" | "Flashlight" | "Lure" | "Lens" | "Charm",
	price: number,
	restockChance: number,
	tier: number?, -- vacuum tier for size limits
	grantsEffect: string?,
	singleUse: boolean?,
	maxRarity: string?, -- Bait Bell: the rarest rarity it can bring
}

local Shop = {}

Shop.RestockSeconds = 5 * 60

-- How many of one single-use item (Bait Bell, Return Charm) a player can buy per restock.
-- Tools (vacuums, flashlights, lenses) are bought once and kept forever.
Shop.ConsumablesPerRestock = 3

-- Selling a monster of this rarity or rarer at the Collector asks "are you sure?" first.
Shop.ConfirmSellFrom = "Legendary"

-- Food isn't built yet; prices are x100 like the monsters so they keep the same size
-- relative to what a monster sells for.
Shop.Bakery = {
	{
		id = "PumpkinCandy",
		name = "Pumpkin Candy",
		kind = "Food",
		price = 50_000,
		restockChance = 80,
		grantsEffect = "PumpkinHead",
	},
	{
		id = "EctoplasmPie",
		name = "Ectoplasm Pie",
		kind = "Food",
		price = 2_500_000,
		restockChance = 30,
		grantsEffect = "Slimed",
	},
	{
		id = "CursedCake",
		name = "Cursed Cake",
		kind = "Food",
		price = 250_000_000,
		restockChance = 2,
		grantsEffect = "Cursed",
	},
} :: { Item }

Shop.Workshop = {
	{ id = "DustBuster", name = "Dust Buster", kind = "Vacuum", price = 0, restockChance = 100, tier = 1 },
	{ id = "CandleLamp", name = "Candle Lamp", kind = "Flashlight", price = 0, restockChance = 100 },
	{
		id = "BaitBell",
		name = "Bait Bell",
		kind = "Lure",
		price = 10_000,
		restockChance = 50,
		singleUse = true,
		maxRarity = "Legendary",
	},
	{ id = "StrobeLight", name = "Strobe Light", kind = "Flashlight", price = 20_000, restockChance = 100 },
	{
		id = "PhantomVac",
		name = "Phantom Vac",
		kind = "Vacuum",
		price = 50_000,
		restockChance = 80,
		tier = 2,
	},
	{
		id = "SpiritLens",
		name = "Spirit Lens",
		kind = "Lens",
		price = 250_000,
		restockChance = 60,
		grantsEffect = "Ghost",
	},
	{
		id = "Moonbeam",
		name = "Moonbeam",
		kind = "Flashlight",
		price = 100_000_000,
		restockChance = 15,
		grantsEffect = "Werewolf",
	},
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

return Shop
