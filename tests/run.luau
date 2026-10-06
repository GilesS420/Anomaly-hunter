-- Plain-Luau checks for the shared config and value math.
-- Run with the Luau CLI from the repo root: luau tests/run.luau

local Monsters = require("../src/shared/Config/Monsters")
local Rarities = require("../src/shared/Config/Rarities")
local Sizes = require("../src/shared/Config/Sizes")
local Catching = require("../src/shared/Util/Catching")
local Format = require("../src/shared/Util/Format")
local Layout = require("../src/shared/Config/Layout")
local Mansion = require("../src/shared/Util/Mansion")
local Roam = require("../src/shared/Util/Roam")
local Hunt = require("../src/shared/Util/Hunt")
local Spawning = require("../src/shared/Util/Spawning")
local Value = require("../src/shared/Util/Value")
local Events = require("../src/shared/Config/Events")
local Watcher = require("../src/shared/Util/Watcher")

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

-- Catching: vacuum tiers gate size and rarity.
check("Dust Buster catches a Normal Common", Catching.canVacuum("DustBuster", "Normal", "Common"))
check("Dust Buster can't hold a Big monster", not Catching.canVacuum("DustBuster", "Big", "Common"))
check("Phantom Vac holds a Huge Epic", Catching.canVacuum("PhantomVac", "Huge", "Epic"))
check("Mythic needs the Void Vac", not Catching.canVacuum("PhantomVac", "Tiny", "Mythic"))
check("Void Vac holds a Colossal Divine", Catching.canVacuum("VoidVac", "Colossal", "Divine"))
check(
	"rarer monsters take longer to catch",
	Catching.catchSeconds("VoidVac", "Divine") > Catching.catchSeconds("VoidVac", "Common")
)
check("a Common takes 1.6s with the Dust Buster", near(Catching.catchSeconds("DustBuster", "Common"), 1.6))
check(
	"the slowest catches still take under 3 seconds",
	Catching.catchSeconds("DustBuster", "Legendary") < 3 and Catching.catchSeconds("VoidVac", "Divine") < 3
)
check(
	"better vacuums are faster",
	Catching.catchSeconds("VoidVac", "Rare") < Catching.catchSeconds("DustBuster", "Rare")
)
check("unknown vacuums can't catch", Catching.catchSeconds("Broom", "Common") == math.huge)
check("better flashlights reach further", Catching.reach("Moonbeam") > Catching.reach("CandleLamp"))

-- Hunt runs: zones open with their wing and only once they've shipped.
check("Pumpkin Graveyard is open from the start", Hunt.isZoneUnlocked(1, 1))
check("Murky Bayou needs the Library", not Hunt.isZoneUnlocked(2, 1) and Hunt.isZoneUnlocked(2, 2))
check("Abandoned Carnival needs the Ballroom", not Hunt.isZoneUnlocked(3, 2) and Hunt.isZoneUnlocked(3, 3))
check("zones 4 and 5 stay shut at launch", not Hunt.isZoneUnlocked(4, 6) and not Hunt.isZoneUnlocked(5, 6))
check("hearts never go below 0", Hunt.afterDamage(1, 5) == 0 and Hunt.afterDamage(3, 1) == 2)
check("open zones have no locked message", Hunt.lockedReason(1, 1) == nil)
check("locked zones name the wing to buy", string.find(Hunt.lockedReason(2, 1) or "", "Library") ~= nil)
check(
	"unreleased zones say they're coming",
	string.find(Hunt.lockedReason(4, 6) or "", "future update") ~= nil
)

