--!strict
-- The Hunter's Workshop: buy vacuums, flashlights, the Spirit Lens, Bait Bells and Return
-- Charms, and choose which tools to use. Hold the prompt at Workspace.Hub.Landmarks.Workshop
-- to open the shop window. The stock changes every 5 minutes (Util/Workshop decides what's in
-- stock, the same in every server). Tools are kept forever and equipped straight away;
-- single-use items stack in the inventory, up to Shop.ConsumablesPerRestock per restock.
--
-- Remotes in ReplicatedStorage.WorkshopRemotes:
--   Open     server -> client (counter: Vector3)   the player used the Workshop prompt
--   GetShop  client -> server () -> View?          what's for sale and what they own
--   Buy      client -> server (itemId) -> Result
--   Equip    client -> server (itemId) -> Result   (equipping the lens you wear takes it off)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local Counter = require(script.Parent.Parent.Counter)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local Notify = require(script.Parent.Parent.Notify)

local WorkshopService = {}

export type Row = {
	id: string,
	name: string,
	kind: string,
	price: number,
	description: string,
	tool: boolean,
	inStock: boolean,
	owned: boolean, -- tools: you have it
	equipped: boolean, -- tools: you're using it
	count: number, -- single-use items: how many you have
	bought: number, -- bought since the last restock
	limit: number, -- most you can buy per restock
}
export type View = { items: { Row }, secondsLeft: number, money: number }
export type Result = { ok: boolean, message: string, view: View? }

local remotes = Instance.new("Folder")
remotes.Name = "WorkshopRemotes"
local Open = Instance.new("RemoteEvent")
Open.Name = "Open"
Open.Parent = remotes
local GetShop = Instance.new("RemoteFunction")
GetShop.Name = "GetShop"
GetShop.Parent = remotes
local Buy = Instance.new("RemoteFunction")
Buy.Name = "Buy"
Buy.Parent = remotes
local Equip = Instance.new("RemoteFunction")
Equip.Name = "Equip"
Equip.Parent = remotes

local counter: Attachment? = nil -- where the Workshop's prompt is (nil if there's no Workshop)

local kindOrder = { Vacuum = 1, Flashlight = 2, Lens = 3, Lure = 4, Charm = 5 }

local function currentSlot(): number
	return Workshop.slotAt(os.time())
end

local function boughtThisSlot(data: DataService.Data, slot: number): { [string]: number }
	return Workshop.boughtThisSlot(data.shop, slot)
end

local function viewFor(data: DataService.Data): View
	local slot = currentSlot()
	local bought = boughtThisSlot(data, slot)
	local equipped = data.equipped :: { [string]: string }
	local items: { Row } = {}
	for _, item in Shop.Workshop do
		local equipSlot = Workshop.equipSlot(item)
		table.insert(items, {
			id = item.id,
			name = item.name,
			kind = item.kind :: string,
			price = item.price,
			description = Workshop.describe(item),
			tool = Workshop.isTool(item),
			inStock = Workshop.inStock(item, slot),
			owned = Workshop.owns(data.inventory, item),
			equipped = equipSlot ~= nil and equipped[equipSlot] == item.id,
			count = data.inventory[item.id] or 0,
			bought = bought[item.id] or 0,
			limit = Workshop.limit(item),
		})
	end
	table.sort(items, function(a, b)
		local ka, kb = kindOrder[a.kind] or 9, kindOrder[b.kind] or 9
		if ka ~= kb then
			return ka < kb
		end
		return if a.price == b.price then a.id < b.id else a.price < b.price
	end)
	return {
		items = items,
		secondsLeft = Workshop.restockAt(slot) - os.time(),
		money = data.money,
	}
end

local function countdown(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
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
		return { ok = false, message = "Walk up to the Workshop to shop.", view = viewFor(data) }
	end
	local item = if typeof(itemId) == "string" then Workshop.item(itemId) else nil
	local slot = currentSlot()
	local bought = boughtThisSlot(data, slot)
	local check =
		Workshop.canBuy(item, slot, data.money, data.inventory, if item then bought[item.id] or 0 else 0)

	local message
	if check == "Ok" and item and DataService.addMoney(player, -item.price) then
		data.inventory[item.id] = (data.inventory[item.id] or 0) + 1
		bought[item.id] = (bought[item.id] or 0) + 1
		local equipSlot = Workshop.equipSlot(item)
		if equipSlot then
			-- A new tool goes straight into use; swap back any time at the Workshop.
			local equipped: { [string]: string } = data.equipped
			equipped[equipSlot] = item.id
			message = `Bought the {item.name}! You're using it now.`
		else
			message = `Bought a {item.name}! You have {data.inventory[item.id]}.`
		end
		HuntService.refreshItems(player)
		Notify.toast(player, message)
		return { ok = true, message = message, view = viewFor(data) }
	elseif check == "TooPoor" and item then
		message = `You need {Format.money(item.price - data.money)} more for the {item.name}.`
	elseif check == "Owned" then
		message = "You already own that."
	elseif check == "SoldOut" and item then
		message = `You bought all {Workshop.limit(item)} this restock. More in {countdown(
			Workshop.restockAt(slot) - os.time()
		)}.`
	elseif check == "OutOfStock" then
		message = `Out of stock. The Workshop restocks in {countdown(Workshop.restockAt(slot) - os.time())}.`
	else
		message = "That isn't for sale."
	end
	Notify.toast(player, message)
	return { ok = false, message = message, view = viewFor(data) }
end

Equip.OnServerInvoke = function(player: Player, itemId: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	if not Counter.isNear(player, counter) then
		return { ok = false, message = "Walk up to the Workshop to change tools.", view = viewFor(data) }
	end
	local item = if typeof(itemId) == "string" then Workshop.item(itemId) else nil
	local equipSlot = if item then Workshop.equipSlot(item) else nil
	if not item or not equipSlot or not Workshop.owns(data.inventory, item) then
		return { ok = false, message = "You don't own that tool.", view = viewFor(data) }
	end
	local equipped = data.equipped :: { [string]: string }
	local message
	if equipSlot == "lens" and equipped.lens == item.id then
		equipped.lens = "" -- a lens is optional: equipping the one you wear takes it off
		message = `Took off the {item.name}.`
	else
		equipped[equipSlot] = item.id
		message = `Using the {item.name}.`
	end
	return { ok = true, message = message, view = viewFor(data) }
end

function WorkshopService.start()
	remotes.Parent = ReplicatedStorage
	counter = Counter.prompt("Workshop", "Shop", "Hunter's Workshop", function(player)
		local at = counter
		if at and DataService.isLoaded(player) then
			Open:FireClient(player, at.WorldPosition)
		end
	end)

	-- Tell everyone when new stock arrives, for the Bakery too since both restock together
	-- (players with a shop window open refresh by themselves).
	task.spawn(function()
		local slot = currentSlot()
		while true do
			task.wait(1)
			local now = currentSlot()
			if now ~= slot then
				slot = now
				if #Players:GetPlayers() > 0 then
					Notify.toastAll("The Workshop and the Bakery have restocked!")
				end
			end
		end
	end)
end

return WorkshopService
