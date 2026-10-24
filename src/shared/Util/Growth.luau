--!strict
-- Growth Chamber rules (numbers in Config/Growth). A win multiplies a monster's weight by its
-- mode's `win`, a loss by its `lose` (a hard push that fails shrinks it). Its size follows
-- its new weight, down as well as up. Every go uses one of its Growth.Charges, win or lose.
-- The hidden growth gene doesn't matter here (it only decides natural growth, Util/Weight).
-- Pure functions so they can be tested outside Roblox. Settle the monster first.

local GrowthConfig = require("../Config/Growth")
local WeightConfig = require("../Config/Weight")
local Rng = require("./Rng")
local Value = require("./Value")
local Weight = require("./Weight")

local Growth = {}

local modes: { [string]: GrowthConfig.Mode } = {}
for _, mode in GrowthConfig.Modes do
	modes[mode.id] = mode
end

function Growth.mode(id: unknown): GrowthConfig.Mode?
	return if typeof(id) == "string" then modes[id] else nil
end

-- How many more times this monster can go in the chamber.
function Growth.chargesLeft(caught: Value.CaughtMonster): number
	return math.max(0, GrowthConfig.Charges - (caught.growUsed or 0))
end

-- The fee for one go in this mode, from the monster's sell value.
function Growth.fee(value: number, mode: GrowthConfig.Mode): number
	return math.floor(math.max(0, value) * mode.feeShare)
end

function Growth.roll(mode: GrowthConfig.Mode, random: Random?): boolean
	return Rng.chance(mode.chance, random)
end

-- One go in the chamber: changes its weight (and size) and uses a charge. Returns its weight
-- before and after.
function Growth.apply(caught: Value.CaughtMonster, mode: GrowthConfig.Mode, won: boolean): (number, number)
	local before = caught.kg or Weight.valueMultiplier(caught.size, nil) * WeightConfig.KgPerValue
	local after = math.max(0.1, math.floor(before * (if won then mode.win else mode.lose) * 10) / 10)
	caught.kg = after
	caught.size = Weight.sizeFor(after)
	caught.growUsed = (caught.growUsed or 0) + 1
	return before, after
end

return Growth
