--!strict
-- Watcher events. Server-wide Hunger rises with time players spend in zones; each
-- threshold fires the next event in the main area. Rates are placeholders.

export type WatcherEvent = {
	id: string,
	level: number,
	launch: boolean,
	effect: string?, -- haunted effect that can roll while the event is live
}

return {
	HungerPerPlayerMinute = 1,
	HungerThresholds = { 60, 150, 280, 450, 700 },
	List = {
		{ id = "Flicker", level = 1, launch = true, effect = "Poltergeist" },
		{ id = "BloodMoon", level = 2, launch = true, effect = "Bloodmoon" },
		{ id = "MimicNight", level = 3, launch = false, effect = "Mimic" },
		{ id = "BreachStorm", level = 4, launch = false },
		{ id = "WatcherAwakens", level = 5, launch = true, effect = "Watched" },
	} :: { WatcherEvent },
}
