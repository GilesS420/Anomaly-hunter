--!strict
-- Roaming effects: while a monster roams its owner's mansion it now and then picks up a
-- haunted effect (Cobwebbed, Possessed, Vampire, Batty, Mummy, and the live Watcher event's
-- effect). Numbers live in Config/Effects. Combos merge by themselves (Value.resolveEffects).
-- Pure functions so they can be tested outside Roblox.

local Effects = require("../Config/Effects")
local Rng = require("./Rng")
local Value = require("./Value")

local Haunting = {}

export type Option = { id: string, weight: number }
export type Event = { effect: string?, effectOddsMultiplier: number? }

-- Percent chance one roll gives an effect, before checking what still fits.
function Haunting.chance(familiarity: number, wingsOwned: number, oddsMultiplier: number?): number
	local familiar = 1 + math.clamp(familiarity, 0, 1) * Effects.RoamFamiliarityBonus
	local wings = 1 + math.max(wingsOwned - 1, 0) * Effects.RoamOddsPerWing
	return math.min(100, Effects.RoamChance * familiar * wings * (oddsMultiplier or 1))
end

-- The effects a roll can pick right now, with their weights (rarer = smaller).
function Haunting.pool(eventEffect: string?): { Option }
	local options: { Option } = {}
	for id, effect in Effects.List do
		if effect.source == "Roam" and (effect.weight or 0) > 0 then
			table.insert(options, { id = id, weight = effect.weight :: number })
		end
	end
	if eventEffect and Effects.List[eventEffect] and not Effects.List[eventEffect].weight then
		table.insert(options, { id = eventEffect, weight = Effects.EventEffectWeight })
	end
	table.sort(options, function(a, b)
		return a.id < b.id -- a fixed order, so a seeded Random gives the same result every time
	end)
	return options
end

-- One roll for a monster: the effect it picks up, or nil. Hungry monsters never pick one up,
-- and it only picks effects the monster doesn't have yet that still fit. force skips the
-- chance (Studio /haunt). Doesn't change the monster.
function Haunting.roll(
	caught: Value.CaughtMonster,
	wingsOwned: number,
	event: Event?,
	random: Random?,
	force: boolean?
): string?
	if not caught.fed then
		return nil
	end
	local odds = if event then event.effectOddsMultiplier else nil
	if not force and not Rng.chance(Haunting.chance(caught.familiarity, wingsOwned, odds), random) then
		return nil
	end
	local options = {}
	for _, option in Haunting.pool(if event then event.effect else nil) do
		if Value.fits(caught.effects, option.id) == "Ok" then
			table.insert(options, option)
		end
	end
	if #options == 0 then
		return nil
	end
	return Rng.pickWeighted(options, function(option: Option)
		return option.weight
	end, random).id
end

return Haunting
