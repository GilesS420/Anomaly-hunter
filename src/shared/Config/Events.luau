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
export type Weather = { kind: "Snow" | "Rain" | "Coins" | "Candy" | "Eyes", color: Rgb? }

export type Sky = {
	ambient: Rgb?, -- Lighting.Ambient
	outdoorAmbient: Rgb?, -- Lighting.OutdoorAmbient
	brightness: number?, -- Lighting.Brightness (the night is 2.4)
	tint: Rgb?, -- colour filter over the whole screen
	saturation: number?, -- -1 (grey) to 1 (vivid)
	atmosphere: { color: Rgb, decay: Rgb, density: number, haze: number }?,
	moon: { color: Rgb, size: number, coin: boolean? }?, -- a big disc in the sky; coin: flat and gold
	eye: boolean?, -- the Watcher's giant eye, looking around
	aurora: Rgb?, -- slow waving bands of light
	sparkles: Rgb?, -- specks drifting down everywhere
	flashes: boolean?, -- lightning: the screen flashes and bolts strike in the distance
	-- What falls (or floats) all around the player while the event is on:
	--   Snow   a thick, sideways-blowing snowstorm
	--   Rain   fast streaks of rain (Blood Moon: blood-red)
	--   Coins  spinning gold coins tumbling out of the sky
	--   Candy  sweets and sprinkles in every colour
	--   Eyes   eyeballs floating in the air, all turning to look at you
	weather: Weather?,
	edge: Rgb?, -- a glow round the edges of the screen in this colour
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

-- How many event monsters (the Flicker and Blood Moon Phantoms, an optional bonus to catch)
-- appear at the start of an event: this many per player in the server, clamped between Min
-- and Max, so everyone gets a chance.
Events.MonstersPerPlayer = 1
Events.MinMonsters = 4
Events.MaxMonsters = 10

-- Event monsters drift between the mansions, this many studs above the ground.
Events.HoverHeight = 3
Events.DriftSpeed = 5 -- studs per second

-- Where event monsters drift: the lanes between the two rows of mansions, keeping clear of
-- the Collector (x -130..-90) and the Trading Booth (x 90..130). Hub coordinates, studs.
Events.DriftAreas = {
	{ x = 0, z = -47.5, width = 580, depth = 45 }, -- north lane, in front of plots 1-4
	{ x = 0, z = 47.5, width = 580, depth = 45 }, -- south lane, in front of plots 5-8
	{ x = -220, z = 0, width = 140, depth = 50 }, -- west middle
	{ x = 0, z = 0, width = 140, depth = 50 }, -- around Watcher Square
	{ x = 220, z = 0, width = 140, depth = 50 }, -- east middle
}

Events.List = {
	{
		id = "FrostFog",
		name = "Frost Fog",
		icon = "❄️",
		launch = true,
		weight = 30,
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
		weight = 25,
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
		weight = 15,
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
		weight = 20,
		effect = "Poltergeist",
		effectChance = 4,
		durationSeconds = 180,
		monsters = { Flickerwick = 70, StaticShade = 30 },
		sky = {
			ambient = { 30, 30, 40 },
			outdoorAmbient = { 40, 40, 55 },
			brightness = 1.2,
			tint = { 205, 210, 235 },
			saturation = -0.45,
			atmosphere = { color = { 45, 45, 60 }, decay = { 12, 12, 18 }, density = 0.5, haze = 2 },
			flashes = true,
			weather = { kind = "Rain", color = { 170, 180, 210 } },
			edge = { 10, 10, 20 },
		},
		warning = "The streetlights buzz and dim...",
		announce = "Flicker! The lights are failing, Phantoms drift between the mansions and the Bakery sells Static Cupcakes.",
	},
	{
		id = "BloodMoon",
		name = "Blood Moon",
		icon = "🩸",
		launch = true,
		weight = 10,
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
		},
		warning = "The moon is turning red...",
		announce = "A Blood Moon rises! Haunted effects are twice as likely, monsters grow, Phantoms roam and the Bakery sells Blood Moon Pies.",
	},
	{ id = "MimicNight", name = "Mimic Night", launch = false, effect = "Mimic" },
	{ id = "BreachStorm", name = "Breach Storm", launch = false },
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
		sky = {
			ambient = { 55, 25, 75 },
			outdoorAmbient = { 80, 35, 110 },
			tint = { 225, 195, 255 },
			saturation = -0.1,
			atmosphere = { color = { 95, 45, 125 }, decay = { 35, 0, 45 }, density = 0.45, haze = 2.5 },
			eye = true,
			weather = { kind = "Eyes" },
			edge = { 110, 30, 160 },
		},
		warning = "All five eyes are open. The Watcher is waking up...",
		announce = "THE WATCHER AWAKENS! Its eye is on every mansion.",
	},
} :: { WatcherEvent }

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
