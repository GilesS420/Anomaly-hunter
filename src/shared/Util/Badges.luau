--!strict
-- What earns each badge in Config/Badges. Pure so it can be tested outside Roblox; the server
-- (BadgesService) looks every few seconds and awards the ones earned and not yet given.
--
-- Most are read straight from the save:
--   FirstCatch, Legendary, Mythic, Rainbow  the Codex (data.codex.monsters), which notes every
--             monster the player has had at home, so a gift or trade counts too
--   ReadyToHunt    data.tutorial == "Done" (older saves are marked Done as well)
--   BackAgain, OneWeek  data.analytics.days, different UTC days played (AnalyticsService)
--   MissionStreak  data.missions.streak
--   NewWing        data.wingsOwned (the Foyer is wing 1, the Library wing 2)
-- and a few from the server right now (Live):
--   Millionaire    what the mansion's monsters sell for (the worth sign out front)
--   WatcherAwakens the event going in the hub (Workspace attribute WatcherEvent)
--   HuntingParty   Roblox friends in the server (player attribute FriendsHere)

local Config = require("../Config/Badges")
local Monsters = require("../Config/Monsters")

local Badges = {}

export type Live = {
	worth: number, -- the mansion's monsters, as on the worth sign
	event: string?, -- the Watcher event going now
	friendsHere: number,
}

local function hasMonster(codex: { [string]: any }, test: (monsterId: string, variants: { [string]: any }) -> boolean): boolean
	local monsters = codex.monsters
	if typeof(monsters) ~= "table" then
		return false
	end
	for monsterId, variants in monsters do
		if typeof(variants) == "table" and test(monsterId, variants) then
			return true
		end
	end
	return false
end

local function ofRarity(rarity: string): (string, { [string]: any }) -> boolean
	return function(monsterId)
		local monster = Monsters[monsterId]
		return monster ~= nil and monster.rarity == rarity
	end
end

-- Whether the save (and what's going on now) has earned the badge with this key.
function Badges.earned(key: string, data: { [string]: any }, live: Live): boolean
	local codex = if typeof(data.codex) == "table" then data.codex else {}
	local analytics = if typeof(data.analytics) == "table" then data.analytics else {}
	local missions = if typeof(data.missions) == "table" then data.missions else {}
	if key == "Welcome" then
		return true
	elseif key == "FirstCatch" then
		return hasMonster(codex, function()
			return true
		end)
	elseif key == "ReadyToHunt" then
		return data.tutorial == "Done"
	elseif key == "BackAgain" then
		return (tonumber(analytics.days) or 0) >= 2
	elseif key == "OneWeek" then
		return (tonumber(analytics.days) or 0) >= Config.WeekDays
	elseif key == "MissionStreak" then
		return (tonumber(missions.streak) or 0) >= Config.StreakDays
	elseif key == "NewWing" then
		return (tonumber(data.wingsOwned) or 0) >= 2
	elseif key == "Millionaire" then
		return live.worth >= Config.MillionaireWorth
	elseif key == "Legendary" then
		return hasMonster(codex, ofRarity("Legendary"))
	elseif key == "Mythic" then
		return hasMonster(codex, ofRarity("Mythic"))
	elseif key == "Rainbow" then
		return hasMonster(codex, function(_, variants)
			return variants.Rainbow == true
		end)
	elseif key == "WatcherAwakens" then
		return live.event == Config.WatcherEvent
	elseif key == "HuntingParty" then
		return live.friendsHere > 0
	end
	return false
end

-- The badges to award now: earned, made in Creator Hub (id set) and not already given.
function Badges.toAward(data: { [string]: any }, live: Live): { Config.Badge }
	local given = if typeof(data.badges) == "table" then data.badges else {}
	local list = {}
	for _, badge in Config.List do
		if badge.id > 0 and not given[badge.key] and Badges.earned(badge.key, data, live) then
			table.insert(list, badge)
		end
	end
	return list
end

return Badges
