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

-- The name of item `itemId`'s preview model in the player's InventoryPreviews, so shop and
-- Backpack cards can draw the real thing (see InventoryService.syncPreviews).
function ToolModel.look(itemId: string): string?
	return if ToolLooks.ById[itemId] then `Tool|{itemId}` else nil
end

-- A still model of item `itemId` for those cards, turned so its side shows with the front
-- pointing right (the card camera looks along +Z from in front).
function ToolModel.preview(itemId: string): Model?
	local recipe = ToolLooks.ById[itemId]
	if not recipe then
		return nil
	end
	local model = Instance.new("Model")
	Recipe.build(recipe(), CFrame.Angles(0, math.rad(65), 0), model)
	for _, light in model:GetDescendants() do
		if light:IsA("PointLight") then
			light:Destroy() -- a viewport draws no lights
		end
	end
	return model
end

return ToolModel
