--!strict
-- Cake rules (numbers and looks in Config/Cakes, the cakes themselves in Config/Shop.Bakery).
-- A placed cake is plain saved data, so it keeps going while its owner is offline:
-- Cakes.catchUp plays back every check that was missed. Pure functions so they can be tested
-- outside Roblox; server/Services/CakeService does the world side.

local CakeConfig = require("../Config/Cakes")
local Effects = require("../Config/Effects")
local Layout = require("../Config/Layout")
local Shop = require("../Config/Shop")
local Format = require("./Format")
local Mansion = require("./Mansion")
local Rng = require("./Rng")
local Value = require("./Value")

local Cakes = {}

export type Fit = "Ok" | "Unknown" | "HasEffect"

-- A cake standing in a mansion, as saved (DataService.Data.cakes). x, y, z are relative to the
-- player's plot, because the plot can be a different one next time they join.
export type Placed = {
	itemId: string,
	x: number,
	y: number,
	z: number,
	placedAt: number,
	checkedAt: number, -- the last check that was rolled
	bitesLeft: number,
	eaten: { string }, -- uids that had a bite
}

-- One bite: who ate, the effect it got (nil when the mutation roll missed) and the combo that
-- effect completed, if any.
export type Bite = { uid: string, effect: string?, combo: string? }

Cakes.Seconds = CakeConfig.Minutes * 60

local items: { [string]: Shop.Item } = {}
for _, item in Shop.Bakery do
	items[item.id] = item
end

-- A Bakery cake by id, or nil.
function Cakes.item(id: string): Shop.Item?
	return items[id]
end

-- The effects a cake may give, in the order they're tried, each with its chance in percent.
-- A plain cake gives its one effect for sure (once a bite passes BiteEffectChance).
function Cakes.effectChances(item: Shop.Item): { Shop.EffectChance }
	if item.effectChances then
		return item.effectChances
	end
	return if item.grantsEffect then { { effect = item.grantsEffect, chance = 100 } } else {}
end

-- Whether one of this cake's effects could still land on this monster: not when it already
-- has them all.
function Cakes.fits(caught: Value.CaughtMonster, item: Shop.Item?): Fit
	if not item or item.kind ~= "Food" then
		return "Unknown"
	end
	local first: Fit = "Ok"
	for i, option in Cakes.effectChances(item) do
		local fits: Fit = Value.fits(caught.effects, option.effect)
		if fits == "Ok" then
			return "Ok"
		elseif i == 1 then
			first = fits
		end
	end
	return first
end

