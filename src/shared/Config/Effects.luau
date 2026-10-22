--!strict
-- Haunted effects. Bonuses add up: total = 1 + sum(multiplier - 1).
-- A monster can hold every effect at once (no cap, Giles 2026-10-20).

export type Source = "Roam" | "Critter" | "Food" | "Catch" | "Event" | "Survive"

export type Effect = {
	id: string,
	multiplier: number,
	source: Source,
	from: string?, -- the food, tool or event that gives it
	weight: number?, -- Roam and Critter effects: how often it's picked when a roll hits (rarer = smaller)
}

export type Combo = {
	id: string,
	multiplier: number,
	recipe: { string },
	critter: boolean?, -- made of Critter effects: counts in full on cheap monsters, like them
}

local Effects = {}

-- Percent each of a vacuum's catch effects (Config/Tools) lands on a catch (balance sheet input).
Effects.CatchChance = 25

-- Roaming effects (Util/Haunting). Every RoamRollSeconds each monster in a player's mansion
-- rolls (while they're offline too, played back when they return: Haunting.catchUp; event
-- effects only while online): RoamChance percent, raised by Familiarity (x(1 + bonus) at 100%),
-- by every wing past the Foyer, and by a Watcher event's effectOddsMultiplier (Blood Moon x2).
-- A hit picks a Roam effect by weight; while an event with an effect is live, that effect
-- joins the pick with EventEffectWeight. Placeholders, tune in playtesting.
Effects.RoamRollSeconds = 5 * 60
Effects.RoamChance = 0.75 -- 1.5% a roll at 100% Familiarity: about 4 effects a day (Giles 2026-10-21: slower)
Effects.RoamFamiliarityBonus = 1
Effects.RoamOddsPerWing = 0.1
Effects.EventEffectWeight = 25

-- Critter effects (Giles 2026-10-22): only monsters worth up to CritterMaxValue (base value)
-- can get them. They're picked up roaming like Roam effects (same rolls, their own weights)
-- and count in full on the price, unlike other effects on cheap monsters (Util/Value).
Effects.CritterMaxValue = 50_000

Effects.List = {
	Cobwebbed = { id = "Cobwebbed", multiplier = 1.2, source = "Roam", weight = 40 },
	PumpkinHead = { id = "PumpkinHead", multiplier = 1.5, source = "Food", from = "PumpkinCandy" },
	Possessed = { id = "Possessed", multiplier = 1.5, source = "Roam", weight = 30 },
	Slimed = { id = "Slimed", multiplier = 2, source = "Food", from = "EctoplasmPie" },
	Poltergeist = { id = "Poltergeist", multiplier = 2, source = "Event", from = "Flicker" },
	Sugarcoated = { id = "Sugarcoated", multiplier = 2, source = "Event", from = "SugarRush" },
	Frostbitten = { id = "Frostbitten", multiplier = 2.5, source = "Event", from = "FrostFog" },
	Gilded = { id = "Gilded", multiplier = 3, source = "Event", from = "GoldRush" },
	Harvested = { id = "Harvested", multiplier = 2.5, source = "Event", from = "HarvestMoon" },
	Skeletal = { id = "Skeletal", multiplier = 2.5, source = "Event", from = "BoneRattle" },
	Bewitched = { id = "Bewitched", multiplier = 3, source = "Event", from = "WitchingHour" },
	Vampire = { id = "Vampire", multiplier = 2.5, source = "Roam", weight = 15 },
	Batty = { id = "Batty", multiplier = 3, source = "Roam", weight = 10 },
	Ghost = { id = "Ghost", multiplier = 3, source = "Catch", from = "SpiritSiphon" },
	-- x4 (not x3 like Ghost) so the Moon Vac has a perk of its own; set by the balance sheet.
	Werewolf = { id = "Werewolf", multiplier = 4, source = "Catch", from = "MoonVac" },
	Mummy = { id = "Mummy", multiplier = 4, source = "Roam", weight = 5 },
	Glowbug = { id = "Glowbug", multiplier = 1.5, source = "Critter", weight = 30 },
	Moldy = { id = "Moldy", multiplier = 2, source = "Critter", weight = 25, from = "MoldyMuffin" },
	Rusty = { id = "Rusty", multiplier = 2, source = "Critter", weight = 25 },
	Fungal = { id = "Fungal", multiplier = 3, source = "Critter", weight = 12 },
	RatKing = { id = "RatKing", multiplier = 5, source = "Critter", weight = 4 },
	-- Round 3 cakes (Giles 2026-10-22).
	Buried = { id = "Buried", multiplier = 6, source = "Food", from = "GraveGateau" },
	Spectral = { id = "Spectral", multiplier = 10, source = "Food", from = "PhantomPavlova" },
	Voidtouched = { id = "Voidtouched", multiplier = 25, source = "Food", from = "VoidVelvet" },
	Stitched = { id = "Stitched", multiplier = 3, source = "Food", from = "StitchCupcake" },
	Cursed = { id = "Cursed", multiplier = 5, source = "Food", from = "CursedCake" },
	Bloodmoon = { id = "Bloodmoon", multiplier = 6, source = "Event", from = "BloodMoon" },
	Mimic = { id = "Mimic", multiplier = 8, source = "Event", from = "MimicNight" },
	Rifted = { id = "Rifted", multiplier = 6, source = "Event", from = "BreachStorm" },
	Hexed = { id = "Hexed", multiplier = 8, source = "Food", from = "WitchsBrewTart" },
	Eclipsed = { id = "Eclipsed", multiplier = 15, source = "Food", from = "EclipseEclair" },
	Watched = { id = "Watched", multiplier = 20, source = "Survive", from = "WatcherAwakens" },
} :: { [string]: Effect }

