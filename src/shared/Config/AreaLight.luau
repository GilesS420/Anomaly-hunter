--!strict
-- How light it is where you stand (client/Controllers/AreaLightController). Giles 2026-11-06:
-- the hub should be a bright, friendly place and the zones stay dark and scary.
--
--   Hub        a warm late afternoon: the sun is up, low and orange, so mansions, stands and
--              monsters are easy to see. Still Halloween: the purple haze stays.
--   HubEvent   while a Watcher event is coming or on: the sun sets into a purple twilight, so
--              the event's own sky (moon, eye, aurora, weather) shows up.
--   Zone       a clear, silvery night: bright moonlight without a moon, lots of stars.
--
-- Only this client's own Lighting is changed: ClockTime, ExposureCompensation and one
-- ColorCorrectionEffect ("AreaLight") the server never touches. The server's night
-- (WorldBuilder.setNight) and the event skies (WatcherService.applySky: Ambient, Brightness,
-- Atmosphere, tints) stay the server's, so they keep working everywhere.
--
-- These are first guesses: tune them in Studio (play, then change the numbers here).

export type Look = {
	clockTime: number, -- 0-24; 24 is midnight reached by going forward through the evening
	exposure: number, -- Lighting.ExposureCompensation
	brightness: number, -- ColorCorrectionEffect
	contrast: number,
	saturation: number,
	tint: { number }, -- RGB
}

local Looks: { [string]: Look } = {
	Hub = {
		clockTime = 16.6,
		exposure = 0.15,
		brightness = 0.04,
		contrast = 0.06,
		saturation = 0.12,
		tint = { 255, 242, 226 },
	},
	HubEvent = {
		clockTime = 18.5,
		exposure = 0.5,
		brightness = 0,
		contrast = 0.05,
		saturation = 0,
		tint = { 255, 255, 255 },
	},
	-- Giles 2026-11-06: a lighter night, as if lit by a bright moon you can't see, under
	-- lots of stars.
	Zone = {
		clockTime = 24,
		exposure = 0.6,
		brightness = 0.04,
		contrast = 0.06,
		saturation = -0.05,
		tint = { 212, 224, 255 },
	},
}

return {
	Looks = Looks,
	-- The night sky on this client: as many stars as Roblox draws, and no moon disc (the
	-- moonlight stays). Events still draw their own moons (client/Controllers/SkyController).
	StarCount = 5000,
	MoonAngularSize = 0,
	-- Seconds to go from one look to the next when nothing else says (walking out of an event).
	FadeSeconds = 6,
	-- After an event ends the server takes this long to put its own night back
	-- (WatcherService LightTween); the sun only comes up again once that's done.
	AfterEventDelay = 3,
	-- A look counts as the zone's when the player has a Zone attribute (HuntService).
	lookFor = function(inZone: boolean, eventSky: boolean): string
		if inZone then
			return "Zone"
		elseif eventSky then
			return "HubEvent"
		end
		return "Hub"
	end,
}
