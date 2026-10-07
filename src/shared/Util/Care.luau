--!strict
-- Feeding and Familiarity rules (numbers in Config/Care, treats in Config/Shop.Bakery).
-- Everything works from timestamps (os.time() seconds), so a monster keeps growing while
-- nobody is looking and nothing needs a timer: call Care.settle(monster, now) before reading
-- its familiarity or fed state. Pure functions so they can be tested outside Roblox.

local CareConfig = require("../Config/Care")
local Effects = require("../Config/Effects")
local Shop = require("../Config/Shop")
local Format = require("./Format")
local Value = require("./Value")

local Care = {}

export type TreatCheck = "Ok" | "Unknown" | "HasEffect" | "NoRoom"

Care.FedSeconds = CareConfig.FedHours * 3600
local GrowSeconds = CareConfig.FamiliarityHours * 3600
local SoonSeconds = CareConfig.HungrySoonHours * 3600

local treats: { [string]: Shop.Item } = {}
for _, item in Shop.Bakery do
	treats[item.id] = item
end

-- A Bakery treat by id, or nil.
function Care.treat(id: string): Shop.Item?
	return treats[id]
end

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

-- Whether this treat can be given to this monster. A treat is refused rather than wasted when
-- the monster already has its effect, or when the effect wouldn't fit (combos count as one).
function Care.canTreat(caught: Value.CaughtMonster, item: Shop.Item?): TreatCheck
	if not item or item.kind ~= "Food" then
		return "Unknown"
	end
	local effectId = item.grantsEffect
	if effectId then
		if table.find(caught.effects, effectId) then
			return "HasEffect"
		end
		local after = table.clone(caught.effects)
		table.insert(after, effectId)
		if #Value.resolveEffects(after) > Effects.MaxSlots then
			return "NoRoom"
		end
	end
	return "Ok"
end

-- Gives a treat (check Care.canTreat first): feeds the monster, fills part of its Familiarity
-- bar and adds the treat's effect.
function Care.giveTreat(caught: Value.CaughtMonster, item: Shop.Item, now: number)
	Care.feed(caught, now)
	caught.familiarity = math.clamp(caught.familiarity + (item.familiarity or 0), 0, 1)
	if item.grantsEffect then
		table.insert(caught.effects, item.grantsEffect)
	end
end

-- The line under a mansion monster's name: "Fed · 45% familiar" or "Hungry! · 45% familiar".
function Care.status(caught: Value.CaughtMonster): string
	local percent = Care.percent(caught)
	local familiar = if percent >= 100 then "fully familiar" else `{percent}% familiar`
	return if caught.fed then `Fed · {familiar}` else `Hungry! · {familiar}`
end

-- One short line saying what a treat does, for the Bakery window.
function Care.describe(item: Shop.Item): string
	local parts = {}
	if item.familiarity then
		table.insert(parts, `+{math.floor(item.familiarity * 100 + 0.5)}% Familiarity`)
	end
	local effect = if item.grantsEffect then Effects.List[item.grantsEffect] else nil
	if effect then
		table.insert(parts, `gives {Format.name(effect.id)} (x{effect.multiplier})`)
	end
	return table.concat(parts, " · ")
end

return Care
