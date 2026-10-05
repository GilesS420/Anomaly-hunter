--!strict
-- Hunt runs: walk into a zone's gate in the hub, catch one monster, and bring it back out
-- through the zone's exit (or use a Return Charm). The world pieces (WorldBuilder makes grey
-- placeholders for any that are missing):
--   Workspace.Hub.ZoneGates.<ZoneId>  a part; touching it takes you into that zone
--   Workspace.Hub.ReturnPoint         where hunters land in the hub if they have no plot
--   Workspace.Zones.<ZoneId>.Arrival  a part where hunters arrive in the zone
--   Workspace.Zones.<ZoneId>.Exit     a part; touching it takes you (and your catch) home
-- Monsters will hurt hunters once their AI exists (#6), through HuntService.damage.
--
-- Remotes in ReplicatedStorage.HuntRemotes:
--   UseReturnCharm  client -> server ()  (the Return Charm button)
-- Player attribute ReturnCharms (number) mirrors how many charms they own, so the button only
-- shows when there is one to use.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Hunt = require(ReplicatedStorage.Shared.Util.Hunt)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)
local Notify = require(script.Parent.Parent.Notify)
local PlotService = require(script.Parent.PlotService)
local World = require(script.Parent.Parent.World)

local HuntService = {}

local PortalCooldown = 1 -- seconds between two trips through a gate or exit
local LockedCooldown = 4 -- seconds between two "this zone is locked" messages

local carrying: { [Player]: Value.CaughtMonster } = {}
local lastPortal: { [Player]: number } = {}
local lastLocked: { [Player]: number } = {}

local remotes = Instance.new("Folder")
remotes.Name = "HuntRemotes"
local UseReturnCharm = Instance.new("RemoteEvent") -- client -> server: ()
UseReturnCharm.Name = "UseReturnCharm"
UseReturnCharm.Parent = remotes

local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return nil
	end
	-- Touched fires many times while standing on a portal; one trip per second is plenty.
	local now = os.clock()
	if now - (lastPortal[player] or 0) < PortalCooldown then
		return nil
	end
	lastPortal[player] = now
	return player
end

-- Standing spot just above a part, looking toward `lookAt` (kept level).
local function standAbove(part: BasePart, lookAt: Vector3?): CFrame
	local position = part.Position + Vector3.new(0, 4, 0)
	if lookAt then
		local flat = Vector3.new(lookAt.X, position.Y, lookAt.Z)
		if (flat - position).Magnitude > 0.1 then
			return CFrame.lookAt(position, flat)
		end
	end
	return CFrame.new(position)
end

local function returnPoint(): BasePart?
	return World.partAt(workspace, "Hub", "ReturnPoint")
		or workspace:FindFirstChildWhichIsA("SpawnLocation", true)
end

local function setCarrying(player: Player, caught: Value.CaughtMonster?)
	if caught then
		carrying[player] = caught
	else
		carrying[player] = nil
	end
	player:SetAttribute("Carrying", if caught then caught.monsterId else nil)
	player:SetAttribute("CarryingSize", if caught then caught.size else nil)
end

-- How many Return Charms the save holds.
local function charmCount(data: DataService.Data): number
	local inventory: { [string]: any } = data.inventory
	return if typeof(inventory.ReturnCharm) == "number" then inventory.ReturnCharm else 0
end

