--!strict
-- Haunted effects. Bonuses add up: total = 1 + sum(multiplier - 1).
-- A monster holds up to MaxSlots effects. Unfed monsters have their effects go dormant.

export type Source = "Roam" | "Food" | "Catch" | "Event" | "Survive"

export type Effect = {
	id: string,
	multiplier: number,
	source: Source,
	from: string?, -- the food, tool or event that gives it
}

export type Combo = {
	id: string,
	multiplier: number,
	recipe: { string },
}

local Effects = {}

Effects.MaxSlots = 3
-- Percent a Catch-effect tool (Spirit Lens, Moonbeam) applies its effect (balance sheet input).
Effects.CatchChance = 25

Effects.List = {
	Cobwebbed = { id = "Cobwebbed", multiplier = 1.2, source = "Roam" },
	PumpkinHead = { id = "PumpkinHead", multiplier = 1.5, source = "Food", from = "PumpkinCandy" },
	Possessed = { id = "Possessed", multiplier = 1.5, source = "Roam" },
	Slimed = { id = "Slimed", multiplier = 2, source = "Food", from = "EctoplasmPie" },
	Poltergeist = { id = "Poltergeist", multiplier = 2, source = "Event", from = "Flicker" },
	Vampire = { id = "Vampire", multiplier = 2.5, source = "Roam" },
	Batty = { id = "Batty", multiplier = 3, source = "Roam" },
	Ghost = { id = "Ghost", multiplier = 3, source = "Catch", from = "SpiritLens" },
	-- x4 (not x3 like Ghost) so the Moonbeam has a perk of its own; set by the balance sheet.
	Werewolf = { id = "Werewolf", multiplier = 4, source = "Catch", from = "Moonbeam" },
	Mummy = { id = "Mummy", multiplier = 4, source = "Roam" },
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
