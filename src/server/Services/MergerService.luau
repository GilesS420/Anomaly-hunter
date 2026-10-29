--!strict
-- The Merger, next to the Trading Booth: fuses two monsters of the same kind from the
-- Backpack (Storage) into one. Pick a main (the one you keep) and a donor; on success the
-- donor's weight and effects go into the main, on failure the donor is lost. The fee is paid
-- either way. Rules in Shared.Util.Merge, numbers in Shared.Config.Merger.
--
-- Remotes in ReplicatedStorage.MergerRemotes:
--   Open     server -> client (counter: Vector3)          the player picked "enter"
--   GetList  client -> server () -> View?                  their Backpack monsters
--   Preview  client -> server (main, donor) -> Preview     what a merge would make, odds, fee
--   Merge    client -> server (main, donor) -> Result      merges them
--
-- The Variant Machine, the Merger's second window (Config/VariantMachine, Util/VariantMachine):
--   OpenVariant server -> client (counter: Vector3)       the player picked "Try the Variant Machine"
--   Pull        client -> server (uid) -> PullResult       uses up one effect for a variant pull
-- GetList's rows carry what the machine needs too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effects = require(ReplicatedStorage.Shared.Config.Effects)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Merge = require(ReplicatedStorage.Shared.Util.Merge)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local VariantMachine = require(ReplicatedStorage.Shared.Util.VariantMachine)
local Weight = require(ReplicatedStorage.Shared.Util.Weight)
local CareService = require(script.Parent.CareService)
local Counter = require(script.Parent.Parent.Counter)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MansionService = require(script.Parent.MansionService)
local MissionService = require(script.Parent.MissionService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)

local MergerService = {}

export type Row = {
	uid: string,
	monsterId: string,
	name: string,
	kind: string, -- "Silver Big Rare"
	effects: { string }, -- effect and combo names
	weight: string, -- "54 kg"
	look: string,
	color: Color3,
	value: number,
	locked: boolean,
	twins: number, -- how many others of its kind are in the Backpack
	chance: number, -- percent, for merging two of these
	variant: string?, -- its catch variant, for the Variant Machine's odds
	pullProblem: string?, -- why it can't go in the Variant Machine, nil if it can
	pullFee: number, -- the Variant Machine's fee for it
}
export type View = { monsters: { Row } }
export type Preview = {
	ok: boolean,
	message: string,
	weight: string?, -- what the main would weigh
	size: string?,
	effects: { string }?,
	combos: { string }?, -- combos the merge would form
	chance: number?,
	fee: number?,
	value: number?, -- what the main would be worth
}
export type Result = { ok: boolean, won: boolean?, message: string, view: View? }
export type PullResult = {
	ok: boolean,
	won: boolean?,
	message: string,
	used: string?, -- the effect the pull used up
	variant: string?, -- the variant it won
	view: View?,
}

local busy: { [Player]: boolean } = {}
local counter: Attachment? = nil

local remotes = Instance.new("Folder")
remotes.Name = "MergerRemotes"
local Open = Instance.new("RemoteEvent")
Open.Name = "Open"
Open.Parent = remotes
local GetList = Instance.new("RemoteFunction")
GetList.Name = "GetList"
GetList.Parent = remotes
local PreviewRemote = Instance.new("RemoteFunction")
PreviewRemote.Name = "Preview"
PreviewRemote.Parent = remotes
local MergeRemote = Instance.new("RemoteFunction")
MergeRemote.Name = "Merge"
MergeRemote.Parent = remotes
local OpenVariant = Instance.new("RemoteEvent")
OpenVariant.Name = "OpenVariant"
OpenVariant.Parent = remotes
local PullRemote = Instance.new("RemoteFunction")
PullRemote.Name = "Pull"
PullRemote.Parent = remotes

local PullProblems: { [string]: string } = {
	NoEffects = "It has no effects to feed the machine.",
	Best = "It's already Rainbow, the best there is!",
	Unknown = "That monster can't go in the machine.",
}

