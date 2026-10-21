--!strict
-- Watcher rules: the event clock (gaps, which event is next, the eyes) and event monster
-- rolls. Pure functions so they can be tested outside Roblox. See Config/Events for how the
-- clock runs.

local Effects = require("../Config/Effects")
local Events = require("../Config/Events")
local Format = require("./Format")
local Monsters = require("../Config/Monsters")
local Rng = require("./Rng")

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
-- picked by weight, never the one that just played (`lastId`).
function Watcher.pick(lastId: string?, eyes: number, random: Random?): Events.WatcherEvent
	if eyes >= Events.EyesToAwaken then
		for _, event in Events.List do
			if event.launch and event.awakening then
				return event
			end
		end
	end
	local options: { Events.WatcherEvent } = {}
	for _, event in Watcher.pool() do
		if event.id ~= lastId then
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
	eyes: number, -- open before this event plays
	warnAt: number, -- the calm ends and the warning starts
	startAt: number, -- the event starts
	endAt: number, -- the event ends and the next slot's calm starts
}

local function slot(index: number, from: number, eyes: number, lastId: string?): Slot
	local rng = Rng.seeded(`watcher:{index}`)
	local warnAt = from + Watcher.gap(rng)
	local event = Watcher.pick(lastId, eyes, rng)
	local startAt = warnAt + Events.WarningSeconds
	return {
		index = index,
		event = event,
		eyes = eyes,
		warnAt = warnAt,
		startAt = startAt,
		endAt = startAt + (event.durationSeconds or 180),
	}
end

function Watcher.nextSlot(previous: Slot): Slot
	return slot(
		previous.index + 1,
		previous.endAt,
		Watcher.eyesAfter(previous.eyes, previous.event),
		previous.event.id
	)
end

-- The slot that is in its calm, warning or event at `time`. Walks the schedule from Epoch,
-- so call it once and then step with nextSlot.
function Watcher.slotAt(time: number): Slot
	local current = slot(1, Watcher.Epoch, 0, nil)
	while current.endAt <= time do
		current = Watcher.nextSlot(current)
	end
	return current
end

-- How many event monsters appear for this many players in the server.
function Watcher.monsterCount(players: number): number
	return math.clamp(math.ceil(players * Events.MonstersPerPlayer), Events.MinMonsters, Events.MaxMonsters)
end

-- Picks which event monster appears next, by the event's weights.
function Watcher.rollMonster(event: Events.WatcherEvent, random: Random?): Monsters.Monster
	local weights = event.monsters
	assert(weights, `event {event.id} has no monsters`)
	local list: { Monsters.Monster } = {}
	for id in weights do
		local monster = Monsters[id]
		assert(monster, `unknown event monster {id}`)
		table.insert(list, monster)
	end
	table.sort(list, function(a, b) -- sorted, so a seeded Random gives the same picks
		return a.id < b.id
	end)
	return Rng.pickWeighted(list, function(m)
		return weights[m.id]
	end, random)
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

-- The event monsters that appear when an event starts: one of each kind first (so every
-- event shows all its monsters, not just the common one), then picked by weight. A
-- Nightmare or Eldritch monster appears at most once, so the batch can be shorter than count.
function Watcher.monsterBatch(
	event: Events.WatcherEvent,
	count: number,
	random: Random?
): { Monsters.Monster }
	local weights = event.monsters
	assert(weights, `event {event.id} has no monsters`)
	local kinds: { Monsters.Monster } = {}
	for id in weights do
		table.insert(kinds, Monsters[id])
	end
	table.sort(kinds, function(a, b) -- commonest first, so a short batch keeps the common ones
		if weights[a.id] ~= weights[b.id] then
			return weights[a.id] > weights[b.id]
		end
		return a.id < b.id
	end)
	local batch: { Monsters.Monster } = {}
	for index = 1, math.min(count, #kinds) do
		batch[index] = kinds[index]
	end
	local common: { Monsters.Monster } = {}
	for _, monster in kinds do
		if monster.rarity == "Phantom" then
			table.insert(common, monster)
		end
	end
	while #batch < count and #common > 0 do
		table.insert(
			batch,
			Rng.pickWeighted(common, function(m)
				return weights[m.id]
			end, random)
		)
	end
	return batch
end

-- "2:05"
function Watcher.clock(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return Watcher
