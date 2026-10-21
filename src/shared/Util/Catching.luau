--!strict
-- Catch rules shared by the server (which decides) and the client (which shows the meter).
-- Pure functions so they can be tested outside Roblox.

local Monsters = require("../Config/Monsters")
local Rarities = require("../Config/Rarities")
local Shop = require("../Config/Shop")
local Sizes = require("../Config/Sizes")
local Tools = require("../Config/Tools")

local Catching = {}

local vacuumTiers: { [string]: number } = {}
local vacuumRanks: { [string]: number } = {} -- 1 for the Dust Buster, up the shop's order
local rank = 0
for _, item in Shop.Workshop do
	if item.kind == "Vacuum" then
		vacuumTiers[item.id] = item.tier or 1
		rank += 1
		vacuumRanks[item.id] = rank
	end
end

-- Lowest vacuum tier that can catch this size and rarity (Big needs Phantom Vac,
-- Colossal or Mythic/Divine need the Void Vac).
function Catching.requiredTier(sizeId: string, rarityId: string): number
	local tier = 1
	for _, size in Sizes do
		if size.id == sizeId then
			tier = size.vacuumTier
		end
	end
	local rarity = Rarities[rarityId]
	if rarity and rarity.vacuumTier then
		tier = math.max(tier, rarity.vacuumTier)
	end
	return tier
end

function Catching.vacuumTier(vacuumId: string): number
	return vacuumTiers[vacuumId] or 0
end

-- The weakest vacuum that can catch this monster, for event monsters that set one.
function Catching.neededVacuum(monsterId: string?): string?
	local monster = if monsterId then Monsters[monsterId] else nil
	return monster and monster.vacuum
end

-- Where a vacuum sits in the shop's order (Dust Buster 1); 0 if it isn't a vacuum.
function Catching.rank(vacuumId: string): number
	return vacuumRanks[vacuumId] or 0
end

-- Whether this vacuum is the monster's needed vacuum or a later one in the shop.
function Catching.strongEnough(vacuumId: string, monsterId: string?): boolean
	local needed = Catching.neededVacuum(monsterId)
	return needed == nil or (vacuumRanks[vacuumId] or 0) >= (vacuumRanks[needed] or math.huge)
end

function Catching.canVacuum(vacuumId: string, sizeId: string, rarityId: string, monsterId: string?): boolean
	return Catching.vacuumTier(vacuumId) >= Catching.requiredTier(sizeId, rarityId)
		and Catching.strongEnough(vacuumId, monsterId)
end

-- Seconds of holding needed to catch this rarity with this vacuum (math.huge if unknown).
function Catching.catchSeconds(vacuumId: string, rarityId: string): number
	local vacuum = Tools.Vacuums[vacuumId]
	if not vacuum then
		return math.huge
	end
	local rarity = Rarities[rarityId]
	local steps = if rarity then rarity.order - 1 else 0
	return vacuum.catchSeconds * (1 + steps * Tools.ResistPerRarity)
end

-- How far away (studs) this vacuum lets you start and keep a catch, slack included.
function Catching.reach(vacuumId: string): number
	local vacuum = Tools.Vacuums[vacuumId]
	return if vacuum then vacuum.reach + Tools.ReachSlack else 0
end

-- Seconds a monster stays dazed after this vacuum lets go of it.
function Catching.stunSeconds(vacuumId: string): number
	local vacuum = Tools.Vacuums[vacuumId]
	return if vacuum then vacuum.stunSeconds else 1
end

-- How many monsters this vacuum carries per trip (at least 1).
function Catching.bagSize(vacuumId: string): number
	local vacuum = Tools.Vacuums[vacuumId]
	return if vacuum then math.max(1, vacuum.bag) else 1
end

return Catching
