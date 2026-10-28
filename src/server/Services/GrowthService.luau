--!strict
-- The Growth Chamber, next to the Collector: makes a monster from the Backpack (Storage)
-- heavier, with odds. Pick a mode (Gentle, Strong, Reckless) and pay its fee; the monster
-- goes into the chamber and bubbles for its mode's seconds (Config/Growth; the clock keeps going
-- while you're offline). Then the chamber shows how it went: a win grows it, a loss in a hard
-- mode shrinks it. Pick it up to put it back in your Backpack (or try again from there).
-- One monster in the chamber at a time; every monster can go in Config/Growth.Charges times.
-- Rules in Shared.Util.Growth. The odds are rolled when it goes in, and only shown at the end.
--
-- Remotes in ReplicatedStorage.GrowthRemotes:
--   Open     server -> client (counter: Vector3)       the player picked "enter"
--   GetList  client -> server () -> View?               Backpack monsters, fees and the chamber
--   Grow     client -> server (uid, mode) -> Result     puts a monster in the chamber
--   PickUp   client -> server () -> Result              takes a finished monster out again

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Growth = require(ReplicatedStorage.Shared.Util.Growth)
local GrowthConfig = require(ReplicatedStorage.Shared.Config.Growth)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Storage = require(ReplicatedStorage.Shared.Util.Storage)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Weight = require(ReplicatedStorage.Shared.Util.Weight)
local Counter = require(script.Parent.Parent.Counter)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)

local GrowthService = {}

export type Option = {
	id: string,
	name: string,
	chance: number,
	win: number,
	lose: number,
	fee: number,
	seconds: number, -- how long it bubbles
}
export type Row = {
	uid: string,
	name: string,
	kind: string, -- "Silver Big Rare"
	weight: string, -- "54 kg"
	look: string,
	color: Color3,
	value: number,
	charges: number, -- left
	options: { Option }, -- one per mode, mildest first
}
export type Side = { size: string, weight: string, value: number }
export type Chamber = {
	uid: string,
	name: string,
	look: string,
	color: Color3,
	mode: string, -- its name
	secondsLeft: number, -- 0 once it's done
	-- Once it's done:
	won: boolean?,
	before: Side?,
	after: Side?,
	charges: number?, -- goes it has left
}
export type View = { monsters: { Row }, charges: number, chamber: Chamber? }
export type Result = { ok: boolean, message: string, view: View? }

local CheckSeconds = 5 -- how often the chamber looks for finished monsters to tell owners about

local busy: { [Player]: boolean } = {}
local counter: Attachment? = nil

local remotes = Instance.new("Folder")
remotes.Name = "GrowthRemotes"
local Open = Instance.new("RemoteEvent")
Open.Name = "Open"
Open.Parent = remotes
local GetList = Instance.new("RemoteFunction")
GetList.Name = "GetList"
GetList.Parent = remotes
local GrowRemote = Instance.new("RemoteFunction")
GrowRemote.Name = "Grow"
GrowRemote.Parent = remotes
local PickUpRemote = Instance.new("RemoteFunction")
PickUpRemote.Name = "PickUp"
PickUpRemote.Parent = remotes

local function valueOf(caught: Value.CaughtMonster, wingsOwned: number): number
	local ok, value = pcall(Value.sellValue, caught, wingsOwned)
	return if ok then value else 0
end

local function chamberFor(data: DataService.Data, now: number): Chamber?
	local chamber = data.chamber
	local caught = chamber.monster
	local monster = if caught then Monsters[caught.monsterId] else nil
	if not caught or not monster or not caught.uid then
		return nil
	end
	local mode = Growth.mode(chamber.mode)
	local left = math.max(0, (chamber.endsAt or 0) - now)
	local view: Chamber = {
		uid = caught.uid,
		name = Format.monsterName(caught),
		look = InventoryService.lookOf(caught),
		color = MonsterModel.color(monster.rarity),
		mode = if mode then mode.name else "",
		secondsLeft = left,
	}
	local before = chamber.before
	if left <= 0 and before then
		view.won = chamber.won == true
		view.before = { size = before.size, weight = Weight.text(before.kg), value = before.value }
		view.after = {
			size = caught.size,
			weight = Weight.text(caught.kg or 0),
			value = valueOf(caught, data.wingsOwned),
		}
		view.charges = Growth.chargesLeft(caught)
	end
	return view
end

