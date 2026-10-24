--!strict
-- The Growth Chamber, next to the Collector: makes a monster from the Backpack (Storage)
-- heavier, with odds. Pick a mode (Gentle, Strong, Reckless) and pay its fee; a win grows it,
-- a loss in a hard mode shrinks it. Every monster can go in Config/Growth.Charges times.
-- Rules in Shared.Util.Growth.
--
-- Remotes in ReplicatedStorage.GrowthRemotes:
--   Open     server -> client (counter: Vector3)       the player picked "enter"
--   GetList  client -> server () -> View?               their Backpack monsters and the fees
--   Grow     client -> server (uid, mode) -> Result     one go in the chamber

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Growth = require(ReplicatedStorage.Shared.Util.Growth)
local GrowthConfig = require(ReplicatedStorage.Shared.Config.Growth)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Weight = require(ReplicatedStorage.Shared.Util.Weight)
local Counter = require(script.Parent.Parent.Counter)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)

local GrowthService = {}

export type Option = { id: string, name: string, chance: number, win: number, lose: number, fee: number }
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
export type View = { monsters: { Row }, charges: number }
export type Result = { ok: boolean, won: boolean?, message: string, view: View? }

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

local function valueOf(caught: Value.CaughtMonster, wingsOwned: number): number
	local ok, value = pcall(Value.sellValue, caught, wingsOwned)
	return if ok then value else 0
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
	return { monsters = rows, charges = GrowthConfig.Charges }
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
	local mode = Growth.mode(modeId)
	local caught: Value.CaughtMonster? = nil
	for _, stored in data.storage do
		if typeof(uid) == "string" and stored.uid == uid then
			caught = stored
		end
	end
	if not mode or not caught then
		return { ok = false, message = "That monster isn't in your Backpack any more.", view = viewFor(data) }
	end
	local monster: Value.CaughtMonster = caught
	if Growth.chargesLeft(monster) <= 0 then
		return {
			ok = false,
			message = `This one has been in the chamber {GrowthConfig.Charges} times already.`,
			view = viewFor(data),
		}
	end
	local fee = Growth.fee(valueOf(monster, data.wingsOwned), mode)
	if not DataService.addMoney(player, -fee) then
		return { ok = false, message = `You need {Format.money(fee)} for the fee.`, view = viewFor(data) }
	end

	busy[player] = true
	local name = Format.monsterName(monster)
	local size = monster.size
	local won = Growth.roll(mode)
	local before, after = Growth.apply(monster, mode, won)
	local message
	if won then
		message = `It worked! Your {name} grew from {Weight.text(before)} to {Weight.text(after)}`
		message ..= if monster.size ~= size then ` and is {monster.size} now!` else "!"
	elseif after < before then
		message = `Oh no, it fizzled. Your {name} shrank to {Weight.text(after)}.`
	else
		message = `Nothing happened. Your {name} is still {Weight.text(after)}.`
	end
	busy[player] = nil
	DataService.saveSoon(player)
	Notify.toast(player, message)
	return { ok = true, won = won, message = message, view = viewFor(data) }
end

GetList.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	return if data then viewFor(data) else nil
end

function GrowthService.start()
	remotes.Parent = ReplicatedStorage
	counter = Counter.prompt("GrowthChamber", "Growth Chamber", function(player)
		local at = counter
		if at and DataService.isLoaded(player) then
			Open:FireClient(player, at.WorldPosition)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return GrowthService
