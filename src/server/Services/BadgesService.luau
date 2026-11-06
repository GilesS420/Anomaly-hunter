--!strict
-- Awards the Roblox badges in Config/Badges (Giles 2026-11-06). Every CheckSeconds it looks at
-- each loaded player (Util/Badges says what earns what) and awards what they've earned. Roblox
-- shows its own "You earned a badge" pop-up, so there is no toast of ours.
-- data.badges remembers what was given, so a badge is only asked for once. A badge whose id
-- is still 0 (not made in Creator Hub yet) is skipped, and given later once the id is filled in.
-- Studio doesn't award badges: it prints "[Badges] would award ..." once per badge instead.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Badges)
local Badges = require(ReplicatedStorage.Shared.Util.Badges)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local DataService = require(script.Parent.DataService)

local BadgesService = {}

local studio = RunService:IsStudio()
local busy: { [Player]: boolean } = {} -- an award is being asked for (it waits on Roblox)
local printed: { [string]: boolean } = {} -- Studio: badges already printed this play test

-- What the mansion's monsters sell for, as on the worth sign out front.
local function mansionWorth(data: DataService.Data): number
	local total = 0
	for _, caught in data.monsters do
		local ok, value = pcall(Value.sellValue, caught, data.wingsOwned)
		if ok and typeof(value) == "number" and value == value then
			total += value
		end
	end
	return total
end

local function award(player: Player, data: DataService.Data, badge: Config.Badge)
	if studio then
		local key = `{player.UserId}:{badge.key}`
		if not printed[key] then
			printed[key] = true
			print(`[Badges] would award {player.Name} "{badge.name}" ({badge.id})`)
		end
		return
	end
	local ok, result = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badge.id)
	if not ok or not result then
		-- false also means they already had it (from another server's try that wasn't saved).
		local hasOk, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badge.id)
		if not (hasOk and has) then
			if not ok then
				warn(`BadgesService: awarding "{badge.name}" to {player.Name} failed: {result}`)
			end
			return -- try again on the next look
		end
	end
	if DataService.get(player) == data then
		data.badges[badge.key] = true
	end
end

local function check(player: Player)
	local data = DataService.get(player)
	if not data or busy[player] then
		return
	end
	if typeof(data.badges) ~= "table" then
		data.badges = {}
	end
	local live: Badges.Live = {
		worth = mansionWorth(data),
		event = workspace:GetAttribute("WatcherEvent"),
		friendsHere = tonumber(player:GetAttribute("FriendsHere")) or 0,
	}
	local list = Badges.toAward(data, live)
	if #list == 0 then
		return
	end
	busy[player] = true
	task.spawn(function()
		for _, badge in list do
			if player.Parent ~= Players then
				break
			end
			award(player, data, badge)
		end
		busy[player] = nil
	end)
end

function BadgesService.start()
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.CheckSeconds)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(check, player)
				if not ok then
					warn(`BadgesService: checking {player.Name} failed: {err}`)
				end
			end
		end
	end)
end

return BadgesService