local function viewFor(data: DataService.Data): View
	local rows: { Row } = {}
	for _, caught in data.storage do
		local monster = Monsters[caught.monsterId]
		if not monster or not caught.uid then
			continue
		end
		local value = valueOf(caught, data.wingsOwned)
		local options = {}
		for _, mode in GrowthConfig.Modes do
			table.insert(options, {
				id = mode.id,
				name = mode.name,
				chance = mode.chance,
				win = mode.win,
				lose = mode.lose,
				fee = Growth.fee(value, mode),
				seconds = mode.seconds,
			})
		end
		local variant = if caught.variant then `{caught.variant} ` else ""
		table.insert(rows, {
			uid = caught.uid,
			name = Format.monsterName(caught),
			kind = `{variant}{caught.size} {monster.rarity}`,
			weight = Weight.text(caught.kg or 0),
			look = InventoryService.lookOf(caught),
			color = MonsterModel.color(monster.rarity),
			value = value,
			charges = Growth.chargesLeft(caught),
			options = options,
		})
	end
	-- Ones with charges left first, most valuable first.
	table.sort(rows, function(a, b)
		if (a.charges > 0) ~= (b.charges > 0) then
			return a.charges > 0
		end
		return if a.value == b.value then a.uid < b.uid else a.value > b.value
	end)
	return { monsters = rows, charges = GrowthConfig.Charges, chamber = chamberFor(data, os.time()) }
end

GrowRemote.OnServerInvoke = function(player: Player, uid: unknown, modeId: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	if not Counter.isNear(player, counter) then
		return { ok = false, message = "Walk up to the Growth Chamber first.", view = viewFor(data) }
	end
	if busy[player] then
		return { ok = false, message = "One at a time!", view = viewFor(data) }
	end
	if data.chamber.monster then
		return { ok = false, message = "The chamber is already bubbling.", view = viewFor(data) }
	end
	local mode = Growth.mode(modeId)
	local index: number? = nil
	for i, stored in data.storage do
		if typeof(uid) == "string" and stored.uid == uid then
			index = i
		end
	end
	if not mode or not index then
		return { ok = false, message = "That monster isn't in your Backpack any more.", view = viewFor(data) }
	end
	local monster = data.storage[index]
	if Growth.chargesLeft(monster) <= 0 then
		return {
			ok = false,
			message = `This one has been in the chamber {GrowthConfig.Charges} times already.`,
			view = viewFor(data),
		}
	end
	local value = valueOf(monster, data.wingsOwned)
	local fee = Growth.fee(value, mode)
	if not DataService.addMoney(player, -fee) then
		local message =
			`Not enough money! {mode.name} costs {Format.money(fee)} and you have {Format.money(data.money)}.`
		Notify.toast(player, message)
		return { ok = false, message = message, view = viewFor(data) }
	end

	busy[player] = true
	-- Out of the Backpack and into the chamber. It stays paused (it keeps its storedAt), so it
	-- comes back exactly as the chamber leaves it.
	table.remove(data.storage, index)
	local before = { kg = monster.kg or 0, size = monster.size, value = value }
	local won = Growth.roll(mode)
	Growth.apply(monster, mode, won)
	data.chamber = {
		monster = monster,
		mode = mode.id,
		endsAt = os.time() + mode.seconds,
		won = won,
		before = before,
	}
	busy[player] = nil
	DataService.saveSoon(player)
	local minutes = math.ceil(mode.seconds / 60)
	return {
		ok = true,
		message = `Your {Format.monsterName(monster)} is bubbling! Come back in {minutes} minutes.`,
		view = viewFor(data),
	}
end

PickUpRemote.OnServerInvoke = function(player: Player): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	if not Counter.isNear(player, counter) then
		return { ok = false, message = "Walk up to the Growth Chamber first.", view = viewFor(data) }
	end
	local chamber = data.chamber
	local monster = chamber.monster
	if not monster then
		return { ok = false, message = "The chamber is empty.", view = viewFor(data) }
	end
	if (chamber.endsAt or 0) > os.time() then
		return { ok = false, message = "It's still bubbling.", view = viewFor(data) }
	end
	if not Storage.hasRoom(#data.storage) then
		return { ok = false, message = "Your Backpack is full. Make room first!", view = viewFor(data) }
	end
	table.insert(data.storage, monster)
	data.chamber = {}
	DataService.saveSoon(player)
	return {
		ok = true,
		message = `{Format.monsterName(monster)} is back in your Backpack.`,
		view = viewFor(data),
	}
end

GetList.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	return if data then viewFor(data) else nil
end

-- Admin: finishes the bubbling right away.
function GrowthService.finish(player: Player): boolean
	local data = DataService.get(player)
	if not data or not data.chamber.monster then
		return false
	end
	data.chamber.endsAt = os.time()
	return true
end

-- Tells owners whose monster is done (also once when they join and it finished meanwhile).
local function tellDone()
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		local chamber = data and data.chamber
		if chamber and chamber.monster and not chamber.told and (chamber.endsAt or 0) <= now then
			chamber.told = true
			Notify.toast(player, `Your {Format.monsterName(chamber.monster)} is done in the Growth Chamber!`)
		end
	end
end

function GrowthService.start()
	remotes.Parent = ReplicatedStorage
	counter = Counter.prompt("GrowthChamber", "Growth Chamber", function(player)
		local at = counter
		if at and DataService.isLoaded(player) then
			Open:FireClient(player, at.WorldPosition)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CheckSeconds)
			tellDone()
		end
	end)
end

return GrowthService
