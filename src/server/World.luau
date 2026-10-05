--!strict
-- Finds the things built in Studio, forgivingly: names match whatever the capitals or spaces
-- ("Pumpkin Graveyard" finds PumpkinGraveyard), and a
-- "part" can be a Part or a Folder/Model with a Part inside.

local World = {}

-- Child of parent called name (any capitals or spaces), or nil.
function World.find(parent: Instance?, name: string): Instance?
	if not parent then
		return nil
	end
	local exact = parent:FindFirstChild(name)
	if exact then
		return exact
	end
	local function simple(text: string): string
		return (string.gsub(string.lower(text), "%s", ""))
	end
	local wanted = simple(name)
	for _, child in parent:GetChildren() do
		if simple(child.Name) == wanted then
			return child
		end
	end
	return nil
end

-- The instance itself if it's a part, otherwise the first part inside it.
function World.part(instance: Instance?): BasePart?
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

-- Every part that makes up an instance: the part itself, or all parts inside a Folder/Model.
function World.parts(instance: Instance?): { BasePart }
	if not instance then
		return {}
	end
	if instance:IsA("BasePart") then
		return { instance }
	end
	local parts = {}
	for _, child in instance:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return parts
end

-- Shorthand for World.part(World.find(...)) along a path, e.g. World.partAt(workspace, "Hub", "ReturnPoint").
function World.partAt(root: Instance, ...: string): BasePart?
	local current: Instance? = root
	for _, name in { ... } do
		current = World.find(current, name)
	end
	return World.part(current)
end

return World
