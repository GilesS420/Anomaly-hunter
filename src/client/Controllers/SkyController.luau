--!strict
-- How a Watcher event looks on each player's screen (Config/Events, each event's `sky`):
--   weather   what falls or floats all around you: a snowstorm, rain, gold coins, candy or
--             eyeballs that turn to look at you; or what circles the hub: ghosts flying high
--             (Phantom Swarm) or a parade of grinning lantern heads (Nightmare Parade)
--   sky       a moon, the Watcher's eye, an aurora, sparkles, lightning
--   mist      low fog rolling round your feet
--   frame     a glow round the edges of the screen in the event's colour (only the scariest)
--   banner    the event's name across the screen when it starts
-- The server changes Lighting; everything here is drawn on this client only, around its
-- camera, so it follows you everywhere and players in zones see it too.
--
-- The server says which sky to show in Workspace attribute WatcherSky (an event id) and when
-- it should be fully in with WatcherSkyAt (server time; the end of the warning). The Watcher
-- Awakens shows its monster set's own sky (WatcherMonsterSet, Events.skyFor). The banner
-- shows when WatcherEvent is set. Pieces live in Workspace.CurrentCamera.WatcherSky.
-- Each lightning flash asks SoundController for a thunderclap.
-- The player's settings (client/Settings) can thin out or hide the weather, and switch off the
-- lightning flashes and the screen edge glow; changing one redraws the sky.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local Settings = require(script.Parent.Parent:WaitForChild("Settings"))
local SettingsUtil = require(ReplicatedStorage.Shared.Util.Settings)
local SoundController = require(script.Parent.SoundController)

local SkyController = {}

local player = Players.LocalPlayer

local Distance = 220 -- studs from the camera to a moon or the eye
local FadeOutSeconds = 3
local MinFadeInSeconds = 1
local MaxRatePerEmitter = 400 -- big particle rates are split over several emitters
local BannerSeconds = 6

type Piece = {
	part: Part,
	opaque: number, -- Transparency when fully in
	place: (piece: Piece, camera: Vector3, t: number) -> CFrame,
}

-- A falling (or floating, or circling) thing: a coin, a sweet, an eyeball, a ghost.
type Bit = {
	parts: { Part },
	offsets: { number }, -- eyes: how far each part sits towards the camera
	shape: { CFrame }, -- circling bits: each part's place in the bit (forward is -Z)
	orbit: Vector3, -- circling bits: radius, height above the hub, turn speed (radians/s)
	opaque: number,
	position: Vector3,
	velocity: Vector3,
	spin: Vector3, -- radians per second round each axis
	angle: Vector3,
	phase: number,
}

-- How a kind of bit moves:
--   fall    from the sky past you (coins, candy, leaves)
--   float   hovering round you (eyes)
--   circle  round the hub (ghosts, lanterns, witches, rifts)
--   rise    up from the ground into the sky (paper lanterns)
--   hang    dangling round you on a thread (spiders)
--   ground  pushing up out of the ground round you and sinking back (skeleton hands, crates)
type Mode = "fall" | "float" | "circle" | "rise" | "hang" | "ground"

type Weather = {
	kind: string,
	bits: { Bit },
	mode: Mode,
	centre: Vector3, -- circle: the middle of Watcher Square
}

local Modes: { [string]: Mode } = {
	Eyes = "float",
	Ghosts = "circle",
	Lanterns = "circle",
	Brooms = "circle",
	SkyLanterns = "rise",
	Spiders = "hang",
	Hands = "ground",
	Crates = "ground",
	Rifts = "circle",
}

type Set = {
	id: string,
	pieces: { Piece },
	emitters: { { emitter: ParticleEmitter, rate: number } },
	weather: Weather?,
	edge: CanvasGroup?,
	holder: Folder,
	alpha: number, -- 0 hidden, 1 fully in
	target: number,
	speed: number, -- alpha per second
	flashes: boolean,
}

local sets: { Set } = {}
local flashToken = 0
local screen: ScreenGui? = nil
local random = Random.new()

local function rgb(color: Events.Rgb): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- A direction in the sky: `turn` degrees around from north, `up` degrees above the horizon.
local function direction(turn: number, up: number): Vector3
	local yaw, pitch = math.rad(turn), math.rad(up)
	return Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
end

