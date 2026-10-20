--!strict
-- Sell value of a caught monster:
--   baseValue x size x effects x familiarity x wing boost x catch variant
-- Effect bonuses add up (1 + sum(multiplier - 1)). Combos replace their two
-- ingredients. Call Util/Care.settle first so familiarity is up to date.

local Effects = require("../Config/Effects")
local Monsters = require("../Config/Monsters")
local Sizes = require("../Config/Sizes")
local Variants = require("../Config/Variants")
local Wings = require("../Config/Wings")

local Value = {}

Value.FamiliarityMaxMultiplier = 2 -- placeholder, tune in playtesting

export type CaughtMonster = {
	uid: string?, -- unique id, given when caught (older saves get one when loaded)
	monsterId: string,
	size: string,
	effects: { string },
	familiarity: number, -- 0 to 1, as of grownAt
	grownAt: number?, -- os.time() its familiarity was last brought up to date
	storedAt: number?, -- os.time() it went into Storage (nil while in the mansion), see Util/Storage
	locked: boolean?, -- locked monsters can't be sold
	variant: string?, -- catch variant (Config/Variants): "Silver", "Gold", "Shiny", "Rainbow"
}

local variantMultipliers: { [string]: number } = {}
for _, variant in Variants do
	variantMultipliers[variant.id] = variant.multiplier
end

-- x2 for Silver, x5 for Gold...; 1 for none (or one that no longer exists).
function Value.variantMultiplier(variantId: string?): number
	return if variantId then variantMultipliers[variantId] or 1 else 1
end

local function sizeMultiplier(sizeId: string): number
	for _, size in Sizes do
		if size.id == sizeId then
			return size.valueMultiplier
		end
	end
	error("unknown size " .. sizeId)
end

-- Turns a list of effect ids into effect and combo ids, merging any combo recipes.
function Value.resolveEffects(effectIds: { string }): { string }
	local remaining = table.clone(effectIds)
	local resolved = {}
	for comboId, combo in Effects.Combos do
		local a = table.find(remaining, combo.recipe[1])
		local b = table.find(remaining, combo.recipe[2])
		if a and b then
			table.remove(remaining, math.max(a, b))
			table.remove(remaining, math.min(a, b))
			table.insert(resolved, comboId)
		end
	end
	for _, id in remaining do
		table.insert(resolved, id)
	end
	return resolved
end

-- Whether one more effect fits on a monster: not one it already has, and the result (after
-- combos merge) holds at most Effects.MaxSlots.
function Value.fits(effectIds: { string }, effectId: string): "Ok" | "HasEffect" | "NoRoom"
	if table.find(effectIds, effectId) then
		return "HasEffect"
	end
	local after = table.clone(effectIds)
	table.insert(after, effectId)
	return if #Value.resolveEffects(after) > Effects.MaxSlots then "NoRoom" else "Ok"
end

-- The combo that appears in `after` but not in `before` (resolved effect lists), or nil.
function Value.newCombo(before: { string }, after: { string }): string?
	for _, effectId in after do
		if Effects.Combos[effectId] and not table.find(before, effectId) then
			return effectId
		end
	end
	return nil
end

function Value.effectMultiplier(effectIds: { string }): number
	local total = 1
	for _, id in Value.resolveEffects(effectIds) do
		local effect = Effects.List[id] or Effects.Combos[id]
		assert(effect, "unknown effect " .. id)
		total += effect.multiplier - 1
	end
	return total
end

function Value.sellValue(caught: CaughtMonster, wingsOwned: number): number
	local monster = Monsters[caught.monsterId]
	assert(monster, "unknown monster " .. caught.monsterId)

	local value = monster.baseValue * sizeMultiplier(caught.size) * Value.variantMultiplier(caught.variant)
	local familiarity = 1 + math.clamp(caught.familiarity, 0, 1) * (Value.FamiliarityMaxMultiplier - 1)
	local wingBoost = 1 + math.max(wingsOwned - 1, 0) * Wings.ValueBoostPerWing
	return math.floor(value * Value.effectMultiplier(caught.effects) * familiarity * wingBoost)
end

return Value
