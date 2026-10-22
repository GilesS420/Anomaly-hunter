--!strict
-- Two shops sell the Shop.Workshop items:
--   the Vacuum Vault       vacuums (always in stock), and choosing which one to use
--   the Hunter's Workshop  Bait Bells, Return Charms, Name Tags
-- Hold the prompt at Workspace.Hub.Landmarks.VacuumVault or .Workshop to open its window.
-- The stock changes every 5 minutes (Util/Workshop decides what's in stock, the same in every
-- server). Tools are kept forever and equipped straight away; single-use items stack in the
-- inventory, up to a random number per restock (Workshop.limit).
--
-- Remotes in ReplicatedStorage.WorkshopRemotes:
--   Open     server -> client (counter: Vector3, store: Store)   the player used a prompt
--   GetShop  client -> server (store: Store) -> View?             what's for sale and owned
--   Buy      client -> server (itemId) -> Result
--   Equip    client -> server (itemId) -> Result   puts an owned vacuum into use

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Tutorial = require(ReplicatedStorage.Shared.Util.Tutorial)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local Counter = require(script.Parent.Parent.Counter)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)
local ToolModel = require(script.Parent.Parent.ToolModel)

local WorkshopService = {}

export type Row = {
	id: string,
	name: string,
	kind: string,
	price: number,
	description: string,
	rarity: string, -- the tag on the card (Shop.Item.rarity)
	rarityColor: Color3,
	tool: boolean,
	inStock: boolean,
	owned: boolean, -- tools: you have it
	equipped: boolean, -- tools: you're using it
	count: number, -- single-use items: how many you have
	bought: number, -- bought since the last restock
	limit: number, -- most you can buy per restock
	look: string?, -- preview model in InventoryPreviews (ToolModel.look)
}
export type View = { items: { Row }, secondsLeft: number, money: number }
export type Store = string -- "Workshop" or "VacuumVault"
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

-- Where each shop's prompt is (nil if that landmark doesn't exist).
local counters: { [Store]: Attachment? } = {}
local StoreNames: { [Store]: string } = { Workshop = "Hunter's Workshop", VacuumVault = "Vacuum Vault" }

-- Which shop sells an item: vacuums in the Vault, the rest in the Workshop.
local function storeOf(item: Shop.Item): Store
	return if item.kind == "Vacuum" then "VacuumVault" else "Workshop"
end

local kindOrder = { Vacuum = 1, Lure = 2, Charm = 3, Tag = 4 }

local function currentSlot(): number
	return Workshop.slotAt(os.time())
end

local function boughtThisSlot(data: DataService.Data, slot: number): { [string]: number }
	return Workshop.boughtThisSlot(data.shop, slot)
end

-- The tutorial's first vacuum is always in stock while its Buy step is on (a huge restock
-- chance multiplier), so a new player is never told to come back later.
local function stockBoost(data: DataService.Data, item: Shop.Item?): number?
	return if item and item.id == Tutorial.FirstVacuum and data.tutorial == "Buy" then math.huge else nil
end

