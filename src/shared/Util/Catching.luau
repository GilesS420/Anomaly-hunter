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

-- How far away (studs) this flashlight lets you start and keep a catch, slack included.
function Catching.reach(flashlightId: string): number
	local flashlight = Tools.Flashlights[flashlightId]
	return if flashlight then flashlight.reach + Tools.ReachSlack else 0
end

return Catching
