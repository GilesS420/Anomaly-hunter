--!strict
-- Roblox badges (Giles 2026-11-06, for retention: they put the game on players' profiles and
-- give reasons to come back on day 2 and day 7). Each badge is made by hand in Creator Hub
-- (Creator Hub > Creations > the game > Engagement > Badges > Create a Badge),
-- then its id goes in `id` below. A badge with id 0 isn't made yet and is skipped, and
-- everyone who already earned it gets it as soon as the id is filled in.
-- `key` is what the save remembers (data.badges); `name` and `description` are what to type
-- into Creator Hub. What earns each one is in Util/Badges.

export type Badge = {
	key: string,
	id: number,
	name: string,
	description: string,
}

local Badges: { Badge } = {
	-- First visit
	{
		key = "Welcome",
		id = 0,
		name = "Welcome, Hunter",
		description = "Joined Hunt a Monster.",
	},
	{
		key = "FirstCatch",
		id = 0,
		name = "First Catch",
		description = "Brought your first monster home.",
	},
	{
		key = "ReadyToHunt",
		id = 0,
		name = "Ready to Hunt",
		description = "Finished the tutorial.",
	},
	-- Coming back
	{
		key = "BackAgain",
		id = 0,
		name = "Back Again",
		description = "Played on 2 different days.",
	},
	{
		key = "OneWeek",
		id = 0,
		name = "One Week Hunter",
		description = "Played on 7 different days.",
	},
	{
		key = "MissionStreak",
		id = 0,
		name = "Mission Streak",
		description = "Finished daily missions 7 days in a row.",
	},
	-- Growing the mansion
	{
		key = "NewWing",
		id = 0,
		name = "New Wing",
		description = "Bought the Library wing.",
	},
	{
		key = "Millionaire",
		id = 0,
		name = "Millionaire Mansion",
		description = "Your mansion's monsters are worth $1M.",
	},
	-- Big catches
	{
		key = "Legendary",
		id = 0,
		name = "Legendary Catch",
		description = "Got a Legendary monster.",
	},
	{
		key = "Mythic",
		id = 0,
		name = "Mythic Catch",
		description = "Got a Mythic monster.",
	},
	{
		key = "Rainbow",
		id = 0,
		name = "Over the Rainbow",
		description = "Got a Rainbow monster.",
	},
	-- Events and friends
	{
		key = "WatcherAwakens",
		id = 0,
		name = "The Watcher Awakens",
		description = "Were there when the Watcher awoke.",
	},
	{
		key = "HuntingParty",
		id = 0,
		name = "Hunting Party",
		description = "Played in a server with a friend.",
	},
}

return {
	List = Badges,
	CheckSeconds = 10, -- how often each player's badges are looked at
	MillionaireWorth = 1_000_000,
	StreakDays = 7, -- Mission Streak
	WeekDays = 7, -- One Week Hunter
	WatcherEvent = "WatcherAwakens", -- Config/Events id
}
