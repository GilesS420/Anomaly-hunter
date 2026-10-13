--!strict
-- Monster attack rules shared by server and tests. Pure functions on plain numbers, so they
-- run in the Luau CLI too. See Config/Attacks for what each attack does.

local AttackConfig = require("../Config/Attacks")

local Attacks = {}

export type Hunter = { id: number, x: number, z: number, ready: boolean }

-- The attack kind this monster uses ("Charge" if it isn't listed).
function Attacks.kindFor(monsterId: string): AttackConfig.Kind
	return AttackConfig.ByMonster[monsterId] or AttackConfig.Default
end

-- The kind's numbers (damage, hit radius...).
function Attacks.stats(kind: AttackConfig.Kind): AttackConfig.AttackKind
	return AttackConfig.Kinds[kind]
end

-- How aggressive a monster of this rarity is (Common's numbers for an unknown rarity).
function Attacks.aggression(rarityId: string): AttackConfig.Aggression
	return AttackConfig.Aggression[rarityId] or AttackConfig.Aggression.Common
end

local function flatDistance(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- The closest ready hunter within range of the monster, or nil. Hunters who aren't ready
-- (just hit, just arrived, or already being attacked) are skipped.
function Attacks.pickTarget(x: number, z: number, range: number, hunters: { Hunter }): number?
	local best: number? = nil
	local bestDistance = range
	for _, hunter in hunters do
		if hunter.ready then
			local distance = flatDistance(x, z, hunter.x, hunter.z)
			if distance <= bestDistance then
				best = hunter.id
				bestDistance = distance
			end
		end
	end
	return best
end

-- True if a hunter at (hx, hz) is caught by an attack landing at (ax, az). Height is ignored,
-- so jumping doesn't dodge; walking away does.
function Attacks.hits(kind: AttackConfig.Kind, ax: number, az: number, hx: number, hz: number): boolean
	return flatDistance(ax, az, hx, hz) <= Attacks.stats(kind).hitRadius
end

-- The spot a charge or slime is aimed at: where the hunter stood when the warning began.
-- Scream and Flash go off around the monster itself.
function Attacks.aimsAtHunter(kind: AttackConfig.Kind): boolean
	return kind == "Charge" or kind == "Slime" or kind == "Vanish"
end

-- Where a Vanish monster pops up: `distance` studs from the hunter, on the side it came from
-- (straight ahead of the hunter's spot if the two are on top of each other).
function Attacks.popSpot(mx: number, mz: number, hx: number, hz: number, distance: number): (number, number)
	local dx, dz = mx - hx, mz - hz
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.01 then
		return hx + distance, hz
	end
	return hx + dx / length * distance, hz + dz / length * distance
end

-- Push direction for a knockback: from the attack spot towards the hunter, flat, length 1.
function Attacks.pushDirection(ax: number, az: number, hx: number, hz: number): (number, number)
	local dx, dz = hx - ax, hz - az
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.01 then
		return 1, 0
	end
	return dx / length, dz / length
end

return Attacks
