--!strict
-- Feeding and Familiarity rules (numbers in Config/Care, treats in Config/Shop.Bakery).
-- Everything works from timestamps (os.time() seconds), so a monster keeps growing while
-- nobody is looking and nothing needs a timer: call Care.settle(monster, now) before reading
-- its familiarity or fed state. Pure functions so they can be tested outside Roblox.

local CareConfig = require("../Config/Care")
local Effects = require("../Config/Effects")
local Shop = require("../Config/Shop")
local Format = require("./Format")
local Rng = require("./Rng")
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

-- The effects a treat may give, in the order they're tried, each with its chance in percent.
-- A plain treat gives its one effect for sure.
function Care.effectChances(item: Shop.Item): { Shop.EffectChance }
	if item.effectChances then
		return item.effectChances
	end
	return if item.grantsEffect then { { effect = item.grantsEffect, chance = 100 } } else {}
end

-- Whether this treat can be given to this monster. A treat is refused rather than wasted when
-- none of its effects could land: the monster already has them, or they wouldn't fit
-- (combos count as one). A chance treat is fine as long as one of its effects fits.
function Care.canTreat(caught: Value.CaughtMonster, item: Shop.Item?): TreatCheck
	if not item or item.kind ~= "Food" then
		return "Unknown"
	end
	local first: TreatCheck = "Ok"
	for i, option in Care.effectChances(item) do
		local fits: TreatCheck = Value.fits(caught.effects, option.effect)
		if fits == "Ok" then
			return "Ok"
		elseif i == 1 then
			first = fits
		end
	end
	return first
end

-- Rolls which effect a treat gives this monster, or nil: each effect in turn rolls its chance
-- (skipping ones that don't fit) and the first hit wins. A bite from a set-out cake first
-- has to pass Config/Care.SetOutEffectChance.
function Care.pickEffect(
	caught: Value.CaughtMonster,
	item: Shop.Item,
	random: Random?,
	bite: boolean?
): string?
	if bite and not Rng.chance(CareConfig.SetOutEffectChance, random) then
		return nil
	end
	for _, option in Care.effectChances(item) do
		if Value.fits(caught.effects, option.effect) == "Ok" and Rng.chance(option.chance, random) then
			return option.effect
		end
	end
	return nil
end

-- Gives a treat (check Care.canTreat first): feeds the monster, fills part of its Familiarity
-- bar and rolls the treat's effect. A bite from a set-out cake fills only
-- Config/Care.BiteFamiliarityShare of it and has lower effect odds (see Care.pickEffect).
-- Returns the effect it got, if any.
function Care.giveTreat(
	caught: Value.CaughtMonster,
	item: Shop.Item,
	now: number,
	random: Random?,
	bite: boolean?
): string?
	Care.feed(caught, now)
	local share = if bite then CareConfig.BiteFamiliarityShare else 1
	caught.familiarity = math.clamp(caught.familiarity + (item.familiarity or 0) * share, 0, 1)
	local effectId = Care.pickEffect(caught, item, random, bite)
	if effectId then
		table.insert(caught.effects, effectId)
	end
	return effectId
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
	local odds = {}
	for _, option in Care.effectChances(item) do
		local effect = Effects.List[option.effect]
		if effect then
			local chance = if option.chance >= 100 then "" else `{option.chance}% `
			table.insert(odds, `{chance}{Format.name(effect.id)} (x{effect.multiplier})`)
		end
	end
	if #odds > 0 then
		-- "gives Slimed (x2)", or "25% Mummy (x4), else Batty (x3)" for a chance treat
		table.insert(parts, if item.effectChances then table.concat(odds, ", else ") else `gives {odds[1]}`)
	end
	return table.concat(parts, " · ")
end

return Care
