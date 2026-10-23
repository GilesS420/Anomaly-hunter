--!strict
-- How the vacuums behave. Prices and stock live in Shop.luau (tiers there too).
-- All numbers are placeholders to tune in playtesting.
--
-- Catching: click or tap a monster. The vacuum's beam freezes it (reach = how far away you
-- can grab it from) and fills the catch meter (catchSeconds = how long that takes). If it
-- breaks free it stays dazed for stunSeconds so you can grab it again quickly.
-- A vacuum carries `bag` monsters per trip. When a catch lands it may roll one of the
-- vacuum's catchEffects (Effects.CatchChance each) and one catch variant (Config/Variants,
-- percent chance each, rarest checked first).

export type Vacuum = {
	catchSeconds: number, -- time to catch a Common monster; rarer ones take longer
	reach: number, -- studs; how far away you can start (and keep) catching
	stunSeconds: number, -- how long a monster stays frozen after you let go
	bag: number, -- monsters carried per trip
	catchEffects: { string }?, -- effects it can give on catch (Ghost, Werewolf)
	variants: { [string]: number }?, -- variant id -> percent chance per catch
}

local Tools = {}

Tools.Vacuums = {
	DustBuster = { catchSeconds = 1.6, reach = 25, stunSeconds = 1.5, bag = 1 },
	PhantomVac = {
		catchSeconds = 1.3,
		reach = 30,
		stunSeconds = 2,
		bag = 1,
		variants = { Silver = 3 },
	},
	SpiritSiphon = {
		catchSeconds = 1.2,
		reach = 35,
		stunSeconds = 2.5,
		bag = 2,
		catchEffects = { "Ghost" },
		variants = { Silver = 5, Gold = 1 },
	},
	BansheeBlower = {
		catchSeconds = 1.1,
		reach = 40,
		stunSeconds = 3,
		bag = 2,
		catchEffects = { "Ghost" },
		variants = { Silver = 5, Gold = 3, Shiny = 0.5 },
	},
	MoonVac = {
		catchSeconds = 1,
		reach = 45,
		stunSeconds = 3.5,
		bag = 3,
		catchEffects = { "Ghost", "Werewolf" },
		variants = { Silver = 5, Gold = 4, Shiny = 1 },
	},
	VoidVac = {
		catchSeconds = 0.9,
		reach = 45,
		stunSeconds = 4,
		bag = 4,
		catchEffects = { "Ghost", "Werewolf" },
		variants = { Silver = 5, Gold = 4, Shiny = 2, Rainbow = 0.3 },
	},
} :: { [string]: Vacuum }

-- With a luck potion going, a vacuum without a Rainbow chance of its own gets this one
-- (percent, before the potion's boost): the Void Vac's base chance.
Tools.PotionRainbowChance = 0.3

-- Each rarity step above Common makes catching take this much longer (0.15 = +15%).
Tools.ResistPerRarity = 0.15

-- Extra studs allowed on top of reach, for lag between what the client saw and the server.
Tools.ReachSlack = 6

return Tools
