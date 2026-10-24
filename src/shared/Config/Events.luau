--!strict
-- Watcher events: every few minutes the Watcher stirs and an event changes the sky for the
-- whole server. Events are passive: players keep doing what they were doing while the sky
-- changes and their mansion monsters pick up the event's boosts. Numbers are placeholders.
--
-- The clock (Util/Watcher, server/Services/WatcherService):
--   calm      a random gap of GapMinSeconds to GapMaxSeconds after the last event ends
--   warning   WarningSeconds before the event; the sky already starts to change
--   live      the event's durationSeconds; then calm again
-- The next event is picked by weight and is never the one that just played. Each event opens
-- one of the Watcher's eyes; once EyesToAwaken are open, the next event is The Watcher Awakens
-- (the event marked `awakening`), which closes them all again.

export type Rgb = { number } -- { red, green, blue }, 0 to 255 (Color3.fromRGB)

-- How an event changes the sky. Lighting values are set on the server and reach everyone;
-- the sky pieces (moon, eye, aurora, sparkles, flashes) are drawn by each client around its
-- own camera (client/Controllers/SkyController), so players in zones see them too.
export type Weather = {
	kind: "Snow"
		| "Rain"
		| "Coins"
		| "Candy"
		| "Eyes"
		| "Ghosts"
		| "Lanterns"
		| "Brooms"
		| "Spiders"
		| "Hands"
		| "SkyLanterns"
		| "Leaves"
		| "Crates"
		| "Rifts",
	color: Rgb?,
}

export type Sky = {
	ambient: Rgb?, -- Lighting.Ambient
	outdoorAmbient: Rgb?, -- Lighting.OutdoorAmbient
	brightness: number?, -- Lighting.Brightness (the night is 2.4)
	tint: Rgb?, -- colour filter over the whole screen
	saturation: number?, -- -1 (grey) to 1 (vivid)
	atmosphere: { color: Rgb, decay: Rgb, density: number, haze: number }?,
	moon: { color: Rgb, size: number, coin: boolean? }?, -- a big disc in the sky; coin: flat and gold
	eye: boolean?, -- the Watcher's giant eye, looking around
	aurora: Rgb?, -- a curtain of light rippling across the northern sky
	sparkles: Rgb?, -- specks drifting down everywhere
	mist: Rgb?, -- low fog rolling over the ground round your feet
	flashes: boolean?, -- lightning: the screen flashes and bolts strike in the distance
	-- What falls (or floats) all around the player while the event is on:
	--   Snow   a thick, sideways-blowing snowstorm
	--   Rain   fast streaks of rain (Blood Moon: blood-red)
	--   Coins  spinning gold coins tumbling out of the sky
	--   Candy  sweets and sprinkles in every colour
	--   Eyes   eyeballs floating in the air, all turning to look at you
	--   Ghosts    pale ghosts flying in circles high over the hub (Phantom Swarm)
	--   Lanterns  a parade of grinning lantern heads marching round the hub (Nightmare Parade)
	--   Brooms       witches on broomsticks circling high over the hub (Witching Hour)
	--   Spiders      spiders dangling on threads all around you (Spider Season)
	--   Hands        skeleton hands pushing up out of the ground round you (Bone Rattle)
	--   SkyLanterns  glowing paper lanterns drifting up into the sky (Ghost Market)
	--   Leaves       autumn leaves see-sawing down (Harvest Moon)
	--   Crates       crates with teeth popping up out of the ground round you (Mimic Night)
	--   Rifts        glowing rifts torn open high over the hub (Breach Storm)
	weather: Weather?,
	edge: Rgb?, -- the event's colour: its icon, its banner and the screen frame
	frame: boolean?, -- a glow round the edges of the screen in the edge colour (only the scariest)
}

export type MonsterSet = {
	id: string,
	name: string, -- shown to players
	weight: number,
	monsters: { [string]: number }, -- monster id -> spawn weight
	count: number?, -- how many appear (nil: Events.MonstersPerPlayer etc.)
	announce: string, -- toast everyone sees when the event starts with this set
	noRespawn: boolean?, -- a caught one isn't replaced (the Eldritch jackpot stays one per event)
	sky: Sky?, -- this set's own sky (nil: the event's sky)
}

