--!strict
-- How the hunting tools behave. Prices and stock live in Shop.luau; vacuum tiers too.
-- All numbers are placeholders to tune in playtesting.

export type Flashlight = {
	stunSeconds: number, -- how long a monster stays stunned after being lit
	range: number, -- studs
	cooldown: number, -- seconds between shines
}

export type Vacuum = {
	catchSpeed: number, -- catch meter filled per second while pulling the right way (1 = full)
	range: number, -- studs; walk further than this and the monster breaks free
}

local Tools = {}

Tools.Flashlights = {
	CandleLamp = { stunSeconds = 1.5, range = 30, cooldown = 1.5 },
	StrobeLight = { stunSeconds = 2.5, range = 40, cooldown = 1.2 },
	Moonbeam = { stunSeconds = 4, range = 45, cooldown = 1 },
} :: { [string]: Flashlight }

Tools.Vacuums = {
	DustBuster = { catchSpeed = 0.25, range = 20 },
	PhantomVac = { catchSpeed = 0.4, range = 25 },
	VoidVac = { catchSpeed = 0.6, range = 30 },
} :: { [string]: Vacuum }

-- Tug-of-war while vacuuming: the monster yanks left or right and you drag the other way.
Tools.Tug = {
	FlipMin = 0.6, -- seconds before the monster changes direction (random in this range)
	FlipMax = 1.6,
	IdleFactor = -0.15, -- meter change while not pulling, as a share of catchSpeed
	WrongFactor = -0.6, -- meter change while pulling the wrong way
	StartProgress = 0.25, -- the meter starts a quarter full; hitting 0 means it broke free
	ResistPerRarity = 0.3, -- each rarity step above Common slows catching by this much
}

return Tools
