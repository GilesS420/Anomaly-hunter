--!strict
-- Daily mission rules (Config/Missions). The save keeps the day's missions in data.missions
-- (a State, below). Pure functions so they can be tested outside Roblox; the server deals
-- and counts them (MissionService), the client draws them (MissionController).

local Config = require("../Config/Missions")
local Monsters = require("../Config/Monsters")
local Rarities = require("../Config/Rarities")
local Shop = require("../Config/Shop")
local Wings = require("../Config/Wings")
local Zones = require("../Config/Zones")
local Format = require("./Format")

local Missions = {}

export type Saved = {
	id: string, -- Config/Missions.Pool id
	zone: string?, -- zone id, for zone missions
	target: number,
	progress: number,
	seen: { string }?, -- Species and ZoneSet: the monsters caught so far
	reward: number,
	claimed: boolean?,
}
export type State = {
	day: number, -- Missions.day of the deal (0: never dealt)
	worth: number, -- the worth the rewards were worked out from
	bonus: number, -- streak bonus on today's rewards (0.3 = +30%)
	streak: number, -- days in a row, up to lastDay, with a claimed mission
	lastDay: number, -- the last day a mission was claimed
	rerolls: number, -- left today
	chest: number, -- the bonus chest's cash
	chestClaimed: boolean?,
	list: { Saved },
}
-- Something the player did, for Missions.record.
export type Done = {
	monsterId: string?,
	zone: string?, -- zone id of a catch ("" or nil for the main area)
	variant: string?,
	lucky: boolean?,
	amount: number?, -- Sell: money earned; Effect: effects picked up (default 1)
	won: boolean?,
}

local DaySeconds = 86_400

local byId: { [string]: Config.Mission } = {}
for _, mission in Config.Pool do
	assert(byId[mission.id] == nil, "duplicate mission " .. mission.id)
	byId[mission.id] = mission
end
local tiersById: { [string]: Config.Tier } = {}
for _, tier in Config.Tiers do
	tiersById[tier.id] = tier
end
local zoneNames: { [string]: string } = {}
local zoneIndex: { [string]: number } = {}
for _, zone in Zones.List do
	zoneNames[zone.id] = zone.name
	zoneIndex[zone.id] = zone.index
end

function Missions.def(id: string): Config.Mission?
	return byId[id]
end

function Missions.tier(id: string): Config.Tier?
	return tiersById[id]
end

-- Today's number: days since 1970 (UTC), turning over Config.ResetOffset after midnight.
function Missions.day(now: number): number
	return math.floor((now - Config.ResetOffset) / DaySeconds)
end

-- Seconds until the next day's missions.
function Missions.secondsLeft(now: number): number
	return (Missions.day(now) + 1) * DaySeconds + Config.ResetOffset - now
end

-- Rounds down to two significant digits, so targets and rewards read cleanly ($1.2M, not
-- $1,234,567 shown as $1.2M).
function Missions.round(amount: number): number
	if amount < 100 then
		return math.floor(amount)
	end
	local step = 10 ^ (math.floor(math.log10(amount)) - 1)
	return math.floor(amount / step) * step
end

-- One reward: the tier's share of worth (at least its floor), plus the streak bonus.
function Missions.reward(share: number, floor: number, worth: number, bonus: number): number
	return Missions.round(math.max(floor, worth * share) * (1 + bonus))
end

function Missions.bonusFor(streak: number): number
	return math.min(Config.StreakMax, streak * Config.StreakStep)
end

-- The launch zones the player can enter, in order.
function Missions.openZones(wingsOwned: number): { string }
	local orders: { [string]: number } = {}
	for _, wing in Wings.List do
		orders[wing.id] = wing.order
	end
	local open = {}
	for _, zone in Zones.List do
		if zone.launch and (orders[zone.wing] or math.huge) <= wingsOwned then
			table.insert(open, zone.id)
		end
	end
	return open
end

-- The monsters a ZoneSet mission asks for: every one of the zone up to maxRarity.
function Missions.zoneTargets(zoneId: string, maxRarity: string?): { string }
	local index = zoneIndex[zoneId]
	local top = maxRarity and Rarities[maxRarity] and Rarities[maxRarity].order or math.huge
	local list = {}
	for id, monster in Monsters do
		if monster.zone == index and Rarities[monster.rarity].order <= top then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

