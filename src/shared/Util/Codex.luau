--!strict
-- The Codex: every monster you've ever caught, in which catch variants (Silver, Gold, Shiny,
-- Rainbow: extra goals for every monster), and every haunted effect and secret combo you've
-- had. The save keeps it in data.codex:
--   monsters  [monsterId] = { Plain = true, Gold = true, ... }  (Plain: caught without a variant)
--   effects   [effectId] = true
--   combos    [comboId] = true
--   rewards   ["PumpkinGraveyard:Gold"] = 180000000  (Codex reward paid: the amount, or `true` in
--             saves from before 2026-11-05, see Config/CodexRewards; first finds use
--             "Find:Gloomlet" and "Find:Gloomlet:Gold"). Rewards wait until the player claims them.
-- Only launch content is listed (zones and events that are in the game). Pure functions so
-- they can be tested outside Roblox; the server fills it (CodexService), the client draws it
-- (CodexController).

local CodexRewards = require("../Config/CodexRewards")
local Effects = require("../Config/Effects")
local Events = require("../Config/Events")
local Monsters = require("../Config/Monsters")
local Rarities = require("../Config/Rarities")
local Shop = require("../Config/Shop")
local Variants = require("../Config/Variants")
local Zones = require("../Config/Zones")
local Value = require("./Value")

local Codex = {}

export type Section = { id: string, title: string, monsters: { string } }
export type Progress = {
	found: number,
	total: number,
	variants: { [string]: number },
	rarities: { [string]: { found: number, total: number } }, -- only rarities on the page
}
-- A Codex reward: a page goal (goal = "Found", "Gold", "Common", "Effects", ...) or a first
-- find on a monster's card (goal = "Find" or a variant, `monster` set).
export type Reward = {
	key: string,
	page: string,
	goal: string,
	amount: number, -- what claiming it pays now
	total: number, -- what the save holds once it's paid
	topUp: boolean,
	monster: string?,
}
export type Found = { kind: "Monster" | "Variant" | "Effect" | "Combo", id: string, variant: string? }

Codex.Plain = "Plain"

-- The variants as goals, commonest first (Config/Variants lists them rarest first).
Codex.VariantOrder = {} :: { string }
for i = #Variants, 1, -1 do
	table.insert(Codex.VariantOrder, Variants[i].id)
end

-- The zone rarities as goals, Common first (event-only rarities are left out).
Codex.RarityOrder = {} :: { string }
for id, rarity in Rarities do
	if not rarity.eventOnly then
		table.insert(Codex.RarityOrder, id)
	end
end
table.sort(Codex.RarityOrder, function(a, b)
	return Rarities[a].order < Rarities[b].order
end)

-- Cheapest and commonest first, so a zone's page reads from Common up to Divine.
local function byRarity(a: string, b: string): boolean
	local ma, mb = Monsters[a], Monsters[b]
	local oa, ob = Rarities[ma.rarity].order, Rarities[mb.rarity].order
	if oa ~= ob then
		return oa < ob
	end
	if ma.baseValue ~= mb.baseValue then
		return ma.baseValue < mb.baseValue
	end
	return a < b
end

-- One page per launch zone, then one for the Watcher event monsters.
function Codex.sections(): { Section }
	local sections: { Section } = {}
	for _, zone in Zones.List do
		if zone.launch then
			local ids = {}
			for id, monster in Monsters do
				if monster.zone == zone.index then
					table.insert(ids, id)
				end
			end
			table.sort(ids, byRarity)
			table.insert(sections, { id = zone.id, title = zone.name, monsters = ids })
		end
	end
	local eventIds = {}
	for _, event in Events.List do
		if event.launch then
			local lists: { { [string]: number } } = {}
			if event.monsters then
				table.insert(lists, event.monsters)
			end
			local sets: { Events.MonsterSet } = event.monsterSets or {}
			for _, set in sets do
				table.insert(lists, set.monsters)
			end
			for _, spawns in lists do
				for id in spawns do
					if Monsters[id] and not table.find(eventIds, id) then
						table.insert(eventIds, id)
					end
				end
			end
		end
	end
	table.sort(eventIds, byRarity)
	if #eventIds > 0 then
		table.insert(sections, { id = "Events", title = "Watcher Events", monsters = eventIds })
	end
	return sections
