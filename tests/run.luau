-- Plain-Luau checks for the shared config and value math.
-- Run with the Luau CLI from the repo root: luau tests/run.luau

local Monsters = require("../src/shared/Config/Monsters")
local Rarities = require("../src/shared/Config/Rarities")
local Sizes = require("../src/shared/Config/Sizes")
local Spawning = require("../src/shared/Util/Spawning")
local Value = require("../src/shared/Util/Value")

local failures = 0
local function check(name: string, ok: boolean)
	if ok then
		print("ok   " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end
local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- Every zone's spawn weights add up to 100%.
local zoneTotals: { [number]: number } = {}
for _, m in Monsters do
	assert(Rarities[m.rarity], "unknown rarity on " .. m.id)
	if m.zone then
		zoneTotals[m.zone] = (zoneTotals[m.zone] or 0) + (m.spawnWeight or 0)
	end
end
for zone = 1, 5 do
	check(`zone {zone} spawn weights add up to 100`, near(zoneTotals[zone] or 0, 100))
end

local sizeTotal = 0
for _, s in Sizes do
	sizeTotal += s.weight
end
check("size weights add up to 100", near(sizeTotal, 100))

-- Bonuses add: Slimed (x2) + Mummy (x4) = x5.
check("effect bonuses add up", near(Value.effectMultiplier({ "Slimed", "Mummy" }), 5))
-- Vampire + Batty merge into Count (x10).
check("combo replaces its recipe", near(Value.effectMultiplier({ "Vampire", "Batty" }), 10))

local caught = { monsterId = "Gravepup", size = "Big", effects = { "Ghost" }, familiarity = 0, fed = true }
check("fed value uses effects", Value.sellValue(caught, 1) == 450) -- 100 x 1.5 x 3
caught.fed = false
check("unfed value is base x size", Value.sellValue(caught, 1) == 150)

-- Spawn rolls. The CLI has no Roblox Random, so use a small seeded stand-in.
local function fakeRandom(seed: number): any
	local state = seed
	return {
		NextNumber = function(_self)
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end,
	}
end

local rolls = 200_000
local rng = fakeRandom(42)
local commons, divines, wrongZone = 0, 0, 0
for _ = 1, rolls do
	local m = Spawning.rollMonster(1, rng)
	if m.zone ~= 1 then
		wrongZone += 1
	end
	if m.rarity == "Common" then
		commons += 1
	elseif m.rarity == "Divine" then
		divines += 1
	end
end
check("zone 1 only rolls zone 1 monsters", wrongZone == 0)
check("about 45% of zone 1 spawns are Common", math.abs(commons / rolls - 0.45) < 0.01)
check("Divine spawns are very rare", divines / rolls < 0.002)

local colossal = 0
for _ = 1, rolls do
	if Spawning.rollSize(rng).id == "Colossal" then
		colossal += 1
	end
end
check("about 1% of sizes are Colossal", math.abs(colossal / rolls - 0.01) < 0.002)

check("no catch effects without a lens", #Spawning.rollCatchEffects({ "DustBuster" }, rng) == 0)
local alwaysHit = {
	NextNumber = function(_self)
		return 0
	end,
}
local effects = Spawning.rollCatchEffects({ "SpiritLens", "Moonbeam", "SpiritLens" }, alwaysHit :: any)
check(
	"lens + moonbeam give Ghost and Werewolf once each",
	#effects == 2 and table.find(effects, "Ghost") ~= nil and table.find(effects, "Werewolf") ~= nil
)

if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("all checks passed")
