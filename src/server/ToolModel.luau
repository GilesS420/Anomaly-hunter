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

-- A still model of item `itemId` for those cards (the card camera looks along +Z from in
-- front). A long tool (a vacuum) is turned so its side shows with the front pointing right; a
-- flat or round one (a slapper's open hand, the Name Tag, the Return Charm, a bell, a potion)
-- is drawn face on, or the camera would only see its thin edge.
function ToolModel.preview(itemId: string): Model?
	local recipe = ToolLooks.ById[itemId]
	if not recipe then
		return nil
	end
	local parts = recipe()
	local front, back, left, right = math.huge, -math.huge, math.huge, -math.huge
	for _, p in parts do
		front = math.min(front, p.at[3] - p.size[3] / 2)
		back = math.max(back, p.at[3] + p.size[3] / 2)
		left = math.min(left, p.at[1] - p.size[1] / 2)
		right = math.max(right, p.at[1] + p.size[1] / 2)
	end
	local long = back - front > (right - left) * 1.5
	local model = Instance.new("Model")
	Recipe.build(parts, if long then CFrame.Angles(0, math.rad(65), 0) else CFrame.new(), model)
	for _, light in model:GetDescendants() do
		if light:IsA("PointLight") then
			light:Destroy() -- a viewport draws no lights
		end
	end
	return model
end

return ToolModel