end

local function launchedEvent(id: string?): boolean
	for _, event in Events.List do
		if event.id == id then
			return event.launch
		end
	end
	return false
end

local function soldInBakery(id: string?): boolean
	for _, item in Shop.Bakery do
		if item.id == id then
			return true
		end
	end
	return false
end

-- Whether an effect can be had in the game right now (not from an event or cake still to come).
function Codex.effectAvailable(effect: Effects.Effect): boolean
	if effect.source == "Event" or effect.source == "Survive" then
		return launchedEvent(effect.from)
	elseif effect.source == "Food" then
		return soldInBakery(effect.from)
	end
	return true
end

-- The effects the Codex lists, cheapest first, then the combos.
function Codex.effectIds(): { string }
	local ids = {}
	for id, effect in Effects.List do
		if Codex.effectAvailable(effect) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local ea, eb = Effects.List[a], Effects.List[b]
		return if ea.multiplier == eb.multiplier then a < b else ea.multiplier < eb.multiplier
	end)
	return ids
end

function Codex.comboIds(): { string }
	local ids = {}
	for id in Effects.Combos do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local ca, cb = Effects.Combos[a], Effects.Combos[b]
		return if ca.multiplier == cb.multiplier then a < b else ca.multiplier < cb.multiplier
	end)
	return ids
end

-- Where to look for an effect, shown even before you've found it.
function Codex.whereFrom(effect: Effects.Effect): string
	if effect.source == "Roam" then
		return "Monsters pick it up roaming your mansion"
	elseif effect.source == "Critter" then
		return "Cheap monsters (base value up to $50K) pick it up roaming your mansion"
	elseif effect.source == "Food" then
		return "From a Bakery cake"
	elseif effect.source == "Catch" then
		return "Caught with the right vacuum"
	elseif effect.source == "Event" then
		return "During a Watcher event"
	end
	return "Surviving the Watcher"
end

local function tableIn(parent: { [string]: any }, key: string): { [string]: any }
	local existing = parent[key]
	if typeof(existing) == "table" then
		return existing
	end
	local made = {}
	parent[key] = made
	return made
end

-- Writes one owned monster into the Codex: its kind, its variant, its effects and combos.
-- Returns what was new (empty if nothing).
function Codex.note(codex: { [string]: any }, caught: Value.CaughtMonster): { Found }
	local found: { Found } = {}
	if not Monsters[caught.monsterId] then
		return found
	end
	local monsters = tableIn(codex, "monsters")
	local entry = monsters[caught.monsterId]
	if typeof(entry) ~= "table" then
		entry = {}
		monsters[caught.monsterId] = entry
		table.insert(found, { kind = "Monster", id = caught.monsterId })
	end
	local variant = caught.variant or Codex.Plain
	if not entry[variant] then
		entry[variant] = true
		if variant ~= Codex.Plain then
			table.insert(found, { kind = "Variant", id = caught.monsterId, variant = variant })
		end
	end
	local effects = tableIn(codex, "effects")
	for _, effectId in caught.effects do
		if Effects.List[effectId] and not effects[effectId] then
			effects[effectId] = true
			table.insert(found, { kind = "Effect", id = effectId })
		end
	end
	local combos = tableIn(codex, "combos")
	for _, effectId in Value.resolveEffects(caught.effects) do
		if Effects.Combos[effectId] and not combos[effectId] then
			combos[effectId] = true
			table.insert(found, { kind = "Combo", id = effectId })
		end
	end
	return found
end

-- Whether this monster (or, with a variant, that variant of it) is in the Codex.
function Codex.has(codex: { [string]: any }, monsterId: string, variant: string?): boolean
	local monsters = codex.monsters
	local entry = if typeof(monsters) == "table" then monsters[monsterId] else nil
	if typeof(entry) ~= "table" then
		return false
	end
	return variant == nil or entry[variant] == true
end

