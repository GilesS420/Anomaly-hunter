--!strict
-- Hunt runs: walk into a zone's gate in the hub, catch as many monsters as your vacuum's bag
-- holds (Config/Tools), and bring them back out through the zone's exit (or use a Return
-- Charm). The world pieces (WorldBuilder makes grey
-- placeholders for any that are missing):
--   Workspace.Hub.ZoneGates.<ZoneId>  a part; touching it takes you into that zone
--   Workspace.Hub.ReturnPoint         where hunters land in the hub if they have no plot
--   Workspace.Zones.<ZoneId>.Arrival  a part where hunters arrive in the zone
--   Workspace.Zones.<ZoneId>.Exit     a part; touching it takes you (and your catch) home
-- Monsters hurt hunters through HuntService.damage (MonsterAiService).
--
-- Remotes in ReplicatedStorage.HuntRemotes:
--   UseReturnCharm  client -> server ()  (the Return Charm button)
--   UseBaitBell     client -> server (bellId?)  (a Bait Bell button: a rarer monster comes to you;
--                   bellId is "BaitBell", "SilverBell" or "GoldBell", the plain bell if left out)
-- Player attributes ReturnCharms and BaitBells (numbers) mirror how many the player owns, so
-- the buttons only show when there is one to use. Every owned vacuum, the Bait Bells and the
-- Return Charms are also Tools in the hotbar (Section "Tool"): catching only works with a
-- vacuum in your hand (heldVacuum), holding one makes it the vacuum you use, and clicking
-- with the bell or charm in hand uses one. Carrying / CarryingSize name the latest
-- catch in the bag, CarryingCount and BagSize say how full it is, BagList names every catch
-- in it (one per line).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catching = require(ReplicatedStorage.Shared.Util.Catching)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Hunt = require(ReplicatedStorage.Shared.Util.Hunt)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)
local Notify = require(script.Parent.Parent.Notify)
local PlotService = require(script.Parent.PlotService)
local SpawnService = require(script.Parent.SpawnService)
local ToolModel = require(script.Parent.Parent.ToolModel)
local World = require(script.Parent.Parent.World)

local HuntService = {}

local PortalCooldown = 1 -- seconds between two trips through a gate or exit
local LockedCooldown = 4 -- seconds between two "this zone is locked" messages

local carrying: { [Player]: { Value.CaughtMonster } } = {} -- the bag, oldest catch first
local lastPortal: { [Player]: number } = {}
local lastLocked: { [Player]: number } = {}

local remotes = Instance.new("Folder")
remotes.Name = "HuntRemotes"
local UseReturnCharm = Instance.new("RemoteEvent") -- client -> server: ()
UseReturnCharm.Name = "UseReturnCharm"
UseReturnCharm.Parent = remotes
local UseBaitBell = Instance.new("RemoteEvent") -- client -> server: (bellId?)
UseBaitBell.Name = "UseBaitBell"
UseBaitBell.Parent = remotes

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

-- How many monsters the player's equipped vacuum carries.
local function bagSize(player: Player): number
	local data = DataService.get(player)
	return if data then Catching.bagSize(data.equipped.vacuum) else 1
end

