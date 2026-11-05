--!strict
-- Playtime gifts (Giles 2026-11-05; numbers in Config/Playtime, rules in Util/Playtime). Counts
-- each player's online play time after the tutorial, saved per day in data.playtime, and pays
-- the gifts they claim from the HUD's gift button (client/Controllers/PlaytimeController).
-- Cash and cakes follow the player's worth plus a share of what their wings and tools cost;
-- the bell gift gets better once zone 3 is open.
--
-- Player attributes: PlaytimeSeconds (today's play time, every few seconds), PlaytimeReady
-- (gifts waiting, the red dot), PlaytimeNext (seconds until the next one; nil when all came).
--
-- Remotes in ReplicatedStorage.PlaytimeRemotes:
--   GetView  client -> server () -> View?
--   Claim    client -> server (index: number) -> Result

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Playtime)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Missions = require(ReplicatedStorage.Shared.Util.Missions)
local Playtime = require(ReplicatedStorage.Shared.Util.Playtime)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CakeService = require(script.Parent.CakeService)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local InventoryService = require(script.Parent.InventoryService)
local MissionService = require(script.Parent.MissionService)
local Notify = require(script.Parent.Parent.Notify)
local ToolModel = require(script.Parent.Parent.ToolModel)

local PlaytimeService = {}

export type Gift = {
	minutes: number,
	cash: number,
	item: string?,
	itemName: string?,
	kind: string?, -- Config/Shop kind of the item
	look: string?, -- the item's preview model in InventoryPreviews (Ui.picture)
	ready: boolean,
	claimed: boolean,
}
export type View = { seconds: number, resetIn: number, gifts: { Gift } }
export type Result = { ok: boolean, message: string, view: View? }

local TickSeconds = 5

local remotes = Instance.new("Folder")
remotes.Name = "PlaytimeRemotes"
local GetView = Instance.new("RemoteFunction")
GetView.Name = "GetView"
GetView.Parent = remotes
local Claim = Instance.new("RemoteFunction")
Claim.Name = "Claim"
Claim.Parent = remotes

local function baseFor(data: DataService.Data): number
	return Playtime.base(MissionService.worth(data), Playtime.invested(data.inventory, data.wingsOwned))
end

local function viewFor(data: DataService.Data): View
	local record = data.playtime
	local base = baseFor(data)
	local gifts: { Gift } = {}
	for index, step in Config.Steps do
		local reward = Playtime.reward(index, base, data.wingsOwned)
		local look: string? = nil
		if reward and reward.item then
			look = if reward.kind == "Food"
				then InventoryService.cakeLook(reward.item)
				else ToolModel.look(reward.item)
		end
		table.insert(gifts, {
			minutes = step.minutes,
			cash = if reward then reward.cash else 0,
			item = reward and reward.item,
			itemName = reward and reward.itemName,
			kind = reward and reward.kind,
			look = look,
			ready = Playtime.isReady(record, index),
			claimed = Playtime.isClaimed(record, index),
		})
	end
	return { seconds = record.seconds, resetIn = Missions.secondsLeft(os.time()), gifts = gifts }
end

local function attributes(player: Player, data: DataService.Data)
	local record = data.playtime
	local playing = data.tutorial == "Done"
	player:SetAttribute("PlaytimeSeconds", if playing then math.floor(record.seconds) else nil)
	player:SetAttribute("PlaytimeReady", if playing then Playtime.ready(record) else nil)
	local nextIn = Playtime.nextIn(record)
	player:SetAttribute("PlaytimeNext", if playing and nextIn then math.ceil(nextIn) else nil)
end

local function tick(player: Player, data: DataService.Data, seconds: number)
	local record = data.playtime
	Playtime.refresh(record, os.time())
	if data.tutorial == "Done" then
		record.seconds += seconds -- a ready gift shows as the dot on Gifts, no pop-up
	end
	attributes(player, data)
end

Claim.OnServerInvoke = function(player: Player, index: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading." }
	end
	local record = data.playtime
	Playtime.refresh(record, os.time())
	-- Worked out before the claim, so the cash doesn't count itself.
	local reward = if typeof(index) == "number"
		then Playtime.reward(index, baseFor(data), data.wingsOwned)
		else nil
	if not reward or not Playtime.claim(record, index) then
		return { ok = false, message = "Not ready yet.", view = viewFor(data) }
	end
	local step = index :: number
	local got: { string } = {}
	if reward.cash > 0 and DataService.addMoney(player, reward.cash) then
		AnalyticsService.money(player, reward.cash, "TimedReward", `Playtime{Config.Steps[step].minutes}`)
		table.insert(got, Format.money(reward.cash))
	end
	if reward.item then
		data.inventory[reward.item] = (data.inventory[reward.item] or 0) + 1
		if reward.kind == "Food" then
			CakeService.syncTools(player)
		else
			HuntService.refreshItems(player)
		end
		table.insert(got, reward.itemName or reward.item)
	end
	AnalyticsService.playtimeGift(player, record.day, step, Config.Steps[step].minutes)
	DataService.saveSoon(player)
	attributes(player, data)
	local message = `+{table.concat(got, " + ")}`
	Notify.toast(player, message)
	return { ok = true, message = message, view = viewFor(data) }
end

GetView.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	Playtime.refresh(data.playtime, os.time())
	return viewFor(data)
end

-- Admin: adds play time today (minutes; negative takes it away). False while loading.
function PlaytimeService.add(player: Player, minutes: number): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local record = data.playtime
	Playtime.refresh(record, os.time())
	record.seconds = math.max(0, record.seconds + minutes * 60)
	attributes(player, data)
	return true
end

-- Admin: today starts over (no play time, nothing claimed).
function PlaytimeService.reset(player: Player): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	data.playtime = Playtime.empty()
	Playtime.refresh(data.playtime, os.time())
	attributes(player, data)
	return true
end

function PlaytimeService.start()
	remotes.Parent = ReplicatedStorage
	DataService.onLoaded(function(player, data)
		tick(player, data, 0)
	end)

	local function watch(player: Player)
		-- The tutorial just ended: the gift button starts counting right away.
		player:GetAttributeChangedSignal("Tutorial"):Connect(function()
			local data = DataService.get(player)
			if data then
				tick(player, data, 0)
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
					warn(`PlaytimeService: {player.Name}: {err}`)
				end
			end
		end
	end)
end

return PlaytimeService
