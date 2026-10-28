--!strict
-- Who may slap whom, and with which slapper (Config/Slap). Shared by the server, which
-- decides, and the client, which only shows the Slap button when a slap would land. Pure, so
-- tests/run.luau can check it.

local SlapConfig = require("../Config/Slap")
local Travel = require("./Travel")

export type Hunter = {
	alive: boolean,
	zone: string?, -- the zone they're in; nil in the hub (or their mansion)
	tutorial: boolean,
	x: number,
	z: number,
}

local Slap = {}

local byId: { [string]: SlapConfig.Slapper } = {}
for _, slapper in SlapConfig.Slappers do
	byId[slapper.id] = slapper
end

-- A slapper's stats by its item id, or nil if it isn't a slapper.
function Slap.get(id: string?): SlapConfig.Slapper?
	return if id then byId[id] else nil
end

-- The best slapper in an inventory (item id -> count), or nil if they have none.
function Slap.best(inventory: { [string]: number }): SlapConfig.Slapper?
	local best = nil
	for _, slapper in SlapConfig.Slappers do
		if (inventory[slapper.id] or 0) > 0 then
			best = slapper
		end
	end
	return best
end

-- Why this slap can't happen, or nil if it can. now and the times are server times; reach is
-- the slapper's reach in studs (lag slack included on the server).
function Slap.blocked(
	slapper: Hunter,
	target: Hunter,
	now: number,
	readyAt: number, -- when the slapper's cooldown is over
	guardUntil: number, -- when the target's guard after their last slap is over
	reach: number
): string?
	if not slapper.alive or not target.alive then
		return "Dead"
	elseif slapper.tutorial or target.tutorial then
		return "Tutorial"
	elseif slapper.zone ~= target.zone then
		return "Apart"
	elseif
		slapper.zone == nil
		and (Travel.inPlot(slapper.x, slapper.z) or Travel.inPlot(target.x, target.z))
	then
		return "Mansion" -- mansions are safe
	end
	local distance = math.sqrt((slapper.x - target.x) ^ 2 + (slapper.z - target.z) ^ 2)
	if distance > reach then
		return "Far"
	elseif now < readyAt then
		return "Cooldown"
	elseif now < guardUntil then
		return "Guarded"
	end
	return nil
end

-- The flat direction (unit x, z) from the slapper to the target, to push them along.
function Slap.push(fromX: number, fromZ: number, toX: number, toZ: number): (number, number)
	local dx, dz = toX - fromX, toZ - fromZ
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.01 then
		return 0, 1
	end
	return dx / length, dz / length
end

-- When a thief slapped at `now` may steal again: the slap's lock, or a longer one they
-- already had (a weak slap never shortens a strong one's lock).
function Slap.stealLockUntil(slapper: SlapConfig.Slapper, now: number, lockedUntil: number?): number
	return math.max(now + slapper.stealLockSeconds, lockedUntil or 0)
end

return Slap
