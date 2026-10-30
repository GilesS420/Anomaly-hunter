--!strict
-- Monster Heist rules (Config/Heists): who may rob whom, the daily caps, and what a stolen
-- monster loses on the way. Pure functions, so tests/run.luau can check them;
-- server/Services/HeistService runs the heists. Every player's save keeps a Record in
-- data.heist.

local Config = require("../Config/Heists")
local Trading = require("./Trading")
local Value = require("./Value")

local Heists = {}

export type Record = {
	charges: number, -- Heist Charges bought and not used yet
	playSeconds: number, -- time played, for the new-player shield
	day: number, -- the day (Util/Missions.day) `lost` and `robbedBy` are for
	lost: number, -- monsters lost to heists that day
	robbedBy: { number }, -- UserIds of the thieves that robbed this player that day
	stolen: number, -- monsters stolen in all
	lostTotal: number, -- monsters lost in all
}

function Heists.empty(): Record
	return { charges = 0, playSeconds = 0, day = -1, lost = 0, robbedBy = {}, stolen = 0, lostTotal = 0 }
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
	record.charges = math.max(0, math.floor(record.charges))
	return record :: Record
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

-- Whether a heist can start, as the server sees both players. `owner` is the mansion's
-- owner, `thief` the one at the door. The owner's daily numbers must be for today (rollDay).
export type Owner = {
	tutorial: boolean,
	playSeconds: number,
	shield: boolean, -- the new-player shield counts (off in Studio, Config.ShieldInStudio)
	worth: number, -- what the monsters roaming their mansion sell for together
	stealable: number, -- roaming monsters that aren't hearted
	record: Record,
	beingRobbed: boolean, -- someone else's heist is already on this mansion
}
export type Thief = {
	userId: number,
	tutorial: boolean,
	inHeist: boolean,
	lockedUntil: number, -- server time a slap's steal lock ends (0: none)
	charges: number,
	hasRoom: boolean, -- their mansion or Storage has room for one more
}

-- Why the heist can't start, or nil if it can. See Heists.message for what each means.
function Heists.blocked(owner: Owner, thief: Thief, now: number): string?
	if thief.tutorial then
		return "ThiefTutorial"
	elseif thief.inHeist then
		return "AlreadyStealing"
	elseif now < thief.lockedUntil then
		return "Locked"
	elseif owner.tutorial or (owner.shield and owner.playSeconds < Config.NewPlayerSeconds) then
		return "NewPlayer"
	elseif owner.worth < Config.MinMansionWorth then
		return "TooPoor"
	elseif owner.beingRobbed then
		return "Busy"
	elseif owner.record.lost >= Config.MaxLossesPerDay then
		return "LostEnough"
	elseif Heists.timesRobbedBy(owner.record, thief.userId) >= Config.SameThiefPerDay then
		return "SameThief"
	elseif owner.stealable <= 0 then
		return "AllHearted"
	elseif not thief.hasRoom then
		return "NoRoom"
	elseif thief.charges <= 0 then
		return "NoCharge"
	end
	return nil
end

-- What to tell the thief when Heists.blocked says no. `name` is the owner's display name;
-- `seconds` how long a steal lock has left.
function Heists.message(reason: string, name: string, seconds: number?): string
	if reason == "ThiefTutorial" then
		return "Finish the tutorial first!"
	elseif reason == "AlreadyStealing" then
		return "You're already on a heist!"
	elseif reason == "Locked" then
		return `You were slapped! You can't steal for {math.ceil(seconds or 0)} more seconds.`
	elseif reason == "NewPlayer" then
		return `{name} is new to the game, so their mansion is protected for now.`
	elseif reason == "TooPoor" then
		return `{name}'s mansion isn't worth robbing yet.`
	elseif reason == "Busy" then
		return `Someone is already robbing {name}!`
	elseif reason == "LostEnough" then
		return `{name} was robbed enough today. Try again tomorrow!`
	elseif reason == "SameThief" then
		return `You already robbed {name} today. Try someone else!`
	elseif reason == "AllHearted" then
		return `Every monster in {name}'s mansion is hearted, so none can be stolen.`
	elseif reason == "NoRoom" then
		return "Your mansion and Storage are full! Make room before a heist."
	elseif reason == "NoCharge" then
		return "You need a Heist Charge. Get one in the Store!"
	end
	return "You can't rob this mansion right now."
end

-- True if a heist can take this monster (hearted ones are safe).
function Heists.canTake(caught: Value.CaughtMonster): boolean
	return not caught.locked
end

-- How many monsters in these lists are hearted.
function Heists.hearts(lists: { { Value.CaughtMonster } }): number
	local count = 0
	for _, list in lists do
		for _, caught in list do
			if caught.locked then
				count += 1
			end
		end
	end
	return count
end

-- True if one more heart is allowed when `count` monsters are hearted already.
function Heists.canHeart(count: number): boolean
	return Config.MaxHearts == nil or count < Config.MaxHearts
end

-- What a stolen monster loses when it gets a new owner: its Familiarity (so stealing never
-- beats raising your own), its name tag and its heart.
function Heists.handOver(caught: Value.CaughtMonster, now: number)
	Trading.handOver(caught)
	caught.familiarity = 0
	caught.grownAt = now
end

-- True if moving (dx, dz) studs in `seconds` is too fast to be walking: a teleport.
function Heists.teleported(dx: number, dz: number, seconds: number): boolean
	local distance = math.sqrt(dx * dx + dz * dz)
	return distance > Config.MaxCarrySpeed * math.max(seconds, 0) + 15
end

return Heists
