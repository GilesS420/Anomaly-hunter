--!strict
-- Mansion plots in the hub. Every player gets the lowest free plot when they join and spawns
-- on it; the plot is freed when they leave. If every plot is taken (set the server size to 8
-- in Game Settings so that doesn't happen), the extra player still plays from the hub and gets
-- the next plot that frees up. Plots are read from
--   Workspace.Hub.Plots.Plot1..Plot8   a Part each (or a Model/Folder with a Part inside)
-- WorldBuilder makes grey ones if they're missing. A plot's front (its Front face) should point
-- toward the middle of the hub; a plot turned sideways is treated as facing the middle.
-- Also holds the shared teleport helper used for every trip (plot, zones, home).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Notify = require(script.Parent.Parent.Notify)
local World = require(script.Parent.Parent.World)

local PlotService = {}

export type Plot = { index: number, name: string, part: BasePart, frame: CFrame }

local plots: { Plot } = {}
local owners: { [Plot]: Player } = {}
local assigned: { [Player]: Plot } = {}
local listeners: { (Player, Plot) -> () } = {}
local waiting: { Player } = {} -- joined while every plot was taken, first come first served
local warnedMissing = false

-- "Plot10" sorts after "Plot9": compare the number at the end, then the name.
local function naturalLess(a: string, b: string): boolean
	local prefixA, numberA = string.match(a, "^(.-)(%d+)$")
	local prefixB, numberB = string.match(b, "^(.-)(%d+)$")
	if prefixA and prefixB and numberA and numberB and string.lower(prefixA) == string.lower(prefixB) then
		local na, nb = tonumber(numberA) :: number, tonumber(numberB) :: number
		if na ~= nb then
			return na < nb
		end
	end
	return a < b
end

-- The plot's frame: at the centre of its top surface, turned so its LookVector points out of
-- the front door. Only yaw 0 or 180 degrees is used, so wing floors stay lined up with X/Z.
local function frameOf(part: BasePart): CFrame
	local cf, size = part.CFrame, part.Size
	-- Half the part's height in world space, whatever way it's turned.
	local halfHeight = (
		math.abs(cf.RightVector.Y) * size.X
		+ math.abs(cf.UpVector.Y) * size.Y
		+ math.abs(cf.LookVector.Y) * size.Z
	) / 2
	local position = cf.Position
	local lookZ = cf.LookVector.Z
	local facesPlusZ
	if math.abs(lookZ) >= 0.5 then
		facesPlusZ = lookZ > 0
	else
		facesPlusZ = position.Z < Layout.Hub.Center.z -- turned sideways: face the middle
	end
	local yaw = if facesPlusZ then math.pi else 0
	return CFrame.new(position.X, position.Y + halfHeight, position.Z) * CFrame.Angles(0, yaw, 0)
end

local function loadPlots()
	table.clear(plots)
	local folder = World.find(World.find(workspace, "Hub"), "Plots")
	if not folder then
		if not warnedMissing then
			warnedMissing = true
			warn(
				"PlotService: no plots found. Add a Folder at Workspace > Hub > Plots with Parts named Plot1, Plot2, ..."
			)
		end
		return
	end
	local found: { { name: string, part: BasePart } } = {}
	for _, child in folder:GetChildren() do
		local part = World.part(child)
		if part then
			table.insert(found, { name = child.Name, part = part })
		end
	end
	table.sort(found, function(a, b)
		return naturalLess(a.name, b.name)
	end)
	for i, entry in found do
		table.insert(plots, { index = i, name = entry.name, part = entry.part, frame = frameOf(entry.part) })
	end
	if #plots == 0 and not warnedMissing then
		warnedMissing = true
		warn("PlotService: Workspace > Hub > Plots has no Parts in it. Add Parts named Plot1, Plot2, ...")
	end
end

function PlotService.get(player: Player): Plot?
	return assigned[player]
end

-- Where the player appears on their plot: in front of the Foyer, looking at their mansion.
function PlotService.spawnCFrame(player: Player): CFrame?
	local plot = assigned[player]
	if not plot then
		return nil
	end
	return plot.frame * CFrame.new(Layout.PlotSpawn.x, 4, Layout.PlotSpawn.z) * CFrame.Angles(0, math.pi, 0)
end

-- Calls back for every plot handed out, including ones already handed out before this call.
function PlotService.onAssigned(callback: (Player, Plot) -> ())
	table.insert(listeners, callback)
	for player, plot in assigned do
		task.spawn(callback, player, plot)
	end
end

function PlotService.ownerOf(plotName: string): Player?
	for plot, player in owners do
		if plot.name == plotName then
			return player
		end
	end
	return nil
end

-- Moves a player's character, asking the server to stream the destination in first so they
-- don't land in empty space. Yields briefly when StreamingEnabled is on.
function PlotService.teleport(player: Player, cframe: CFrame)
	if workspace.StreamingEnabled then
		pcall(player.RequestStreamAroundAsync, player, cframe.Position, 5)
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false -- otherwise the seat comes along
	end
	character:PivotTo(cframe)
	root.AssemblyLinearVelocity = Vector3.zero -- no leftover falling speed
end

local function onCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	-- Let Roblox finish placing the character at a SpawnLocation first, then move it.
	task.wait()
	local spawnAt = PlotService.spawnCFrame(player)
	if spawnAt and player.Character == character then
		PlotService.teleport(player, spawnAt)
	end
end

local function assign(player: Player)
	if assigned[player] then
		return
	end
	if #plots == 0 then
		return -- no plots at all (already warned); players use the normal spawn
	end
	local free: Plot? = nil
	for _, plot in plots do
		if not owners[plot] then
			free = plot
			break
		end
	end
	if not free then
		if not table.find(waiting, player) then
			table.insert(waiting, player)
			Notify.toast(
				player,
				"Every mansion plot is taken right now. You'll get one as soon as someone leaves!"
			)
		end
		return
	end
	owners[free] = player
	assigned[player] = free
	player:SetAttribute("Plot", free.name)
	free.part:SetAttribute("OwnerId", player.UserId)
	free.part:SetAttribute("OwnerName", player.DisplayName)
	for _, callback in listeners do
		task.spawn(callback, player, free)
	end
end

local function onPlayerAdded(player: Player)
	assign(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local index = table.find(waiting, player)
	if index then
		table.remove(waiting, index)
	end
	local plot = assigned[player]
	if not plot then
		return
	end
	assigned[player] = nil
	owners[plot] = nil
	plot.part:SetAttribute("OwnerId", nil)
	plot.part:SetAttribute("OwnerName", nil)

	-- Hand the free plot to whoever has waited longest.
	while #waiting > 0 do
		local nextPlayer = table.remove(waiting, 1) :: Player
		if nextPlayer.Parent == Players then
			assign(nextPlayer)
			local home = PlotService.spawnCFrame(nextPlayer)
			if home then
				Notify.toast(nextPlayer, "A mansion plot is free now. It's yours!")
				if nextPlayer:GetAttribute("Zone") == nil then
					task.spawn(PlotService.teleport, nextPlayer, home) -- only if they're not on a hunt
				end
			end
			break
		end
	end
end

function PlotService.start()
	loadPlots()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlotService
