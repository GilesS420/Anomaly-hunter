--!strict
-- Watcher rules: the event clock (gaps, which event is next, the eyes) and event monster
-- rolls. Pure functions so they can be tested outside Roblox. See Config/Events for how the
-- clock runs.

local Events = require("../Config/Events")
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
