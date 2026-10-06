--!strict
-- Watcher rules: the Hunger cycle, the meter, and event monster rolls. Pure functions so
-- they can be tested outside Roblox. See Config/Events for how a cycle runs.

local Events = require("../Config/Events")
local Monsters = require("../Config/Monsters")
local Rng = require("./Rng")

local Watcher = {}

export type Step = { event: Events.WatcherEvent, threshold: number }

-- The events in one cycle, in level order: launch events whose id is in `built` (the
-- server passes the events it knows how to play), each with its Hunger threshold.
function Watcher.cycle(built: { [string]: boolean }): { Step }
	local steps: { Step } = {}
	for _, event in Events.List do
		local threshold = Events.HungerThresholds[event.level]
		if event.launch and built[event.id] and threshold then
			table.insert(steps, { event = event, threshold = threshold })
		end
	end
	table.sort(steps, function(a, b)
		return a.event.level < b.event.level
	end)
	return steps
end

-- Hunger added over `seconds` with this many players in zones.
function Watcher.gain(playersInZones: number, seconds: number): number
	return math.max(playersInZones, 0) * Events.HungerPerPlayerMinute * seconds / 60
end

-- How full the meter is (0 to 1) on the way from the previous event to the next one.
function Watcher.meter(hunger: number, steps: { Step }, nextIndex: number): number
	local step = steps[nextIndex]
	if not step then
		return 0
	end
	local previous = steps[nextIndex - 1]
	local from = if previous then previous.threshold else 0
	if step.threshold <= from then
		return 1
	end
	return math.clamp((hunger - from) / (step.threshold - from), 0, 1)
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

-- "2:05"
function Watcher.clock(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return Watcher
