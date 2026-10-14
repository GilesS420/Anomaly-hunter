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
local Shop = require("../src/shared/Config/Shop")
local Workshop = require("../src/shared/Util/Workshop")
local Care = require("../src/shared/Util/Care")
local CareConfig = require("../src/shared/Config/Care")
local Effects = require("../src/shared/Config/Effects")
local Haunting = require("../src/shared/Util/Haunting")
local AttackConfig = require("../src/shared/Config/Attacks")
local Attacks = require("../src/shared/Util/Attacks")
local Landmarks = require("../src/shared/Config/Landmarks")
local Looks = require("../src/shared/Config/Looks")
local Rooms = require("../src/shared/Config/Rooms")
local Scenery = require("../src/shared/Config/Scenery")
local Travel = require("../src/shared/Util/Travel")
local TravelConfig = require("../src/shared/Config/Travel")

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
check("fed value uses effects", Value.sellValue(caught, 1) == 45_000) -- 10,000 x 1.5 x 3
caught.fed = false
check("unfed value is base x size", Value.sellValue(caught, 1) == 15_000)

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
	result, wing = Mansion.canBuyNext(3, 1e12)
	check("the Attic is for sale after the Ballroom", result == "Ok" and wing ~= nil and wing.id == "Attic")
	result, wing = Mansion.canBuyNext(4, 1e12)
	check("the Crypt is for sale after the Attic", result == "Ok" and wing ~= nil and wing.id == "Crypt")
	result, wing = Mansion.canBuyNext(5, 1e12)
	check("the Garden is the last wing for sale", result == "Ok" and wing ~= nil and wing.id == "Garden")
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

-- Workshop: stock comes from the slot alone, matches restockChance, and buying follows the rules.
do
	check("a slot lasts 5 minutes", Workshop.slotAt(299) == 0 and Workshop.slotAt(300) == 1)
	check("the next restock is the start of the next slot", Workshop.restockAt(4) == 1500)
	local strobe = Workshop.item("StrobeLight") :: Shop.Item
	local phantomVac = Workshop.item("PhantomVac") :: Shop.Item
	local voidVac = Workshop.item("VoidVac") :: Shop.Item
	local charm = Workshop.item("ReturnCharm") :: Shop.Item
	local starter = Workshop.item("DustBuster") :: Shop.Item
	check(
		"the same slot always has the same stock",
		Workshop.inStock(strobe, 1234) == Workshop.inStock(strobe, 1234)
	)
	local slots = 20_000
	local strobeIn, phantomIn, voidIn = 0, 0, 0
	for slot = 1, slots do
		if Workshop.inStock(strobe, slot) then
			strobeIn += 1
		end
		if Workshop.inStock(phantomVac, slot) then
			phantomIn += 1
		end
		if Workshop.inStock(voidVac, slot) then
			voidIn += 1
		end
	end
	check("Strobe Light is always in stock", strobeIn == slots)
	check("Phantom Vac is in stock about 80% of restocks", math.abs(phantomIn / slots - 0.80) < 0.02)
	check("Void Vac is in stock about 6% of restocks", math.abs(voidIn / slots - 0.06) < 0.01)
	check(
		"starter tools are always in stock and owned",
		Workshop.inStock(starter, 7) and Workshop.owns({}, starter)
	)

	local inSlot = 1
	while not Workshop.inStock(charm, inSlot) do
		inSlot += 1
	end
	local outSlot = 1
	while Workshop.inStock(charm, outSlot) do
		outSlot += 1
	end
	check("can buy a charm in stock", Workshop.canBuy(charm, inSlot, 1e6, {}, 0) == "Ok")
	check("can't buy a charm out of stock", Workshop.canBuy(charm, outSlot, 1e6, {}, 0) == "OutOfStock")
	check(
		"charms sell out after the limit",
		Workshop.canBuy(charm, inSlot, 1e6, {}, Shop.ConsumablesPerRestock) == "SoldOut"
	)
	check("can't buy without the money", Workshop.canBuy(charm, inSlot, charm.price - 1, {}, 0) == "TooPoor")
	check(
		"a tool you own can't be bought again",
		Workshop.canBuy(strobe, 1, 1e9, { StrobeLight = 1 }, 0) == "Owned"
	)
	check("an unknown item can't be bought", Workshop.canBuy(nil, 1, 1e9, {}, 0) == "Unknown")
	check("vacuums go in the vacuum slot", Workshop.equipSlot(voidVac) == "vacuum")
	check("charms aren't equipped", Workshop.equipSlot(charm) == nil)
	local described = true
	for _, item in Shop.Workshop do
		if Workshop.describe(item) == "" then
			described = false
		end
	end
	check("every Workshop item has a description", described)
end

-- Bait Bell: the lured monster is one rarity up, but never above Legendary.
do
	local rng = fakeRandom(7)
	local upgraded = true
	for _ = 1, 5000 do
		local m = Spawning.rollLured(1, rng)
		if m.rarity == "Common" or m.zone ~= 1 then
			upgraded = false
		end
	end
	check("a Bait Bell never brings a Common", upgraded)
	local tooRare, legendaries = 0, 0
	for _ = 1, 20_000 do
		local rarity = Spawning.rollLured(1, rng).rarity
		if Rarities[rarity].order > Rarities.Legendary.order then
			tooRare += 1
		elseif rarity == "Legendary" then
			legendaries += 1
		end
	end
	check("a Bait Bell never brings anything above Legendary", tooRare == 0)
	-- Epic rolls (7%) move up to Legendary, and Legendary, Mythic and Divine rolls (3%) give one.
	check(
		"a Bait Bell brings a Legendary about 10% of the time",
		math.abs(legendaries / 20_000 - 0.10) < 0.01
	)
