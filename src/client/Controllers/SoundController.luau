--!strict
-- Music and event sounds, all played on this client only (Config/Sounds).
--
--   music      one playlist for the whole server, the same song for everyone wherever they
--              are, timed by the server clock (Sounds.Sheets.Music, in order, then again).
--   events     the event's warning sound when the 30 second warning starts (workspace
--              attribute WatcherNext), its start sound with the banner (WatcherEvent), then
--              its ambience loops quietly and the music is turned down until it ends.
--   thunder    SkyController calls SoundController.thunder() for each lightning flash.
--
--   night      a quiet night (wind, crickets, an owl) loops under everything, and a little
--              sound fills the pause between two songs (Sounds.BetweenSongs). It follows
--              the Music volume setting.
--
-- Also switches off the default walking sound on every character (Sounds.MutedCharacterSounds).
-- The player's Music and Sound effects settings (client/Settings) scale the groups.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Settings = require(script.Parent.Parent:WaitForChild("Settings"))
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local SoundController = {}

local random = Random.new()

local groups: { [string]: SoundGroup } = {}
local musicTracks: { [string]: Sound } = {} -- by Sounds.Files key
local playingMusic: Sound? = nil
local musicTween: { [Sound]: Tween } = {}
local ambience: Sound? = nil
local liveEvent: string? = nil
local musicDuck = 1 -- how far the music is turned down for the live event
local worldDuck = 1 -- how far the night is turned down for the live event

local function group(name: string, volume: number): SoundGroup
	local made = Instance.new("SoundGroup")
	made.Name = name
	made.Volume = volume
	made.Parent = SoundService
	groups[name] = made
	return made
end

local function fileId(file: string): string
	return Sounds.assetId((Sounds.Files :: any)[file] or "")
end

-- A Sound playing one slice of a sound sheet. nil when the sheet isn't uploaded yet.
local function sliceSound(file: string, key: string, groupName: string, looped: boolean): Sound?
	local id = fileId(file)
	local region = (Sounds.Sheets :: any)[file][key]
	if id == "" or not region then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = id
	sound.SoundGroup = groups[groupName]
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = NumberRange.new(region.start, region.start + region.length)
	if looped then
		sound.Looped = true
		sound.LoopRegion = sound.PlaybackRegion
	end
	sound.TimePosition = region.start
	sound.Parent = SoundService
	return sound
end

-- One slice of a sheet, played once. Event sounds come from EventStingers by default.
local function playOnce(key: string, delaySeconds: number?, file: string?, groupName: string?)
	local sheet = file or "EventStingers"
	local region = (Sounds.Sheets :: any)[sheet][key]
	local sound = sliceSound(sheet, key, groupName or "Events", false)
	if not sound or not region then
		return
	end
	local function go()
		sound:Play()
		task.delay(region.length + 1, function()
			sound:Destroy()
		end)
	end
	if delaySeconds then
		task.delay(delaySeconds, go)
	else
		go()
	end
end

local function tweenVolume(sound: Sound, volume: number, seconds: number, after: (() -> ())?)
	local old = musicTween[sound]
	if old then
		old:Cancel()
	end
	local tween =
		TweenService:Create(sound, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Volume = volume })
	musicTween[sound] = tween
	if after then
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				after()
			end
		end)
	end
	tween:Play()
end

-- ------------------------------------------------------------------ music

-- The uploaded songs in playlist order. Every client has the same config, so every client
-- works out the same playlist.
local function playlist(): { { file: string, length: number } }
	local list = {}
	for _, song in Sounds.Sheets.Music do
		if fileId(song.file) ~= "" then
			table.insert(list, song)
		end
	end
	return list
end

