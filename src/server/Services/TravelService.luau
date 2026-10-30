--!strict
-- Getting around the hub faster:
--   * In the open hub (not on a mansion plot, not in a zone) hunters walk at
--     Config/Travel.HubWalkSpeed; everywhere else at the normal StarterPlayer speed.
--     A Slow attack (player attribute Slowed, MonsterAiService) always wins.
--   * Fast travel: the buttons at the top of the screen jump you to your own mansion, the
--     Zone Gates, in front of the Vacuum Vault between the Haunted Bakery and the Hunter's Workshop, or the Collector. Only from the hub and with nothing in your
--     vacuum, so it never replaces the Return Charm (which gets you OUT of a zone).
--
-- Remotes in ReplicatedStorage.TravelRemotes:
--   FastTravel  client -> server (destinationId: string), one of Config/Travel.Destinations

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Heists = require(ReplicatedStorage.Shared.Config.Heists)
local Hunt = require(ReplicatedStorage.Shared.Util.Hunt)
local Travel = require(ReplicatedStorage.Shared.Util.Travel)
local TravelConfig = require(ReplicatedStorage.Shared.Config.Travel)
local Tutorial = require(ReplicatedStorage.Shared.Util.Tutorial)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local Notify = require(script.Parent.Parent.Notify)
local Perks = require(script.Parent.Parent.Perks)
local PlotService = require(script.Parent.PlotService)
local World = require(script.Parent.Parent.World)

local TravelService = {}

local SpeedCheckSeconds = 0.2

local lastTrip: { [Player]: number } = {}

local remotes = Instance.new("Folder")
remotes.Name = "TravelRemotes"
local FastTravel = Instance.new("RemoteEvent") -- client -> server: (destinationId: string)
FastTravel.Name = "FastTravel"
FastTravel.Parent = remotes

-- The box around a landmark or gate: a Part's own, or the bounding box of everything in a
-- Model or Folder (so it works with a placeholder block and with a real build alike).
local function bounds(instance: Instance): (CFrame?, Vector3?)
	if instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	elseif instance:IsA("Model") then
		return instance:GetBoundingBox()
	end
	local parts = World.parts(instance)
	if #parts == 0 then
		return nil, nil
	end
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in parts do
		local half = part.Size / 2
		low = low:Min(part.Position - half)
		high = high:Max(part.Position + half)
	end
	return CFrame.new((low + high) / 2), high - low
end

-- Standing spot in front of a box, on the side toward the middle of the hub, looking at it.
local function inFront(frame: CFrame, size: Vector3): CFrame
	local centre = frame.Position
	local toMiddle = Vector3.new(-centre.X, 0, -centre.Z)
	toMiddle = if toMiddle.Magnitude > 0.1 then toMiddle.Unit else Vector3.xAxis
	-- How far the box reaches in that direction, whatever way it's turned.
	local reach = math.abs(frame.RightVector:Dot(toMiddle)) * size.X / 2
		+ math.abs(frame.LookVector:Dot(toMiddle)) * size.Z / 2
	local bottom = centre.Y - size.Y / 2
	local spot = centre + toMiddle * (reach + TravelConfig.StandOff)
	local standAt = Vector3.new(spot.X, bottom + 4, spot.Z)
	return CFrame.lookAt(standAt, Vector3.new(centre.X, standAt.Y, centre.Z))
end

local function landmarkBounds(name: string): (CFrame?, Vector3?)
	local landmark = World.find(World.find(World.find(workspace, "Hub"), "Landmarks"), name)
	if not landmark then
		return nil, nil
	end
	return bounds(landmark)
end

local function landmarkSpot(name: string): CFrame?
	local frame, size = landmarkBounds(name)
	return if frame and size then inFront(frame, size) else nil
end

-- A spot just as far from two landmarks (on the line halfway between them), out toward the
-- middle of the hub, looking at the gap between them, so both are in view.
local function betweenSpot(a: string, b: string): CFrame?
	local frameA, sizeA = landmarkBounds(a)
	local frameB, sizeB = landmarkBounds(b)
	if not (frameA and sizeA and frameB and sizeB) then
		return landmarkSpot(a) or landmarkSpot(b)
	end
	local flat = Vector3.new(1, 0, 1)
	local centreA, centreB = frameA.Position, frameB.Position
	local middle = (centreA + centreB) / 2
	local across = (centreB - centreA) * flat
	local out = Vector3.new(-middle.X, 0, -middle.Z)
	if across.Magnitude > 0.1 then
		out -= across.Unit * out:Dot(across.Unit) -- stay on the halfway line
	end
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.xAxis
	local reach = math.max(sizeA.X, sizeA.Z, sizeB.X, sizeB.Z) / 2
	local bottom = math.min(centreA.Y - sizeA.Y / 2, centreB.Y - sizeB.Y / 2)
	local spot = middle + out * (reach + TravelConfig.StandOff * 2)
	local standAt = Vector3.new(spot.X, bottom + 4, spot.Z)
	return CFrame.lookAt(standAt, Vector3.new(middle.X, standAt.Y, middle.Z))
