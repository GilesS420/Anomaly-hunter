--!strict
-- Roaming effects: while a monster roams its owner's mansion it now and then picks up a
-- haunted effect (Cobwebbed, Possessed, Vampire, Batty, Mummy; cheap monsters also the
-- Critter effects: Glowbug, Moldy, Rusty, Fungal, Rat King). Numbers live in
-- Config/Effects. While a Watcher event is live, monsters also roll for that event's own
-- effect (eventRoll, numbers in Config/Events). Combos merge by themselves
-- (Value.resolveEffects). Pure functions so they can be tested outside Roblox.

local Care = require("./Care")
local Effects = require("../Config/Effects")
local Events = require("../Config/Events")
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
		if (effect.source == "Roam" or effect.source == "Critter") and (effect.weight or 0) > 0 then
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

-- One roll for a monster: the effect it picks up, or nil (also when it lands on one the
-- monster already has). force skips the chance (Studio /haunt). Doesn't change the monster.
function Haunting.roll(
	caught: Value.CaughtMonster,
	wingsOwned: number,
	event: Event?,
	random: Random?,
	force: boolean?
): string?
	local odds = if event then event.effectOddsMultiplier else nil
	if not force and not Rng.chance(Haunting.chance(caught.familiarity, wingsOwned, odds), random) then
		return nil
	end
	-- Picks from every effect the monster could ever get, including ones it already has (a
	-- roll that lands on one of those gives nothing). Picking only from what's left made the
	-- last, rarest effect a sure thing once the common ones were taken, so every monster had
	-- Mummy within a day (Giles 2026-10-24). A forced roll (Studio /haunt) still always gives
	-- a new one.
	local options = {}
	for _, option in Haunting.pool(if event then event.effect else nil) do
		local fit = Value.fits(caught.effects, option.id, caught.monsterId)
		if fit == "Ok" or (fit == "HasEffect" and not force) then
			table.insert(options, option)
		end
	end
	if #options == 0 then
		return nil
	end
	local picked = Rng.pickWeighted(options, function(option: Option)
		return option.weight
	end, random).id
	return if table.find(caught.effects, picked) then nil else picked
end

-- Plays back the roaming rolls a monster had while its owner was away, from `from` to `to`
-- (os.time()), one every Effects.RoamRollSeconds, with its Familiarity as it was at each one.
-- Only roaming effects (no event's). Puts the new effects on the monster and returns them.
-- Call it before Care.settle (it reads Familiarity as of caught.grownAt).
function Haunting.catchUp(
	caught: Value.CaughtMonster,
	wingsOwned: number,
	from: number,
	to: number,
	random: Random?
): { string }
	local gained: { string } = {}
	local growSeconds = Care.hours(caught.monsterId) * 3600
	local grownAt = caught.grownAt or from
	local at = from + Effects.RoamRollSeconds
	while at <= to do
		local familiarity = math.clamp((caught.familiarity or 0) + (at - grownAt) / growSeconds, 0, 1)
		local probe = table.clone(caught)
		probe.familiarity = familiarity
		local effectId = Haunting.roll(probe, wingsOwned, nil, random)
		if effectId then
			table.insert(caught.effects, effectId)
			table.insert(gained, effectId)
		end
		local left = false
		for _, option in Haunting.pool(nil) do
			left = left or Value.fits(caught.effects, option.id, caught.monsterId) == "Ok"
		end
		if not left then
			break -- it has every roaming effect
		end
		at += Effects.RoamRollSeconds
	end
	return gained
end

-- Percent chance one event roll hits, from the event's base chance, raised by Familiarity and
-- wings the same way as roaming odds.
function Haunting.eventChance(base: number, familiarity: number, wingsOwned: number): number
	return math.min(100, base * Haunting.chance(familiarity, wingsOwned, nil) / Effects.RoamChance)
end

-- The monster's effects with `effectId` added, or nil if it already has it.
function Haunting.withEffect(effects: { string }, effectId: string): { string }?
	if Value.fits(effects, effectId) ~= "Ok" then
		return nil
	end
	local after = table.clone(effects)
	table.insert(after, effectId)
	return after
end

-- The effects of the other launch events (for The Watcher Awakens' otherEffectsChance).
local function otherEventEffects(event: Events.WatcherEvent): { string }
	local list: { string } = {}
	for _, other in Events.List do
		local id = other.effect
		if other.launch and other.id ~= event.id and id and Effects.List[id] and not table.find(list, id) then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

-- One event roll for a monster while `event` is live: the effect it picks up and its effect
-- list afterwards, or nil. Doesn't change the monster.
function Haunting.eventRoll(
	caught: Value.CaughtMonster,
	wingsOwned: number,
	event: Events.WatcherEvent,
	random: Random?
): (string?, { string }?)
	local effectId: string? = nil
	if event.effect and event.effectChance then
		if Rng.chance(Haunting.eventChance(event.effectChance, caught.familiarity, wingsOwned), random) then
			effectId = event.effect
		end
	end
	if not effectId and event.otherEffectsChance then
		local others = otherEventEffects(event)
		if
			#others > 0
			and Rng.chance(
				Haunting.eventChance(event.otherEffectsChance, caught.familiarity, wingsOwned),
				random
			)
		then
			effectId = Rng.pickWeighted(others, function()
				return 1
			end, random)
		end
	end
	if not effectId then
		return nil, nil
	end
	local after = Haunting.withEffect(caught.effects, effectId)
	if not after then
		return nil, nil
	end
	return effectId, after
end

return Haunting
