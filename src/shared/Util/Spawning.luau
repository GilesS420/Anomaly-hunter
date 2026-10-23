--!strict
-- Rolls for zone spawns and captures. Pure functions so they can be tested outside Roblox.

local Effects = require("../Config/Effects")
local Monsters = require("../Config/Monsters")
local Rarities = require("../Config/Rarities")
local Rng = require("./Rng")
local Shop = require("../Config/Shop")
local Sizes = require("../Config/Sizes")
local Tools = require("../Config/Tools")
local Variants = require("../Config/Variants")
local Zones = require("../Config/Zones")

local Spawning = {}

-- Zone monster lists, built once and sorted by id so a seeded Random gives the same picks.
local byZone: { [number]: { Monsters.Monster } } = {}
for _, m in Monsters do
	if m.zone and m.spawnWeight then
		byZone[m.zone] = byZone[m.zone] or {}
		table.insert(byZone[m.zone], m)
	end
end
for _, list in byZone do
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
end

function Spawning.monstersInZone(zoneIndex: number): { Monsters.Monster }
	return byZone[zoneIndex] or {}
end

-- How many wild monsters a zone keeps alive with this many hunters in it: more hunters get
-- more monsters, so a crowded zone isn't picked clean (Zones.luau).
function Spawning.aliveTarget(hunters: number): number
	return math.clamp(Zones.AliveBase + Zones.AlivePerHunter * hunters, Zones.MaxAlive, Zones.MaxAliveCap)
end

-- Picks which monster spawns next in a zone, using spawnWeight.
function Spawning.rollMonster(zoneIndex: number, random: Random?): Monsters.Monster
	local list = byZone[zoneIndex]
	assert(list, `no monsters in zone {zoneIndex}`)
	return Rng.pickWeighted(list, function(m)
		return m.spawnWeight :: number
	end, random)
end

-- A Bait Bell's monster (Shop.luau, kind "Lure"; `bellId` defaults to the plain Bait Bell).
-- With lureOdds the rarity is picked from those odds (only rarities this zone has). Otherwise
-- it's a normal roll moved lureSteps rarities up the zone's ladder (staying at the zone's
-- rarest), but never above the bell's maxRarity. Picked by spawnWeight within that rarity.
function Spawning.rollLured(zoneIndex: number, random: Random?, bellId: string?): Monsters.Monster
	local bell: Shop.Item? = nil
	for _, item in Shop.Workshop do
		if item.id == (bellId or "BaitBell") then
			bell = item
		end
	end
	local monsters = Spawning.monstersInZone(zoneIndex)
	local function ofRarity(rarity: string): { Monsters.Monster }
		local list = {}
		for _, m in monsters do
			if m.rarity == rarity then
				table.insert(list, m)
			end
		end
		return list
	end
	local function pick(list: { Monsters.Monster }): Monsters.Monster
		return Rng.pickWeighted(list, function(m)
			return m.spawnWeight :: number
		end, random)
	end

	local odds = bell and bell.lureOdds
	if odds then
		local choices: { { rarity: string, chance: number } } = {}
		for rarity, chance in odds do
			if #ofRarity(rarity) > 0 then
				table.insert(choices, { rarity = rarity, chance = chance })
			end
		end
		table.sort(choices, function(a, b)
			return Rarities[a.rarity].order < Rarities[b.rarity].order
		end)
		if #choices > 0 then
			local choice = Rng.pickWeighted(choices, function(c)
				return c.chance
			end, random)
			return pick(ofRarity(choice.rarity))
		end
	end

	-- The zone's rarities, commonest first.
	local ladder: { number } = {}
	for _, m in monsters do
		local order = Rarities[m.rarity].order
		if not table.find(ladder, order) then
			table.insert(ladder, order)
		end
	end
	table.sort(ladder)
	local rolled = Spawning.rollMonster(zoneIndex, random)
	local at = table.find(ladder, Rarities[rolled.rarity].order) or 1
	local steps = if bell and bell.lureSteps then bell.lureSteps else 1
	local order = ladder[math.min(at + steps, #ladder)]
	local maxRarity = bell and bell.maxRarity
	if maxRarity then
		order = math.min(order, Rarities[maxRarity].order)
	end
	local candidates = {}
	for _, m in monsters do
		if Rarities[m.rarity].order == order then
			table.insert(candidates, m)
		end
	end
	return if #candidates > 0 then pick(candidates) else rolled
end

-- Orbs are drawn as balls 3 studs across at Normal size, scaled by size.
Spawning.BaseRadius = 1.5

function Spawning.scale(sizeId: string): number
	for _, size in Sizes do
		if size.id == sizeId then
			return size.scale
		end
	end
	return 1
end

-- Radius of a monster's orb in studs (used to keep orbs from overlapping).
function Spawning.radius(sizeId: string): number
	return Spawning.BaseRadius * Spawning.scale(sizeId)
end

function Spawning.rollSize(random: Random?): Sizes.Size
	return Rng.pickWeighted(Sizes, function(s)
		return s.weight
	end, random)
end

-- Effects a monster gets at the moment it's caught: each of the vacuum's catch effects
-- (Config/Tools) rolls Effects.CatchChance once (times boost: a Lucky Ring catch).
function Spawning.rollCatchEffects(vacuumId: string, random: Random?, boost: number?): { string }
	local effects = {}
	local vacuum = Tools.Vacuums[vacuumId]
	local candidates: { string } = if vacuum and vacuum.catchEffects then vacuum.catchEffects else {}
	for _, effectId in candidates do
		if
			Effects.List[effectId]
			and not table.find(effects, effectId)
			and Rng.chance(math.min(Effects.CatchChance * (boost or 1), 100), random)
		then
			table.insert(effects, effectId)
		end
	end
	return effects
end

-- The catch variant a monster gets (nil for none): rarest first, each with the vacuum's
-- chance for it (times boost: a Lucky Ring catch, Config/Struggles), so a catch never gets two.
-- With a luck potion going (`potion`), any vacuum also has Tools.PotionRainbowChance of a
-- Rainbow if it has none of its own (Giles 2026-10-23), times the boost like the rest.
function Spawning.rollVariant(vacuumId: string, random: Random?, boost: number?, potion: boolean?): string?
	local vacuum = Tools.Vacuums[vacuumId]
	local chances = if vacuum then vacuum.variants else nil
	if potion and not (chances and chances.Rainbow) then
		local withRainbow: { [string]: number } = table.clone(chances or {})
		withRainbow.Rainbow = Tools.PotionRainbowChance
		chances = withRainbow
	end
	if not chances then
		return nil
	end
	for _, variant in Variants do
		local chance = chances[variant.id]
		if chance and Rng.chance(math.min(chance * (boost or 1), 100), random) then
			return variant.id
		end
	end
	return nil
end

return Spawning