local function piecePart(
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	color: Color3,
	holder: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = holder
	return part
end

local function screenGui(): ScreenGui
	local existing = screen
	if existing and existing.Parent then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "WatcherSkyUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5 -- under the HUD and toasts
	gui.Parent = player:WaitForChild("PlayerGui")
	screen = gui
	return gui
end

------------------------------------------------------------------------------------------
-- Sky pieces

local function addMoon(set: Set, moon: { color: Events.Rgb, size: number, coin: boolean? })
	local at = direction(35, 30) * Distance
	if moon.coin then
		-- A flat gold coin with a darker rim, turned to face the camera.
		local rim = piecePart(
			"CoinRim",
			Enum.PartType.Cylinder,
			Vector3.new(1, moon.size * 1.08, moon.size * 1.08),
			rgb(moon.color):Lerp(Color3.new(0, 0, 0), 0.35),
			set.holder
		)
		local face = piecePart(
			"Coin",
			Enum.PartType.Cylinder,
			Vector3.new(1.2, moon.size, moon.size),
			rgb(moon.color),
			set.holder
		)
		for index, part in { rim, face } do
			table.insert(set.pieces, {
				part = part,
				opaque = 0,
				place = function(_piece, camera, t)
					local position = camera + at + (if index == 2 then -at.Unit * 0.5 else Vector3.zero)
					-- Turns slowly, like a coin on a string.
					return CFrame.lookAt(position, camera)
						* CFrame.Angles(0, math.rad(90 + math.sin(t * 0.5) * 25), 0)
				end,
			})
		end
	else
		local part =
			piecePart("Moon", Enum.PartType.Ball, Vector3.one * moon.size, rgb(moon.color), set.holder)
		table.insert(set.pieces, {
			part = part,
			opaque = 0,
			place = function(_piece, camera)
				return CFrame.new(camera + at)
			end,
		})
	end
end

-- The Watcher's giant eye, high in the north, with its iris wandering as if it looks around.
local function addEye(set: Set)
	local at = direction(0, 32) * Distance
	local size = 150
	local white = piecePart(
		"EyeWhite",
		Enum.PartType.Ball,
		Vector3.one * size,
		Color3.fromRGB(205, 195, 175),
		set.holder
	)
	white.Material = Enum.Material.SmoothPlastic
	local iris = piecePart(
		"Iris",
		Enum.PartType.Ball,
		Vector3.one * size * 0.5,
		Color3.fromRGB(170, 70, 255),
		set.holder
	)
	local pupil = piecePart(
		"Pupil",
		Enum.PartType.Ball,
		Vector3.one * size * 0.22,
		Color3.fromRGB(10, 5, 15),
		set.holder
	)
	pupil.Material = Enum.Material.SmoothPlastic

	local function gaze(t: number): Vector3
		local toCamera = (-at).Unit
		local side = toCamera:Cross(Vector3.yAxis).Unit
		local wander = side * math.sin(t * 0.4) * 0.35 + Vector3.yAxis * math.sin(t * 0.27 + 1) * 0.2
		return (toCamera + wander).Unit
	end
	local layers: { { part: Part, out: number } } =
		{ { part = white, out = 0 }, { part = iris, out = 0.3 }, { part = pupil, out = 0.42 } }
	for _, layer in layers do
		local out = layer.out
		table.insert(set.pieces, {
			part = layer.part,
			opaque = 0,
			place = function(_piece, camera, t)
				return CFrame.new(camera + at + gaze(t) * size * out)
			end,
		})
	end
end

-- A curtain of light low in the northern sky: two rows of thin upright strips side by side,
-- each a bright foot with a fainter top, rippling as waves run along it.
local AuroraStrips = 40
local AuroraSpread = 130 -- degrees of sky the curtain covers
local function addAurora(set: Set, color: Events.Rgb)
	local base = rgb(color)
	local top = base:Lerp(Color3.fromRGB(200, 120, 255), 0.45)
	for row = 1, 2 do
		local far = Distance + (row - 1) * 40
		local width = math.rad(AuroraSpread / AuroraStrips) * far * 1.02 -- edge to edge, no gaps
		local lift = (row - 1) * 6
		for index = 1, AuroraStrips do
			local turn = -AuroraSpread / 2 + (index - 0.5) * AuroraSpread / AuroraStrips + (row - 1) * 8
			-- The foot of the strip, waving up and down as ripples run along the curtain.
			local function foot(camera: Vector3, t: number): Vector3
				local wave = math.sin(index * 0.33 + t * 0.35 + row) * 4
					+ math.sin(index * 0.11 - t * 0.2) * 3
				return camera + direction(turn, 16 + lift + wave) * far
			end
			local function stretch(t: number): number
				return 45 + math.sin(index * 0.5 + t * 0.6 + row * 2) * 20
			end
			for layer = 1, 2 do
				local part = piecePart(
					`Aurora{row}_{index}_{layer}`,
					Enum.PartType.Block,
					Vector3.new(width, 1, 0.5),
					if layer == 1 then base else top,
					set.holder
				)
				table.insert(set.pieces, {
					part = part,
					opaque = if layer == 1 then 0.55 + row * 0.08 else 0.78 + row * 0.06,
					place = function(_piece, camera, t)
						local height = stretch(t)
						local low = if layer == 1 then 0 else height * 0.35
						local tall = if layer == 1 then height * 0.35 else height * 0.65
						part.Size = Vector3.new(width, tall, 0.5)
						local at = foot(camera, t)
						local facing = Vector3.new(camera.X, at.Y, camera.Z)
						return CFrame.lookAt(at, facing) * CFrame.new(0, low + tall / 2, 0)
					end,
				})
			end
		end
	end
end

-- A flat invisible cloud above the player that particles fall out of.
local function cloud(set: Set, name: string, width: number, height: number): Part
	local part =
		piecePart(name, Enum.PartType.Block, Vector3.new(width, 1, width), Color3.new(1, 1, 1), set.holder)
	table.insert(set.pieces, {
		part = part,
		opaque = 1, -- the cloud itself stays invisible
		place = function(_piece, camera)
			return CFrame.new(camera + Vector3.new(0, height, 0))
		end,
	})
	return part
end

-- Particles out of a cloud; `setup` sets everything but the rate, which is split over enough
-- emitters to reach `rate`.
local function emit(set: Set, part: Part, rate: number, setup: (ParticleEmitter) -> ())
	local left = rate
	while left > 0 do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.LightEmission = 1
		setup(emitter)
		emitter.Rate = 0
		emitter.Parent = part
		table.insert(set.emitters, { emitter = emitter, rate = math.min(left, MaxRatePerEmitter) })
		left -= MaxRatePerEmitter
	end
end

local function addSparkles(set: Set, color: Events.Rgb)
	emit(set, cloud(set, "Sparkles", 160, 40), 60, function(emitter)
		emitter.Color = ColorSequence.new(rgb(color))
		emitter.Lifetime = NumberRange.new(6, 9)
		emitter.Speed = NumberRange.new(5, 9)
		emitter.SpreadAngle = Vector2.new(15, 15)
		emitter.Size = NumberSequence.new(0.35)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.2),
			NumberSequenceKeypoint.new(0.85, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
	end)
end

-- The floor under the player: a ray straight down, so jumping doesn't lift the mist, the hands
-- or the spiders with you. Mid-air with no floor in reach it keeps the last one found.
local GroundRay = 60
local lastGround: number? = nil
local function groundY(camera: Vector3): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return lastGround or camera.Y - 8
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance, workspace.CurrentCamera }
	params.IgnoreWater = true
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -GroundRay, 0), params)
	if hit then
		lastGround = hit.Position.Y
	end
	return lastGround or root.Position.Y - 3