local function setCarrying(player: Player, bag: { Value.CaughtMonster }?)
	local list: { Value.CaughtMonster } = bag or {}
	local latest = list[#list]
	if latest then
		carrying[player] = list
	else
		carrying[player] = nil -- an empty bag counts as none
	end
	player:SetAttribute("Carrying", if latest then latest.monsterId else nil)
	player:SetAttribute("CarryingSize", if latest then latest.size else nil)
	player:SetAttribute("CarryingCount", if latest then #list else nil)
	-- Every catch in the bag, one per line ("Big Gloomlet", "Gold Normal Wisp Jack"), for the HUD.
	local lines: { string } = {}
	for _, caught in list do
		local variant = if caught.variant then `{caught.variant} ` else ""
		table.insert(lines, `{variant}{caught.size} {Format.name(caught.monsterId)}`)
	end
	player:SetAttribute("BagList", if #lines > 0 then table.concat(lines, "\n") else nil)
	player:SetAttribute("BagSize", bagSize(player))
end

-- How many of a single-use item (ReturnCharm, BaitBell) the save holds.
local function itemCount(data: DataService.Data, itemId: string): number
	local count: any = (data.inventory :: { [string]: any })[itemId]
	return if typeof(count) == "number" then count else 0
end

-- Uses one up; the last one leaves the inventory list.
local function useItem(data: DataService.Data, itemId: string)
	local count = itemCount(data, itemId)
	local inventory: { [string]: number? } = data.inventory
	inventory[itemId] = if count <= 1 then nil else count - 1
end

-- "Big Gravepup", or "3 monsters".
local function bagName(bag: { Value.CaughtMonster }): string
	return if #bag == 1 then `{bag[1].size} {Format.name(bag[1].monsterId)}` else `{#bag} monsters`
end

-- Drops everything in the bag (it's lost) without ending anything else.
local function drop(player: Player)
	local bag = carrying[player]
	if bag then
		setCarrying(player, nil)
		Notify.toast(player, `You dropped {bagName(bag)}!`)
	end
end

-- Leaves the zone. With deliver, the bag goes home with the hunter.
local function goHome(player: Player, deliver: boolean)
	local bag = carrying[player]
	if bag and deliver then
		local home, stored, lost = 0, 0, 0
		for _, caught in bag do
			local where = MansionService.addMonster(player, caught)
			if where == "Mansion" then
				home += 1
			elseif where == "Storage" then
				stored += 1
			else
				lost += 1
			end
		end
		if home == #bag then
			Notify.toast(player, `{bagName(bag)} {if #bag == 1 then "is" else "are"} home in your mansion!`)
		elseif lost == 0 then
			Notify.toast(player, `Your mansion is full, so {stored} went into Storage (your Backpack).`)
		else
			Notify.toast(
				player,
				`Your mansion and Storage are full! {lost} got away. Sell some at the Collector or buy a new wing.`
			)
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

-- The vacuum in the player's hand right now, or nil.
function HuntService.heldVacuum(player: Player): string?
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	local id = if tool then tool:GetAttribute("VacuumId") else nil
	return if typeof(id) == "string" then id else nil
end

-- Holding a vacuum makes it the one you use (reach, strength, bag).
local function holdVacuum(player: Player, itemId: string)
	local data = DataService.get(player)
	local item = Workshop.item(itemId)
	if data and item and Workshop.equipSlot(item) == "vacuum" and Workshop.owns(data.inventory, item) then
		data.equipped.vacuum = item.id
		setCarrying(player, carrying[player]) -- the bag size follows the vacuum
	end
end

-- The hotbar Tool an item should be right now (its name carries the count), or nil for none.
local function toolName(data: DataService.Data, item: Shop.Item): string?
	if Workshop.isTool(item) then
		return if Workshop.owns(data.inventory, item) then item.name else nil
	end
	local count = itemCount(data, item.id)
	return if count > 0 then `{item.name} x{count}` else nil
end

-- Makes the hotbar match the vacuums, Bait Bells and Return Charms the player owns: one
-- Tool each, in Workshop order.
local function syncTools(player: Player)
	local data = DataService.get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	local have: { [string]: Tool } = {}
	local containers: { Instance } = { backpack }
	if player.Character then
		table.insert(containers, player.Character)
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			local id = child:GetAttribute("ToolId")
			if child:IsA("Tool") and typeof(id) == "string" then
				local item = Workshop.item(id)
				local name = if item then toolName(data, item) else nil
				if not name or have[id] then
					child:Destroy()
				else
					have[id] = child
					child.Name = name
				end
			end
		end
	end
	for _, item in Shop.Workshop do
		local name = toolName(data, item)
		if not name or have[item.id] then
			continue
		end
		local tool = ToolModel.tool(item.id, name)
		if not tool then
			continue
		end
		tool:SetAttribute("ToolId", item.id)
		tool:SetAttribute("Section", "Tool")
		tool:SetAttribute("Order", item.price)
		if Workshop.isTool(item) then
			tool:SetAttribute("VacuumId", item.id)
			tool.ToolTip = "Hold it and click a monster to catch it"
			tool.Equipped:Connect(function()
				holdVacuum(player, item.id)
			end)
		elseif item.kind == "Lure" then
			tool.ToolTip = "Click in a zone to ring it: a rarer monster comes to you"
			tool.Activated:Connect(function()
				HuntService.useBaitBell(player, item.id)
			end)
		elseif item.id == "ReturnCharm" then
			tool.ToolTip = "Click to go home with your catch"
			tool.Activated:Connect(function()
				HuntService.useReturnCharm(player)
			end)
		end
		tool.Parent = backpack
	end
end

-- Updates the ReturnCharms, BaitBells and BagSize attributes (the client shows each button
-- only if it's above 0) and the hotbar Tools. Call it after anything changes the inventory or
-- the equipped vacuum.
function HuntService.refreshItems(player: Player)
	local data = DataService.get(player)
	player:SetAttribute("ReturnCharms", if data then itemCount(data, "ReturnCharm") else 0)
	-- BaitBells, SilverBells, GoldBells
	for _, item in Shop.Workshop do
		if item.kind == "Lure" then
			player:SetAttribute(`{item.id}s`, if data then itemCount(data, item.id) else 0)
		end
	end
	setCarrying(player, carrying[player])
	syncTools(player)
end

function HuntService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

-- True when the bag holds as many as the equipped vacuum carries.
function HuntService.isBagFull(player: Player): boolean
	local bag = carrying[player]
	return bag ~= nil and #bag >= bagSize(player)
end

-- Puts a fresh catch in the hunter's bag. False if the bag is full.
function HuntService.carry(player: Player, caught: Value.CaughtMonster): boolean
	if HuntService.isBagFull(player) then
		return false
	end
	local bag = table.clone(carrying[player] or {})
	table.insert(bag, caught)
	setCarrying(player, bag)
	return true
end

-- Monsters fighting back. At 0 hearts everything in the bag is dropped and the hunter is
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
	Notify.toast(player, "Hold your vacuum (hotbar), then click or tap a monster to catch it!")
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

-- Uses a Return Charm (the button, R, or clicking with the charm in hand).
function HuntService.useReturnCharm(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if player:GetAttribute("Zone") == nil and not carrying[player] then
		Notify.toast(player, "You're already home. The Return Charm works on a hunt.")
		return
	end
	if itemCount(data, "ReturnCharm") <= 0 then
		Notify.toast(player, "You don't have a Return Charm. The Hunter's Workshop sells them.")
		return
	end
	useItem(data, "ReturnCharm")
	HuntService.refreshItems(player)
	goHome(player, true)
end

-- Rings a Bait Bell (a button, B, or clicking with the bell in hand). `bellId` picks the kind
-- (Shop.luau, kind "Lure"); the plain Bait Bell if left out.
function HuntService.useBaitBell(player: Player, bellId: unknown)
	local bell = Workshop.item(if typeof(bellId) == "string" then bellId else "BaitBell")
	if not bell or bell.kind ~= "Lure" then
		return
	end
	local data = DataService.get(player)
	local zone = Hunt.zoneById(player:GetAttribute("Zone"))
	if not data then
		return
	end
	if not zone then
		Notify.toast(player, `Ring the {bell.name} in a zone to call a monster.`)
		return
	end
	if itemCount(data, bell.id) <= 0 then
		Notify.toast(player, `You don't have a {bell.name}. The Hunter's Workshop sells them.`)
		return
	end
	-- A monster you couldn't catch would waste the bell.
	if HuntService.isBagFull(player) then
		Notify.toast(player, "Your bag is full. Bring your catch home before ringing the bell!")
		return
	end
	if not MansionService.hasRoom(player) then
		Notify.toast(
			player,
			"Your mansion and Storage are full! Sell some at the Collector or buy a new wing."
		)
		return
	end
	local ok, message = SpawnService.lure(player, zone.index, data.equipped.vacuum, bell.id)
	if ok then
		useItem(data, bell.id) -- only used up when a monster actually came
		HuntService.refreshItems(player)
	end
	Notify.toast(player, message)
end

UseReturnCharm.OnServerEvent:Connect(HuntService.useReturnCharm)
UseBaitBell.OnServerEvent:Connect(HuntService.useBaitBell)

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
			task.defer(syncTools, player) -- the Backpack is new after every respawn
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
		HuntService.refreshItems(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- Leaving mid-run loses the bag, so quitting can't be used as a free teleport home.
		carrying[player] = nil
		lastPortal[player] = nil
		lastLocked[player] = nil
	end)
end

return HuntService
