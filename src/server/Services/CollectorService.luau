--!strict
-- The Collector: sells the monsters in your Backpack (Storage) for money, saved ones from
-- earlier visits included. Monsters roaming your mansion aren't offered: pick one up first
-- (E next to it). Hold the prompt at Workspace.Hub.Landmarks.Collector to open the sell
-- window. Prices come from Util/Value.sellValue (size, effects, familiarity and wings all
-- count), at the value a monster had when stored. Hearted (locked) monsters are listed but
-- can't be sold; the Vault is never offered here.
--
-- Remotes in ReplicatedStorage.CollectorRemotes:
--   Open     server -> client (counter: Vector3)   the player used the Collector prompt
--   GetList  client -> server () -> Offer?         what they can sell and for how much
--   Sell     client -> server (uids) -> Result     sells those monsters

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Weight = require(ReplicatedStorage.Shared.Util.Weight)
local Counter = require(script.Parent.Parent.Counter)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MansionService = require(script.Parent.MansionService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)

local CollectorService = {}

export type Row = {
	uid: string,
	monsterId: string,
	name: string,
	details: string, -- "Big Rare · Ghost"
	kind: string, -- "Shiny Big Rare": variant, size and rarity
	effects: { string }, -- effect names, for the Effects box
	weight: string?, -- "54 kg"
	look: string, -- the preview model in PlayerGui.InventoryPreviews (InventoryService)
	color: Color3, -- rarity colour
	price: number,
	confirm: boolean, -- rare enough that the window asks "are you sure?" first
	locked: boolean, -- hearted in the Backpack: shown, but not for sale
}
export type Offer = { monsters: { Row }, total: number }
export type Result = { ok: boolean, message: string, offer: Offer? }

local MaxPerSale = 200 -- more uids than any mansion holds is a bad request

local busy: { [Player]: boolean } = {}
local counter: Attachment? = nil -- where the Collector's prompt is (nil if there's no Collector)

local remotes = Instance.new("Folder")
remotes.Name = "CollectorRemotes"
local Open = Instance.new("RemoteEvent")
Open.Name = "Open"
Open.Parent = remotes
local GetList = Instance.new("RemoteFunction")
GetList.Name = "GetList"
GetList.Parent = remotes
local Sell = Instance.new("RemoteFunction")
Sell.Name = "Sell"
Sell.Parent = remotes

local confirmOrder = Rarities[Shop.ConfirmSellFrom].order

-- What the Collector pays: the sell value, raised while a Watcher event with a
-- sellMultiplier is live (Gold Rush).
local function price(caught: Value.CaughtMonster, wingsOwned: number): number
	local ok, value = pcall(Value.sellValue, caught, wingsOwned)
	if not ok then
		-- An unknown monster or effect sells for nothing (and isn't listed): say why in Output.
		warn(`CollectorService: can't price {caught.monsterId} ({caught.uid}): {value}`)
		return 0
	end
	local event = Events.find(workspace:GetAttribute("WatcherEvent"))
	local multiplier = if event then event.sellMultiplier or 1 else 1
	return math.floor(value * multiplier)
end

-- Every monster that can be sold: the unlocked ones in the Backpack (Storage). They're
-- paused there, so they keep the state they were stored with.
local function sellable(data: DataService.Data): { Value.CaughtMonster }
	local list = {}
	for _, caught in data.storage do
		if not caught.locked then
			table.insert(list, caught)
		end
	end
	return list
end

local function offerFor(data: DataService.Data): Offer
	local rows: { Row } = {}
	local total = 0
	for _, caught in data.storage do
		local monster = Monsters[caught.monsterId]
		local value = price(caught, data.wingsOwned)
		if not monster or not caught.uid or value <= 0 then
			continue
		end
		local rarity = Rarities[monster.rarity]
		local variant = if caught.variant then `{caught.variant} ` else ""
		local kind = `{variant}{caught.size} {monster.rarity}`
		local details = kind
		local names = {}
		for _, effectId in Value.resolveEffects(caught.effects) do
			table.insert(names, Format.name(effectId))
		end
		if #names > 0 then
			details ..= ` · {table.concat(names, ", ")}`
		end
		table.insert(rows, {
			uid = caught.uid,
			monsterId = caught.monsterId,
			name = Format.monsterName(caught),
			details = details,
			kind = kind,
			effects = names,
			weight = if caught.kg then Weight.text(caught.kg) else nil,
			look = InventoryService.lookOf(caught),
			color = MonsterModel.color(monster.rarity),
			price = value,
			confirm = rarity ~= nil and rarity.order >= confirmOrder,
			locked = caught.locked == true,
		})
		if not caught.locked then
			total += value
		end
	end
	-- Most valuable first; hearted ones after the rest.
	table.sort(rows, function(a, b)
		if a.locked ~= b.locked then
			return b.locked
		end
		return if a.price == b.price then a.uid < b.uid else a.price > b.price
	end)
	return { monsters = rows, total = total }
end

GetList.OnServerInvoke = function(player: Player): Offer?
	local data = DataService.get(player)
	return if data then offerFor(data) else nil
end

Sell.OnServerInvoke = function(player: Player, uids: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	if not Counter.isNear(player, counter) then
		return { ok = false, message = "Walk up to the Collector to sell.", offer = offerFor(data) }
	end
	if typeof(uids) ~= "table" then
		return { ok = false, message = "Nothing to sell.", offer = offerFor(data) }
	end
	if busy[player] then
		return { ok = false, message = "One sale at a time!", offer = offerFor(data) }
	end

	-- A set of uid strings; anything else in the request is ignored.
	local wanted: { [string]: boolean } = {}
	local count = 0
	for _, uid in uids :: { any } do
		if typeof(uid) == "string" and not wanted[uid] then
			wanted[uid] = true
			count += 1
			if count > MaxPerSale then
				return { ok = false, message = "That's too many at once.", offer = offerFor(data) }
			end
		end
	end

	busy[player] = true
	-- Price each one before it leaves the mansion (the wing boost needs the save as it is now).
	local earned = 0
	local priced: { [string]: number } = {}
	local selling: { [string]: boolean } = {} -- only unlocked ones, whatever was asked
	for _, caught in sellable(data) do
		if caught.uid and wanted[caught.uid] then
			priced[caught.uid] = price(caught, data.wingsOwned)
			selling[caught.uid] = true
		end
	end
	local sold = MansionService.removeMonsters(player, selling)
	for _, caught in sold do
		earned += priced[caught.uid :: string] or 0
	end
	if earned > 0 then
		DataService.addMoney(player, earned)
	end
	busy[player] = nil

	if #sold == 0 then
		return { ok = false, message = "Those monsters are already gone.", offer = offerFor(data) }
	end
	local what = if #sold == 1 then Format.name(sold[1].monsterId) else `{#sold} monsters`
	local message = `Sold {what} for {Format.money(earned)}!`
	Notify.toast(player, message)
	return { ok = true, message = message, offer = offerFor(data) }
end

function CollectorService.start()
	remotes.Parent = ReplicatedStorage
	counter = Counter.prompt("Collector", "The Collector", function(player)
		local at = counter
		if at and DataService.isLoaded(player) then
			Open:FireClient(player, at.WorldPosition)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return CollectorService
