--!strict
-- Monster attack rules (numbers and the roster in Config/Attacks). Pure functions on plain
-- floor coordinates (x, z) so they can be tested outside Roblox; MonsterAiService does the
-- timing, the moving and the hitting.

local AttackConfig = require("../Config/Attacks")
local Roam = require("./Roam")

local Attacks = {}

export type Attack = {
	kind: AttackConfig.Kind,
	text: string,
	damage: number,
	range: number,
	radius: number,
	effectSeconds: number,
}

-- A hunter a monster could go after: where they stand and how many monsters already are.
export type Hunter = { x: number, z: number, attackers: number, mine: boolean }

-- The attack a monster uses, or nil if it has none (event monsters, unknown ids).
function Attacks.forMonster(monsterId: string, rarityOrder: number): Attack?
	local entry = AttackConfig.Monsters[monsterId]
	if not entry then
		return nil
	end
	local kind = AttackConfig.Kinds[entry.kind]
	local damage = entry.damage or kind.damage
	if damage == 0 and rarityOrder >= AttackConfig.HarmfulFromRarity and entry.kind ~= "Blink" then
		damage = 1
	end
	return {
		kind = entry.kind,
		text = entry.text,
		damage = damage,
		range = kind.range,
		radius = kind.radius,
		effectSeconds = kind.effectSeconds,
	}
end

-- Seconds between two attacks by one monster (rarer attacks more often).
function Attacks.cooldown(rarityOrder: number): number
	return math.max(AttackConfig.CooldownMin, AttackConfig.CooldownBase - rarityOrder)
end

-- Which hunter a monster at (x, z) goes after: the nearest one within NoticeRadius who isn't
-- already busy with MaxAttackersPerHunter other monsters (its own target always counts as
-- free). Returns the index in hunters, or nil.
function Attacks.pickTarget(x: number, z: number, hunters: { Hunter }): number?
	local best, bestDistance = nil, AttackConfig.NoticeRadius
	for index, hunter in hunters do
		if hunter.mine or hunter.attackers < AttackConfig.MaxAttackersPerHunter then
			local distance = math.sqrt((hunter.x - x) ^ 2 + (hunter.z - z) ^ 2)
			if distance <= bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	return best
end

-- Where a monster at m walks to when its hunter at h is out of range: most of the way along
-- the line between them, stopping inside the attack range.
function Attacks.chaseSpot(mx: number, mz: number, hx: number, hz: number, range: number): (number, number)
	local dx, dz = mx - hx, mz - hz
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1e-6 then
		return mx, mz
	end
	local keep = range * 0.6
	return hx + dx / distance * keep, hz + dz / distance * keep
end

-- Where the attack lands, locked in when the warning appears (so you can step out of it):
-- the end of a Charge's lane (it dashes a little past you, never further than its range plus
-- that bit), your spot for Throw and Slow, and the monster itself for Shockwave and Blind.
function Attacks.aim(attack: Attack, mx: number, mz: number, hx: number, hz: number): (number, number)
	if attack.kind == "Charge" then
		local dx, dz = hx - mx, hz - mz
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance < 1e-6 then
			return mx, mz
		end
		local length = math.min(distance + 6, attack.range + 6)
		return mx + dx / distance * length, mz + dz / distance * length
	elseif attack.kind == "Throw" or attack.kind == "Slow" then
		return hx, hz
	end
	return mx, mz
end

-- True if a hunter at p is caught by an attack from a monster at m aimed at a.
function Attacks.hits(
	attack: Attack,
	mx: number,
	mz: number,
	ax: number,
	az: number,
	px: number,
	pz: number
): boolean
	local kind = attack.kind
	if kind == "Charge" then
		return Roam.segmentDistance(px, pz, mx, mz, ax, az) <= attack.radius
	elseif kind == "Throw" or kind == "Slow" then
		return math.sqrt((px - ax) ^ 2 + (pz - az) ^ 2) <= attack.radius
	elseif kind == "Shockwave" or kind == "Blind" then
		return math.sqrt((px - mx) ^ 2 + (pz - mz) ^ 2) <= attack.radius
	end
	return false
end

-- Direction (unit x, z) a hit pushes a hunter at p: away from the monster, or along a Charge.
function Attacks.pushDirection(
	attack: Attack,
	mx: number,
	mz: number,
	ax: number,
	az: number,
	px: number,
	pz: number
): (number, number)
	local dx, dz = px - mx, pz - mz
	if attack.kind == "Charge" then
		dx, dz = ax - mx, az - mz
	end
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then
		return 1, 0
	end
	return dx / length, dz / length
end

-- The message for a hunter who got hit: "Gravepup charged at you! -1 heart".
function Attacks.hitMessage(name: string, attack: Attack): string
	local cost = if attack.damage == 1
		then " -1 heart"
		elseif attack.damage > 1 then ` -{attack.damage} hearts`
		else ""
	return `{name} {attack.text}!{cost}`
end

return Attacks