end

-- Pacing: the balance sheet's targets (docs in /mnt/project-files/balance) in plain math, so a
-- price or value change that breaks the money pace fails here. The full simulation lives with
-- the docs; these checks use expected values only.
do
	local Effects = require("../src/shared/Config/Effects")
	local Wings = require("../src/shared/Config/Wings")
	local Zones = require("../src/shared/Config/Zones")

	-- Expected value of the best monster this vacuum can hold out of `seen` wild ones in a
	-- zone. Each one is rolled by spawnWeight and size weight; ones it can't hold count as 0.
	local function expectedBest(zone: number, vacuumId: string, seen: number): number
		local outcomes: { { value: number, p: number } } = {}
		local totalWeight = 0
		for _, m in Spawning.monstersInZone(zone) do
			totalWeight += m.spawnWeight :: number
		end
		for _, m in Spawning.monstersInZone(zone) do
			for _, size in Sizes do
				local value = if Catching.canVacuum(vacuumId, size.id, m.rarity)
					then m.baseValue * size.valueMultiplier
					else 0
				local p = (m.spawnWeight :: number) / totalWeight * size.weight / sizeTotal
				table.insert(outcomes, { value = value, p = p })
			end
		end
		table.sort(outcomes, function(a, b)
			return a.value < b.value
		end)
		-- E[max] = sum of value x P(max is this value) = value x (F(v)^seen - F(below v)^seen)
		local best, below = 0, 0
		for _, o in outcomes do
			local upTo = below + o.p
			best += o.value * (upTo ^ seen - below ^ seen)
			below = upTo
		end
		return best
	end

	-- Average catch-effect bonus from the Spirit Lens (Ghost) and Moonbeam (Werewolf).
	local function catchBonus(lens: boolean, moonbeam: boolean): number
		local chance = Effects.CatchChance / 100
		local bonus = 1
		if lens then
			bonus += chance * (Effects.List.Ghost.multiplier - 1)
		end
		if moonbeam then
			bonus += chance * (Effects.List.Werewolf.multiplier - 1)
		end
		return bonus
	end

	local function priceOf(id: string): number
		for _, wing in Wings.List do
			if wing.id == id then
				return wing.price
			end
		end
		return (Workshop.item(id) :: Shop.Item).price
	end

	-- The sheet's main curve: 3 hunters share a zone of 12, so each picks from about 4.
	local hunters = 3
	local seen = Spawning.aliveTarget(hunters) // hunters
	local tripSeconds = 55 -- a full trip with selling takes 51-56 s in the sheet's simulation

	check(
		"a zone keeps 12 monsters for 1-3 hunters",
		Spawning.aliveTarget(1) == 12 and Spawning.aliveTarget(3) == 12
	)
	check(
		"a crowded zone keeps more monsters",
		Spawning.aliveTarget(8) == 22 and Spawning.aliveTarget(30) == 24
	)

	-- Zone 1 with the Dust Buster: the best of 12 is worth tens of thousands, not hundreds.
	local solo = expectedBest(1, "DustBuster", Zones.MaxAlive)
	check("zone 1 Dust Buster: best of 12 is worth $40K-$70K a trip", solo >= 40_000 and solo <= 70_000)
	local shared = expectedBest(1, "DustBuster", seen)
	check(
		"zone 1 Dust Buster: 3 hunters sharing earn $15K-$35K a trip",
		shared >= 15_000 and shared <= 35_000
	)

	-- Each zone is worth about x4 the one before, with the same vacuum.
	local stepsOk = true
	for _, vacuumId in { "DustBuster", "PhantomVac", "VoidVac" } do
		for zone = 2, 5 do
			if
				expectedBest(zone, vacuumId, Zones.MaxAlive)
				< 3.5 * expectedBest(zone - 1, vacuumId, Zones.MaxAlive)
			then
				stepsOk = false
			end
		end
	end
	check("each zone's best of 12 is about x4 the zone before", stepsOk)

	-- Every price is a positive round number (two significant digits); only starters are free.
	local function round(price: number): boolean
		local unit = 10 ^ math.max(math.floor(math.log10(price)) - 1, 0)
		return price % unit == 0
	end
	local pricesOk = true
	for _, list in { Shop.Workshop, Shop.Bakery } do
		for _, item in list do
			local starter = item.id == "DustBuster" or item.id == "CandleLamp"
			if starter then
				pricesOk = pricesOk and item.price == 0
			else
				pricesOk = pricesOk and item.price > 0 and round(item.price)
			end
		end
	end
	for _, wing in Wings.List do
		if wing.order == 1 then
			pricesOk = pricesOk and wing.price == 0
		else
			pricesOk = pricesOk and wing.price > 0 and round(wing.price)
		end
	end
	check("every tool and wing price is a positive round number", pricesOk)
	check(
		"the Moonbeam's Werewolf beats the Spirit Lens's Ghost",
		catchBonus(false, true) > catchBonus(true, false)
	)

	-- The upgrade order, and what a player earns per trip while saving for each step:
	-- zone, vacuum, Spirit Lens, Moonbeam (wings owned = zone).
	local order = {
		{ id = "StrobeLight", zone = 1, vacuum = "DustBuster", lens = false, moonbeam = false },
		{ id = "PhantomVac", zone = 1, vacuum = "DustBuster", lens = false, moonbeam = false },
		{ id = "SpiritLens", zone = 1, vacuum = "PhantomVac", lens = false, moonbeam = false },
		{ id = "Library", zone = 1, vacuum = "PhantomVac", lens = true, moonbeam = false },
		{ id = "Ballroom", zone = 2, vacuum = "PhantomVac", lens = true, moonbeam = false },
		{ id = "Moonbeam", zone = 3, vacuum = "PhantomVac", lens = true, moonbeam = false },
		{ id = "VoidVac", zone = 3, vacuum = "PhantomVac", lens = true, moonbeam = true },
	}
	local rising, paced = true, true
	local trips: { number } = {}
	local totalTrips, libraryTrips = 0, 0
	for i, step in order do
		local wingBoost = 1 + (step.zone - 1) * Wings.ValueBoostPerWing
		local perTrip = expectedBest(step.zone, step.vacuum, seen)
			* catchBonus(step.lens, step.moonbeam)
			* wingBoost
		trips[i] = priceOf(step.id) / perTrip
		totalTrips += trips[i]
		if step.id == "Library" then
			libraryTrips = totalTrips
		end
		if i > 1 then
			rising = rising and priceOf(step.id) > priceOf(order[i - 1].id)
			-- the sheet's curve: each step takes about 2-3x as long as the one before
			local ratio = trips[i] / trips[i - 1]
			paced = paced and ratio >= 1.5 and ratio <= 4
		end
	end
	check("prices rise along the upgrade order", rising)
	check("the Strobe Light takes about one trip", trips[1] <= 1.5)
	check("each upgrade takes 1.5-4x as many trips as the one before", paced)
	check("the Library comes inside the first hour", libraryTrips * tripSeconds / 60 <= 60)
	local hours = totalTrips * tripSeconds / 3600
	check("the launch tools last 4-20 hours", hours >= 4 and hours <= 20)
	check(
		"Nightmare monsters need the Phantom Vac",
		not Catching.canVacuum("DustBuster", "Normal", "Nightmare")
			and Catching.canVacuum("PhantomVac", "Normal", "Nightmare")
	)
	check(
		"Eldritch monsters need the Void Vac",
		not Catching.canVacuum("PhantomVac", "Normal", "Eldritch")
			and Catching.canVacuum("VoidVac", "Normal", "Eldritch")
	)
