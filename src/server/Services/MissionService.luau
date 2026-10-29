--!strict
-- Daily missions (rules in Shared.Util.Missions, numbers in Config/Missions). Deals each
-- player their three missions for the day when their save loads and again when the day turns
-- over while they're online, counts what they do (other services call MissionService.record)
-- and pays the rewards they claim in the Missions window (client MissionController).
-- The player attribute MissionsReady is how many rewards are waiting (the red dot).
--
-- Remotes in ReplicatedStorage.MissionRemotes:
--   GetView  client -> server () -> View?
--   Claim    client -> server (index: number; 0 = the bonus chest) -> Result
--   Reroll   client -> server (index: number) -> Result
--   Changed  server -> client (View), whenever progress moves

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Missions)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Missions = require(ReplicatedStorage.Shared.Util.Missions)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Parent.Notify)
local Perks = require(script.Parent.Parent.Perks)

local MissionService = {}

export type Card = {
	tier: string,
	text: string,
	progress: number,
	target: number,
	money: boolean, -- the target is money ($ in the progress line)
	reward: number,
	done: boolean,
	claimed: boolean,
}
export type View = {
	streakDay: number, -- "Day 4 streak"
	bonus: number,
	secondsLeft: number,
	rerolls: number,
	missions: { Card },
	chest: { reward: number, ready: boolean, claimed: boolean },
}
export type Result = { ok: boolean, message: string, view: View? }

local CheckSeconds = 30 -- how often to look for the day turning over

local random = Random.new()

local remotes = Instance.new("Folder")
remotes.Name = "MissionRemotes"
local GetView = Instance.new("RemoteFunction")
GetView.Name = "GetView"
GetView.Parent = remotes
local Claim = Instance.new("RemoteFunction")
Claim.Name = "Claim"
Claim.Parent = remotes
local Reroll = Instance.new("RemoteFunction")
Reroll.Name = "Reroll"
Reroll.Parent = remotes
local Changed = Instance.new("RemoteEvent")
Changed.Name = "Changed"
Changed.Parent = remotes

-- Cash plus what every monster the player owns would sell for.
function MissionService.worth(data: DataService.Data): number
	local total = data.money
	local lists = { data.monsters, data.storage, data.vault }
	if data.chamber.monster then
		table.insert(lists, { data.chamber.monster })
	end
	for _, list in lists do
		for _, caught in list do
			local ok, value = pcall(Value.sellValue, caught, data.wingsOwned)
			if ok then
				total += value
			end
		end
	end
	return total
end

local function viewFor(state: Missions.State): View
	local now = os.time()
	local today = Missions.day(now)
	local cards: { Card } = {}
	for _, saved in state.list do
		local def = Missions.def(saved.id)
		table.insert(cards, {
			tier = if def then def.tier else "",
			text = Missions.text(saved),
			progress = saved.progress,
			target = saved.target,
			money = def ~= nil and def.moneyShare ~= nil,
			reward = saved.reward,
			done = Missions.isDone(saved),
			claimed = saved.claimed == true,
		})
	end
	return {
		streakDay = if state.lastDay == today then state.streak else state.streak + 1,
		bonus = state.bonus,
		secondsLeft = Missions.secondsLeft(now),
		rerolls = state.rerolls,
		missions = cards,
		chest = {
			reward = state.chest,
			ready = Missions.chestReady(state),
			claimed = state.chestClaimed == true,
		},
	}
end

local function update(player: Player, state: Missions.State)
	player:SetAttribute("MissionsReady", Missions.ready(state))
	Changed:FireClient(player, viewFor(state))
end

-- VIP Hunters get their extra free rerolls once a day (the pass may be found after the deal,
-- so this is checked every time, not only when dealing). True if any were added.
local function vipRerolls(player: Player, state: Missions.State): boolean
	local extra = Perks.extraRerolls(player)
	if extra <= 0 or state.vipDay == state.day then
		return false
	end
	state.vipDay = state.day
	state.rerolls += extra
	return true
end

-- Today's missions for this player, dealing new ones first if the day turned over. `quiet`:
-- no toast (the first look when they join).
local function current(player: Player, data: DataService.Data, quiet: boolean?): Missions.State
	local now = os.time()
	if not Missions.isCurrent(data.missions, now) then
		data.missions = Missions.deal(data.missions, now, MissionService.worth(data), data.wingsOwned, random)
		DataService.saveSoon(player)
		if not quiet then
			Notify.toast(player, "New daily missions are up! Open Missions to see them.")
		end
		update(player, data.missions)
	end
	if vipRerolls(player, data.missions) then
		update(player, data.missions)
	end
	return data.missions
end

-- Counts something the player did towards today's missions (kinds in Config/Missions:
-- "Catch", "Sell", "PlaceCake", "Effect", "Combo", "Merge", "Grow", "GoldenGhost").
function MissionService.record(player: Player, kind: string, done: Missions.Done?)
	local data = DataService.get(player)
	if not data then
		return
	end
	local state = current(player, data)
	local before = 0
	for _, saved in state.list do
		before += saved.progress
	end
	local finished = Missions.record(state, kind, done or {})
	local after = 0
	for _, saved in state.list do
		after += saved.progress
	end
	if after == before then
		return
	end
	for _, saved in finished do
		Notify.toast(
			player,
			`Mission done: {Missions.text(saved)}! Claim {Format.money(saved.reward)} in Missions.`
		)
	end
	update(player, state)