-- How much of a page is done: monsters found, and how many have each variant.
function Codex.progress(codex: { [string]: any }, monsterIds: { string }): Progress
	local progress: Progress = { found = 0, total = #monsterIds, variants = {}, rarities = {} }
	for _, variant in Codex.VariantOrder do
		progress.variants[variant] = 0
	end
	for _, id in monsterIds do
		local monster = Monsters[id]
		local rarity = if monster then progress.rarities[monster.rarity] else nil
		if monster and not rarity then
			rarity = { found = 0, total = 0 }
			progress.rarities[monster.rarity] = rarity
		end
		if rarity then
			rarity.total += 1
		end
		if Codex.has(codex, id) then
			progress.found += 1
			if rarity then
				rarity.found += 1
			end
			for _, variant in Codex.VariantOrder do
				if Codex.has(codex, id, variant) then
					progress.variants[variant] += 1
				end
			end
		end
	end
	return progress
end

Codex.EffectsPage = "Effects"

-- A goal's reward in a rates table (Config/CodexRewards, or its Old rates).
local function amountIn(rates: any, page: string, goal: string): number
	if rates.Rarities and rates.Rarities[goal] then
		return math.floor(rates.Rarities[goal] * (rates.RarityScale[page] or 0))
	end
	if page == Codex.EffectsPage then
		return if goal == "Effects" then rates.Effects elseif goal == "Combos" then rates.Combos else 0
	end
	return math.floor((rates.Pages[page] or 0) * (rates.Goals[goal] or 0))
end

-- What finishing a goal on a page pays (0 if that goal pays nothing).
function Codex.rewardAmount(page: string, goal: string): number
	return amountIn(CodexRewards, page, goal)
end

-- How much of a goal's reward is paid already. A save from before the 2026-11-05 raise holds
-- `true`: that's the old amount when old claims get topped up, otherwise all of it.
function Codex.paidSoFar(codex: { [string]: any }, page: string, goal: string): number
	local rewards = codex.rewards
	local mark = if typeof(rewards) == "table" then rewards[Codex.rewardKey(page, goal)] else nil
	if typeof(mark) == "number" then
		return mark
	elseif mark == true then
		return if CodexRewards.TopUpOldClaims then amountIn(CodexRewards.Old, page, goal) else math.huge
	end
	return 0
end

-- The goals of a monster page that are done: each rarity once every monster of it is caught,
-- "Found" once every monster is caught, then each variant once every monster has it.
function Codex.goalsDone(progress: Progress): { string }
	local done = {}
	for _, rarity in Codex.RarityOrder do
		local counts = progress.rarities[rarity]
		if counts and counts.total > 0 and counts.found >= counts.total then
			table.insert(done, rarity)
		end
	end
	if progress.total == 0 or progress.found < progress.total then
		return done
	end
	table.insert(done, "Found")
	for _, variant in Codex.VariantOrder do
		if (progress.variants[variant] or 0) >= progress.total then
			table.insert(done, variant)
		end
	end
	return done
end

-- How many of the listed effects and combos are in the Codex.
function Codex.effectProgress(codex: { [string]: any }): (number, number, number, number)
	local effects = if typeof(codex.effects) == "table" then codex.effects else {}
	local combos = if typeof(codex.combos) == "table" then codex.combos else {}
	local effectIds, comboIds = Codex.effectIds(), Codex.comboIds()
	local found, made = 0, 0
	for _, id in effectIds do
		found += if effects[id] then 1 else 0
	end
	for _, id in comboIds do
		made += if combos[id] then 1 else 0
	end
	return found, #effectIds, made, #comboIds
end

function Codex.rewardKey(page: string, goal: string): string
	return `{page}:{goal}`
end

-- Whether this goal's reward has been paid.
function Codex.claimed(codex: { [string]: any }, page: string, goal: string): boolean
	local rewards = codex.rewards
	return typeof(rewards) == "table" and rewards[Codex.rewardKey(page, goal)] ~= nil
end

-- First-find rewards: catching a monster for the first time ("Find"), and catching it in
-- each colour for the first time (the variant's id). Keyed apart from the page goals.
function Codex.findKey(monsterId: string, variant: string?): string
	return if variant then `Find:{monsterId}:{variant}` else `Find:{monsterId}`
end

function Codex.findAmount(monsterId: string, variant: string?): number
	local monster = Monsters[monsterId]
	if not monster then
		return 0
	end
	local multiplier = 1
	for _, entry in Variants do
		if entry.id == variant then
			multiplier = entry.multiplier
		end
	end
	return math.floor(monster.baseValue * CodexRewards.FindShare * multiplier)
end

-- Every reward waiting to be claimed; nothing is marked. Goals done but not fully paid come
-- first (one paid at an older, smaller amount waits with only the difference: `topUp`), then
-- first finds unless `withFinds` is false. `total` is what the save holds once it's claimed.
function Codex.pending(codex: { [string]: any }, sections: { Section }, withFinds: boolean?): { Reward }
	local reached: { { page: string, goal: string } } = {}
	for _, section in sections do
		for _, goal in Codex.goalsDone(Codex.progress(codex, section.monsters)) do
			table.insert(reached, { page = section.id, goal = goal })
		end
	end
	local found, effectTotal, made, comboTotal = Codex.effectProgress(codex)
	if effectTotal > 0 and found >= effectTotal then
		table.insert(reached, { page = Codex.EffectsPage, goal = "Effects" })
	end
	if comboTotal > 0 and made >= comboTotal then
		table.insert(reached, { page = Codex.EffectsPage, goal = "Combos" })
	end

	local waiting: { Reward } = {}
	for _, entry in reached do
		local amount = Codex.rewardAmount(entry.page, entry.goal)
		local before = Codex.paidSoFar(codex, entry.page, entry.goal)
		if amount > before then
			table.insert(waiting, {
				key = Codex.rewardKey(entry.page, entry.goal),
				page = entry.page,
				goal = entry.goal,
				amount = amount - before,
				total = amount,
				topUp = before > 0,
			})
		end
	end
	if withFinds == false then
		return waiting
	end
	local rewards = if typeof(codex.rewards) == "table" then codex.rewards else {}
	for _, section in sections do
		for _, id in section.monsters do
			if Codex.has(codex, id) then
				local goals: { string } = { "Find" }
				for _, variant in Codex.VariantOrder do
					if Codex.has(codex, id, variant) then
						table.insert(goals, variant)
					end
				end
				for i, goal in goals do
					local variant = if i == 1 then nil else goal
					local key = Codex.findKey(id, variant)
					local amount = Codex.findAmount(id, variant)
					if rewards[key] == nil and amount > 0 then
						table.insert(waiting, {
							key = key,
							page = section.id,
							goal = goal,
							amount = amount,
							total = amount,
							topUp = false,
							monster = id,
						})
					end
				end
			end
		end
	end
	return waiting
end

local function markPaid(codex: { [string]: any }, reward: Reward)
	tableIn(codex, "rewards")[reward.key] = reward.total
end

-- Claims the waiting rewards whose keys are listed (every one when `keys` is nil): marks them
-- paid and returns them, so the caller pays them out. Keys that aren't waiting do nothing.
function Codex.claim(codex: { [string]: any }, sections: { Section }, keys: { [string]: boolean }?): { Reward }
	local paid: { Reward } = {}
	for _, reward in Codex.pending(codex, sections) do
		if keys == nil or keys[reward.key] then
			markPaid(codex, reward)
			table.insert(paid, reward)
		end
	end
	return paid
end

-- Claims every waiting page goal (not first finds) at once. Used by the tests.
function Codex.newRewards(codex: { [string]: any }, sections: { Section }): { Reward }
	local paid = Codex.pending(codex, sections, false)
	for _, reward in paid do
		markPaid(codex, reward)
	end
	return paid
end

-- How many of a combo's two recipe effects are in the Codex (0, 1 or 2): the clue the Codex
-- shows for a combo you haven't made yet, without naming which effects they are.
function Codex.recipeKnown(codex: { [string]: any }, comboId: string): number
	local combo = Effects.Combos[comboId]
	local effects = codex.effects
	if not combo or typeof(effects) ~= "table" then
		return 0
	end
	local known = 0
	for _, part in combo.recipe do
		known += if effects[part] then 1 else 0
	end
	return known
end

return Codex
