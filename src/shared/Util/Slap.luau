--!strict
-- Who may slap whom (Config/Slap). Shared by the server, which decides, and the client, which
-- only shows the Slap button when a slap would land. Pure, so tests/run.luau can check it.

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

-- Why this slap can't happen, or nil if it can. now and the times are server times; slack is
-- extra range (the server's lag allowance).
function Slap.blocked(
	slapper: Hunter,
	target: Hunter,
	now: number,
	readyAt: number, -- when the slapper's cooldown is over
	guardUntil: number, -- when the target's guard after their last slap is over
	slack: number
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
	if distance > SlapConfig.Range + slack then
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

return Slap