end

-- Low fog rolling over the ground round the player's feet.
local MistTexture = "rbxasset://textures/particles/smoke_main.dds"
local function addMist(set: Set, color: Events.Rgb)
	local part =
		piecePart("Mist", Enum.PartType.Block, Vector3.new(140, 2, 140), Color3.new(1, 1, 1), set.holder)
	table.insert(set.pieces, {
		part = part,
		opaque = 1,
		place = function(_piece, camera)
			return CFrame.new(camera.X, groundY(camera), camera.Z)
		end,
	})
	emit(set, part, 45, function(emitter)
		emitter.Texture = MistTexture
		emitter.Color = ColorSequence.new(rgb(color))
		emitter.LightEmission = 0.15
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Lifetime = NumberRange.new(8, 12)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.Acceleration = Vector3.new(1.5, 0, 0.5)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-8, 8)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 10),
			NumberSequenceKeypoint.new(1, 18),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.75),
			NumberSequenceKeypoint.new(0.7, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		})
	end)
end

------------------------------------------------------------------------------------------
-- Weather

local function addSnow(set: Set)
	-- A wide storm of flakes blowing sideways, and big close flakes whipping past the camera.
	local function flakes(emitter: ParticleEmitter, size: number, wind: Vector3, speed: number)
		emitter.Color = ColorSequence.new(Color3.fromRGB(240, 248, 255))
		emitter.LightEmission = 0.3
		emitter.Lifetime = NumberRange.new(3, 4.5)
		emitter.Speed = NumberRange.new(speed, speed * 1.4)
		emitter.SpreadAngle = Vector2.new(20, 20)
		emitter.Acceleration = wind
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size, size * 0.4),
			NumberSequenceKeypoint.new(1, size, size * 0.4),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0.1),
			NumberSequenceKeypoint.new(0.85, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-120, 120)
	end
	emit(set, cloud(set, "SnowStorm", 200, 45), 1600, function(emitter)
		flakes(emitter, 0.45, Vector3.new(16, 0, 6), 18)
	end)
	emit(set, cloud(set, "SnowGusts", 70, 18), 400, function(emitter)
		flakes(emitter, 1.1, Vector3.new(35, 0, 12), 22)
	end)
end

local function addRain(set: Set, color: Events.Rgb)
	emit(set, cloud(set, "Rain", 170, 55), 1600, function(emitter)
		emitter.Color = ColorSequence.new(rgb(color))
		emitter.LightEmission = 0.5
		emitter.Lifetime = NumberRange.new(0.8, 1)
		emitter.Speed = NumberRange.new(80, 95)
		emitter.SpreadAngle = Vector2.new(3, 3)
		emitter.Acceleration = Vector3.new(6, 0, 2)
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Size = NumberSequence.new(0.14)
		emitter.Squash = NumberSequence.new(3)
		emitter.Transparency = NumberSequence.new(0.25)
	end)
end

local CandyColors = {
	{ 255, 120, 190 },
	{ 120, 220, 255 },
	{ 255, 235, 110 },
	{ 150, 255, 120 },
	{ 255, 255, 255 },
	{ 190, 140, 255 },
}

-- Somewhere in a ring round the camera, `above` studs up.
local function spot(camera: Vector3, radius: number, above: number): Vector3
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(random:NextNumber()) * radius
	return camera + Vector3.new(math.cos(angle) * distance, above, math.sin(angle) * distance)
end

