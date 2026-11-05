--!strict
-- Fills each player's Codex (rules in Shared.Util.Codex) and sends it to the Codex window
-- (client CodexController). Every few seconds it looks over the monsters in the mansion and
-- the Backpack, so whatever way a monster, variant or effect turned up (a catch, an event,
-- a cake) it's written down. New finds are quiet (Giles 2026-11-05: too many pop-ups); the
-- Codex button shows how many rewards wait instead (player attribute CodexReady).
-- Finishing a goal on a page (every monster found, every one in Gold, every effect, ...) and
-- every first find of a monster or colour earn a Codex reward (Config/CodexRewards) that the
-- player claims by tapping it in the Codex. Nothing is paid automatically.
--
-- Remotes in ReplicatedStorage.CodexRemotes:
--   GetView  client -> server () -> View?
--   Claim    client -> server ({ string } reward keys, or "all") -> (number paid, View?)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codex = require(ReplicatedStorage.Shared.Util.Codex)
local Effects = require(ReplicatedStorage.Shared.Config.Effects)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)

local CodexService = {}

export type MonsterCard = {
	id: string,
	name: string, -- "???" until found
	rarity: string,
	color: Color3,
	found: boolean,
	variants: { [string]: boolean }, -- Silver, Gold, Shiny, Rainbow
	look: string?, -- preview in PlayerGui.InventoryPreviews, once found
	unclaimed: number, -- first-find money waiting on this card (0 when none)
	claimKeys: { string }, -- the reward keys to claim it with
}
-- A goal's reward by goal ("Found", "Gold", "Effects", ...): `claimed` once fully paid,
-- `ready` (with its key and what it pays now) when it waits to be claimed.
export type Reward = { amount: number, claimed: boolean, ready: number?, key: string }
export type Rewards = { [string]: Reward }
export type Page = {
	id: string,
	title: string,
	progress: Codex.Progress,
	monsters: { MonsterCard },
	rewards: Rewards,
	-- Zone pages: catch every monster of a rarity, Common first. Empty on the event page.
	rarityGoals: { { id: string, color: Color3, found: number, total: number } },
}
export type EffectCard = {
	id: string,
	name: string,
	multiplier: number,
	found: boolean,
	hint: string, -- where it comes from (effects), or the recipe once found (combos)
	combo: boolean,
	recipe: { string }?, -- combos you've made: the two effect names
	known: number?, -- combos: how many of its two effects you've found (the clue for secret ones)
	usedIn: { string }?, -- effects: the combos you've made with it
}
export type View = { pages: { Page }, effects: { EffectCard }, effectRewards: Rewards, variants: { string } }

local CheckSeconds = 3
local MaxClaimKeys = 500 -- more keys than this in one Claim are refused

local remotes = Instance.new("Folder")
remotes.Name = "CodexRemotes"
local GetView = Instance.new("RemoteFunction")
GetView.Name = "GetView"
GetView.Parent = remotes
local Claim = Instance.new("RemoteFunction")
Claim.Name = "Claim"
Claim.Parent = remotes

local sections = Codex.sections()

