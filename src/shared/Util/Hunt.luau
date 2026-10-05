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

-- Hearts after taking damage; at 0 the carried monster is dropped.
function Hunt.afterDamage(hearts: number, damage: number): number
	return math.max(0, hearts - math.max(0, damage))
end

return Hunt
