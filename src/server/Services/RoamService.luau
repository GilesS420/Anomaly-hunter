--!strict
-- Monsters wandering around a zone or a mansion. The server decides every move as a "leg"
-- (glide from A to B between two server times) and publishes it as attributes on the model;
-- each client draws the glide smoothly itself (RoamController), so nothing moves part by part
-- over the network.
--
-- Orbs never overlap: a new leg is only allowed if its whole path stays clear of every other
-- orb's spot AND of the rest of their current path, and new spawns avoid all of those too.
-- Roamers are grouped (one group per zone or per mansion); only orbs in the same group are
-- compared, because different groups are far apart.
--
-- Replication contract (read by RoamController), on the Model:
--   RoamFrom (Vector3), RoamTo (Vector3), RoamStart (server time), RoamEnd (server time)
-- plus the CollectionService tag "Roamer".

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roam = require(ReplicatedStorage.Shared.Util.Roam)

local RoamService = {}

export type Options = { rects: { Roam.Rect }, radius: number, speed: number, group: string, at: Vector3 }

type Roamer = {
	model: Model,
	rects: { Roam.Rect },
	radius: number,
	speed: number,
	group: string,
	from: Vector3,
	to: Vector3,
	startTime: number,
	endTime: number,
	moving: boolean, -- true while a leg is in progress
	pauseUntil: number, -- no new leg before this server time
	held: boolean, -- frozen by a hunter's catch
	destroying: RBXScriptConnection,
}

local Tag = "Roamer"
local TickSeconds = 0.1 -- how often legs are checked (10 times a second)
local MaxLeg = 24 -- studs; legs mostly stay within this box around the orb so it wanders, not dashes
local MinLegSeconds = 0.5
local PauseMin, PauseMax = 0.5, 2.5 -- rest between legs
local RetrySeconds = 1 -- wait when no clear path was found (crowded)
local Candidates = 8 -- targets tried per new leg
local PathStep = 1 -- studs between the sample bodies placed along a path (small, so no gaps)

local random = Random.new()
local roamers: { [Model]: Roamer } = {}
local started = false

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Where the roamer is right now along its leg.
local function currentPosition(roamer: Roamer, at: number): Vector3
	if roamer.held or not roamer.moving then
		return roamer.to
	end
	return roamer.from:Lerp(roamer.to, Roam.alpha(roamer.startTime, roamer.endTime, at))
end

-- Height of the orb's centre above the floor rectangle it is over.
local function centreY(rects: { Roam.Rect }, x: number, z: number, radius: number, fallback: number): number
	for _, r in rects do
		if x >= r.minX and x <= r.maxX and z >= r.minZ and z <= r.maxZ then
			return r.y + radius + 0.5
		end
	end
	return fallback
end

-- Publishes the current leg to clients (order matters: From, To, Start, End).
local function publish(roamer: Roamer)
	local model = roamer.model
	model:SetAttribute("RoamFrom", roamer.from)
	model:SetAttribute("RoamTo", roamer.to)
	model:SetAttribute("RoamStart", roamer.startTime)
	model:SetAttribute("RoamEnd", roamer.endTime)
end

-- Moves the real part on the server too, so late joiners and streaming see the right spot.
local function settle(roamer: Roamer, position: Vector3)
	if roamer.model.PrimaryPart then
		roamer.model:PivotTo(CFrame.new(position))
	end
end

-- Bodies covering what one roamer occupies from now on: where it is, where it's going, and
-- a body every PathStep studs along the way. With orbs at least 0.9 studs across, the chain
-- of circles leaves at most ~0.15 studs uncovered, which the Roam.Gap of 1 stud absorbs.
local function addBodiesOf(roamer: Roamer, at: number, out: { Roam.Body })
	local here = currentPosition(roamer, at)
	local there = roamer.to
	local radius = roamer.radius
	table.insert(out, { x = here.X, z = here.Z, radius = radius })
	table.insert(out, { x = there.X, z = there.Z, radius = radius })

	local flat = Vector3.new(there.X - here.X, 0, there.Z - here.Z)
	local length = flat.Magnitude
	if length > PathStep then
		local steps = math.ceil(length / PathStep)
		for i = 1, steps - 1 do
			local t = i / steps
			table.insert(out, { x = here.X + flat.X * t, z = here.Z + flat.Z * t, radius = radius })
		end
	end
end

-- The rectangles cut down to a box around (x, z), so most legs are short wanders.
local function nearby(rects: { Roam.Rect }, x: number, z: number, radius: number): { Roam.Rect }
	local result = {}
	for _, r in rects do
		local clipped: Roam.Rect = {
			minX = math.max(r.minX, x - MaxLeg),
			maxX = math.min(r.maxX, x + MaxLeg),
			minZ = math.max(r.minZ, z - MaxLeg),
			maxZ = math.min(r.maxZ, z + MaxLeg),
			y = r.y,
		}
		if clipped.maxX - clipped.minX >= 2 * radius and clipped.maxZ - clipped.minZ >= 2 * radius then
			table.insert(result, clipped)
		end
	end
	return result
end

