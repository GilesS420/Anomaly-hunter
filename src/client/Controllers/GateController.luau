--!strict
-- Shows each zone gate in the hub as open or shut for this player only. A gate whose wing you
-- don't own yet goes dark with planks nailed across it, and its sign says which wing opens it;
-- once you own the wing it glows again and says "Walk in to hunt!". Walking into a shut gate is
-- still refused by the server (HuntService); this is only how it looks.
--
-- The server keeps the player's wing count in their WingsOwned attribute (MansionService). The
-- gates are the neon parts in Workspace.Hub.ZoneGates, named by zone id (WorldBuilder).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hunt = require(ReplicatedStorage.Shared.Util.Hunt)

local GateController = {}

local ShutColor = Color3.fromRGB(28, 22, 34)
local Plank = Color3.fromRGB(96, 72, 50)
-- Planks across the front: height on the gate (0 bottom, 1 top) and tilt in degrees.
local Boards = { { 0.3, 12 }, { 0.5, -9 }, { 0.7, 6 } }

type Look = { color: Color3, material: Enum.Material, transparency: number }
local open: { [BasePart]: Look } = {}

local function subtitleOf(gate: BasePart): TextLabel?
	local billboard = gate:FindFirstChild("Label")
	if not billboard then
		return nil
	end
	for _, child in billboard:GetChildren() do
		if child:IsA("TextLabel") and child.Position.Y.Scale > 0 then
			return child
		end
	end
	return nil
end

local function shut(gate: BasePart)
	gate.Color = ShutColor
	gate.Material = Enum.Material.SmoothPlastic
	gate.Transparency = 0
	if gate:FindFirstChild("Boards") then
		return
	end
	local boards = Instance.new("Folder")
	boards.Name = "Boards"
	local size = gate.Size
	for i, board in Boards do
		local part = Instance.new("Part")
		part.Name = `Board{i}`
		part.Size = Vector3.new(size.X + 1, 1.2, 0.3)
		-- The gate's front (-Z) faces the hub; the planks sit just in front of it.
		part.CFrame = gate.CFrame
			* CFrame.new(0, size.Y * (board[1] - 0.5), -size.Z / 2 - 0.2 - (i - 1) * 0.3)
			* CFrame.Angles(0, 0, math.rad(board[2]))
		part.Color = Plank
		part.Material = Enum.Material.WoodPlanks
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = boards
	end
	boards.Parent = gate
end

local function reopen(gate: BasePart, look: Look)
	gate.Color = look.color
	gate.Material = look.material
	gate.Transparency = look.transparency
	local boards = gate:FindFirstChild("Boards")
	if boards then
		boards:Destroy()
	end
end

local function refresh()
	local wings = Players.LocalPlayer:GetAttribute("WingsOwned")
	if typeof(wings) ~= "number" then
		return -- not loaded yet: leave the gates as the server built them
	end
	for gate, look in open do
		local zone = Hunt.zoneById(gate.Name)
		if zone and gate.Parent then
			local unlocked = Hunt.isZoneUnlocked(zone.index, wings)
			if unlocked then
				reopen(gate, look)
			else
				shut(gate)
			end
			local subtitle = subtitleOf(gate)
			if subtitle then
				subtitle.Text = if unlocked then "Walk in to hunt!" else `Locked: buy the {zone.wing}`
			end
		end
	end
end

local function track(gate: Instance)
	if gate:IsA("BasePart") and not open[gate] and Hunt.zoneById(gate.Name) then
		open[gate] = { color = gate.Color, material = gate.Material, transparency = gate.Transparency }
		-- The sign is added just after the gate; wait for it so the text can follow too.
		gate:WaitForChild("Label", 10)
		refresh()
	end
end

function GateController.start()
	local hub = workspace:WaitForChild("Hub")
	local gates = hub:WaitForChild("ZoneGates")
	gates.ChildAdded:Connect(function(gate)
		task.spawn(track, gate)
	end)
	for _, gate in gates:GetChildren() do
		task.spawn(track, gate)
	end
	Players.LocalPlayer:GetAttributeChangedSignal("WingsOwned"):Connect(refresh)
	refresh()
end

return GateController
