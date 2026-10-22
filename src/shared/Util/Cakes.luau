--!strict
-- Cake rules (numbers and looks in Config/Cakes, the cakes themselves in Config/Shop.Bakery).
-- A placed cake is plain saved data, so it keeps going while its owner is offline:
-- Cakes.catchUp plays back every bite that was missed. Pure functions so they can be tested
-- outside Roblox; server/Services/CakeService does the world side.

local CakeConfig = require("../Config/Cakes")
local Effects = require("../Config/Effects")
local Shop = require("../Config/Shop")
local Format = require("./Format")
local Rng = require("./Rng")
local Value = require("./Value")

local Cakes = {}

export type Fit = "Ok" | "Unknown" | "HasEffect" | "TooPricey"

-- A cake standing in a mansion, as saved (DataService.Data.cakes). x, y, z are relative to the
-- player's plot, because the plot can be a different one next time they join.
export type Placed = {
	itemId: string,
	x: number,
	y: number,
	z: number,
	placedAt: number,
	checkedAt: number, -- the last time it was checked (older saves; bites now follow the clock)
	bitesLeft: number,
	eaten: { string }, -- uids that had a bite
	gaveEffect: boolean?, -- a bite has given an effect
	biteAt: number?, -- when the next bite is due (older saves: Cakes.nextBiteAt works it out)
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
		local fits: Fit = Value.fits(caught.effects, option.effect, caught.monsterId)
		if fits == "Ok" then
			return "Ok"
		elseif i == 1 then
			first = fits
		end
	end
	return first
end

-- Rolls the effect a bite gives, or nil: first BiteEffectChance (x `chanceMultiplier`, for
-- an event), then each effect in turn rolls its chance (skipping ones that don't fit) and the
-- first hit wins. `force` skips the first roll and, if every effect misses, gives the first
-- one that fits: a cake's last bite when it hasn't given an effect yet.
function Cakes.pickEffect(
	caught: Value.CaughtMonster,
	item: Shop.Item,
	random: Random?,
	force: boolean?,
	chanceMultiplier: number?
): string?
	if not force and not Rng.chance(CakeConfig.BiteEffectChance * (chanceMultiplier or 1), random) then
		return nil
	end
	local first: string? = nil
	for _, option in Cakes.effectChances(item) do
		if Value.fits(caught.effects, option.effect, caught.monsterId) == "Ok" then
			if Rng.chance(option.chance, random) then
				return option.effect
			end
			first = first or option.effect
		end
	end
	return if force then first else nil
end

-- How many bites a cake gets: more for pricier cakes.
function Cakes.bites(itemId: string): number
	return CakeConfig.BitesById[itemId] or CakeConfig.Bites
end

-- Picks when the next bite lands: a random moment in the middle 80% of its share of the time.
local function rollBite(cake: Placed, random: Random?)
	local total = Cakes.bites(cake.itemId)
	local done = math.clamp(total - cake.bitesLeft, 0, total - 1)
	local share = Cakes.Seconds / total
	local roll = if random then random:NextNumber() else math.random() -- no Random outside Roblox (tests)
	cake.biteAt = cake.placedAt + (done + 0.1 + 0.8 * roll) * share
end

-- A new cake at (x, y, z) relative to the plot.
function Cakes.new(itemId: string, x: number, y: number, z: number, now: number, random: Random?): Placed
	local cake: Placed = {
		itemId = itemId,
		x = x,
		y = y,
		z = z,
		placedAt = now,
		checkedAt = now,
		bitesLeft = Cakes.bites(itemId),
		eaten = {},
	}
	rollBite(cake, random)
	return cake
end

function Cakes.expiresAt(cake: Placed): number
	return cake.placedAt + Cakes.Seconds
end

-- When the next bite is due (rolled when the cake is set out and after every bite). Older
-- saves without one: the middle of the next bite's share of the time.
function Cakes.nextBiteAt(cake: Placed): number
	if cake.biteAt then
		return cake.biteAt
	end
	local total = Cakes.bites(cake.itemId)
	local share = Cakes.Seconds / total
	return cake.placedAt + (math.max(total - cake.bitesLeft, 0) + 0.5) * share
end

-- True once it's eaten up or has gone stale.
function Cakes.isDone(cake: Placed, now: number): boolean
	return cake.bitesLeft <= 0 or now >= Cakes.expiresAt(cake)
end

-- How far a cake reaches, in studs (a circle round it on the floor).
function Cakes.reach(itemId: string): number
	return CakeConfig.Reach[itemId] or CakeConfig.DefaultReach
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

-- One monster takes a bite: it may get the cake's effect, and does for sure on the last bite
-- if the cake hasn't given one yet.
function Cakes.bite(
	cake: Placed,
	caught: Value.CaughtMonster,
	random: Random?,
	chanceMultiplier: number?
): Bite
	local force = cake.bitesLeft <= 1 and not cake.gaveEffect
	cake.bitesLeft -= 1
	if cake.bitesLeft > 0 then
		rollBite(cake, random)
	end
	local uid = caught.uid or ""
	table.insert(cake.eaten, uid)
	local item = items[cake.itemId]
	local effectId = if item then Cakes.pickEffect(caught, item, random, force, chanceMultiplier) else nil
	local combo = nil
	if effectId then
		cake.gaveEffect = true
		local before = Value.resolveEffects(caught.effects)
		table.insert(caught.effects, effectId)
		combo = Value.newCombo(before, Value.resolveEffects(caught.effects))
	end
	return { uid = uid, effect = effectId, combo = combo }
end

-- Plays back every bite that came due since the owner left (up to now, or until the cake is
-- done), the same way as online. Returns the bites, in order.
function Cakes.catchUp(
	cake: Placed,
	monsters: { Value.CaughtMonster },
	now: number,
	random: Random?
): { Bite }
	local bites: { Bite } = {}
	local untilTime = math.min(now, Cakes.expiresAt(cake))
	while cake.bitesLeft > 0 and Cakes.nextBiteAt(cake) <= untilTime do
		local eater = Cakes.pickEater(cake, monsters, random)
		if not eater then
			break -- every monster has had a bite
		end
		cake.checkedAt = Cakes.nextBiteAt(cake)
		table.insert(bites, Cakes.bite(cake, eater, random))
	end
	return bites
end

-- One short line saying what a cake does, with the real odds per bite:
-- "3 bites, at least one effect · Each bite: 30% Slimed (x2)".
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
	local critter = false
	for _, option in Cakes.effectChances(item) do
		local effect = Effects.List[option.effect]
		critter = critter or (effect ~= nil and effect.source == "Critter")
	end
	local only = if critter
		then ` · Only for monsters with a base value up to {Format.money(Effects.CritterMaxValue)}`
		else ""
	return `{Cakes.bites(item.id)} bites, at least one effect · Each bite: {table.concat(odds, ", ")}{only}`
end

return Cakes
