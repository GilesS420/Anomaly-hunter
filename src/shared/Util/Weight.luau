--!strict
-- Weight rules (numbers in Config/Weight). Like Familiarity it works from timestamps
-- (os.time() seconds): call Weight.settle(monster, now) before reading its weight or size.
-- Pure functions so they can be tested outside Roblox.

local Sizes = require("../Config/Sizes")
local WeightConfig = require("../Config/Weight")

local Weight = {}

-- The fields of a caught monster (Util/Value.CaughtMonster) that weight uses.
export type Growing = {
	size: string,
	effects: { string },
	kg: number?, -- its weight; nil until it first settles (just caught, or an older save)
	kgAt: number?, -- os.time() its weight was last brought up to date
}

local order: { [string]: number } = {}
local byId: { [string]: Sizes.Size } = {}
for i, size in Sizes do
	order[size.id] = i
	byId[size.id] = size
end

local function startKg(sizeId: string): number
	return (WeightConfig.StartKg :: { [string]: number })[sizeId] or WeightConfig.StartKg.Normal
end

-- How far a Titan is from turning Titan (0) to MaxKg (1), on a log scale so every doubling
-- counts the same.
local function titanProgress(kg: number): number
	local from, to = WeightConfig.StartKg.Titan, WeightConfig.MaxKg
	return math.clamp(math.log(kg / from) / math.log(to / from), 0, 1)
end

-- The size a monster of this weight is drawn at.
function Weight.sizeFor(kg: number): string
	local best = Sizes[1].id
	for _, size in Sizes do
		if kg >= startKg(size.id) and startKg(size.id) >= startKg(best) then
			best = size.id
		end
	end
	return best
end

-- A random weight for a monster just caught at this size.
function Weight.roll(sizeId: string, random: Random?): number
	local from = startKg(sizeId)
	local to = from * 2
	for _, size in Sizes do
		local start = startKg(size.id)
		if start > from and start < to then
			to = start
		end
	end
	local rng = random or Random.new()
	return math.floor((from + rng:NextNumber() * (to - from)) * 10) / 10
end

-- Growth per hour as a share of its weight (0.02 = +2% an hour).
function Weight.rate(caught: Growing): number
	return WeightConfig.GrowthPerHour + #caught.effects * WeightConfig.GrowthPerEffect
end

-- Brings a monster's weight up to date at `now` and moves its size up when it got heavy
-- enough (sizes never go down). A monster without a weight gets one for its size and grows
-- from now on. Returns true if its size changed.
function Weight.settle(caught: Growing, now: number, random: Random?): boolean
	local kg = caught.kg
	if typeof(kg) ~= "number" or kg ~= kg or kg <= 0 then
		caught.kg = Weight.roll(caught.size, random)
		caught.kgAt = now
		return false
	end
	local from = caught.kgAt or now
	local hours = math.max(0, now - from) / 3600
	local grown = math.min(WeightConfig.MaxKg, kg * math.exp(Weight.rate(caught) * hours))
	caught.kg = math.max(kg, grown)
	caught.kgAt = math.max(from, now)
	local size = Weight.sizeFor(caught.kg :: number)
	if (order[size] or 0) > (order[caught.size] or 0) then
		caught.size = size
		return true
	end
	return false
end

-- What its size multiplies its value by: Config/Sizes, except a Titan, which goes from x10 up
-- to Config/Weight.TitanMaxValue as it keeps growing.
function Weight.valueMultiplier(sizeId: string, kg: number?): number
	local size = byId[sizeId]
	assert(size, "unknown size " .. sizeId)
	if sizeId ~= "Titan" or not kg then
		return size.valueMultiplier
	end
	return size.valueMultiplier + (WeightConfig.TitanMaxValue - size.valueMultiplier) * titanProgress(kg)
end

-- How big it's drawn (Normal = 1): Config/Sizes, except a Titan, which grows in steps up to
-- Config/Weight.TitanMaxScale.
function Weight.drawScale(sizeId: string, kg: number?): number
	local size = byId[sizeId]
	if not size then
		return 1
	end
	if sizeId ~= "Titan" or not kg then
		return size.scale
	end
	local from, to, step =
		WeightConfig.TitanStartScale, WeightConfig.TitanMaxScale, WeightConfig.TitanScaleStep
	return math.min(to, from + math.floor((to - from) * titanProgress(kg) / step + 1e-6) * step)
end

-- "54 kg", "320 kg", "1.2 t".
function Weight.text(kg: number): string
	if kg >= 1000 then
		return `{math.floor(kg / 100) / 10} t`
	end
	return if kg < 10 then `{math.floor(kg * 10) / 10} kg` else `{math.floor(kg)} kg`
end

return Weight