-- Combo recipes are secret in game; players unlock them in the Codex.
Effects.Combos = {
	Count = { id = "Count", multiplier = 10, recipe = { "Vampire", "Batty" } },
	Banshee = { id = "Banshee", multiplier = 12, recipe = { "Ghost", "Cursed" } },
	Pharaoh = { id = "Pharaoh", multiplier = 15, recipe = { "Mummy", "Cursed" } },
	Alpha = { id = "Alpha", multiplier = 25, recipe = { "Werewolf", "Bloodmoon" } },
	-- Round 2 combos (Giles 2026-10-22). Each is worth more than its two effects added up.
	PhantomWeaver = { id = "PhantomWeaver", multiplier = 4, recipe = { "Cobwebbed", "Possessed" } },
	TrickOrTreat = { id = "TrickOrTreat", multiplier = 6, recipe = { "PumpkinHead", "Sugarcoated" } },
	Wraith = { id = "Wraith", multiplier = 8, recipe = { "Ghost", "Poltergeist" } },
	GlacierGoo = { id = "GlacierGoo", multiplier = 7, recipe = { "Slimed", "Frostbitten" } },
	TombLord = { id = "TombLord", multiplier = 14, recipe = { "Mummy", "Buried" } },
	WitchsDoll = { id = "WitchsDoll", multiplier = 16, recipe = { "Stitched", "Hexed" } },
	HoardKing = { id = "HoardKing", multiplier = 18, recipe = { "Gilded", "Mimic" } },
	EclipseWraith = { id = "EclipseWraith", multiplier = 40, recipe = { "Spectral", "Eclipsed" } },
	TheUnseen = { id = "TheUnseen", multiplier = 60, recipe = { "Voidtouched", "Watched" } },
	-- Critter combos: only cheap monsters can have their effects.
	Lanternbot = { id = "Lanternbot", multiplier = 4, recipe = { "Glowbug", "Rusty" }, critter = true },
	Rotbloom = { id = "Rotbloom", multiplier = 6, recipe = { "Moldy", "Fungal" }, critter = true },
	PlagueKing = { id = "PlagueKing", multiplier = 10, recipe = { "RatKing", "Moldy" }, critter = true },
} :: { [string]: Combo }

return Effects
