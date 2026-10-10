--!strict
-- The Haunted Bakery: buy treats and give them to your monsters. Hold the prompt at
-- Workspace.Hub.Landmarks.Bakery to open the window. The stock changes every 5 minutes, at
-- the same moment as the Workshop's and by the same rules (Util/Workshop), and you can buy up
-- to Shop.ConsumablesPerRestock of each treat per restock. Bought treats wait in your
-- inventory until you give one to a monster here (Util/Care says what a treat does).
-- Everyday feeding is free with Feed all (CareService), here or anywhere.
--
-- Remotes in ReplicatedStorage.BakeryRemotes:
--   Open     server -> client (counter: Vector3)   the player used the Bakery prompt
--   GetShop  client -> server () -> View?          the treats for sale and your monsters
--   Buy      client -> server (itemId) -> Result
--   Give     client -> server (itemId, uid) -> Result   gives a treat to one of your monsters

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(ReplicatedStorage.Shared.Util.Care)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local CareService = require(script.Parent.CareService)
local Counter = require(script.Parent.Parent.Counter)
local DataService = require(script.Parent.DataService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)

local BakeryService = {}

export type TreatRow = {
	id: string,
	name: string,
	price: number,
	description: string,
	inStock: boolean,
	count: number, -- how many you have
	bought: number, -- bought since the last restock
	limit: number, -- most you can buy per restock
}
export type MonsterRow = {
	uid: string,
	name: string, -- "Big Gravepup · $45K"
	details: string, -- "Ghost · Fed · 45% familiar"
	color: Color3, -- rarity colour
	hungry: boolean,
	blocked: { [string]: string }, -- treat id -> why it can't have that treat ("Has it", "Full")
}
export type View = { treats: { TreatRow }, monsters: { MonsterRow }, secondsLeft: number, money: number }
export type Result = { ok: boolean, message: string, view: View? }

local remotes = Instance.new("Folder")
remotes.Name = "BakeryRemotes"
local Open = Instance.new("RemoteEvent")
Open.Name = "Open"
Open.Parent = remotes
local GetShop = Instance.new("RemoteFunction")
GetShop.Name = "GetShop"
GetShop.Parent = remotes
local Buy = Instance.new("RemoteFunction")
Buy.Name = "Buy"
Buy.Parent = remotes
local Give = Instance.new("RemoteFunction")
Give.Name = "Give"
Give.Parent = remotes

local counter: Attachment? = nil -- where the Bakery's prompt is (nil if there's no Bakery)

local function currentSlot(): number
	return Workshop.slotAt(os.time())
end

local function countdown(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local blockedText: { [string]: string } = { HasEffect = "Has it", NoRoom = "Full" }

local function monsterRows(data: DataService.Data): { MonsterRow }
	local now = os.time()
	local rows: { MonsterRow } = {}
	local values: { [string]: number } = {}
	for _, caught in data.monsters do
		local monster = Monsters[caught.monsterId]
		local uid = caught.uid
		if not monster or not uid then
			continue
		end
		Care.settle(caught, now)
		local ok, value = pcall(Value.sellValue, caught, data.wingsOwned)
		values[uid] = if ok then value else 0

		local parts = {}
		for _, effectId in caught.effects do
			table.insert(parts, Format.name(effectId))
		end
		local effects = if #parts > 0 then `{table.concat(parts, ", ")} · ` else ""
		local blocked = {}
		for _, item in Shop.Bakery do
			local reason = blockedText[Care.canTreat(caught, item)]
			if reason then
				blocked[item.id] = reason
			end
		end
		table.insert(rows, {
			uid = uid,
			name = `{caught.size} {Format.name(caught.monsterId)} · {Format.money(values[uid])}`,
			details = `{effects}{Care.status(caught)}`,
			color = MonsterModel.color(monster.rarity),
			hungry = not caught.fed,
			blocked = blocked,
		})
	end
	-- The most valuable first: that's where a treat is worth the most.
	table.sort(rows, function(a, b)
		local va, vb = values[a.uid], values[b.uid]
		return if va == vb then a.uid < b.uid else va > vb
	end)
	return rows
end

local function viewFor(data: DataService.Data): View
	local slot = currentSlot()
	local bought = Workshop.boughtThisSlot(data.shop, slot)
	local treats: { TreatRow } = {}
	for _, item in Shop.Bakery do
		table.insert(treats, {
			id = item.id,
			name = item.name,
			price = item.price,
			description = Care.describe(item),
			inStock = Workshop.inStock(item, slot),
			count = data.inventory[item.id] or 0,
			bought = bought[item.id] or 0,
			limit = Workshop.limit(item),
		})
	end
	table.sort(treats, function(a, b)
		return if a.price == b.price then a.id < b.id else a.price < b.price
	end)
	return {
		treats = treats,
		monsters = monsterRows(data),
		secondsLeft = Workshop.restockAt(slot) - os.time(),
		money = data.money,
	}
end

GetShop.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	return if data then viewFor(data) else nil
end

Buy.OnServerInvoke = function(player: Player, itemId: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	if not Counter.isNear(player, counter) then
		return { ok = false, message = "Walk up to the Bakery to shop.", view = viewFor(data) }
	end
	local item = if typeof(itemId) == "string" then Care.treat(itemId) else nil
	local slot = currentSlot()
	local bought = Workshop.boughtThisSlot(data.shop, slot)
	local check =
		Workshop.canBuy(item, slot, data.money, data.inventory, if item then bought[item.id] or 0 else 0)

	local message
	if check == "Ok" and item and DataService.addMoney(player, -item.price) then
		data.inventory[item.id] = (data.inventory[item.id] or 0) + 1
		bought[item.id] = (bought[item.id] or 0) + 1
		message = `Bought a {item.name}! Give it to a monster with the Give button.`
		Notify.toast(player, message)
		return { ok = true, message = message, view = viewFor(data) }
	elseif check == "TooPoor" and item then
		message = `You need {Format.money(item.price - data.money)} more for the {item.name}.`
	elseif check == "SoldOut" and item then
		message = `You bought all {Workshop.limit(item)} this restock. More in {countdown(
			Workshop.restockAt(slot) - os.time()
		)}.`
	elseif check == "OutOfStock" then
		message = `Out of stock. The Bakery restocks in {countdown(Workshop.restockAt(slot) - os.time())}.`
	else
		message = "That isn't for sale."
	end
	Notify.toast(player, message)
	return { ok = false, message = message, view = viewFor(data) }
end

Give.OnServerInvoke = function(player: Player, itemId: unknown, uid: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	if not Counter.isNear(player, counter) then
		return { ok = false, message = "Walk up to the Bakery to give treats.", view = viewFor(data) }
	end
	local ok, message = CareService.giveTreat(player, uid, itemId)
	Notify.toast(player, message)
	return { ok = ok, message = message, view = viewFor(data) }
end

function BakeryService.start()
	remotes.Parent = ReplicatedStorage
	counter = Counter.prompt("Bakery", "Shop", "Haunted Bakery", function(player)
		local at = counter
		if at and DataService.isLoaded(player) then
			Open:FireClient(player, at.WorldPosition)
		end
	end)
end

return BakeryService
