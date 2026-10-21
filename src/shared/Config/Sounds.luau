--!strict
-- Music and sound effects. Every sound is made by tools/sound/make_sounds.py (synthesized
-- from scratch, so nobody else owns it); the music is our own rendition of public-domain
-- classical pieces. client/Controllers/SoundController plays it all.
--
-- Roblox can't read sound files from this repo: each of the five files in Files has to be
-- uploaded to Roblox once (Creator Hub > Development Items > Audio), and its asset id goes
-- here. A file without an id is simply silent, and Studio's Output says which ones are missing.
--
-- The two event files are "sound sheets": one upload holds many sounds one after another,
-- and the game plays just the slice it needs (Config/SoundSheets says where each one sits).

local SoundSheets = require("./SoundSheets")

export type Area = "Hub" | "Mansion" | "Zone"

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
	EventStingers = "",
	EventAmbience = "",
	MusicHub = "",
	MusicMansion = "",
	MusicZone = "",
}

-- Overall loudness of each kind of sound, 0 to 1.
Sounds.MusicVolume = 0.35
Sounds.StingerVolume = 0.8
Sounds.AmbienceVolume = 0.55

Sounds.MusicFadeSeconds = 2.5 -- crossfade when walking from one area into another
Sounds.AmbienceFadeSeconds = 3

-- Which music plays where. A track that's left picks up where it stopped when you come back.
--   Hub      after Erik Satie, Gymnopedie No. 1 (1888)
--   Mansion  after J. S. Bach, Prelude in C major, BWV 846 (1722)
--   Zone     after Edvard Grieg, In the Hall of the Mountain King (1875)
Sounds.Music = {
	Hub = "MusicHub",
	Mansion = "MusicMansion",
	Zone = "MusicZone",
} :: { [Area]: string }

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
