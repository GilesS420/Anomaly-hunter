--!strict
-- A bright hub and dark zones (Giles 2026-11-06: the darkness may keep players away). The
-- hub and the mansion plots get a sunny late afternoon; the zones keep the foggy night
-- WorldBuilder sets up, so going on a hunt still feels like stepping into the dark. During a
-- Watcher event the hub goes back to the night too, so the event's sky change stands out.
-- Drawn on each player's screen only (client/Controllers/DaylightController); the server's
-- Lighting stays the night. Set Enabled to false to go back to night everywhere.

export type Rgb = { number }

return {
	Enabled = true,
	FadeSeconds = 1.5, -- day to night and back
	-- After an event ends the server fades its sky out over 3 s; wait that long before the
	-- day comes back so the two don't fight.
	AfterEventSeconds = 3.5,

	-- Lighting in the hub.
	Lighting = {
		ClockTime = 15.5, -- late afternoon: warm sun, long-ish shadows
		Brightness = 2.6,
		Ambient = { 128, 122, 132 } :: Rgb,
		OutdoorAmbient = { 150, 146, 158 } :: Rgb,
		ExposureCompensation = 0,
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 0.6,
	},
	-- The hub's haze: light and thin instead of the night's purple fog.
	Atmosphere = {
		Density = 0.22,
		Offset = 0.1,
		Color = { 206, 200, 214 } :: Rgb,
		Decay = { 150, 140, 170 } :: Rgb,
		Glare = 0.2,
		Haze = 0.6,
	},
	-- A touch of extra colour on top (its own ColorCorrection, only in the hub).
	Tint = {
		Brightness = 0.02,
		Contrast = 0.05,
		Saturation = 0.12,
		TintColor = { 255, 250, 240 } :: Rgb,
	},
}
