--!strict
-- The first half hour after the tutorial (Giles 2026-11-05: new players left after about 5
-- minutes), plus the "Next goal" bar for everyone.
--
-- Rookie hour (numbers in Config/Rookie): a save that starts the tutorial gets Minutes of
-- online play after it with a Collector bonus (Perks.sellBonuses reads the player attribute
-- RookieSeconds), and on their LuckyHunt-th trip into a zone a monster of LuckyRarity waits
-- for them, reserved like a Bait Bell's. Older saves are marked done on their first load, so
-- existing players never get it. Saved in data.rookie.
--
-- Next goal (Util/Goals): every few seconds the player attributes GoalName and GoalPrice say
-- what to save up for next; the client draws the bar against their money (HuntController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Goals = require(ReplicatedStorage.Shared.Util.Goals)
local Hunt = require(ReplicatedStorage.Shared.Util.Hunt)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Rookie = require(ReplicatedStorage.Shared.Config.Rookie)
local Tutorial = require(ReplicatedStorage.Shared.Util.Tutorial)
local DataService = require(script.Parent.DataService)
local SpawnService = require(script.Parent.SpawnService)
local Notify = require(script.Parent.Parent.Notify)

local RookieService = {}

local TickSeconds = 5
local LuckyDelay = 1.5 -- seconds after arriving in the zone, so they've landed

-- The zone's monster of the lucky rarity (the first by id, so it's always the same one).
local function luckyMonster(zoneIndex: number): string?
	local found: string? = nil
	for id, monster in Monsters do
		if monster.zone == zoneIndex and monster.rarity == Rookie.LuckyRarity then
			if not found or id < found then
				found = id
			end
		end
	end
	return found
end

-- Older saves: never a rookie. A save that's new or still in the tutorial: a rookie.
local function decide(data: DataService.Data)
	local record = data.rookie
	if record.decided then
		return
	end
	record.decided = true
	local fresh = data.tutorial ~= "Done"
		and (
			data.tutorial ~= "New"
			or Tutorial.isFresh(data.money, #data.monsters, #data.storage, data.wingsOwned, 0)
		)
	record.secondsLeft = if fresh then Rookie.Minutes * 60 else 0
	record.lucky = not fresh
end

local function rookieAttribute(player: Player, data: DataService.Data)
	local left = data.rookie.secondsLeft
	player:SetAttribute("RookieSeconds", if data.tutorial == "Done" and left > 0 then math.ceil(left) else nil)
end

local function goalAttributes(player: Player, data: DataService.Data)
	local goal = if data.tutorial == "Done" then Goals.next(data.inventory, data.wingsOwned) else nil
	player:SetAttribute("GoalName", if goal then goal.name else nil)
	player:SetAttribute("GoalPrice", if goal then goal.price else nil)
end

local function tick(player: Player, data: DataService.Data, seconds: number)
	local record = data.rookie
	if data.tutorial == "Done" and record.secondsLeft > 0 then
		record.secondsLeft = math.max(record.secondsLeft - seconds, 0)
		if record.secondsLeft == 0 then
			Notify.toast(player, "Your rookie hour is over. Thanks for hunting, keep it up!")
		end
	end
	rookieAttribute(player, data)
	goalAttributes(player, data)
end

-- A trip into a zone: count it, and on the lucky one bring the waiting monster.
local function arrived(player: Player)
	local data = DataService.get(player)
	local zone = Hunt.zoneById(player:GetAttribute("Zone"))
	if not data or not zone or data.tutorial ~= "Done" or data.rookie.lucky then
		return
	end
	local record = data.rookie
	record.hunts += 1
	if record.hunts < Rookie.LuckyHunt then
		return
	end
	local monsterId = luckyMonster(zone.index)
	if not monsterId then
		return
	end
	task.delay(LuckyDelay, function()
		if player:GetAttribute("Zone") ~= zone.id or record.lucky then
			return
		end
		local ok = SpawnService.spawnFor(player, monsterId, "Normal")
		if ok then
			record.lucky = true
			DataService.saveSoon(player)
			local rarity = Monsters[monsterId].rarity
			Notify.toast(
				player,
				`Lucky hunt! A {rarity} {Format.name(monsterId)} is waiting for you here. Only you can catch it!`
			)
		end
		-- Too crowded: the next trip tries again (hunts stays past LuckyHunt).
	end)
end

function RookieService.start()
	DataService.onLoaded(function(player, data)
		decide(data)
		tick(player, data, 0)
	end)

	local function watch(player: Player)
		player:GetAttributeChangedSignal("Zone"):Connect(function()
			if player:GetAttribute("Zone") ~= nil then
				arrived(player)
			end
		end)
		-- The tutorial just ended: the bar and the rookie hour show right away.
		player:GetAttributeChangedSignal("Tutorial"):Connect(function()
			local data = DataService.get(player)
			if data and player:GetAttribute("Tutorial") == nil and data.tutorial == "Done" then
				tick(player, data, 0)
				if data.rookie.secondsLeft > 0 then
					Notify.toast(
						player,
						`Rookie hour! For your first {Rookie.Minutes} minutes the Collector pays double.`
					)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited < TickSeconds then
			return
		end
		local seconds = waited
		waited = 0
		for _, player in Players:GetPlayers() do
			local data = DataService.get(player)
			if data then
				local ok, err = pcall(tick, player, data, seconds)
				if not ok then
					warn(`RookieService: {player.Name}: {err}`)
				end
			end
		end
	end)
end

return RookieService