local function valueOf(caught: Value.CaughtMonster, wingsOwned: number): number
	local ok, value = pcall(Value.sellValue, caught, wingsOwned)
	return if ok then value else 0
end

local function effectNames(effects: { string }): { string }
	local names = {}
	for _, effectId in Value.resolveEffects(effects) do
		table.insert(names, Format.name(effectId))
	end
	return names
end

local function find(data: DataService.Data, uid: unknown): Value.CaughtMonster?
	if typeof(uid) ~= "string" then
		return nil
	end
	for _, caught in data.storage do
		if caught.uid == uid then
			return caught
		end
	end
	return nil
end

local function viewFor(data: DataService.Data): View
	local kinds: { [string]: number } = {}
	for _, caught in data.storage do
		kinds[caught.monsterId] = (kinds[caught.monsterId] or 0) + 1
	end
	local rows: { Row } = {}
	for _, caught in data.storage do
		local monster = Monsters[caught.monsterId]
		if not monster or not caught.uid then
			continue
		end
		local variant = if caught.variant then `{caught.variant} ` else ""
		local pullProblem = VariantMachine.problem(caught)
		table.insert(rows, {
			uid = caught.uid,
			monsterId = caught.monsterId,
			name = Format.monsterName(caught),
			kind = `{variant}{caught.size} {monster.rarity}`,
			effects = effectNames(caught.effects),
			weight = Weight.text(caught.kg or 0),
			look = InventoryService.lookOf(caught),
			color = MonsterModel.color(monster.rarity),
			value = valueOf(caught, data.wingsOwned),
			locked = caught.locked == true,
			twins = (kinds[caught.monsterId] or 1) - 1,
			chance = Merge.chance(caught.monsterId),
			variant = caught.variant,
			pullProblem = if pullProblem then PullProblems[pullProblem] else nil,
			pullFee = VariantMachine.fee(valueOf(caught, data.wingsOwned)),
		})
	end
	-- Kinds you can merge first, then by kind and most valuable first.
	table.sort(rows, function(a, b)
		if (a.twins > 0) ~= (b.twins > 0) then
			return a.twins > 0
		end
		if a.monsterId ~= b.monsterId then
			return a.monsterId < b.monsterId
		end
		return if a.value == b.value then a.uid < b.uid else a.value > b.value
	end)
	return { monsters = rows }
end

local Problems: { [string]: string } = {
	Same = "Pick two different monsters.",
	Different = "Only two of the same kind can be merged.",
	Locked = "That one is hearted (♥). Un-heart it in your Backpack to give it away.",
	Unknown = "Those monsters can't be merged.",
}

-- The two monsters, or why they can't be merged.
local function pair(data: DataService.Data, mainUid: unknown, donorUid: unknown): (any, any, string?)
	local main, donor = find(data, mainUid), find(data, donorUid)
	if not main or not donor then
		return nil, nil, "Those monsters aren't in your Backpack any more."
	end
	local problem = Merge.problem(main, donor)
	if problem then
		return nil, nil, Problems[problem]
	end
	return main, donor, nil
end

PreviewRemote.OnServerInvoke = function(player: Player, mainUid: unknown, donorUid: unknown): Preview
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	local main, donor, problem = pair(data, mainUid, donorUid)
	if problem then
		return { ok = false, message = problem }
	end
	local result = Merge.preview(main, donor)
	local before = Value.resolveEffects(main.effects)
	local combos = {}
	for _, effectId in Value.resolveEffects(result.effects) do
		if Effects.Combos[effectId] and not table.find(before, effectId) then
			table.insert(combos, Format.name(effectId))
		end
	end
	return {
		ok = true,
		message = "",
		weight = Weight.text(result.kg or 0),
		size = result.size,
		effects = effectNames(result.effects),
		combos = combos,
		chance = Merge.chance(main.monsterId),
		fee = Merge.fee(valueOf(donor, data.wingsOwned)),
		value = valueOf(result, data.wingsOwned),
	}