-- Which song plays right now and how far into it, from the shared server clock: the
-- playlist repeats forever from time 0, with a short pause after each song, so everyone in
-- every server hears the same moment of the same song (and the song's length). In a pause:
-- nil and the number of the song that just ended.
local function nowPlaying(list: { { file: string, length: number } }): (string?, number, number)
	local cycle = 0
	for _, song in list do
		cycle += song.length + Sounds.PlaylistGapSeconds
	end
	if cycle <= 0 then
		return nil, 0, 0
	end
	local at = workspace:GetServerTimeNow() % cycle
	for index, song in list do
		if at < song.length then
			return song.file, at, song.length
		end
		at -= song.length + Sounds.PlaylistGapSeconds
		if at < 0 then
			return nil, index, 0
		end
	end
	return nil, 0, 0
end

local function track(file: string): Sound
	local existing = musicTracks[file]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = file
	sound.SoundId = fileId(file)
	sound.Volume = 0
	sound.SoundGroup = groups.Music
	sound.Parent = SoundService
	musicTracks[file] = sound
	return sound
end

local function fadeOut(sound: Sound)
	tweenVolume(sound, 0, Sounds.MusicFadeSeconds, function()
		sound:Stop()
	end)
end

local fadingOut = false -- the playing song has started its fade at the end
local resyncing = false -- the playing song is dipping out to jump back onto the clock

local function updateMusic(list: { { file: string, length: number } })
	local file, at, length = nowPlaying(list)
	local nextTrack = if file then track(file) else nil
	if nextTrack ~= playingMusic then
		if playingMusic then
			fadeOut(playingMusic)
			if not nextTrack and #Sounds.BetweenSongs > 0 then
				-- a little sound fills the pause, the same one for everyone (at is the song number);
				-- the pause is longer than any of them, so it's over before the next song starts
				playOnce(
					Sounds.BetweenSongs[(at - 1) % #Sounds.BetweenSongs + 1],
					nil,
					"WorldAmbience",
					"World"
				)
			end
			playingMusic = nil
		end
		-- a song still loading waits (this runs again every half second): started early, it
		-- would begin at the wrong spot and then have to jump
		if nextTrack and nextTrack.IsLoaded then
			playingMusic = nextTrack
			fadingOut = false
			resyncing = false
			nextTrack.TimePosition = at
			nextTrack:Play()
			-- every song builds up from silence over its first seconds (or, joining halfway,
			-- over the usual fade)
			local rest = Sounds.MusicFadeInSeconds - at
			tweenVolume(nextTrack, 1, if rest > 0.5 then rest else Sounds.MusicFadeSeconds)
		end
	elseif nextTrack and not fadingOut and length - at <= Sounds.MusicFadeOutSeconds then
		-- and dies away over its last seconds, so it's silent by the time it ends
		fadingOut = true
		tweenVolume(nextTrack, 0, math.max(length - at, 0.1))
	elseif
		nextTrack
		and not fadingOut
		and not resyncing
		and math.abs(nextTrack.TimePosition - at) > Sounds.MusicDriftSeconds
	then
		-- it fell well behind (a lag spike): dip out, jump back onto the clock, come back in,
		-- rather than skipping audibly in the middle of a note
		resyncing = true
		local song = nextTrack
		tweenVolume(song, 0, 0.4, function()
			if playingMusic == song and resyncing then
				local _, now = nowPlaying(list)
				song.TimePosition = now
				resyncing = false
				tweenVolume(song, 1, 1)
			end
		end)
	end
end

-- The quiet night under everything, so the music never starts out of silence.
local function startNight()
	local sound = sliceSound("WorldAmbience", "Night", "World", true)
	if sound then
		sound:Play()
	end
end

-- The music group is turned down while an event is live (Sounds.Events[id].musicVolume),
-- and the night with it: the event's own ambience takes over.
local function setMusicDuck(level: number)
	musicDuck = level
	worldDuck = if level < 1 then Sounds.WorldDuringEvents else 1
	local info = TweenInfo.new(Sounds.AmbienceFadeSeconds, Enum.EasingStyle.Sine)
	TweenService
		:Create(groups.Music, info, { Volume = Sounds.MusicVolume * level * Settings.volume("music") })
		:Play()
	TweenService
		:Create(groups.World, info, { Volume = Sounds.WorldVolume * worldDuck * Settings.volume("music") })
		:Play()
end

-- The player's volume settings, applied straight away.
local function applySettings()
	groups.Music.Volume = Sounds.MusicVolume * musicDuck * Settings.volume("music")
	groups.Events.Volume = Sounds.StingerVolume * Settings.volume("sounds")
	groups.Ambience.Volume = Sounds.AmbienceVolume * Settings.volume("sounds")
	groups.World.Volume = Sounds.WorldVolume * worldDuck * Settings.volume("music") -- part of the music
	groups.Monsters.Volume = Sounds.MonsterVolume * Settings.volume("sounds")
end

-- ------------------------------------------------------------------ events

local function stopAmbience()
	local old = ambience
	ambience = nil
	if old then
		tweenVolume(old, 0, Sounds.AmbienceFadeSeconds, function()
			old:Destroy()
		end)
	end
end

local function startAmbience(key: string)
	stopAmbience()
	local sound = sliceSound("EventAmbience", key, "Ambience", true)
	if not sound then
		return
	end
	sound.Volume = 0
	sound:Play()
	tweenVolume(sound, 1, Sounds.AmbienceFadeSeconds)
	ambience = sound
end

-- joined: the event was already running when this client started, so skip its start sound.
local function onEvent(id: string?, joined: boolean)
	if id == liveEvent then
		return
	end
	local wasLive = liveEvent ~= nil
	liveEvent = id
	local sounds = if id then Sounds.Events[id] else nil
	if sounds then
		if not joined then
			playOnce(sounds.start)
		end
		startAmbience(sounds.ambience)
		setMusicDuck(sounds.musicVolume)
	else
		stopAmbience()
		setMusicDuck(1)
		if wasLive and not joined then
			playOnce(Sounds.EndCue)
		end
	end
end

local function onWarning(id: string?)
	local sounds = if id then Sounds.Events[id] else nil
	if sounds then
		playOnce(sounds.warning)
	end
end

-- A thunderclap for a lightning flash, a moment later (the storm is a little way off).
function SoundController.thunder()
	local sounds = if liveEvent then Sounds.Events[liveEvent] else nil
	if sounds and sounds.thunder then
		playOnce(Sounds.ThunderCue, random:NextNumber(0.15, 1.1))
	end
end

-- ------------------------------------------------------------------ walking sound

local function muteSound(sound: Instance)
	if not sound:IsA("Sound") or not Sounds.MutedCharacterSounds[sound.Name] then
		return
	end
	sound.Volume = 0
	-- RbxCharacterSounds may set it again; keep it at 0
	sound:GetPropertyChangedSignal("Volume"):Connect(function()
		if sound.Volume ~= 0 then
			sound.Volume = 0
		end
	end)
end

local function watchCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	for _, child in root:GetChildren() do
		muteSound(child)
	end
	root.ChildAdded:Connect(muteSound)
end

-- Every player's character, not just ours: each client plays everyone's footsteps itself.
local function watchPlayer(other: Player)
	if other.Character then
		task.spawn(watchCharacter, other.Character)
	end
	other.CharacterAdded:Connect(watchCharacter)
end

-- ------------------------------------------------------------------ start

local function reportMissing()
	if not RunService:IsStudio() then
		return
	end
	local missing = {}
	for file, id in Sounds.Files do
		if id == "" then
			table.insert(missing, file)
		end
	end
	if #missing > 0 then
		table.sort(missing)
		warn(
			`[Sounds] Not uploaded yet, so silent: {table.concat(missing, ", ")}. Put their asset ids in ReplicatedStorage.Shared.Config.Sounds (src/shared/Config/Sounds.luau).`
		)
	end
end

function SoundController.start()
	group("Music", Sounds.MusicVolume)
	group("Events", Sounds.StingerVolume)
	group("Ambience", Sounds.AmbienceVolume)
	group("World", Sounds.WorldVolume)
	group("Monsters", Sounds.MonsterVolume) -- MonsterVoiceController plays into it
	applySettings()
	Settings.changed(function(key)
		if key == "music" or key == "sounds" then
			applySettings()
		end
	end)
	reportMissing()

	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	-- load the sound files in the background so the first warning isn't late
	task.spawn(function()
		local preload = {}
		for file in Sounds.Files :: { [string]: string } do
			local id = fileId(file)
			if id ~= "" then
				local sound = Instance.new("Sound")
				sound.SoundId = id
				table.insert(preload, sound)
			end
		end
		if #preload > 0 then
			ContentProvider:PreloadAsync(preload)
		end
	end)

	workspace:GetAttributeChangedSignal("WatcherNext"):Connect(function()
		onWarning(workspace:GetAttribute("WatcherNext"))
	end)
	workspace:GetAttributeChangedSignal("WatcherEvent"):Connect(function()
		onEvent(workspace:GetAttribute("WatcherEvent"), false)
	end)
	onEvent(workspace:GetAttribute("WatcherEvent"), true)

	startNight()
	local list = playlist()
	while true do
		updateMusic(list)
		task.wait(0.5)
	end
end

return SoundController
