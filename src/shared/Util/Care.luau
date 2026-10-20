--!strict
-- Familiarity rules (numbers in Config/Care). Everything works from timestamps (os.time()
-- seconds), so a monster keeps growing while nobody is looking and nothing needs a timer:
-- call Care.settle(monster, now) before reading its familiarity. Pure functions so they can
-- be tested outside Roblox.

local CareConfig = require("../Config/Care")
local Value = require("./Value")

local Care = {}

local GrowSeconds = CareConfig.FamiliarityHours * 3600

-- Brings a monster up to date at `now`: its Familiarity grows for the time since the last
-- update. Safe to call as often as you like. A monster without a timestamp (just caught)
-- grows from now on. Clears the hunger fields older saves still carry.
function Care.settle(caught: Value.CaughtMonster, now: number)
	local from = caught.grownAt or now
	local grown = math.max(0, now - from)
	caught.familiarity = math.clamp((caught.familiarity or 0) + grown / GrowSeconds, 0, 1)
	caught.grownAt = math.max(from, now)
	local old = caught :: any
	old.fed = nil
	old.fedUntil = nil
end

-- Familiarity as a whole percent, 0 to 100.
function Care.percent(caught: Value.CaughtMonster): number
	return math.floor(math.clamp(caught.familiarity or 0, 0, 1) * 100 + 1e-6)
end

-- The line under a mansion monster's name: "45% familiar" or "Fully familiar".
function Care.status(caught: Value.CaughtMonster): string
	local percent = Care.percent(caught)
	return if percent >= 100 then "Fully familiar" else `{percent}% familiar`
end

return Care