end

-- Feeding and Familiarity (Util/Care).
do
	local fed = CareConfig.FedHours * 3600
	local grow = CareConfig.FamiliarityHours * 3600
	local t0 = 1_000_000
	local m: any = {
		monsterId = "Gravepup",
		size = "Normal",
		effects = {},
		familiarity = 0,
		fed = true,
		fedUntil = t0 + fed,
		grownAt = t0,
	}
	Care.settle(m, t0 + fed / 2)
	check("Familiarity grows while fed", near(m.familiarity, math.min(fed / 2 / grow, 1)) and m.fed)
	Care.settle(m, t0 + fed * 3)
	local atHungry = math.min(fed / grow, 1)
	check("Familiarity stops growing once hungry", near(m.familiarity, atHungry) and not m.fed)
	Care.settle(m, t0 + fed * 5)
	check("settling again while hungry changes nothing", near(m.familiarity, atHungry))
	check("a hungry monster needs food", Care.needsFood(m, t0 + fed * 5))
	check("a hungry monster sells for base x size", Value.sellValue(m, 3) == 10_000)

	Care.feed(m, t0 + fed * 5)
	check("feeding makes it fed for a day", m.fed and m.fedUntil == t0 + fed * 6)
	check("a just-fed monster doesn't need food", not Care.needsFood(m, t0 + fed * 5))
	check("hours left counts down", Care.hoursLeft(m, t0 + fed * 5) == CareConfig.FedHours)

	local fresh: any = { monsterId = "Gloomlet", size = "Normal", effects = {}, familiarity = 0, fed = false }
	Care.settle(fresh, t0)
	check(
		"a monster without timestamps starts fed",
		fresh.fed and fresh.fedUntil == t0 + fed and fresh.grownAt == t0
	)
	Care.settle(fresh, t0 - 50)
	check("a clock that went back never shrinks or regrows", fresh.familiarity == 0 and fresh.grownAt == t0)

	check("percent rounds down cleanly", Care.percent({ familiarity = 0.29 } :: any) == 29)

	-- Treats: refused rather than wasted, and combos free up a slot.
	local candy = Care.treat("PumpkinCandy") :: Shop.Item
	local cake = Care.treat("CursedCake") :: Shop.Item
	local function withEffects(effects: { string }): any
		return { monsterId = "Gravepup", size = "Normal", effects = effects, familiarity = 0.95, fed = false }
	end
	check("an unknown treat is refused", Care.canTreat(withEffects({}), Care.treat("VoidVac")) == "Unknown")
	check("a treat isn't given twice", Care.canTreat(withEffects({ "PumpkinHead" }), candy) == "HasEffect")
	check(
		"a treat doesn't fit a monster with 3 effects",
		Care.canTreat(withEffects({ "Ghost", "Mummy", "Possessed" }), candy) == "NoRoom"
	)
	check(
		"a combo counts as one effect",
		Care.canTreat(withEffects({ "Vampire", "Batty", "Ghost" }), candy) == "Ok"
	)
	check(
		"a treat that completes a combo fits",
		Care.canTreat(withEffects({ "Ghost", "Vampire", "Possessed" }), cake) == "Ok"
	)
	local treated = withEffects({ "Ghost" })
	Care.giveTreat(treated, candy, t0)
	check(
		"a treat feeds, adds its effect and Familiarity (capped)",
		treated.fed
			and treated.fedUntil == t0 + fed
			and treated.familiarity == 1
			and treated.effects[2] == "PumpkinHead"
	)

	local treatsOk = true
	for _, item in Shop.Bakery do
		local effect = item.grantsEffect
		treatsOk = treatsOk
			and item.kind == "Food"
			and (item.familiarity or 0) > 0
			and (item.familiarity or 0) <= 1
			and effect ~= nil
			and Effects.List[effect] ~= nil
			and Care.describe(item) ~= ""
			and Care.treat(item.id) == item
	end
	check("every treat is food with Familiarity and a real effect", treatsOk)

	local record = { slot = 5, bought = { PumpkinCandy = 2 } }
	check("buys count within a restock", Workshop.boughtThisSlot(record, 5).PumpkinCandy == 2)
	check("buys reset on the next restock", Workshop.boughtThisSlot(record, 6).PumpkinCandy == nil)
