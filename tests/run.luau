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
local CakeConfig = require("../src/shared/Config/Cakes")
local Cakes = require("../src/shared/Util/Cakes")
local Effects = require("../src/shared/Config/Effects")
local Haunting = require("../src/shared/Util/Haunting")
local Away = require("../src/shared/Util/Away")
local AttackConfig = require("../src/shared/Config/Attacks")
local Attacks = require("../src/shared/Util/Attacks")
local Landmarks = require("../src/shared/Config/Landmarks")
local Looks = require("../src/shared/Config/Looks")
local Rooms = require("../src/shared/Config/Rooms")
local Scenery = require("../src/shared/Config/Scenery")
local Travel = require("../src/shared/Util/Travel")
local TravelConfig = require("../src/shared/Config/Travel")
local Storage = require("../src/shared/Util/Storage")
local Tools = require("../src/shared/Config/Tools")
local Variants = require("../src/shared/Config/Variants")
local InventoryConfig = require("../src/shared/Config/Inventory")
local Weight = require("../src/shared/Util/Weight")
local WeightConfig = require("../src/shared/Config/Weight")

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
do
	local function slimed(id: string): any
		return { monsterId = id, size = "Normal", effects = { "Slimed", "Mummy" }, familiarity = 0 }
	end
	check(
		"effects add less on cheap monsters",
		near(Value.monsterEffectMultiplier(slimed("Gloomlet")), 1 + 4 * Value.CheapEffectShare)
			and Value.monsterEffectMultiplier(slimed("Gravepup")) < Value.monsterEffectMultiplier(
				slimed("LadyOfLanterns")
			)
			and near(Value.monsterEffectMultiplier({ monsterId = "Gloomlet", effects = {} } :: any), 1)
	)
end

local caught = { monsterId = "Gravepup", size = "Big", effects = { "Ghost" }, familiarity = 0 }
check("value uses effects", Value.sellValue(caught, 1) == 27_000) -- 10,000 x 1.5 x (1 + 2 x 0.4: a cheap monster)

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