-- Tries to start a new leg. Returns false if the area around it is too crowded right now.
local function startLeg(roamer: Roamer, at: number): boolean
	local here = roamer.to
	local others = RoamService.bodies(roamer.group, roamer.model)

	-- If it already overlaps something (only when a mansion is over capacity and orbs had to
	-- be stacked), ignore those so it can walk out instead of being stuck forever.
	local blocking = others
	if not Roam.isFree(here.X, here.Z, roamer.radius, others) then
		blocking = {}
		for _, body in others do
			if Roam.isFree(here.X, here.Z, roamer.radius, { body }) then
				table.insert(blocking, body)
			end
		end
	end

	local close = nearby(roamer.rects, here.X, here.Z, roamer.radius)
	for attempt = 1, Candidates do
		-- Mostly short hops; the last tries look anywhere, so a crowded corner can't trap it.
		local pool = if attempt <= Candidates - 2 and #close > 0 then close else roamer.rects
		local point = Roam.findFreePoint(pool, roamer.radius, blocking, random, 12)
		if point and Roam.pathClear(here.X, here.Z, point.x, point.z, roamer.radius, blocking) then
			local target = Vector3.new(point.x, point.y + roamer.radius + 0.5, point.z)
			local distance = (target - here).Magnitude
			roamer.from = here
			roamer.to = target
			roamer.startTime = at
			roamer.endTime = at + math.max(distance / roamer.speed, MinLegSeconds)
			roamer.moving = true
			publish(roamer)
			return true
		end
	end
	return false
end

local function step()
	local at = now()
	for _, roamer in roamers do
		if roamer.held then
			continue
		end
		if roamer.moving then
			if at >= roamer.endTime then
				-- Arrived: rest a moment before the next leg.
				roamer.moving = false
				settle(roamer, roamer.to)
				roamer.pauseUntil = at + random:NextNumber(PauseMin, PauseMax)
			end
		elseif at >= roamer.pauseUntil then
			if not startLeg(roamer, at) then
				roamer.pauseUntil = at + RetrySeconds
			end
		end
	end
end

-- Starts a model roaming from `at` (the caller already picked a free spot). Only X and Z of
-- `at` matter when it's over one of the rectangles: the height is set so the orb floats just
-- above that floor (rect.y + radius + 0.5).
function RoamService.add(model: Model, opts: Options)
	if roamers[model] then
		RoamService.remove(model)
	end
	local start =
		Vector3.new(opts.at.X, centreY(opts.rects, opts.at.X, opts.at.Z, opts.radius, opts.at.Y), opts.at.Z)
	local at = now()
	local roamer: Roamer = {
		model = model,
		rects = opts.rects,
		radius = opts.radius,
		speed = math.max(opts.speed, 0.1),
		group = opts.group,
		from = start,
		to = start,
		startTime = at,
		endTime = at,
		moving = false,
		pauseUntil = at + random:NextNumber(0, PauseMax), -- stagger so they don't all set off together
		held = false,
		destroying = model.Destroying:Connect(function()
			RoamService.remove(model)
		end),
	}
	roamers[model] = roamer
	settle(roamer, start)
	publish(roamer)
	CollectionService:AddTag(model, Tag)
end

-- Stops a model roaming (it stays where it is).
function RoamService.remove(model: Model)
	local roamer = roamers[model]
	if not roamer then
		return
	end
	roamers[model] = nil
	roamer.destroying:Disconnect()
	CollectionService:RemoveTag(model, Tag)
end

-- New floor area for one roamer (it walks there on its next leg if it's outside).
function RoamService.setRects(model: Model, rects: { Roam.Rect })
	local roamer = roamers[model]
	if roamer then
		roamer.rects = rects
	end
end

-- New floor area for every roamer in a group (e.g. a mansion got a new wing).
function RoamService.setRectsForGroup(group: string, rects: { Roam.Rect })
	for _, roamer in roamers do
		if roamer.group == group then
			roamer.rects = rects
		end
	end
end

-- Where the model really is now (use this for distance checks, not the part's position).
function RoamService.position(model: Model): Vector3?
	local roamer = roamers[model]
	return if roamer then currentPosition(roamer, now()) else nil
end

-- Freezes the model on the spot (a hunter is catching it).
function RoamService.hold(model: Model)
	local roamer = roamers[model]
	if not roamer then
		return
	end
	local at = now()
	local here = currentPosition(roamer, at)
	roamer.held = true
	roamer.moving = false
	roamer.from = here
	roamer.to = here
	roamer.startTime = at
	roamer.endTime = at
	publish(roamer)
	settle(roamer, here)
end

-- Lets a held model go. It stays dazed for pauseSeconds, then wanders again.
function RoamService.release(model: Model, pauseSeconds: number)
	local roamer = roamers[model]
	if not roamer then
		return
	end
	roamer.held = false
	roamer.pauseUntil = math.max(roamer.pauseUntil, now() + math.max(pauseSeconds, 0))
end

function RoamService.isHeld(model: Model): boolean
	local roamer = roamers[model]
	return roamer ~= nil and roamer.held
end

-- Everything a new orb in this group must stay clear of: each roamer's current spot, its
-- target, and the path between them. Pass `except` to leave one roamer out (itself).
function RoamService.bodies(group: string, except: Model?): { Roam.Body }
	local at = now()
	local out: { Roam.Body } = {}
	for model, roamer in roamers do
		if roamer.group == group and model ~= except then
			addBodiesOf(roamer, at, out)
		end
	end
	return out
end

function RoamService.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			task.wait(TickSeconds)
			-- One bad roamer must never stop every monster from moving.
			xpcall(step, function(err)
				warn(`RoamService: {err}\n{debug.traceback()}`)
			end)
		end
	end)
end

return RoamService