-- Rolls the effect a bite gives, or nil: first BiteEffectChance, then each effect in turn rolls
-- its chance (skipping ones that don't fit) and the first hit wins.
function Cakes.pickEffect(caught: Value.CaughtMonster, item: Shop.Item, random: Random?): string?
	if not Rng.chance(CakeConfig.BiteEffectChance, random) then
		return nil
	end
	for _, option in Cakes.effectChances(item) do
		if Value.fits(caught.effects, option.effect) == "Ok" and Rng.chance(option.chance, random) then
			return option.effect
		end
	end
	return nil
end

-- A new cake at (x, y, z) relative to the plot.
function Cakes.new(itemId: string, x: number, y: number, z: number, now: number): Placed
	return {
		itemId = itemId,
		x = x,
		y = y,
		z = z,
		placedAt = now,
		checkedAt = now,
		bitesLeft = CakeConfig.Bites,
		eaten = {},
	}
end

function Cakes.expiresAt(cake: Placed): number
	return cake.placedAt + Cakes.Seconds
end

-- True once it's eaten up or has gone stale.
function Cakes.isDone(cake: Placed, now: number): boolean
	return cake.bitesLeft <= 0 or now >= Cakes.expiresAt(cake)
end

-- How far a cake reaches, in studs (a circle round it on the floor).
function Cakes.reach(itemId: string): number
	return CakeConfig.Reach[itemId] or CakeConfig.DefaultReach
end

-- The mansion's floor area in square studs (every owned wing that has a spot in the layout).
function Cakes.floorArea(wingsOwned: number): number
	local area = 0
	for _, wing in Mansion.ownedWings(wingsOwned) do
		local spot = Layout.Wings[wing.id]
		if spot then
			area += spot.width * spot.depth
		end
	end
	return area
end

-- The chance (0 to 1) that a monster roaming the mansion is within this cake's reach at a
-- check: the share of the floor its circle covers. Used while the owner is offline.
function Cakes.reachShare(itemId: string, wingsOwned: number): number
	local area = Cakes.floorArea(wingsOwned)
	if area <= 0 then
		return 1
	end
	local reach = Cakes.reach(itemId)
	return math.min(1, math.pi * reach * reach / area)
end

-- How many cakes can stand at once.
function Cakes.limit(wingsOwned: number): number
	return wingsOwned * CakeConfig.PerWing
end

-- Picks who comes for the next bite: a monster that hasn't had one of this cake, preferring
-- ones its effect can still land on. `canCome` leaves out ones that can't walk over right now.
function Cakes.pickEater(
	cake: Placed,
	monsters: { Value.CaughtMonster },
	random: Random?,
	canCome: ((Value.CaughtMonster) -> boolean)?
): Value.CaughtMonster?
	local item = items[cake.itemId]
	local best: { Value.CaughtMonster } = {}
	local others: { Value.CaughtMonster } = {}
	for _, caught in monsters do
		if caught.uid and not table.find(cake.eaten, caught.uid) and (not canCome or canCome(caught)) then
			table.insert(if Cakes.fits(caught, item) == "Ok" then best else others, caught)
		end
	end
	local pool = if #best > 0 then best else others
	if #pool == 0 then
		return nil
	end
	local rng = random or Random.new()
	return pool[rng:NextInteger(1, #pool)]
end

-- One monster takes a bite: it may get the cake's effect.
function Cakes.bite(cake: Placed, caught: Value.CaughtMonster, random: Random?): Bite
	cake.bitesLeft -= 1
	local uid = caught.uid or ""
	table.insert(cake.eaten, uid)
	local item = items[cake.itemId]
	local effectId = if item then Cakes.pickEffect(caught, item, random) else nil
	local combo = nil
	if effectId then
		local before = Value.resolveEffects(caught.effects)
		table.insert(caught.effects, effectId)
		combo = Value.newCombo(before, Value.resolveEffects(caught.effects))
	end
	return { uid = uid, effect = effectId, combo = combo }
end

-- Plays back every check missed since cake.checkedAt (up to now, or until the cake is done),
-- with the same odds as when the owner is online: at each check every monster is within reach
-- with the chance Cakes.reachShare. Returns the bites, in order.
function Cakes.catchUp(
	cake: Placed,
	monsters: { Value.CaughtMonster },
	now: number,
	wingsOwned: number,
	random: Random?
): { Bite }
	local bites: { Bite } = {}
	local untilTime = math.min(now, Cakes.expiresAt(cake))
	local share = Cakes.reachShare(cake.itemId, wingsOwned) * 100
	local function inReach(): boolean
		return Rng.chance(share, random)
	end
	while cake.bitesLeft > 0 and cake.checkedAt + CakeConfig.CheckSeconds <= untilTime do
		cake.checkedAt += CakeConfig.CheckSeconds
		if Rng.chance(CakeConfig.BiteChance, random) then
			local eater = Cakes.pickEater(cake, monsters, random, inReach)
			if eater then
				table.insert(bites, Cakes.bite(cake, eater, random))
			end
		end
	end
	return bites
end

-- One short line saying what a cake does, with its reach and the real odds per bite:
-- "Reach 10 studs · Each bite: 50% Slimed (x2)".
function Cakes.describe(item: Shop.Item): string
	local odds = {}
	local left = CakeConfig.BiteEffectChance / 100 -- chance the roll gets this far
	for _, option in Cakes.effectChances(item) do
		local effect = Effects.List[option.effect]
		local chance = left * option.chance / 100
		left -= chance
		if effect then
			local percent = math.floor(chance * 1000 + 0.5) / 10
			table.insert(odds, `{percent}% {Format.name(effect.id)} (x{effect.multiplier})`)
		end
	end
	return `Reach {Cakes.reach(item.id)} studs · Each bite: {table.concat(odds, ", ")}`
end

return Cakes
