-- Plain-Luau checks for the shared config and value math.
-- Run with the Luau CLI from the repo root: luau tests/run.luau

local Monsters = require("../src/shared/Config/Monsters")
local Rarities = require("../src/shared/Config/Rarities")
local Sizes = require("../src/shared/Config/Sizes")
local Catching = require("../src/shared/Util/Catching")
local Format = require("../src/shared/Util/Format")
local Nickname = require("../src/shared/Util/Nickname")
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
local Restock = require("../src/shared/Util/Restock")
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
check(
	"a potion gives the Dust Buster a Rainbow chance",
	Spawning.rollVariant("DustBuster", alwaysHit :: any, 1, true) == "Rainbow"
)
check(
	"a potion's Rainbow can still miss",
	Spawning.rollVariant("DustBuster", neverHit :: any, 1, true) == nil
)
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

-- Every catch has quick time struggles; rarer and bigger monsters are harder (Giles 2026-10-21).
do
	local common = Catching.strugglePlan("Common", "Normal")
	local divine = Catching.strugglePlan("Divine", "Normal")
	check(
		"every rarity struggles at least once",
		(function()
			for id in Rarities do
				if #Catching.strugglePlan(id, "Normal").marks < 1 then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"rarer monsters struggle more, faster, with a smaller zone",
		#divine.marks > #common.marks and divine.speed > common.speed and divine.zone < common.zone
	)
	check(
		"bigger monsters have a smaller zone",
		Catching.strugglePlan("Rare", "Colossal").zone < Catching.strugglePlan("Rare", "Tiny").zone
	)
	check(
		"the needle sweeps there and back",
		Catching.needle(0, 1) == 0
			and Catching.needle(0.5, 1) == 0.5
			and Catching.needle(1, 1) == 1
			and math.abs(Catching.needle(1.25, 1) - 0.75) < 1e-9
	)
	check(
		"a tap in the zone hits, outside misses",
		Catching.struggleHit(0.5, 1, 0.5, 0.2) and not Catching.struggleHit(0.1, 1, 0.5, 0.2)
	)
	local fits = true
	local rng = fakeRandom(3)
	for _ = 1, 200 do
		local centre = Catching.zoneCentre(0.34, rng)
		if centre - 0.17 < 0 or centre + 0.17 > 1 or centre < 0.25 then
			fits = false
		end
	end
	check("the zone always fits on the bar, away from the start", fits)

	-- The Lucky Ring (quick time event A): rare and event monsters only, after the struggles.
	local epic = Catching.strugglePlan("Epic", "Normal")
	check(
		"the Lucky Ring comes for Epic and event monsters, after their struggles",
		Catching.strugglePlan("Rare", "Normal").ring == nil
			and epic.ring ~= nil
			and (epic.ring :: number) > epic.marks[#epic.marks]
			and (epic.ring :: number) < 1
			and Catching.strugglePlan("Phantom", "Normal").ring ~= nil
	)
	local lineUp = 1.5 * (1 - 1 / 3) -- Struggles.Ring: 1.5 seconds, starting 3x the circle
	check(
		"the ring hits only as it lines up with the circle",
		Catching.ringHit(lineUp)
			and not Catching.ringHit(0)
			and not Catching.ringHit(1.5)
			and Catching.ringScale(0) == 3
			and Catching.ringScale(5) == 0
	)
	local epicStops = Catching.stops(epic)
	check(
		"the meter stops at every struggle and then at the ring",
		#epicStops == #epic.marks + 1
			and epicStops[1] == epic.marks[1]
			and epicStops[#epicStops] == epic.ring
			and #Catching.stops(Catching.strugglePlan("Common", "Normal")) == 1
	)
	check(
		"a tap's own time counts, even a little ahead of the server's clock",
		Catching.tapTime(9.9, 10) == 9.9
			and Catching.tapTime(10.1, 10) == 10 -- slightly ahead: counted as now, not thrown away
			and Catching.tapTime(11, 10) == 10
			and Catching.tapTime(5, 10) == 10 -- too old: when it arrived
			and Catching.tapTime("x", 10) == 10
			and Catching.tapTime(0 / 0, 10) == 10
	)
	local plain, boosted = 0, 0
	local variantRng = fakeRandom(21)
	for _ = 1, 20_000 do
		plain += if Spawning.rollVariant("MoonVac", variantRng) then 1 else 0
		boosted += if Spawning.rollVariant("MoonVac", variantRng, 3) then 1 else 0
	end
	check("a Lucky Ring catch gets a variant more often", boosted > plain * 2)
	local plainEffects, boostedEffects = 0, 0
	for _ = 1, 20_000 do
		plainEffects += #Spawning.rollCatchEffects("SpiritSiphon", variantRng)
		boostedEffects += #Spawning.rollCatchEffects("SpiritSiphon", variantRng, 2)
	end
	check("a Lucky Ring catch gets its Ghost effect more often", boostedEffects > plainEffects * 1.6)
end
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
do
	-- Walking through a portal (Util/Hunt.walkCrossesBox): a 14 x 16 x 2 gate, in its own space.
	local half = { x = 7, y = 8, z = 1 }
	local function walk(a: { number }, b: { number }): boolean
		return Hunt.walkCrossesBox({ x = a[1], y = a[2], z = a[3] }, { x = b[1], y = b[2], z = b[3] }, half)
	end
	check("portals: walking straight through a thin gate counts", walk({ 0, 0, -5 }, { 0, 0, 5 }))
	check("portals: standing inside a gate counts", walk({ 1, 0, 0 }, { 1, 0, 0 }))
	check("portals: ending inside a gate counts", walk({ 0, 0, -5 }, { 0, 0, 0.5 }))
	check("portals: walking past beside a gate doesn't", not walk({ 9, 0, -5 }, { 9, 0, 5 }))
	check("portals: stopping short of a gate doesn't", not walk({ 0, 0, -5 }, { 0, 0, -1.5 }))
	check("portals: walking along in front of it doesn't", not walk({ -10, 0, -3 }, { 10, 0, -3 }))
	check("portals: jumping over it doesn't", not walk({ 0, 10, -5 }, { 0, 10, 5 }))
	check("portals: cutting a corner counts", walk({ 9, 0, -3 }, { 5, 0, 3 }))
end
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
	local recent: { string } = {}
	for _ = 1, 20_000 do
		local event = Watcher.pick(recent, 0, clockRng)
		if table.find(recent, event.id) then
			repeats += 1
		end
		if event.awakening then
			awakenings += 1
		end
		counts[event.id] = (counts[event.id] or 0) + 1
		table.insert(recent, event.id)
		if #recent > Events.NoRepeat then
			table.remove(recent, 1)
		end
	end
	check(`an event never comes back within {Events.NoRepeat} others`, repeats == 0)
	local later = Watcher.Epoch + 50_000
	local timeline = Watcher.upcoming(later, 10)
	local ordered = #timeline == 10 and timeline[1].endAt > later
	for index = 2, #timeline do
		ordered = ordered and timeline[index].startAt > timeline[index - 1].endAt
	end
	check(
		"the admin timeline lists the schedule in order, starting with the event now",
		ordered and timeline[1].startAt == Watcher.slotAt(later).startAt
	)
	local skipped = Watcher.upcoming(later, 10, timeline[1].index)
	check(
		"the admin timeline drops a slot that was already played now",
		#skipped == 10 and skipped[1].index == timeline[2].index and skipped[10].index ~= timeline[10].index
	)
	local playedAll = true
	for _, event in Watcher.pool() do
		if (counts[event.id] or 0) == 0 then
			playedAll = false
		end
	end
	check("every event in the pool comes up", playedAll)
	check("The Watcher Awakens only comes with all eyes open", awakenings == 0)
	check("the rare new events play too", counts.MimicNight ~= nil and counts.BreachStorm ~= nil)
	check("Frost Fog is commoner than Blood Moon", (counts.FrostFog or 0) > (counts.BloodMoon or 0))
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
		Watcher.pick({ "Flicker" }, Events.EyesToAwaken, clockRng).id == "WatcherAwakens"
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
			if #lists > 0 or event.zoneMonsters then
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
		table.concat(withMonsters, ",") == "BloodMoon,BreachStorm,MimicNight,WatcherAwakens"
	)
	local unused = {}
	for id, m in Monsters do
		if type(m) == "table" and m.event and not used[id] then
			table.insert(unused, id)
		end
	end
	check(`every event monster can spawn ({table.concat(unused, ", ")})`, #unused == 0)

	-- Breach Storm: monsters from the launch zones, Legendary and up 5x as likely.
	local breach = Events.find("BreachStorm") :: Events.WatcherEvent
	local breachWeights, breachCount = Watcher.spawns(breach, nil, 8)
	local zonesOk = breachWeights ~= nil and breachCount == Watcher.monsterCount(8)
	for id, weight in breachWeights or {} do
		local m = Monsters[id]
		local rarity = Rarities[m.rarity]
		local boost = if rarity.order >= Rarities.Legendary.order then 5 else 1
		zonesOk = zonesOk and m.zone ~= nil and m.zone <= 3 and weight == (m.spawnWeight :: number) * boost
	end
	check(
		"Breach Storm brings launch-zone monsters, Legendary and up 5x as likely",
		zonesOk and (breachWeights :: any).TheBogKing == 12.5 and (breachWeights :: any).Chalkling == nil
	)
	check(
		"the Breach Storm tooltip says where its monsters come from",
		Watcher.monsterLine(breach) == "Monsters: any from the zones, Legendary and up 5x as likely"
	)
	local mimic = Events.find("MimicNight") :: Events.WatcherEvent
	check(
		"Mimic Night brings its Mimics, on the ground, and they bite",
		Watcher.monsterLine(mimic) == "Monsters: Barrel Mimic, Crate Mimic"
			and mimic.grounded == true
			and mimic.bite ~= nil
			and Watcher.vacuumLine(mimic) == "Catch with the Banshee Blower or better"
	)

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
	local function setOf(id: string): Events.MonsterSet?
		for _, set in awakens.monsterSets or {} do
			if set.id == id then
				return set
			end
		end
		return nil
	end
	check(
		"caught event monsters come back, except the Eldritch jackpot",
		Watcher.respawns(nil)
			and Watcher.respawns(setOf("Phantoms"))
			and Watcher.respawns(setOf("Nightmares"))
			and not Watcher.respawns(setOf("Eldritch"))
	)
	check(
		"the Workshop says which events a vacuum opens up",
		table.concat(Workshop.unlocksEvents("BansheeBlower"), ",") == "Blood Moon,Mimic Night"
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
	local voidIn, bellIn = 0, 0
	local bell = Workshop.item("BaitBell") :: Shop.Item
	for slot = 1, slots do
		if Workshop.inStock(phantomVac, slot) and Workshop.inStock(voidVac, slot) then
			voidIn += 1
		end
		if Workshop.inStock(bell, slot) then
			bellIn += 1
		end
	end
	check("vacuums are in stock in every restock", voidIn == slots)
	check("Bait Bells are in stock about 50% of restocks", math.abs(bellIn / slots - 0.50) < 0.02)
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
		Workshop.canBuy(charm, inSlot, 1e6, {}, Workshop.limit(charm, inSlot)) == "SoldOut"
	)
	local seen: { [number]: boolean } = {}
	local inRange = true
	for slot = 1, 200 do
		local limit = Workshop.limit(charm, slot)
		seen[limit] = true
		inRange = inRange and limit >= Shop.StockMin and limit <= Shop.StockMax
	end
	check("shop stock is a random amount in range", inRange and seen[Shop.StockMin] and seen[Shop.StockMax])
	check("shop stock is the same for the same restock", Workshop.limit(charm, 7) == Workshop.limit(charm, 7))
	check("a tool is always one", Workshop.limit(siphon, 7) == 1)
	local tag = Workshop.item("NameTag") :: Shop.Item
	local tagsOk, tagSeen = true, {}
	for slot = 1, 200 do
		local limit = Workshop.limit(tag, slot)
		tagSeen[limit] = true
		tagsOk = tagsOk and limit >= 2 and limit <= 5
	end
	check("Name Tags come 2 to 5 at a time", tagsOk and tagSeen[2] and tagSeen[5])
	local tagStocked = 0
	for slot = 1, 1000 do
		if Workshop.inStock(tag, slot) then
			tagStocked += 1
		end
	end
	check("Name Tags are only sometimes in stock", tagStocked > 200 and tagStocked < 500)
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

-- Silver Bell: two rarities up, up to Mythic. Gold Bell: Legendary 85%, Mythic 14%, Divine 1%.
do
	local rng = fakeRandom(11)
	local silverLow, silverTooRare = 0, 0
	for _ = 1, 5000 do
		local order = Rarities[Spawning.rollLured(1, rng, "SilverBell").rarity].order
		if order < Rarities.Rare.order then
			silverLow += 1
		elseif order > Rarities.Mythic.order then
			silverTooRare += 1
		end
	end
	check("a Silver Bell brings Rare or better, never Divine", silverLow == 0 and silverTooRare == 0)
	local counts: { [string]: number } = {}
	for _ = 1, 20_000 do
		local rarity = Spawning.rollLured(1, rng, "GoldBell").rarity
		counts[rarity] = (counts[rarity] or 0) + 1
	end
	check(
		"a Gold Bell follows its odds",
		math.abs((counts.Legendary or 0) / 20_000 - 0.85) < 0.015
			and math.abs((counts.Mythic or 0) / 20_000 - 0.14) < 0.015
			and (counts.Divine or 0) > 0
			and (counts.Epic or 0) == 0
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
		"a zone keeps 18 monsters for 1-4 hunters",
		Spawning.aliveTarget(1) == 18 and Spawning.aliveTarget(4) == 18
	)
	check(
		"a crowded zone keeps more monsters",
		Spawning.aliveTarget(8) == 26 and Spawning.aliveTarget(30) == 30
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
		"a bite of Fang Fudge lands Vampire about 10.5% of the time",
		math.abs(vampires / tries - 0.105) < 0.03
	)
	check(
		"the odds shown are the real odds per bite",
		Cakes.describe(fudge) == "3 bites, at least one effect · Each bite: 10.5% Vampire (x2.5)"
	)
	check(
		"a chance cake shows each effect's real odds",
		Cakes.describe(mousse)
			== "6 bites, at least one effect · Each bite: 7.5% Mummy (x4), 22.5% Batty (x3)"
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
		Cakes.nextBiteAt(timed) >= t0 + Cakes.Seconds / Cakes.bites("PumpkinCandy") * 0.1
			and Cakes.nextBiteAt(timed) <= t0 + Cakes.Seconds / Cakes.bites("PumpkinCandy") * 0.9
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
		sure = sure and #bites == Cakes.bites(id) and effects == 1 and bites[#bites].effect ~= nil
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
		local source = Effects.List[id] and Effects.List[id].source
		onlyRoam = onlyRoam and (source == "Roam" or source == "Critter")
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

-- Combos: each is worth more than its two effects added up, and a shared ingredient goes to
-- the stronger combo.
do
	local better = true
	for id, combo in Effects.Combos do
		local parts = Value.effectMultiplier({ combo.recipe[1] })
			+ Value.effectMultiplier({ combo.recipe[2] })
			- 1
		if combo.multiplier <= parts then
			better = false
			print(`  {id} is not worth more than its recipe`)
		end
	end
	check("every combo beats its two effects added up", better)
	local shared = Value.resolveEffects({ "Ghost", "Mummy", "Cursed" })
	check("a shared ingredient goes to the stronger combo", table.find(shared, "Pharaoh") ~= nil)
	local rot: any =
		{ monsterId = "Gloomlet", size = "Normal", effects = { "Moldy", "Fungal" }, familiarity = 0 }
	check("a critter combo counts in full", near(Value.monsterEffectMultiplier(rot), 6))
end

-- Critter effects: only on cheap monsters, and they count in full.
do
	local cheap: any = { monsterId = "Gloomlet", size = "Normal", effects = {}, familiarity = 0 }
	local pricey: any = { monsterId = "TheGroundskeeper", size = "Normal", effects = {}, familiarity = 0 }
	check(
		"Critter effects only fit cheap monsters",
		Value.fits({}, "Moldy", "Gloomlet") == "Ok"
			and Value.fits({}, "Moldy", "TheGroundskeeper") == "TooPricey"
	)
	local rolledCritter = false
	local rng = fakeRandom(5)
	for _ = 1, 500 do
		local id = Haunting.roll(pricey, 1, nil, rng, true)
		rolledCritter = rolledCritter or (id ~= nil and Effects.List[id].source == "Critter")
	end
	check("a pricey monster never rolls a Critter effect", not rolledCritter)
	local muffin: Shop.Item? = nil
	for _, item in Shop.Bakery do
		if item.id == "MoldyMuffin" then
			muffin = item
		end
	end
	check(
		"a Moldy Muffin only fits cheap monsters",
		Cakes.fits(cheap, muffin) == "Ok" and Cakes.fits(pricey, muffin) == "TooPricey"
	)
	local rusty = table.clone(cheap)
	rusty.effects = { "Rusty" }
	local slimed = table.clone(cheap)
	slimed.effects = { "Slimed" }
	check(
		"a Critter x2 doubles a cheap monster, a normal x2 adds less",
		near(Value.monsterEffectMultiplier(rusty), 2) and Value.monsterEffectMultiplier(slimed) < 1.5
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
		local source = Effects.List[option.id].source
		poolOk = poolOk and (source == "Roam" or source == "Critter") and option.weight > 0
	end
	check("the roam pool only holds Roam and Critter effects", poolOk and #Haunting.pool(nil) == 10)
	local withEvent = Haunting.pool("Bloodmoon")
	local hasEvent = false
	for _, option in withEvent do
		hasEvent = hasEvent or option.id == "Bloodmoon"
	end
	check("a live event adds its effect to the pool", hasEvent and #withEvent == 11)

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
	-- The rarest effect stays rare when it's the only one left (Giles 2026-10-24).
	local allButMummy: { string } = {}
	for _, id in allRoam do
		if id ~= "Mummy" and Effects.List[id].source == "Roam" then
			table.insert(allButMummy, id)
		end
	end
	local mummies, forced = 0, 20_000
	local mummyRandom = fakeRandom(5)
	for _ = 1, forced do
		mummies += if Haunting.roll(monster(allButMummy), 1, { effectOddsMultiplier = 1000 }, mummyRandom)
				== "Mummy"
			then 1
			else 0
	end
	local roamWeight = 0
	for _, option in Haunting.pool(nil) do
		local fit = Value.fits({}, option.id, monster({}).monsterId)
		roamWeight += if fit == "Ok" then option.weight else 0
	end
	check(
		"Mummy is as rare as its weight, even as the last effect left",
		math.abs(mummies / forced - Effects.List.Mummy.weight :: number / roamWeight) < 0.01
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
	local materials = {
		Metal = true,
		SmoothPlastic = true,
		Fabric = true,
		Foil = true,
		Ice = true,
		Glass = true,
		CorrodedMetal = true,
	}
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
	-- Roaming effects rank under the rest: a cobwebbed, slimed monster wears the slime skin.
	-- A shell coats the monster's own parts and adds no see-through parts (they flickered,
	-- Giles 2026-10-24).
	local slimed = EffectLooks.dress(look, { "Slimed", "PhantomWeaver" })
	local slimy = false
	for _, p in slimed.pieces do
		slimy = slimy or p.material == "SmoothPlastic"
	end
	check("a roaming effect's skin gives way to another effect's", slimy)
	local shellCount = 0
	for _, id in { "Cobwebbed", "Slimed", "Frostbitten", "Sugarcoated", "Bloodmoon" } do
		for _, p in EffectLooks.dress(look, { id }).pieces do
			shellCount += if string.find(p.name, "Shell", 1, true) then 1 else 0
		end
	end
	check("no effect draws shell parts", shellCount == 0)
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
	local fitsInPause = true
	for _, key in Sounds.BetweenSongs do
		local slice = Sounds.Sheets.WorldAmbience[key]
		if slice and slice.length + 1 > Sounds.PlaylistGapSeconds then
			fitsInPause = false
			print(
				`  {key} ({slice.length} s) doesn't fit in the {Sounds.PlaylistGapSeconds} s pause between songs`
			)
		end
	end
	check("every between-songs sound is over before the next song starts", fitsInPause)
	for _, song in Sounds.Sheets.Music do
		ok = ok and (Sounds.Files :: any)[song.file] ~= nil and song.length > 0
	end
	check("every launch event has sounds that exist on the sound sheets", ok)
	local calls = true
	for id, m in Monsters :: { [string]: any } do
		local call = Sounds.MonsterVoices[id]
		if not call or not Sounds.Sheets.MonsterVoices[call] then
			calls = false
			print(`  {id} has no call on the MonsterVoices sheet`)
		end
	end
	for monsterId in Sounds.MonsterVoices do
		if not (Monsters :: any)[monsterId] then
			calls = false
			print(`  Sounds.MonsterVoices names an unknown monster {monsterId}`)
		end
	end
	for _, call in Sounds.DefaultCall do
		calls = calls and Sounds.Sheets.MonsterVoices[call] ~= nil
	end
	check("every monster has a call on the MonsterVoices sheet", calls)
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
	check(
		"tutorial: touch words only for real steps, keyboard words otherwise",
		(function()
			for step in Tutorial.TouchText do
				if Tutorial.index(step) == 0 then
					return false
				end
			end
			return Tutorial.textFor("Catch", true) == Tutorial.TouchText.Catch
				and Tutorial.textFor("Catch", false) == Tutorial.Text.Catch
				and Tutorial.textFor("Tour", true) == Tutorial.Text.Tour
		end)()
	)
	check(
		"tutorial: the mansion list opens with the Backpack",
		Tutorial.Unlocks.MansionList == Tutorial.Unlocks.Backpack
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
	check("codex lists every event monster", zoneIds.Events == 12)
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
		"codex lists the effects of every event in the game",
		table.find(effectIds, "Mimic") ~= nil
			and table.find(effectIds, "Rifted") ~= nil
			and table.find(effectIds, "Cobwebbed") ~= nil
	)
	local comboCount = 0
	for _ in Effects.Combos do
		comboCount += 1
	end
	check("codex lists every combo", #Codex.comboIds() == comboCount and comboCount == 16)
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
	check("settings ui size is normal by default", Settings.value("uiSize", nil) == "Normal")
end

-- How big the HUD is drawn (Util/UiScale, client/Scale).
do
	local UiScale = require("../src/shared/Util/UiScale")
	check("a computer screen draws at full size", UiScale.fit(1920, 1080) == 1)
	check("a tablet sideways draws at full size", UiScale.fit(1133, 744) == 1)
	local phone = UiScale.fit(844, 390)
	check(`a phone sideways draws smaller (got {phone})`, phone > 0.6 and phone < 0.7)
	check("a tiny screen never goes under the smallest", UiScale.fit(400, 200) == UiScale.Smallest)
	check("an unknown screen size draws at full size", UiScale.fit(0, 0) == 1)
	check("a phone counts as small", UiScale.isSmall(844, 390) and not UiScale.isSmall(1920, 1080))
	check(
		"the ui size setting scales on top",
		UiScale.factor(1920, 1080, "Small") < 1
			and UiScale.factor(1920, 1080, "Large") > 1
			and UiScale.factor(844, 390, "Normal") == phone
			and UiScale.factor(844, 390, "Huge") == phone
	)
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

-- Codex rewards (Util/Codex.newRewards, Config/CodexRewards) and the Portals button's gate
-- (Util/Hunt.newestZone).
do
	local Codex = require("../src/shared/Util/Codex")
	local page = Codex.sections()[1]
	local codex: { [string]: any } = {}
	check("codex: nothing done pays nothing", #Codex.newRewards(codex, { page }) == 0)
	for _, id in page.monsters do
		Codex.note(codex, { monsterId = id, size = "Normal", effects = {}, familiarity = 0 })
	end
	local paid = Codex.newRewards(codex, { page })
	check(
		"codex: every monster found pays the Found reward once",
		#paid == 1 and paid[1].goal == "Found" and paid[1].amount == Codex.rewardAmount(page.id, "Found")
	)
	check("codex: a paid reward isn't paid again", #Codex.newRewards(codex, { page }) == 0)
	check("codex: a paid reward is marked", Codex.claimed(codex, page.id, "Found"))
	for _, id in page.monsters do
		Codex.note(
			codex,
			{ monsterId = id, size = "Normal", effects = {}, familiarity = 0, variant = "Gold" }
		)
	end
	local gold = Codex.newRewards(codex, { page })
	check("codex: every monster in Gold pays the Gold reward", #gold == 1 and gold[1].goal == "Gold")
	check(
		"codex: rarer variants pay more",
		Codex.rewardAmount(page.id, "Rainbow") > Codex.rewardAmount(page.id, "Shiny")
			and Codex.rewardAmount(page.id, "Shiny") > Codex.rewardAmount(page.id, "Gold")
			and Codex.rewardAmount(page.id, "Gold") > Codex.rewardAmount(page.id, "Silver")
	)
	check(
		"codex: later zones pay more",
		Codex.rewardAmount("MurkyBayou", "Found") > Codex.rewardAmount("PumpkinGraveyard", "Found")
	)
	local launched = 0
	for _, section in Codex.sections() do
		launched += if Codex.rewardAmount(section.id, "Found") > 0 then 1 else 0
	end
	check("codex: every page has a reward", launched == #Codex.sections())

	check("portals: a new player goes to the first zone", Hunt.newestZone(1).index == 1)
	check("portals: two wings go to the second zone", Hunt.newestZone(2).index == 2)
	local last = Hunt.newestZone(99)
	check("portals: never a zone that isn't in the game yet", last ~= nil and last.launch)
end

-- The Golden Ghost (quick time event B): the prize grows with the mansion.
do
	local GoldenGhost = require("../src/shared/Util/GoldenGhost")
	local GhostConfig = require("../src/shared/Config/GoldenGhost")
	check(
		"golden ghost: cash grows with the mansion, never below the minimum",
		GoldenGhost.cash(0) == GhostConfig.MinCash and GoldenGhost.cash(100_000_000) == 3_000_000
	)
	local cakesOk = true
	for _, item in GoldenGhost.cakeChoices(1_000_000) do
		cakesOk = cakesOk and item.event == nil and item.price <= 5_000_000
	end
	local poor = GoldenGhost.cakeChoices(1)
	local cheapest = math.huge
	for _, item in Shop.Bakery do
		if not item.event then
			cheapest = math.min(cheapest, item.price)
		end
	end
	check(
		"golden ghost: cakes are Bakery cakes it can afford, never event treats",
		cakesOk and #GoldenGhost.cakeChoices(1_000_000) > 0 and #poor == 1 and poor[1].price == cheapest
	)
	check(
		"golden ghost: it's gone before the next warning",
		GhostConfig.LatestSeconds + GhostConfig.Seconds < Events.GapMinSeconds
	)
end

-- A monster with every effect stays cheap to draw: one skin, a few extras and particles.
do
	local EffectLooks = require("../src/shared/Config/EffectLooks")
	local all = {}
	for id in Effects.List do
		table.insert(all, id)
	end
	table.sort(all)
	local worst, auras = 0, 0
	for _, look in Looks do
		if type(look) == "table" and (look :: any).pieces then
			local dressed = EffectLooks.dress(look :: any, all, "Rainbow")
			worst = math.max(worst, #dressed.pieces - 2 * #(look :: any).pieces)
			auras = math.max(auras, #(dressed.auras or {}))
		end
	end
	check(`every effect at once adds at most a skin and 120 parts (got {worst})`, worst <= 120)
	check(`every effect at once gives at most 5 particle emitters (got {auras})`, auras <= 5)
end

-- Monster names (Name Tags).
do
	check("a name is trimmed and squeezed", Nickname.clean("  Mr   Bones \t") == "Mr Bones")
	check("an empty name takes the name off", Nickname.clean("   ") == "")
	check("a name of 20 letters fits", Nickname.clean(string.rep("a", 20)) == string.rep("a", 20))
	check("a name of 21 letters doesn't", Nickname.clean(string.rep("a", 21)) == nil)
	check("control characters are dropped", Nickname.clean("Bo\nb") == "Bob")
	check("broken text is refused", Nickname.clean("\255\254") == nil)
	check(
		"a named monster reads 'Bob the Gravepup'",
		Format.monsterName({ monsterId = "Gravepup", nickname = "Bob" }) == "Bob the Gravepup"
	)
	check("an unnamed one just its species", Format.monsterName({ monsterId = "WispJack" }) == "Wisp Jack")
end

-- Luck potions (Util/Potions).
do
	local Potions = require("../src/shared/Util/Potions")
	local state: Potions.State = { id = "", secondsLeft = 0 }
	check("no potion, no boost", Potions.boost(state) == 1)
	check(
		"drinking a Lucky Tonic starts it",
		Potions.drink(state, "LuckyTonic") == "Ok" and Potions.boost(state) == 2
	)
	check("the same potion again tops it up", Potions.drink(state, "LuckyTonic") == "Refreshed")
	check(
		"a stronger one replaces it",
		Potions.drink(state, "PrismDraught") == "Ok" and Potions.boost(state) == 5
	)
	check(
		"a weaker one is refused while a stronger one goes",
		Potions.drink(state, "GildedElixir") == "Weaker" and state.id == "PrismDraught"
	)
	Potions.tick(state, 15 * 60 - 1)
	check("it still works with a second left", Potions.boost(state) == 5)
	Potions.tick(state, 5)
	check("it wears off", Potions.boost(state) == 1 and state.id == "" and state.secondsLeft == 0)
	check("unknown potions do nothing", Potions.drink(state, "Bogus") == "Unknown")
	local sold = 0
	for _, item in Shop.Workshop do
		if item.kind == "Potion" then
			sold += 1
			local stocked = 0
			for slot = 1, 2000 do
				if Workshop.inStock(item, slot) then
					stocked += 1
				end
			end
			local share = stocked / 2000 * 100
			check(
				`{item.name} is in stock about {item.restockChance}% of restocks`,
				math.abs(share - item.restockChance) < item.restockChance * 0.5 + 0.5
			)
			check(`{item.name} sells one per restock`, Workshop.limit(item, 7) == 1)
		end
	end
	check("three potions in the Workshop", sold == 3)
end

-- Codex combo clue (Util/Codex.recipeKnown): how many of a combo's two effects you've found.
do
	local Codex = require("../src/shared/Util/Codex")
	local codex: { [string]: any } = {}
	check("combo clue: nothing found yet", Codex.recipeKnown(codex, "Count") == 0)
	codex.effects = { Vampire = true }
	check("combo clue: one of the two found", Codex.recipeKnown(codex, "Count") == 1)
	codex.effects.Batty = true
	check("combo clue: both found", Codex.recipeKnown(codex, "Count") == 2)
	check("combo clue: unknown combo is 0", Codex.recipeKnown(codex, "Nothing") == 0)
end

-- Merger (Util/Merge) and Growth Chamber (Util/Growth).
do
	local Merge = require("../src/shared/Util/Merge")
	local Growth = require("../src/shared/Util/Growth")
	local GrowthConfig = require("../src/shared/Config/Growth")
	local MergerConfig = require("../src/shared/Config/Merger")
	local function pup(uid: string, kg: number, effects: { string }): any
		return {
			uid = uid,
			monsterId = "Gravepup",
			size = Weight.sizeFor(kg),
			kg = kg,
			effects = effects,
			familiarity = 0.2,
			gene = "Sturdy",
		}
	end
	local main, donor = pup("a", 22, { "Ghost", "Vampire" }), pup("b", 30, { "Cursed", "Batty", "Ghost" })
	main.variant = "Silver"
	donor.gene = "Titanic"
	donor.familiarity = 0.9
	donor.growUsed = 3
	check("merge: same kind is fine", Merge.problem(main, donor) == nil)
	check("merge: not with itself", Merge.problem(main, main) == "Same")
	local other = pup("c", 20, {})
	other.monsterId = "Gloomlet"
	check("merge: only the same kind", Merge.problem(main, other) == "Different")
	donor.locked = true
	check("merge: a hearted donor is refused", Merge.problem(main, donor) == "Locked")
	check("merge: a hearted main is fine", Merge.problem(donor, main) == nil)
	donor.locked = nil
	check("merge: Rare odds", Merge.chance("Gravepup") == MergerConfig.Success.Rare)
	local everyRarity = true
	for id in Rarities do
		everyRarity = everyRarity and (MergerConfig.Success[id] or 0) > 0 and MergerConfig.Success[id] < 100
	end
	check("merge: every rarity has odds", everyRarity)
	check("merge: fee is a share of the donor", Merge.fee(1000) == math.floor(1000 * MergerConfig.FeeShare))

	local result = Merge.preview(main, donor)
	check("merge: preview leaves the main alone", main.kg == 22 and #main.effects == 2)
	check("merge: gains half the donor's weight", near(result.kg, 22 + 30 * MergerConfig.DonorKgShare))
	check("merge: size follows the weight", result.size == Weight.sizeFor(result.kg))
	check("merge: keeps every effect once", #result.effects == 4)
	check(
		"merge: combos form",
		table.find(Value.resolveEffects(result.effects), "Banshee") ~= nil
			and table.find(Value.resolveEffects(result.effects), "Count") ~= nil
	)
	check("merge: better variant kept", result.variant == "Silver")
	check("merge: better gene kept", result.gene == "Titanic")
	check("merge: higher Familiarity kept", result.familiarity == 0.9)
	check("merge: more used charges kept", result.growUsed == 3)
	check("merge: main's uid kept", result.uid == "a")
	local gold = pup("d", 20, {})
	gold.variant = "Gold"
	check("merge: donor's better variant wins", Merge.preview(main, gold).variant == "Gold")
	-- Critter effects still only land on cheap monsters.
	local pricey: any = {
		uid = "e",
		monsterId = "LadyOfLanterns",
		size = "Normal",
		kg = 20,
		effects = {},
		familiarity = 0,
	}
	local pricey2 = table.clone(pricey)
	pricey2.uid = "f"
	pricey2.effects = { "Moldy" }
	check("merge: no Critter effects on pricey monsters", #Merge.preview(pricey, pricey2).effects == 0)

	local gentle = Growth.mode("Gentle") :: GrowthConfig.Mode
	local reckless = Growth.mode("Reckless") :: GrowthConfig.Mode
	check("growth: modes found", gentle ~= nil and reckless ~= nil and Growth.mode("Nope") == nil)
	local g = pup("g", 20, {})
	g.gene = "Stunted"
	check("growth: full charges", Growth.chargesLeft(g) == GrowthConfig.Charges)
	local before, after = Growth.apply(g, reckless, true)
	check(
		"growth: a win ignores a Stunted gene",
		before == 20 and near(after, 20 * reckless.win) and g.size == "Colossal"
	)
	check("growth: a go uses a charge", Growth.chargesLeft(g) == GrowthConfig.Charges - 1)
	Growth.apply(g, reckless, false)
	check(
		"growth: a hard loss shrinks it",
		near(g.kg, 20 * reckless.win * reckless.lose) and g.size == "Huge"
	)
	local kg = g.kg
	Growth.apply(g, gentle, false)
	check("growth: a gentle loss does nothing", g.kg == kg)
	check("growth: fee is a share of its value", Growth.fee(1000, reckless) == 250)
	local ordered = true
	for i = 2, #GrowthConfig.Modes do
		local a, b = GrowthConfig.Modes[i - 1], GrowthConfig.Modes[i]
		ordered = ordered
			and b.chance < a.chance
			and b.win > a.win
			and b.lose <= a.lose
			and b.seconds > a.seconds
	end
	check("growth: harder modes risk more for more, and take longer", ordered)
	check("growth: Reckless takes 20 minutes", reckless.seconds == 20 * 60)
	-- Five Reckless wins from a Normal makes a Titan.
	local lucky = pup("h", 20, {})
	for _ = 1, GrowthConfig.Charges do
		Growth.apply(lucky, reckless, true)
	end
	check("growth: five Reckless wins make a Titan", lucky.size == "Titan" and Growth.chargesLeft(lucky) == 0)
end

-- Hotbar layout (Util/HotbarLayout): each Tool keeps its slot across respawns and rejoins.
do
	local HotbarLayout = require("../src/shared/Util/HotbarLayout")
	check(
		"tools, cakes and monsters get their own keys",
		HotbarLayout.key("DustBuster", nil, nil) == "T:DustBuster"
			and HotbarLayout.key(nil, "MoldyMuffin", nil) == "C:MoldyMuffin"
			and HotbarLayout.key(nil, nil, "abc") == "M:abc"
			and HotbarLayout.key(nil, nil, nil) == nil
			and HotbarLayout.key("VoidVac", nil, nil, "VoidVac") == "V:vacuum"
	)
	local layout = HotbarLayout.new()
	HotbarLayout.remember(layout, "T:DustBuster", 3)
	HotbarLayout.remember(layout, "C:MoldyMuffin", 3)
	check("one key per slot", layout.slots["C:MoldyMuffin"] == 3 and layout.slots["T:DustBuster"] == nil)
	HotbarLayout.bench(layout, "C:MoldyMuffin")
	check(
		"a benched key leaves its slot",
		layout.slots["C:MoldyMuffin"] == nil and HotbarLayout.isBenched(layout, "C:MoldyMuffin")
	)
	HotbarLayout.remember(layout, "C:MoldyMuffin", 1)
	check("putting it back un-benches it", not HotbarLayout.isBenched(layout, "C:MoldyMuffin"))
	local cleaned = HotbarLayout.clean({
		slots = { ["T:A"] = 1, ["T:B"] = 1, ["T:C"] = 10, ["T:D"] = 2.5, [5] = 3, ["T:E"] = "4" },
		benched = { "M:x", "M:x", 7, "T:A" },
	})
	local count = 0
	for _ in cleaned.slots do
		count += 1
	end
	check("cleaning drops bad and clashing slots", count == 1 and cleaned.slots["T:A"] == 1)
	check(
		"cleaning drops bad and repeated benched keys",
		#cleaned.benched == 1 and cleaned.benched[1] == "M:x"
	)
	check("cleaning anything else gives an empty layout", next(HotbarLayout.clean("junk").slots) == nil)
end

-- Daily missions (Util/Missions, Config/Missions).
do
	local Missions = require("../src/shared/Util/Missions")
	local MissionConfig = require("../src/shared/Config/Missions")
	local seed = 7
	local random: any = {
		NextInteger = function(_self, min: number, max: number): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return min + seed % (max - min + 1)
		end,
	}
	local day = 20_000
	local now = day * 86_400 + 3_600
	check("missions: day number", Missions.day(now) == day)
	check("missions: time left until reset", Missions.secondsLeft(now) == 86_400 - 3_600)
	check("missions: rounding", Missions.round(1_234_567) == 1_200_000 and Missions.round(45) == 45)
	check("missions: reward floor", Missions.reward(0.03, 2_000, 15_000, 0) == 2_000)
	check("missions: reward share and bonus", Missions.reward(0.03, 2_000, 20_000_000, 0.3) == 780_000)
	check(
		"missions: streak bonus capped",
		near(Missions.bonusFor(3), 0.3) and Missions.bonusFor(20) == MissionConfig.StreakMax
	)
	local sellSmall = Missions.def("SellSmall") :: any
	check(
		"missions: selling pays most of the money target",
		Missions.missionReward(sellSmall, 700_000_000, 14_000_000_000, 0) == 560_000_000
	)
	check(
		"missions: effort raises a hard mission",
		Missions.missionReward(Missions.def("ZoneSet") :: any, 5, 1_000_000, 0) == 200_000
	)
	check("missions: floor still applies", Missions.missionReward(sellSmall, 5_000, 0, 0) == 4_000)
	check("missions: open zones", #Missions.openZones(1) == 1 and #Missions.openZones(3) == 3)
	check("missions: zone 4 isn't launched", #Missions.openZones(6) == 3)
	local set = Missions.zoneTargets("PumpkinGraveyard", "Rare")
	check("missions: zone set is Common to Rare", #set == 5 and table.find(set, "Gravepup") ~= nil)

	-- Every pool entry has a known tier and a text that fills in.
	local pooled = true
	for _, mission in MissionConfig.Pool do
		pooled = pooled
			and Missions.tier(mission.tier) ~= nil
			and (mission.count ~= nil or mission.moneyShare ~= nil or mission.kind == "ZoneSet")
	end
	check("missions: pool entries are complete", pooled)

	local fresh = Missions.deal(nil, now, 20_000_000, 3, random)
	check("missions: three dealt, one per tier", #fresh.list == 3)
	local tiersSeen = {}
	for _, saved in fresh.list do
		local def = Missions.def(saved.id)
		tiersSeen[def and def.tier or "?"] = true
		check(`missions: {saved.id} text filled`, not string.find(Missions.text(saved), "{", 1, true))
	end
	check("missions: tiers", tiersSeen.Easy and tiersSeen.Medium and tiersSeen.Hard or false)
	check("missions: chest", fresh.chest == 1_200_000 and fresh.rerolls == MissionConfig.Rerolls)

	-- Counting.
	local state: any = {
		day = day,
		worth = 1_000_000,
		bonus = 0,
		streak = 0,
		lastDay = 0,
		rerolls = 1,
		chest = 60_000,
		list = {
			{ id = "Catch8", target = 2, progress = 0, reward = 30_000 },
			{ id = "Species4", zone = "MurkyBayou", target = 2, progress = 0, seen = {}, reward = 60_000 },
			{ id = "Variant1", target = 1, progress = 0, reward = 100_000 },
		},
	}
	Missions.record(state, "Catch", { monsterId = "Bogbub", zone = "MurkyBayou" })
	Missions.record(state, "Catch", { monsterId = "Bogbub", zone = "MurkyBayou" })
	check("missions: catches count", state.list[1].progress == 2 and Missions.isDone(state.list[1]))
	check("missions: same species counts once", state.list[2].progress == 1)
	Missions.record(state, "Catch", { monsterId = "Gloomlet", zone = "PumpkinGraveyard" })
	check("missions: other zone doesn't count", state.list[2].progress == 1)
	local finished =
		Missions.record(state, "Catch", { monsterId = "Croakling", zone = "MurkyBayou", variant = "Silver" })
	check("missions: species done and variant done", #finished == 2 and state.list[3].progress == 1)
	check("missions: catches stop at the target", state.list[1].progress == 2)
	check("missions: three ready", Missions.ready(state) == 3)
	check("missions: claim pays", Missions.claim(state, 1, now) == 30_000)
	check("missions: claim only once", Missions.claim(state, 1, now) == nil)
	check("missions: first claim starts the streak", state.streak == 1 and state.lastDay == day)
	check("missions: chest shut until all are claimed", Missions.claimChest(state) == nil)
	Missions.claim(state, 2, now)
	Missions.claim(state, 3, now)
	check("missions: chest opens", Missions.claimChest(state) == 60_000 and Missions.claimChest(state) == nil)
	check("missions: nothing left", Missions.ready(state) == 0)

	-- Sell, merges and rerolls.
	local other: any = Missions.empty()
	other.rerolls = 1
	other.list = {
		{ id = "SellSmall", target = 10_000, progress = 0, reward = 1 },
		{ id = "MergeWin", target = 1, progress = 0, reward = 1 },
	}
	Missions.record(other, "Sell", { amount = 6_000 })
	Missions.record(other, "Merge", { won = false })
	check(
		"missions: money adds up, lost merges don't count for wins",
		other.list[1].progress == 6_000 and other.list[2].progress == 0
	)
	Missions.record(other, "Merge", { won = true })
	check("missions: won merge counts", other.list[2].progress == 1)
	check("missions: can't reroll a finished one", not Missions.reroll(other, 2, 3, random))
	check(
		"missions: reroll swaps",
		Missions.reroll(other, 1, 3, random) and other.list[1].id ~= "SellSmall" and other.rerolls == 0
	)
	check("missions: no rerolls left", not Missions.reroll(other, 1, 3, random))

	-- Streaks: kept for a claim yesterday, lost after a missed day.
	local kept = Missions.deal(state, now + 86_400, 1_000_000, 3, random)
	check("missions: streak carries over", kept.streak == 1 and near(kept.bonus, 0.1))
	local next = Missions.deal(state, now + 2 * 86_400, 1_000_000, 3, random)
	check("missions: missed day resets the streak", next.streak == 0 and next.bonus == 0)
	local again = Missions.deal(state, now, 1_000_000, 3, random)
	check("missions: dealing again the same day keeps today's bonus", again.streak == 1 and again.bonus == 0)
end

-- Slapping: same place, close, not on a mansion plot, not in the tutorial, cooldown and guard;
-- slappers get better up the list and every one is sold in the Workshop.
do
	local Slap = require("../src/shared/Util/Slap")
	local SlapConfig = require("../src/shared/Config/Slap")
	local plot = Layout.Plots[1]
	local reach = 7
	-- A spot in the open hub: well clear of every plot.
	local hubX, hubZ = Layout.Hub.Center.x, Layout.Hub.Center.z
	check("slap: test spot is off the plots", not Travel.inPlot(hubX, hubZ))
	local function at(x: number, z: number, zone: string?): Slap.Hunter
		return { alive = true, zone = zone, tutorial = false, x = x, z = z }
	end
	local a, b = at(hubX, hubZ), at(hubX + 4, hubZ)
	check("slap: in the hub", Slap.blocked(a, b, 10, 0, 0, reach) == nil)
	check("slap: in a zone", Slap.blocked(at(0, 0, "Z1"), at(3, 0, "Z1"), 10, 0, 0, reach) == nil)
	check("slap: different zones", Slap.blocked(at(0, 0, "Z1"), at(3, 0, "Z2"), 10, 0, 0, reach) == "Apart")
	check("slap: zone vs hub", Slap.blocked(at(0, 0, "Z1"), at(0, 3), 10, 0, 0, reach) == "Apart")
	check("slap: too far", Slap.blocked(a, at(hubX + reach + 1, hubZ), 10, 0, 0, reach) == "Far")
	check("slap: more reach", Slap.blocked(a, at(hubX + reach + 1, hubZ), 10, 0, 0, reach + 2) == nil)
	local home = Slap.blocked(at(plot.x, plot.z), at(plot.x + 3, plot.z), 10, 0, 0, reach)
	check("slap: mansions are safe", home == "Mansion")
	check("slap: cooldown", Slap.blocked(a, b, 10, 12, 0, reach) == "Cooldown")
	check("slap: guarded", Slap.blocked(a, b, 10, 0, 12, reach) == "Guarded")
	local learner = at(hubX + 4, hubZ)
	learner.tutorial = true
	check("slap: tutorial is safe", Slap.blocked(a, learner, 10, 0, 0, reach) == "Tutorial")
	local px, pz = Slap.push(0, 0, 3, 4)
	check("slap: push points away", near(px, 0.6) and near(pz, 0.8))

	check("slap: nobody starts with a slapper", Slap.best({}) == nil)
	local best = Slap.best({ RubberGlove = 1, GhoulClaw = 1 })
	check("slap: best slapper is used", best ~= nil and best.id == "GhoulClaw")
	local better = true
	for i = 2, #SlapConfig.Slappers do
		local low, high = SlapConfig.Slappers[i - 1], SlapConfig.Slappers[i]
		better = better
			and high.reach > low.reach
			and high.push > low.push
			and high.stealLockSeconds > low.stealLockSeconds
	end
	check("slap: each slapper beats the one before", better)
	local sold, cheaper = true, true
	local lastPrice = -1
	for _, slapper in SlapConfig.Slappers do
		local item = Workshop.item(slapper.id)
		sold = sold and item ~= nil and item.kind == "Slapper" and item.price > 0
		if item then
			cheaper = cheaper and item.price > lastPrice
			lastPrice = item.price
		end
	end
	check("slap: every slapper is sold in the Workshop, dearer up the list", sold and cheaper)
	local glove = Workshop.item("RubberGlove") :: any
	check(
		"slap: slappers are always in stock and kept",
		Workshop.inStock(glove, 12345)
			and Workshop.limit(glove, 12345) == 1
			and Workshop.canBuy(glove, 12345, 1e12, { RubberGlove = 1 }, 0) == "Owned"
	)
	local strong = SlapConfig.Slappers[#SlapConfig.Slappers]
	local weak = SlapConfig.Slappers[1]
	local longer = Slap.stealLockUntil(strong, 100) > Slap.stealLockUntil(weak, 100)
	check("slap: stronger slap locks a thief longer", longer)
	check("slap: a weak slap never shortens a lock", Slap.stealLockUntil(weak, 100, 1000) == 1000)
end

-- Admin restocks (Util/Restock + Workshop.canBuy's adminStock)
do
	local plan = Restock.parse("cakes 10") :: Restock.Plan
	local allCakes, noTools, noEvent = true, true, true
	for _, item in Shop.Bakery do
		if not item.event and plan.items[item.id] ~= 10 then
			allCakes = false
		end
		if item.event and plan.items[item.id] then
			noEvent = false
		end
	end
	for _, item in Shop.Workshop do
		if plan.items[item.id] then
			noTools = false
		end
	end
	check("restock: cakes 10 puts every cake in at 10", allCakes and noTools and plan.minutes == 5)
	check("restock: groups leave out event treats", noEvent)
	local picked = Restock.parse("PUMPKINCANDY 3 baitbell 0 time 15") :: Restock.Plan
	local count = 0
	for _ in picked.items do
		count += 1
	end
	check(
		"restock: picked items, any capitals, 0 allowed, time in minutes",
		count == 2 and picked.items.PumpkinCandy == 3 and picked.items.BaitBell == 0 and picked.minutes == 15
	)
	local later = Restock.parse("all 3 PumpkinCandy 9") :: Restock.Plan
	check("restock: a later name wins", later.items.PumpkinCandy == 9 and later.items.BaitBell == 3)
	local everything = Restock.parse("all 1") :: Restock.Plan
	check(
		"restock: all leaves out vacuums and slappers",
		everything.items.VoidVac == nil and everything.items.RubberGlove == nil
	)
	check("restock: a vacuum can't be restocked", Restock.parse("VoidVac 5") == nil)
	check("restock: unknown items are refused", Restock.parse("Banana 5") == nil)
	check("restock: an amount is needed", Restock.parse("cakes") == nil and Restock.parse("") == nil)
	check(
		"restock: amounts stay in range",
		Restock.parse("cakes -1") == nil and Restock.parse("cakes 1000") == nil
	)
	check(
		"restock: time stays in range",
		Restock.parse("cakes 1 time 0") == nil and Restock.parse("cakes 1 time 121") == nil
	)
	check("restock: nan is refused", Restock.parse("cakes nan") == nil)
	local back = Restock.parse(Restock.argument(picked.items, 15)) :: Restock.Plan
	check(
		"restock: the panel's argument reads back the same",
		back.items.PumpkinCandy == 3 and back.items.BaitBell == 0 and back.minutes == 15
	)
	local charm = Workshop.item("ReturnCharm") :: Shop.Item
	local outSlot = 1
	while Workshop.inStock(charm, outSlot) do
		outSlot += 1
	end
	check(
		"restock: an admin amount puts an item in stock",
		Workshop.canBuy(charm, outSlot, 1e9, {}, 0, nil, nil, 20) == "Ok"
	)
	check(
		"restock: it sells out at the admin amount",
		Workshop.canBuy(charm, outSlot, 1e9, {}, 20, nil, nil, 20) == "SoldOut"
	)
	local inSlot = 1
	while not Workshop.inStock(charm, inSlot) do
		inSlot += 1
	end
	check(
		"restock: 0 means sold out",
		Workshop.canBuy(charm, inSlot, 1e9, {}, 0, nil, nil, 0) == "OutOfStock"
	)
end

if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("all checks passed")