-- Watcher: Hunger cycle, meter and event monsters.
do
	local steps = Watcher.cycle({ Flicker = true, BloodMoon = true })
	check(
		"the cycle is Flicker then Blood Moon",
		#steps == 2 and steps[1].event.id == "Flicker" and steps[2].event.id == "BloodMoon"
	)
	check(
		"Flicker comes at 60 Hunger, Blood Moon at 150",
		steps[1].threshold == 60 and steps[2].threshold == 150
	)
	check("events that aren't built are skipped", #Watcher.cycle({ Flicker = true, MimicNight = true }) == 1)
	check("8 hunters fill 8 Hunger a minute", near(Watcher.gain(8, 60), 8))
	check("nobody hunting means no Hunger", Watcher.gain(0, 60) == 0)
	check("the meter is half full at 30 of 60", near(Watcher.meter(30, steps, 1), 0.5))
	check(
		"the meter restarts after Flicker",
		near(Watcher.meter(60, steps, 2), 0) and near(Watcher.meter(105, steps, 2), 0.5)
	)
	check("the meter never overflows", Watcher.meter(999, steps, 1) == 1)
	check("at least 4 event monsters", Watcher.monsterCount(1) == Events.MinMonsters)
	check("one event monster per player", Watcher.monsterCount(7) == 7)
	check("at most 10 event monsters", Watcher.monsterCount(30) == Events.MaxMonsters)
	check("countdown clock", Watcher.clock(125) == "2:05" and Watcher.clock(-3) == "0:00")

	local eventRng = fakeRandom(3)
	local wrong, wicks = 0, 0
	for _ = 1, 20_000 do
		local m = Watcher.rollMonster(steps[1].event, eventRng)
		if m.event ~= "Flicker" then
			wrong += 1
		elseif m.id == "Flickerwick" then
			wicks += 1
		end
	end
	check("Flicker only spawns Flicker monsters", wrong == 0)
	check("about 70% of Flicker monsters are Flickerwicks", math.abs(wicks / 20_000 - 0.7) < 0.02)

	local valid = true
	for _, event in Events.List do
		for id in event.monsters or {} do
			local m = Monsters[id]
			if not m or m.event ~= event.id then
				valid = false
			end
		end
	end
	check("event monster lists match Monsters config", valid)
	check(
		"Phantoms can be caught with the starter vacuum",
		Catching.canVacuum("DustBuster", "Normal", "Phantom")
	)
end

-- Mansion: capacity grows with wings, wings are bought in order, unreleased wings can't be bought.
check("the Foyer holds 8", Mansion.capacity(1) == 8)
check("Foyer + Library + Ballroom hold 26", Mansion.capacity(3) == 26)
check("an 8th monster fits in the Foyer, a 9th doesn't", Mansion.hasRoom(1, 7) and not Mansion.hasRoom(1, 8))
do
	local result, wing = Mansion.canBuyNext(1, 999_999)
	check("the Library costs $1M", result == "TooPoor" and wing ~= nil and wing.id == "Library")
	result, wing = Mansion.canBuyNext(1, 1_000_000)
	check("$1M buys the Library", result == "Ok" and wing ~= nil and wing.id == "Library")
	result = Mansion.canBuyNext(3, 1e12)
	check("the Attic isn't for sale yet", result == "ComingSoon")
	result = Mansion.canBuyNext(6, 1e12)
	check("nothing left after the Garden", result == "AllOwned")
end

-- Money and names on screen.
check("money is shortened", Format.money(2_500_000) == "$2.5M" and Format.money(1_000_000) == "$1M")
check("small money is exact", Format.money(999) == "$999" and Format.money(25_000) == "$25K")
check("monster names get spaces", Format.name("TheGroundskeeper") == "The Groundskeeper")

-- Roaming: orbs always land on a free spot inside the floor and never overlap.
do
	local floor = { Roam.rect(0, 0, 40, 40, 5) }
	local placed: { Roam.Body } = {}
	local rngRoam = fakeRandom(7)
	local overlaps, outside = 0, 0
	for _ = 1, 40 do
		local radius = 1.5 * (0.6 + rngRoam:NextNumber() * 1.9)
		local point = Roam.findFreePoint(floor, radius, placed, rngRoam)
		if point then
			if not Roam.inside(floor, point.x, point.z, radius - 1e-6) then
				outside += 1
			end
			for _, other in placed do
				local d = math.sqrt((point.x - other.x) ^ 2 + (point.z - other.z) ^ 2)
				if d < radius + other.radius + Roam.Gap - 1e-6 then
					overlaps += 1
				end
			end
			table.insert(placed, { x = point.x, z = point.z, radius = radius })
		end
	end
	check("roaming orbs never overlap", overlaps == 0)
	check("roaming orbs stay on the floor", outside == 0)
	check("a 40x40 floor fits plenty of orbs", #placed >= 20)
	check(
		"a full floor says no instead of overlapping",
		Roam.findFreePoint(floor, 30, placed, rngRoam) == nil
	)
	check(
		"paths through another orb are blocked",
		not Roam.pathClear(-10, 0, 10, 0, 1, { { x = 0, z = 0.5, radius = 1 } })
	)
	check(
		"paths around other orbs are clear",
		Roam.pathClear(-10, 0, 10, 0, 1, { { x = 0, z = 5, radius = 1 } })
	)
	check("moves finish at alpha 1", Roam.alpha(10, 12, 13) == 1 and Roam.alpha(10, 12, 11) == 0.5)
end

-- World layout: 8 plots, all inside the oval, none overlapping, every wing inside its plot.
do
	local hx, hz = Layout.Hub.GroundSize.x / 2, Layout.Hub.GroundSize.z / 2
	local px, pz = Layout.PlotSize.x / 2, Layout.PlotSize.z / 2
	check("there are 8 plots", #Layout.Plots == 8)
	local inOval, apart = true, true
	for i, plot in Layout.Plots do
		for _, cx in { plot.x - px, plot.x + px } do
			for _, cz in { plot.z - pz, plot.z + pz } do
				if (cx / hx) ^ 2 + (cz / hz) ^ 2 > 1 then
					inOval = false
				end
			end
		end
		for j, other in Layout.Plots do
			if
				i ~= j
				and math.abs(plot.x - other.x) < Layout.PlotSize.x
				and math.abs(plot.z - other.z) < Layout.PlotSize.z
			then
				apart = false
			end
		end
		check(`{plot.name} faces the middle`, plot.facing == -math.sign(plot.z))
	end
	check("every plot is inside the oval", inOval)
	check("no two plots overlap", apart)
	local wingsFit = true
	for _, wing in Layout.Wings do
		if math.abs(wing.x) + wing.width / 2 > px or math.abs(wing.z) + wing.depth / 2 > pz then
			wingsFit = false
		end
	end
	check("every wing fits inside its plot", wingsFit)
	check("the plot spawn is inside the plot", math.abs(Layout.PlotSpawn.z) < pz)
	local gatesInOval = true
	for _, gate in Layout.Gates do
		if (gate.x / hx) ^ 2 + (gate.z / hz) ^ 2 > 1 then
			gatesInOval = false
		end
	end
	check("every gate is inside the oval", gatesInOval)
end

if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("all checks passed")