-- Drops the carried monster (it's lost) without ending anything else.
local function drop(player: Player)
	local caught = carrying[player]
	if caught then
		setCarrying(player, nil)
		Notify.toast(player, `You dropped {Format.name(caught.monsterId)}!`)
	end
end

-- Leaves the zone. With deliver, the carried monster goes home with the hunter.
local function goHome(player: Player, deliver: boolean)
	local caught = carrying[player]
	if caught and deliver then
		if MansionService.addMonster(player, caught) then
			Notify.toast(player, `{caught.size} {Format.name(caught.monsterId)} is home in your mansion!`)
		else
			Notify.toast(player, "Your mansion is full! Buy a new wing to keep more monsters.")
		end
	end
	setCarrying(player, nil)
	player:SetAttribute("Zone", nil)
	player:SetAttribute("Hearts", Zones.MaxHearts)

	-- Home is the player's own plot; the hub's ReturnPoint if they have none.
	local home = PlotService.spawnCFrame(player)
	if not home then
		local point = returnPoint()
		home = if point then standAbove(point, nil) else nil
	end
	if home then
		PlotService.teleport(player, home)
	end
end

-- Updates the ReturnCharms attribute (the client shows the button only if it's above 0).
-- Call it after anything changes data.inventory.ReturnCharm (e.g. the Workshop selling one).
function HuntService.refreshCharms(player: Player)
	local data = DataService.get(player)
	player:SetAttribute("ReturnCharms", if data then charmCount(data) else 0)
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
	if typeof(hearts) ~= "number" or player:GetAttribute("Zone") == nil then
		return
	end
	local left = Hunt.afterDamage(hearts, amount)
	player:SetAttribute("Hearts", left)
	if left == 0 then
		drop(player)
		goHome(player, false)
	end
end

-- Where to face on arrival: the middle of the zone's roaming area (or of its spawn points in
-- an older zone), or the zone's centre in the layout.
local function zoneMiddle(zone: Zones.Zone, zoneFolder: Instance): Vector3?
	local roamArea = World.part(World.find(zoneFolder, "RoamArea"))
	if roamArea then
		return roamArea.Position
	end
	local spawnPoints = World.parts(World.find(zoneFolder, "SpawnPoints"))
	if #spawnPoints > 0 then
		local sum = Vector3.zero
		for _, part in spawnPoints do
			sum += part.Position
		end
		return sum / #spawnPoints
	end
	local centre = Layout.Zones[zone.index]
	return if centre then Vector3.new(centre.x, centre.y, centre.z) else nil
end

local function enterZone(player: Player, zone: Zones.Zone, arrival: BasePart, facing: Vector3?)
	local data = DataService.get(player)
	if not data then
		Notify.toast(player, "Your save is still loading. Try again in a moment!")
		return
	end
	local reason = Hunt.lockedReason(zone.index, data.wingsOwned)
	if reason then
		-- Standing in a gate touches it over and over; don't repeat the message every second.
		local now = os.clock()
		if now - (lastLocked[player] or 0) >= LockedCooldown then
			lastLocked[player] = now
			Notify.toast(player, reason)
		end
		return
	end
	player:SetAttribute("Zone", zone.id)
	player:SetAttribute("Hearts", Zones.MaxHearts)
	Notify.toast(player, `Entering {zone.name}`)
	Notify.toast(player, "Press and HOLD on a monster to catch it!")
	PlotService.teleport(player, standAbove(arrival, facing))
end

local function onCharacter(player: Player, character: Model)
	player:SetAttribute("Hearts", Zones.MaxHearts)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(function()
		drop(player)
		player:SetAttribute("Zone", nil)
	end)
end

UseReturnCharm.OnServerEvent:Connect(function(player)
	local data = DataService.get(player)
	if not data or (player:GetAttribute("Zone") == nil and not carrying[player]) then
		return
	end
	local charms = charmCount(data)
	if charms <= 0 then
		Notify.toast(player, "You don't have a Return Charm yet. (The Workshop opens soon.)")
		return
	end
	local inventory: { [string]: any } = data.inventory
	inventory.ReturnCharm = if charms <= 1 then nil else charms - 1 -- the last one leaves the list
	HuntService.refreshCharms(player)
	goHome(player, true)
end)

-- Connects one zone's gate and exit. Only zones that exist in Workspace.Zones are wired.
local function wireZone(zone: Zones.Zone)
	local zoneFolder = World.find(World.find(workspace, "Zones"), zone.id)
	local gateInstance = World.find(World.find(World.find(workspace, "Hub"), "ZoneGates"), zone.id)
	local gate = World.part(gateInstance)
	if not zoneFolder then
		if gate then
			warn(
				`HuntService: the {zone.id} gate leads nowhere. Add a Folder at Workspace > Zones > {zone.id}`
			)
		end
		return
	end
	local arrival = World.part(World.find(zoneFolder, "Arrival"))
	local exitInstance = World.find(zoneFolder, "Exit")
	local exit = World.part(exitInstance)

	-- Say what's missing in the Output window.
	if not gate then
		warn(`HuntService: {zone.id} has no gate. Add a Part at Workspace > Hub > ZoneGates > {zone.id}`)
	end
	if not arrival then
		warn(`HuntService: {zone.id} has no Arrival. Add a Part at Workspace > Zones > {zone.id} > Arrival`)
	end
	if not exit then
		warn(`HuntService: {zone.id} has no Exit. Add a Part at Workspace > Zones > {zone.id} > Exit`)
	end

	-- A gate or exit built as a Model or Folder works when any part of it is touched.
	if gate and arrival then
		local facing = zoneMiddle(zone, zoneFolder)
		for _, part in World.parts(gateInstance) do
			part.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				if player and player:GetAttribute("Zone") == nil then
					enterZone(player, zone, arrival, facing)
				end
			end)
		end
	end
	if exit then
		for _, part in World.parts(exitInstance) do
			part.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				-- Only hunters who came in through this zone's gate can leave (and deliver) here.
				if player and player:GetAttribute("Zone") == zone.id then
					goHome(player, true)
				end
			end)
		end
	end
end

function HuntService.start()
	remotes.Parent = ReplicatedStorage

	for _, zone in Zones.List do
		wireZone(zone)
	end
	if not returnPoint() then
		warn("HuntService: no Workspace > Hub > ReturnPoint part (or SpawnLocation) to send hunters home to")
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	DataService.onLoaded(function(player)
		HuntService.refreshCharms(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- Leaving mid-run loses the catch, so quitting can't be used as a free teleport home.
		carrying[player] = nil
		lastPortal[player] = nil
		lastLocked[player] = nil
	end)
end

return HuntService
