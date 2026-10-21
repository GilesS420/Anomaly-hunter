--!strict
-- Music and event sounds, all played on this client only (Config/Sounds).
--
--   music      one track per area: the hub, a mansion plot, or a zone (player attribute
--              Zone). Walking from one area to another crossfades; a track that's left is
--              paused, so it picks up where it was when you come back.
--   events     the event's warning sound when the 30 second warning starts (workspace
--              attribute WatcherNext), its start sound with the banner (WatcherEvent), then
--              its ambience loops quietly and the music is turned down until it ends.
--   thunder    SkyController calls SoundController.thunder() for each lightning flash.
--
-- Also switches off the default walking sound on every character (Sounds.MutedCharacterSounds).

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local SoundController = {}

local player = Players.LocalPlayer
local random = Random.new()

local groups: { [string]: SoundGroup } = {}
local musicTracks: { [string]: Sound } = {} -- by Sounds.Files key
local playingMusic: Sound? = nil
local musicTween: { [Sound]: Tween } = {}
local ambience: Sound? = nil
local liveEvent: string? = nil

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

local function playOnce(key: string, delaySeconds: number?)
	local region = Sounds.Sheets.EventStingers[key]
	local sound = sliceSound("EventStingers", key, "Events", false)
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

local function inPlot(position: Vector3): boolean
	local halfX, halfZ = Layout.PlotSize.x / 2, Layout.PlotSize.z / 2
	for _, plot in Layout.Plots do
		if math.abs(position.X - plot.x) <= halfX and math.abs(position.Z - plot.z) <= halfZ then
			return true
		end
	end
	return false
end

local function currentArea(): Sounds.Area
	if player:GetAttribute("Zone") ~= nil then
		return "Zone"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and inPlot(root.Position) then
		return "Mansion"
	end
	return "Hub"
end

local function track(file: string): Sound?
	if musicTracks[file] then
		return musicTracks[file]
	end
	local id = fileId(file)
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = file
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = groups.Music
	sound.Parent = SoundService
	musicTracks[file] = sound
	return sound
end

local function switchMusic(area: Sounds.Area)
	local nextTrack = track(Sounds.Music[area])
	if nextTrack == playingMusic then
		return
	end
	local old = playingMusic
	if old then
		tweenVolume(old, 0, Sounds.MusicFadeSeconds, function()
			old:Pause()
		end)
	end
	playingMusic = nextTrack
	if nextTrack then
		if nextTrack.IsPaused then
			nextTrack:Resume()
		elseif not nextTrack.IsPlaying then
			nextTrack:Play()
		end
		tweenVolume(nextTrack, 1, Sounds.MusicFadeSeconds)
	end
end

-- The music group is turned down while an event is live (Sounds.Events[id].musicVolume).
local function setMusicDuck(level: number)
	local tween = TweenService:Create(
		groups.Music,
		TweenInfo.new(Sounds.AmbienceFadeSeconds, Enum.EasingStyle.Sine),
		{ Volume = Sounds.MusicVolume * level }
	)
	tween:Play()
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

	while true do
		switchMusic(currentArea())
		task.wait(0.5)
	end
end

return SoundController
