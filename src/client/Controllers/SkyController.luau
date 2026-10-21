--!strict
-- How a Watcher event looks on each player's screen (Config/Events, each event's `sky`):
--   weather   what falls or floats all around you: a snowstorm, rain, gold coins, candy or
--             eyeballs that turn to look at you
--   sky       a moon, the Watcher's eye, an aurora, sparkles, lightning
--   edge      a glow round the edges of the screen in the event's colour
--   banner    the event's name across the screen when it starts
-- The server changes Lighting; everything here is drawn on this client only, around its
-- camera, so it follows you everywhere and players in zones see it too.
--
-- The server says which sky to show in Workspace attribute WatcherSky (an event id) and when
-- it should be fully in with WatcherSkyAt (server time; the end of the warning). The banner
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
local BannerSeconds = 4

type Piece = {
	part: Part,
	opaque: number, -- Transparency when fully in
	place: (piece: Piece, camera: Vector3, t: number) -> CFrame,
}

-- A falling (or floating) thing: a coin, a sweet, an eyeball.
type Bit = {
	parts: { Part },
	offsets: { number }, -- eyes: how far each part sits towards the camera
	opaque: number,
	position: Vector3,
	velocity: Vector3,
	spin: Vector3, -- radians per second round each axis
	angle: Vector3,
	phase: number,
}

type Weather = {
	kind: string,
	bits: { Bit },
	floating: boolean, -- eyes hover round you instead of falling
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

-- Five wide bands of light, waving slowly overhead.
local function addAurora(set: Set, color: Events.Rgb)
	for index = 1, 5 do
		local band =
			piecePart(`Aurora{index}`, Enum.PartType.Block, Vector3.new(800, 40, 1), rgb(color), set.holder)
		table.insert(set.pieces, {
			part = band,
			opaque = 0.35 + index * 0.06,
			place = function(_piece, camera, t)
				local phase = t * 0.25 + index * 1.3
				local offset = Vector3.new(math.sin(phase) * 50, 130 + index * 14, -200 + index * 70)
				return CFrame.new(camera + offset)
					* CFrame.Angles(
						math.rad(-50),
						math.rad(math.sin(phase * 0.6) * 15),
						math.sin(phase) * 0.08
					)
			end,
		})
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

local function addBits(set: Set, kind: string, count: number)
	local weather: Weather = { kind = kind, bits = {}, floating = kind == "Eyes" }
	for index = 1, count do
		local parts: { Part } = {}
		local offsets: { number } = {}
		local fall = 0
		if kind == "Coins" then
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
			opaque = 0,
			position = Vector3.zero, -- placed on the first frame
			velocity = Vector3.new(random:NextNumber(-3, 3), -fall, random:NextNumber(-3, 3)),
			spin = Vector3.new(random:NextNumber(-4, 4), random:NextNumber(-4, 4), random:NextNumber(-4, 4)),
			angle = Vector3.new(random:NextNumber(0, 6), random:NextNumber(0, 6), random:NextNumber(0, 6)),
			phase = random:NextNumber(0, 10),
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
	end
	for index = before + 1, #set.emitters do
		set.emitters[index].rate *= scale
	end
end

local FallRadius = 90 -- coins and candy fall within this many studs of the camera
local FloatRadius = 60

-- Moves the coins, candy or eyes along. A bit that has fallen past the camera (or that the
-- camera has walked away from) starts again above it.
local function stepWeather(weather: Weather, camera: Vector3, deltaTime: number, t: number, alpha: number)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for _, bit in weather.bits do
		local flat = Vector3.new(bit.position.X - camera.X, 0, bit.position.Z - camera.Z)
		if weather.floating then
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
			table.insert(parts, bit.parts[1])
			table.insert(
				frames,
				CFrame.new(bit.position) * CFrame.Angles(bit.angle.X, bit.angle.Y, bit.angle.Z)
			)
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
local function showBanner(event: Events.WatcherEvent)
	local gui = screenGui()
	local old = gui:FindFirstChild("Banner")
	if old then
		old:Destroy()
	end
	local color = if event.sky and event.sky.edge then rgb(event.sky.edge) else Color3.new(1, 1, 1)
	local label = Instance.new("TextLabel")
	label.Name = "Banner"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.8, 0.12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Creepster
	label.Text = string.upper(event.name)
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

local function show(id: string?)
	-- Fade out whatever is showing.
	for _, set in sets do
		set.target = 0
		set.speed = 1 / FadeOutSeconds
	end
	stopFlashes()

	local event = Events.find(id)
	local sky = event and event.sky
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
	if sky.edge and Settings.get("glow") == true then
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
			showBanner(event)
		end
	end)
	Settings.changed(function(key)
		if key == "weather" or key == "flashes" or key == "glow" then
			show(workspace:GetAttribute("WatcherSky"))
		end
	end)
	show(workspace:GetAttribute("WatcherSky"))
	RunService.RenderStepped:Connect(step)
end

return SkyController
