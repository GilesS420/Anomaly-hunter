--!strict
-- Music and sound effects. Every sound is made by tools/sound/make_sounds.py (synthesized
-- from scratch, so nobody else owns it); the music is our own rendition of public-domain
-- classical pieces plus two songs of our own. Very famous melodies get rejected by Roblox's
-- audio moderation (Gymnopedie and Fur Elise were, 2026-10-21), so don't add those.
-- client/Controllers/SoundController plays it all.
--
-- Roblox can't read sound files from this repo: each of the seven files in Files has to be
-- uploaded to Roblox once (Creator Hub > Development Items > Audio), and its asset id goes
-- here. A file without an id is simply silent, and Studio's Output says which ones are missing.
--
-- The two event files and WorldAmbience are "sound sheets": one upload holds many sounds one after another,
-- and the game plays just the slice it needs (Config/SoundSheets says where each one sits).

local SoundSheets = require("./SoundSheets")

export type EventSounds = {
	warning: string, -- EventStingers slice played when the 30 second warning starts
	start: string, -- EventStingers slice played when the event starts (with the banner)
	ambience: string, -- EventAmbience slice that loops quietly while the event is live
	musicVolume: number, -- the music is turned down to this (0 to 1) while the event is live
	thunder: boolean?, -- a thunderclap follows each lightning flash (client/Controllers/SkyController)
}

local Sounds = {}

-- Asset ids, like "rbxassetid://1234567890" (or just the number). "" means not uploaded yet.
Sounds.Files = {
	EventStingers = "rbxassetid://79245545160543",
	EventAmbience = "rbxassetid://122808714791910",
	MusicWaltz = "rbxassetid://72259685212361",
	MusicMountainKing = "rbxassetid://94551444495402",
	MusicLullaby = "rbxassetid://129818520848497",
	MusicMoonlight = "rbxassetid://124222698146635",
	WorldAmbience = "rbxassetid://99157796020232",
}

-- Overall loudness of each kind of sound, 0 to 1.
Sounds.MusicVolume = 0.35
Sounds.StingerVolume = 0.8
Sounds.AmbienceVolume = 0.55
Sounds.WorldVolume = 0.6 -- the night under the music (WorldAmbience)
Sounds.WorldDuringEvents = 0.35 -- the night is turned down to this while an event is live

Sounds.MusicFadeSeconds = 2.5 -- fade out at the end of a song, or in when you join halfway
Sounds.AmbienceFadeSeconds = 3

-- The music is one playlist for the whole server: every player hears the same song at the
-- same moment, wherever they are. The order and lengths are in Config/SoundSheets (Music):
--   The Haunted Waltz (our own)
--   after Edvard Grieg, In the Hall of the Mountain King (1875)
--   The Nursery Lullaby (our own)
--   after Ludwig van Beethoven, Moonlight Sonata, first movement (1801)
-- A song that isn't uploaded yet is skipped.
Sounds.PlaylistGapSeconds = 4 -- quiet between two songs
Sounds.MusicDriftSeconds = 1.5 -- a song this far off the server clock jumps back in time

-- WorldAmbience slices played in the pause after each song, taking turns: a music box being
-- wound up, a far-off bell, creaking floorboards and an owl.
Sounds.BetweenSongs = { "WindUp", "Toll", "Creaks" }

-- The sounds of each Watcher event (Config/Events ids).
Sounds.Events = {
	FrostFog = {
		warning = "FrostFogWarning",
		start = "FrostFogStart",
		ambience = "FrostFog",
		musicVolume = 0.5,
	},
	SugarRush = {
		warning = "SugarRushWarning",
		start = "SugarRushStart",
		ambience = "SugarRush",
		musicVolume = 0.6,
	},
	GoldRush = {
		warning = "GoldRushWarning",
		start = "GoldRushStart",
		ambience = "GoldRush",
		musicVolume = 0.6,
	},
	Flicker = {
		warning = "FlickerWarning",
		start = "FlickerStart",
		ambience = "Flicker",
		musicVolume = 0.35,
		thunder = true,
	},
	BloodMoon = {
		warning = "BloodMoonWarning",
		start = "BloodMoonStart",
		ambience = "BloodMoon",
		musicVolume = 0.3,
	},
	-- The newer events borrow the closest sounds until they get their own on the sheets.
	SpiderSeason = {
		warning = "FlickerWarning",
		start = "FrostFogStart",
		ambience = "FrostFog",
		musicVolume = 0.5,
	},
	HarvestMoon = {
		warning = "BloodMoonWarning",
		start = "GoldRushStart",
		ambience = "GoldRush",
		musicVolume = 0.6,
	},
	WitchingHour = {
		warning = "WatcherAwakensWarning",
		start = "SugarRushStart",
		ambience = "BloodMoon",
		musicVolume = 0.4,
	},
	GhostMarket = {
		warning = "GoldRushWarning",
		start = "GoldRushStart",
		ambience = "SugarRush",
		musicVolume = 0.6,
	},
	BoneRattle = {
		warning = "FlickerWarning",
		start = "BloodMoonStart",
		ambience = "Flicker",
		musicVolume = 0.4,
	},
	MimicNight = {
		warning = "FlickerWarning",
		start = "BloodMoonStart",
		ambience = "Flicker",
		musicVolume = 0.4,
	},
	BreachStorm = {
		warning = "WatcherAwakensWarning",
		start = "BloodMoonStart",
		ambience = "BloodMoon",
		musicVolume = 0.3,
		thunder = true,
	},
	-- the Watcher's organ and drone take over completely
	WatcherAwakens = {
		warning = "WatcherAwakensWarning",
		start = "WatcherAwakensStart",
		ambience = "WatcherAwakens",
		musicVolume = 0,
	},
} :: { [string]: EventSounds }

Sounds.EndCue = "EventEnd" -- EventStingers slice played when an event is over
Sounds.ThunderCue = "Thunder"

-- Default character sounds (Roblox's RbxCharacterSounds script) that are switched off, by
-- the Sound's name in the character's HumanoidRootPart. Running is the walking sound; the
-- others are Climbing, Died, FreeFalling, GettingUp, Jumping, Landing, Splash, Swimming.
Sounds.MutedCharacterSounds = {
	Running = true,
} :: { [string]: boolean }

-- "1234" and "rbxassetid://1234" both become "rbxassetid://1234"; "" stays "".
function Sounds.assetId(value: string | number): string
	local text = tostring(value)
	if text == "" or string.find(text, "://", 1, true) then
		return text
	end
	return "rbxassetid://" .. text
end

Sounds.Sheets = SoundSheets

return Sounds
