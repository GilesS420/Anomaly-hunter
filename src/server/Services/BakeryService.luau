--!strict
-- The Haunted Bakery: buy cakes to set out for your monsters. Hold the prompt at
-- Workspace.Hub.Landmarks.Bakery to open the window. The stock changes every 5 minutes, at
-- the same moment as the Workshop's and by the same rules (Util/Workshop), and you can buy up
-- to a random number (Shop.StockMin to StockMax) of each cake per restock. Bought cakes go into your Roblox
-- hotbar, where you hold one in your mansion and click to set it out (CakeService;
-- Util/Cakes says what a cake does).
--
-- Remotes in ReplicatedStorage.BakeryRemotes:
--   Open     server -> client (counter: Vector3)   the player used the Bakery prompt
--   GetShop  client -> server () -> View?          the cakes for sale
--   Buy      client -> server (itemId) -> Result

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cakes = require(ReplicatedStorage.Shared.Util.Cakes)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local AdminRestock = require(script.Parent.Parent.AdminRestock)
local Counter = require(script.Parent.Parent.Counter)
local CakeService = require(script.Parent.CakeService)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)

local BakeryService = {}

export type TreatRow = {
	id: string,
	name: string,
	price: number,
	description: string, -- reach and the effect odds per bite
	rarity: string, -- the tag on the card (Shop.Item.rarity)
	rarityColor: Color3,
	look: string, -- the cake's preview model in PlayerGui.InventoryPreviews
	inStock: boolean,
	count: number, -- how many you have
	bought: number, -- bought since the last restock
	limit: number, -- most you can buy per restock
}
export type View = { treats: { TreatRow }, secondsLeft: number, money: number }
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

local counter: Attachment? = nil -- where the Bakery's prompt is (nil if there's no Bakery)

local function currentSlot(): number
	return Workshop.slotAt(os.time())
end

-- The Watcher event that's live right now (WatcherService keeps the attribute), or nil.
local function liveEvent(): Events.WatcherEvent?
	return Events.find(workspace:GetAttribute("WatcherEvent"))
end

-- What the live event changes about the stock: its id (event treats) and the restock boost.
local function stockBoost(): (string?, number?)
	local event = liveEvent()
	return if event then event.id else nil, if event then event.bakeryStockMultiplier else nil
end

local function countdown(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function viewFor(player: Player, data: DataService.Data): View
	local slot = currentSlot()
	local bought = Workshop.boughtThisSlot(data.shop, slot)
	local adminBought = AdminRestock.bought(player)
	local eventId, stockMultiplier = stockBoost()
	local treats: { TreatRow } = {}
	for _, item in Shop.Bakery do
		-- An admin restock (server/AdminRestock) sets the stock and limit of the items in it.
		local adminStock = AdminRestock.stock(item.id)
		local inStock = if adminStock
			then adminStock > 0
			else Workshop.inStock(item, slot, eventId, stockMultiplier)
		if item.event and not inStock then
			continue -- event treats only show up during their event
		end
		table.insert(treats, {
			id = item.id,
			name = item.name,
			price = item.price,
			description = Cakes.describe(item),
			rarity = item.rarity,
			rarityColor = MonsterModel.color(item.rarity),
			look = InventoryService.cakeLook(item.id),
			inStock = inStock,
			count = data.inventory[item.id] or 0,
			bought = if adminStock then adminBought[item.id] or 0 else bought[item.id] or 0,
			limit = adminStock or Workshop.limit(item, slot),
		})
	end
	table.sort(treats, function(a, b)
		return if a.price == b.price then a.id < b.id else a.price < b.price
	end)
	return {
		treats = treats,
		secondsLeft = AdminRestock.countdown(Workshop.restockAt(slot) - os.time()),
		money = data.money,
	}
end

GetShop.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	return if data then viewFor(player, data) else nil
end

Buy.OnServerInvoke = function(player: Player, itemId: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	if not Counter.isNear(player, counter) then
		return { ok = false, message = "Walk up to the Bakery to shop.", view = viewFor(player, data) }
	end
	local item = if typeof(itemId) == "string" then Cakes.item(itemId) else nil
	local slot = currentSlot()
	local adminStock = if item then AdminRestock.stock(item.id) else nil
	-- Buys during an admin restock count from it, not against the normal limit.
	local bought = if adminStock then AdminRestock.bought(player) else Workshop.boughtThisSlot(data.shop, slot)
	local eventId, stockMultiplier = stockBoost()
	local check = Workshop.canBuy(
		item,
		slot,
		data.money,
		data.inventory,
		if item then bought[item.id] or 0 else 0,
		eventId,
		stockMultiplier,
		adminStock
	)

	local message
	if check == "Ok" and item and DataService.addMoney(player, -item.price) then
		data.inventory[item.id] = (data.inventory[item.id] or 0) + 1
		bought[item.id] = (bought[item.id] or 0) + 1
		message =
			`Bought a {item.name}! It's in your hotbar: hold it in your mansion and click to set it out.`
		CakeService.syncTools(player)
		Notify.toast(player, message)
		return { ok = true, message = message, view = viewFor(player, data) }
	elseif check == "TooPoor" and item then
		message = `You need {Format.money(item.price - data.money)} more for the {item.name}.`
	elseif check == "SoldOut" and item then
		message = `You bought all {adminStock or Workshop.limit(item, slot)} this restock. More in {countdown(
			AdminRestock.countdown(Workshop.restockAt(slot) - os.time())
		)}.`
	elseif check == "OutOfStock" and item and item.event then
		message = `The {item.name} is only sold during its Watcher event.`
	elseif check == "OutOfStock" then
		message = `Out of stock. The Bakery restocks in {countdown(Workshop.restockAt(slot) - os.time())}.`
	else
		message = "That isn't for sale."
	end
	Notify.toast(player, message)
	return { ok = false, message = message, view = viewFor(player, data) }
end

function BakeryService.start()
	remotes.Parent = ReplicatedStorage
	counter = Counter.prompt("Bakery", "Haunted Bakery", function(player)
		local at = counter
		if at and DataService.isLoaded(player) then
			Open:FireClient(player, at.WorldPosition)
		end
	end)
end

return BakeryService
