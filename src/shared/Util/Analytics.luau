--!strict
-- The rules for the Creator Hub analytics (server/Services/AnalyticsService sends them). Which
-- funnel steps there are, which step a save has reached, and the "played on N days" milestones.
-- No Roblox services, so plain Luau can test it.
--
-- Two one-time funnels (Creator Hub > Analytics > Funnels):
--   Onboarding  join > first zone > first catch > ... > tutorial done > first wings
--   Comeback    played on 1, 2, 3, 5, 7, 14 different days
--   FirstVisit  minutes played on a new player's first day (MinuteMarks): where they stop
-- And when anyone leaves, a custom event (Creator Hub > Analytics > Custom events):
--   SessionMinutes / NewPlayerLeft  value = minutes this visit, fields = what they were doing
--   (stage), where they were (place) and the visit length bucket (Giles 2026-11-06: "what
--   exactly makes players leave, how long do they stay").
-- Only players who start the tutorial are counted (older players aren't new). Each step is
-- sent once per player: the highest one sent is saved in the profile as `analytics`.

local Tutorial = require("./Tutorial")

local Analytics = {}

-- Saved in the profile. onboard: the highest Onboarding step sent, 0 = not decided yet (the
-- tutorial hasn't looked at the save), -1 = an older player who isn't counted.
export type Record = {
	onboard: number,
	days: number, -- different days played since they joined (UTC days)
	lastDay: number, -- the last UTC day counted
	marks: number, -- the highest FirstVisit step sent
	firstSeconds: number, -- seconds played on their first day, for FirstVisit
}

function Analytics.empty(): Record
	return { onboard = 0, days = 0, lastDay = 0, marks = 0, firstSeconds = 0 }
end

-- Old or broken records back to something usable.
function Analytics.repair(record: any): Record
	if type(record) ~= "table" then
		return Analytics.empty()
	end
	local function int(value: any): number
		return if type(value) == "number" and value == value and math.abs(value) ~= math.huge
			then math.floor(value)
			else 0
	end
	return {
		onboard = int(record.onboard),
		days = int(record.days),
		lastDay = int(record.lastDay),
		marks = int(record.marks),
		firstSeconds = int(record.firstSeconds),
	}
end

-- The Onboarding funnel, in order. Steps 1-5 follow the tutorial (Tutorial.Steps: the step a
-- player is ON means they finished the one before it), then the first two wings bought.
-- Numbering history: 8 steps to "Finished tutorial" until 2026-11-05, then 13 with the Bakery
-- steps, then 7 with the short tutorial (the Bakery is its own BakeryQuest funnel now), then
-- 6 without the button tour (buying the Phantom Vac finishes it).
Analytics.Onboarding = {
	"Joined", -- on step Gate: walk to the first zone
	"Entered first zone", -- Catch
	"Caught first monster", -- Home
	"Brought it home", -- Sell
	"Sold first monster", -- Buy
	"Finished tutorial", -- Done: bought the first vacuum
	"Bought 1st wing", -- 2 wings owned (Library)
	"Bought 2nd wing", -- 3 wings owned (Ballroom)
}
Analytics.TutorialDone = #Tutorial.Steps + 1 -- the Onboarding step for "Done"

-- Roblox's built-in Onboarding funnel keeps every player ever counted under the step NUMBER,
-- and shows one name per number, so after the numbering changed it mixed three tutorials
-- (Giles's screenshot 2026-11-06: "Finished tutorial" at 6, 8 and 13). The same steps also
-- go to a custom funnel with this name; bump the version whenever Onboarding changes, so the
-- new funnel only holds players of the current tutorial.
Analytics.OnboardingFunnel = "NewPlayersV4"

-- The Onboarding step this save has reached (0 while the tutorial hasn't started).
function Analytics.onboardStep(tutorial: string, wingsOwned: number): number
	if tutorial == "Done" then
		local most = #Analytics.Onboarding - Analytics.TutorialDone
		local extra = math.clamp(math.floor(wingsOwned) - 1, 0, most)
		return Analytics.TutorialDone + extra
	end
	return Tutorial.index(tutorial)
end

-- The BakeryQuest funnel (the optional quest after the tutorial, Tutorial.QuestSteps).
Analytics.Quest = {
	"Started quest", -- on step Bake
	"Bought the cake", -- Place
	"Set out the cake", -- Hunt
	"Caught second monster", -- Return
	"Brought it home", -- Feed
	"Cake gave an effect", -- Done
}

-- The BakeryQuest step for this quest value (0 for not started or skipped).
function Analytics.questStep(quest: string): number
	if quest == "Done" then
		return #Tutorial.QuestSteps + 1
	end
	return Tutorial.questIndex(quest)
end

-- The Comeback funnel: step i is "played on ComebackDays[i] different days".
Analytics.ComebackDays = { 1, 2, 3, 5, 7, 14 }

function Analytics.comebackName(step: number): string
	local days = Analytics.ComebackDays[step]
	return if days == 1 then "Played day 1" else `Played on {days} days`
end

-- The Comeback step reached on exactly this many days played, or nil if it's not a milestone.
function Analytics.comebackStep(days: number): number?
	for step, needed in Analytics.ComebackDays do
		if needed == days then
			return step
		end
	end
	return nil
end

-- The FirstVisit funnel: step i is "played MinuteMarks[i] minutes" on a new player's first
-- day (all visits that day added up).
Analytics.FirstVisitFunnel = "FirstVisitV1"
Analytics.MinuteMarks = { 1, 2, 3, 4, 5, 7, 10, 15, 20, 30, 45, 60 }

function Analytics.markName(step: number): string
	local minutes = Analytics.MinuteMarks[step]
	return if minutes == 1 then "Played 1 min" else `Played {minutes} min`
end

-- How many FirstVisit steps this many minutes reaches.
function Analytics.marksReached(minutes: number): number
	local reached = 0
	for step, needed in Analytics.MinuteMarks do
		if minutes >= needed then
			reached = step
		end
	end
	return reached
end

-- A visit's length as a few readable buckets (custom event fields need few distinct values).
local Buckets = { 1, 2, 3, 5, 10, 20, 40 }
function Analytics.lengthBucket(minutes: number): string
	local from = 0
	for _, upTo in Buckets do
		if minutes < upTo then
			return `{from}-{upTo} min`
		end
		from = upTo
	end
	return `{from}+ min`
end

-- What the player was doing: their tutorial step, their Bakery quest step, or free play.
function Analytics.stageOf(tutorial: string, quest: string): string
	if tutorial ~= "Done" then
		return `Tutorial: {tutorial}`
	elseif Tutorial.questIndex(quest) > 0 then
		return `Quest: {quest}`
	end
	return "Free play"
end

-- The UTC day number of an os.time().
function Analytics.day(time: number): number
	return time // 86400
end

return Analytics
