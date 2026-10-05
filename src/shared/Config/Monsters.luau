--!strict
-- Every catchable monster. Zone monsters spawn by weight (percent of spawns in that zone);
-- event monsters spawn only in the main area during their Watcher event and have fixed values.

export type Monster = {
	id: string,
	rarity: string,
	baseValue: number,
	zone: number?,
	spawnWeight: number?,
	event: string?,
}

local Monsters: { [string]: Monster } = {}

local function add(m: Monster)
	assert(Monsters[m.id] == nil, "duplicate monster " .. m.id)
	Monsters[m.id] = m
end

-- Zone 1: Pumpkin Graveyard (unlocked by the Foyer)
add({ id = "Gloomlet", rarity = "Common", baseValue = 10, zone = 1, spawnWeight = 27 })
add({ id = "Skittercrow", rarity = "Common", baseValue = 15, zone = 1, spawnWeight = 18 })
add({ id = "Mossbones", rarity = "Uncommon", baseValue = 30, zone = 1, spawnWeight = 18 })
add({ id = "WispJack", rarity = "Uncommon", baseValue = 45, zone = 1, spawnWeight = 12 })
add({ id = "Gravepup", rarity = "Rare", baseValue = 100, zone = 1, spawnWeight = 15 })
add({ id = "Tombgrin", rarity = "Epic", baseValue = 400, zone = 1, spawnWeight = 7 })
add({ id = "TheGroundskeeper", rarity = "Legendary", baseValue = 2_000, zone = 1, spawnWeight = 2.5 })
add({ id = "TheHeadlessRider", rarity = "Mythic", baseValue = 15_000, zone = 1, spawnWeight = 0.45 })
add({ id = "LadyOfLanterns", rarity = "Divine", baseValue = 150_000, zone = 1, spawnWeight = 0.05 })

-- Zone 2: Murky Bayou (unlocked by the Library)
add({ id = "Bogbub", rarity = "Common", baseValue = 40, zone = 2, spawnWeight = 27 })
add({ id = "Croakling", rarity = "Common", baseValue = 60, zone = 2, spawnWeight = 18 })
add({ id = "WillowWisp", rarity = "Uncommon", baseValue = 120, zone = 2, spawnWeight = 18 })
add({ id = "Reedwitch", rarity = "Uncommon", baseValue = 180, zone = 2, spawnWeight = 12 })
add({ id = "Gatorghast", rarity = "Rare", baseValue = 400, zone = 2, spawnWeight = 15 })
add({ id = "SunkenBell", rarity = "Epic", baseValue = 1_600, zone = 2, spawnWeight = 7 })
add({ id = "TheBogKing", rarity = "Legendary", baseValue = 8_000, zone = 2, spawnWeight = 2.5 })
add({ id = "MireSerpent", rarity = "Mythic", baseValue = 60_000, zone = 2, spawnWeight = 0.45 })
add({ id = "MoonlitHeron", rarity = "Divine", baseValue = 600_000, zone = 2, spawnWeight = 0.05 })

-- Zone 3: Abandoned Carnival (unlocked by the Ballroom)
add({ id = "Poplet", rarity = "Common", baseValue = 160, zone = 3, spawnWeight = 27 })
add({ id = "BalloonBoo", rarity = "Common", baseValue = 240, zone = 3, spawnWeight = 18 })
add({ id = "TicketGremlin", rarity = "Uncommon", baseValue = 480, zone = 3, spawnWeight = 18 })
add({ id = "CarouselColt", rarity = "Uncommon", baseValue = 720, zone = 3, spawnWeight = 12 })
add({ id = "JesterJinx", rarity = "Rare", baseValue = 1_600, zone = 3, spawnWeight = 15 })
add({ id = "MirrorGrin", rarity = "Epic", baseValue = 6_400, zone = 3, spawnWeight = 7 })
add({ id = "TheRingmaster", rarity = "Legendary", baseValue = 32_000, zone = 3, spawnWeight = 2.5 })
add({ id = "BigTopTerror", rarity = "Mythic", baseValue = 240_000, zone = 3, spawnWeight = 0.45 })
add({ id = "GoldenCarousel", rarity = "Divine", baseValue = 2_400_000, zone = 3, spawnWeight = 0.05 })

