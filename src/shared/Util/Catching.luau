--!strict
-- Catch rules shared by the server (which decides) and the client (which shows the meter).
-- Pure functions so they can be tested outside Roblox.

local Rarities = require("../Config/Rarities")
local Shop = require("../Config/Shop")
local Sizes = require("../Config/Sizes")
local Tools = require("../Config/Tools")

local Catching = {}

local vacuumTiers: { [string]: number } = {}
for _, item in Shop.Workshop do
	if item.kind == "Vacuum" then
		vacuumTiers[item.id] = item.tier or 1
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

function Catching.canVacuum(vacuumId: string, sizeId: string, rarityId: string): boolean
	return Catching.vacuumTier(vacuumId) >= Catching.requiredTier(sizeId, rarityId)
end

-- Meter filled per second for this vacuum against this rarity.
function Catching.catchRate(vacuumId: string, rarityId: string): number
	local vacuum = Tools.Vacuums[vacuumId]
	if not vacuum then
		return 0
	end
	local rarity = Rarities[rarityId]
	local steps = if rarity then rarity.order - 1 else 0
	return vacuum.catchSpeed / (1 + steps * Tools.Tug.ResistPerRarity)
end

-- Moves the catch meter. pull is the hunter's sideways input (-1, 0 or 1) and tug the
-- monster's direction (-1 or 1); pulling against the tug fills the meter.
function Catching.step(progress: number, pull: number, tug: number, rate: number, dt: number): number
	local factor
	if pull == 0 then
		factor = Tools.Tug.IdleFactor
	elseif pull == -tug then
		factor = 1
	else
		factor = Tools.Tug.WrongFactor
	end
	return math.clamp(progress + factor * rate * dt, 0, 1)
end

return Catching