end

-- Roaming effects (Util/Haunting).
do
	local function monster(effects: { string }, fed: boolean): any
		return { monsterId = "Gravepup", size = "Normal", effects = effects, familiarity = 0, fed = fed }
	end
	check(
		"a new monster in the Foyer rolls at the base chance",
		near(Haunting.chance(0, 1, nil), Effects.RoamChance)
	)
	check(
		"Familiarity, wings and a Blood Moon raise the odds",
		Haunting.chance(1, 1, nil) > Haunting.chance(0, 1, nil)
			and Haunting.chance(0, 3, nil) > Haunting.chance(0, 1, nil)
			and near(Haunting.chance(0, 1, 2), 2 * Effects.RoamChance)
	)
	check("the odds never pass 100%", Haunting.chance(1, 6, 1000) == 100)

	local poolOk = true
	for _, option in Haunting.pool(nil) do
		poolOk = poolOk and Effects.List[option.id].source == "Roam" and option.weight > 0
	end
	check("the roam pool only holds Roam effects", poolOk and #Haunting.pool(nil) == 5)
	local withEvent = Haunting.pool("Bloodmoon")
	local hasEvent = false
	for _, option in withEvent do
		hasEvent = hasEvent or option.id == "Bloodmoon"
	end
	check("a live event adds its effect to the pool", hasEvent and #withEvent == 6)

	local random = fakeRandom(11)
	check("hungry monsters pick up nothing", Haunting.roll(monster({}, false), 1, nil, random, true) == nil)
	local picked = Haunting.roll(monster({}, true), 1, nil, random, true)
	check("a forced roll picks a Roam effect", picked ~= nil and Effects.List[picked].source == "Roam")
	check(
		"a full monster picks up nothing",
		Haunting.roll(monster({ "Ghost", "Slimed", "PumpkinHead" }, true), 1, nil, random, true) == nil
	)
	-- Vampire on a monster with Batty and two more: only Vampire fits, because it merges into a Count.
	local count = 0
	for _ = 1, 50 do
		local id = Haunting.roll(monster({ "Batty", "Ghost", "Slimed" }, true), 1, nil, random, true)
		if id == "Vampire" then
			count += 1
		end
	end
	check("an effect that completes a combo still fits", count == 50)
	check(
		"a new combo is spotted",
		Value.newCombo({ "Batty", "Ghost" }, Value.resolveEffects({ "Batty", "Ghost", "Vampire" })) == "Count"
	)

	-- About RoamChance% of plain rolls hit.
	local hits = 0
	local trials = 20000
	for _ = 1, trials do
		if Haunting.roll(monster({}, true), 1, nil, random) then
			hits += 1
		end
	end
	check("rolls hit about RoamChance% of the time", math.abs(hits / trials * 100 - Effects.RoamChance) < 0.6)
end

-- Monster attacks (#6).
do
	-- Every zone monster has an attack of a known kind, and no attack is for a missing monster.
	local allArmed = true
	for _, m in Monsters do
		if
			m.zone
			and not (AttackConfig.Monsters[m.id] and AttackConfig.Kinds[AttackConfig.Monsters[m.id].kind])
		then
			allArmed = false
			print("  no attack for " .. m.id)
		end
	end
	check("every zone monster has an attack", allArmed)
	local noStrays = true
	for id in AttackConfig.Monsters do
		if not Monsters[id] then
			noStrays = false
			print("  attack for unknown monster " .. id)
		end
	end
	check("every attack belongs to a monster", noStrays)
	check("event monsters don't attack (yet)", Attacks.forMonster("Flickerwick", 8) == nil)

	local gravepup = Attacks.forMonster("Gravepup", 3)
	local wispJack = Attacks.forMonster("WispJack", 2)
	local lady = Attacks.forMonster("LadyOfLanterns", 7)
	local heron = Attacks.forMonster("MoonlitHeron", 7)
	assert(gravepup and wispJack and lady and heron)
	check("a charge costs a heart", gravepup.kind == "Charge" and gravepup.damage == 1)
	check("a blind is harmless on a low rarity", wispJack.damage == 0)
	check("a Divine blind costs a heart", lady.damage == 1)
	check("a blink never costs a heart", heron.damage == 0)
	check("rarer monsters attack more often", Attacks.cooldown(1) == 10 and Attacks.cooldown(5) == 6)
	check("the cooldown has a floor", Attacks.cooldown(7) == AttackConfig.CooldownMin)

	-- Targets: nearest hunter in reach, skipping hunters already busy with enough monsters.
	local max = AttackConfig.MaxAttackersPerHunter
	local hunters: { Attacks.Hunter } = {
		{ x = 10, z = 0, attackers = max, mine = false },
		{ x = 20, z = 0, attackers = 0, mine = false },
		{ x = 500, z = 0, attackers = 0, mine = false },
	}
	check("a busy hunter is skipped", Attacks.pickTarget(0, 0, hunters) == 2)
	hunters[1].mine = true
	check("its own target still counts", Attacks.pickTarget(0, 0, hunters) == 1)
	check("nobody close means no target", Attacks.pickTarget(1000, 1000, hunters) == nil)

	-- Charge: a lane that runs a bit past the hunter; stepping sideways dodges it.
	local ax, az = Attacks.aim(gravepup, 0, 0, 10, 0)
	check("a charge runs past the hunter", near(ax, 16) and near(az, 0))
	check("standing in the lane is a hit", Attacks.hits(gravepup, 0, 0, ax, az, 10, 0))
	check(
		"stepping out of the lane dodges it",
		not Attacks.hits(gravepup, 0, 0, ax, az, 10, gravepup.radius + 1)
	)
	local px, pz = Attacks.pushDirection(gravepup, 0, 0, ax, az, 10, 2)
	check("a charge pushes along the lane", near(px, 1) and near(pz, 0))

	-- Throw: lands where you stood when the warning showed.
	local bone = Attacks.forMonster("Mossbones", 2)
	assert(bone)
	local tx, tz = Attacks.aim(bone, 0, 0, 20, 5)
	check("a throw lands on your old spot", near(tx, 20) and near(tz, 5))
	check("a throw misses once you move away", not Attacks.hits(bone, 0, 0, tx, tz, 20 + bone.radius + 1, 5))

	-- Shockwave: a ring around the monster.
	local scream = Attacks.forMonster("TheGroundskeeper", 5)
	assert(scream)
	check("a shockwave hits close by", Attacks.hits(scream, 0, 0, 0, 0, scream.radius - 1, 0))
	check("a shockwave misses further out", not Attacks.hits(scream, 0, 0, 0, 0, scream.radius + 1, 0))

	-- Chasing stops inside the attack range.
	local cx, cz = Attacks.chaseSpot(40, 0, 0, 0, gravepup.range)
	check("a chase stops inside the range", cx <= gravepup.range and cx > 0 and near(cz, 0))
	check("the hit message", Attacks.hitMessage("Gravepup", gravepup) == "Gravepup charged at you! -1 heart")

	-- Roam.clamp keeps a target on the floor.
	local rects = { Roam.rect(0, 0, 20, 20, 3) }
	local inside = Roam.clamp(rects, 4, -2, 1)
	local outside = Roam.clamp(rects, 50, 0, 1)
	check("clamp leaves an inside point alone", inside ~= nil and near(inside.x, 4) and near(inside.z, -2))
	check("clamp pulls an outside point in", outside ~= nil and near(outside.x, 9) and near(outside.y, 3))
end

-- Monster looks: every look is for a real monster, every part has a size, and walkers
-- feet touch y = -2 so they stand on the floor.
do
	local ok, feetOk = true, true
	for id, look in Looks do
		-- #look catches parts written after `pieces` closed (they'd silently never be built)
		ok = ok and Monsters[id] ~= nil and #look.pieces > 0 and #(look :: any) == 0
		local lowest = math.huge
		for _, piece in look.pieces do
			ok = ok and #piece.size == 3 and #piece.at == 3 and #piece.color == 3
			ok = ok and piece.size[1] > 0 and piece.size[2] > 0 and piece.size[3] > 0
			lowest = math.min(lowest, piece.at[2] - piece.size[2] / 2)
		end
		if look.gait == "walk" and not near(lowest, -2) then
			feetOk = false
			print(`  {id}'s feet are at {lowest}, not -2`)
		end
	end
	check("every look is for a known monster and has sized parts", ok)
	check("walkers stand on the floor", feetOk)
end

-- Mansion rooms: every part is sized, uses a real material, stays inside its floor, and
-- the doors open for owned wings only.
do
	local materials = {
		Plaster = true,
		WoodPlanks = true,
		Wood = true,
		Slate = true,
		Metal = true,
		Neon = true,
		Fabric = true,
		SmoothPlastic = true,
		Glass = true,
		Marble = true,
		Grass = true,
		Marble = true,
		Ground = true,
		Cobblestone = true,
	}
	local all = { Foyer = true, Library = true, Ballroom = true, Attic = true, Crypt = true, Garden = true }
	local expectBoarded = { Foyer = 6, Library = 2, Ballroom = 2, Attic = 0, Crypt = 0, Garden = 0 }
	for wingId, recipe in Rooms.ByWing do
		local spot = Layout.Wings[wingId]
		local function build(owned: { [string]: boolean })
			local ok, names, boarded = true, {}, 0
			for _, p in recipe(spot.width, spot.depth, owned) do
				ok = ok and #p.size == 3 and #p.at == 3 and #p.color == 3 and materials[p.material] == true
				-- A threshold may reach over the 2-stud gap to the next floor.
				ok = ok
					and math.abs(p.at[1]) <= spot.width / 2 + 2
					and math.abs(p.at[3]) <= spot.depth / 2 + 2
				ok = ok and p.at[2] - p.size[2] / 2 >= -1.01 and p.at[2] <= Rooms.WallHeight + 8
				if names[p.name] then
					ok = false
					print(`  {wingId} has two parts named {p.name}`)
				end
				names[p.name] = true
				if string.find(p.name, "Boarded") then
					boarded += 1
				end
			end
			return ok, boarded
		end
		local ok, shut = build({ Foyer = true })
		local _, open = build(all)
		check(`{wingId} parts are sized, named once and inside the room`, ok)
		check(
			`{wingId} doors are boarded until the next wing is bought`,
			shut == expectBoarded[wingId] and open == 0
		)
	end
end

-- Hub landmarks: every part is sized, uses a real material and stays on the landmark's spot,
-- the shops have a counter spot in front, and the middle of Watcher Square stays clear for
-- the Watcher's meter.
do
	local materials = {
		WoodPlanks = true,
		Wood = true,
		Slate = true,
		Metal = true,
		Neon = true,
		Fabric = true,
		SmoothPlastic = true,
		Glass = true,
		Cobblestone = true,
		Brick = true,
	}
	local spots = {}
	for _, spot in Layout.Landmarks do
		spots[spot.name] = spot
	end
	for name, recipe in Landmarks.ByName do
		local spot = spots[name]
		local ok, names, byName = spot ~= nil, {}, {}
		for _, p in recipe() do
			ok = ok and #p.size == 3 and #p.at == 3 and #p.color == 3 and materials[p.material] == true
			ok = ok
				and math.abs(p.at[1]) <= spot.width / 2 + 1
				and math.abs(p.at[3]) <= spot.depth / 2 + 1
				and (p.rot ~= nil or p.at[2] - p.size[2] / 2 >= -0.01) -- nothing sunk into the ground
			if names[p.name] then
				ok = false
				print(`  {name} has two parts named {p.name}`)
			end
			names[p.name] = true
			byName[p.name] = p
		end
		check(`{name} parts are sized, named once and on its spot`, ok)
		check(`{name} has its anchor part`, byName[Landmarks.Anchor[name]] ~= nil)
		if name ~= "WatcherSquare" then
			local spotPart, counter = byName[Landmarks.CounterSpot], byName.Counter
			check(
				`{name} counter spot is invisible and in front of the counter`,
				spotPart ~= nil
					and counter ~= nil
					and spotPart.transparency == 1
					and not spotPart.solid
					and spotPart.at[3] < counter.at[3] - counter.size[3] / 2
			)
		end
	end
	local clear = true
	for _, p in Landmarks.WatcherSquare() do
		if
			p.name ~= "Plaza"
			and math.abs(p.at[1]) - p.size[1] / 2 < 2
			and math.abs(p.at[3]) - p.size[3] / 2 < 2
		then
			clear = false
		end
	end
	check("the middle of Watcher Square is clear for the Watcher's meter", clear)
end

-- Portals and zone scenery: every part is sized, uses a real material and is named once,
-- zone props stay inside the fence and off the ground monsters roam, and that ground stays
-- clear of the arrival pad and the exit.
do
	local materials = {
		WoodPlanks = true,
		Wood = true,
		Slate = true,
		Metal = true,
		Neon = true,
		Fabric = true,
		SmoothPlastic = true,
		Glass = true,
		Cobblestone = true,
		Ground = true,
		Grass = true,
		Marble = true,
	}
	local function valid(parts: { Rooms.Part }, limit: number): boolean
		local ok, names = true, {}
		for _, p in parts do
			ok = ok and #p.size == 3 and #p.at == 3 and #p.color == 3 and materials[p.material] == true
			if math.abs(p.at[1]) > limit or math.abs(p.at[3]) > limit then
				ok = false
				print(`  {p.name} is outside the fence`)
			end
			if names[p.name] then
				ok = false
				print(`  two parts named {p.name}`)
			end
			names[p.name] = true
		end
		return ok
	end
	local hub, exit = Scenery.HubPortal, Scenery.ExitPortal
	check(
		"the hub portal matches the gate size",
		hub.width == Layout.GateSize.width
			and hub.height == Layout.GateSize.height
			and hub.thickness == Layout.GateSize.thickness
	)
	for _, zone in require("../src/shared/Config/Zones").List do
		check(
			`{zone.id} arches are sized and named once`,
			valid(Scenery.Arch(zone.id, hub.width, hub.height, hub.thickness, not zone.launch), 20)
				and valid(Scenery.Arch(zone.id, exit.width, exit.height, exit.thickness, false), 20)
		)
	end
	local function inside(
		x: number,
		z: number,
		r: { x: number, z: number, width: number, depth: number },
		pad: number
	)
		return math.abs(x - r.x) < r.width / 2 + pad and math.abs(z - r.z) < r.depth / 2 + pad
	end
	for id, zone in Scenery.Zones do
		local parts, cliffs = {}, {}
		for _, p in zone.parts() do
			table.insert(if string.find(p.name, "^Cliff") then cliffs else parts, p)
		end
		check(
			`{id} parts are sized, named once and inside the fence`,
			valid(parts, Layout.ZoneSize.x / 2 - 1)
		)
		local outside = #cliffs > 0
		for _, p in cliffs do
			local half = Layout.ZoneSize.x / 2
			outside = outside
				and (math.abs(p.at[1]) - p.size[1] / 2 >= half or math.abs(p.at[3]) - p.size[3] / 2 >= half)
		end
		check(`{id} cliffs ring the zone outside its walls`, outside)
		local clear = true
		for _, p in parts do
			-- Slabs level with the ground may lie under the roaming, low walk-through parts may be
			-- glided over, and monsters may walk under anything overhead.
			local hx, hz, bottom = Scenery.footprint(p)
			local top = p.at[2] * 2 - bottom
			local rise = if p.solid then 0.05 else Scenery.Low
			if math.abs(top) > 0.05 and not string.find(p.name, "^Fence") then
				for _, r in zone.roam do
					local y = r.y or 0
					if
						top > y + rise
						and bottom < y + Scenery.Overhead
						and math.abs(p.at[1] - r.x) < hx + r.width / 2
						and math.abs(p.at[3] - r.z) < hz + r.depth / 2
					then
						clear = false
						print(`  {id}: {p.name} stands on the monsters' ground`)
					end
				end
			end
		end
		check(`{id} props stay off the monsters' ground`, clear)
		local roomy = true
		for _, r in zone.roam do
			roomy = roomy
				and math.abs(r.x) + r.width / 2 <= Layout.ZoneSize.x / 2
				and math.abs(r.z) + r.depth / 2 <= Layout.ZoneSize.z / 2
				and not inside(Layout.ZoneArrival.x, Layout.ZoneArrival.z, r, 5)
				and not inside(Layout.ZoneExit.x, Layout.ZoneExit.z, r, 5)
		end
		check(`{id} roaming ground is inside the zone and clear of the arrival and exit`, roomy)
		if zone.water then
			-- Monsters roam over the water's surface: ground over a pool lies wholly in it, at
			-- the surface.
			local surface = (zone.waterDepth or 2) - (zone.bed or 0)
			local dry = surface < 0
			for _, pool in zone.water do
				dry = dry and pool.y == surface
				for _, r in zone.roam do
					local over = math.abs(pool.x - r.x) < (pool.width + r.width) / 2
						and math.abs(pool.z - r.z) < (pool.depth + r.depth) / 2
					if over then
						dry = dry
							and r.y == surface
							and math.abs(pool.x - r.x) + r.width / 2 <= pool.width / 2
							and math.abs(pool.z - r.z) + r.depth / 2 <= pool.depth / 2
					end
				end
			end
			check(`{id} water stays below the ground; monsters roam on its surface`, dry)
		end
	end
end

-- The hub map: every part sized and named once, everything but the cliffs inside the oval,
-- and nothing standing on a plot, a landmark, a gate or the landing spot.
do
	local HubMap = require("../src/shared/Config/HubMap")
	local parts = HubMap.parts()
	local ok, names = #parts > 0, {}
	local blocked: { { number } } = {} -- minX, maxX, minZ, maxZ
	local hx, hz = Layout.PlotSize.x / 2, Layout.PlotSize.z / 2
	for _, plot in Layout.Plots do
		table.insert(blocked, { plot.x - hx, plot.x + hx, plot.z - hz, plot.z + hz })
	end
	for _, spot in Layout.Landmarks do
		-- Turned to face the middle along x (WorldBuilder.landmarkFrame), or not turned.
		local w, d = spot.width / 2, spot.depth / 2
		if math.abs(spot.x) >= math.abs(spot.z) and spot.x ~= 0 then
			w, d = d, w
		end
		table.insert(blocked, { spot.x - w, spot.x + w, spot.z - d, spot.z + d })
	end
	for _, gate in Layout.Gates do
		table.insert(blocked, { gate.x - 4, gate.x + 4, gate.z - 11, gate.z + 11 })
	end
	local back = Layout.ReturnPoint
	for _, p in parts do
		ok = ok
			and #p.size == 3
			and #p.at == 3
			and #p.color == 3
			and p.size[1] > 0
			and p.size[2] > 0
			and p.size[3] > 0
		if names[p.name] then
			ok = false
			print(`  two hub map parts named {p.name}`)
		end
		names[p.name] = true
		local fx, fz = Scenery.footprint(p)
		if not string.find(p.name, "^Cliff") then
			for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
				if not HubMap.inside(p.at[1] + c[1] * fx, p.at[3] + c[2] * fz, 0) then
					ok = false
					print(`  {p.name} hangs over the edge of the hub`)
					break
				end
			end
			for _, b in blocked do
				if
					p.at[1] + fx > b[1]
					and p.at[1] - fx < b[2]
					and p.at[3] + fz > b[3]
					and p.at[3] - fz < b[4]
				then
					ok = false
					print(`  {p.name} stands on a plot, landmark or gate`)
				end
			end
			-- Paths may run over the landing spot; nothing else may stand on it.
			local flat = p.at[2] + p.size[2] / 2 <= 0.2
			if not flat and math.abs(p.at[1] - back.x) < fx + 3 and math.abs(p.at[3] - back.z) < fz + 3 then
				ok = false
				print(`  {p.name} stands on the landing spot`)
			end
		elseif HubMap.inside(p.at[1], p.at[3], 0) then
			ok = false
			print(`  {p.name} is inside the hub`)
		end
	end
	check("the hub map stays inside the oval and off the plots, landmarks, gates and landing spot", ok)
end

-- Open ground: monsters may roam everywhere except near solid props on the floor (props high
-- overhead don't count), the arrival pad and the exit.
do
	local box = {
		name = "Box",
		size = { 10, 4, 10 },
		at = { 40, 2, 40 },
		color = { 0, 0, 0 },
		material = "Slate",
		solid = true,
	}
	local roof = {
		name = "Roof",
		size = { 30, 1, 30 },
		at = { -40, 12, 40 },
		color = { 0, 0, 0 },
		material = "Slate",
		solid = true,
	}
	local rects = Scenery.openGround({ box :: any, roof :: any })
	local function onGround(x: number, z: number): boolean
		for _, r in rects do
			if math.abs(x - r.x) <= r.width / 2 and math.abs(z - r.z) <= r.depth / 2 then
				return true
			end
		end
		return false
	end
	check("open ground leaves out the cells round a prop", not onGround(40, 40) and not onGround(45.5, 40))
	check(
		"open ground runs under a roof and across the rest",
		onGround(-40, 40) and onGround(0, 0) and onGround(80, -60)
	)
	check(
		"open ground leaves out the arrival pad and the exit",
		not onGround(-20, -90) and not onGround(20, -100)
	)
	-- Most of each zone is open (the rectangles may overlap, so count spots on a grid).
	for id, zone in Scenery.Zones do
		local open, total = 0, 0
		for x = -105, 105, 2 do
			for z = -105, 105, 2 do
				total += 1
				for _, r in zone.roam do
					if math.abs(x - r.x) <= r.width / 2 and math.abs(z - r.z) <= r.depth / 2 then
						open += 1
						break
					end
				end
			end
		end
		check(`monsters roam most of {id}`, open > 0.6 * total)
	end

	-- A floor of water: ground over it sits at its height, and a stone poking out of the water
	-- (but not up to the ground) still blocks it.
	local pool = { x = 40, z = -40, width = 20, depth = 20, y = -2 }
	local stone = {
		name = "Stone",
		size = { 2, 2, 2 },
		at = { 40, -2, -40 },
		color = { 0, 0, 0 },
		material = "Slate",
		solid = true,
	}
	local wet = Scenery.openGround({ stone :: any }, { floors = { pool } })
	local onWater, onStone, dryAround = false, false, true
	for _, r in wet do
		local inPool = math.abs(r.x - 40) < 10 and math.abs(r.z + 40) < 10
		if math.abs(35 - r.x) <= r.width / 2 and math.abs(-35 - r.z) <= r.depth / 2 then
			onWater = r.y == -2
		end
		if math.abs(40 - r.x) <= r.width / 2 and math.abs(-40 - r.z) <= r.depth / 2 then
			onStone = true
		end
		dryAround = dryAround and (inPool == (r.y == -2))
	end
	check("open ground runs over a pool at its surface", onWater and dryAround)
	check("a stone in the water blocks the ground over it", not onStone)
end

-- Roaming legs stay on the floor: a straight line between two patches of open ground may not
-- cut across what's between them, but may step over a small gap between two floors.
do
	local L = { Roam.rect(-30, 0, 20, 100, 0), Roam.rect(30, 0, 20, 100, 0), Roam.rect(0, 45, 80, 10, 0) }
	check("a leg along one patch stays on the floor", Roam.lineInside(L, -30, -40, -30, 40, 1.5))
	check("a leg round the corner stays on the floor", Roam.lineInside(L, -30, 45, 30, 45, 1.5))
	check("a leg straight across the props is refused", not Roam.lineInside(L, -30, -40, 30, -40, 1.5))
	local wings = { Roam.rect(-21, 0, 40, 40, 0), Roam.rect(21, 0, 40, 40, 0) }
	check("a leg may step over the gap between two wings", Roam.lineInside(wings, -30, 0, 30, 0, 1.5))
	-- A big orb never squeezes through a gap narrower than itself.
	local gap = { Roam.rect(-20, 0, 30, 30, 0), Roam.rect(0, 0, 10, 2, 0), Roam.rect(20, 0, 30, 30, 0) }
	check("a small orb may cross a narrow gap", Roam.lineInside(Roam.fitting(gap, 0.8), -20, 0, 20, 0, 0.25))
	check(
		"a big orb can't cross a narrow gap",
		not Roam.lineInside(Roam.fitting(gap, 3), -20, 0, 20, 0, 0.25)
	)
end

-- Fast travel and the faster hub walk.
do
	local hub = TravelConfig.HubWalkSpeed
	check("the hub walk is faster than normal", hub > 16)
	check("Watcher Square is open hub", Travel.walkSpeed(false, 0, 0, 16, hub) == hub)
	check("the Zone Gates are open hub", Travel.walkSpeed(false, 370, 0, 16, hub) == hub)
	check("the Bakery is open hub", Travel.walkSpeed(false, -380, -45, 16, hub) == hub)
	local onPlot = true
	for _, plot in Layout.Plots do
		onPlot = onPlot
			and Travel.inPlot(plot.x, plot.z)
			and Travel.walkSpeed(false, plot.x, plot.z, 16, hub) == 16
	end
	check("every mansion plot walks at normal speed", onPlot)
	check("zones walk at normal speed", Travel.walkSpeed(true, 0, 1500, 16, hub) == 16)
	local ids = {}
	for _, destination in TravelConfig.Destinations do
		ids[destination.id] = true
	end
	check(
		"fast travel goes to the portals and both shops",
		ids.Portals and ids.Bakery and ids.Workshop or false
	)
	local landmarks = {}
	for _, spot in Layout.Landmarks do
		landmarks[spot.name] = true
	end
	check("fast-travel shops are hub landmarks", landmarks.Bakery and landmarks.Workshop or false)
end

if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("all checks passed")
