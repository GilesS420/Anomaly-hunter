--!strict
-- Hunt runs: walk into a zone's gate in the hub, catch one monster, and bring it back out
-- through the zone's exit (or use a Return Charm). Built in Studio as
--   Workspace.Hub.ZoneGates.<ZoneId>  a part; touching it takes you into that zone
--   Workspace.Hub.ReturnPoint         a part where hunters arrive back in the hub
--   Workspace.Zones.<ZoneId>.Arrival  a part where hunters arrive in the zone
--   Workspace.Zones.<ZoneId>.Exit     a part; touching it takes you (and your catch) home
-- Monsters will hurt hunters once their AI exists (#6), through HuntService.damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hunt = require(ReplicatedStorage.Shared.Util.Hunt)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local DataService = require(script.Parent.DataService)

local HuntService = {}

local carrying: { [Player]: Value.CaughtMonster } = {}
local lastPortal: { [Player]: number } = {}

local remotes = Instance.new("Folder")
remotes.Name = "HuntRemotes"
local UseReturnCharm = Instance.new("RemoteEvent") -- client -> server: ()
UseReturnCharm.Name = "UseReturnCharm"
UseReturnCharm.Parent = remotes
local Notice = Instance.new("RemoteEvent") -- server -> client: (kind, info?)
Notice.Name = "Notice"
Notice.Parent = remotes

local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return nil
	end
	-- Touched fires many times while standing on a portal; one trip per second is plenty.
	local now = os.clock()
	if now - (lastPortal[player] or 0) < 1 then
		return nil
	end
	lastPortal[player] = now
	return player
end

local function teleport(player: Player, to: BasePart)
	local character = player.Character
	if character then
		character:PivotTo(to.CFrame + Vector3.new(0, 4, 0))
	end
end

local function returnPoint(): BasePart?
	local hub = workspace:FindFirstChild("Hub")
	local point = hub and hub:FindFirstChild("ReturnPoint")
	if point and point:IsA("BasePart") then
		return point
	end
	return workspace:FindFirstChildWhichIsA("SpawnLocation", true)
end

local function setCarrying(player: Player, caught: Value.CaughtMonster?)
	carrying[player] = caught
	player:SetAttribute("Carrying", if caught then caught.monsterId else nil)
	player:SetAttribute("CarryingSize", if caught then caught.size else nil)
end

-- Drops the carried monster (it's lost) without ending anything else.
local function drop(player: Player, reason: string)
	local caught = carrying[player]
	if caught then
		setCarrying(player, nil)
		Notice:FireClient(player, "Dropped", { monsterId = caught.monsterId, reason = reason })
	end
end

-- Leaves the zone. With deliver, the carried monster goes home with the hunter.
local function goHome(player: Player, deliver: boolean)
	local caught = carrying[player]
	if caught and deliver then
		local data = DataService.get(player)
		if data then
			-- TODO(#9): place it in a mansion wing (and check capacity) once the mansion exists.
			table.insert(data.monsters :: { any }, caught)
			Notice:FireClient(player, "Delivered", { monsterId = caught.monsterId, size = caught.size })
		end
	end
	setCarrying(player, nil)
	player:SetAttribute("Zone", nil)
	player:SetAttribute("Hearts", Zones.MaxHearts)
	local point = returnPoint()
	if point then
		teleport(player, point)
	end
end

function HuntService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

-- Puts a fresh catch in the hunter's vacuum. False if they already carry one.
function HuntService.carry(player: Player, caught: Value.CaughtMonster): boolean
	if carrying[player] then
		return false
	end
	setCarrying(player, caught)
	return true
end

-- Monsters fighting back. At 0 hearts the carried monster is dropped and the hunter is
-- sent home (no death; the game is for all ages).
function HuntService.damage(player: Player, amount: number)
	local hearts = player:GetAttribute("Hearts")
	if typeof(hearts) ~= "number" then
		return
	end
	local left = Hunt.afterDamage(hearts, amount)
	player:SetAttribute("Hearts", left)
	if left == 0 then
		drop(player, "Scared")
		goHome(player, false)
	end
end

local function enterZone(player: Player, zone: Zones.Zone, arrival: BasePart)
	local data = DataService.get(player)
	if not data then
		return
	end
	if not Hunt.isZoneUnlocked(zone.index, data.wingsOwned) then
		Notice:FireClient(player, "Locked", { zone = zone.name, wing = zone.wing })
		return
	end
	player:SetAttribute("Zone", zone.id)
	player:SetAttribute("Hearts", Zones.MaxHearts)
	teleport(player, arrival)
	Notice:FireClient(player, "Entered", { zone = zone.name })
end

local function onCharacter(player: Player, character: Model)
	player:SetAttribute("Hearts", Zones.MaxHearts)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		drop(player, "Died")
		player:SetAttribute("Zone", nil)
	end)
end

UseReturnCharm.OnServerEvent:Connect(function(player)
	local data = DataService.get(player)
	if not data or (player:GetAttribute("Zone") == nil and not carrying[player]) then
		return
	end
	local inventory = data.inventory :: { [string]: number }
	local charms = inventory.ReturnCharm or 0
	if charms <= 0 then
		Notice:FireClient(player, "NoCharm")
		return
	end
	inventory.ReturnCharm = if charms == 1 then nil else charms - 1
	goHome(player, true)
end)

function HuntService.start()
	remotes.Parent = ReplicatedStorage

	local hub = workspace:FindFirstChild("Hub")
	local gates = hub and hub:FindFirstChild("ZoneGates")
	local zonesFolder = workspace:FindFirstChild("Zones")
	for _, zone in Zones.List do
		local zoneFolder = zonesFolder and zonesFolder:FindFirstChild(zone.id)
		local gate = gates and gates:FindFirstChild(zone.id)
		local arrival = zoneFolder and zoneFolder:FindFirstChild("Arrival")
		if gate and gate:IsA("BasePart") and arrival and arrival:IsA("BasePart") then
			gate.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				if player and player:GetAttribute("Zone") == nil then
					enterZone(player, zone, arrival)
				end
			end)
		end
		local exit = zoneFolder and zoneFolder:FindFirstChild("Exit")
		if exit and exit:IsA("BasePart") then
			exit.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				if player then
					goHome(player, true)
				end
			end)
		end
	end

	local function onPlayer(player: Player)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		-- Leaving mid-run loses the catch, so quitting can't be used as a free teleport home.
		carrying[player] = nil
		lastPortal[player] = nil
	end)
end

return HuntService
