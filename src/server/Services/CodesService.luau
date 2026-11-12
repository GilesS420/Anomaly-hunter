--!strict
-- Reward codes (thread "Add fresh content to match the market", 2026-11-11; the codes are in
-- Config/Codes, rules in Util/Codes). Players type one in Settings > Codes; each pays once per
-- player and is remembered in data.codes.
--
-- Remotes in ReplicatedStorage.CodesRemotes:
--   Redeem  client -> server (code: string) -> Result

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codes = require(ReplicatedStorage.Shared.Util.Codes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Playtime = require(ReplicatedStorage.Shared.Util.Playtime)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CakeService = require(script.Parent.CakeService)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local MissionService = require(script.Parent.MissionService)

local CodesService = {}

export type Result = { ok: boolean, message: string }

local TryGap = 1.5 -- seconds between tries, so nobody can guess codes by the thousand

local remotes = Instance.new("Folder")
remotes.Name = "CodesRemotes"
local Redeem = Instance.new("RemoteFunction")
Redeem.Name = "Redeem"
Redeem.Parent = remotes

local lastTry: { [Player]: number } = {}

local Answers = {
	unknown = "That code doesn't exist.",
	used = "You already used this code.",
	ended = "This code has ended.",
}

Redeem.OnServerInvoke = function(player: Player, typed: unknown): Result
	local now = os.clock()
	if now - (lastTry[player] or -math.huge) < TryGap then
		return { ok = false, message = "Slow down a little." }
	end
	lastTry[player] = now
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading." }
	end
	local state, entry = Codes.check(data.codes, typed)
	if state ~= "ok" or not entry then
		return { ok = false, message = Answers[state] or Answers.unknown }
	end
	local base = Playtime.base(MissionService.worth(data), Playtime.invested(data.inventory, data.wingsOwned))
	local reward = Codes.reward(entry, base)
	data.codes[entry.code] = true -- marked first: a second call while this one runs gets "used"
	local got: { string } = {}
	if reward.cash > 0 and DataService.addMoney(player, reward.cash) then
		AnalyticsService.money(player, reward.cash, "Gameplay", `Code{entry.code}`)
		table.insert(got, Format.money(reward.cash))
	end
	local food, tools = false, false
	for _, item in reward.items do
		data.inventory[item.id] = (data.inventory[item.id] or 0) + item.count
		if item.kind == "Food" then
			food = true
		else
			tools = true
		end
		table.insert(got, if item.count > 1 then `{item.count}x {item.name}` else item.name)
	end
	if food then
		CakeService.syncTools(player)
	end
	if tools then
		HuntService.refreshItems(player)
	end
	DataService.saveSoon(player)
	return { ok = true, message = `+{table.concat(got, " + ")}` }
end

function CodesService.start()
	remotes.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
	end)
end

return CodesService
