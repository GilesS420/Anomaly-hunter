--!strict
-- Two shops in the main area. Each restocks every RestockSeconds; restockChance is the
-- percent chance an item is in stock after a restock.

export type Item = {
	id: string,
	name: string,
	kind: "Food" | "Vacuum" | "Flashlight" | "Lure" | "Lens" | "Charm",
	price: number,
	restockChance: number,
	tier: number?, -- vacuum tier for size limits
	grantsEffect: string?,
	singleUse: boolean?,
}

local Shop = {}

Shop.RestockSeconds = 5 * 60

Shop.Bakery = {
	{ id = "PumpkinCandy", name = "Pumpkin Candy", kind = "Food", price = 500, restockChance = 80, grantsEffect = "PumpkinHead" },
	{ id = "EctoplasmPie", name = "Ectoplasm Pie", kind = "Food", price = 25_000, restockChance = 30, grantsEffect = "Slimed" },
	{ id = "CursedCake", name = "Cursed Cake", kind = "Food", price = 2_500_000, restockChance = 2, grantsEffect = "Cursed" },
} :: { Item }

Shop.Workshop = {
	{ id = "DustBuster", name = "Dust Buster", kind = "Vacuum", price = 0, restockChance = 100, tier = 1 },
	{ id = "CandleLamp", name = "Candle Lamp", kind = "Flashlight", price = 0, restockChance = 100 },
	{ id = "BaitBell", name = "Bait Bell", kind = "Lure", price = 8_000, restockChance = 50, singleUse = true },
	{ id = "StrobeLight", name = "Strobe Light", kind = "Flashlight", price = 20_000, restockChance = 40 },
	{ id = "PhantomVac", name = "Phantom Vac", kind = "Vacuum", price = 50_000, restockChance = 25, tier = 2 },
	{ id = "SpiritLens", name = "Spirit Lens", kind = "Lens", price = 750_000, restockChance = 8, grantsEffect = "Ghost" },
	{ id = "Moonbeam", name = "Moonbeam", kind = "Flashlight", price = 1_500_000, restockChance = 5, grantsEffect = "Werewolf" },
	{ id = "VoidVac", name = "Void Vac", kind = "Vacuum", price = 5_000_000, restockChance = 1, tier = 3 },
	-- Price not decided yet; placeholder.
	{ id = "ReturnCharm", name = "Return Charm", kind = "Charm", price = 10_000, restockChance = 60, singleUse = true },
} :: { Item }

return Shop
