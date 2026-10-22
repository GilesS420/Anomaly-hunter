--!strict
-- Fills each player's Codex (rules in Shared.Util.Codex) and sends it to the Codex window
-- (client CodexController). Every few seconds it looks over the monsters in the mansion and
-- the Backpack, so whatever way a monster, variant or effect turned up (a catch, an event,
-- a cake) it's written down; the first look after joining fills in older saves quietly.
-- New finds get a toast, except combos (HauntService already announces those).
-- Finishing a goal on a page (every monster found, every one in Gold, every effect, ...) pays
-- its Codex reward once (Config/CodexRewards), straight into the player's money.
--
-- Remotes in ReplicatedStorage.CodexRemotes:
--   GetView  client -> server () -> View?

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codex = require(ReplicatedStorage.Shared.Util.Codex)
local Effects = require(ReplicatedStorage.Shared.Config.Effects)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)

local CodexService = {}

export type MonsterCard = {
	id: string,
	name: string, -- "???" until found
	rarity: string,
	color: Color3,
	found: boolean,
	variants: { [string]: boolean }, -- Silver, Gold, Shiny, Rainbow
	look: string?, -- preview in PlayerGui.InventoryPreviews, once found
}
-- A goal's reward and whether it's been paid, by goal ("Found", "Gold", "Effects", ...).
export type Rewards = { [string]: { amount: number, claimed: boolean } }
export type Page = {
	id: string,
	title: string,
	progress: Codex.Progress,
	monsters: { MonsterCard },
	rewards: Rewards,
}
export type EffectCard = {
	id: string,
	name: string,
	multiplier: number,
	found: boolean,
	hint: string, -- where it comes from (effects), or the recipe once found (combos)
	combo: boolean,
}
export type View = { pages: { Page }, effects: { EffectCard }, effectRewards: Rewards, variants: { string } }

local CheckSeconds = 3
local MaxToasts = 2 -- more finds than this at once get one summary message

local checked: { [Player]: boolean } = {} -- had their first (quiet) look this visit

local remotes = Instance.new("Folder")
remotes.Name = "CodexRemotes"
local GetView = Instance.new("RemoteFunction")
GetView.Name = "GetView"
GetView.Parent = remotes

local sections = Codex.sections()

local function message(find: Codex.Found): string?
	local name = Format.name(find.id)
	if find.kind == "Monster" then
		return `New in your Codex: {name}!`
	elseif find.kind == "Variant" then
		return `Codex goal reached: {find.variant} {name}!`
	elseif find.kind == "Effect" then
		return `New effect in your Codex: {name}!`
	end
	return nil -- combos are announced by HauntService
end

-- Notes everything the player owns right now; tells them what's new unless quiet.
local function check(player: Player, quiet: boolean)
	local data = DataService.get(player)
	if not data then
		return
	end
	local messages: { string } = {}
	for _, list in { data.monsters, data.storage } do
		for _, caught in list do
			for _, find in Codex.note(data.codex, caught) do
				local text = message(find)
				if text then
					table.insert(messages, text)
				end
			end
		end
	end
	-- Rewards are paid even on the quiet first look, so older saves get what they earned.
	for _, reward in Codex.newRewards(data.codex, sections) do
		DataService.addMoney(player, reward.amount)
		local page = if reward.page == Codex.EffectsPage then "" else ` on {Format.name(reward.page)}`
		local goal = if reward.goal == "Found" then "Every monster found" else `Every {reward.goal}`
		if reward.goal == "Effects" then
			goal = "Every effect found"
		elseif reward.goal == "Combos" then
			goal = "Every secret combo made"
		end
		Notify.toast(player, `Codex reward! {goal}{page}: +{Format.money(reward.amount)}`)
	end
	if quiet or #messages == 0 then
		return
	end
	if #messages > MaxToasts then
		Notify.toast(player, `{#messages} new entries in your Codex!`)
	else
		for _, text in messages do
			Notify.toast(player, text)
		end
	end
end

local function rewardsFor(codex: { [string]: any }, page: string, goals: { string }): Rewards
	local rewards: Rewards = {}
	for _, goal in goals do
		rewards[goal] =
			{ amount = Codex.rewardAmount(page, goal), claimed = Codex.claimed(codex, page, goal) }
	end
	return rewards
end

local function viewFor(data: DataService.Data): View
	local codex = data.codex
	local pageGoals = { "Found" }
	for _, variant in Codex.VariantOrder do
		table.insert(pageGoals, variant)
	end
	local pages: { Page } = {}
	for _, section in sections do
		local cards: { MonsterCard } = {}
		for _, id in section.monsters do
			local monster = Monsters[id]
			local found = Codex.has(codex, id)
			local variants: { [string]: boolean } = {}
			for _, variant in Codex.VariantOrder do
				variants[variant] = Codex.has(codex, id, variant)
			end
			table.insert(cards, {
				id = id,
				name = if found then Format.name(id) else "???",
				rarity = monster.rarity,
				color = MonsterModel.color(monster.rarity),
				found = found,
				variants = variants,
				look = if found then InventoryService.codexLook(id) else nil,
			})
		end
		table.insert(pages, {
			id = section.id,
			title = section.title,
			progress = Codex.progress(codex, section.monsters),
			monsters = cards,
			rewards = rewardsFor(codex, section.id, pageGoals),
		})
	end

	local effects: { EffectCard } = {}
	local foundEffects = if typeof(codex.effects) == "table" then codex.effects else {}
	for _, id in Codex.effectIds() do
		local effect = Effects.List[id]
		table.insert(effects, {
			id = id,
			name = Format.name(id),
			multiplier = effect.multiplier,
			found = foundEffects[id] == true,
			hint = Codex.whereFrom(effect),
			combo = false,
		})
	end
	local foundCombos = if typeof(codex.combos) == "table" then codex.combos else {}
	for _, id in Codex.comboIds() do
		local combo = Effects.Combos[id]
		local found = foundCombos[id] == true
		local parts = {}
		for _, part in combo.recipe do
			table.insert(parts, Format.name(part))
		end
		table.insert(effects, {
			id = id,
			name = if found then Format.name(id) else "Secret combo",
			multiplier = combo.multiplier,
			found = found,
			-- The recipe stays secret until you've made it.
			hint = if found then table.concat(parts, " + ") else "??? + ???",
			combo = true,
		})
	end
	return {
		pages = pages,
		effects = effects,
		effectRewards = rewardsFor(codex, Codex.EffectsPage, { "Effects", "Combos" }),
		variants = Codex.VariantOrder,
	}
end

GetView.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	check(player, not checked[player])
	checked[player] = true
	return viewFor(data)
end

function CodexService.start()
	remotes.Parent = ReplicatedStorage
	task.spawn(function()
		while true do
			task.wait(CheckSeconds)
			for _, player in Players:GetPlayers() do
				if DataService.isLoaded(player) then
					local ok, err = pcall(check, player, not checked[player])
					checked[player] = true
					if not ok then
						warn(`CodexService: checking {player.Name} failed: {err}`)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		checked[player] = nil
	end)
end

return CodexService
