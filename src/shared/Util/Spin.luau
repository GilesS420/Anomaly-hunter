--!strict
-- Lucky Spin rules (numbers in Config/Spin). Pure so they can be tested outside Roblox;
-- server/Services/SpinService keeps the record in the save (data.spin).

local Config = require("../Config/Spin")
local Missions = require("./Missions")
local Playtime = require("./Playtime")
local PlaytimeConfig = require("../Config/Playtime")
local Shop = require("../Config/Shop")

local Spin = {}

export type Record = {
	day: number, -- Util/Missions.day the count below is for
	used: number, -- spins used that day
}
export type Reward = { cash: number, item: string?, itemName: string?, kind: string?, count: number }

local items: { [string]: Shop.Item } = {}
for _, list in { Shop.Workshop, Shop.Bakery } do
	for _, item in list do
		items[item.id] = item
	end
end

function Spin.empty(): Record
	return { day = 0, used = 0 }
end

-- A broken or missing record becomes an empty one.
function Spin.repair(record: any): Record
	if typeof(record) ~= "table" then
		return Spin.empty()
	end
	if typeof(record.day) ~= "number" or record.day ~= record.day then
		record.day = 0
	end
	if typeof(record.used) ~= "number" or record.used ~= record.used or record.used < 0 then
		record.used = 0
	end
	record.used = math.floor(record.used)
	return record
end

-- Starts the count over when the day turned. True if it did.
function Spin.refresh(record: Record, now: number): boolean
	local today = Missions.day(now)
	if record.day == today then
		return false
	end
	record.day = today
	record.used = 0
	return true
end

-- Spins earned today after this many seconds of play.
function Spin.earned(playSeconds: number): number
	local count = Config.FreePerDay
	for _, minutes in Config.PlayMinutes do
		if playSeconds >= minutes * 60 then
			count += 1
		end
	end
	return count
end

-- Spins waiting right now.
function Spin.left(record: Record, playSeconds: number): number
	return math.max(0, Spin.earned(playSeconds) - record.used)
end

-- Seconds of play until the next spin is earned, or nil when every one has been earned today.
function Spin.nextIn(playSeconds: number): number?
	for _, minutes in Config.PlayMinutes do
		local left = minutes * 60 - playSeconds
		if left > 0 then
			return left
		end
	end
	return nil
end

-- Index of the prize for a roll in [0, 1).
function Spin.pick(roll: number): number
	local total = 0
	for _, prize in Config.Prizes do
		total += prize.weight
	end
	local at = math.clamp(roll, 0, 0.999999) * total
	for index, prize in Config.Prizes do
		at -= prize.weight
		if at < 0 then
			return index
		end
	end
	return #Config.Prizes
end

-- What prize `index` gives a player with this base and this many wings.
function Spin.reward(index: number, base: number, wingsOwned: number): Reward?
	local prize = Config.Prizes[index]
	if not prize then
		return nil
	end
	local cash = 0
	if prize.share then
		cash = math.max(prize.floor or 0, math.floor(math.max(0, base) * prize.share))
	end
	local itemId = prize.item
	if prize.pick == "Bell" then
		itemId = if wingsOwned >= PlaytimeConfig.SilverBellWings then "SilverBell" else "BaitBell"
	elseif prize.pick == "Cake" then
		local cake = Playtime.cake(base)
		itemId = if cake then cake.id else nil
	end
	local item = if itemId then items[itemId] else nil
	return {
		cash = cash,
		item = if item then item.id else nil,
		itemName = if item then item.name else nil,
		kind = if item then item.kind :: string else nil,
		count = if item then prize.count or 1 else 0,
	}
end

-- Uses a spin. False if none is left.
function Spin.use(record: Record, playSeconds: number): boolean
	if Spin.left(record, playSeconds) <= 0 then
		return false
	end
	record.used += 1
	return true
end

return Spin
