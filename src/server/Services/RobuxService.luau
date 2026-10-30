--!strict
-- Robux purchases (Sprint E; products, prices and ids in Config/Robux, bookkeeping in
-- Util/Robux). Paying only ever speeds things up: every shop item can be bought with Robux,
-- even when sold out, but never a monster.
--
-- How a purchase goes:
--   1. The client asks with RobuxRemotes.Buy(kind, arg). The server checks it makes sense,
--      notes what was tapped in data.robux.pending (which shop item, which mission) and opens
--      Roblox's purchase prompt.
--   2. Roblox calls ProcessReceipt once the Robux are paid, and again later if we don't answer
--      PurchaseGranted. Each receipt's PurchaseId is saved in data.robux.receipts with what it
--      gave, and we only answer PurchaseGranted once ProfileStore has written that save. So a
--      receipt is paid out exactly once, even if the server crashes halfway.
--   3. Anything paid for that can't be handed out right then (the tapped item is gone, a mission
--      got finished meanwhile) becomes a credit: the next tap on the same product uses it
--      instead of asking for Robux again.
-- Game Passes set the player attribute Pass<Key>; server/Perks says what each one changes.
--
-- Remotes in ReplicatedStorage.RobuxRemotes:
--   Buy      client -> server (kind: string, arg: any) -> { ok, message }
--            kinds: "Item" (item id), "ShopReroll", "MissionReroll", "MissionSkip" (mission
--            number), "StarterPack", "Pass" (pass key)
--   Granted  server -> client (kind: string)   something was paid out: refresh open windows
-- ReplicatedStorage.RobuxPrices has an attribute per product and pass that is set up (its id
-- isn't 0): its price in Robux, as Roblox knows it.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cakes = require(ReplicatedStorage.Shared.Util.Cakes)
local Config = require(ReplicatedStorage.Shared.Config.Robux)
local Missions = require(ReplicatedStorage.Shared.Util.Missions)
local Robux = require(ReplicatedStorage.Shared.Util.Robux)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local CakeService = require(script.Parent.CakeService)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local MissionService = require(script.Parent.MissionService)
local Notify = require(script.Parent.Parent.Notify)
local Perks = require(script.Parent.Parent.Perks)

local RobuxService = {}

export type Result = { ok: boolean, message: string }

local LoadWait = 15 -- seconds a receipt waits for the buyer's save to load
local random = Random.new()

local remotes = Instance.new("Folder")
remotes.Name = "RobuxRemotes"
local Buy = Instance.new("RemoteFunction")
Buy.Name = "Buy"
Buy.Parent = remotes
local Granted = Instance.new("RemoteEvent")
Granted.Name = "Granted"
Granted.Parent = remotes

local prices = Instance.new("Folder")
prices.Name = "RobuxPrices"

-- A shop item by id, from the Workshop (and Vault) or the Bakery.
local function shopItem(id: unknown): Shop.Item?
	if typeof(id) ~= "string" then
		return nil
	end
	return Workshop.item(id) or Cakes.item(id)
end

local function isCake(item: Shop.Item): boolean
	return Cakes.item(item.id) ~= nil
end

-- Why this item can't be bought with Robux right now, or nil if it can.
local function itemProblem(data: DataService.Data, item: Shop.Item?): string?
	if not item or not Robux.productFor(item.id, item.price) then
		return "That isn't for sale."
	end
	if Workshop.keepsForever(item) and Workshop.owns(data.inventory, item) then
		return "You already own that."
	end
	if item.event and workspace:GetAttribute("WatcherEvent") ~= item.event then
		return `The {item.name} is only sold during its Watcher event.`
	end
	return nil
end

-- Hands one shop item over, the same way a cash buy does.
local function giveItem(player: Player, data: DataService.Data, item: Shop.Item)
	data.inventory[item.id] = (data.inventory[item.id] or 0) + 1
	local equipSlot = Workshop.equipSlot(item)
	if equipSlot then
		local equipped: { [string]: string } = data.equipped
		equipped[equipSlot] = item.id -- a new vacuum goes straight into use
	end
	if isCake(item) then
		CakeService.syncTools(player)
	else
		HuntService.refreshItems(player)
	end
	Notify.toast(player, `Thanks! You got the {item.name}.`)
end

-- Uses one credit of `key` on the item if there is one. True if it did.
local function useItemCredit(player: Player, data: DataService.Data, key: string, item: Shop.Item): boolean
	if itemProblem(data, item) or not Robux.takeCredit(data.robux, key) then
		return false
	end
	giveItem(player, data, item)
	return true
end

local function shopReroll(player: Player, data: DataService.Data)
	local slot = Workshop.slotAt(os.time())
	data.robux.reroll = { slot = slot, salt = random:NextInteger(1, 1_000_000_000) }
	-- New stock, new limits: what they bought from the old stock doesn't count against it.
	data.shop.slot = slot
	data.shop.bought = {}
	Notify.toast(player, "Your Bakery and Workshop stock was rerolled, just for you, until the next restock!")
end

local function missionReroll(player: Player, data: DataService.Data)
	Robux.countReroll(data.robux, Missions.day(os.time()))
	local swapped = MissionService.rerollAll(player)
	if swapped > 0 then
		Notify.toast(player, `New missions! {swapped} swapped.`)
	else
		Robux.addCredit(data.robux, "MissionReroll")
		Notify.toast(player, "Your missions were all done, so your reroll is saved for later.")
	end
end

local function missionSkip(player: Player, data: DataService.Data, index: any)
	if not MissionService.skip(player, index) then
		Robux.addCredit(data.robux, "MissionSkip")
		Notify.toast(player, "That mission was already done, so your skip is saved: tap Skip on another one.")
	end
end

local function starterPack(player: Player, data: DataService.Data)
	data.robux.starter = true
	player:SetAttribute("StarterPack", true)
	for id, count in Config.StarterPack do
		data.inventory[id] = (data.inventory[id] or 0) + count
	end
	HuntService.refreshItems(player)
	Notify.toast(player, `Starter Pack! You got {Config.StarterText}`)
end

-- Pays out one receipt for product `key`. Errors only if something is badly wrong.
local function payOut(player: Player, data: DataService.Data, key: string)
	local record = data.robux
	local pending = record.pending[key]
	record.pending[key] = nil
	if string.sub(key, 1, 8) == "ItemTier" then
		Robux.addCredit(record, key)
		local item = shopItem(pending)
		if
			not item
			or Robux.productFor(item.id, item.price) ~= key
			or not useItemCredit(player, data, key, item)
		then
			Notify.toast(
				player,
				"You have a Robux item credit: tap Robux on any item of the same price to get it free."
			)
		end
	elseif key == "ShopReroll" then
		shopReroll(player, data)
	elseif key == "MissionReroll" then
		missionReroll(player, data)
	elseif key == "MissionSkip" then
		missionSkip(player, data, pending)
	elseif key == "StarterPack" then
		starterPack(player, data)
	else
		error(`no payout for {key}`)
	end
end

local function waitForData(player: Player): DataService.Data?
	local deadline = os.clock() + LoadWait
	local data = DataService.get(player)
	while not data and player.Parent == Players and os.clock() < deadline do
		task.wait(0.5)
		data = DataService.get(player)
	end
	return data
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox tries again when they rejoin
	end
	local data = waitForData(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if not Robux.hasReceipt(data.robux, purchaseId) then
		local key = Robux.productKey(info.ProductId)
		if not key then
			warn(`RobuxService: product {info.ProductId} isn't in Config/Robux`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, problem = pcall(payOut :: any, player, data, key)
		if not ok then
			warn(`RobuxService: paying out {key} for {player.Name} failed: {problem}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		Robux.addReceipt(data.robux, purchaseId)
		data.robux.spent += tonumber(info.CurrencySpent) or 0
		Granted:FireClient(player, key)
	end
	-- Only once the save holding this receipt is written; if not, Roblox asks again later and
	-- the receipt id (still in memory, or lost with the rest) decides whether to pay again.
	if not DataService.saveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Opens Roblox's prompt for product `key`, noting `pending` first. Returns the answer.
local function prompt(player: Player, data: DataService.Data, key: string, pending: any): Result
	local product = Config.Products[key]
	if not product or product.id == 0 then
		return { ok = false, message = "Robux buying for this isn't set up yet." }
	end
	data.robux.pending[key] = pending
	MarketplaceService:PromptProductPurchase(player, product.id)
	return { ok = true, message = "Check the Robux prompt!" }
end

local function owns(player: Player, pass: string): boolean
	return Perks.has(player, pass)
end

-- Turns a pass on for this player (owned on Roblox or just bought).
local function grantPass(player: Player, pass: string, fresh: boolean)
	local data = DataService.get(player)
	if data then
		data.robux.passes[pass] = true
	end
	if owns(player, pass) then
		return
	end
	player:SetAttribute(`Pass{pass}`, true)
	if pass == "VIP" then
		MissionService.refresh(player) -- today's extra reroll
	end
	if fresh then
		local info = Config.Passes[pass]
		Notify.toast(player, `Thanks! {info.name} is yours forever: {Config.PassText[pass]}.`)
		Granted:FireClient(player, pass)
	end
end

Buy.OnServerInvoke = function(player: Player, kind: unknown, arg: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	if kind == "Item" then
		local item = shopItem(arg)
		local problem = itemProblem(data, item)
		if problem or not item then
			return { ok = false, message = problem or "That isn't for sale." }
		end
		local key = Robux.productFor(item.id, item.price) :: string
		if useItemCredit(player, data, key, item) then
			Granted:FireClient(player, key)
			return { ok = true, message = `Used your Robux credit on the {item.name}!` }
		end
		return prompt(player, data, key, item.id)
	elseif kind == "ShopReroll" then
		return prompt(player, data, "ShopReroll", nil)
	elseif kind == "MissionReroll" then
		if MissionService.allDone(player) then
			return { ok = false, message = "Your missions are all done. New ones come tomorrow!" }
		end
		if Robux.takeCredit(data.robux, "MissionReroll") then
			missionReroll(player, data)
			return { ok = true, message = "Used your saved reroll!" }
		end
		if Robux.rerollsBought(data.robux, Missions.day(os.time())) >= Config.MissionRerollsPerDay then
			return {
				ok = false,
				message = `That's the most rerolls for today ({Config.MissionRerollsPerDay}).`,
			}
		end
		return prompt(player, data, "MissionReroll", nil)
	elseif kind == "MissionSkip" then
		local state = data.missions
		local saved = if typeof(arg) == "number" and arg == math.floor(arg) then state.list[arg] else nil
		if not saved or saved.claimed or Missions.isDone(saved) then
			return { ok = false, message = "Pick a mission that isn't done yet." }
		end
		if Robux.takeCredit(data.robux, "MissionSkip") then
			missionSkip(player, data, arg)
			return { ok = true, message = "Used your saved skip!" }
		end
		return prompt(player, data, "MissionSkip", arg)
	elseif kind == "StarterPack" then
		if data.robux.starter then
			return { ok = false, message = "You already got the Starter Pack." }
		end
		return prompt(player, data, "StarterPack", nil)
	elseif kind == "Pass" then
		local pass = if typeof(arg) == "string" then Config.Passes[arg] else nil
		if not pass then
			return { ok = false, message = "That isn't for sale." }
		end
		if owns(player, arg :: string) then
			return { ok = false, message = "You already own that." }
		end
		if pass.id == 0 then
			return { ok = false, message = "Robux buying for this isn't set up yet." }
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
		return { ok = true, message = "Check the Robux prompt!" }
	end
	return { ok = false, message = "That isn't for sale." }
end

-- Turns on the passes a player owns: the ones their save remembers straight away, then the
-- ones Roblox says they own.
local function checkPasses(player: Player, data: DataService.Data)
	for pass in data.robux.passes do
		if Config.Passes[pass] then
			grantPass(player, pass, false)
		end
	end
	for pass, info in Config.Passes do
		if info.id ~= 0 and not owns(player, pass) then
			local ok, has =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, info.id)
			if ok and has and player.Parent == Players then
				grantPass(player, pass, false)
			end
		end
	end
end

-- A gold "VIP" tag over a VIP Hunter's head.
local function vipTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not owns(player, "VIP") or head:FindFirstChild("VipTag") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "VipTag"
	tag.Size = UDim2.fromOffset(70, 26)
	tag.StudsOffset = Vector3.new(0, 3.2, 0)
	tag.MaxDistance = 80
	tag.AlwaysOnTop = false
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "VIP"
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 211, 107)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(90, 50, 0)
	text.Parent = tag
	tag.Parent = head
end

-- Looks up each set-up product's and pass's price on Roblox (falling back to Config/Robux).
local function loadPrices()
	for key, product in Config.Products do
		if product.id ~= 0 then
			local ok, info = pcall(
				MarketplaceService.GetProductInfo,
				MarketplaceService,
				product.id,
				Enum.InfoType.Product
			)
			prices:SetAttribute(
				key,
				if ok and info and info.PriceInRobux then info.PriceInRobux else product.price
			)
		end
	end
	for key, pass in Config.Passes do
		if pass.id ~= 0 then
			local ok, info =
				pcall(MarketplaceService.GetProductInfo, MarketplaceService, pass.id, Enum.InfoType.GamePass)
			prices:SetAttribute(
				key,
				if ok and info and info.PriceInRobux then info.PriceInRobux else pass.price
			)
		end
	end
end

function RobuxService.start()
	remotes.Parent = ReplicatedStorage
	prices.Parent = ReplicatedStorage
	task.spawn(loadPrices)
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = Robux.passKey(passId)
		if purchased and pass then
			grantPass(player, pass, true)
			vipTag(player)
			DataService.saveSoon(player)
		end
	end)
	DataService.onLoaded(function(player, data)
		player:SetAttribute("StarterPack", data.robux.starter)
		checkPasses(player, data)
		vipTag(player)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			vipTag(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return RobuxService
