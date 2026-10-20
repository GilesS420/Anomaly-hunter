--!strict
-- The inventory: everything you own, anywhere in the game, in three sections (the client
-- draws them, InventoryController):
--   Monsters  every monster in your mansion and in Storage, most valuable first. Store one to
--             make room (it's paused there, see Util/Storage) and Lock the ones you never want
--             to sell by accident. Monsters in Storage are also Tools in the hotbar: hold one
--             and click in your mansion to place it there.
--   Cakes     how many of each cake you have. They are Tools in the hotbar too (CakeService).
--   Tools     your vacuums (equip them right here), Bait Bells and Return Charms.
-- Catches that don't fit in the mansion land in Storage by themselves (MansionService.addMonster).
--
-- Hotbar Tools carry attributes the client sorts and groups them by: Section ("Cake" or
-- "Monster") and Order (cakes by price, monsters most valuable first). Monster Tools also
-- carry MonsterUid.
--
-- Remotes in ReplicatedStorage.InventoryRemotes:
--   GetView  client -> server () -> View?
--   Move     client -> server (uid) -> Result      mansion -> Storage, or Storage -> mansion
--   Lock     client -> server (uid) -> Result      locks or unlocks a monster
--   Equip    client -> server (itemId) -> Result   puts an owned tool into use

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cakes = require(ReplicatedStorage.Shared.Util.Cakes)
local Care = require(ReplicatedStorage.Shared.Util.Care)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.Inventory)
local Mansion = require(ReplicatedStorage.Shared.Util.Mansion)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local MansionService = require(script.Parent.MansionService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)
local RoamService = require(script.Parent.RoamService)
local WorkshopService = require(script.Parent.WorkshopService)

local InventoryService = {}

export type MonsterRow = {
	uid: string,
	name: string,
	details: string, -- "Big Rare · Ghost · $1.2M"
	color: Color3, -- rarity colour
	stored: boolean,
	locked: boolean,
}
export type ItemRow = {
	id: string,
	name: string,
	details: string,
	tool: boolean,
	equipped: boolean,
	cake: boolean, -- a Bakery cake (the Cakes section), else the Tools section
}
export type View = {
	monsters: { MonsterRow },
	items: { ItemRow },
	mansionCount: number,
	mansionCapacity: number,
	storageCount: number,
	storageCapacity: number,
}
export type Result = { ok: boolean, message: string, view: View? }

local remotes = Instance.new("Folder")
remotes.Name = "InventoryRemotes"
local function remote(name: string): RemoteFunction
	local fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remotes
	return fn
end
local GetView = remote("GetView")
local Move = remote("Move")
local Lock = remote("Lock")
local Equip = remote("Equip")

local kindOrder = { Vacuum = 1, Food = 2, Lure = 3, Charm = 4 }

local function price(caught: Value.CaughtMonster, wingsOwned: number): number
	local ok, value = pcall(Value.sellValue, caught, wingsOwned)
	return if ok then value else 0
end

local function monsterRow(caught: Value.CaughtMonster, stored: boolean, value: number): MonsterRow?
	local monster = Monsters[caught.monsterId]
	if not monster or not caught.uid then
		return nil
	end
	local variant = if caught.variant then `{caught.variant} ` else ""
	local parts = { `{variant}{caught.size} {monster.rarity}` }
	local effects = Value.resolveEffects(caught.effects)
	if #effects > 0 then
		local names = {}
		for _, effectId in effects do
			table.insert(names, Format.name(effectId))
		end
		table.insert(parts, table.concat(names, ", "))
	end
	table.insert(parts, Format.money(value))
	return {
		uid = caught.uid,
		name = Format.name(caught.monsterId),
		details = table.concat(parts, " · "),
		color = MonsterModel.color(monster.rarity),
		stored = stored,
		locked = caught.locked == true,
	}
end

