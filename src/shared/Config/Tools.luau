--!strict
-- How the hunting tools behave. Prices and stock live in Shop.luau (vacuum tiers too).
-- All numbers are placeholders to tune in playtesting.
--
-- Catching: press and hold on a monster. The flashlight's beam freezes it (reach = how far
-- away you can grab it from), then the vacuum fills the catch meter (catchSeconds = how long
-- that takes). Let go early and it escapes, but stays dazed for stunSeconds so you can grab
-- it again quickly.

export type Flashlight = {
	reach: number, -- studs; how far away you can start (and keep) catching
	stunSeconds: number, -- how long a monster stays frozen after you let go
}

export type Vacuum = {
	catchSeconds: number, -- time to catch a Common monster; rarer ones take longer
}

local Tools = {}

Tools.Flashlights = {
	CandleLamp = { reach = 25, stunSeconds = 1.5 },
	StrobeLight = { reach = 35, stunSeconds = 2.5 },
	Moonbeam = { reach = 45, stunSeconds = 4 },
} :: { [string]: Flashlight }

Tools.Vacuums = {
	DustBuster = { catchSeconds = 1.6 },
	PhantomVac = { catchSeconds = 1.2 },
	VoidVac = { catchSeconds = 0.9 },
} :: { [string]: Vacuum }

-- Each rarity step above Common makes catching take this much longer (0.15 = +15%).
Tools.ResistPerRarity = 0.15

-- Extra studs allowed on top of reach, for lag between what the client saw and the server.
Tools.ReachSlack = 6

return Tools
