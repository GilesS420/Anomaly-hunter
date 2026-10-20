--!strict
-- Anyone carrying a monster (a hotbar Tool with Section "Monster", see InventoryService)
-- holds both arms straight up under it. Every client poses every carrier: each frame, just
-- before drawing, the shoulder joints' Transform is replaced, which wins over the walk and
-- idle animations for that frame. Nothing is changed for good, so putting the monster away
-- lets the animations take over again by themselves.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CarryController = {}

-- Turned round the shoulder's sideways axis, from hanging down to pointing up (a little
-- forward, so the hands sit under the monster).
local R15Up = CFrame.Angles(math.rad(170), 0, 0)
-- R6 shoulders are turned to face sideways, so their sideways axis is Z.
local R6Up = {
	["Right Arm"] = CFrame.Angles(0, 0, math.rad(170)),
	["Left Arm"] = CFrame.Angles(0, 0, math.rad(-170)),
}
local Arms = { RightUpperArm = true, LeftUpperArm = true, ["Right Arm"] = true, ["Left Arm"] = true }

local function carrying(character: Model): boolean
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("Section") == "Monster" then
			return true
		end
	end
	return false
end

-- The joints that hold the arms on (found by the arm they move, whatever they're called).
local function shoulders(character: Model): { Motor6D }
	local found = {}
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part1 and Arms[joint.Part1.Name] then
			table.insert(found, joint)
		end
	end
	return found
end

function CarryController.start()
	local cache: { [Model]: { Motor6D } } = {}
	RunService.PreRender:Connect(function()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and carrying(character) then
				local joints: { Motor6D } = cache[character] or {}
				if #joints == 0 or not joints[1].Parent then
					joints = shoulders(character)
					cache[character] = joints
				end
				for _, joint in joints do
					local part = joint.Part1
					if part then
						joint.Transform = R6Up[part.Name] or R15Up
					end
				end
			elseif character then
				cache[character] = nil
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			cache[player.Character] = nil
		end
	end)
end

return CarryController