local function monsterRows(data: DataService.Data): { MonsterRow }
	local rows: { MonsterRow } = {}
	local values: { [string]: number } = {}
	local now = os.time()
	local function add(caught: Value.CaughtMonster, stored: boolean)
		local value = price(caught, data.wingsOwned)
		local row = monsterRow(caught, stored, value)
		if row then
			values[row.uid] = value
			table.insert(rows, row)
		end
	end
	for _, caught in data.monsters do
		Care.settle(caught, now)
		add(caught, false)
	end
	for _, caught in data.storage do
		add(caught, true) -- paused: keeps the state it was stored with
	end
	table.sort(rows, function(a, b)
		local va, vb = values[a.uid], values[b.uid]
		return if va == vb then a.uid < b.uid else va > vb
	end)
	return rows
end

local function itemRows(data: DataService.Data): { ItemRow }
	local equipped = data.equipped :: { [string]: string }
	local rows: { ItemRow } = {}
	local order: { [string]: number } = {}
	local function add(item: Shop.Item)
		local tool: boolean = Workshop.isTool(item)
		local count = data.inventory[item.id] or 0
		if tool and not Workshop.owns(data.inventory, item) or not tool and count <= 0 then
			return
		end
		local equipSlot = Workshop.equipSlot(item)
		local details
		if item.kind == "Food" then
			details = `x{count} · {Cakes.describe(item)}`
		elseif tool then
			details = Workshop.describe(item)
		else
			details = `x{count} · {Workshop.describe(item)}`
		end
		table.insert(rows, {
			id = item.id,
			name = item.name,
			details = details,
			tool = Workshop.isTool(item),
			equipped = equipSlot ~= nil and equipped[equipSlot] == item.id,
			cake = item.kind == "Food",
		})
		order[item.id] = (kindOrder[item.kind] or 9) * 1e15 + item.price
	end
	for _, item in Shop.Workshop do
		add(item)
	end
	for _, item in Shop.Bakery do
		add(item)
	end
	table.sort(rows, function(a, b)
		return if order[a.id] == order[b.id] then a.id < b.id else order[a.id] < order[b.id]
	end)
	return rows
end

local function viewFor(data: DataService.Data): View
	return {
		monsters = monsterRows(data),
		items = itemRows(data),
		mansionCount = #data.monsters,
		mansionCapacity = Mansion.capacity(data.wingsOwned),
		storageCount = #data.storage,
		storageCapacity = InventoryConfig.StorageSlots,
	}
end

local function find(data: DataService.Data, uid: string): Value.CaughtMonster?
	for _, list in { data.monsters, data.storage } do
		for _, caught in list do
			if caught.uid == uid then
				return caught
			end
		end
	end
	return nil
end

local Loading: Result = { ok = false, message = "Your save is still loading. Try again in a moment!" }

GetView.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	return if data then viewFor(data) else nil
end

Move.OnServerInvoke = function(player: Player, uid: unknown): Result
	local data = DataService.get(player)
	if not data then
		return Loading
	end
	if typeof(uid) ~= "string" then
		return { ok = false, message = "That monster is gone.", view = viewFor(data) }
	end
	local result, caught = MansionService.move(player, uid)
	local name = if caught then Format.name(caught.monsterId) else "That monster"
	local message
	if result == "Ok" then
		message = if caught and caught.storedAt
			then `{name} is in Storage now. It's paused until you place it back.`
			else `{name} is back in your mansion!`
	elseif result == "MansionFull" then
		message = "Your mansion is full. Store or sell a monster first, or buy a new wing."
	elseif result == "StorageFull" then
		message = `Storage is full ({InventoryConfig.StorageSlots}). Sell some at the Collector first.`
	else
		message = "That monster is gone."
	end
	return { ok = result == "Ok", message = message, view = viewFor(data) }
end

Lock.OnServerInvoke = function(player: Player, uid: unknown): Result
	local data = DataService.get(player)
	if not data then
		return Loading
	end
	local caught = if typeof(uid) == "string" then find(data, uid) else nil
	if not caught then
		return { ok = false, message = "That monster is gone.", view = viewFor(data) }
	end
	caught.locked = if caught.locked then nil else true
	local name = Format.name(caught.monsterId)
	local message = if caught.locked
		then `Locked {name}. The Collector won't sell it.`
		else `Unlocked {name}.`
	return { ok = true, message = message, view = viewFor(data) }
end

