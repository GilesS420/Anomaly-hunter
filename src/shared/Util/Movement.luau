--!strict
-- The movement anti-cheat rules (Config/Movement). Pure, so tests/run.luau can check them;
-- server MovementService feeds in where each hunter is and pulls them back on a "no".
--
--   speed  a "walk budget" fills up at the fastest allowed walking speed (up to BurstSeconds
--          of walking) and every stud walked sideways spends it. Spent below zero: too fast,
--          or a teleport. Up and down don't count (falling is fine; rising is the jump rule).
--   jump   in the air, more than jumpHeight + RiseSlack above the floor they left from.
--   fly    in the air for HoverSeconds without dropping MinDrop studs.

local Config = require("../Config/Movement")

export type Limits = {
	maxSpeed: number, -- studs per second, sideways
	jumpHeight: number, -- studs
}

export type State = {
	-- Last place they stood on something: where a pulled-back player goes.
	safeX: number,
	safeY: number,
	safeZ: number,
	-- Where they were at the last check.
	lastX: number,
	lastZ: number,
	budget: number,
	inAir: boolean,
	liftY: number, -- the height they left the floor at
	hoverY: number, -- height at the start of this stretch of HoverSeconds in the air
	hoverSeconds: number,
}

local Movement = {}

-- The most studs a player may cover at once after standing still (lag catch-up included).
function Movement.cap(limits: Limits): number
	return limits.maxSpeed * Config.BurstSeconds + Config.SlackStuds
end

-- A fresh start at (x, y, z), as if standing there with a full walk budget.
function Movement.new(x: number, y: number, z: number, limits: Limits): State
	return {
		safeX = x,
		safeY = y,
		safeZ = z,
		lastX = x,
		lastZ = z,
		budget = Movement.cap(limits),
		inAir = false,
		liftY = y,
		hoverY = y,
		hoverSeconds = 0,
	}
end

-- The fastest a player may walk: the hub speed (or their own WalkSpeed, if the game made it
-- higher), times their walk pass, times SpeedTolerance.
function Movement.maxSpeed(walkSpeed: number, hubSpeed: number, passMultiplier: number): number
	return math.max(walkSpeed, hubSpeed * passMultiplier) * Config.SpeedTolerance
end

-- One check, `dt` seconds after the last one, of a player now at (x, y, z), standing on
-- something or not. Returns nil when it's fine, else why not: "speed", "jump" or "fly".
-- On a "no" the state is NOT changed (except the budget): the caller pulls the player back
-- to safeX/safeY/safeZ and calls Movement.pulledBack.
function Movement.step(
	state: State,
	x: number,
	y: number,
	z: number,
	dt: number,
	grounded: boolean,
	limits: Limits
): string?
	local cap = Movement.cap(limits)
	local walked = math.sqrt((x - state.lastX) ^ 2 + (z - state.lastZ) ^ 2)
	state.budget = math.min(cap, state.budget + limits.maxSpeed * dt) - walked
	if state.budget < 0 then
		return "speed"
	end

	if grounded then
		state.inAir = false
		state.safeX, state.safeY, state.safeZ = x, y, z
		state.liftY = y
		state.hoverY = y
		state.hoverSeconds = 0
	else
		if not state.inAir then
			state.inAir = true
			state.hoverY = state.liftY
			state.hoverSeconds = 0
		end
		if y - state.liftY > limits.jumpHeight + Config.RiseSlack then
			return "jump"
		end
		state.hoverSeconds += dt
		if state.hoverSeconds >= Config.HoverSeconds then
			if state.hoverY - y < Config.MinDrop then
				return "fly"
			end
			state.hoverY = y
			state.hoverSeconds = 0
		end
	end
	state.lastX, state.lastZ = x, z
	return nil
end

-- After the caller moved a player back to the safe spot. The walk budget starts empty, so
-- a speed cheat that keeps going only ever gets normal walking speed out of it.
function Movement.pulledBack(state: State, limits: Limits)
	local fresh = Movement.new(state.safeX, state.safeY, state.safeZ, limits)
	fresh.budget = 0
	for key, value in fresh :: any do
		(state :: any)[key] = value
	end
end

-- Counts a pull-back at `now` and drops the ones older than StrikeWindow. Returns how many
-- are left in the window, and whether that's enough to kick (never when KickStrikes is 0).
function Movement.strike(strikes: { number }, now: number): (number, boolean)
	table.insert(strikes, now)
	while strikes[1] and now - strikes[1] > Config.StrikeWindow do
		table.remove(strikes, 1)
	end
	return #strikes, Config.KickStrikes > 0 and #strikes >= Config.KickStrikes
end

return Movement