local function viewFor(data: DataService.Data, store: Store): View
	local slot = currentSlot()
	local bought = boughtThisSlot(data, slot)
	local equipped = data.equipped :: { [string]: string }
	local items: { Row } = {}
	for _, item in Shop.Workshop do
		if storeOf(item) ~= store then
			continue
		end
		local equipSlot = Workshop.equipSlot(item)
		table.insert(items, {
			id = item.id,
			name = item.name,
			kind = item.kind :: string,
			price = item.price,
			description = Workshop.describe(item),
			rarity = item.rarity,
			rarityColor = MonsterModel.color(item.rarity),
			tool = Workshop.isTool(item),
			inStock = Workshop.inStock(item, slot, nil, stockBoost(data, item)),
			owned = Workshop.owns(data.inventory, item),
			equipped = equipSlot ~= nil and equipped[equipSlot] == item.id,
			count = data.inventory[item.id] or 0,
			bought = bought[item.id] or 0,
			limit = Workshop.limit(item, slot),
			look = ToolModel.look(item.id),
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

GetShop.OnServerInvoke = function(player: Player, store: unknown): View?
	local data = DataService.get(player)
	return if data then viewFor(data, if store == "VacuumVault" then "VacuumVault" else "Workshop") else nil
end

Buy.OnServerInvoke = function(player: Player, itemId: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	local item = if typeof(itemId) == "string" then Workshop.item(itemId) else nil
	local store: Store = if item then storeOf(item) else "Workshop"
	if not Counter.isNear(player, counters[store]) then
		return {
			ok = false,
			message = `Walk up to the {StoreNames[store]} to shop.`,
			view = viewFor(data, store),
		}
	end
	local slot = currentSlot()
	local bought = boughtThisSlot(data, slot)
	local check = Workshop.canBuy(
		item,
		slot,
		data.money,
		data.inventory,
		if item then bought[item.id] or 0 else 0,
		nil,
		stockBoost(data, item)
	)

	local message
	if check == "Ok" and item and DataService.addMoney(player, -item.price) then
		data.inventory[item.id] = (data.inventory[item.id] or 0) + 1
		bought[item.id] = (bought[item.id] or 0) + 1
		local equipSlot = Workshop.equipSlot(item)
		if equipSlot then
			-- A new tool goes straight into use; swap back any time at the Vault.
			local equipped: { [string]: string } = data.equipped
			equipped[equipSlot] = item.id
			message = `Bought the {item.name}! You're using it now.`
		else
			message = `Bought a {item.name}! You have {data.inventory[item.id]}.`
		end
		HuntService.refreshItems(player)
		Notify.toast(player, message)
		return { ok = true, message = message, view = viewFor(data, store) }
	elseif check == "TooPoor" and item then
		message = `You need {Format.money(item.price - data.money)} more for the {item.name}.`
	elseif check == "Owned" then
		message = "You already own that."
	elseif check == "SoldOut" and item then
		message = `You bought all {Workshop.limit(item, slot)} this restock. More in {countdown(
			Workshop.restockAt(slot) - os.time()
		)}.`
	elseif check == "OutOfStock" then
		message = `Out of stock. The Workshop restocks in {countdown(Workshop.restockAt(slot) - os.time())}.`
	else
		message = "That isn't for sale."
	end
	Notify.toast(player, message)
	return { ok = false, message = message, view = viewFor(data, store) }
end

-- Puts an owned tool into use (the Vault window and the Backpack both use this).
-- Returns whether it worked and what to say.
function WorkshopService.equip(data: DataService.Data, itemId: unknown): (boolean, string)
	local item = if typeof(itemId) == "string" then Workshop.item(itemId) else nil
	local equipSlot = if item then Workshop.equipSlot(item) else nil
	if not item or not equipSlot or not Workshop.owns(data.inventory, item) then
		return false, "You don't own that tool."
	end
	local equipped = data.equipped :: { [string]: string }
	equipped[equipSlot] = item.id
	return true, `Using the {item.name}.`
end

Equip.OnServerInvoke = function(player: Player, itemId: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	if not Counter.isNear(player, counters.VacuumVault) then
		return {
			ok = false,
			message = "Walk up to the Vacuum Vault to change vacuums.",
			view = viewFor(data, "VacuumVault"),
		}
	end
	local ok, message = WorkshopService.equip(data, itemId)
	HuntService.refreshItems(player) -- the bag size follows the vacuum
	return { ok = ok, message = message, view = viewFor(data, "VacuumVault") }
end

-- Flashlights and the Spirit Lens were replaced by vacuums: owners get their money back.
local function refundRetired(player: Player, data: DataService.Data)
	local equipped: { [string]: string? } = data.equipped :: any -- older saves have more slots
	equipped.flashlight = nil
	equipped.lens = nil
	if not Workshop.item(data.equipped.vacuum) then
		data.equipped.vacuum = "DustBuster"
	end
	local refund = Workshop.refundRetired(data.inventory)
	if refund > 0 and DataService.addMoney(player, refund) then
		Notify.toast(
			player,
			`Flashlights are gone: vacuums do it all now. You got {Format.money(refund)} back for yours!`
		)
	end
end

function WorkshopService.start()
	remotes.Parent = ReplicatedStorage
	DataService.onLoaded(refundRetired)
	for store, name in StoreNames do
		counters[store] = Counter.prompt(store, "Shop", name, function(player)
			local at = counters[store]
			if at and DataService.isLoaded(player) then
				Open:FireClient(player, at.WorldPosition, store)
			end
		end)
	end

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
