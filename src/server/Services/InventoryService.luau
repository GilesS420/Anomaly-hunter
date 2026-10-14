--!strict
-- The Backpack: everything you own, anywhere in the game. Two tabs:
--   Items     your tools (equip them right here) and how many of each treat, bell and charm.
--             Give on a treat lists your mansion monsters so you pick who eats it.
--   Monsters  every monster in your mansion and in Storage, most valuable first. Store one to
--             make room (it's paused there, see Util/Storage), place it back when a wing has
--             room, and Lock the ones you never want to sell by accident.
-- Catches that don't fit in the mansion land in Storage by themselves (MansionService.addMonster).
--
-- Remotes in ReplicatedStorage.InventoryRemotes:
--   GetView  client -> server () -> View?
--   Move     client -> server (uid) -> Result      mansion -> Storage, or Storage -> mansion
--   Lock     client -> server (uid) -> Result      locks or unlocks a monster
--   Equip    client -> server (itemId) -> Result   puts an owned tool into use
--   Give     client -> server (itemId, uid) -> Result   gives a treat to a mansion monster

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(ReplicatedStorage.Shared.Util.Care)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.Inventory)
local Mansion = require(ReplicatedStorage.Shared.Util.Mansion)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local CareService = require(script.Parent.CareService)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)
local WorkshopService = require(script.Parent.WorkshopService)

local InventoryService = {}

export type MonsterRow = {
	uid: string,
	name: string,
	details: string, -- "Big Rare · Ghost · $1.2M"
	color: Color3, -- rarity colour
	stored: boolean,
	locked: boolean,
	blocked: { [string]: string }, -- treat id -> why it can't have that treat ("Has it", "Full")
}
export type ItemRow = {
	id: string,
	name: string,
	details: string,
	tool: boolean,
	equipped: boolean,
	treat: boolean, -- a Bakery treat: can be given to a monster
	confirm: boolean, -- expensive treat: giving it needs a second tap
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
local Give = remote("Give")

local ConfirmGiveFrom = 1_000_000 -- giving a treat this expensive needs a second tap
local blockedText: { [string]: string } = { HasEffect = "Has it", NoRoom = "Full" }

local kindOrder = { Vacuum = 1, Flashlight = 2, Lens = 3, Food = 4, Lure = 5, Charm = 6 }

local function price(caught: Value.CaughtMonster, wingsOwned: number): number
	local ok, value = pcall(Value.sellValue, caught, wingsOwned)
	return if ok then value else 0
end

local function monsterRow(caught: Value.CaughtMonster, stored: boolean, value: number): MonsterRow?
	local monster = Monsters[caught.monsterId]
	if not monster or not caught.uid then
		return nil
	end
	local parts = { `{caught.size} {monster.rarity}` }
	local effects = Value.resolveEffects(caught.effects)
	if #effects > 0 then
		local names = {}
		for _, effectId in effects do
			table.insert(names, Format.name(effectId))
		end
		table.insert(parts, table.concat(names, ", "))
	end
	table.insert(parts, Format.money(value))
	if not stored and not caught.fed then
		table.insert(parts, "Hungry")
	end
	local blocked = {}
	for _, item in Shop.Bakery do
		local reason = if stored then "Stored" else blockedText[Care.canTreat(caught, item)]
		if reason then
			blocked[item.id] = reason
		end
	end
	return {
		uid = caught.uid,
		name = Format.name(caught.monsterId),
		details = table.concat(parts, " · "),
		color = MonsterModel.color(monster.rarity),
		stored = stored,
		locked = caught.locked == true,
		blocked = blocked,
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
			details = `x{count} · {Care.describe(item)}`
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
			treat = item.kind == "Food",
			confirm = item.kind == "Food" and item.price >= ConfirmGiveFrom,
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
	return { ok = ok, message = message, view = viewFor(data) }
end

Give.OnServerInvoke = function(player: Player, itemId: unknown, uid: unknown): Result
	local data = DataService.get(player)
	if not data then
		return Loading
	end
	local ok, message = CareService.giveTreat(player, uid, itemId)
	Notify.toast(player, message)
	return { ok = ok, message = message, view = viewFor(data) }
end

function InventoryService.start()
	remotes.Parent = ReplicatedStorage
end

return InventoryService