export type WatcherEvent = {
	id: string,
	name: string, -- shown to players
	icon: string?, -- emoji on the event's button at the bottom of the screen while it's live
	launch: boolean,
	weight: number?, -- how often it's picked by the clock (nil: never picked by weight)
	awakening: boolean?, -- plays when all the eyes are open
	effect: string?, -- haunted effect mansion monsters can pick up while the event is live
	effectChance: number?, -- percent per monster per EffectRollSeconds (raised like roaming odds)
	otherEffectsChance: number?, -- percent per roll for one of the other events' effects
	durationSeconds: number?,
	monsters: { [string]: number }?, -- event monster id -> spawn weight (optional bonus to catch)
	-- The Watcher Awakens instead picks one of these sets each time, by weight: usually the
	-- small Phantoms, sometimes Nightmares, rarely the Eldritch ones.
	monsterSets: { MonsterSet }?,
	-- Breach Storm: monsters from every launch zone fall into the hub instead (by their zone
	-- spawn weights), with Legendary and rarer rareMultiplier times as likely. Normal vacuum
	-- rules apply.
	zoneMonsters: { rareMultiplier: number }?,
	grounded: boolean?, -- its monsters walk on the ground instead of hovering
	monsterSpeed: number?, -- studs per second its monsters move (nil: DriftSpeed)
	-- Mimic Night: a monster that isn't being caught bites anyone in the main area who walks
	-- within radius studs, knocking them back (no damage; once per cooldown seconds per player).
	bite: { radius: number, cooldown: number }?,
	rifts: boolean?, -- each of its monsters drops out of a rift that opens above it
	effectOddsMultiplier: number?, -- mansion effect odds while live (Blood Moon doubles them)
	growthMultiplier: number?, -- extra growth spurt rolls while live (Config/Weight.EventSpurtChance)
	cakeEffectMultiplier: number?, -- a cake bite's effect chance (Config/Cakes.BiteEffectChance) x this
	bakeryStockMultiplier: number?, -- Bakery restock chances while live (an item in stock stays in)
	sellMultiplier: number?, -- the Collector pays this much more while live
	sky: Sky?,
	warning: string?, -- toast everyone sees when the warning starts
	announce: string?, -- toast everyone sees when it starts
}

local Events = {}

Events.GapMinSeconds = 5 * 60
Events.GapMaxSeconds = 10 * 60
Events.WarningSeconds = 30
Events.EyesToAwaken = 5

-- While an event is live, every monster in the mansions of the players in the server rolls
-- for the event's effect this often (Util/Haunting.eventRoll).
Events.EffectRollSeconds = 30

-- How many event monsters (an optional bonus to catch, only in the rare events: Blood Moon,
-- Mimic Night, Breach Storm and The Watcher Awakens) are out during an event (caught ones come back, RespawnSeconds): this many per player in the
-- server, clamped between Min and Max, so everyone gets a chance. Each kind appears at least
-- once. A monster set with a count brings just that many.
Events.MonstersPerPlayer = 1
Events.MinMonsters = 4
Events.MaxMonsters = 10

-- A caught event monster is replaced this many seconds later, so there is something to
-- catch all event long, not just in the first minute (a set with noRespawn excepted).
Events.RespawnSeconds = 20

-- An event can't come back until this many other events have played since (the clock's pick).
Events.NoRepeat = 3

-- Event monsters drift between the mansions, this many studs above the ground.
Events.HoverHeight = 3
Events.DriftSpeed = 5 -- studs per second

-- Where event monsters drift: the lanes between the two rows of mansions, keeping clear of
-- the stands in the middle row: Growth Chamber (x -185..-145), Collector (x -130..-90), Trading
-- Booth (x 90..130) and Merger (x 145..185). Hub coordinates, studs.
Events.DriftAreas = {
	{ x = 0, z = -47.5, width = 580, depth = 45 }, -- north lane, in front of plots 1-4
	{ x = 0, z = 47.5, width = 580, depth = 45 }, -- south lane, in front of plots 5-8
	{ x = -245, z = 0, width = 100, depth = 50 }, -- west middle
	{ x = 0, z = 0, width = 140, depth = 50 }, -- around Watcher Square
	{ x = 245, z = 0, width = 100, depth = 50 }, -- east middle
}

