--!strict
-- Watcher events. Server-wide Hunger rises with time players spend in zones; each
-- threshold fires the next event in the main area. Rates are placeholders.
--
-- One cycle runs the events that are built, in level order: Hunger fills to the first
-- event's threshold, that event plays, Hunger keeps filling to the next one, and after the
-- last event Hunger starts again from 0. Hunger doesn't rise while an event is playing.

export type WatcherEvent = {
	id: string,
	name: string, -- shown to players
	level: number,
	launch: boolean,
	effect: string?, -- haunted effect that can roll while the event is live
	durationSeconds: number?,
	monsters: { [string]: number }?, -- event monster id -> spawn weight
	effectOddsMultiplier: number?, -- mansion effect odds while live (Blood Moon doubles them)
	announce: string?, -- toast everyone sees when it starts
}

local Events = {}

Events.HungerPerPlayerMinute = 1 -- each player in a zone adds this much Hunger per minute
Events.HungerThresholds = { 60, 150, 280, 450, 700 } -- by event level

-- How many event monsters appear at the start of an event: this many per player in the
-- server, clamped between Min and Max, so everyone gets a chance.
Events.MonstersPerPlayer = 1
Events.MinMonsters = 4
Events.MaxMonsters = 10

-- Event monsters drift between the mansions, this many studs above the ground.
Events.HoverHeight = 3
Events.DriftSpeed = 5 -- studs per second

-- Where event monsters drift: the lanes between the two rows of mansions, keeping clear of
-- the Collector (x -130..-90) and the Trading Booth (x 90..130). Hub coordinates, studs.
Events.DriftAreas = {
	{ x = 0, z = -47.5, width = 580, depth = 45 }, -- north lane, in front of plots 1-4
	{ x = 0, z = 47.5, width = 580, depth = 45 }, -- south lane, in front of plots 5-8
	{ x = -220, z = 0, width = 140, depth = 50 }, -- west middle
	{ x = 0, z = 0, width = 140, depth = 50 }, -- around Watcher Square
	{ x = 220, z = 0, width = 140, depth = 50 }, -- east middle
}

Events.List = {
	{
		id = "Flicker",
		name = "Flicker",
		level = 1,
		launch = true,
		effect = "Poltergeist",
		durationSeconds = 180,
		monsters = { Flickerwick = 70, StaticShade = 30 },
		announce = "The Watcher stirs... the streetlights are failing! Phantoms drift between the mansions.",
	},
	{
		id = "BloodMoon",
		name = "Blood Moon",
		level = 2,
		launch = true,
		effect = "Bloodmoon",
		durationSeconds = 240,
		monsters = { CrimsonWisp = 70, Moonhowler = 30 },
		effectOddsMultiplier = 2,
		announce = "A Blood Moon rises! Phantoms roam the main area and haunted effects are twice as likely.",
	},
	{ id = "MimicNight", name = "Mimic Night", level = 3, launch = false, effect = "Mimic" },
	{ id = "BreachStorm", name = "Breach Storm", level = 4, launch = false },
	{ id = "WatcherAwakens", name = "The Watcher Awakens", level = 5, launch = true, effect = "Watched" },
} :: { WatcherEvent }

return Events
