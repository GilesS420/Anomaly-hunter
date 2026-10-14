--!strict
-- Haunted effects. Bonuses add up: total = 1 + sum(multiplier - 1).
-- A monster holds up to MaxSlots effects. Unfed monsters have their effects go dormant.

export type Source = "Roam" | "Food" | "Catch" | "Event" | "Survive"

export type Effect = {
	id: string,
	multiplier: number,
	source: Source,
	from: string?, -- the food, tool or event that gives it
	weight: number?, -- Roam effects: how often it's picked when a roll hits (rarer = smaller)
}

export type Combo = {
	id: string,
	multiplier: number,
	recipe: { string },
}

local Effects = {}

Effects.MaxSlots = 3
-- Percent each of a vacuum's catch effects (Config/Tools) lands on a catch (balance sheet input).
Effects.CatchChance = 25

-- Roaming effects (Util/Haunting). Every RoamRollSeconds each fed monster in an online
-- player's mansion rolls: RoamChance percent, raised by Familiarity (x(1 + bonus) at 100%),
-- by every wing past the Foyer, and by a Watcher event's effectOddsMultiplier (Blood Moon x2).
-- A hit picks a Roam effect by weight; while an event with an effect is live, that effect
-- joins the pick with EventEffectWeight. Placeholders, tune in playtesting.
Effects.RoamRollSeconds = 5 * 60
Effects.RoamChance = 4
Effects.RoamFamiliarityBonus = 1.5
Effects.RoamOddsPerWing = 0.1
Effects.EventEffectWeight = 25

Effects.List = {
	Cobwebbed = { id = "Cobwebbed", multiplier = 1.2, source = "Roam", weight = 40 },
	PumpkinHead = { id = "PumpkinHead", multiplier = 1.5, source = "Food", from = "PumpkinCandy" },
	Possessed = { id = "Possessed", multiplier = 1.5, source = "Roam", weight = 30 },
	Slimed = { id = "Slimed", multiplier = 2, source = "Food", from = "EctoplasmPie" },
	Poltergeist = { id = "Poltergeist", multiplier = 2, source = "Event", from = "Flicker" },
	Vampire = { id = "Vampire", multiplier = 2.5, source = "Roam", weight = 15 },
	Batty = { id = "Batty", multiplier = 3, source = "Roam", weight = 10 },
	Ghost = { id = "Ghost", multiplier = 3, source = "Catch", from = "SpiritSiphon" },
	-- x4 (not x3 like Ghost) so the Moon Vac has a perk of its own; set by the balance sheet.
	Werewolf = { id = "Werewolf", multiplier = 4, source = "Catch", from = "MoonVac" },
	Mummy = { id = "Mummy", multiplier = 4, source = "Roam", weight = 5 },
	Cursed = { id = "Cursed", multiplier = 5, source = "Food", from = "CursedCake" },
	Bloodmoon = { id = "Bloodmoon", multiplier = 6, source = "Event", from = "BloodMoon" },
	Mimic = { id = "Mimic", multiplier = 8, source = "Event", from = "MimicNight" },
	Watched = { id = "Watched", multiplier = 20, source = "Survive", from = "WatcherAwakens" },
} :: { [string]: Effect }

-- Combo recipes are secret in game; players unlock them in the Codex.
Effects.Combos = {
	Count = { id = "Count", multiplier = 10, recipe = { "Vampire", "Batty" } },
	Banshee = { id = "Banshee", multiplier = 12, recipe = { "Ghost", "Cursed" } },
	Pharaoh = { id = "Pharaoh", multiplier = 15, recipe = { "Mummy", "Cursed" } },
	Alpha = { id = "Alpha", multiplier = 25, recipe = { "Werewolf", "Bloodmoon" } },
} :: { [string]: Combo }

return Effects
