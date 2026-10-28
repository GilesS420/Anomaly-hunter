--!strict
-- Roaming effects (#11): every few minutes each monster in an online player's mansion
-- may pick up a haunted effect (rules in Util/Haunting, numbers in Config/Effects).
-- Familiarity, more wings and a Blood Moon raise the odds. While a Watcher event is live,
-- every monster also rolls for that event's own effect every Events.EffectRollSeconds. When
-- two effects make a secret combo they merge, the owner is told and the combo goes into
-- their Codex (data.codex.combos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(ReplicatedStorage.Shared.Util.Care)
local Effects = require(ReplicatedStorage.Shared.Config.Effects)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Haunting = require(ReplicatedStorage.Shared.Util.Haunting)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local CareService = require(script.Parent.CareService)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)
local Notify = require(script.Parent.Parent.Notify)
local MissionService = require(script.Parent.MissionService)
local WatcherService = require(script.Parent.WatcherService)

local HauntService = {}

local MaxToasts = 2 -- more new effects than this at once get one summary message

local random = Random.new()

type Gains = { messages: { string }, combos: { string } }

-- Puts `after` (the monster's effects with `effectId` in) on the monster and notes what to
-- tell the owner.
local function gain(data: any, caught: Value.CaughtMonster, effectId: string, after: { string }, gains: Gains)
	local before = Value.resolveEffects(caught.effects)
	local lost: string? = nil
	for _, id in caught.effects do
		if not table.find(after, id) then
			lost = id
		end
	end
	caught.effects = after
	local name = Format.monsterName(caught)
	local combo = Value.newCombo(before, Value.resolveEffects(caught.effects))
	if combo then
		CareService.discoverCombo(data, combo)
		local article = if string.match(combo, "^[AEIOU]") then "an" else "a"
		table.insert(gains.combos, `Your {name} turned into {article} {combo}! You found a secret combo.`)
	elseif lost then
		table.insert(gains.messages, `Your {name} swapped {Format.name(lost)} for {Format.name(effectId)}!`)
	else
		table.insert(gains.messages, `Your {name} picked up {Format.name(effectId)}!`)
	end
end

-- Rebuilds the changed monsters and tells the owner. Returns how many gained an effect.
local function announce(player: Player, gains: Gains): number
	local gained = #gains.messages + #gains.combos
	if gained == 0 then
		return 0
	end
	MissionService.record(player, "Effect", { amount = gained })
	if #gains.combos > 0 then
		MissionService.record(player, "Combo")
	end
	MansionService.refreshMonsters(player)
	for _, message in gains.combos do
		Notify.toast(player, message)
		Notify.log(player, message)
	end
	for _, message in gains.messages do
		Notify.log(player, message) -- every one, even when the toast is a summary
	end
	if #gains.messages > MaxToasts then
		Notify.toast(player, `{#gains.messages} of your monsters picked up new haunted effects!`)
	else
		for _, message in gains.messages do
			Notify.toast(player, message)
		end
	end
	return gained
end

-- Rolls once for every monster in the player's mansion (force: every one that can take an
-- effect gets one). Returns how many picked up an effect.
function HauntService.rollFor(player: Player, force: boolean?): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local now = os.time()
	-- A live event raises the roaming odds (Blood Moon); its own effect has its own roll below.
	local event = WatcherService.current()
	local odds = if event then { effectOddsMultiplier = event.effectOddsMultiplier } else nil
	local gains: Gains = { messages = {}, combos = {} }
	for _, caught in data.monsters do
		Care.settle(caught, now)
		local effectId = Haunting.roll(caught, data.wingsOwned, odds, random, force)
		if effectId then
			local after = table.clone(caught.effects)
			table.insert(after, effectId)
			gain(data, caught, effectId, after, gains)
		end
	end
	return announce(player, gains)
end

-- One event roll for every monster in the player's mansion while `event` is live (force:
-- every one that can take the event's effect gets it, Studio /haunt). Returns how many
-- picked up an effect.
function HauntService.eventRollFor(player: Player, event: Events.WatcherEvent, force: boolean?): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local now = os.time()
	local gains: Gains = { messages = {}, combos = {} }
	for _, caught in data.monsters do
		Care.settle(caught, now)
		local effectId: string?, after: { string }?
		local forced = if force then event.effect else nil
		if forced then
			effectId, after = forced, Haunting.withEffect(caught.effects, forced)
		else
			effectId, after = Haunting.eventRoll(caught, data.wingsOwned, event, random)
		end
		if effectId and after then
			gain(data, caught, effectId, after, gains)
		end
	end
	return announce(player, gains)
end

-- Gives one monster in the player's mansion this effect right away (the tutorial shows
-- off an effect on the first catch). Returns whether a monster could take it.
function HauntService.give(player: Player, effectId: string): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	for _, caught in data.monsters do
		local after = Haunting.withEffect(caught.effects, effectId)
		if after then
			local gains: Gains = { messages = {}, combos = {} }
			gain(data, caught, effectId, after, gains)
			return announce(player, gains) > 0
		end
	end
	return false
end

local function forEachPlayer(label: string, roll: (Player) -> ())
	for _, player in Players:GetPlayers() do
		local ok, err = pcall(function()
			roll(player)
		end)
		if not ok then
			warn(`HauntService: {label} for {player.Name} failed: {err}`)
		end
	end
end

function HauntService.start()
	task.spawn(function()
		while true do
			task.wait(Effects.RoamRollSeconds)
			forEachPlayer("rolling effects", function(player)
				HauntService.rollFor(player)
			end)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Events.EffectRollSeconds)
			local event = WatcherService.current()
			if event and event.effect then
				forEachPlayer("rolling event effects", function(player)
					HauntService.eventRollFor(player, event)
				end)
			end
		end
	end)
end

return HauntService
