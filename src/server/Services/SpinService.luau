--!strict
-- The Lucky Spin (thread "Add fresh content to match the market", 2026-11-11; numbers in
-- Config/Spin, rules in Util/Spin). A free prize wheel: one spin a day plus one more after 15
-- and 45 minutes of play (the playtime gifts' clock, data.playtime). The server picks the
-- prize; the client only spins the wheel to where the server says it landed. Never sold for
-- Robux.
--
-- Player attributes: SpinLeft (spins waiting, the red dot), SpinNext (seconds of play until
-- the next spin is earned; nil when all of today's are earned). Both stay nil until the
-- tutorial is done.
--
-- Remotes in ReplicatedStorage.SpinRemotes:
--   GetView  client -> server () -> View?
--   Spin     client -> server ("Spin") -> Result   (the word guards against junk calls)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Spin)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Missions = require(ReplicatedStorage.Shared.Util.Missions)
local Playtime = require(ReplicatedStorage.Shared.Util.Playtime)
local Spin = require(ReplicatedStorage.Shared.Util.Spin)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CakeService = require(script.Parent.CakeService)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local InventoryService = require(script.Parent.InventoryService)
local MissionService = require(script.Parent.MissionService)
local Notify = require(script.Parent.Parent.Notify)
local ToolModel = require(script.Parent.Parent.ToolModel)

local SpinService = {}

export type Slice = {
	id: string,
	color: { number },
	cash: number,
	item: string?,
	itemName: string?,
	kind: string?, -- Config/Shop kind of the item
	count: number,
	look: string?, -- the item's preview model in InventoryPreviews (Ui.picture)
	jackpot: boolean,
}
export type View = { left: number, nextIn: number?, resetIn: number, slices: { Slice } }
export type Result = { ok: boolean, message: string, index: number?, view: View? }

local TickSeconds = 5
local SpinWord = "Spin"

local remotes = Instance.new("Folder")
remotes.Name = "SpinRemotes"
local GetView = Instance.new("RemoteFunction")
GetView.Name = "GetView"
GetView.Parent = remotes
local SpinRemote = Instance.new("RemoteFunction")
SpinRemote.Name = "Spin"
SpinRemote.Parent = remotes

local spinning: { [Player]: boolean } = {}

local function baseFor(data: DataService.Data): number
	return Playtime.base(MissionService.worth(data), Playtime.invested(data.inventory, data.wingsOwned))
end

local function played(data: DataService.Data): number
	Playtime.refresh(data.playtime, os.time())
	return data.playtime.seconds
end

local function viewFor(data: DataService.Data): View
	Spin.refresh(data.spin, os.time())
	local base = baseFor(data)
	local slices: { Slice } = {}
	for index, prize in Config.Prizes do
		local reward = Spin.reward(index, base, data.wingsOwned)
		local look: string? = nil
		if reward and reward.item then
			look = if reward.kind == "Food"
				then InventoryService.cakeLook(reward.item)
				else ToolModel.look(reward.item)
		end
		table.insert(slices, {
			id = prize.id,
			color = prize.color,
			cash = if reward then reward.cash else 0,
			item = reward and reward.item,
			itemName = reward and reward.itemName,
			kind = reward and reward.kind,
			count = if reward then reward.count else 0,
			look = look,
			jackpot = prize.jackpot == true,
		})
	end
	local seconds = played(data)
	return {
		left = Spin.left(data.spin, seconds),
		nextIn = Spin.nextIn(seconds),
		resetIn = Missions.secondsLeft(os.time()),
		slices = slices,
	}
end

local function attributes(player: Player, data: DataService.Data)
	local playing = data.tutorial == "Done"
	Spin.refresh(data.spin, os.time())
	local seconds = played(data)
	local nextIn = Spin.nextIn(seconds)
	player:SetAttribute("SpinLeft", if playing then Spin.left(data.spin, seconds) else nil)
	player:SetAttribute("SpinNext", if playing and nextIn then math.ceil(nextIn) else nil)
end

local pay: (Player, DataService.Data, number) -> Result

SpinRemote.OnServerInvoke = function(player: Player, word: unknown): Result
	if word ~= SpinWord then
		return { ok = false, message = "" }
	end
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading." }
	end
	if data.tutorial ~= "Done" then
		return { ok = false, message = "Finish the tutorial first." }
	end
	if spinning[player] then
		return { ok = false, message = "Already spinning." }
	end
	spinning[player] = true
	Spin.refresh(data.spin, os.time())
	-- Worked out before the prize, so the cash doesn't count itself.
	local base = baseFor(data)
	if not Spin.use(data.spin, played(data)) then
		spinning[player] = nil
		attributes(player, data)
		return { ok = false, message = "No spins left. Play on for more!", view = viewFor(data) }
	end
	local ok, result = pcall(function(): Result
		return pay(player, data, base)
	end)
	if not ok then
		spinning[player] = nil
		warn(`SpinService: {player.Name}: {result}`)
		return { ok = false, message = "Something went wrong, try again." }
	end
	return result
end

pay = function(player: Player, data: DataService.Data, base: number): Result
	local index = Spin.pick(math.random())
	local prize = Config.Prizes[index]
	local reward = Spin.reward(index, base, data.wingsOwned) :: Spin.Reward
	local got: { string } = {}
	if reward.cash > 0 and DataService.addMoney(player, reward.cash) then
		AnalyticsService.money(player, reward.cash, "TimedReward", `Spin{prize.id}`)
		table.insert(got, Format.money(reward.cash))
	end
	if reward.item and reward.count > 0 then
		data.inventory[reward.item] = (data.inventory[reward.item] or 0) + reward.count
		if reward.kind == "Food" then
			CakeService.syncTools(player)
		else
			HuntService.refreshItems(player)
		end
		local name = reward.itemName or reward.item
		table.insert(got, if reward.count > 1 then `{reward.count}x {name}` else name)
	end
	DataService.saveSoon(player)
	attributes(player, data)
	local message = `+{table.concat(got, " + ")}`
	-- The wheel shows the prize, so no toast for it (Giles 2026-11-05: fewer pop-ups). Only a
	-- jackpot is told to the whole server, once the wheel has stopped (about 4 s), so it
	-- doesn't spoil it. Another spin waits for the wheel too.
	task.delay(4.5, function()
		spinning[player] = nil
		if prize.jackpot and player.Parent == Players then
			Notify.toastAll(`{player.DisplayName} hit the Lucky Spin JACKPOT!`)
		end
	end)
	return { ok = true, message = message, index = index, view = viewFor(data) }
end

GetView.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	return viewFor(data)
end

-- Admin: gives back today's used spins (the free ones and the earned ones come back).
function SpinService.reset(player: Player): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	data.spin = Spin.empty()
	attributes(player, data)
	return true
end

function SpinService.start()
	remotes.Parent = ReplicatedStorage
	DataService.onLoaded(function(player, data)
		attributes(player, data)
	end)

	local function watch(player: Player)
		player:GetAttributeChangedSignal("Tutorial"):Connect(function()
			local data = DataService.get(player)
			if data then
				attributes(player, data)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		spinning[player] = nil
	end)

	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited < TickSeconds then
			return
		end
		waited = 0
		for _, player in Players:GetPlayers() do
			local data = DataService.get(player)
			if data then
				local ok, err = pcall(function(): string?
					attributes(player, data)
					return nil
				end)
				if not ok then
					warn(`SpinService: {player.Name}: {err}`)
				end
			end
		end
	end)
end

return SpinService
