--!strict
-- Anyone carrying a monster (a hotbar Tool with Section "Monster", see InventoryService)
-- holds both arms fully stretched straight up, the monster resting on the hands. Every
-- client poses every carrier: the arm joints' Transform is replaced each frame after the
-- animations have run (and again just before drawing), which wins over the walk, idle and
-- emote animations for that frame. Nothing is changed for good, so putting the monster away
-- lets the animations take over again by themselves.
--
-- The pose itself (shoulders turned half a turn, elbows and wrists straight) comes from
-- CarryPose, which the server also uses to seat the monster on the hands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarryPose = require(ReplicatedStorage.Shared.Util.CarryPose)

local CarryController = {}

type Pose = { joint: Instance, transform: CFrame }

local function carrying(character: Model): boolean
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("Section") == "Monster" then
			return true
		end
	end
	return false
end

-- The arm joints and the Transform each one gets (worked out once per character).
local function armPoses(character: Model): { Pose }
	local found = {}
	for _, j in CarryPose.joints(character) do
		local transform = CarryPose.transform(j)
		if transform then
			table.insert(found, { joint = j.joint, transform = transform })
		end
	end
	return found
end

function CarryController.start()
	local cache: { [Model]: { Pose } } = {}
	local function pose()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and carrying(character) then
				local poses = cache[character]
				if not poses or #poses == 0 or not poses[1].joint.Parent then
					poses = armPoses(character)
					cache[character] = poses
				end
				for _, p in poses do
					(p.joint :: any).Transform = p.transform
				end
			elseif character then
				cache[character] = nil
			end
		end
		for character in cache do
			if not character.Parent then
				cache[character] = nil -- respawned while carrying
			end
		end
	end
	-- Animators write the joints before PreSimulation, so this is the moment to win over them.
	RunService.PreSimulation:Connect(pose)
	RunService.PreRender:Connect(pose)
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			cache[player.Character] = nil
		end
	end)
end

return CarryController
