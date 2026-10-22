--!strict
-- Watcher rules: the event clock (gaps, which event is next, the eyes) and event monster
-- rolls. Pure functions so they can be tested outside Roblox. See Config/Events for how the
-- clock runs.

local Catching = require("./Catching")
local Effects = require("../Config/Effects")
local Events = require("../Config/Events")
local Format = require("./Format")
local Monsters = require("../Config/Monsters")
local Rarities = require("../Config/Rarities")
local Rng = require("./Rng")
local Zones = require("../Config/Zones")

local Watcher = {}

-- Seconds of calm after an event, before the next warning: anywhere from GapMinSeconds to
-- GapMaxSeconds, so nobody can time it to the second.
function Watcher.gap(random: Random?): number
	local rng = random or Random.new()
	return Events.GapMinSeconds + (Events.GapMaxSeconds - Events.GapMinSeconds) * rng:NextNumber()
end

-- The events the clock picks from by weight (launch events with a weight).
function Watcher.pool(): { Events.WatcherEvent }
	local list: { Events.WatcherEvent } = {}
	for _, event in Events.List do
		if event.launch and (event.weight or 0) > 0 then
			table.insert(list, event)
		end
	end
	return list
end

-- The event that plays next. With all the eyes open it's The Watcher Awakens; otherwise one
-- picked by weight, never one of the last Events.NoRepeat that played (`recent`, oldest
-- first), so the same few don't keep coming round.
function Watcher.pick(recent: { string }?, eyes: number, random: Random?): Events.WatcherEvent
	if eyes >= Events.EyesToAwaken then
		for _, event in Events.List do
			if event.launch and event.awakening then
				return event
			end
		end
	end
	local options: { Events.WatcherEvent } = {}
	for _, event in Watcher.pool() do
		if not table.find(recent or {}, event.id) then
			table.insert(options, event)
		end
	end
	if #options == 0 then
		options = Watcher.pool()
	end
	return Rng.pickWeighted(options, function(event)
		return event.weight or 0
	end, random)
end

-- How many eyes are open after `event` played: one more, or none after the awakening.
function Watcher.eyesAfter(eyes: number, event: Events.WatcherEvent): number
	if event.awakening then
		return 0
	end
	return math.min(eyes + 1, Events.EyesToAwaken)
end

-- The global schedule: every server works out the same events at the same times from the
-- clock alone (workspace:GetServerTimeNow, Unix seconds), so hopping servers never finds a
-- different or rarer event. Slot 1 starts its calm at Epoch; each slot is a calm gap, the
-- warning and the event, and the next slot's calm starts when it ends. A slot's gap and
-- event are rolled from its number (Rng.seeded), and the eyes carry over from slot to slot.
Watcher.Epoch = 1792454400 -- 2026-10-20 00:00 UTC

export type Slot = {
	index: number,
	event: Events.WatcherEvent,
	recent: { string }, -- the events before this one (Events.NoRepeat of them, oldest first)
	eyes: number, -- open before this event plays
	warnAt: number, -- the calm ends and the warning starts
	startAt: number, -- the event starts
	endAt: number, -- the event ends and the next slot's calm starts
}

local function slot(index: number, from: number, eyes: number, recent: { string }): Slot
	local rng = Rng.seeded(`watcher:{index}`)
	local warnAt = from + Watcher.gap(rng)
	local event = Watcher.pick(recent, eyes, rng)
	local startAt = warnAt + Events.WarningSeconds
	return {
		index = index,
		event = event,
		recent = recent,
		eyes = eyes,
		warnAt = warnAt,
		startAt = startAt,
		endAt = startAt + (event.durationSeconds or 180),
	}
end

function Watcher.nextSlot(previous: Slot): Slot
	local recent = table.clone(previous.recent)
	table.insert(recent, previous.event.id)
	while #recent > Events.NoRepeat do
		table.remove(recent, 1)
	end
	return slot(previous.index + 1, previous.endAt, Watcher.eyesAfter(previous.eyes, previous.event), recent)
end

-- The slot that is in its calm, warning or event at `time`. Walks the schedule from Epoch,
-- so call it once and then step with nextSlot.
function Watcher.slotAt(time: number): Slot
	local current = slot(1, Watcher.Epoch, 0, {})
	while current.endAt <= time do
		current = Watcher.nextSlot(current)
	end
	return current
end

-- How many event monsters appear for this many players in the server.
function Watcher.monsterCount(players: number): number
	return math.clamp(math.ceil(players * Events.MonstersPerPlayer), Events.MinMonsters, Events.MaxMonsters)
end

-- The monsters in a weights table (monster id -> weight), in a fixed order so a seeded
-- Random gives the same picks.
local function kindsOf(weights: { [string]: number }): { Monsters.Monster }
	local list: { Monsters.Monster } = {}
	for id in weights do
		local monster = Monsters[id]
		assert(monster, `unknown event monster {id}`)
		table.insert(list, monster)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

-- Picks one event monster by weight (monster id -> weight).
function Watcher.rollMonster(weights: { [string]: number }, random: Random?): Monsters.Monster
	return Rng.pickWeighted(kindsOf(weights), function(m)
		return weights[m.id]
	end, random)
end

-- Which monster set The Watcher Awakens brings this time (nil for events without sets).
function Watcher.pickSet(event: Events.WatcherEvent, random: Random?): Events.MonsterSet?
	local sets = event.monsterSets
	if not sets or #sets == 0 then
		return nil
	end
	return Rng.pickWeighted(sets, function(set)
		return set.weight
	end, random)
