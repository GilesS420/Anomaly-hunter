--!strict
-- Weight rules (numbers in Config/Weight). Works from timestamps (os.time() seconds) so
-- growth rolls keep happening while nobody is looking: call Weight.settle(monster, now) after
-- Care.settle and before reading its weight or size.
-- Pure functions so they can be tested outside Roblox.

local Rng = require("./Rng")
local Sizes = require("../Config/Sizes")
local WeightConfig = require("../Config/Weight")

local Weight = {}

-- The fields of a caught monster (Util/Value.CaughtMonster) that weight uses.
export type Growing = {
	size: string,
	familiarity: number,
	kg: number?, -- its weight; nil until it first settles (just caught)
	kgAt: number?, -- os.time() of its last growth check
	gene: string?, -- hidden growth gene (Config/Weight.Genes), rolled with its weight
}

local CheckSeconds = WeightConfig.CheckMinutes * 60

local order: { [string]: number } = { None = 0 }
local byId: { [string]: Sizes.Size } = {}
for i, size in Sizes do
	order[size.id] = i
	byId[size.id] = size
end

local genes: { [string]: WeightConfig.Gene } = {}
for _, gene in WeightConfig.Genes do
	genes[gene.id] = gene
end

local function startKg(sizeId: string): number
	return (WeightConfig.StartKg :: { [string]: number })[sizeId] or WeightConfig.StartKg.Normal
end

-- The size a monster of this weight is drawn at.
function Weight.sizeFor(kg: number): string
	local best = Sizes[1].id
	for _, size in Sizes do
		if kg >= startKg(size.id) and startKg(size.id) >= startKg(best) then
			best = size.id
		end
	end
	return best
end

-- A random weight for a monster just caught at this size.
function Weight.roll(sizeId: string, random: Random?): number
	local size = byId[sizeId] or byId.Normal
	local rng = random or Random.new()
	local spread = WeightConfig.CatchSpread
	local kg = size.valueMultiplier * WeightConfig.KgPerValue * (1 - spread + rng:NextNumber() * 2 * spread)
	return math.floor(kg * 10) / 10
end

function Weight.rollGene(random: Random?): string
	return Rng.pickWeighted(WeightConfig.Genes, function(gene)
		return gene.weight
	end, random).id
end

-- True if its gene still lets it grow past the size it is now.
function Weight.canGrow(caught: Growing): boolean
	local gene = genes[caught.gene or ""]
	if not gene or not gene.maxSize then
		return gene ~= nil
	end
	return (order[caught.size] or 0) < (order[gene.maxSize] or 0)
end

-- One growth spurt: adds SpurtMin to SpurtMax of its weight, but never past what its gene
-- allows (it stops at the top of its gene's biggest size). Returns true if its size changed.
function Weight.spurt(caught: Growing, random: Random?, ignoreGene: boolean?): boolean
	if not ignoreGene and not Weight.canGrow(caught) then
		return false
	end
	local rng = random or Random.new()
	local kg = caught.kg or Weight.roll(caught.size, rng)
	local share = WeightConfig.SpurtMin
		+ rng:NextNumber() ^ WeightConfig.SpurtSkew * (WeightConfig.SpurtMax - WeightConfig.SpurtMin)
	kg *= 1 + share
	local gene = genes[caught.gene or ""]
	if not ignoreGene and gene and gene.maxSize then
		-- Stops just under the next size up from its gene's biggest.
		local ceiling = math.huge
		for _, size in Sizes do
			if order[size.id] == (order[gene.maxSize] or 0) + 1 then
				ceiling = startKg(size.id) - 0.1
			end
		end
		kg = math.min(kg, math.max(ceiling, caught.kg or 0))
	end
	caught.kg = math.floor(kg * 10) / 10
	local size = Weight.sizeFor(caught.kg :: number)
	if (order[size] or 0) > (order[caught.size] or 0) then
		caught.size = size
		return true
	end
	return false
end

-- Brings a monster's growth up to date at `now`: one SpurtChance roll for every CheckMinutes
-- that passed while it was fully familiar (settle Familiarity first). A monster without a
-- weight (just caught) gets one for its size and a gene. Returns true if its size changed.
function Weight.settle(caught: Growing, now: number, random: Random?): boolean
	local kg = caught.kg
	if typeof(kg) ~= "number" or kg ~= kg or kg <= 0 or not caught.gene then
		-- Just caught (or weighed under the first rules, before genes): weigh it afresh.
		caught.kg = Weight.roll(caught.size, random)
		caught.gene = Weight.rollGene(random)
		caught.kgAt = now
		return false
	end
	local from = caught.kgAt or now
	local checks = math.floor(math.max(0, now - from) / CheckSeconds)
	caught.kgAt = from + checks * CheckSeconds
	if caught.familiarity < 1 or not Weight.canGrow(caught) then
		return false
	end
	checks = math.min(checks, WeightConfig.MaxOfflineDays * 24 * 60 / WeightConfig.CheckMinutes)
	local changed = false
	for _ = 1, checks do
		if Rng.chance(WeightConfig.SpurtChance, random) then
			changed = Weight.spurt(caught, random) or changed
		end
	end
	return changed
end

-- One minute of a live Watcher event with this growthMultiplier: an extra spurt roll.
-- Returns whether it spurted and whether its size changed.
function Weight.eventRoll(caught: Growing, growthMultiplier: number, random: Random?): (boolean, boolean)
	if not caught.kg or not Weight.canGrow(caught) then
		return false, false
	end
	if not Rng.chance(WeightConfig.EventSpurtChance * growthMultiplier, random) then
		return false, false
	end
	return true, Weight.spurt(caught, random)
end

-- What its weight multiplies its value by: kg / KgPerValue. Without a weight (wild
-- monsters) it's the size's multiplier from Config/Sizes.
function Weight.valueMultiplier(sizeId: string, kg: number?): number
	local size = byId[sizeId]
	assert(size, "unknown size " .. sizeId)
	return if kg then kg / WeightConfig.KgPerValue else size.valueMultiplier
end

-- How big it's drawn (Normal = 1): Config/Sizes, except a Titan, which grows a step every
-- time it doubles in weight, with no limit (see Config/Weight.EngineMaxScale).
function Weight.drawScale(sizeId: string, kg: number?): number
	local size = byId[sizeId]
	if not size then
		return 1
	end
	if sizeId ~= "Titan" or not kg then
		return size.scale
	end
	local doublings = math.max(0, math.floor(math.log(kg / WeightConfig.StartKg.Titan, 2) + 1e-6))
	return math.min(
		WeightConfig.EngineMaxScale,
		WeightConfig.TitanStartScale + doublings * WeightConfig.TitanScaleStep
	)
end

-- "54 kg", "320 kg", "1.2 t".
function Weight.text(kg: number): string
	if kg >= 1000 then
		return `{math.floor(kg / 100) / 10} t`
	end
	return if kg < 10 then `{math.floor(kg * 10) / 10} kg` else `{math.floor(kg)} kg`
end

return Weight