-- The middle of Watcher Square (the meter's pillar), on the ground; ghosts and lanterns
-- circle it.
local function hubCentre(): Vector3
	local hub = workspace:FindFirstChild("Hub")
	local meter = hub and hub:FindFirstChild("WatcherMeter", true)
	if meter and meter:IsA("BasePart") then
		return meter.Position - Vector3.new(0, meter.Size.Y / 2, 0)
	end
	return Vector3.zero
end

local LeafColors = { { 220, 110, 30 }, { 190, 60, 25 }, { 240, 170, 40 }, { 130, 80, 35 } }
local Bone = Color3.fromRGB(235, 228, 205)

local function addBits(set: Set, kind: string, count: number)
	local mode: Mode = Modes[kind] or "fall"
	local weather: Weather = {
		kind = kind,
		bits = {},
		mode = mode,
		centre = if mode == "circle" then hubCentre() else Vector3.zero,
	}
	for index = 1, count do
		local parts: { Part } = {}
		local offsets: { number } = {}
		local layout: { CFrame } = {}
		local orbit = Vector3.zero
		local opaque = 0
		local fall = 0
		-- A part of a many-part bit, placed at `at` in the bit (forward is -Z).
		local function add(
			name: string,
			shape: Enum.PartType,
			size: Vector3,
			color: Color3,
			at: CFrame,
			matte: boolean?
		)
			local part = piecePart(`{name}{index}`, shape, size, color, set.holder)
			if matte then
				part.Material = Enum.Material.SmoothPlastic
			end
			table.insert(parts, part)
			table.insert(layout, at)
		end
		if kind == "Brooms" then
			-- A witch on a broomstick: stick, straw bristles, a dark body, a green face and a
			-- pointy hat, flying in wide circles high over the hub.
			local black = Color3.fromRGB(25, 15, 35)
			add(
				"Broom",
				Enum.PartType.Block,
				Vector3.new(0.3, 0.3, 6),
				Color3.fromRGB(110, 70, 35),
				CFrame.identity,
				true
			)
			add(
				"Bristles",
				Enum.PartType.Block,
				Vector3.new(1.3, 1.3, 1.8),
				Color3.fromRGB(210, 170, 80),
				CFrame.new(0, 0, 3.6),
				true
			)
			add("Witch", Enum.PartType.Block, Vector3.new(1.4, 2, 1), black, CFrame.new(0, 1.1, 0.6), true)
			add(
				"Face",
				Enum.PartType.Ball,
				Vector3.one * 1.1,
				Color3.fromRGB(120, 255, 120),
				CFrame.new(0, 2.6, 0.4)
			)
			add(
				"HatBrim",
				Enum.PartType.Cylinder,
				Vector3.new(0.15, 2.4, 2.4),
				black,
				CFrame.new(0, 3.1, 0.4) * CFrame.Angles(0, 0, math.rad(90)),
				true
			)
			add(
				"Hat",
				Enum.PartType.Block,
				Vector3.new(0.9, 1.8, 0.9),
				black,
				CFrame.new(0, 4, 0.6) * CFrame.Angles(math.rad(15), 0, 0),
				true
			)
			orbit = Vector3.new(
				random:NextNumber(60, 140),
				random:NextNumber(40, 70),
				random:NextNumber(0.25, 0.45)
			)
		elseif kind == "Spiders" then
			-- A hairy brown-black spider: a fat abdomen with a red hourglass on its back, a
			-- smaller head with glinting red eyes and fangs, and eight bent legs (up to the knee,
			-- then down), hanging on a fine silk thread.
			local body = Color3.fromRGB(35, 25, 22)
			local leg = Color3.fromRGB(25, 18, 16)
			add(
				"Abdomen",
				Enum.PartType.Ball,
				Vector3.new(1.3, 1.1, 1.6),
				body,
				CFrame.new(0, 0.1, 0.55),
				true
			)
			add(
				"Hourglass",
				Enum.PartType.Block,
				Vector3.new(0.3, 0.06, 0.5),
				Color3.fromRGB(200, 25, 25),
				CFrame.new(0, 0.66, 0.55),
				true
			)
			add(
				"SpiderHead",
				Enum.PartType.Ball,
				Vector3.new(0.8, 0.7, 0.8),
				body,
				CFrame.new(0, 0, -0.45),
				true
			)
			for side = -1, 1, 2 do
				add(
					"SpiderEye",
					Enum.PartType.Ball,
					Vector3.one * 0.14,
					Color3.fromRGB(255, 40, 40),
					CFrame.new(side * 0.14, 0.15, -0.8)
				)
				add(
					"Fang",
					Enum.PartType.Block,
					Vector3.new(0.08, 0.25, 0.08),
					Color3.fromRGB(60, 45, 40),
					CFrame.new(side * 0.1, -0.2, -0.82),
					true
				)
				for index, spread in { -0.55, -0.2, 0.2, 0.55 } do
					local yaw = CFrame.Angles(0, spread * side, 0) * CFrame.new(0, 0, -0.35 + index * 0.08)
					add(
						"SpiderThigh",
						Enum.PartType.Block,
						Vector3.new(1.08, 0.1, 0.1),
						leg,
						yaw * CFrame.new(side * 0.75, 0.3, 0) * CFrame.Angles(0, 0, side * math.rad(33.7)),
						true
					)
					add(
						"SpiderShin",
						Enum.PartType.Block,
						Vector3.new(1.26, 0.08, 0.08),
						leg,
						yaw * CFrame.new(side * 1.4, 0, 0) * CFrame.Angles(0, 0, side * math.rad(-71.6)),
						true
					)
				end
			end
			-- Fine, matte silk: no glowing beam.
			add(
				"Thread",
				Enum.PartType.Block,
				Vector3.new(0.03, 30, 0.03),
				Color3.fromRGB(200, 200, 205),
				CFrame.new(0, 15.6, 0.3),
				true
			)
		elseif kind == "Hands" then
			-- A bony hand: palm, four fingers and a thumb, reaching up out of the ground.
			add("Palm", Enum.PartType.Block, Vector3.new(1.6, 1.9, 0.5), Bone, CFrame.identity, true)
			for finger, x in { -0.6, -0.2, 0.2, 0.6 } do
				local tall = if finger == 1 or finger == 4 then 1.2 else 1.5
				add(
					"Finger",
					Enum.PartType.Block,
					Vector3.new(0.3, tall, 0.3),
					Bone,
					CFrame.new(x, 0.95 + tall / 2, 0),
					true
				)
			end
			add(
				"Thumb",
				Enum.PartType.Block,
				Vector3.new(0.3, 1.1, 0.3),
				Bone,
				CFrame.new(1, 0.3, 0) * CFrame.Angles(0, 0, math.rad(-45)),
				true
			)
		elseif kind == "Crates" then
			-- A little crate with a gaping row of teeth and two yellow eyes, rising out of the
			-- ground round you to have a look, then sinking back.
			local wood = Color3.fromRGB(150, 105, 60)
			add("Crate", Enum.PartType.Block, Vector3.new(2, 1.6, 1.8), wood, CFrame.identity, true)
			add(
				"CrateMouth",
				Enum.PartType.Block,
				Vector3.new(1.6, 0.35, 0.1),
				Color3.fromRGB(15, 10, 10),
				CFrame.new(0, 0.2, -0.92),
				true
			)
			for tooth = -2, 2 do
				add(
					"CrateTooth",
					Enum.PartType.Block,
					Vector3.new(0.16, 0.2, 0.08),
					Color3.fromRGB(245, 245, 255),
					CFrame.new(tooth * 0.3, 0.32, -0.96),
					true
				)
			end
			for side = -1, 1, 2 do
				add(
					"CrateEye",
					Enum.PartType.Block,
					Vector3.new(0.35, 0.25, 0.08),
					Color3.fromRGB(255, 220, 80),
					CFrame.new(side * 0.5, 0.6, -0.92)
				)
			end
		elseif kind == "Rifts" then
			-- A rift torn in the sky: a dark hole ringed with blue-white light, drifting slowly
			-- round high over the hub and always facing its middle.
			add(
				"RiftRing",
				Enum.PartType.Cylinder,
				Vector3.new(0.3, 26, 16),
				Color3.fromRGB(150, 180, 255),
				CFrame.identity
			)
			add(
				"RiftHole",
				Enum.PartType.Cylinder,
				Vector3.new(0.5, 22, 12),
				Color3.fromRGB(10, 8, 30),
				CFrame.identity,
				true
			)
			add(
				"RiftSpark",
				Enum.PartType.Cylinder,
				Vector3.new(0.6, 4, 4),
				Color3.fromRGB(235, 240, 255),
				CFrame.identity
			)
			orbit = Vector3.new(
				random:NextNumber(40, 150),
				random:NextNumber(55, 95),
				random:NextNumber(0.02, 0.05) * (if random:NextNumber() < 0.5 then 1 else -1)
			)
		elseif kind == "SkyLanterns" then
			-- A glowing paper lantern drifting up into the sky.
			add(
				"SkyLantern",
				Enum.PartType.Block,
				Vector3.new(1.3, 1.7, 1.3),
				Color3.fromRGB(255, 170, 70),
				CFrame.identity
			)
			opaque = 0.1
			fall = -random:NextNumber(3, 6) -- rises
		elseif kind == "Leaves" then
			local color = rgb(LeafColors[random:NextInteger(1, #LeafColors)])
			add("Leaf", Enum.PartType.Block, Vector3.new(1.2, 0.08, 0.9), color, CFrame.identity, true)
			fall = random:NextNumber(5, 9)
		elseif kind == "Ghosts" then
			-- A glowing head with two black eyes and a tail of shrinking puffs, flying in
			-- circles high over the hub, some near and some far, at different speeds.
			local pale = Color3.fromRGB(225, 240, 255)
			table.insert(
				parts,
				piecePart(`Ghost{index}`, Enum.PartType.Ball, Vector3.one * 4, pale, set.holder)
			)
			table.insert(layout, CFrame.identity)
			for side = -1, 1, 2 do
				local eye = piecePart(
					`GhostEye{index}`,
					Enum.PartType.Ball,
					Vector3.new(0.8, 1.2, 0.8),
					Color3.fromRGB(10, 10, 20),
					set.holder
				)
				eye.Material = Enum.Material.SmoothPlastic
				table.insert(parts, eye)
				table.insert(layout, CFrame.new(side * 0.75, 0.4, -1.75))
			end
			for puff, size in { 3.2, 2.4, 1.6 } do
				table.insert(
					parts,
					piecePart(`GhostTail{index}`, Enum.PartType.Ball, Vector3.one * size, pale, set.holder)
				)
				table.insert(layout, CFrame.new(0, -0.35 * puff, 1.9 * puff))
			end
			opaque = 0.2
			orbit = Vector3.new(
				random:NextNumber(35, 120),
				random:NextNumber(22, 55),
				random:NextNumber(0.18, 0.4) * (if random:NextNumber() < 0.8 then 1 else -1)
			)
		elseif kind == "Lanterns" then
			-- A grinning orange head with black eyes and mouth, all of them in one long
			-- procession round the hub, bobbing as they march.
			table.insert(
				parts,
				piecePart(
					`Lantern{index}`,
					Enum.PartType.Ball,
					Vector3.one * 3.6,
					Color3.fromRGB(255, 130, 30),
					set.holder
				)
			)
			table.insert(layout, CFrame.identity)
			local features: { { size: Vector3, at: CFrame } } = {
				{
					size = Vector3.new(0.7, 0.9, 0.5),
					at = CFrame.new(-0.75, 0.5, -1.55) * CFrame.Angles(0, 0, 0.4),
				},
				{
					size = Vector3.new(0.7, 0.9, 0.5),
					at = CFrame.new(0.75, 0.5, -1.55) * CFrame.Angles(0, 0, -0.4),
				},
				{ size = Vector3.new(2, 0.45, 0.5), at = CFrame.new(0, -0.6, -1.5) },
			}
			for _, feature in features do
				local part = piecePart(
					`LanternFace{index}`,
					Enum.PartType.Block,
					feature.size,
					Color3.fromRGB(20, 5, 0),
					set.holder
				)
				part.Material = Enum.Material.SmoothPlastic
				table.insert(parts, part)
				table.insert(layout, feature.at)
			end
			orbit = Vector3.new(random:NextNumber(62, 72), random:NextNumber(7, 11), 0.12)
		elseif kind == "Coins" then
			local coin = piecePart(
				`Coin{index}`,
				Enum.PartType.Cylinder,
				Vector3.new(0.25, 1.6, 1.6),
				Color3.fromRGB(255, 200, 40),
				set.holder
			)
			table.insert(parts, coin)
			fall = random:NextNumber(18, 26)
		elseif kind == "Candy" then
			local color = rgb(CandyColors[random:NextInteger(1, #CandyColors)])
			local shape = random:NextInteger(1, 3)
			local candy = if shape == 1
				then piecePart(`Candy{index}`, Enum.PartType.Ball, Vector3.one * 0.9, color, set.holder)
				elseif shape == 2 then piecePart(
					`Candy{index}`,
					Enum.PartType.Block,
					Vector3.new(0.25, 0.25, 1),
					color,
					set.holder
				)
				else piecePart(
					`Candy{index}`,
					Enum.PartType.Cylinder,
					Vector3.new(0.3, 1.2, 1.2),
					color,
					set.holder
				)
			table.insert(parts, candy)
			fall = random:NextNumber(12, 18)
		else -- Eyes
			local white = piecePart(
				`EyeWhite{index}`,
				Enum.PartType.Ball,
				Vector3.one * 2.4,
				Color3.fromRGB(225, 215, 195),
				set.holder
			)
			white.Material = Enum.Material.SmoothPlastic
			local iris = piecePart(
				`EyeIris{index}`,
				Enum.PartType.Ball,
				Vector3.one * 1.3,
				Color3.fromRGB(170, 70, 255),
				set.holder
			)
			local pupil = piecePart(
				`EyePupil{index}`,
				Enum.PartType.Ball,
				Vector3.one * 0.6,
				Color3.fromRGB(10, 5, 15),
				set.holder
			)
			pupil.Material = Enum.Material.SmoothPlastic
			parts = { white, iris, pupil }
			offsets = { 0, 0.6, 0.95 }
		end
		table.insert(weather.bits, {
			parts = parts,
			offsets = offsets,
			shape = layout,
			orbit = orbit,
			opaque = opaque,
			position = Vector3.zero, -- placed on the first frame
			velocity = Vector3.new(random:NextNumber(-3, 3), -fall, random:NextNumber(-3, 3)),
			spin = Vector3.new(random:NextNumber(-4, 4), random:NextNumber(-4, 4), random:NextNumber(-4, 4)),
			angle = Vector3.new(random:NextNumber(0, 6), random:NextNumber(0, 6), random:NextNumber(0, 6)),
			-- Circling: where on the circle it starts; the parade is evenly spaced.
			phase = if kind == "Lanterns" then index / count * math.pi * 2 else random:NextNumber(0, 10),
		})
	end
	set.weather = weather
end

-- `scale` is the Event weather setting (1 full, less than 1 thinned out).
local function addWeather(set: Set, weather: Events.Weather, scale: number)
	local function bits(kind: string, count: number)
		addBits(set, kind, math.max(math.floor(count * scale), 1))
	end
	local before = #set.emitters
	if weather.kind == "Snow" then
		addSnow(set)
	elseif weather.kind == "Rain" then
		addRain(set, weather.color or { 170, 180, 210 })
	elseif weather.kind == "Coins" then
		bits("Coins", 150)
		addSparkles(set, { 255, 215, 110 })
	elseif weather.kind == "Candy" then
		bits("Candy", 140)
	elseif weather.kind == "Eyes" then
		bits("Eyes", 28)
	elseif weather.kind == "Ghosts" then
		bits("Ghosts", 22)
		addSparkles(set, { 200, 230, 255 })
	elseif weather.kind == "Lanterns" then
		bits("Lanterns", 26)
	elseif weather.kind == "Brooms" then
		bits("Brooms", 7)
	elseif weather.kind == "Spiders" then
		bits("Spiders", 45)
	elseif weather.kind == "Hands" then
		bits("Hands", 24)
	elseif weather.kind == "SkyLanterns" then
		bits("SkyLanterns", 70)
	elseif weather.kind == "Leaves" then
		bits("Leaves", 120)
	elseif weather.kind == "Crates" then
		bits("Crates", 14)
	elseif weather.kind == "Rifts" then
		bits("Rifts", 9)
		addSparkles(set, { 170, 200, 255 })
	end
	for index = before + 1, #set.emitters do
		set.emitters[index].rate *= scale
	end
end

local FallRadius = 90 -- coins and candy fall within this many studs of the camera
local FloatRadius = 60
local NearRadius = 40 -- skeleton hands and crates
local HangRadius = 90 -- spiders, spread wide and mostly overhead

-- Moves the coins, candy or eyes along. A bit that has fallen past the camera (or that the
-- camera has walked away from) starts again above it.
local function stepWeather(weather: Weather, camera: Vector3, deltaTime: number, t: number, alpha: number)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	local ground = groundY(camera)
	local function place(bit: Bit, frame: CFrame)
		for index, part in bit.parts do
			table.insert(parts, part)
			table.insert(frames, frame * bit.shape[index])
		end
	end
	for _, bit in weather.bits do
		local flat = Vector3.new(bit.position.X - camera.X, 0, bit.position.Z - camera.Z)
		local mode = weather.mode
		if mode == "hang" or mode == "ground" then
			local radius = if mode == "hang" then HangRadius else NearRadius
			if bit.position == Vector3.zero or flat.Magnitude > radius * 1.3 then
				bit.position = spot(camera, radius, 0)
			end
			if mode == "hang" then
				-- Swinging gently up and down on its thread, turning slowly.
				local height = ground + 10 + (bit.phase % 1) * 18 + math.sin(t * 0.6 + bit.phase) * 2.5
				local at = Vector3.new(bit.position.X, height, bit.position.Z)
				place(bit, CFrame.new(at) * CFrame.Angles(0, bit.phase + t * 0.3, 0))
			else
				-- Out of the ground, a wave of the fingers, and back down again.
				local up = math.max(0, math.sin(t * 0.5 + bit.phase))
				local at = Vector3.new(bit.position.X, ground - 2.6 + up * 2.8, bit.position.Z)
				local facing = Vector3.new(camera.X, at.Y, camera.Z)
				local frame = if (facing - at).Magnitude > 0.1
					then CFrame.lookAt(at, facing)
					else CFrame.new(at)
				place(bit, frame * CFrame.Angles(0, 0, math.sin(t * 2 + bit.phase) * 0.2))
			end
		elseif mode == "rise" then
			if
				bit.position == Vector3.zero
				or bit.position.Y > camera.Y + 90
				or flat.Magnitude > FallRadius * 1.3
			then
				-- The first time, spread them over the whole height so they don't arrive as one wave.
				local above = if bit.position == Vector3.zero then random:NextNumber(0, 90) else 0
				bit.position = Vector3.new(0, ground + above - camera.Y, 0) + spot(camera, FallRadius, 0)
			end
			bit.position += bit.velocity * deltaTime
			local sway = math.sin(t * 0.7 + bit.phase) * 0.15
			place(bit, CFrame.new(bit.position) * CFrame.Angles(sway, bit.phase, -sway))
		elseif mode == "circle" then
			local turn = bit.phase + t * bit.orbit.Z
			local ahead = Vector3.new(-math.sin(turn), 0, math.cos(turn)) * math.sign(bit.orbit.Z)
			local bob = if weather.kind == "Lanterns"
				then math.abs(math.sin(t * 3 + bit.phase * 4)) * 1.2 -- marching steps
				else math.sin(t * 0.9 + bit.phase) * 3
			local at = weather.centre
				+ Vector3.new(math.cos(turn) * bit.orbit.X, bit.orbit.Y + bob, math.sin(turn) * bit.orbit.X)
			-- Ghosts look where they fly; lanterns grin at you as they pass.
			local frame = if weather.kind == "Lanterns"
				then CFrame.lookAt(at, Vector3.new(camera.X, at.Y, camera.Z))
				else CFrame.lookAt(at, at + ahead)
			for index, part in bit.parts do
				table.insert(parts, part)
				table.insert(frames, frame * bit.shape[index])
			end
		elseif mode == "float" then
			if bit.position == Vector3.zero or flat.Magnitude > FloatRadius * 1.3 then
				bit.position = spot(camera, FloatRadius, random:NextNumber(4, 30))
			end
			local bob = Vector3.new(0, math.sin(t * 0.8 + bit.phase) * 1.5, 0)
			local at = bit.position + bob
			local look = (camera - at).Unit
			for index, part in bit.parts do
				table.insert(parts, part)
				table.insert(frames, CFrame.new(at + look * bit.offsets[index]))
			end
		else
			if
				bit.position == Vector3.zero
				or bit.position.Y < camera.Y - 25
				or flat.Magnitude > FallRadius * 1.3
			then
				-- The first time, spread them over the whole height so they don't arrive as one wave.
				local above = if bit.position == Vector3.zero
					then random:NextNumber(-20, 70)
					else random:NextNumber(40, 70)
				bit.position = spot(camera, FallRadius, above)
			end
			bit.position += bit.velocity * deltaTime
			bit.angle += bit.spin * deltaTime
			local position = bit.position
			if weather.kind == "Leaves" then
				-- Leaves see-saw from side to side as they drift down.
				position += Vector3.new(
					math.sin(t * 1.3 + bit.phase) * 2,
					0,
					math.cos(t * 1.1 + bit.phase) * 1.5
				)
			end
			table.insert(parts, bit.parts[1])
			table.insert(frames, CFrame.new(position) * CFrame.Angles(bit.angle.X, bit.angle.Y, bit.angle.Z))
		end
		for _, part in bit.parts do
			part.Transparency = 1 - alpha * (1 - bit.opaque)
		end
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

------------------------------------------------------------------------------------------
-- Screen: the edge glow, lightning and the banner

local function addEdge(set: Set, color: Events.Rgb)
	local group = Instance.new("CanvasGroup")
	group.Name = `{set.id}Edge`
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	-- Four strips, each fading from the screen's edge towards the middle.
	local strips: { { at: UDim2, size: UDim2, rotation: number } } = {
		{ at = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 0.22), rotation = 90 },
		{ at = UDim2.fromScale(0, 0.78), size = UDim2.fromScale(1, 0.22), rotation = -90 },
		{ at = UDim2.fromScale(0, 0), size = UDim2.fromScale(0.16, 1), rotation = 0 },
		{ at = UDim2.fromScale(0.84, 0), size = UDim2.fromScale(0.16, 1), rotation = 180 },
	}
	for _, strip in strips do
		local frame = Instance.new("Frame")
		frame.Position = strip.at
		frame.Size = strip.size
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = rgb(color)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = strip.rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		frame.Parent = group
	end
	group.Parent = screenGui()
	set.edge = group
end

-- A jagged bolt of lightning somewhere in the distance, gone again in a blink.
local function strike(set: Set)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position
	local turn = random:NextNumber(0, 360)
	local top = origin + direction(turn, 35) * 260
	local bottom = origin + direction(turn + random:NextNumber(-6, 6), 2) * 260
	local bolt = Instance.new("Folder")
	bolt.Name = "Lightning"
	local from = top
	local segments = 8
	for index = 1, segments do
		local along = top:Lerp(bottom, index / segments)
		local to = if index == segments
			then along
			else along + Vector3.new(random:NextNumber(-14, 14), 0, random:NextNumber(-14, 14))
		local length = (to - from).Magnitude
		local part = piecePart(
			`Bolt{index}`,
			Enum.PartType.Block,
			Vector3.new(1.6, 1.6, length),
			Color3.fromRGB(225, 230, 255),
			bolt
		)
		part.CFrame = CFrame.lookAt((from + to) / 2, to)
		part.Transparency = 0
		from = to
	end
	bolt.Parent = set.holder
	task.delay(random:NextNumber(0.15, 0.35), function()
		bolt:Destroy()
	end)
end

-- Now and then the whole screen flashes bright and lightning strikes, sometimes twice.
local function startFlashes(set: Set)
	flashToken += 1
	local mine = flashToken
	local flash = Lighting:FindFirstChild("WatcherFlash") :: ColorCorrectionEffect?
	if not flash then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "WatcherFlash"
		made.Parent = Lighting
		flash = made
	end
	local effect = flash :: ColorCorrectionEffect
	task.spawn(function()
		while flashToken == mine do
			task.wait(random:NextNumber(2, 6))
			if flashToken == mine then
				SoundController.thunder()
			end
			for _ = 1, if random:NextNumber() < 0.4 then 2 else 1 do
				if flashToken ~= mine then
					break
				end
				effect.Brightness = random:NextNumber(0.35, 0.6)
				TweenService:Create(effect, TweenInfo.new(0.4), { Brightness = 0 }):Play()
				strike(set)
				task.wait(0.15)
			end
		end
		effect.Brightness = 0
	end)
end

local function stopFlashes()
	flashToken += 1
end

-- The event's name across the middle of the screen for a few seconds.
local function showBanner(event: Events.WatcherEvent, setId: string?)
	local gui = screenGui()
	local old = gui:FindFirstChild("Banner")
	if old then
		old:Destroy()
	end
	local sky = Events.skyFor(event, setId)
	local color = if sky and sky.edge then rgb(sky.edge) else Color3.new(1, 1, 1)
	local text = string.upper(event.name)
	local sets: { Events.MonsterSet } = event.monsterSets or {}
	for _, set in sets do
		if set.id == setId then
			text ..= `\n{string.upper(set.name)}` -- The Watcher Awakens: which set came
		end
	end
	local label = Instance.new("TextLabel")
	label.Name = "Banner"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.8, if string.find(text, "\n") then 0.2 else 0.12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
	label.TextTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 1
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = label
	label.Parent = gui

	local pop = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(label, pop, { TextTransparency = 0 }):Play()
	TweenService:Create(stroke, pop, { Transparency = 0 }):Play()
	TweenService:Create(scale, pop, { Scale = 1 }):Play()
	task.delay(BannerSeconds, function()
		local fade = TweenInfo.new(1)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		task.delay(1, function()
			label:Destroy()
		end)
	end)
end

------------------------------------------------------------------------------------------

local shown: Events.Sky? = nil -- the sky last drawn

local function show(id: string?)
	-- Fade out whatever is showing.
	for _, set in sets do
		set.target = 0
		set.speed = 1 / FadeOutSeconds
	end
	stopFlashes()

	local event = Events.find(id)
	local sky = if event then Events.skyFor(event, workspace:GetAttribute("WatcherMonsterSet")) else nil
	shown = sky
	if not event or not sky then
		return
	end
	local holder = Instance.new("Folder")
	holder.Name = event.id
	local root = workspace.CurrentCamera:FindFirstChild("WatcherSky")
	if not root then
		root = Instance.new("Folder")
		root.Name = "WatcherSky"
		root.Parent = workspace.CurrentCamera
	end
	holder.Parent = root

	local skyAt = workspace:GetAttribute("WatcherSkyAt")
	local seconds = if typeof(skyAt) == "number"
		then skyAt - workspace:GetServerTimeNow()
		else MinFadeInSeconds
	local set: Set = {
		id = event.id,
		pieces = {},
		emitters = {},
		weather = nil,
		edge = nil,
		holder = holder,
		alpha = 0,
		target = 1,
		speed = 1 / math.max(seconds, MinFadeInSeconds),
		flashes = sky.flashes == true and Settings.get("flashes") == true,
	}
	if sky.moon then
		addMoon(set, sky.moon)
	end
	if sky.eye then
		addEye(set)
	end
	if sky.aurora then
		addAurora(set, sky.aurora)
	end
	if sky.sparkles then
		addSparkles(set, sky.sparkles)
	end
	local scale = SettingsUtil.weatherScale(Settings.get("weather"))
	if sky.weather and scale > 0 then
		addWeather(set, sky.weather, scale)
	end
	if sky.mist then
		addMist(set, sky.mist)
	end
	if sky.frame and sky.edge and Settings.get("edgeGlow") == true then
		addEdge(set, sky.edge)
	end
	table.insert(sets, set)
	if set.flashes then
		startFlashes(set)
	end
end

local function step(deltaTime: number)
	local camera = workspace.CurrentCamera
	if not camera or #sets == 0 then
		return
	end
	local position = camera.CFrame.Position
	local t = os.clock()
	for index = #sets, 1, -1 do
		local set = sets[index]
		if set.alpha < set.target then
			set.alpha = math.min(set.alpha + deltaTime * set.speed, set.target)
		elseif set.alpha > set.target then
			set.alpha = math.max(set.alpha - deltaTime * set.speed, set.target)
		end
		if set.target == 0 and set.alpha <= 0 then
			set.holder:Destroy()
			if set.edge then
				set.edge:Destroy()
			end
			table.remove(sets, index)
			continue
		end
		for _, piece in set.pieces do
			piece.part.CFrame = piece.place(piece, position, t)
			piece.part.Transparency = 1 - set.alpha * (1 - piece.opaque)
		end
		for _, entry in set.emitters do
			entry.emitter.Rate = entry.rate * set.alpha
		end
		if set.weather then
			stepWeather(set.weather, position, deltaTime, t, set.alpha)
		end
		if set.edge then
			set.edge.GroupTransparency = 1 - set.alpha
		end
	end
end

function SkyController.start()
	workspace:GetAttributeChangedSignal("WatcherSky"):Connect(function()
		show(workspace:GetAttribute("WatcherSky"))
	end)
	workspace:GetAttributeChangedSignal("WatcherEvent"):Connect(function()
		local event = Events.find(workspace:GetAttribute("WatcherEvent"))
		if event then
			showBanner(event, workspace:GetAttribute("WatcherMonsterSet"))
		end
	end)
	-- The Watcher's monster set has its own sky; redraw only if it actually changes the sky.
	workspace:GetAttributeChangedSignal("WatcherMonsterSet"):Connect(function()
		local event = Events.find(workspace:GetAttribute("WatcherSky"))
		if event and Events.skyFor(event, workspace:GetAttribute("WatcherMonsterSet")) ~= shown then
			show(event.id)
		end
	end)
	Settings.changed(function(key)
		if key == "weather" or key == "flashes" or key == "edgeGlow" then
			show(workspace:GetAttribute("WatcherSky"))
		end
	end)
	show(workspace:GetAttribute("WatcherSky"))
	RunService.RenderStepped:Connect(step)
end

return SkyController
