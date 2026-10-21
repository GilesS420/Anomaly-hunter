--!strict
-- Draws wandering monsters smoothly. The server only says "glide from A to B between these
-- two times" (attributes RoamFrom, RoamTo, RoamStart, RoamEnd on every model tagged
-- "Roamer", see server/Services/RoamService.luau); every frame this works out where each
-- monster should be right now and moves it locally. Orbs float with a gentle bob; block
-- monsters (Config/Looks) turn to face where they're going and swing their limbs, fast
-- while walking and slow while they stand still. A monster that is being caught (HeldBy is
-- set) trembles instead.
-- Only the model's PrimaryPart ("Body") is moved; the other parts are joined to it and follow.
--
-- Eight full mansions hold hundreds of block monsters with ~16 swinging joints each, far too
-- many to move every frame. So only monsters near the camera (and in front of it) swing their
-- limbs; the rest just glide, and the further away they are the fewer frames they're moved on.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Roam = require(Shared:WaitForChild("Util"):WaitForChild("Roam"))

local RoamController = {}

local TAG = "Roamer"
local BOB_HEIGHT = 0.35 -- studs up and down
local BOB_SPEED = 2
local SHAKE = 0.12 -- studs of trembling while someone is catching it

local TURN_SPEED = 8 -- how quickly a monster turns to face where it walks
local IDLE_PACE = 0.35 -- limbs swing this much slower and smaller while standing still
local HOP_HEIGHT = 0.15 -- studs walkers bounce with each step
local TAU = math.pi * 2

-- Level of detail by distance from the camera (studs).
local ANIMATE_DISTANCE = 140 -- closer than this (and in view): every frame, limbs swinging
local MID_DISTANCE = 320 -- closer than this: moved every MID_EVERY frames, limbs still
local MID_EVERY = 3
local FAR_EVERY = 8 -- further away: moved every FAR_EVERY frames
local BEHIND_SLACK = 30 -- monsters this close still animate when just behind the camera

type Swing = {
	motor: Motor6D,
	base: CFrame,
	axis: Vector3,
	amp: number,
	speed: number,
	phase: number,
	spin: boolean, -- turns round and round instead of swinging
	slide: boolean, -- moves along the axis (amp in studs) instead of swinging
}

type State = {
	phase: number, -- each monster bobs a little out of step with the others
	yaw: number,
	clock: number, -- limb clock: runs fast while walking, slow while standing
	pace: number, -- eases between IDLE_PACE and 1 so limbs never jump
	swings: { Swing }?, -- nil until the model has streamed in
	lookVersion: any, -- the server rebuilds the blocks when effects change (LookVersion)
	rescanUntil: number?, -- os.clock(): keep looking for the new joints until then
	nextScan: number?,
	rainbow: { BasePart }?, -- parts of a Rainbow monster, recoloured every frame
	slot: number, -- spreads far monsters' updates over different frames
	lastUpdate: number, -- os.clock() of the last frame it was moved
}

local RAINBOW_SPEED = 0.25 -- trips round the colour wheel per second
local RESCAN_SECONDS = 4
local random = Random.new()
local phases: { [Model]: State } = {}

local function track(instance: Instance)
	if instance:IsA("Model") then
		phases[instance] = {
			phase = random:NextNumber(0, TAU),
			yaw = 0,
			clock = 0,
			pace = IDLE_PACE,
			slot = random:NextInteger(0, FAR_EVERY * MID_EVERY - 1),
			lastUpdate = os.clock(),
		}
	end
end

-- The swinging joints the server set up for a block monster (MonsterModel.buildLook).
-- Joints already in `known` keep their entry: their C0 has been moved since.
local function findSwings(model: Model, known: { Swing }?): { Swing }
	local seen: { [Motor6D]: Swing } = {}
	if known then
		for _, swing in known do
			seen[swing.motor] = swing
		end
	end
	local swings: { Swing } = {}
	for _, motor in model:GetDescendants() do
		if motor:IsA("Motor6D") and seen[motor] then
			table.insert(swings, seen[motor])
			continue
		end
		if motor:IsA("Motor6D") then
			local axis = motor:GetAttribute("SwingAxis")
			local amp = motor:GetAttribute("SwingAmp")
			local speed = motor:GetAttribute("SwingSpeed")
			local phase = motor:GetAttribute("SwingPhase")
			if typeof(axis) == "Vector3" and typeof(amp) == "number" and typeof(speed) == "number" then
				table.insert(swings, {
					motor = motor,
					base = motor.C0,
					axis = axis,
					amp = amp,
					speed = speed,
					phase = if typeof(phase) == "number" then phase else 0,
					spin = motor:GetAttribute("SwingSpin") == true,
					slide = motor:GetAttribute("SwingSlide") == true,
				})
			end
		end
	end
	return swings
end

-- Turns from one angle toward another the short way round.
local function turn(from: number, to: number, alpha: number): number
	local delta = (to - from + math.pi) % TAU - math.pi
	return from + delta * alpha
end

local function untrack(instance: Instance)
	if instance:IsA("Model") then
		phases[instance] = nil
	end
end

-- Where the orb's centre should be this frame, or nil if the leg hasn't arrived yet.
local function legPosition(from: any, to: any, startTime: any, endTime: any, serverNow: number): Vector3?
	if
		typeof(from) ~= "Vector3"
		or typeof(to) ~= "Vector3"
		or typeof(startTime) ~= "number"
		or typeof(endTime) ~= "number"
	then
		return nil
	end
	return from:Lerp(to, Roam.alpha(startTime, endTime, serverNow))
