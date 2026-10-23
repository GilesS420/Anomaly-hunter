--!strict
-- Holding a Name Tag from the hotbar: click (or tap) one of your own mansion monsters to open
-- the name box for it (NamePrompt). The server checks and uses up the tag
-- (InventoryRemotes.Rename); mansion monsters carry Uid, OwnerId and Nickname attributes
-- (server/Services/MansionService, MonsterModel.refresh).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local NamePrompt = require(script.Parent.Parent:WaitForChild("NamePrompt"))
local ToastController = require(script.Parent.ToastController)

local NameTagController = {}

local function monsterOf(instance: Instance?): Model?
	local at = instance
	while at and at ~= workspace do
		if at:IsA("Model") and at:GetAttribute("Uid") ~= nil then
			return at
		end
		at = at.Parent
	end
	return nil
end

-- How many Name Tags the player has, from the hotbar Tool's name ("Name Tag x3").
local function tagsIn(tool: Tool): number
	return tonumber(string.match(tool.Name, "x(%d+)$")) or 1
end

function NameTagController.start()
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()

	local function watch(tool: Instance)
		if
			not tool:IsA("Tool")
			or tool:GetAttribute("ToolId") ~= "NameTag"
			or tool:GetAttribute("NameTagWatched")
		then
			return
		end
		tool:SetAttribute("NameTagWatched", true)
		tool.Activated:Connect(function()
			local monster = monsterOf(mouse.Target)
			if not monster or monster:GetAttribute("OwnerId") ~= player.UserId then
				ToastController.show("Click one of the monsters in your mansion to name it.")
				return
			end
			local uid = monster:GetAttribute("Uid")
			local monsterId = monster:GetAttribute("MonsterId")
			local nickname = monster:GetAttribute("Nickname")
			if typeof(uid) ~= "string" or typeof(monsterId) ~= "string" then
				return
			end
			NamePrompt.open(
				uid,
				Format.name(monsterId),
				if typeof(nickname) == "string" then nickname else nil,
				tagsIn(tool),
				function(result)
					if result.ok then
						ToastController.show(result.message)
					end
				end
			)
		end)
	end

	local function follow(container: Instance)
		for _, child in container:GetChildren() do
			watch(child)
		end
		container.ChildAdded:Connect(watch)
	end
	follow(player:WaitForChild("Backpack"))
	player.CharacterAdded:Connect(follow)
	if player.Character then
		follow(player.Character)
	end
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			follow(child)
		end
	end)
end

return NameTagController
