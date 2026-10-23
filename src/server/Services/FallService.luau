--!strict
-- A safety net now there's no Baseplate under the world: a player who somehow drops off the
-- hub floor or a zone island is put back on solid ground instead of falling forever.
--   hub    below the floor  -> Workspace.Hub.ReturnPoint (or a SpawnLocation)
--   zone   below its island -> that zone's Arrival (Workspace.Zones.<ZoneId>.Arrival)
-- Zones are the islands in Config/Layout (Zones), far from the hub; the closest one counts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local World = require(script.Parent.Parent.World)

local FallService = {}

local CheckSeconds = 0.5
local Drop = 30 -- studs below a floor that counts as fallen off
local ZoneReach = 200 -- a player this close (in X/Z) to a zone's middle is on that zone

local function hubPoint(): BasePart?
	return World.partAt(workspace, "Hub", "ReturnPoint")
		or workspace:FindFirstChildWhichIsA("SpawnLocation", true)
end

-- Where a player at `position` should be, if they have fallen; nil while they're fine.
local function rescuePoint(position: Vector3): BasePart?
	for _, zone in Zones.List do
		local spot = Layout.Zones[zone.index]
		if
			spot
			and math.abs(position.X - spot.x) < ZoneReach
			and math.abs(position.Z - spot.z) < ZoneReach
		then
			if position.Y > spot.y - Drop then
				return nil
			end
			return World.partAt(workspace, "Zones", zone.id, "Arrival") or hubPoint()
		end
	end
	if position.Y > Layout.Hub.Center.y - Drop then
		return nil
	end
	return hubPoint()
end

local function check()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			local point = rescuePoint(root.Position)
			if point then
				root.AssemblyLinearVelocity = Vector3.zero
				character:PivotTo(CFrame.new(point.Position + Vector3.new(0, 4, 0)))
			end
		end
	end
end

function FallService.start()
	task.spawn(function()
		while true do
			task.wait(CheckSeconds)
			check()
		end
	end)
end

return FallService