end

function RoamController.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)

	-- Reused every frame so moving lots of orbs doesn't make garbage.
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}

	local frame = 0
	RunService.RenderStepped:Connect(function()
		local serverNow = workspace:GetServerTimeNow()
		local clock = os.clock()
		local view = workspace.CurrentCamera.CFrame
		local eye, ahead = view.Position, view.LookVector
		frame += 1
		table.clear(parts)
		table.clear(cframes)

		for model, state in phases do
			local body = model.PrimaryPart -- nil while it hasn't streamed in yet
			if not body or not model.Parent then
				continue
			end
			local held = model:GetAttribute("HeldBy") ~= nil

			-- How much detail this monster gets this frame.
			local offset = body.Position - eye
			local distance = offset.Magnitude
			local animate = held
				or (distance < ANIMATE_DISTANCE and (distance < BEHIND_SLACK or offset:Dot(ahead) > 0))
			if not animate then
				local every = if distance < MID_DISTANCE then MID_EVERY else FAR_EVERY
				if (frame + state.slot) % every ~= 0 then
					continue
				end
			end
			local dt = math.min(clock - state.lastUpdate, 0.5)
			state.lastUpdate = clock

			local from = model:GetAttribute("RoamFrom")
			local to = model:GetAttribute("RoamTo")
			local endTime = model:GetAttribute("RoamEnd")
			local position = legPosition(from, to, model:GetAttribute("RoamStart"), endTime, serverNow)
			if not position then
				continue
			end
			local gait = model:GetAttribute("Gait") -- nil for orbs

			-- Walking = on a leg that hasn't arrived yet; face the way it's going.
			local walking = false
			if typeof(from) == "Vector3" and typeof(to) == "Vector3" and typeof(endTime) == "number" then
				local step = to - from
				if serverNow < endTime and step.X * step.X + step.Z * step.Z > 0.01 then
					walking = true
					if gait then
						state.yaw =
							turn(state.yaw, math.atan2(-step.X, -step.Z), math.min(1, dt * TURN_SPEED))
					end
				end
			end

			local target = if walking and not held then 1 else IDLE_PACE
			state.pace += (target - state.pace) * math.min(1, dt * 4)
			state.clock += dt * state.pace

			if held then
				position += Vector3.new(
					random:NextNumber(-SHAKE, SHAKE),
					random:NextNumber(-SHAKE, SHAKE),
					random:NextNumber(-SHAKE, SHAKE)
				)
			elseif gait == "walk" then
				local hop = math.abs(math.sin(state.clock * TAU * 1.25 + state.phase))
				position += Vector3.new(0, hop * HOP_HEIGHT * (state.pace - IDLE_PACE) / (1 - IDLE_PACE), 0)
			else
				position += Vector3.new(0, math.sin(clock * BOB_SPEED + state.phase) * BOB_HEIGHT, 0)
			end

			if gait and animate then
				local swings = state.swings
				local lookVersion = model:GetAttribute("LookVersion")
				local now = os.clock()
				-- After a rebuild (a new effect) the new blocks can reach us after LookVersion
				-- does, so keep looking for a few seconds, and whenever a joint we move is gone.
				local changed = state.lookVersion ~= lookVersion
				if changed then
					state.rescanUntil = now + RESCAN_SECONDS
				end
				local stale = swings ~= nil and #swings > 0 and swings[1].motor.Parent == nil
				local settling = state.rescanUntil ~= nil
					and now < state.rescanUntil
					and now >= (state.nextScan or 0)
				if not swings or changed or stale or settling then
					state.lookVersion = lookVersion
					state.nextScan = now + 0.5
					local rainbow: { BasePart } = {}
					for _, part in model:GetDescendants() do
						if part:IsA("BasePart") and typeof(part:GetAttribute("Rainbow")) == "number" then
							table.insert(rainbow, part)
						end
					end
					state.rainbow = if #rainbow > 0 then rainbow else nil
					swings = findSwings(model, swings)
					state.swings = swings
				end
				if state.rainbow then
					-- Rainbow catches keep cycling through the colours, each part a bit ahead
					-- of the one below it.
					for _, part in state.rainbow do
						local start = part:GetAttribute("Rainbow") :: number
						part.Color = Color3.fromHSV((start + clock * RAINBOW_SPEED) % 1, 0.75, 1)
					end
				end
				for _, swing in swings :: { Swing } do
					local angle = if swing.spin
						then (state.clock * swing.speed + swing.phase) * TAU
						else math.sin((state.clock * swing.speed + swing.phase) * TAU)
							* swing.amp
							* state.pace
					swing.motor.C0 = if swing.slide
						then CFrame.new(swing.axis * angle)
							* swing.base -- along the monster's axis, even if tilted
						else swing.base * CFrame.fromAxisAngle(swing.axis, angle)
				end
			end

			table.insert(parts, body)
			table.insert(
				cframes,
				if gait then CFrame.new(position) * CFrame.Angles(0, state.yaw, 0) else CFrame.new(position)
			)
		end

		if #parts > 0 then
			-- One call for every orb; FireCFrameChanged keeps the name labels following them.
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return RoamController
