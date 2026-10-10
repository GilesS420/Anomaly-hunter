--!strict
-- The Collector: sells the monsters roaming your mansion for money. Hold the prompt at
-- Workspace.Hub.Landmarks.Collector to open the sell window. Prices come from
-- Util/Value.sellValue (size, effects, familiarity and wings all count; a hungry monster
-- sells for base value x size, so the window says so). Monsters in the Vault are never
-- offered here.
--
-- Remotes in ReplicatedStorage.CollectorRemotes:
--   Open     server -> client (counter: Vector3)   the player used the Collector prompt
--   GetList  client -> server () -> Offer?         what they can sell and for how much
--   Sell     client -> server (uids) -> Result     sells those monsters

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(ReplicatedStorage.Shared.Util.Care)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Counter = require(script.Parent.Parent.Counter)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)

local CollectorService = {}

export type Row = {
	uid: string,
	monsterId: string,
	name: string,
	details: string, -- "Big Rare · Ghost"
	color: Color3, -- rarity colour
	price: number,
	confirm: boolean, -- rare enough that the window asks "are you sure?" first
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

local function price(caught: Value.CaughtMonster, wingsOwned: number): number
	local ok, value = pcall(Value.sellValue, caught, wingsOwned)
	return if ok then value else 0 -- an unknown monster or effect sells for nothing (and isn't listed)
end

local function offerFor(data: DataService.Data): Offer
	local rows: { Row } = {}
	local total = 0
	local now = os.time()
	for _, caught in data.monsters do
		Care.settle(caught, now) -- up-to-date Familiarity, and hungry or not
		local monster = Monsters[caught.monsterId]
		local value = price(caught, data.wingsOwned)
		if not monster or not caught.uid or value <= 0 then
			continue
		end
		local rarity = Rarities[monster.rarity]
		local details = `{caught.size} {monster.rarity}`
		if #caught.effects > 0 then
			local names = {}
			for _, effectId in caught.effects do
				table.insert(names, Format.name(effectId))
			end
			details ..= ` · {table.concat(names, ", ")}`
		end
		if not caught.fed then
			details ..= " · Hungry: feed it to sell for more"
		end
		table.insert(rows, {
			uid = caught.uid,
			monsterId = caught.monsterId,
			name = Format.name(caught.monsterId),
			details = details,
			color = MonsterModel.color(monster.rarity),
			price = value,
			confirm = rarity ~= nil and rarity.order >= confirmOrder,
		})
		total += value
	end
	table.sort(rows, function(a, b)
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
	local now = os.time()
	for _, caught in data.monsters do
		if caught.uid and wanted[caught.uid] then
			Care.settle(caught, now)
			priced[caught.uid] = price(caught, data.wingsOwned)
		end
	end
	local sold = MansionService.removeMonsters(player, wanted)
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
	counter = Counter.prompt("Collector", "Sell monsters", "The Collector", function(player)
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