-- What it says in the window: "Catch 4 different monsters in Murky Bayou".
function Missions.text(saved: Saved): string
	local mission = byId[saved.id]
	if not mission then
		return "Mission"
	end
	local text = string.gsub(mission.text, "{n}", tostring(saved.target))
	text = string.gsub(text, "{money}", Format.money(saved.target))
	text = string.gsub(text, "{zone}", if saved.zone then zoneNames[saved.zone] or saved.zone else "")
	return text
end

function Missions.isDone(saved: Saved): boolean
	return saved.progress >= saved.target
end

-- Two missions on one day never count the same thing, except catches (there are many kinds).
local function clashes(mission: Config.Mission, others: { Saved }): boolean
	for _, other in others do
		local def = byId[other.id]
		if def and (def.id == mission.id or (def.kind == mission.kind and mission.kind ~= "Catch")) then
			return true
		end
	end
	return false
end

-- A new mission for the tier, or nil when none fits.
local function pick(
	tierId: string,
	others: { Saved },
	worth: number,
	bonus: number,
	zones: { string },
	random: Random
): Saved?
	local choices = {}
	for _, mission in Config.Pool do
		if mission.tier == tierId and not (mission.zone and #zones == 0) and not clashes(mission, others) then
			table.insert(choices, mission)
		end
	end
	if #choices == 0 then
		return nil
	end
	local mission = choices[random:NextInteger(1, #choices)]
	local tier = tiersById[tierId]
	local zone = if mission.zone then zones[random:NextInteger(1, #zones)] else nil
	local target = mission.count or 1
	if mission.moneyShare then
		target = Missions.round(math.max(mission.moneyFloor or 0, worth * mission.moneyShare))
	elseif mission.kind == "ZoneSet" and zone then
		target = #Missions.zoneTargets(zone, mission.maxRarity)
	end
	return {
		id = mission.id,
		zone = zone,
		target = target,
		progress = 0,
		seen = if mission.kind == "Species" or mission.kind == "ZoneSet" then {} else nil,
		reward = Missions.reward(tier.share, tier.floor, worth, bonus),
	}
end

-- A fresh State with nothing dealt yet (a new save).
function Missions.empty(): State
	return { day = 0, worth = 0, bonus = 0, streak = 0, lastDay = 0, rerolls = 0, chest = 0, list = {} }
end

-- Whether `state` (anything from a save) still holds today's missions.
function Missions.isCurrent(state: any, now: number): boolean
	return typeof(state) == "table" and state.day == Missions.day(now) and typeof(state.list) == "table"
end

-- Today's missions for a player worth `worth`, keeping the streak from `old` (the last
-- State, or anything for none). A streak survives only if a mission was claimed yesterday
-- (or today, when dealing again the same day).
function Missions.deal(old: any, now: number, worth: number, wingsOwned: number, random: Random): State
	local today = Missions.day(now)
	local streak = 0
	local lastDay = 0
	if typeof(old) == "table" and typeof(old.streak) == "number" and typeof(old.lastDay) == "number" then
		lastDay = old.lastDay
		streak = if lastDay >= today - 1 then old.streak else 0
	end
	-- Today's bonus counts the days before today only.
	local bonus = Missions.bonusFor(if lastDay == today then math.max(0, streak - 1) else streak)
	local zones = Missions.openZones(wingsOwned)
	local list: { Saved } = {}
	for _, tier in Config.Tiers do
		local saved = pick(tier.id, list, worth, bonus, zones, random)
		if saved then
			table.insert(list, saved)
		end
	end
	return {
		day = today,
		worth = worth,
		bonus = bonus,
		streak = streak,
		lastDay = lastDay,
		rerolls = Config.Rerolls,
		chest = Missions.reward(Config.ChestShare, Config.ChestFloor, worth, bonus),
		list = list,
	}
end

-- Swaps mission `index` for another of its tier. False when it can't be (done already, no
-- rerolls left, or nothing else fits).
function Missions.reroll(state: State, index: number, wingsOwned: number, random: Random): boolean
	local saved = state.list[index]
	if not saved or state.rerolls <= 0 or Missions.isDone(saved) then
		return false
	end
	local def = byId[saved.id]
	if not def then
		return false
	end
	local others = table.clone(state.list) -- the old one stays in, so it isn't picked again
	local new = pick(def.tier, others, state.worth, state.bonus, Missions.openZones(wingsOwned), random)
	if not new then
		return false
	end
	state.list[index] = new
	state.rerolls -= 1
	return true
end

-- Whether a catch of `done.monsterId` counts for this Catch mission.
local function catchCounts(mission: Config.Mission, saved: Saved, done: Done): boolean
	local monster = done.monsterId and Monsters[done.monsterId]
	if not monster then
		return false
	end
	local inHub = done.zone == nil or done.zone == ""
	if mission.hub and not inHub then
		return false
	end
	if saved.zone and done.zone ~= saved.zone then
		return false
	end
	if mission.minRarity and Rarities[monster.rarity].order < Rarities[mission.minRarity].order then
		return false
	end
	if mission.variant and not done.variant then
		return false
	end
	if mission.lucky and not done.lucky then
		return false
	end
	return true
end

-- Counts something the player did towards today's missions. Returns the missions it just
-- finished.
function Missions.record(state: State, kind: string, done: Done): { Saved }
	local finished = {}
	for _, saved in state.list do
		local mission = byId[saved.id]
		if not mission or saved.claimed or Missions.isDone(saved) then
			continue
		end
		local before = saved.progress
		if mission.kind == "Catch" and kind == "Catch" then
			if catchCounts(mission, saved, done) then
				saved.progress += 1
			end
		elseif (mission.kind == "Species" or mission.kind == "ZoneSet") and kind == "Catch" then
			local id = done.monsterId
			local seen = saved.seen or {}
			saved.seen = seen
			local wanted = id ~= nil and done.zone == saved.zone and not table.find(seen, id)
			if wanted and mission.kind == "ZoneSet" then
				wanted = table.find(Missions.zoneTargets(saved.zone or "", mission.maxRarity), id :: string)
					~= nil
			end
			if wanted then
				table.insert(seen, id :: string)
				saved.progress = #seen
			end
		elseif mission.kind == kind then
			if mission.kind == "Sell" or mission.kind == "Effect" then
				saved.progress += math.max(0, done.amount or 1)
			elseif not mission.won or done.won then
				saved.progress += 1
			end
		end
		if saved.progress ~= before and Missions.isDone(saved) then
			saved.progress = saved.target
			table.insert(finished, saved)
		end
	end
	return finished
end

-- Notes a claim for the streak.
local function noteClaim(state: State, now: number)
	local today = Missions.day(now)
	if state.lastDay == today then
		return
	end
	state.streak = if state.lastDay == today - 1 then state.streak + 1 else 1
	state.lastDay = today
end

-- Claims mission `index`: returns its reward, or nil if it isn't done or was claimed.
function Missions.claim(state: State, index: number, now: number): number?
	local saved = state.list[index]
	if not saved or saved.claimed or not Missions.isDone(saved) then
		return nil
	end
	saved.claimed = true
	noteClaim(state, now)
	return saved.reward
end

-- Whether every mission is claimed and the chest is still shut.
function Missions.chestReady(state: State): boolean
	if state.chestClaimed or #state.list == 0 then
		return false
	end
	for _, saved in state.list do
		if not saved.claimed then
			return false
		end
	end
	return true
end

-- Opens the chest: returns its cash, or nil if it isn't ready.
function Missions.claimChest(state: State): number?
	if not Missions.chestReady(state) then
		return nil
	end
	state.chestClaimed = true
	return state.chest
end

-- The cakes the chest may hold: every Bakery cake (not an event treat) costing at most
-- ChestCakeTimesCash times its cash, or the cheapest one if none does.
function Missions.chestCakes(cash: number): { Shop.Item }
	local choices: { Shop.Item } = {}
	local cheapest: Shop.Item? = nil
	for _, item in Shop.Bakery do
		if item.event then
			continue
		end
		if item.price <= cash * Config.ChestCakeTimesCash then
			table.insert(choices, item)
		end
		if not cheapest or item.price < cheapest.price then
			cheapest = item
		end
	end
	if #choices == 0 and cheapest then
		table.insert(choices, cheapest)
	end
	return choices
end

-- How many rewards are waiting to be claimed (the red dot on the Missions button).
function Missions.ready(state: State): number
	local count = if Missions.chestReady(state) then 1 else 0
	for _, saved in state.list do
		if not saved.claimed and Missions.isDone(saved) then
			count += 1
		end
	end
	return count
end

return Missions