end

-- In front of the middle of the row of gates.
local function portalSpot(): CFrame?
	local gates = World.find(World.find(workspace, "Hub"), "ZoneGates")
	local sum, count, bottom, reach = Vector3.zero, 0, math.huge, 0
	for _, zone in Zones.List do
		local gate = World.find(gates, zone.id)
		local frame: CFrame?, size: Vector3? = nil, nil
		if gate then
			frame, size = bounds(gate)
		end
		if frame and size then
			sum += frame.Position
			count += 1
			bottom = math.min(bottom, frame.Position.Y - size.Y / 2)
			reach = math.max(reach, math.max(size.X, size.Z) / 2)
		end
	end
	if count == 0 then
		return nil
	end
	local middle = sum / count
	local row = CFrame.new(Vector3.new(middle.X, bottom + 0.5, middle.Z))
	return inFront(row, Vector3.new(reach * 2, 1, reach * 2))
end

-- In front of the gate of the newest zone this player has opened (Giles 2026-10-21), or the
-- middle of the row if that gate isn't there.
local function newestGateSpot(player: Player): CFrame?
	local data = DataService.get(player)
	local zone = Hunt.newestZone(if data then data.wingsOwned else 1)
	local gate = zone and World.find(World.find(World.find(workspace, "Hub"), "ZoneGates"), zone.id)
	if gate then
		local frame, size = bounds(gate)
		if frame and size then
			return inFront(frame, size)
		end
	end
	return portalSpot()
end

local function destinationSpot(player: Player, destination: TravelConfig.Destination): CFrame?
	if destination.home then
		return PlotService.spawnCFrame(player)
	end
	local landmarks = destination.landmarks
	if not landmarks or #landmarks == 0 then
		return newestGateSpot(player)
	elseif #landmarks == 1 then
		return landmarkSpot(landmarks[1])
	end
	return betweenSpot(landmarks[1], landmarks[2])
end

local function validDestination(id: any): TravelConfig.Destination?
	if typeof(id) ~= "string" then
		return nil
	end
	for _, destination in TravelConfig.Destinations do
		if destination.id == id then
			return destination
		end
	end
	return nil
end

FastTravel.OnServerEvent:Connect(function(player, id)
	local destination = validDestination(id)
	if not destination then
		return
	end
	-- Greyed out during the tutorial until its step (the client hides it too).
	local step = player:GetAttribute("Tutorial")
	if not Tutorial.isUnlocked(if typeof(step) == "string" then step else nil, destination.id) then
		Notify.toast(player, "Finish the tutorial first!")
		return
	end
	if player:GetAttribute("Zone") ~= nil or HuntService.isCarrying(player) then
		Notify.toast(player, "Fast travel only works in the hub. Use the exit or a Return Charm to get home!")
		return
	end
	local now = os.clock()
	if now - (lastTrip[player] or -math.huge) < TravelConfig.Cooldown then
		return
	end
	local spot = destinationSpot(player, destination)
	if not spot then
		warn(`TravelService: nothing to travel to for {destination.id} (see Workspace > Hub)`)
		return
	end
	lastTrip[player] = now
	PlotService.teleport(player, spot)
end)

-- Puts every hunter on the right WalkSpeed for where they are standing.
local function updateSpeeds()
	local normal = StarterPlayer.CharacterWalkSpeed
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and not player:GetAttribute("Slowed") then
			local position = root.Position
			local inZone = player:GetAttribute("Zone") ~= nil
			local speed = Travel.walkSpeed(inZone, position.X, position.Z, normal, TravelConfig.HubWalkSpeed)
				* Perks.walkMultiplier(player)
				* (if player:GetAttribute("HeistPhase") == "Carrying" then Heists.CarrySpeed else 1)
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end
		end
	end
end

function TravelService.start()
	remotes.Parent = ReplicatedStorage

	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited >= SpeedCheckSeconds then
			waited = 0
			updateSpeeds()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastTrip[player] = nil
	end)
end

return TravelService
