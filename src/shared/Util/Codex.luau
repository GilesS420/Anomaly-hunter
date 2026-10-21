--!strict
-- The Codex: every monster you've ever caught, in which catch variants (Silver, Gold, Shiny,
-- Rainbow: extra goals for every monster), and every haunted effect and secret combo you've
-- had. The save keeps it in data.codex:
--   monsters  [monsterId] = { Plain = true, Gold = true, ... }  (Plain: caught without a variant)
--   effects   [effectId] = true
--   combos    [comboId] = true
-- Only launch content is listed (zones and events that are in the game). Pure functions so
-- they can be tested outside Roblox; the server fills it (CodexService), the client draws it
-- (CodexController).

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
export type Progress = { found: number, total: number, variants: { [string]: number } }
export type Found = { kind: "Monster" | "Variant" | "Effect" | "Combo", id: string, variant: string? }

Codex.Plain = "Plain"

-- The variants as goals, commonest first (Config/Variants lists them rarest first).
Codex.VariantOrder = {} :: { string }
for i = #Variants, 1, -1 do
	table.insert(Codex.VariantOrder, Variants[i].id)
end

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
		local spawns = event.monsters
		if event.launch and spawns then
			for id in spawns do
				if Monsters[id] and not table.find(eventIds, id) then
					table.insert(eventIds, id)
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
	local progress: Progress = { found = 0, total = #monsterIds, variants = {} }
	for _, variant in Codex.VariantOrder do
		progress.variants[variant] = 0
	end
	for _, id in monsterIds do
		if Codex.has(codex, id) then
			progress.found += 1
			for _, variant in Codex.VariantOrder do
				if Codex.has(codex, id, variant) then
					progress.variants[variant] += 1
				end
			end
		end
	end
	return progress
end

return Codex