-- Zone 4: Spooky School (unlocked by the Attic)
add({ id = "Chalkling", rarity = "Common", baseValue = 650, zone = 4, spawnWeight = 27 })
add({ id = "Paperbat", rarity = "Common", baseValue = 1_000, zone = 4, spawnWeight = 18 })
add({ id = "LunchGhoul", rarity = "Uncommon", baseValue = 2_000, zone = 4, spawnWeight = 18 })
add({ id = "LockerLurker", rarity = "Uncommon", baseValue = 3_000, zone = 4, spawnWeight = 12 })
add({ id = "HallMonitor", rarity = "Rare", baseValue = 6_500, zone = 4, spawnWeight = 15 })
add({ id = "DetentionShade", rarity = "Epic", baseValue = 26_000, zone = 4, spawnWeight = 7 })
add({ id = "ThePrincipal", rarity = "Legendary", baseValue = 130_000, zone = 4, spawnWeight = 2.5 })
add({ id = "BellTowerBat", rarity = "Mythic", baseValue = 1_000_000, zone = 4, spawnWeight = 0.45 })
add({ id = "StarlightScholar", rarity = "Divine", baseValue = 10_000_000, zone = 4, spawnWeight = 0.05 })

-- Zone 5: Ghost Ship (unlocked by the Crypt)
add({ id = "BarnacleBoo", rarity = "Common", baseValue = 2_600, zone = 5, spawnWeight = 27 })
add({ id = "Gullghast", rarity = "Common", baseValue = 4_000, zone = 5, spawnWeight = 18 })
add({ id = "BottleSpirit", rarity = "Uncommon", baseValue = 8_000, zone = 5, spawnWeight = 18 })
add({ id = "AnchorCrab", rarity = "Uncommon", baseValue = 12_000, zone = 5, spawnWeight = 12 })
add({ id = "Kraklet", rarity = "Rare", baseValue = 26_000, zone = 5, spawnWeight = 15 })
add({ id = "SirenShade", rarity = "Epic", baseValue = 100_000, zone = 5, spawnWeight = 7 })
add({ id = "CaptainDreadwake", rarity = "Legendary", baseValue = 500_000, zone = 5, spawnWeight = 2.5 })
add({ id = "TheKraken", rarity = "Mythic", baseValue = 4_000_000, zone = 5, spawnWeight = 0.45 })
add({ id = "SeraphOfTheDeep", rarity = "Divine", baseValue = 40_000_000, zone = 5, spawnWeight = 0.05 })

-- Watcher event monsters (main area only)
add({ id = "Flickerwick", rarity = "Phantom", baseValue = 250_000, event = "Flicker" })
add({ id = "StaticShade", rarity = "Phantom", baseValue = 400_000, event = "Flicker" })
add({ id = "CrimsonWisp", rarity = "Phantom", baseValue = 600_000, event = "BloodMoon" })
add({ id = "Moonhowler", rarity = "Phantom", baseValue = 900_000, event = "BloodMoon" })
add({ id = "MailboxMimic", rarity = "Nightmare", baseValue = 3_000_000, event = "MimicNight" })
add({ id = "LamppostLurker", rarity = "Nightmare", baseValue = 5_000_000, event = "MimicNight" })
add({ id = "StormGremlin", rarity = "Nightmare", baseValue = 8_000_000, event = "BreachStorm" })
add({ id = "Doorknocker", rarity = "Nightmare", baseValue = 12_000_000, event = "BreachStorm" })
add({ id = "Watcherling", rarity = "Eldritch", baseValue = 80_000_000, event = "WatcherAwakens" })
add({ id = "EyeOfTheWatcher", rarity = "Eldritch", baseValue = 150_000_000, event = "WatcherAwakens" })

return Monsters