check("the Dust Buster gives no catch effects", #Spawning.rollCatchEffects("DustBuster", rng) == 0)
local alwaysHit = {
	NextNumber = function(_self)
		return 0
	end,
}
local effects = Spawning.rollCatchEffects("VoidVac", alwaysHit :: any)
check(
	"the Void Vac can give Ghost and Werewolf",
	#effects == 2 and table.find(effects, "Ghost") ~= nil and table.find(effects, "Werewolf") ~= nil
)
local neverHit = {
	NextNumber = function(_self)
		return 0.999999
	end,
}
check("the Dust Buster never rolls a variant", Spawning.rollVariant("DustBuster", alwaysHit :: any) == nil)
check("a lucky Void Vac catch is Rainbow", Spawning.rollVariant("VoidVac", alwaysHit :: any) == "Rainbow")
check("an unlucky catch has no variant", Spawning.rollVariant("VoidVac", neverHit :: any) == nil)
-- The little stand-in above is too streaky for several rolls in a row; math.random isn't.
math.randomseed(5)
local variantRng = {
	NextNumber = function(_self)
		return math.random()
	end,
}
local golds = 0
for _ = 1, 20_000 do
	if Spawning.rollVariant("BansheeBlower", variantRng :: any) == "Gold" then
		golds += 1
	end
end
-- Gold is checked after Shiny (0.5%), so it lands a little under its 3%.
check("about 3% of Banshee Blower catches are Gold", math.abs(golds / 20_000 - 0.03) < 0.005)
do
	local plain: any = { monsterId = "Gravepup", size = "Normal", effects = {}, familiarity = 0 }
	local gold: any = table.clone(plain)
	gold.variant = "Gold"
	check("a Gold monster sells for x5", Value.sellValue(gold, 1) == 5 * Value.sellValue(plain, 1))
end

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
check("better vacuums reach further", Catching.reach("VoidVac") > Catching.reach("DustBuster"))
check(
	"the Dust Buster carries one, the Void Vac four",
	Catching.bagSize("DustBuster") == 1 and Catching.bagSize("VoidVac") == 4
)
check("an unknown vacuum can't reach anything", Catching.reach("Broom") == 0)
do
	local inventory = { StrobeLight = 1, Moonbeam = 1, CandleLamp = 1, BaitBell = 2 }
	local refund = Workshop.refundRetired(inventory)
	check("retired tools are refunded", refund == Shop.Retired.StrobeLight + Shop.Retired.Moonbeam)
	check(
		"retired tools leave the inventory, the rest stays",
		inventory.StrobeLight == nil
			and inventory.Moonbeam == nil
			and inventory.CandleLamp == nil
			and inventory.BaitBell == 2
	)
	check("nothing to refund twice", Workshop.refundRetired(inventory) == 0)
end

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

-- Watcher: the event clock, the eyes and event monsters.
do
	local clockRng = fakeRandom(11)
	local shortest, longest = math.huge, 0
	for _ = 1, 5_000 do
		local gap = Watcher.gap(clockRng)
		shortest = math.min(shortest, gap)
		longest = math.max(longest, gap)
	end
	check(
		"events come 5 to 10 minutes apart",
		shortest >= 5 * 60 and longest <= 10 * 60 and shortest < 5.5 * 60 and longest > 9.5 * 60
	)

	local repeats, awakenings, counts = 0, 0, {} :: { [string]: number }
	local last: string? = nil
	for _ = 1, 20_000 do
		local event = Watcher.pick(last, 0, clockRng)
		if event.id == last then
			repeats += 1
		end
		if event.awakening then
			awakenings += 1
		end
		counts[event.id] = (counts[event.id] or 0) + 1
		last = event.id
	end
	check("the same event never plays twice in a row", repeats == 0)
	check("The Watcher Awakens only comes with all eyes open", awakenings == 0)
	check("events that aren't launched never play", counts.MimicNight == nil and counts.BreachStorm == nil)
	check("Frost Fog is commoner than Blood Moon", (counts.FrostFog or 0) > (counts.BloodMoon or 0) * 2)
	check(
		"every weighted launch event can play",
		counts.FrostFog ~= nil
			and counts.SugarRush ~= nil
			and counts.GoldRush ~= nil
			and counts.Flicker ~= nil
			and counts.BloodMoon ~= nil
	)
	check(
		"all eyes open means The Watcher Awakens",
		Watcher.pick("Flicker", Events.EyesToAwaken, clockRng).id == "WatcherAwakens"
	)

	-- The global schedule: worked out from the clock alone, so every server agrees.
	local day = Watcher.Epoch + 3 * 86400 + 1234
	local here, there = Watcher.slotAt(day), Watcher.slotAt(day)
	check(
		"every server works out the same event at the same time",
		here.index == there.index and here.event.id == there.event.id and here.warnAt == there.warnAt
	)
	check("the slot found is the one under way", here.endAt > day and here.index > 1)
	local walk = Watcher.slotAt(Watcher.Epoch)
	local seamless, spaced, awakened, sameTwice = true, true, false, false
	for _ = 1, 400 do
		local after = Watcher.nextSlot(walk)
		local gap = after.warnAt - walk.endAt
		seamless = seamless and after.index == walk.index + 1
		spaced = spaced and gap >= Events.GapMinSeconds and gap <= Events.GapMaxSeconds
		awakened = awakened or after.event.awakening == true
		sameTwice = sameTwice or after.event.id == walk.event.id
		if walk.event.awakening then
			seamless = seamless and after.eyes == 0
		end
		walk = after
	end
	check("scheduled events come 5 to 10 minutes apart, one after another", seamless and spaced)
	check("The Watcher Awakens comes round in the schedule", awakened)
	check("the schedule never plays the same event twice in a row", not sameTwice)
	local again = Watcher.slotAt(walk.startAt)
	check(
		"finding a slot from the clock matches stepping to it",
		again.index == walk.index and again.event.id == walk.event.id
	)

	local frostLines = Watcher.effectLines(Events.find("FrostFog") :: Events.WatcherEvent)
	check(
		"the event icon names the effect and its chance",
		frostLines[1] == "Gives Frostbitten (x2.5 value)"
			and frostLines[2] == "6% chance per monster every 30 s"
	)
	local watchedLines =
		table.concat(Watcher.effectLines(Events.find("WatcherAwakens") :: Events.WatcherEvent), "|")
	check(
		"The Watcher Awakens shows its rare chance",
		string.find(watchedLines, "0.3% chance", 1, true) ~= nil
			and string.find(watchedLines, "another event", 1, true) ~= nil
	)

	local eyes = 0
	for _ = 1, Events.EyesToAwaken do
		eyes = Watcher.eyesAfter(eyes, Watcher.pick(nil, eyes, clockRng))
	end
	check("each event opens an eye", eyes == Events.EyesToAwaken)
	eyes = Watcher.eyesAfter(eyes, Watcher.pick(nil, eyes, clockRng))
	check("The Watcher Awakens closes all the eyes", eyes == 0)

	local skies = true
	for _, event in Events.List do
		if event.launch and not event.sky then
			skies = false
		end
	end
	check("every launch event has its own sky", skies)
	local loud = true
	for _, event in Events.List do
		if event.launch and event.sky then
			loud = loud and event.sky.weather ~= nil and event.sky.edge ~= nil
		end
	end
	check("every launch event has weather and a screen edge you can't miss", loud)
	check("Events.find finds by id", (Events.find("BloodMoon") :: any).name == "Blood Moon")
	check("Events.find returns nil for unknown ids", Events.find("Nope") == nil and Events.find(nil) == nil)

	check("at least 4 event monsters", Watcher.monsterCount(1) == Events.MinMonsters)
	check("one event monster per player", Watcher.monsterCount(7) == 7)
	check("at most 10 event monsters", Watcher.monsterCount(30) == Events.MaxMonsters)
	check("countdown clock", Watcher.clock(125) == "2:05" and Watcher.clock(-3) == "0:00")

	local eventRng = fakeRandom(3)
	local blood = Events.find("BloodMoon") :: Events.WatcherEvent
	local awakens = Events.find("WatcherAwakens") :: Events.WatcherEvent
	local wrong, wisps = 0, 0
	for _ = 1, 20_000 do
		local m = Watcher.rollMonster(blood.monsters :: any, eventRng)
		if m.event ~= "BloodMoon" then
			wrong += 1
		elseif m.id == "CrimsonWisp" then
			wisps += 1
		end
	end
	check("Blood Moon only spawns Blood Moon monsters", wrong == 0)
	check("about 70% of Blood Moon monsters are Crimson Wisps", math.abs(wisps / 20_000 - 0.7) < 0.02)

	local withMonsters: { string } = {}
	local used: { [string]: boolean } = {}
	for _, event in Events.List do
		if event.launch then
			local lists = { event.monsters }
			for _, set in event.monsterSets or {} do
				table.insert(lists, set.monsters)
			end
			if #lists > 0 then
				table.insert(withMonsters, event.id)
			end
			for _, list in lists do
				for id in list do
					used[id] = true
				end
			end
		end
	end
	table.sort(withMonsters)
	check(
		"only the rare events bring monsters",
		table.concat(withMonsters, ",") == "BloodMoon,WatcherAwakens"
	)
	local unused = {}
	for id, m in Monsters do
		if type(m) == "table" and m.event and not used[id] then
			table.insert(unused, id)
		end
	end
	check(`every event monster can spawn ({table.concat(unused, ", ")})`, #unused == 0)

	local bloodBatch = Watcher.monsterBatch(blood.monsters :: any, 4, eventRng)
	local kindsSeen: { [string]: boolean } = {}
	for _, m in bloodBatch do
		kindsSeen[m.id] = true
	end
	check(
		"Blood Moon shows both its monsters",
		#bloodBatch == 4 and kindsSeen.CrimsonWisp == true and kindsSeen.Moonhowler == true
	)

	local setCounts: { [string]: number } = {}
	for _ = 1, 10_000 do
		local set = Watcher.pickSet(awakens, eventRng) :: Events.MonsterSet
		setCounts[set.id] = (setCounts[set.id] or 0) + 1
	end
	check(
		"the Watcher usually brings Phantoms, sometimes Nightmares, rarely Eldritch",
		(setCounts.Phantoms or 0) > (setCounts.Nightmares or 0)
			and (setCounts.Nightmares or 0) > (setCounts.Eldritch or 0)
			and (setCounts.Eldritch or 0) > 0
	)
	check("other events have no monster sets", Watcher.pickSet(blood, eventRng) == nil)
	local nightmares = (awakens.monsterSets :: { Events.MonsterSet })[2]
	local pair = Watcher.monsterBatch(nightmares.monsters, 2, eventRng)
	check("a Nightmare Parade brings two different Nightmares", #pair == 2 and pair[1].id ~= pair[2].id)
	local weights, count = Watcher.spawns(awakens, nightmares, 8)
	check("a set's own count wins", weights == nightmares.monsters and count == 2)
	check(
		"the tooltip names the monsters",
		Watcher.monsterLine(blood) == "Monsters: Crimson Wisp, Moonhowler"
			and Watcher.monsterLine(awakens, "Eldritch") == "Eldritch Gaze: Eye Of The Watcher, Watcherling"
			and Watcher.monsterLine(Events.find("FrostFog") :: Events.WatcherEvent) == nil
	)

	-- Each Watcher set has its own look: ghosts, a lantern parade, or the event's eye sky.
	local function weatherOf(setId: string?): string?
		local sky = Events.skyFor(awakens, setId)
		return if sky and sky.weather then sky.weather.kind else nil
	end
	check(
		"each Watcher set has its own sky",
		weatherOf("Phantoms") == "Ghosts"
			and weatherOf("Nightmares") == "Lanterns"
			and Events.skyFor(awakens, "Eldritch") == awakens.sky
			and Events.skyFor(awakens, nil) == awakens.sky
			and Events.skyFor(blood, "Phantoms") == blood.sky
	)

	local valid = true
	for _, event in Events.List do
		local lists = { event.monsters or {} }
		for _, set in event.monsterSets or {} do
			table.insert(lists, set.monsters)
		end
		for _, list in lists do
			for id in list do
				local m = Monsters[id]
				if not m or m.event ~= event.id then
					valid = false
				end
			end
		end
	end
	check("event monster lists match Monsters config", valid)
	-- Event monsters wait for a better vacuum (Giles 2026-10-21: not the first one you buy).
	check(
		"event monsters need a later vacuum",
		not Catching.canVacuum("PhantomVac", "Normal", "Phantom", "Flickerwick")
			and Catching.canVacuum("SpiritSiphon", "Normal", "Phantom", "Flickerwick")
			and not Catching.canVacuum("SpiritSiphon", "Normal", "Phantom", "CrimsonWisp")
			and Catching.canVacuum("BansheeBlower", "Normal", "Phantom", "CrimsonWisp")
			and Catching.canVacuum("VoidVac", "Normal", "Phantom", "Moonhowler")
			and not Catching.canVacuum("MoonVac", "Normal", "Nightmare", "Doorknocker")
	)
	local everyNeedsOne = true
	for _, monster in Monsters do
		if
			monster.event
			and (not monster.vacuum or Catching.rank(monster.vacuum) <= Catching.rank("PhantomVac"))
		then
			everyNeedsOne = false
		end
	end
	check("every event monster needs more than the Phantom Vac", everyNeedsOne)
	check(
		"the Workshop says which events a vacuum opens up",
		table.concat(Workshop.unlocksEvents("BansheeBlower"), ",") == "Blood Moon"
			and table.concat(Workshop.unlocksEvents("VoidVac"), ",") == "Eldritch Gaze,Nightmare Parade"
			and #Workshop.unlocksEvents("PhantomVac") == 0
	)
	check(
		"the tooltip names the vacuum",
		Watcher.vacuumLine(blood) == "Catch with the Banshee Blower or better"
			and Watcher.vacuumLine(awakens, "Phantoms") == "Catch with the Spirit Siphon or better"
			and Watcher.vacuumLine(awakens, "Eldritch") == "Catch with the Void Vac or better"
			and Watcher.vacuumLine(Events.find("FrostFog") :: Events.WatcherEvent) == nil
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
	local siphon = Workshop.item("SpiritSiphon") :: Shop.Item
	local phantomVac = Workshop.item("PhantomVac") :: Shop.Item
	local voidVac = Workshop.item("VoidVac") :: Shop.Item
	local charm = Workshop.item("ReturnCharm") :: Shop.Item
	local starter = Workshop.item("DustBuster") :: Shop.Item
	check(
		"the same slot always has the same stock",
		Workshop.inStock(siphon, 1234) == Workshop.inStock(siphon, 1234)
	)
	local slots = 20_000
	local phantomIn, voidIn = 0, 0
	for slot = 1, slots do
		if Workshop.inStock(phantomVac, slot) then
			phantomIn += 1
		end
		if Workshop.inStock(voidVac, slot) then
			voidIn += 1
		end
	end
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
		Workshop.canBuy(siphon, 1, 1e9, { SpiritSiphon = 1 }, 0) == "Owned"
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
	local tagged = true
	for _, list in { Shop.Workshop, Shop.Bakery } do
		for _, item in list do
			local event = item.rarity == "Event"
			if not (Rarities[item.rarity] or event) or event ~= (item.event ~= nil) then
				tagged = false
			end
		end
	end
	check("every shop item has a rarity tag (Event for event treats)", tagged)
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

	-- Expected total value of the `take` best monsters this vacuum can hold out of `seen` wild
	-- ones in a zone (take = the bag size). Each one is rolled by spawnWeight and size weight;
	-- ones it can't hold count as 0.
	local function expectedTop(zone: number, vacuumId: string, seen: number, take: number): number
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
		local function choose(n: number, k: number): number
			local c = 1
			for i = 1, k do
				c = c * (n - k + i) / i
			end
			return c
		end
		-- P(the j-th best of `seen` is at most v) = P(fewer than j of them are above v).
		local function atMost(j: number, below: number): number
			local above = 1 - below
			local total = 0
			for i = 0, j - 1 do
				total += choose(seen, i) * above ^ i * below ^ (seen - i)
			end
			return total
		end
		local sum = 0
		for j = 1, math.min(take, seen) do
			local below, last = 0, 0
			for _, o in outcomes do
				below += o.p
				local now = atMost(j, math.min(below, 1))
				sum += o.value * (now - last)
				last = now
			end
		end
		return sum
	end
	local function expectedBest(zone: number, vacuumId: string, seen: number): number
		return expectedTop(zone, vacuumId, seen, 1)
	end

	-- Average value bonus a vacuum's catch effects and variants add to each catch.
	local function vacuumBonus(vacuumId: string): number
		local vacuum = Tools.Vacuums[vacuumId]
		local chance = Effects.CatchChance / 100
		local effects = 1
		for _, effectId in vacuum.catchEffects or {} do
			effects += chance * (Effects.List[effectId].multiplier - 1)
		end
		local variant, left = 0, 1
		for _, v in Variants do
			local p = left * (((vacuum.variants or {})[v.id] or 0) / 100)
			variant += p * v.multiplier
			left -= p
		end
		return effects * (variant + left)
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
			local starter = item.id == "DustBuster"
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
	local ladderOk = true
	local previous = "DustBuster"
	for _, id in { "PhantomVac", "SpiritSiphon", "BansheeBlower", "MoonVac", "VoidVac" } do
		local a, b = Tools.Vacuums[previous], Tools.Vacuums[id]
		ladderOk = ladderOk
			and vacuumBonus(id) > vacuumBonus(previous)
			and b.catchSeconds < a.catchSeconds
			and b.reach >= a.reach
			and b.bag >= a.bag
		previous = id
	end
	check("every vacuum up the ladder is better at everything", ladderOk)

	-- The upgrade order, and what a player uses while saving for each step (wings owned = zone).
	local order = {
		{ id = "PhantomVac", zone = 1, vacuum = "DustBuster" },
		{ id = "SpiritSiphon", zone = 1, vacuum = "PhantomVac" },
		{ id = "Library", zone = 1, vacuum = "SpiritSiphon" },
		{ id = "Ballroom", zone = 2, vacuum = "SpiritSiphon" },
		{ id = "BansheeBlower", zone = 3, vacuum = "SpiritSiphon" },
		{ id = "MoonVac", zone = 3, vacuum = "BansheeBlower" },
		{ id = "VoidVac", zone = 3, vacuum = "MoonVac" },
	}
	-- Each extra monster in the bag makes a trip about 20% longer (more catching).
	local function tripFor(vacuumId: string): number
		return tripSeconds * (1 + 0.2 * (Catching.bagSize(vacuumId) - 1))
	end
	local rising, paced = true, true
	local trips: { number } = {}
	local totalTrips = 0
	local totalSeconds, librarySeconds = 0, 0
	for i, step in order do
		local wingBoost = 1 + (step.zone - 1) * Wings.ValueBoostPerWing
		local perTrip = expectedTop(step.zone, step.vacuum, seen, Catching.bagSize(step.vacuum))
			* vacuumBonus(step.vacuum)
			* wingBoost
		trips[i] = priceOf(step.id) / perTrip
		totalTrips += trips[i]
		totalSeconds += trips[i] * tripFor(step.vacuum)
		if step.id == "Library" then
			librarySeconds = totalSeconds
		end
		print(`  pacing: {step.id} takes {math.floor(trips[i] * 10) / 10} trips`)
		if i > 1 then
			rising = rising and priceOf(step.id) > priceOf(order[i - 1].id)
			-- the sheet's curve: each step takes about 2-3x as long as the one before
			local ratio = trips[i] / trips[i - 1]
			paced = paced and ratio >= 1.5 and ratio <= 4
		end
	end
	check("prices rise along the upgrade order", rising)
	check("the Phantom Vac takes a few trips", trips[1] <= 3)
	check("each upgrade takes 1.5-4x as many trips as the one before", paced)
	check("the Library comes inside the first hour", librarySeconds / 60 <= 60)
	local hours = totalSeconds / 3600
	print(
		`  pacing: Library after {math.floor(librarySeconds / 60)} min, all tools after {math.floor(
			hours * 10
		) / 10} h`
	)
	check("the launch tools last 4-20 hours", hours >= 4 and hours <= 20)
	check(
		"Nightmare monsters need the Void Vac",
		not Catching.canVacuum("PhantomVac", "Normal", "Nightmare")
			and Catching.canVacuum("VoidVac", "Normal", "Nightmare")
	)
	check(
		"Eldritch monsters need the Void Vac",
		not Catching.canVacuum("PhantomVac", "Normal", "Eldritch")
			and Catching.canVacuum("VoidVac", "Normal", "Eldritch")
	)
end

-- Familiarity (Util/Care): it just grows with time, no hunger.
do
	local grow = Care.hours("Gravepup") * 3600
	local t0 = 1_000_000
	local m: any = {
		monsterId = "Gravepup",
		size = "Normal",
		effects = {},
		familiarity = 0,
		grownAt = t0,
		fed = false, -- an old save's hunger fields are cleared
		fedUntil = t0,
	}
	Care.settle(m, t0 + grow / 2)
	check("Familiarity grows with time", near(m.familiarity, 0.5))
	check("old hunger fields are cleared", m.fed == nil and m.fedUntil == nil)
	Care.settle(m, t0 + grow * 5)
	check("Familiarity stops at 100%", m.familiarity == 1 and Care.status(m) == "Fully familiar")

	local fresh: any = { monsterId = "Gloomlet", size = "Normal", effects = {}, familiarity = 0 }
	Care.settle(fresh, t0)
	check("a monster without a timestamp grows from now", fresh.grownAt == t0 and fresh.familiarity == 0)
	Care.settle(fresh, t0 - 50)
	check("a clock that went back never shrinks or regrows", fresh.familiarity == 0 and fresh.grownAt == t0)

	check(
		"cheaper monsters get familiar faster",
		Care.hours("Gloomlet") < Care.hours("Gravepup")
			and Care.hours("Gravepup") < Care.hours("LadyOfLanterns")
	)
	check(
		"Familiarity hours run from cheap to pricey",
		near(Care.hours("Gloomlet"), CareConfig.CheapHours)
			and Care.hours("LadyOfLanterns") <= CareConfig.PriceyHours
	)
	check(
		"an unknown monster takes the default time",
		Care.hours("NoSuchMonster") == CareConfig.FamiliarityHours
	)

	check("percent rounds down cleanly", Care.percent({ familiarity = 0.29 } :: any) == 29)

	-- Cakes (Util/Cakes): a bite only goes to a monster its effect can land on, if there is one.
	local candy = Cakes.item("PumpkinCandy") :: Shop.Item
	local cursed = Cakes.item("CursedCake") :: Shop.Item
	local function withEffects(effects: { string }): any
		return { monsterId = "Gravepup", size = "Normal", effects = effects, familiarity = 0.95 }
	end
	check("an unknown cake doesn't fit", Cakes.fits(withEffects({}), Cakes.item("VoidVac")) == "Unknown")
	check(
		"a cake's effect doesn't land twice",
		Cakes.fits(withEffects({ "PumpkinHead" }), candy) == "HasEffect"
	)
	check(
		"a cake's effect still fits a monster with many effects",
		Cakes.fits(withEffects({ "Ghost", "Mummy", "Possessed", "Slimed", "Werewolf" }), candy) == "Ok"
	)
	check(
		"a combo counts as one effect",
		Cakes.fits(withEffects({ "Vampire", "Batty", "Ghost" }), candy) == "Ok"
	)
	check(
		"an effect that completes a combo fits",
		Cakes.fits(withEffects({ "Ghost", "Vampire", "Possessed" }), cursed) == "Ok"
	)

	local cakesOk = true
	for _, item in Shop.Bakery do
		local chances = Cakes.effectChances(item)
		cakesOk = cakesOk
			and item.kind == "Food"
			and #chances > 0
			and Cakes.describe(item) ~= ""
			and Cakes.item(item.id) == item
			and CakeConfig.Looks[item.id] ~= nil
		for _, option in chances do
			cakesOk = cakesOk
				and Effects.List[option.effect] ~= nil
				and option.chance > 0
				and option.chance <= 100
		end
	end
	check("every cake has a look and real effects", cakesOk)

	-- Event treats: only in stock while their Watcher event is live; Sugar Rush raises the odds.
	local frostTart = Cakes.item("FrostTart") :: any
	check(
		"an event treat is only in stock during its event",
		frostTart ~= nil
			and Workshop.inStock(frostTart, 1, "FrostFog")
			and not Workshop.inStock(frostTart, 1, nil)
			and not Workshop.inStock(frostTart, 1, "GoldRush")
	)
	local treatsOk = true
	for _, item in Shop.Bakery do
		if item.event then
			local event = Events.find(item.event)
			treatsOk = treatsOk and event ~= nil and event.launch and event.effect == item.grantsEffect
		end
	end
	check("every event treat gives its event's effect", treatsOk)
	local eclair = Cakes.item("EclipseEclair") :: any
	local plain, rushed, lost = 0, 0, false
	for slot = 1, 20_000 do
		local before = Workshop.inStock(eclair, slot)
		local after = Workshop.inStock(eclair, slot, "SugarRush", 3)
		plain += if before then 1 else 0
		rushed += if after then 1 else 0
		lost = lost or (before and not after)
	end
	check("Sugar Rush triples restock chances", rushed > plain * 2.5 and not lost)
	check(
		"an event treat can only be bought during its event",
		Workshop.canBuy(frostTart, 1, 1e12, {}, 0) == "OutOfStock"
			and Workshop.canBuy(frostTart, 1, 1e12, {}, 0, "FrostFog") == "Ok"
	)

	local foodEffectsOk = true
	for id, effect in Effects.List do
		if effect.source == "Food" then
			local from = Cakes.item(effect.from or "")
			foodEffectsOk = foodEffectsOk and from ~= nil and from.grantsEffect == id
		end
	end
	check("every Food effect comes from the Bakery cake it names", foodEffectsOk)

	local fudge = Cakes.item("FangFudge") :: Shop.Item
	local mousse = Cakes.item("BoneMarrowMousse") :: Shop.Item
	local lucky = {
		NextNumber = function()
			return 0
		end,
		NextInteger = function(_, min: number)
			return min
		end,
	} :: any
	check(
		"a chance cake fits while one of its effects does",
		Cakes.fits(withEffects({ "Mummy" }), mousse) == "Ok"
	)
	check(
		"a chance cake doesn't fit when none of its effects can land",
		Cakes.fits(withEffects({ "Vampire" }), fudge) == "HasEffect"
	)
	check(
		"the mousse gives Batty when Mummy can't land",
		Cakes.pickEffect(withEffects({ "Mummy" }), mousse, lucky) == "Batty"
	)
	math.randomseed(7)
	local fake = {
		NextNumber = function()
			return math.random()
		end,
		NextInteger = function(_, min: number, max: number)
			return math.random(min, max)
		end,
	} :: any
	local tries, candyHits, vampires = 4000, 0, 0
	for _ = 1, tries do
		if Cakes.pickEffect(withEffects({}), candy, fake) then
			candyHits += 1
		end
		if Cakes.pickEffect(withEffects({}), fudge, fake) == "Vampire" then
			vampires += 1
		end
	end
	check(
		"a bite of a sure cake gives its effect about BiteEffectChance of the time",
		math.abs(candyHits / tries - CakeConfig.BiteEffectChance / 100) < 0.03
	)
	check(
		"a bite of Fang Fudge lands Vampire about 17.5% of the time",
		math.abs(vampires / tries - 0.175) < 0.03
	)
	check(
		"the odds shown are the real odds per bite",
		Cakes.describe(fudge) == "3 bites, at least one effect · Each bite: 17.5% Vampire (x2.5)"
	)
	check(
		"a chance cake shows each effect's real odds",
		Cakes.describe(mousse)
			== "3 bites, at least one effect · Each bite: 12.5% Mummy (x4), 37.5% Batty (x3)"
	)

	-- A bite never feeds and goes to a monster the effect can land on first.
	local has = withEffects({ "PumpkinHead" })
	has.uid = "a"
	local fresh = withEffects({})
	fresh.uid = "b"
	local placed = Cakes.new("PumpkinCandy", 0, 0, 0, t0)
	check(
		"a bite goes to a monster the effect can land on",
		Cakes.pickEater(placed, { has, fresh }, fake) == fresh
	)
	local b = Cakes.bite(placed, fresh, lucky)
	check(
		"a bite gives the effect and uses up a bite, nothing else",
		b.effect == "PumpkinHead" and placed.bitesLeft == CakeConfig.Bites - 1 and fresh.familiarity == 0.95
	)
	check("a monster only bites a cake once", Cakes.pickEater(placed, { fresh }, fake) == nil)
	local vamp = withEffects({ "Vampire" })
	vamp.uid = "c"
	local bat = Cakes.bite(Cakes.new("BoneMarrowMousse", 0, 0, 0, t0), vamp, lucky)
	check("a bite that makes no combo says none", bat.effect == "Mummy" and bat.combo == nil)
	local batty = withEffects({ "Vampire" })
	batty.uid = "d"
	table.insert(batty.effects, "Mummy") -- Mummy can't land again, so the mousse gives Batty
	local count = Cakes.bite(Cakes.new("BoneMarrowMousse", 0, 0, 0, t0), batty, lucky)
	check("Vampire + Batty from a bite makes a Count", count.effect == "Batty" and count.combo == "Count")
	check("cakes allowed: several per wing", Cakes.limit(3) == 3 * CakeConfig.PerWing and Cakes.limit(1) > 1)
	check(
		"better cakes reach further",
		Cakes.reach("EclipseEclair") > Cakes.reach("CursedCake")
			and Cakes.reach("CursedCake") > Cakes.reach("PumpkinCandy")
	)
	local reachOk = true
	for i = 2, #Shop.Bakery do
		reachOk = reachOk and Cakes.reach(Shop.Bakery[i].id) >= Cakes.reach(Shop.Bakery[i - 1].id)
	end
	check("reach never shrinks as cakes get pricier", reachOk)
	-- Bites come on a schedule, and every cake gives at least one effect.
	local timed = Cakes.new("PumpkinCandy", 0, 0, 0, t0)
	check(
		"bites are spread over the cake's time",
		Cakes.nextBiteAt(timed) == t0 + Cakes.Seconds / CakeConfig.Bites / 2
	)
	local herd = {}
	for i = 1, 10 do
		local m = withEffects({})
		m.uid = `m{i}`
		table.insert(herd, m)
	end
	local away = Cakes.new("PumpkinCandy", 0, 0, 0, t0)
	check("no bite due yet, no bites", #Cakes.catchUp(away, herd, Cakes.nextBiteAt(away) - 1, fake) == 0)
	check("a due bite happens while away", #Cakes.catchUp(away, herd, Cakes.nextBiteAt(away), fake) == 1)
	local never = {
		NextNumber = function()
			return 0.999
		end,
		NextInteger = function(_, min: number)
			return min
		end,
	} :: any
	local sure = true
	for _, id in { "PumpkinCandy", "FangFudge", "BoneMarrowMousse" } do
		local c = Cakes.new(id, 0, 0, 0, t0)
		local monsters = {}
		for i = 1, 10 do
			local m = withEffects({})
			m.uid = `m{i}`
			table.insert(monsters, m)
		end
		local bites = Cakes.catchUp(c, monsters, t0 + 6 * 3600, never)
		local effects = 0
		for _, b in bites do
			effects += if b.effect then 1 else 0
		end
		sure = sure and #bites == CakeConfig.Bites and effects == 1 and bites[#bites].effect ~= nil
	end
	check("every cake gives an effect on its last bite at the latest, even unlucky", sure)
	local stale = Cakes.new("PumpkinCandy", 0, 0, 0, t0)
	Cakes.catchUp(stale, herd, t0 + 6 * 3600, fake)
	check("a cake is done after its time, even offline", Cakes.isDone(stale, t0 + 6 * 3600))
	local lone = Cakes.new("PumpkinCandy", 0, 0, 0, t0)
	check(
		"a monster only eats once, even offline",
		#Cakes.catchUp(lone, { herd[1] }, t0 + 6 * 3600, fake) <= 1
	)

	local record = { slot = 5, bought = { PumpkinCandy = 2 } }
	check("buys count within a restock", Workshop.boughtThisSlot(record, 5).PumpkinCandy == 2)
	check("buys reset on the next restock", Workshop.boughtThisSlot(record, 6).PumpkinCandy == nil)
end

-- Offline: roaming rolls are played back, and the away book lists what changed.
do
	local hit = {
		NextNumber = function()
			return 0
		end,
		NextInteger = function(_, min: number)
			return min
		end,
	} :: any
	local miss = {
		NextNumber = function()
			return 0.999
		end,
		NextInteger = function(_, min: number)
			return min
		end,
	} :: any
	local function fresh(): any
		return {
			uid = "u1",
			monsterId = "Gravepup",
			size = "Normal",
			kg = 20,
			effects = {},
			familiarity = 1,
			grownAt = 0,
		}
	end
	local lucky = fresh()
	local gained = Haunting.catchUp(lucky, 1, 0, 3600, hit)
	check("offline rolls give roaming effects", #gained > 0 and #lucky.effects == #gained)
	local onlyRoam = true
	for _, id in gained do
		onlyRoam = onlyRoam and Effects.List[id] ~= nil and Effects.List[id].source == "Roam"
	end
	check("offline rolls only give roaming effects", onlyRoam)
	check("no time away, no rolls", #Haunting.catchUp(fresh(), 1, 0, Effects.RoamRollSeconds - 1, hit) == 0)
	check("unlucky offline rolls give nothing", #Haunting.catchUp(fresh(), 1, 0, 3600, miss) == 0)

	local m = fresh()
	local snap = Away.snapshot({ m })
	check("nothing changed, nothing in the book", #Away.changes(snap, { m }) == 0)
	m.kg = 30
	m.size = "Big"
	table.insert(m.effects, "Cobwebbed")
	local changes = Away.changes(snap, { m })
	check(
		"the book lists weight, size and new effects",
		#changes == 1
			and changes[1].kgBefore == 20
			and changes[1].kgAfter == 30
			and changes[1].sizeAfter == "Big"
			and changes[1].effects[1] == "Cobwebbed"
	)
end

-- Roaming effects (Util/Haunting).
do
	local function monster(effects: { string }): any
		return { monsterId = "Gravepup", size = "Normal", effects = effects, familiarity = 0 }
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
	local picked = Haunting.roll(monster({}), 1, nil, random, true)
	check("a forced roll picks a Roam effect", picked ~= nil and Effects.List[picked].source == "Roam")
	local three = Haunting.roll(monster({ "Ghost", "Slimed", "PumpkinHead" }), 1, nil, random, true)
	check("a monster with 3 effects still picks up a new one", three ~= nil)
	local allRoam: { string } = {}
	for _, option in Haunting.pool(nil) do
		table.insert(allRoam, option.id)
	end
	check(
		"a monster with every Roam effect picks up nothing",
		Haunting.roll(monster(allRoam), 1, nil, random, true) == nil
	)
	-- Event effects: every launch event with an effect has a chance, and its effect exists.
	local eventsOk = true
	for _, event in Events.List do
		if event.launch and event.effect then
			local effect = Effects.List[event.effect]
			eventsOk = eventsOk and effect ~= nil and (event.effectChance or 0) > 0
		end
	end
	check("every launch event's effect exists and has a chance", eventsOk)
	check(
		"Frost Fog, Sugar Rush and Gold Rush give their own effects",
		(Events.find("FrostFog") :: any).effect == "Frostbitten"
			and (Events.find("SugarRush") :: any).effect == "Sugarcoated"
			and (Events.find("GoldRush") :: any).effect == "Gilded"
	)
	check("event odds start at the event's chance", near(Haunting.eventChance(6, 0, 1), 6))
	check("Familiarity raises event odds", Haunting.eventChance(6, 1, 1) > 6)

	local frost = Events.find("FrostFog") :: any
	local frostHits, frostRandom = 0, fakeRandom(5)
	for _ = 1, 20_000 do
		local id = Haunting.eventRoll(monster({}), 1, frost, frostRandom)
		if id == "Frostbitten" then
			frostHits += 1
		end
	end
	check("about 6% of Frost Fog rolls frost a new monster", math.abs(frostHits / 20_000 - 0.06) < 0.01)
	check(
		"a monster that already has the event's effect gets nothing",
		Haunting.eventRoll(monster({ "Frostbitten" }), 1, frost, alwaysHit :: any) == nil
	)
	local gotId, after =
		Haunting.eventRoll(monster({ "Cobwebbed", "Possessed", "Slimed" }), 1, frost, alwaysHit :: any)
	check(
		"a monster with 3 effects simply gains the event effect",
		gotId == "Frostbitten" and after ~= nil and #after == 4 and table.find(after, "Cobwebbed") ~= nil
	)
	local every: { string } = {}
	for id in Effects.List do
		local next = Haunting.withEffect(every, id)
		if next then
			every = next
		end
	end
	local total = 0
	for _ in Effects.List do
		total += 1
	end
	check("a monster can hold every effect at once", #every == total)
	local watcher = Events.find("WatcherAwakens") :: any
	local others, watched, otherRandom = 0, 0, fakeRandom(9)
	for _ = 1, 50_000 do
		local id = Haunting.eventRoll(monster({}), 1, watcher, otherRandom)
		if id == "Watched" then
			watched += 1
		elseif id then
			others += 1
		end
	end
	check("The Watcher Awakens rarely gives Watched", watched > 0 and watched / 50_000 < 0.006)
	check("The Watcher Awakens can give the other events' effects", others > watched)

	check(
		"a new combo is spotted",
		Value.newCombo({ "Batty", "Ghost" }, Value.resolveEffects({ "Batty", "Ghost", "Vampire" })) == "Count"
	)

	-- About RoamChance% of plain rolls hit.
	local hits = 0
	local trials = 20000
	for _ = 1, trials do
		if Haunting.roll(monster({}), 1, nil, random) then
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

-- Buying a wing only changes the door to that wing in the rooms already standing (its boards
-- come off and the leaves swing open); every other part keeps the same key, so MansionService
-- leaves it alone and the mansion doesn't blink.
do
	for count = 1, #Mansion.ownedWings(99) - 1 do
		local before, after = {}, {}
		for _, wing in Mansion.ownedWings(count) do
			before[wing.id] = true
			after[wing.id] = true
		end
		local bought = (Mansion.nextWing(count) :: any).id
		after[bought] = true
		local ok = true
		for wingId in before do
			local spot = Layout.Wings[wingId]
			local recipe = Rooms.ByWing[wingId]
			local keys = {}
			for _, p in recipe(spot.width, spot.depth, before) do
				keys[p.name] = Rooms.key(p)
			end
			for _, p in recipe(spot.width, spot.depth, after) do
				if keys[p.name] ~= Rooms.key(p) and string.sub(p.name, 1, #bought) ~= bought then
					ok = false
					print(`  buying the {bought} changes {wingId}'s {p.name}`)
				end
			end
		end
		check(`buying the {bought} only changes the doors to it`, ok)
	end
end

-- Effect looks: every effect, combo and variant has a look, and dressing any monster in any
-- of them (or three effects plus a variant) gives sized, uniquely named parts with real
-- materials; head extras stack above the monster and the label clears them.
do
	local EffectLooks = require("../src/shared/Config/EffectLooks")
	local materials =
		{ Metal = true, SmoothPlastic = true, Fabric = true, Foil = true, Ice = true, Glass = true }
	local missing = {}
	for id in Effects.List do
		if not EffectLooks.Styles[id] then
			table.insert(missing, id)
		end
	end
	for id in Effects.Combos do
		if not EffectLooks.Styles[id] then
			table.insert(missing, id)
		end
	end
	for _, id in EffectLooks.Variants do
		if not EffectLooks.Styles[id] then
			table.insert(missing, id)
		end
	end
	check(`every effect, combo and variant has a look {table.concat(missing, ",")}`, #missing == 0)

	local function valid(look: any): boolean
		local names = {}
		for _, p in look.pieces do
			if names[p.name] or #p.size ~= 3 or #p.at ~= 3 or #p.color ~= 3 then
				return false
			end
			for i = 1, 3 do
				if p.size[i] <= 0 or p.color[i] < 0 or p.color[i] > 255 then
					return false
				end
			end
			if p.material and not materials[p.material] then
				return false
			end
			names[p.name] = true
			if p.at[2] + p.size[2] / 2 > look.top + 0.01 then
				return false
			end
		end
		return true
	end
	local stacks = {
		{ { "PumpkinHead", "Watched", "Hexed" }, "Gold" },
		{ { "Count", "Pharaoh", "Alpha" }, "Rainbow" },
		{ { "Slimed", "Poltergeist", "Eclipsed" }, "Shiny" },
		{ { "Mimic", "Stitched", "Cobwebbed" }, "Silver" },
		{ { "Banshee", "Possessed", "Mummy" }, nil },
	}
	local ok, bad = true, ""
	for monsterId, look in Looks do
		for id in EffectLooks.Styles do
			local isVariant = table.find(EffectLooks.Variants, id) ~= nil
			local dressed =
				EffectLooks.dress(look, if isVariant then nil else { id }, if isVariant then id else nil)
			if not valid(dressed) then
				ok, bad = false, `{monsterId} {id}`
			end
		end
		for _, stack in stacks do
			if not valid(EffectLooks.dress(look, stack[1], stack[2])) then
				ok, bad = false, `{monsterId} {table.concat(stack[1], "+")}`
			end
		end
	end
	check(`every monster can wear every effect look {bad}`, ok)

	-- Effects change the monster itself: a pumpkin head turns the head orange (no hat on
	-- top), and every bat flies as one piece (its wings touch its body).
	local look = Looks.Gravepup
	local function find(dressed: any, name: string): any
		for _, p in dressed.pieces do
			if p.name == name then
				return p
			end
		end
		return nil
	end
	local pumpkin = EffectLooks.dress(look, { "PumpkinHead" })
	local head = find(pumpkin, "Head")
	check(
		"a pumpkin head turns the head into a pumpkin",
		head and head.color[1] == 245 and head.color[2] == 130
	)
	local batty = EffectLooks.dress(look, { "Batty" })
	local body, wing = find(batty, "BattyBat1"), find(batty, "BattyBat1WingL")
	local dx, dz = body.at[1] - wing.at[1], body.at[3] - wing.at[3]
	local gap = math.sqrt(dx * dx + dz * dz) - (body.size[1] + wing.size[1]) / 2
	check("a bat's wings touch its body", math.abs(gap) < 0.11)
	local rainbow = EffectLooks.dress(look, {}, "Rainbow")
	check("rainbow parts carry where they start in the colour cycle", rainbow.pieces[1].rainbow ~= nil)
	check("an undressed look is the look itself", EffectLooks.dress(look, {}, nil) == look)
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
		"fast travel goes to the portals, the shops and the Collector",
		ids.Portals and ids.Shops and ids.Sell or false
	)
	local landmarks = {}
	for _, spot in Layout.Landmarks do
		landmarks[spot.name] = true
	end
	local real = true
	for _, destination in TravelConfig.Destinations do
		for _, name in destination.landmarks or {} do
			real = real and landmarks[name] == true
		end
	end
	check("fast-travel landmarks are hub landmarks", real)
end

-- Storage (Util/Storage): a stored monster is paused and comes back as it went in.
do
	local day = 24 * 3600
	local caught: any = { monsterId = "Gravepup", size = "Normal", effects = {}, familiarity = 0 }
	Care.settle(caught, 0)
	Care.settle(caught, 3600) -- an hour of growing
	local before = caught.familiarity
	Storage.store(caught, 3600)
	check("storing a monster notes when", caught.storedAt == 3600)
	Storage.unstore(caught, 3600 + 10 * day) -- ten days in Storage
	check("taking it out clears storedAt", caught.storedAt == nil)
	check("stored monster didn't grow", near(caught.familiarity, before))
	check("storage has room below the limit", Storage.hasRoom(InventoryConfig.StorageSlots - 1))
	check("storage is full at the limit", not Storage.hasRoom(InventoryConfig.StorageSlots))
end

-- Weight and Titans (Util/Weight): price follows weight, growth is lucky spurts.
do
	local caught: any = { monsterId = "Gravepup", size = "Normal", effects = {}, familiarity = 0 }
	Weight.settle(caught, 0, fakeRandom(1))
	check("a new monster gets a weight in its size", caught.kg >= 18 and caught.kg <= 22 and caught.kgAt == 0)
	check("and a growth gene", WeightConfig.Genes[1] ~= nil and caught.gene ~= nil)
	check("weight picks the size", Weight.sizeFor(caught.kg) == "Normal")
	local geneTotal = 0
	for _, gene in WeightConfig.Genes do
		geneTotal += gene.weight
	end
	check("gene weights add up to 100", near(geneTotal, 100))

	-- No growth until fully familiar, then only by luck.
	caught.gene = "Titanic"
	caught.kg = 20
	local day = 24 * 3600
	check("not familiar: no growth", not Weight.settle(caught, 10 * day, fakeRandom(2)) and caught.kg == 20)
	check("growth checks still move on", caught.kgAt == 10 * day)
	caught.familiarity = 1
	Weight.settle(caught, 40 * day, fakeRandom(3))
	check("30 lucky days grow a fully familiar monster", caught.kg > 20)
	check("value follows weight", near(Weight.valueMultiplier("Normal", 30), 1.5))
	check("wild monsters use their size", near(Weight.valueMultiplier("Colossal", nil), 5))

	local stunted: any = { size = "Normal", familiarity = 1, kg = 20, kgAt = 0, gene = "Stunted" }
	Weight.settle(stunted, 100 * day, fakeRandom(4))
	check("a Stunted monster never grows", stunted.kg == 20)
	check("but /grow can force it", Weight.spurt(stunted, fakeRandom(4), true) or stunted.kg > 20)

	local sturdy: any = { size = "Normal", familiarity = 1, kg = 20, kgAt = 0, gene = "Sturdy" }
	for _ = 1, 200 do
		Weight.spurt(sturdy, fakeRandom(5))
	end
	check(
		"a Sturdy monster stops at Huge",
		sturdy.size == "Huge" and sturdy.kg < WeightConfig.StartKg.Colossal
	)

	local titan: any = { size = "Normal", familiarity = 1, kg = 20, kgAt = 0, gene = "Titanic" }
	local rng = fakeRandom(6)
	for _ = 1, 200 do
		Weight.spurt(titan, rng)
	end
	check("a Titanic monster becomes a Titan", titan.size == "Titan")
	check("and keeps growing past any old cap", titan.kg > 10000)
	check("a Titan's price has no limit", Weight.valueMultiplier("Titan", titan.kg) > 500)
	check(
		"and its drawing keeps growing too",
		Weight.drawScale("Titan", titan.kg * 4) > Weight.drawScale("Titan", titan.kg)
	)
	check(
		"a new Titan starts at TitanStartScale",
		near(Weight.drawScale("Titan", 500), WeightConfig.TitanStartScale)
	)
	check("other sizes draw at their Sizes scale", near(Weight.drawScale("Huge", 50), 1.7))
	check(
		"value uses the weight",
		Value.sellValue(
			{ monsterId = "Gravepup", size = "Titan", kg = 500, effects = {}, familiarity = 0 } :: any,
			1
		) == 250_000
	)
	local big: any = { size = "Big", familiarity = 0, kg = 15, kgAt = 0, gene = "Mighty" }
	Weight.spurt(big, fakeRandom(7))
	check("sizes never shrink", big.size == "Big")
	check(
		"weight text",
		Weight.text(54.7) == "54 kg" and Weight.text(1250) == "1.2 t" and Weight.text(5.25) == "5.2 kg"
	)
	local always: any = { size = "Normal", familiarity = 0, kg = 20, gene = "Titanic" }
	local hit = Weight.eventRoll(always, 100, fakeRandom(8))
	check("events roll growth even before full Familiarity", hit and always.kg > 20)
	check(
		"Titans are never rolled wild",
		(function()
			for _, s in Sizes do
				if s.id == "Titan" then
					return s.weight == 0
				end
			end
			return false
		end)()
	)

	-- Storage pauses growth too.
	local stored: any = {
		monsterId = "Gravepup",
		size = "Normal",
		effects = {},
		familiarity = 1,
		kg = 20,
		kgAt = 0,
		gene = "Titanic",
	}
	Storage.store(stored, 0)
	Storage.unstore(stored, 100 * day)
	Weight.settle(stored, 100 * day, fakeRandom(9))
	check("stored monster didn't gain weight", near(stored.kg, 20))
end

-- Hand-held tool looks: every Workshop item has one, held by a part named Handle at the
-- origin, every part sized and named once.
do
	local ToolLooks = require("../src/shared/Config/ToolLooks")
	local ok = true
	for _, item in Shop.Workshop do
		local recipe = ToolLooks.ById[item.id]
		if not recipe then
			ok = false
			print(`  {item.id} has no hand-held look`)
			continue
		end
		local names, handle = {}, false
		for _, p in recipe() do
			if names[p.name] or #p.size ~= 3 or p.size[1] <= 0 or p.size[2] <= 0 or p.size[3] <= 0 then
				ok = false
				print(`  {item.id}: bad or doubled part {p.name}`)
			end
			names[p.name] = true
			handle = handle or (p.name == "Handle" and p.at[1] == 0 and p.at[2] == 0 and p.at[3] == 0)
		end
		ok = ok and handle
	end
	check("every Workshop item has a hand-held look with a Handle at the grip", ok)
end

-- Sounds: every launch event has its sounds, and every slice it names is on its sheet.
do
	local Sounds = require("../src/shared/Config/Sounds")
	local ok = true
	for _, event in Events.List do
		if not event.launch then
			continue
		end
		local sounds = Sounds.Events[event.id]
		if not sounds then
			ok = false
			print(`  {event.id} has no sounds`)
			continue
		end
		for _, key in { sounds.warning, sounds.start } do
			ok = ok and Sounds.Sheets.EventStingers[key] ~= nil
		end
		ok = ok and Sounds.Sheets.EventAmbience[sounds.ambience] ~= nil
	end
	ok = ok
		and Sounds.Sheets.EventStingers[Sounds.EndCue] ~= nil
		and Sounds.Sheets.EventStingers[Sounds.ThunderCue] ~= nil
	ok = ok and Sounds.Sheets.WorldAmbience.Night ~= nil
	for _, key in Sounds.BetweenSongs do
		ok = ok and Sounds.Sheets.WorldAmbience[key] ~= nil
	end
	for _, song in Sounds.Sheets.Music do
		ok = ok and (Sounds.Files :: any)[song.file] ~= nil and song.length > 0
	end
	check("every launch event has sounds that exist on the sound sheets", ok)
	check(
		"asset ids get their prefix",
		Sounds.assetId("123") == "rbxassetid://123" and Sounds.assetId("") == ""
	)
end

-- The first-timer tutorial (Util/Tutorial).
do
	local Tutorial = require("../src/shared/Util/Tutorial")
	local Zones = require("../src/shared/Config/Zones")
	check("tutorial starts at the gate and ends after the tour", Tutorial.Steps[1] == "Gate")
	check("tutorial step order", Tutorial.nextStep("Gate") == "Catch" and Tutorial.nextStep("Tour") == "Done")
	check(
		"tutorial: every step has words and a hint",
		(function()
			for _, step in Tutorial.Steps do
				if not Tutorial.Text[step] or not Tutorial.Hints[step] then
					return false
				end
			end
			return true
		end)()
	)
	check("tutorial: buttons locked at the start", not Tutorial.isUnlocked("Gate", "Sell"))
	check("tutorial: Portals works from the first step", Tutorial.isUnlocked("Gate", "Portals"))
	check(
		"tutorial: hotbar opens for the catch",
		Tutorial.isUnlocked("Catch", "Hotbar") and not Tutorial.isUnlocked("Gate", "Hotbar")
	)
	check(
		"tutorial: Sell opens at the sell step and stays open",
		Tutorial.isUnlocked("Sell", "Sell") and Tutorial.isUnlocked("Tour", "Sell")
	)
	check("tutorial: unlisted features wait for the end", not Tutorial.isUnlocked("Tour", "Something"))
	check(
		"tutorial: everything works once done",
		Tutorial.isUnlocked(nil, "Something") and Tutorial.isUnlocked("Done", "Sell")
	)
	check(
		"tutorial: every unlock names a real step",
		(function()
			for _, from in Tutorial.Unlocks do
				if Tutorial.index(from) == 0 then
					return false
				end
			end
			return true
		end)()
	)
	local travelIds = {}
	for _, destination in TravelConfig.Destinations do
		travelIds[destination.id] = true
	end
	check(
		"tutorial: every fast-travel button gets unlocked",
		travelIds.Portals
			and Tutorial.Unlocks.Portals ~= nil
			and Tutorial.Unlocks.Shops ~= nil
			and Tutorial.Unlocks.Sell ~= nil
	)
	check(
		"tutorial: fresh save only",
		Tutorial.isFresh(0, 0, 0, 1, 0)
			and not Tutorial.isFresh(10, 0, 0, 1, 0)
			and not Tutorial.isFresh(0, 1, 0, 1, 0)
			and not Tutorial.isFresh(0, 0, 0, 2, 0)
			and not Tutorial.isFresh(0, 0, 0, 1, 1)
	)
	check(
		"tutorial: a lost hunt starts over at the gate",
		Tutorial.resumeAt("Catch") == "Gate"
			and Tutorial.resumeAt("Home") == "Gate"
			and Tutorial.resumeAt("Sell") == "Sell"
	)
	check(
		"tutorial: welcome gift tops up to the price",
		Tutorial.gift(1_200, 50_000) == 48_800 and Tutorial.gift(60_000, 50_000) == 0
	)
	local zoneOk = false
	for _, zone in Zones.List do
		zoneOk = zoneOk or (zone.id == Tutorial.Zone and zone.index == 1)
	end
	check("tutorial zone is the first zone", zoneOk)
	check(
		"tutorial monster lives in the first zone",
		Monsters[Tutorial.Monster] ~= nil and Monsters[Tutorial.Monster].zone == 1
	)
	check("tutorial effect is a roaming effect", Effects.List[Tutorial.Effect] ~= nil)
	check(
		"tutorial vacuum is a Workshop vacuum",
		Workshop.item(Tutorial.FirstVacuum) ~= nil and Workshop.item(Tutorial.FirstVacuum).kind == "Vacuum"
	)
	check(
		"tutorial vacuum is always in stock with the tutorial boost",
		Workshop.inStock(Workshop.item(Tutorial.FirstVacuum), 12345, nil, math.huge)
	)
end

-- The Codex (Util/Codex).
do
	local Codex = require("../src/shared/Util/Codex")
	local sections = Codex.sections()
	local zoneIds = {}
	for _, section in sections do
		zoneIds[section.id] = #section.monsters
	end
	check(
		"codex has a page per launch zone",
		zoneIds.PumpkinGraveyard == 9 and zoneIds.MurkyBayou == 9 and zoneIds.AbandonedCarnival == 9
	)
	check(
		"codex leaves out zones that aren't in the game yet",
		zoneIds.SpookySchool == nil and zoneIds.GhostShip == nil
	)
	check("codex lists every event monster", zoneIds.Events == 10)
	check("codex pages start with the commonest monster", sections[1].monsters[1] == "Gloomlet")
	check(
		"codex variant goals are Silver, Gold, Shiny, Rainbow",
		table.concat(Codex.VariantOrder, ",") == "Silver,Gold,Shiny,Rainbow"
	)

	local codex = {}
	local found = Codex.note(
		codex,
		{ monsterId = "Gloomlet", size = "Normal", effects = { "Cobwebbed" }, familiarity = 0 }
	)
	check(
		"codex: first catch is a new monster and a new effect",
		#found == 2 and found[1].kind == "Monster" and found[2].kind == "Effect"
	)
	check(
		"codex: plain catch is no variant goal",
		Codex.has(codex, "Gloomlet") and not Codex.has(codex, "Gloomlet", "Gold")
	)
	check(
		"codex: the same catch again is nothing new",
		#Codex.note(
				codex,
				{ monsterId = "Gloomlet", size = "Big", effects = { "Cobwebbed" }, familiarity = 0 }
			) == 0
	)
	local gold = Codex.note(
		codex,
		{ monsterId = "Gloomlet", size = "Normal", effects = {}, familiarity = 0, variant = "Gold" }
	)
	check(
		"codex: a Gold one is a new variant goal",
		#gold == 1
			and gold[1].kind == "Variant"
			and gold[1].variant == "Gold"
			and Codex.has(codex, "Gloomlet", "Gold")
	)
	local combo = Codex.note(
		codex,
		{ monsterId = "Gravepup", size = "Normal", effects = { "Vampire", "Batty" }, familiarity = 0 }
	)
	local kinds = {}
	for _, f in combo do
		kinds[f.kind] = (kinds[f.kind] or 0) + 1
	end
	check("codex: combos are noted from their recipe", kinds.Combo == 1 and codex.combos.Count == true)
	check(
		"codex: unknown monsters are ignored",
		#Codex.note(codex, { monsterId = "Nobody", size = "Normal", effects = {}, familiarity = 0 }) == 0
	)
	local progress = Codex.progress(codex, sections[1].monsters)
	check(
		"codex progress counts found and variants",
		progress.found == 2
			and progress.total == 9
			and progress.variants.Gold == 1
			and progress.variants.Silver == 0
	)
	local effectIds = Codex.effectIds()
	check(
		"codex leaves out effects from events not in the game",
		not table.find(effectIds, "Mimic") and table.find(effectIds, "Cobwebbed") ~= nil
	)
	check("codex lists every combo", #Codex.comboIds() == 4)
end

-- Settings
do
	local Settings = require("../src/shared/Util/Settings")
	local TutorialUtil = require("../src/shared/Util/Tutorial")
	local allValid = true
	for _, setting in Settings.List do
		allValid = allValid and Settings.valid(setting.key, setting.default)
	end
	check("settings defaults are all allowed", allValid)
	check(
		"settings volume takes whole percents 0 to 100",
		Settings.valid("music", 0)
			and Settings.valid("music", 37)
			and Settings.valid("music", 100)
			and not Settings.valid("music", 101)
			and not Settings.valid("music", -1)
			and not Settings.valid("music", 37.5)
	)
	check("settings volume needs a number", not Settings.valid("music", "50"))
	check(
		"settings choice takes only its options",
		Settings.valid("weather", "Less") and not Settings.valid("weather", "Max")
	)
	check(
		"settings toggle needs true or false",
		Settings.valid("edgeGlow", false) and not Settings.valid("edgeGlow", 1)
	)
	check("settings unknown key is refused", not Settings.valid("speed", true))
	check("settings broken save falls back to default", Settings.value("weather", "Max") == "Full")
	check("settings saved value is kept", Settings.value("music", 25) == 25)
	check("settings missing value falls back to default", Settings.value("flashes", nil) == true)
	check("settings attribute name", Settings.attribute("music") == "SettingMusic")
	check("settings edge glow is off by default", Settings.value("edgeGlow", nil) == false)
	check(
		"settings weather scale",
		Settings.weatherScale("Off") == 0
			and Settings.weatherScale("Less") < 1
			and Settings.weatherScale("Full") == 1
	)
	check("settings work during the tutorial", TutorialUtil.isUnlocked("Gate", "Settings"))
end

-- The worth sign and trophy stand outside each mansion (Util/Mansion.worth).
do
	local total, best = Mansion.worth({ 100, 2500, 40 })
	check("mansion worth adds every monster", total == 2640)
	check("mansion worth picks the most valuable", best == 2)
	local emptyTotal, none = Mansion.worth({})
	check("empty mansion is worth nothing and has no best", emptyTotal == 0 and none == nil)
	local _, first = Mansion.worth({ 50, 50 })
	check("mansion worth tie goes to the first", first == 1)
end

if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("all checks passed")
