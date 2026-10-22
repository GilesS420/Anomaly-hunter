--!strict
-- Sell value of a caught monster:
--   baseValue x weight (kg / 20, Util/Weight; wild monsters use their size) x effects
--   x familiarity x wing boost x catch variant
-- Effects add less on cheap monsters (Value.monsterEffectMultiplier).
-- Effect bonuses add up (1 + sum(multiplier - 1)). Combos replace their two
-- ingredients. Call Util/Care.settle first so familiarity is up to date.

local Care = require("../Config/Care")
local Effects = require("../Config/Effects")
local Monsters = require("../Config/Monsters")
local Variants = require("../Config/Variants")
local Wings = require("../Config/Wings")
local Weight = require("./Weight")

local Value = {}

Value.FamiliarityMaxMultiplier = 2 -- placeholder, tune in playtesting
-- Cheap monsters get familiar fast (Util/Care.hours), so effects add less to them: the
-- cheapest (Config/Care.CheapValue) get this share of the effect bonus, the priciest
-- (Config/Care.PriceyValue) all of it, in between by price (Value.priceShare).
Value.CheapEffectShare = 0.25

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
	kg: number?, -- weight, kept up to date by Util/Weight.settle (its size follows it)
	kgAt: number?, -- os.time() of its last growth check
	gene: string?, -- hidden growth gene (Config/Weight.Genes)
}

local variantMultipliers: { [string]: number } = {}
for _, variant in Variants do
	variantMultipliers[variant.id] = variant.multiplier
end

-- x2 for Silver, x5 for Gold...; 1 for none (or one that no longer exists).
function Value.variantMultiplier(variantId: string?): number
	return if variantId then variantMultipliers[variantId] or 1 else 1
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

-- Whether a Critter effect (Config/Effects) can land on this monster: only cheap ones.
-- Every other effect can land on any monster. Without a monster id there's nothing to check.
function Value.critterAllowed(monsterId: string?, effectId: string): boolean
	local effect = Effects.List[effectId]
	if not effect or effect.source ~= "Critter" then
		return true
	end
	if not monsterId then
		return true
	end
	local monster = Monsters[monsterId]
	return monster ~= nil and monster.baseValue <= Effects.CritterMaxValue
end

-- Whether one more effect fits on a monster: any effect it doesn't have yet (there's no cap),
-- but Critter effects only on cheap monsters (pass the monster's id).
function Value.fits(
	effectIds: { string },
	effectId: string,
	monsterId: string?
): "Ok" | "HasEffect" | "TooPricey"
	if table.find(effectIds, effectId) then
		return "HasEffect"
	end
	return if Value.critterAllowed(monsterId, effectId) then "Ok" else "TooPricey"
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

-- Where a monster's base price sits between Config/Care.CheapValue (0) and PriceyValue (1),
-- by x10 steps. Nil for a monster that isn't in Config/Monsters.
function Value.priceShare(monsterId: string): number?
	local monster = Monsters[monsterId]
	if not monster then
		return nil
	end
	local span = math.log10(Care.PriceyValue / Care.CheapValue)
	return math.clamp(math.log10(math.max(monster.baseValue, 1) / Care.CheapValue) / span, 0, 1)
end

-- The effects' value multiplier on this monster: the full bonus on pricey monsters, less on
-- cheap ones (Value.CheapEffectShare). Critter effects always count in full.
function Value.monsterEffectMultiplier(caught: CaughtMonster): number
	local share = Value.CheapEffectShare
		+ (1 - Value.CheapEffectShare) * (Value.priceShare(caught.monsterId) or 1)
	local critter = 0
	for _, id in caught.effects do
		local effect = Effects.List[id]
		if effect and effect.source == "Critter" then
			critter += effect.multiplier - 1
		end
	end
	local rest = Value.effectMultiplier(caught.effects) - 1 - critter
	return 1 + rest * share + critter
end

function Value.sellValue(caught: CaughtMonster, wingsOwned: number): number
	local monster = Monsters[caught.monsterId]
	assert(monster, "unknown monster " .. caught.monsterId)

	local value = monster.baseValue
		* Weight.valueMultiplier(caught.size, caught.kg)
		* Value.variantMultiplier(caught.variant)
	local familiarity = 1 + math.clamp(caught.familiarity, 0, 1) * (Value.FamiliarityMaxMultiplier - 1)
	local wingBoost = 1 + math.max(wingsOwned - 1, 0) * Wings.ValueBoostPerWing
	return math.floor(value * Value.monsterEffectMultiplier(caught) * familiarity * wingBoost)
end

return Value
