--!strict
-- Rolls for zone spawns and captures. Pure functions so they can be tested outside Roblox.

local Effects = require("../Config/Effects")
local Monsters = require("../Config/Monsters")
local Rng = require("./Rng")
local Sizes = require("../Config/Sizes")

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

-- Picks which monster spawns next in a zone, using spawnWeight.
function Spawning.rollMonster(zoneIndex: number, random: Random?): Monsters.Monster
	local list = byZone[zoneIndex]
	assert(list, `no monsters in zone {zoneIndex}`)
	return Rng.pickWeighted(list, function(m)
		return m.spawnWeight :: number
	end, random)
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
