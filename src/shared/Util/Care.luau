--!strict
-- Familiarity rules (numbers in Config/Care). Everything works from timestamps (os.time()
-- seconds), so a monster keeps growing while nobody is looking and nothing needs a timer:
-- call Care.settle(monster, now) before reading its familiarity. Pure functions so they can
-- be tested outside Roblox.

local CareConfig = require("../Config/Care")
local Monsters = require("../Config/Monsters")
local Value = require("./Value")

local Care = {}

-- Hours this monster takes to go from 0% to 100% Familiarity: fewer the cheaper it is.
function Care.hours(monsterId: string): number
	local monster = Monsters[monsterId]
	if not monster then
		return CareConfig.FamiliarityHours
	end
	local span = math.log10(CareConfig.PriceyValue / CareConfig.CheapValue)
	local at = math.clamp(math.log10(math.max(monster.baseValue, 1) / CareConfig.CheapValue) / span, 0, 1)
	return CareConfig.CheapHours * (CareConfig.PriceyHours / CareConfig.CheapHours) ^ at
end

-- Brings a monster up to date at `now`: its Familiarity grows for the time since the last
-- update (cheaper monsters grow faster, Care.hours). Safe to call as often as you like. A monster without a timestamp (just caught)
-- grows from now on. Clears the hunger fields older saves still carry.
function Care.settle(caught: Value.CaughtMonster, now: number)
	local from = caught.grownAt or now
	local grown = math.max(0, now - from)
	local growSeconds = Care.hours(caught.monsterId) * 3600
	caught.familiarity = math.clamp((caught.familiarity or 0) + grown / growSeconds, 0, 1)
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
