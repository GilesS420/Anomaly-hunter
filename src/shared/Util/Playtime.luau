--!strict
-- Playtime gift rules (numbers in Config/Playtime). Pure so they can be tested outside Roblox;
-- server/Services/PlaytimeService keeps the record in the save (data.playtime).

local Config = require("../Config/Playtime")
local Missions = require("./Missions")
local Shop = require("../Config/Shop")
local Wings = require("../Config/Wings")

local Playtime = {}

export type Record = {
	day: number, -- Util/Missions.day of the seconds below
	seconds: number, -- play time counted that day
	claimed: { [string]: boolean }, -- step index (as a string, so it saves) -> claimed
}
export type Reward = { cash: number, item: string?, itemName: string?, kind: string? }

local items: { [string]: Shop.Item } = {}
for _, list in { Shop.Workshop, Shop.Bakery } do
	for _, item in list do
		items[item.id] = item
	end
end

function Playtime.empty(): Record
	return { day = 0, seconds = 0, claimed = {} }
end

-- A broken or missing record becomes an empty one.
function Playtime.repair(record: any): Record
	if typeof(record) ~= "table" then
		return Playtime.empty()
	end
	if typeof(record.day) ~= "number" or record.day ~= record.day then
		record.day = 0
	end
	if typeof(record.seconds) ~= "number" or record.seconds ~= record.seconds or record.seconds < 0 then
		record.seconds = 0
	end
	if typeof(record.claimed) ~= "table" then
		record.claimed = {}
	end
	return record
end

-- Starts the record over when the day turned. True if it did.
function Playtime.refresh(record: Record, now: number): boolean
	local today = Missions.day(now)
	if record.day == today then
		return false
	end
	record.day = today
	record.seconds = 0
	record.claimed = {}
	return true
end

function Playtime.isReady(record: Record, index: number): boolean
	local step = Config.Steps[index]
	return step ~= nil and record.seconds >= step.minutes * 60 and not record.claimed[tostring(index)]
end

function Playtime.isClaimed(record: Record, index: number): boolean
	return record.claimed[tostring(index)] == true
end

-- How many gifts are waiting (the red dot).
function Playtime.ready(record: Record): number
	local count = 0
	for index in Config.Steps do
		if Playtime.isReady(record, index) then
			count += 1
		end
	end
	return count
end

-- Seconds of play until the next gift, or nil when every one has come today.
function Playtime.nextIn(record: Record): number?
	for _, step in Config.Steps do
		local left = step.minutes * 60 - record.seconds
		if left > 0 then
			return left
		end
	end
	return nil
end

-- What their wings past the Foyer and their vacuums and slappers cost.
function Playtime.invested(inventory: { [string]: number }, wingsOwned: number): number
	local total = 0
	for index = 1, math.min(math.floor(wingsOwned), #Wings.List) do
		total += Wings.List[index].price
	end
	for id, count in inventory do
		local item = items[id]
		if
			item
			and (item.kind == "Vacuum" or item.kind == "Slapper")
			and typeof(count) == "number"
			and count > 0
		then
			total += item.price
		end
	end
	return total
end

function Playtime.base(worth: number, invested: number): number
	return math.max(0, worth) + math.max(0, invested) * Config.InvestShare
end

-- The cake for this base: the priciest non-event cake up to CakeShare of it, else the cheapest.
function Playtime.cake(base: number): Shop.Item?
	local best: Shop.Item? = nil
	local cheapest: Shop.Item? = nil
	for _, item in Shop.Bakery do
		if item.event then
			continue
		end
		if item.price <= base * Config.CakeShare and (not best or item.price > best.price) then
			best = item
		end
		if not cheapest or item.price < cheapest.price then
			cheapest = item
		end
	end
	return best or cheapest
end

-- What step `index` gives a player with this base and this many wings.
function Playtime.reward(index: number, base: number, wingsOwned: number): Reward?
	local step = Config.Steps[index]
	if not step then
		return nil
	end
	local cash = 0
	if step.share then
		cash = math.max(step.floor or 0, math.floor(base * step.share))
	end
	local itemId = step.item
	if step.pick == "Bell" then
		itemId = if wingsOwned >= Config.SilverBellWings then "SilverBell" else "BaitBell"
	elseif step.pick == "Cake" then
		local cake = Playtime.cake(base)
		itemId = if cake then cake.id else nil
	end
	local item = if itemId then items[itemId] else nil
	return {
		cash = cash,
		item = if item then item.id else nil,
		itemName = if item then item.name else nil,
		kind = if item then item.kind :: string else nil,
	}
end

-- Marks step `index` claimed. False if it isn't ready (not played long enough, or claimed).
function Playtime.claim(record: Record, index: unknown): boolean
	if typeof(index) ~= "number" or index ~= math.floor(index) or not Playtime.isReady(record, index) then
		return false
	end
	record.claimed[tostring(index)] = true
	return true
end

return Playtime
