--!strict
-- Feeding and Familiarity rules (numbers in Config/Care).
-- Everything works from timestamps (os.time() seconds), so a monster keeps growing while
-- nobody is looking and nothing needs a timer: call Care.settle(monster, now) before reading
-- its familiarity or fed state. Pure functions so they can be tested outside Roblox.

local CareConfig = require("../Config/Care")
local Value = require("./Value")

local Care = {}

Care.FedSeconds = CareConfig.FedHours * 3600
local GrowSeconds = CareConfig.FamiliarityHours * 3600
local SoonSeconds = CareConfig.HungrySoonHours * 3600

-- Brings a monster up to date at `now`: its Familiarity grows for the time it was fed since
-- the last update, and fed says whether it's fed right now. Safe to call as often as you like.
-- A monster without timestamps (just caught, or from a save from before feeding) starts out
-- fed and grows from now on.
function Care.settle(caught: Value.CaughtMonster, now: number)
	local fedUntil = caught.fedUntil or now + Care.FedSeconds
	local from = caught.grownAt or now
	local grown = math.max(0, math.min(now, fedUntil) - from)
	caught.familiarity = math.clamp((caught.familiarity or 0) + grown / GrowSeconds, 0, 1)
	caught.fedUntil = fedUntil
	caught.grownAt = math.max(from, now)
	caught.fed = now < fedUntil
end

-- Feeds a monster: it stays fed for Config/Care.FedHours from now (feeding early just tops it up).
function Care.feed(caught: Value.CaughtMonster, now: number)
	Care.settle(caught, now)
	caught.fedUntil = now + Care.FedSeconds
	caught.fed = true
end

-- True if it's hungry now or gets hungry within Config/Care.HungrySoonHours.
function Care.needsFood(caught: Value.CaughtMonster, now: number): boolean
	return (caught.fedUntil or 0) - now < SoonSeconds
end

-- Whole hours until it gets hungry (0 when it already is).
function Care.hoursLeft(caught: Value.CaughtMonster, now: number): number
	return math.max(0, math.ceil(((caught.fedUntil or 0) - now) / 3600))
end

-- Familiarity as a whole percent, 0 to 100.
function Care.percent(caught: Value.CaughtMonster): number
	return math.floor(math.clamp(caught.familiarity or 0, 0, 1) * 100 + 1e-6)
end

-- The line under a mansion monster's name: "Fed · 45% familiar" or "Hungry! · 45% familiar".
function Care.status(caught: Value.CaughtMonster): string
	local percent = Care.percent(caught)
	local familiar = if percent >= 100 then "fully familiar" else `{percent}% familiar`
	return if caught.fed then `Fed · {familiar}` else `Hungry! · {familiar}`
end

return Care