end

-- Robux Mission Reroll: swaps every mission that isn't done yet for a new one. Returns how
-- many were swapped (0 while the save is loading or everything is done).
function MissionService.rerollAll(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local state = current(player, data)
	local swapped = Missions.rerollAll(state, data.wingsOwned, random)
	update(player, state)
	return swapped
end

-- Robux Mission Skip: finishes mission `index` (it still needs claiming). False if it's
-- already done or there's no such mission.
function MissionService.skip(player: Player, index: unknown): boolean
	local data = DataService.get(player)
	if not data or typeof(index) ~= "number" then
		return false
	end
	local state = current(player, data)
	local saved = state.list[index]
	if not saved or saved.claimed or Missions.isDone(saved) then
		return false
	end
	saved.progress = saved.target
	Notify.toast(
		player,
		`Mission skipped: {Missions.text(saved)}! Claim {Format.money(saved.reward)} in Missions.`
	)
	update(player, state)
	return true
end

-- True if every one of today's missions is done (nothing left to reroll or skip).
function MissionService.allDone(player: Player): boolean
	local data = DataService.get(player)
	if not data then
		return true
	end
	for _, saved in current(player, data).list do
		if not saved.claimed and not Missions.isDone(saved) then
			return false
		end
	end
	return true
end

-- Brings today's missions up to date (RobuxService calls it once a VIP pass is found).
function MissionService.refresh(player: Player)
	local data = DataService.get(player)
	if data then
		current(player, data)
	end
end

-- Admin: deals a fresh set of missions now (the streak stays).
function MissionService.redeal(player: Player): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	data.missions =
		Missions.deal(data.missions, os.time(), MissionService.worth(data), data.wingsOwned, random)
	vipRerolls(player, data.missions)
	update(player, data.missions)
	return true
end

-- Admin: finishes mission `index` (1 to 3), or every one for nil.
function MissionService.finish(player: Player, index: number?): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local state = current(player, data)
	local any = false
	for i, saved in state.list do
		if (index == nil or index == i) and not saved.claimed then
			saved.progress = saved.target
			any = true
		end
	end
	update(player, state)
	return any
end

-- Admin: sets the streak as if missions were claimed every day up to yesterday, and deals
-- new missions so the bonus shows.
function MissionService.setStreak(player: Player, days: number): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local state = current(player, data)
	state.streak = math.max(0, math.floor(days))
	state.lastDay = Missions.day(os.time()) - 1
	return MissionService.redeal(player)
end

Claim.OnServerInvoke = function(player: Player, index: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	local state = current(player, data)
	if typeof(index) ~= "number" or index ~= math.floor(index) then
		return { ok = false, message = "Pick a mission.", view = viewFor(state) }
	end
	local message
	if index == 0 then
		local cash = Missions.claimChest(state)
		if not cash then
			return { ok = false, message = "Claim all three missions first.", view = viewFor(state) }
		end
		DataService.addMoney(player, cash)
		local cakes = Missions.chestCakes(cash)
		local cake = cakes[random:NextInteger(1, math.max(1, #cakes))]
		if cake then
			data.inventory[cake.id] = (data.inventory[cake.id] or 0) + 1
			-- Required here, not at the top: CakeService reports cakes placed to this service.
			local CakeService = (require :: any)(script.Parent.CakeService)
			CakeService.syncTools(player)
			message = `Bonus chest! You got {Format.money(cash)} and a {cake.name}!`
		else
			message = `Bonus chest! You got {Format.money(cash)}!`
		end
	else
		local reward = Missions.claim(state, index, os.time())
		if not reward then
			return { ok = false, message = "That mission isn't done yet.", view = viewFor(state) }
		end
		DataService.addMoney(player, reward)
		message = `Mission reward: +{Format.money(reward)}!`
	end
	DataService.saveSoon(player)
	Notify.toast(player, message)
	player:SetAttribute("MissionsReady", Missions.ready(state))
	return { ok = true, message = message, view = viewFor(state) }
end

Reroll.OnServerInvoke = function(player: Player, index: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	local state = current(player, data)
	if typeof(index) ~= "number" then
		return { ok = false, message = "Pick a mission.", view = viewFor(state) }
	end
	if state.rerolls <= 0 then
		return { ok = false, message = "No rerolls left today.", view = viewFor(state) }
	end
	if not Missions.reroll(state, index, data.wingsOwned, random) then
		return { ok = false, message = "That one can't be swapped.", view = viewFor(state) }
	end
	DataService.saveSoon(player)
	return { ok = true, message = "New mission!", view = viewFor(state) }
end

GetView.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	return if data then viewFor(current(player, data)) else nil
end

function MissionService.start()
	remotes.Parent = ReplicatedStorage
	DataService.onLoaded(function(player, data)
		player:SetAttribute("MissionsReady", Missions.ready(current(player, data, true)))
	end)
	task.spawn(function()
		while true do
			task.wait(CheckSeconds)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					current(player, data)
				end
			end
		end
	end)
end

return MissionService
