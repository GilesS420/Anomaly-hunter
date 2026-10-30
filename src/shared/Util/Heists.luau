--!strict
-- Monster stealing rules (Config/Heists): what a monster costs to steal, who may rob whom, the
-- daily caps, and what a stolen monster loses on the way. Pure functions, so tests/run.luau
-- can check them; server/Services/HeistService does the stealing. Every player's save keeps a
-- Record in data.heist.

local Config = require("../Config/Heists")
local Trading = require("./Trading")
local Value = require("./Value")

local Heists = {}

export type Record = {
	playSeconds: number, -- time played, for the new-player shield
	day: number, -- the day (Util/Missions.day) `lost` and `robbedBy` are for
	lost: number, -- monsters lost to stealing that day
	robbedBy: { number }, -- UserIds of the thieves that robbed this player that day
	stolen: number, -- monsters stolen in all
	lostTotal: number, -- monsters lost in all
}

function Heists.empty(): Record
	return { playSeconds = 0, day = -1, lost = 0, robbedBy = {}, stolen = 0, lostTotal = 0 }
end

-- Mends a record from a save (missing or broken parts back to empty) and returns it.
function Heists.repair(record: any): Record
	local fresh = Heists.empty()
	if typeof(record) ~= "table" then
		return fresh
	end
	for key, value in fresh :: any do
		if typeof(record[key]) ~= typeof(value) or record[key] ~= record[key] then
			record[key] = value
		end
	end
	return record :: Record
end

-- The Steal product (Config/Robux) for a monster worth `value`; a hearted one costs a step more.
function Heists.productFor(value: number, hearted: boolean): string
	local index = #Config.Steps - 1 -- the last step is only for hearted ones
	for i, step in Config.Steps do
		if value <= step.maxValue then
			index = i
			break
		end
	end
	if hearted then
		index += 1
	end
	return Config.Steps[math.min(index, #Config.Steps)].product
end

-- True if `key` is one of the Steal products.
function Heists.isProduct(key: string): boolean
	for _, step in Config.Steps do
		if step.product == key then
			return true
		end
	end
	return false
end

-- Starts a new day's count if `day` isn't the one the record is for.
function Heists.rollDay(record: Record, day: number)
	if record.day ~= day then
		record.day = day
		record.lost = 0
		record.robbedBy = {}
	end
end

-- How often `thiefId` robbed this player on the record's day.
function Heists.timesRobbedBy(record: Record, thiefId: number): number
	local count = 0
	for _, id in record.robbedBy do
		if id == thiefId then
			count += 1
		end
	end
	return count
end

-- Notes a monster this player lost to `thiefId` (call rollDay first).
function Heists.noteLoss(record: Record, thiefId: number)
	record.lost += 1
	record.lostTotal += 1
	table.insert(record.robbedBy, thiefId)
end

-- Whether `thief` may steal from `owner` right now, as the server sees them. The owner's
-- record must be for today (rollDay).
export type Owner = {
	tutorial: boolean,
	playSeconds: number,
	shield: boolean, -- the new-player shield counts (off in Studio, Config.ShieldInStudio)
	record: Record,
}
export type Thief = {
	userId: number,
	tutorial: boolean,
	hasRoom: boolean, -- their mansion or Storage has room for one more
}

-- Why the steal can't happen, or nil if it can. See Heists.message for what each means.
function Heists.blocked(owner: Owner, thief: Thief): string?
	if thief.tutorial then
		return "ThiefTutorial"
	elseif owner.tutorial or (owner.shield and owner.playSeconds < Config.NewPlayerSeconds) then
		return "NewPlayer"
	elseif owner.record.lost >= Config.MaxLossesPerDay then
		return "LostEnough"
	elseif Heists.timesRobbedBy(owner.record, thief.userId) >= Config.SameThiefPerDay then
		return "SameThief"
	elseif not thief.hasRoom then
		return "NoRoom"
	end
	return nil
end

-- What to tell the thief when Heists.blocked says no. `name` is the owner's display name.
function Heists.message(reason: string, name: string): string
	if reason == "ThiefTutorial" then
		return "Finish the tutorial first!"
	elseif reason == "NewPlayer" then
		return `{name} is new to the game, so their monsters are protected for now.`
	elseif reason == "LostEnough" then
		return `{name} was robbed enough today. Try again tomorrow!`
	elseif reason == "SameThief" then
		return `You already stole from {name} today. Try someone else!`
	elseif reason == "NoRoom" then
		return "Your mansion and Storage are full! Make room first."
	end
	return "You can't steal that right now."
end

-- What a stolen monster loses when it gets a new owner: its Familiarity (so stealing never
-- beats raising your own), its name tag and its heart.
function Heists.handOver(caught: Value.CaughtMonster, now: number)
	Trading.handOver(caught)
	caught.familiarity = 0
	caught.grownAt = now
end

return Heists
