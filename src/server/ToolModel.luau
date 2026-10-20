--!strict
-- Builds a hand-held Roblox Tool from its look in Config/ToolLooks (the vacuums, the Bait
-- Bell and the Return Charm). The part named Handle is what the hand grips; everything else
-- is welded to it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolLooks = require(ReplicatedStorage.Shared.Config.ToolLooks)
local Recipe = require(script.Parent.Recipe)

local ToolModel = {}

-- A Tool named `name` holding item `itemId`'s look, or nil if it has none.
function ToolModel.tool(itemId: string, name: string): Tool?
	local recipe = ToolLooks.ById[itemId]
	if not recipe then
		return nil
	end
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	Recipe.build(recipe(), CFrame.new(), tool)
	local handle = tool:FindFirstChild("Handle") :: BasePart
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			child.CanCollide = false
			if child ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = child
				weld.Parent = child
			end
			local light = child:FindFirstChildOfClass("PointLight")
			if light then
				light.Shadows = false -- a light in your hand casting shadows is costly and flickers
			end
		end
	end
	-- The looks are drawn upright with their front along -Z, and a grip with no turn keeps the
	-- Handle that way in the hand, so no offset is needed.
	tool.Grip = CFrame.new()
	return tool
end

return ToolModel
