--!strict
-- Sell value of a caught monster:
--   baseValue x size x effects x familiarity x wing boost
-- Effect bonuses add up (1 + sum(multiplier - 1)). Combos replace their two
-- ingredients. Unfed (hungry) monsters only sell for base value x size. Call Util/Care.settle
-- first so familiarity and fed are up to date.

local Effects = require("../Config/Effects")
local Monsters = require("../Config/Monsters")
local Sizes = require("../Config/Sizes")
local Wings = require("../Config/Wings")

local Value = {}

Value.FamiliarityMaxMultiplier = 2 -- placeholder, tune in playtesting

export type CaughtMonster = {
	uid: string?, -- unique id, given when caught (older saves get one when loaded)
	monsterId: string,
	size: string,
	effects: { string },
	familiarity: number, -- 0 to 1, as of grownAt
	fed: boolean, -- kept up to date by Util/Care.settle; hungry monsters sell for base x size
	fedUntil: number?, -- os.time() when it gets hungry (set when it enters the mansion)
	grownAt: number?, -- os.time() its familiarity was last brought up to date
}

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

	local value = monster.baseValue * sizeMultiplier(caught.size)
	if not caught.fed then
		return math.floor(value)
	end

	local familiarity = 1 + math.clamp(caught.familiarity, 0, 1) * (Value.FamiliarityMaxMultiplier - 1)
	local wingBoost = 1 + math.max(wingsOwned - 1, 0) * Wings.ValueBoostPerWing
	return math.floor(value * Value.effectMultiplier(caught.effects) * familiarity * wingBoost)
end

return Value