end

MergeRemote.OnServerInvoke = function(player: Player, mainUid: unknown, donorUid: unknown): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	if not Counter.isNear(player, counter) then
		return { ok = false, message = "Walk up to the Merger to merge.", view = viewFor(data) }
	end
	if busy[player] then
		return { ok = false, message = "One merge at a time!", view = viewFor(data) }
	end
	local main, donor, problem = pair(data, mainUid, donorUid)
	if problem then
		return { ok = false, message = problem, view = viewFor(data) }
	end
	local fee = Merge.fee(valueOf(donor, data.wingsOwned))
	if not DataService.addMoney(player, -fee) then
		return { ok = false, message = `You need {Format.money(fee)} for the fee.`, view = viewFor(data) }
	end

	busy[player] = true
	local name = Format.monsterName(main)
	local won = Merge.roll(main.monsterId)
	local message
	local madeCombo = false
	if won then
		local before = Value.resolveEffects(main.effects)
		local size = main.size
		Merge.apply(main, donor)
		local combo = Value.newCombo(before, Value.resolveEffects(main.effects))
		message = `Merged! Your {name} now weighs {Weight.text(main.kg or 0)}`
		if main.size ~= size then
			message ..= ` and is {main.size}`
		end
		message ..= "."
		if combo then
			madeCombo = true
			CareService.discoverCombo(data, combo)
			message ..= ` It became a {Format.name(combo)}!`
		end
	else
		message =
			`The merge failed... the other {Format.name(donor.monsterId)} dissolved. Your {name} is unchanged.`
	end
	MansionService.removeMonsters(player, { [donor.uid :: string] = true })
	busy[player] = nil
	MissionService.record(player, "Merge", { won = won })
	if madeCombo then
		MissionService.record(player, "Combo")
	end
	DataService.saveSoon(player)
	Notify.toast(player, message)
	return { ok = true, won = won, message = message, view = viewFor(data) }
end

PullRemote.OnServerInvoke = function(player: Player, uid: unknown): PullResult
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	if not Counter.isNear(player, counter) then
		return { ok = false, message = "Walk up to the Merger to use the machine.", view = viewFor(data) }
	end
	if busy[player] then
		return { ok = false, message = "One at a time!", view = viewFor(data) }
	end
	local caught = find(data, uid)
	if not caught then
		return { ok = false, message = "That monster isn't in your Backpack any more.", view = viewFor(data) }
	end
	local problem = VariantMachine.problem(caught)
	if problem then
		return { ok = false, message = PullProblems[problem], view = viewFor(data) }
	end
	local fee = VariantMachine.fee(valueOf(caught, data.wingsOwned))
	if not DataService.addMoney(player, -fee) then
		return { ok = false, message = `You need {Format.money(fee)} for the fee.`, view = viewFor(data) }
	end

	busy[player] = true
	local name = Format.monsterName(caught)
	local index, variant = VariantMachine.roll(caught)
	local used = VariantMachine.apply(caught, index, variant)
	local message = if variant
		then `{string.upper(variant)}! The machine ate {Format.name(used)} and your {name} came out {variant}!`
		else `No luck... the machine ate {Format.name(used)}. Your {name} is still {caught.variant or "plain"}.`
	busy[player] = nil
	DataService.saveSoon(player)
	Notify.toast(player, message)
	return {
		ok = true,
		won = variant ~= nil,
		message = message,
		used = Format.name(used),
		variant = variant,
		view = viewFor(data),
	}
end

GetList.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	return if data then viewFor(data) else nil
end

function MergerService.start()
	remotes.Parent = ReplicatedStorage
	counter = Counter.prompt("Merger", "The Merger", function(player, option)
		local at = counter
		if at and DataService.isLoaded(player) then
			if option == "Variant" then
				OpenVariant:FireClient(player, at.WorldPosition)
			else
				Open:FireClient(player, at.WorldPosition)
			end
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return MergerService
