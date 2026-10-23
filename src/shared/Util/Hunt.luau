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

-- The furthest zone the player has opened (the Portals button lands at its gate), or nil.
function Hunt.newestZone(wingsOwned: number): Zones.Zone?
	local newest: Zones.Zone? = nil
	for _, zone in Zones.List do
		if Hunt.isZoneUnlocked(zone.index, wingsOwned) and (newest == nil or zone.index > newest.index) then
			newest = zone
		end
	end
	return newest
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

export type Point = { x: number, y: number, z: number }

-- Did a walk from `from` to `to` pass through (or end in) a box centred on 0,0,0 with these
-- half sizes? Both points are in the box's own space (part.CFrame:PointToObjectSpace). Used
-- for portals: a hunter walking fast through a thin gate can be past it between two checks,
-- so checking only where they stand now would miss them.
function Hunt.walkCrossesBox(from: Point, to: Point, half: Point): boolean
	local enter, leave = 0, 1
	for _, axis in { "x", "y", "z" } do
		local a: number, b: number, h: number = (from :: any)[axis], (to :: any)[axis], (half :: any)[axis]
		local step = b - a
		if math.abs(step) < 1e-9 then
			if a < -h or a > h then
				return false -- moving alongside the box, outside it
			end
		else
			local t1, t2 = (-h - a) / step, (h - a) / step
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			enter = math.max(enter, t1)
			leave = math.min(leave, t2)
			if enter > leave then
				return false
			end
		end
	end
	return true
end

-- Hearts after taking damage; at 0 the carried monster is dropped.
function Hunt.afterDamage(hearts: number, damage: number): number
	return math.max(0, hearts - math.max(0, damage))
end

return Hunt
