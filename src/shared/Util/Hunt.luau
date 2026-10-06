--!strict
-- Hunt run rules shared by server and client. Pure functions so they can be tested.

local Wings = require("../Config/Wings")
local Zones = require("../Config/Zones")

local Hunt = {}

function Hunt.zoneByIndex(zoneIndex: number): Zones.Zone?
	for _, zone in Zones.List do
		if zone.index == zoneIndex then
			return zone
		end
	end
	return nil
end

-- A zone opens once its wing is owned (wings are bought in order) and it has shipped.
-- The zone with this id ("PumpkinGraveyard"), or nil. Takes anything, e.g. a player attribute.
function Hunt.zoneById(zoneId: unknown): Zones.Zone?
	if typeof(zoneId) ~= "string" then
		return nil
	end
	for _, zone in Zones.List do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

function Hunt.isZoneUnlocked(zoneIndex: number, wingsOwned: number): boolean
	local zone = Hunt.zoneByIndex(zoneIndex)
	if not zone or not zone.launch then
		return false
	end
	for _, wing in Wings.List do
		if wing.unlocksZone == zoneIndex then
			return wing.order <= wingsOwned
		end
	end
	return false
end

-- Why a zone's gate won't open, as a message for the player, or nil if it's open.
function Hunt.lockedReason(zoneIndex: number, wingsOwned: number): string?
	local zone = Hunt.zoneByIndex(zoneIndex)
	if not zone then
		return "This gate doesn't lead anywhere yet."
	end
	if not zone.launch then
		return `{zone.name} opens in a future update.`
	end
	if not Hunt.isZoneUnlocked(zoneIndex, wingsOwned) then
		return `{zone.name} is locked. Buy the {zone.wing} wing for your mansion to open it.`
	end
	return nil
end

-- Hearts after taking damage; at 0 the carried monster is dropped.
function Hunt.afterDamage(hearts: number, damage: number): number
	return math.max(0, hearts - math.max(0, damage))
end

return Hunt