Equip.OnServerInvoke = function(player: Player, itemId: unknown): Result
	local data = DataService.get(player)
	if not data then
		return Loading
	end
	local ok, message = WorkshopService.equip(data, itemId)
	HuntService.refreshItems(player) -- the bag size follows the vacuum
	return { ok = ok, message = message, view = viewFor(data) }
end

-- Monsters in Storage as hotbar Tools ------------------------------------------------------

local PlaceAhead = 4 -- studs in front of you
local SyncSeconds = 1
local placing: { [Player]: boolean } = {}

-- A small glowing orb in the monster's rarity colour, to hold.
local function monsterTool(player: Player, caught: Value.CaughtMonster, rarity: string): Tool
	local tool = Instance.new("Tool")
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Click in your mansion to place it there"
	tool:SetAttribute("Section", "Monster")
	tool:SetAttribute("MonsterUid", caught.uid)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.one * 1.2
	handle.Material = Enum.Material.Neon
	handle.Color = MonsterModel.color(rarity)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local light = Instance.new("PointLight")
	light.Color = handle.Color
	light.Range = 6
	light.Parent = handle
	tool.Grip = CFrame.new(0, 0, -0.4)
	tool.Activated:Connect(function()
		InventoryService.place(player, caught.uid or "")
	end)
	return tool
end

-- Makes the hotbar's monster Tools match Storage: one per stored monster, named and ordered
-- by value. Called every second, so catches, sales and moves all show up by themselves.
function InventoryService.syncMonsterTools(player: Player)
	local data = DataService.get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	local stored: { [string]: Value.CaughtMonster } = {}
	for _, caught in data.storage do
		if caught.uid then
			stored[caught.uid] = caught
		end
	end
	local have: { [string]: Tool } = {}
	local containers: { Instance } = { backpack }
	if player.Character then
		table.insert(containers, player.Character)
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			local uid = child:GetAttribute("MonsterUid")
			if child:IsA("Tool") and typeof(uid) == "string" then
				if not stored[uid] or have[uid] then
					child:Destroy()
				else
					have[uid] = child
				end
			end
		end
	end
	for uid, caught in stored do
		local monster = Monsters[caught.monsterId]
		if monster then
			local tool = have[uid] or monsterTool(player, caught, monster.rarity)
			local variant = if caught.variant then `{caught.variant} ` else ""
			tool.Name = `{variant}{caught.size} {Format.name(caught.monsterId)}`
			tool:SetAttribute("Order", -price(caught, data.wingsOwned))
			if not tool.Parent then
				tool.Parent = backpack
			end
		end
	end
end

local function tryPlace(player: Player, uid: string): string
	local data = DataService.get(player)
	if not data then
		return Loading.message
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local spot = if root and root:IsA("BasePart")
		then MansionService.floorSpot(player, root.Position + root.CFrame.LookVector * PlaceAhead, 3)
		else nil
	if not spot then
		return "Stand inside your mansion to place it."
	end
	local result, caught = MansionService.move(player, uid)
	local name = if caught then Format.name(caught.monsterId) else "That monster"
	if result == "MansionFull" then
		return "Your mansion is full. Store or sell a monster first, or buy a new wing."
	elseif result ~= "Ok" then
		return "That monster is gone."
	end
	-- It appears at a free spot; walk it over to where you clicked.
	task.delay(0.5, function()
		local model = MansionService.monsterModels(player)[uid]
		if model then
			RoamService.teleport(model, spot.X, spot.Z, 2)
		end
	end)
	return `{name} is back in your mansion!`
end

-- Places a stored monster in the mansion, in front of the player (they clicked with it).
function InventoryService.place(player: Player, uid: string)
	if placing[player] then
		return
	end
	placing[player] = true
	local ok, message = pcall(tryPlace, player, uid)
	placing[player] = nil
	if ok then
		Notify.toast(player, message)
		InventoryService.syncMonsterTools(player)
	else
		warn(`InventoryService: placing a monster failed: {message}`)
	end
end

function InventoryService.start()
	remotes.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player)
		placing[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(SyncSeconds)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					InventoryService.syncMonsterTools(player)
				end)
				if not ok then
					warn(`InventoryService: syncing {player.Name}'s monster tools failed: {err}`)
				end
			end
		end
	end)
end

return InventoryService
