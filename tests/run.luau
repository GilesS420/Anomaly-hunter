-- Plain-Luau checks for the shared config and value math.
-- Run with the Luau CLI from the repo root: luau tests/run.luau

local Monsters = require("../src/shared/Config/Monsters")
local Rarities = require("../src/shared/Config/Rarities")
local Sizes = require("../src/shared/Config/Sizes")
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

if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("all checks passed")
