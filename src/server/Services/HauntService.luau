--!strict
-- Roaming effects (#11): every few minutes each fed monster in an online player's mansion
-- may pick up a haunted effect (rules in Util/Haunting, numbers in Config/Effects).
-- Familiarity, more wings and a Blood Moon raise the odds; a live Watcher event adds its own
-- effect to the pick. When two effects make a secret combo they merge, the owner is told and
-- the combo goes into their Codex (data.codex.combos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(ReplicatedStorage.Shared.Util.Care)
local Effects = require(ReplicatedStorage.Shared.Config.Effects)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Haunting = require(ReplicatedStorage.Shared.Util.Haunting)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local CareService = require(script.Parent.CareService)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)
local Notify = require(script.Parent.Parent.Notify)
local WatcherService = require(script.Parent.WatcherService)

local HauntService = {}

local MaxToasts = 2 -- more new effects than this at once get one summary message

local random = Random.new()

-- Rolls once for every monster in the player's mansion (force: every one that can take an
-- effect gets one). Returns how many picked up an effect.
function HauntService.rollFor(player: Player, force: boolean?): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local now = os.time()
	local event = WatcherService.current()
	local messages: { string } = {}
	local combos: { string } = {}
	for _, caught in data.monsters do
		Care.settle(caught, now)
		local before = Value.resolveEffects(caught.effects)
		local effectId = Haunting.roll(caught, data.wingsOwned, event, random, force)
		if effectId then
			table.insert(caught.effects, effectId)
			local name = Format.name(caught.monsterId)
			local combo = Value.newCombo(before, Value.resolveEffects(caught.effects))
			if combo then
				CareService.discoverCombo(data, combo)
				local article = if string.match(combo, "^[AEIOU]") then "an" else "a"
				table.insert(combos, `Your {name} turned into {article} {combo}! You found a secret combo.`)
			else
				table.insert(messages, `Your {name} picked up {Format.name(effectId)}!`)
			end
		end
	end
	local gained = #messages + #combos
	if gained == 0 then
		return 0
	end
	MansionService.refreshMonsters(player)
	for _, message in combos do
		Notify.toast(player, message)
	end
	if #messages > MaxToasts then
		Notify.toast(player, `{#messages} of your monsters picked up new haunted effects!`)
	else
		for _, message in messages do
			Notify.toast(player, message)
		end
	end
	return gained
end

function HauntService.start()
	task.spawn(function()
		while true do
			task.wait(Effects.RoamRollSeconds)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					HauntService.rollFor(player)
				end)
				if not ok then
					warn(`HauntService: rolling effects for {player.Name} failed: {err}`)
				end
			end
		end
	end)
end

return HauntService
