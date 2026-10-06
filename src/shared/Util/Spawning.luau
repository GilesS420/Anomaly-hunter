--!strict
-- Rolls for zone spawns and captures. Pure functions so they can be tested outside Roblox.

local Effects = require("../Config/Effects")
local Monsters = require("../Config/Monsters")
local Rarities = require("../Config/Rarities")
local Rng = require("./Rng")
local Shop = require("../Config/Shop")
local Sizes = require("../Config/Sizes")
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

-- The rarest rarity a Bait Bell can bring (Shop.luau BaitBell.maxRarity; nil = no limit).
local lureMaxOrder = math.huge
for _, item in Shop.Workshop do
	if item.id == "BaitBell" and item.maxRarity then
		lureMaxOrder = Rarities[item.maxRarity].order
	end
end

-- A Bait Bell's monster: a normal roll, then the next rarity up that this zone has (the
-- same one if the roll was already the zone's rarest), but never above the bell's maxRarity
-- (rolls at or above it give that rarity). Picked by spawnWeight within that rarity.
function Spawning.rollLured(zoneIndex: number, random: Random?): Monsters.Monster
	local rolled = Spawning.rollMonster(zoneIndex, random)
	local rolledOrder = Rarities[rolled.rarity].order
	local nextOrder = math.huge
	for _, m in Spawning.monstersInZone(zoneIndex) do
		local order = Rarities[m.rarity].order
		if order > rolledOrder and order < nextOrder then
			nextOrder = order
		end
	end
	if nextOrder == math.huge then
		nextOrder = rolledOrder
	end
	nextOrder = math.min(nextOrder, lureMaxOrder)
	local candidates = {}
	for _, m in Spawning.monstersInZone(zoneIndex) do
		if Rarities[m.rarity].order == nextOrder then
			table.insert(candidates, m)
		end
	end
	if #candidates == 0 then
		return rolled
	end
	return Rng.pickWeighted(candidates, function(m)
		return m.spawnWeight :: number
	end, random)
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

-- Tool id -> effect it can give on catch (Spirit Lens -> Ghost, Moonbeam -> Werewolf).
local catchEffectByItem: { [string]: string } = {}
for _, effect in Effects.List do
	if effect.source == "Catch" and effect.from then
		catchEffectByItem[effect.from] = effect.id
	end
end

-- Effects a monster gets at the moment it's caught. Each equipped Catch-effect tool rolls
-- CatchChance once.
function Spawning.rollCatchEffects(equippedItemIds: { string }, random: Random?): { string }
	local effects = {}
	for _, itemId in equippedItemIds do
		local effectId = catchEffectByItem[itemId]
		if
			effectId
			and #effects < Effects.MaxSlots
			and not table.find(effects, effectId)
			and Rng.chance(Effects.CatchChance, random)
		then
			table.insert(effects, effectId)
		end
	end
	return effects
end

return Spawning
