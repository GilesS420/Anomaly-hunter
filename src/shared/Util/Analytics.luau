--!strict
-- The rules for the Creator Hub analytics (server/Services/AnalyticsService sends them). Which
-- funnel steps there are, which step a save has reached, and the "played on N days" milestones.
-- No Roblox services, so plain Luau can test it.
--
-- Two one-time funnels (Creator Hub > Analytics > Funnels):
--   Onboarding  join > first zone > first catch > ... > tutorial done > first wings
--   Comeback    played on 1, 2, 3, 5, 7, 14 different days
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
}

function Analytics.empty(): Record
	return { onboard = 0, days = 0, lastDay = 0 }
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
	return { onboard = int(record.onboard), days = int(record.days), lastDay = int(record.lastDay) }
end

-- The Onboarding funnel, in order. Steps 1-6 follow the tutorial (Tutorial.Steps: the step a
-- player is ON means they finished the one before it), then the first two wings bought.
-- Numbering history: 8 steps to "Finished tutorial" until 2026-11-05, then 13 with the Bakery
-- steps, then 7 with the short tutorial (the Bakery is its own BakeryQuest funnel now).
Analytics.Onboarding = {
	"Joined", -- on step Gate: walk to the first zone
	"Entered first zone", -- Catch
	"Caught first monster", -- Home
	"Brought it home", -- Sell
	"Sold first monster", -- Buy
	"Bought first vacuum", -- Tour
	"Finished tutorial", -- Done
	"Bought 1st wing", -- 2 wings owned (Library)
	"Bought 2nd wing", -- 3 wings owned (Ballroom)
}
Analytics.TutorialDone = #Tutorial.Steps + 1 -- the Onboarding step for "Done"

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

-- The UTC day number of an os.time().
function Analytics.day(time: number): number
	return time // 86400
end

return Analytics
