--!strict
-- Variant Machine rules (numbers in Config/VariantMachine). A pull uses up one random effect
-- of the monster and rolls the odds once. If the roll lands on a variant better than the
-- one it has, the monster gets it; otherwise it keeps its variant. Pure functions so they can
-- be tested outside Roblox.

local Config = require("../Config/VariantMachine")
local Monsters = require("../Config/Monsters")
local Variants = require("../Config/Variants")
local Value = require("./Value")

local VariantMachine = {}

export type Problem = "NoEffects" | "Best" | "Unknown"
export type Odd = { id: string, chance: number, possible: boolean }

-- Variants are listed rarest first; a higher rank is better.
local rank: { [string]: number } = {}
for i, variant in Variants do
	rank[variant.id] = #Variants - i + 1
end

-- True if `variant` would be an upgrade for a monster that has `current` (nil = none).
function VariantMachine.better(variant: string, current: string?): boolean
	return (rank[variant] or 0) > (rank[current or ""] or 0)
end

-- Why this monster can't go in, or nil if it can.
function VariantMachine.problem(caught: Value.CaughtMonster): Problem?
	if not Monsters[caught.monsterId] then
		return "Unknown"
	end
	if #caught.effects == 0 then
		return "NoEffects"
	end
	for id in Config.Odds do
		if VariantMachine.better(id, caught.variant) then
			return nil
		end
	end
	return "Best"
end

-- Every variant's chance, rarest first, and whether it's an upgrade for this monster.
function VariantMachine.odds(current: string?): { Odd }
	local list = {}
	for _, variant in Variants do
		local chance = Config.Odds[variant.id]
		if chance then
			table.insert(
				list,
				{ id = variant.id, chance = chance, possible = VariantMachine.better(variant.id, current) }
			)
		end
	end
	return list
end

-- The chance in percent that a pull upgrades a monster that has `current`.
function VariantMachine.chance(current: string?): number
	local total = 0
	for _, odd in VariantMachine.odds(current) do
		if odd.possible then
			total += odd.chance
		end
	end
	return total
end

function VariantMachine.fee(value: number): number
	return math.floor(math.max(0, value) * Config.FeeShare)
end

-- One pull: which effect (its index in caught.effects) is used up, and the variant the
-- monster gets (nil for a miss). Doesn't change the monster; see apply.
function VariantMachine.roll(caught: Value.CaughtMonster, random: Random?): (number, string?)
	local rng = random or Random.new()
	local index = math.clamp(math.floor(rng:NextNumber() * #caught.effects) + 1, 1, #caught.effects)
	local roll = rng:NextNumber() * 100
	for _, odd in VariantMachine.odds(caught.variant) do
		roll -= odd.chance
		if roll < 0 then
			return index, if odd.possible then odd.id else nil
		end
	end
	return index, nil
end

-- Uses up the effect and gives the variant (if any). Returns the effect that was used up.
function VariantMachine.apply(caught: Value.CaughtMonster, index: number, variant: string?): string
	local effects = table.clone(caught.effects)
	local used = table.remove(effects, index) :: string
	caught.effects = effects
	if variant and VariantMachine.better(variant, caught.variant) then
		caught.variant = variant
	end
	return used
end

return VariantMachine