-- Notes everything the player owns right now and updates how many rewards wait.
local function check(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	for _, list in { data.monsters, data.storage } do
		for _, caught in list do
			Codex.note(data.codex, caught)
		end
	end
	player:SetAttribute("CodexReady", #Codex.pending(data.codex, sections))
end

local function viewFor(data: DataService.Data): View
	local codex = data.codex
	local waiting: { [string]: Codex.Reward } = {}
	for _, reward in Codex.pending(codex, sections) do
		waiting[reward.key] = reward
	end
	local function rewardsFor(page: string, goals: { string }): Rewards
		local rewards: Rewards = {}
		for _, goal in goals do
			local key = Codex.rewardKey(page, goal)
			local ready = waiting[key]
			rewards[goal] = {
				amount = Codex.rewardAmount(page, goal),
				claimed = Codex.claimed(codex, page, goal) and not ready,
				ready = if ready then ready.amount else nil,
				key = key,
			}
		end
		return rewards
	end
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
			local unclaimed, claimKeys = 0, {}
			for _, variant in { "", table.unpack(Codex.VariantOrder) } do
				local key = Codex.findKey(id, if variant == "" then nil else variant)
				local ready = waiting[key]
				if ready then
					unclaimed += ready.amount
					table.insert(claimKeys, key)
				end
			end
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
				unclaimed = unclaimed,
				claimKeys = claimKeys,
			})
		end
		local progress = Codex.progress(codex, section.monsters)
		local goals = table.clone(pageGoals)
		local rarityGoals = {}
		for _, rarity in Codex.RarityOrder do
			local counts = progress.rarities[rarity]
			if counts and Codex.rewardAmount(section.id, rarity) > 0 then
				table.insert(goals, rarity)
				table.insert(rarityGoals, {
					id = rarity,
					color = MonsterModel.color(rarity),
					found = counts.found,
					total = counts.total,
				})
			end
		end
		table.insert(pages, {
			id = section.id,
			title = section.title,
			progress = progress,
			monsters = cards,
			rewards = rewardsFor(section.id, goals),
			rarityGoals = rarityGoals,
		})
	end

	local effects: { EffectCard } = {}
	local foundEffects = if typeof(codex.effects) == "table" then codex.effects else {}
	local foundCombos = if typeof(codex.combos) == "table" then codex.combos else {}
	for _, id in Codex.effectIds() do
		local effect = Effects.List[id]
		local usedIn = {}
		for _, comboId in Codex.comboIds() do
			if foundCombos[comboId] and table.find(Effects.Combos[comboId].recipe, id) then
				table.insert(usedIn, Format.name(comboId))
			end
		end
		table.insert(effects, {
			id = id,
			name = Format.name(id),
			multiplier = effect.multiplier,
			found = foundEffects[id] == true,
			hint = Codex.whereFrom(effect),
			combo = false,
			usedIn = usedIn,
		})
	end
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
			recipe = if found then parts else nil,
			known = Codex.recipeKnown(codex, id),
		})
	end
	return {
		pages = pages,
		effects = effects,
		effectRewards = rewardsFor(Codex.EffectsPage, { "Effects", "Combos" }),
		variants = Codex.VariantOrder,
	}
end

GetView.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	check(player)
	return viewFor(data)
end

-- Pays the listed waiting rewards (or all of them), once each. Unknown or already claimed
-- keys are ignored, so a client can't claim anything that isn't really waiting.
Claim.OnServerInvoke = function(player: Player, keys: any): (number, View?)
	local data = DataService.get(player)
	if not data then
		return 0, nil
	end
	local wanted: { [string]: boolean }? = nil -- nil claims everything
	if keys ~= "all" then
		if typeof(keys) ~= "table" or #keys > MaxClaimKeys then
			return 0, nil
		end
		local set: { [string]: boolean } = {}
		for _, key in keys do
			if typeof(key) == "string" then
				set[key] = true
			end
		end
		wanted = set
	end
	check(player)
	local total = 0
	for _, reward in Codex.claim(data.codex, sections, wanted) do
		total += reward.amount
	end
	if total > 0 and DataService.addMoney(player, total) then
		AnalyticsService.money(player, total, "Gameplay", "CodexReward")
	end
	player:SetAttribute("CodexReady", #Codex.pending(data.codex, sections))
	return total, viewFor(data)
end

function CodexService.start()
	remotes.Parent = ReplicatedStorage
	task.spawn(function()
		while true do
			task.wait(CheckSeconds)
			for _, player in Players:GetPlayers() do
				if DataService.isLoaded(player) then
					local ok, err = pcall(check, player)
					if not ok then
						warn(`CodexService: checking {player.Name} failed: {err}`)
					end
				end
			end
		end
	end)
end

return CodexService
