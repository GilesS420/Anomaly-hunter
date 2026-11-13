--!strict
-- Lucky Spin rules (numbers in Config/Spin). Pure so they can be tested outside Roblox;
-- server/Services/SpinService keeps the record in the save (data.spin).

local Config = require("../Config/Spin")
local Hunt = require("./Hunt")
local Monsters = require("../Config/Monsters")
local Missions = require("./Missions")
local Playtime = require("./Playtime")
local PlaytimeConfig = require("../Config/Playtime")
local Shop = require("../Config/Shop")

local Spin = {}

export type Record = {
	day: number, -- Util/Missions.day the count below is for
	used: number, -- free spins used that day
	bought: number, -- spins bought with Robux and not used yet (they keep from day to day)
}
-- `monster` is the rarity of a monster prize; which monster is picked when it's paid out
-- (Spin.monsterPool), so the slice just says "Legendary".
export type Reward = {
	cash: number,
	item: string?,
	itemName: string?,
	kind: string?,
	count: number,
	monster: string?,
}

local items: { [string]: Shop.Item } = {}
for _, list in { Shop.Workshop, Shop.Bakery } do
	for _, item in list do
		items[item.id] = item
	end
end

function Spin.empty(): Record
	return { day = 0, used = 0, bought = 0 }
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
	if typeof(record.bought) ~= "number" or record.bought ~= record.bought or record.bought < 0 then
		record.bought = 0
	end
	record.bought = math.floor(math.min(record.bought, 1_000_000))
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

-- Free spins waiting right now.
function Spin.freeLeft(record: Record, playSeconds: number): number
	return math.max(0, Spin.earned(playSeconds) - record.used)
end

-- Spins waiting right now: the free ones and the bought ones.
function Spin.left(record: Record, playSeconds: number): number
	return Spin.freeLeft(record, playSeconds) + record.bought
end

-- Adds `count` bought spins.
function Spin.buy(record: Record, count: number)
	record.bought += math.max(0, math.floor(count))
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

-- The monsters a `rarity` prize can be for a player with this many wings: one per zone they
-- have opened, with a weight (a newer zone counts more: zone 1 counts 1, zone 4 counts 4, so
-- a late player mostly gets one that's still worth having). Sorted by id so it's the same
-- every time.
function Spin.monsterPool(rarity: string, wingsOwned: number): { { id: string, weight: number } }
	local pool = {}
	for id, monster in Monsters do
		local zone = monster.zone
		if monster.rarity == rarity and zone and Hunt.isZoneUnlocked(zone, wingsOwned) then
			table.insert(pool, { id = id, weight = zone })
		end
	end
	table.sort(pool, function(a, b)
		return a.id < b.id
	end)
	return pool
end

-- The monster a `rarity` slice shows: the one from the newest zone they've opened (the most
-- likely pick), or nil if none is open.
function Spin.showMonster(rarity: string, wingsOwned: number): string?
	local best: { id: string, weight: number }? = nil
	for _, entry in Spin.monsterPool(rarity, wingsOwned) do
		if not best or entry.weight > best.weight then
			best = entry
		end
	end
	return if best then best.id else nil
end

-- The monster a roll in [0, 1) picks from the pool, or nil if the pool is empty.
function Spin.pickMonster(rarity: string, wingsOwned: number, roll: number): string?
	local pool = Spin.monsterPool(rarity, wingsOwned)
	local total = 0
	for _, entry in pool do
		total += entry.weight
	end
	local at = math.clamp(roll, 0, 0.999999) * total
	for _, entry in pool do
		at -= entry.weight
		if at < 0 then
			return entry.id
		end
	end
	return if #pool > 0 then pool[#pool].id else nil
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
	if prize.monster then
		return { cash = 0, kind = "Monster", count = 1, monster = prize.monster }
	end
	return {
		cash = cash,
		item = if item then item.id else nil,
		itemName = if item then item.name else nil,
		kind = if item then item.kind :: string else nil,
		count = if item then prize.count or 1 else 0,
	}
end

-- Uses a spin, a free one first, then a bought one. False if none is left.
function Spin.use(record: Record, playSeconds: number): boolean
	if Spin.freeLeft(record, playSeconds) > 0 then
		record.used += 1
		return true
	end
	if record.bought > 0 then
		record.bought -= 1
		return true
	end
	return false
end

-- Odds of slice `index` in percent (30, 2.5).
function Spin.odds(index: number): number
	local total = 0
	for _, prize in Config.Prizes do
		total += prize.weight
	end
	local prize = Config.Prizes[index]
	return if prize and total > 0 then prize.weight / total * 100 else 0
end

return Spin