end

-- Breach Storm's monsters: every monster of the launch zones by its zone spawn weight, with
-- Legendary and rarer `rareMultiplier` times as likely.
function Watcher.zoneWeights(rareMultiplier: number): { [string]: number }
	local open: { [number]: boolean } = {}
	for _, zone in Zones.List do
		if zone.launch then
			open[zone.index] = true
		end
	end
	local legendary = Rarities.Legendary.order
	local weights: { [string]: number } = {}
	for id, monster in Monsters do
		if monster.zone and open[monster.zone] and monster.spawnWeight then
			local rarity = Rarities[monster.rarity]
			local rare = rarity ~= nil and rarity.order >= legendary
			weights[id] = monster.spawnWeight * (if rare then rareMultiplier else 1)
		end
	end
	return weights
end

-- The monsters an event brings this time, as weights and a count (nil: none).
function Watcher.spawns(
	event: Events.WatcherEvent,
	set: Events.MonsterSet?,
	players: number
): ({ [string]: number }?, number)
	if set then
		return set.monsters, set.count or Watcher.monsterCount(players)
	end
	if event.zoneMonsters then
		return Watcher.zoneWeights(event.zoneMonsters.rareMultiplier), Watcher.monsterCount(players)
	end
	return event.monsters, Watcher.monsterCount(players)
end

-- Whether a caught event monster is replaced while the event is live.
function Watcher.respawns(set: Events.MonsterSet?): boolean
	return not (set and set.noRespawn)
end

local function percent(value: number): string
	local rounded = math.floor(value * 10 + 0.5) / 10
	return if rounded == math.floor(rounded) then `{math.floor(rounded)}%` else `{rounded}%`
end

-- What an event does to mansion monsters, in a few short lines for the event icon's tooltip:
-- the effect it gives, its value boost and the chance per roll.
function Watcher.effectLines(event: Events.WatcherEvent): { string }
	local lines: { string } = {}
	local effect = if event.effect then Effects.List[event.effect] else nil
	if effect then
		table.insert(lines, `Gives {Format.name(effect.id)} (x{effect.multiplier} value)`)
		table.insert(
			lines,
			`{percent(event.effectChance or 0)} chance per monster every {Events.EffectRollSeconds} s`
		)
	end
	if event.otherEffectsChance then
		table.insert(lines, `{percent(event.otherEffectsChance)} chance of another event's effect`)
	end
	if event.effectOddsMultiplier and event.effectOddsMultiplier ~= 1 then
		table.insert(lines, `Other haunted effects x{event.effectOddsMultiplier} as likely`)
	end
	if #lines > 0 then
		table.insert(lines, "Higher with Familiarity and more wings")
	end
	return lines
end

-- The event monsters that appear when an event starts. With room for every kind, each
-- appears once (so Blood Moon always shows a Moonhowler next to its Wisps) and the rest are
-- picked by weight; with less room (a set that brings 1 or 2), different kinds by weight.
function Watcher.monsterBatch(
	weights: { [string]: number },
	count: number,
	random: Random?
): { Monsters.Monster }
	local kinds = kindsOf(weights)
	local function weight(m: Monsters.Monster): number
		return weights[m.id]
	end
	local batch: { Monsters.Monster } = {}
	if count < #kinds then
		local left = table.clone(kinds)
		for _ = 1, count do
			local pick = Rng.pickWeighted(left, weight, random)
			table.insert(batch, pick)
			table.remove(left, table.find(left, pick) :: number)
		end
		return batch
	end
	for _, monster in kinds do
		table.insert(batch, monster)
	end
	while #batch < count do
		table.insert(batch, Rng.pickWeighted(kinds, weight, random))
	end
	return batch
end

-- The monsters an event brings this time and what to call them (nil: none), with the
-- monster set The Watcher Awakens picked (setId, the WatcherMonsterSet attr).
local function shownMonsters(event: Events.WatcherEvent, setId: string?): ({ [string]: number }?, string)
	local weights = event.monsters
	local prefix = "Monsters"
	local sets: { Events.MonsterSet } = event.monsterSets or {}
	for _, set in sets do
		if set.id == setId then
			weights = set.monsters
			prefix = set.name
		end
	end
	return weights, prefix
end

-- One line for the event icon's tooltip on the monsters the event brings (nil: none).
function Watcher.monsterLine(event: Events.WatcherEvent, setId: string?): string?
	if event.zoneMonsters then
		return `Monsters: any from the zones, Legendary and up {event.zoneMonsters.rareMultiplier}x as likely`
	end
	local weights, prefix = shownMonsters(event, setId)
	if not weights then
		return nil
	end
	local names: { string } = {}
	for _, monster in kindsOf(weights) do
		table.insert(names, Format.name(monster.id))
	end
	return `{prefix}: {table.concat(names, ", ")}`
end

-- The tooltip line on which vacuum the event's monsters need (nil: any vacuum will do):
-- the weakest one that catches at least one of them.
function Watcher.vacuumLine(event: Events.WatcherEvent, setId: string?): string?
	local weights = shownMonsters(event, setId)
	local weakest: string? = nil
	for _, monster in kindsOf(weights or {}) do
		local needed = monster.vacuum
		if needed and (weakest == nil or Catching.rank(needed) < Catching.rank(weakest)) then
			weakest = needed
		end
	end
	return if weakest then `Catch with the {Format.name(weakest)} or better` else nil
end

-- "2:05"
function Watcher.clock(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return Watcher