Events.List = {
	{
		id = "FrostFog",
		name = "Frost Fog",
		icon = "❄️",
		launch = true,
		weight = 13,
		effect = "Frostbitten",
		effectChance = 6,
		durationSeconds = 180,
		sky = {
			ambient = { 80, 110, 150 },
			outdoorAmbient = { 110, 150, 200 },
			tint = { 205, 230, 255 },
			saturation = -0.15,
			atmosphere = { color = { 220, 235, 250 }, decay = { 160, 190, 225 }, density = 0.6, haze = 3 },
			aurora = { 120, 230, 255 },
			mist = { 220, 240, 255 },
			weather = { kind = "Snow" },
			edge = { 225, 245, 255 },
		},
		warning = "The air turns icy cold...",
		announce = "Frost Fog rolls in! Monsters can freeze over, and the Bakery sells Frost Tarts.",
	},
	{
		id = "SugarRush",
		name = "Sugar Rush",
		icon = "🍬",
		launch = true,
		weight = 11,
		effect = "Sugarcoated",
		effectChance = 6,
		durationSeconds = 180,
		growthMultiplier = 2,
		cakeEffectMultiplier = 2,
		bakeryStockMultiplier = 3,
		sky = {
			ambient = { 70, 115, 65 },
			outdoorAmbient = { 105, 170, 90 },
			tint = { 215, 255, 195 },
			saturation = 0.15,
			atmosphere = { color = { 150, 220, 115 }, decay = { 45, 110, 45 }, density = 0.38, haze = 2 },
			sparkles = { 230, 255, 160 },
			weather = { kind = "Candy" },
			edge = { 140, 255, 120 },
		},
		warning = "Something sweet is in the air...",
		announce = "Sugar Rush! Cakes get eaten twice as fast, monsters grow and the Bakery is packed.",
	},
	{
		id = "GoldRush",
		name = "Gold Rush",
		icon = "💰",
		launch = true,
		weight = 8,
		effect = "Gilded",
		effectChance = 4,
		durationSeconds = 180,
		sellMultiplier = 1.25,
		sky = {
			ambient = { 130, 95, 50 },
			outdoorAmbient = { 200, 145, 70 },
			tint = { 255, 228, 180 },
			saturation = 0.1,
			atmosphere = { color = { 240, 180, 90 }, decay = { 150, 85, 25 }, density = 0.3, haze = 1.4 },
			moon = { color = { 255, 205, 80 }, size = 70, coin = true },
			sparkles = { 255, 215, 110 },
			weather = { kind = "Coins" },
			edge = { 255, 200, 60 },
		},
		warning = "Coins jingle somewhere in the dark...",
		announce = "Gold Rush! The Collector pays 25% more and the Bakery sells Gilded Truffles.",
	},
	{
		id = "Flicker",
		name = "Flicker",
		icon = "⚡",
		launch = true,
		weight = 10,
		effect = "Poltergeist",
		effectChance = 4,
		durationSeconds = 180,
		sky = {
			ambient = { 30, 30, 40 },
			outdoorAmbient = { 40, 40, 55 },
			brightness = 1.2,
			tint = { 205, 210, 235 },
			saturation = -0.45,
			atmosphere = { color = { 45, 45, 60 }, decay = { 12, 12, 18 }, density = 0.5, haze = 2 },
			flashes = true,
			mist = { 70, 75, 95 },
			weather = { kind = "Rain", color = { 170, 180, 210 } },
			edge = { 10, 10, 20 },
		},
		warning = "The streetlights buzz and dim...",
		announce = "Flicker! The lights are failing and the Bakery sells Static Cupcakes.",
	},
	{
		id = "SpiderSeason",
		name = "Spider Season",
		icon = "🕷️",
		launch = true,
		weight = 10,
		effect = "Cobwebbed",
		effectChance = 8,
		effectOddsMultiplier = 2,
		durationSeconds = 180,
		sky = {
			ambient = { 50, 50, 60 },
			outdoorAmbient = { 75, 75, 90 },
			tint = { 225, 225, 235 },
			saturation = -0.5,
			atmosphere = { color = { 150, 150, 165 }, decay = { 60, 60, 70 }, density = 0.45, haze = 2.5 },
			mist = { 205, 205, 215 },
			weather = { kind = "Spiders" },
			edge = { 200, 200, 215 },
		},
		warning = "Something is skittering across the hub...",
		announce = "Spider Season! Mansion monsters pick up effects twice as often and the Bakery sells Web Waffles.",
	},
	{
		id = "HarvestMoon",
		name = "Harvest Moon",
		icon = "🌕",
		launch = true,
		weight = 10,
		effect = "Harvested",
		effectChance = 4,
		growthMultiplier = 3,
		durationSeconds = 180,
		sky = {
			ambient = { 80, 50, 30 },
			outdoorAmbient = { 120, 75, 40 },
			tint = { 255, 215, 170 },
			saturation = 0.15,
			atmosphere = { color = { 150, 90, 40 }, decay = { 90, 40, 10 }, density = 0.35, haze = 1.5 },
			moon = { color = { 255, 150, 50 }, size = 110 },
			weather = { kind = "Leaves" },
			edge = { 255, 150, 50 },
		},
		warning = "The moon is rising, huge and orange...",
		announce = "Harvest Moon! Monsters grow faster and the Bakery sells Pumpkin Spice Rolls.",
	},
	{
		id = "WitchingHour",
		name = "Witching Hour",
		icon = "🧹",
		launch = true,
		weight = 9,
		effect = "Bewitched",
		effectChance = 3,
		cakeEffectMultiplier = 2,
		bakeryStockMultiplier = 2,
		durationSeconds = 180,
		sky = {
			ambient = { 50, 25, 70 },
			outdoorAmbient = { 70, 40, 95 },
			tint = { 215, 200, 255 },
			atmosphere = { color = { 70, 30, 100 }, decay = { 20, 80, 40 }, density = 0.45, haze = 2 },
			aurora = { 140, 255, 140 },
			mist = { 110, 255, 140 },
			weather = { kind = "Brooms" },
			edge = { 130, 255, 140 },
		},
		warning = "Cackling echoes over the rooftops...",
		announce = "Witching Hour! Cakes work twice as well and the Bakery sells Cauldron Cupcakes.",
	},
	{
		id = "GhostMarket",
		name = "Ghost Market",
		icon = "🏮",
		launch = true,
		weight = 9,
		sellMultiplier = 1.5,
		durationSeconds = 180,
		sky = {
			ambient = { 60, 45, 40 },
			outdoorAmbient = { 95, 70, 55 },
			tint = { 255, 230, 200 },
			atmosphere = { color = { 120, 80, 50 }, decay = { 60, 30, 15 }, density = 0.3, haze = 1.5 },
			sparkles = { 255, 200, 120 },
			weather = { kind = "SkyLanterns" },
			edge = { 255, 170, 80 },
		},
		warning = "Paper lanterns flicker on, one by one...",
		announce = "Ghost Market! The Collector pays 50% more. Time to sell!",
	},
	{
		id = "BoneRattle",
		name = "Bone Rattle",
		icon = "💀",
		launch = true,
		weight = 9,
		effect = "Skeletal",
		effectChance = 4,
		durationSeconds = 180,
		sky = {
			ambient = { 40, 55, 45 },
			outdoorAmbient = { 60, 80, 65 },
			tint = { 215, 240, 215 },
			saturation = -0.3,
			atmosphere = { color = { 90, 120, 95 }, decay = { 30, 60, 35 }, density = 0.45, haze = 2.5 },
			mist = { 190, 230, 190 },
			weather = { kind = "Hands" },
			edge = { 200, 240, 200 },
		},
		warning = "The ground is starting to rattle...",
		announce = "Bone Rattle! Monsters can turn Skeletal and the Bakery sells Bone Biscuits.",
	},
	{
		id = "BloodMoon",
		name = "Blood Moon",
		icon = "🩸",
		launch = true,
		weight = 6,
		effect = "Bloodmoon",
		effectChance = 2,
		durationSeconds = 240,
		monsters = { CrimsonWisp = 70, Moonhowler = 30 },
		effectOddsMultiplier = 2,
		growthMultiplier = 2,
		sky = {
			ambient = { 70, 20, 20 },
			outdoorAmbient = { 150, 30, 30 },
			tint = { 255, 170, 170 },
			atmosphere = { color = { 190, 50, 50 }, decay = { 100, 0, 0 }, density = 0.35, haze = 1.5 },
			moon = { color = { 255, 70, 55 }, size = 90 },
			weather = { kind = "Rain", color = { 200, 25, 30 } },
			edge = { 170, 0, 10 },
			frame = true,
		},
		warning = "The moon is turning red...",
		announce = "A Blood Moon rises! Haunted effects are twice as likely, monsters grow, Phantoms roam and the Bakery sells Blood Moon Pies.",
	},
	{
		id = "MimicNight",
		name = "Mimic Night",
		icon = "📦",
		launch = true,
		weight = 4,
		effect = "Mimic",
		effectChance = 1.5,
		durationSeconds = 240,
		monsters = { CrateMimic = 65, BarrelMimic = 35 },
		grounded = true,
		monsterSpeed = 1.5, -- they creep: did that crate just move?
		bite = { radius = 6, cooldown = 4 },
		sky = {
			ambient = { 40, 55, 50 },
			outdoorAmbient = { 70, 95, 85 },
			tint = { 220, 255, 235 },
			saturation = -0.15,
			atmosphere = { color = { 60, 95, 85 }, decay = { 20, 45, 40 }, density = 0.45, haze = 2 },
			mist = { 150, 230, 200 },
			weather = { kind = "Crates" },
			edge = { 120, 230, 190 },
		},
		warning = "The crates around the hub are... breathing?",
		announce = "Mimic Night! Some crates and barrels are Mimics. Watch your step, they bite!",
	},
	{
		id = "BreachStorm",
		name = "Breach Storm",
		icon = "🌀",
		launch = true,
		weight = 4.5,
		effect = "Rifted",
		effectChance = 2,
		durationSeconds = 240,
		zoneMonsters = { rareMultiplier = 5 },
		grounded = true,
		rifts = true,
		sky = {
			ambient = { 40, 40, 85 },
			outdoorAmbient = { 70, 70, 140 },
			tint = { 210, 215, 255 },
			saturation = 0.1,
			atmosphere = { color = { 60, 50, 125 }, decay = { 20, 10, 60 }, density = 0.4, haze = 2 },
			flashes = true,
			weather = { kind = "Rifts" },
			edge = { 130, 160, 255 },
		},
		warning = "The sky over the hub is starting to crack...",
		announce = "Breach Storm! Zone monsters are falling through the rifts. Legendaries and up are 5x as likely!",
	},
	{
		id = "WatcherAwakens",
		name = "The Watcher Awakens",
		icon = "👁️",
		launch = true,
		awakening = true,
		effect = "Watched",
		effectChance = 0.3,
		otherEffectsChance = 1,
		durationSeconds = 300,
		growthMultiplier = 3,
		monsterSets = {
			{
				id = "Phantoms",
				name = "Phantom Swarm",
				weight = 65,
				monsters = { Flickerwick = 60, StaticShade = 40 },
				announce = "Phantoms pour out of the Watcher's eye!",
				sky = {
					ambient = { 70, 85, 110 },
					outdoorAmbient = { 110, 130, 165 },
					tint = { 205, 225, 255 },
					saturation = -0.35,
					atmosphere = {
						color = { 170, 190, 220 },
						decay = { 90, 110, 150 },
						density = 0.4,
						haze = 2,
					},
					aurora = { 180, 230, 255 },
					mist = { 200, 225, 255 },
					weather = { kind = "Ghosts" },
					edge = { 190, 225, 255 },
				},
			},
			{
				id = "Nightmares",
				name = "Nightmare Parade",
				weight = 28,
				monsters = { MailboxMimic = 35, LamppostLurker = 30, StormGremlin = 20, Doorknocker = 15 },
				count = 2,
				announce = "Nightmares crawl out of the shadows! Only a Void Vac can hold them.",
				sky = {
					ambient = { 60, 10, 20 },
					outdoorAmbient = { 85, 15, 30 },
					tint = { 255, 175, 175 },
					saturation = 0.1,
					atmosphere = { color = { 45, 0, 10 }, decay = { 95, 0, 20 }, density = 0.5, haze = 2 },
					moon = { color = { 255, 120, 40 }, size = 60 },
					flashes = true,
					mist = { 120, 10, 25 },
					weather = { kind = "Lanterns" },
					edge = { 160, 0, 25 },
				},
			},
			{
				id = "Eldritch",
				name = "Eldritch Gaze",
				weight = 7,
				monsters = { Watcherling = 70, EyeOfTheWatcher = 30 },
				count = 1,
				noRespawn = true,
				announce = "Something ELDRITCH has slipped through. Only a Void Vac can hold it!",
			},
		} :: { MonsterSet },
		sky = {
			ambient = { 55, 25, 75 },
			outdoorAmbient = { 80, 35, 110 },
			tint = { 225, 195, 255 },
			saturation = -0.1,
			atmosphere = { color = { 95, 45, 125 }, decay = { 35, 0, 45 }, density = 0.45, haze = 2.5 },
			eye = true,
			weather = { kind = "Eyes" },
			edge = { 110, 30, 160 },
			frame = true,
		},
		warning = "All five eyes are open. The Watcher is waking up...",
		announce = "THE WATCHER AWAKENS! Its eye is on every mansion.",
	},
} :: { WatcherEvent }

-- The sky an event shows: the monster set's own sky (The Watcher Awakens), else the event's.
function Events.skyFor(event: WatcherEvent, setId: string?): Sky?
	local sets: { MonsterSet } = event.monsterSets or {}
	for _, set in sets do
		if set.id == setId and set.sky then
			return set.sky
		end
	end
	return event.sky
end

-- Finds an event by id.
function Events.find(id: string?): WatcherEvent?
	for _, event in Events.List do
		if event.id == id then
			return event
		end
	end
	return nil
end

return Events
