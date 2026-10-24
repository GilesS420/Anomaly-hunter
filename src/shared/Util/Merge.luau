--!strict
-- Merger rules (numbers in Config/Merger). Two monsters of the same kind go in, a main and a
-- donor. On success the donor fuses into the main: the main gains DonorKgShare of the
-- donor's weight (its size follows) and every effect it doesn't have yet, and keeps the
-- better variant, the better hidden gene, the higher Familiarity and the higher number of
-- used Growth Chamber charges. On failure only the donor is lost.
-- Pure functions so they can be tested outside Roblox. Settle both monsters first.

local MergerConfig = require("../Config/Merger")
local Monsters = require("../Config/Monsters")
local Sizes = require("../Config/Sizes")
local Variants = require("../Config/Variants")
local WeightConfig = require("../Config/Weight")
local Rng = require("./Rng")
local Value = require("./Value")
local Weight = require("./Weight")

local Merge = {}

export type Problem = "Same" | "Different" | "Locked" | "Unknown"

local sizeOrder: { [string]: number } = {}
for i, size in Sizes do
	sizeOrder[size.id] = i
end
-- Variants are listed rarest first; a higher rank is better.
local variantRank: { [string]: number } = {}
for i, variant in Variants do
	variantRank[variant.id] = #Variants - i + 1
end
-- Genes are listed from never growing to no limit; a higher rank is better.
local geneRank: { [string]: number } = {}
for i, gene in WeightConfig.Genes do
	geneRank[gene.id] = i
end

-- Why these two can't be merged, or nil if they can. The donor can't be hearted (♥).
function Merge.problem(main: Value.CaughtMonster, donor: Value.CaughtMonster): Problem?
	if main == donor or (main.uid ~= nil and main.uid == donor.uid) then
		return "Same"
	end
	if not Monsters[main.monsterId] or not Monsters[donor.monsterId] then
		return "Unknown"
	end
	if main.monsterId ~= donor.monsterId then
		return "Different"
	end
	if donor.locked then
		return "Locked"
	end
	return nil
end

-- The success chance in percent for merging two of this monster.
function Merge.chance(monsterId: string): number
	local monster = Monsters[monsterId]
	return if monster then MergerConfig.Success[monster.rarity] or 0 else 0
end

-- The fee for merging this donor in, from its sell value.
function Merge.fee(donorValue: number): number
	return math.floor(math.max(0, donorValue) * MergerConfig.FeeShare)
end

function Merge.roll(monsterId: string, random: Random?): boolean
	return Rng.chance(Merge.chance(monsterId), random)
end

local function kgOf(caught: Value.CaughtMonster): number
	return caught.kg or Weight.valueMultiplier(caught.size, nil) * WeightConfig.KgPerValue
end

-- Fuses the donor into the main (a successful merge). Changes main; the donor is left as it
-- was, for the caller to take out of the save.
function Merge.apply(main: Value.CaughtMonster, donor: Value.CaughtMonster)
	local kg = kgOf(main) + kgOf(donor) * MergerConfig.DonorKgShare
	main.kg = math.floor(kg * 10) / 10
	local size = Weight.sizeFor(main.kg :: number)
	if (sizeOrder[size] or 0) > (sizeOrder[main.size] or 0) then
		main.size = size
	end

	local effects = table.clone(main.effects)
	for _, effectId in donor.effects do
		if Value.fits(effects, effectId, main.monsterId) == "Ok" then
			table.insert(effects, effectId)
		end
	end
	main.effects = effects

	if (variantRank[donor.variant or ""] or 0) > (variantRank[main.variant or ""] or 0) then
		main.variant = donor.variant
	end
	if (geneRank[donor.gene or ""] or 0) > (geneRank[main.gene or ""] or 0) then
		main.gene = donor.gene
	end
	main.familiarity = math.max(main.familiarity, donor.familiarity)
	local used = math.max(main.growUsed or 0, donor.growUsed or 0)
	main.growUsed = if used > 0 then used else nil
end

-- What the main would look like after a successful merge, without changing either.
function Merge.preview(main: Value.CaughtMonster, donor: Value.CaughtMonster): Value.CaughtMonster
	local copy = table.clone(main)
	copy.effects = table.clone(main.effects)
	Merge.apply(copy, donor)
	return copy
end

return Merge
