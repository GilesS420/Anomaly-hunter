--!strict
-- The sky pieces of a Watcher event: a moon, the Watcher's eye, an aurora, sparkles drifting
-- down and flashes (Config/Events, each event's `sky`). The server changes Lighting; these are
-- drawn here, on each player's own screen, around their camera. They move along with the
-- camera so they look infinitely far away, and players in zones see them too.
--
-- The server says which sky to show in Workspace attribute WatcherSky (an event id) and when
-- it should be fully in with WatcherSkyAt (server time; the end of the warning).
-- The pieces live in Workspace.CurrentCamera.WatcherSky, on this client only.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Config.Events)

local SkyController = {}

local Distance = 220 -- studs from the camera to a moon or the eye
local FadeOutSeconds = 3
local MinFadeInSeconds = 1

type Piece = {
	part: Part,
	opaque: number, -- Transparency when fully in
	place: (piece: Piece, camera: Vector3, t: number) -> CFrame,
}

type Set = {
	id: string,
	pieces: { Piece },
	emitters: { { emitter: ParticleEmitter, rate: number } },
	holder: Folder,
	alpha: number, -- 0 hidden, 1 fully in
	target: number,
	speed: number, -- alpha per second
	flashes: boolean,
}

local sets: { Set } = {}
local flashToken = 0

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
	holder: Folder
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

local function addMoon(set: Set, moon: { color: Events.Rgb, size: number, coin: boolean? })
	local at = direction(35, 32) * Distance
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
				place = function(_piece, camera)
					local position = camera + at + (if index == 2 then -at.Unit * 0.5 else Vector3.zero)
					return CFrame.lookAt(position, camera) * CFrame.Angles(0, math.rad(90), 0)
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
	local at = direction(0, 38) * Distance
	local size = 70
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

	local function gaze(camera: Vector3, t: number): Vector3
		local toCamera = (-at).Unit
		local side = toCamera:Cross(Vector3.yAxis).Unit
		local wander = side * math.sin(t * 0.4) * 0.35 + Vector3.yAxis * math.sin(t * 0.27 + 1) * 0.2
		return (toCamera + wander).Unit
	end
	table.insert(set.pieces, {
		part = white,
		opaque = 0,
		place = function(_piece, camera)
			return CFrame.new(camera + at)
		end,
	})
	table.insert(set.pieces, {
		part = iris,
		opaque = 0,
		place = function(_piece, camera, t)
			return CFrame.new(camera + at + gaze(camera, t) * size * 0.3)
		end,
	})
	table.insert(set.pieces, {
		part = pupil,
		opaque = 0,
		place = function(_piece, camera, t)
			return CFrame.new(camera + at + gaze(camera, t) * size * 0.42)
		end,
	})
end

-- Three long see-through bands of light, waving slowly overhead.
local function addAurora(set: Set, color: Events.Rgb)
	for index = 1, 3 do
		local band =
			piecePart(`Aurora{index}`, Enum.PartType.Block, Vector3.new(700, 22, 1), rgb(color), set.holder)
		table.insert(set.pieces, {
			part = band,
			opaque = 0.55 + index * 0.08,
			place = function(_piece, camera, t)
				local phase = t * 0.25 + index * 1.7
				local offset = Vector3.new(math.sin(phase) * 40, 150 + index * 18, -160 + index * 70)
				return CFrame.new(camera + offset)
					* CFrame.Angles(
						math.rad(-55),
						math.rad(math.sin(phase * 0.6) * 12),
						math.sin(phase) * 0.06
					)
			end,
		})
	end
end

-- Specks drifting down all around the player.
local function addSparkles(set: Set, color: Events.Rgb)
	local cloud =
		piecePart("Sparkles", Enum.PartType.Block, Vector3.new(160, 1, 160), Color3.new(1, 1, 1), set.holder)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Color = ColorSequence.new(rgb(color))
	emitter.LightEmission = 1
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
	emitter.Rate = 0
	emitter.Parent = cloud
	table.insert(set.emitters, { emitter = emitter, rate = 60 })
	table.insert(set.pieces, {
		part = cloud,
		opaque = 1, -- the cloud itself stays invisible
		place = function(_piece, camera)
			return CFrame.new(camera + Vector3.new(0, 40, 0))
		end,
	})
end

-- Now and then the whole screen flashes bright, sometimes twice, like a dying bulb.
local function startFlashes()
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
		local random = Random.new()
		while flashToken == mine do
			task.wait(random:NextNumber(3, 8))
			for _ = 1, if random:NextNumber() < 0.4 then 2 else 1 do
				if flashToken ~= mine then
					break
				end
				effect.Brightness = random:NextNumber(0.25, 0.45)
				TweenService:Create(effect, TweenInfo.new(0.35), { Brightness = 0 }):Play()
				task.wait(0.15)
			end
		end
		effect.Brightness = 0
	end)
end

local function stopFlashes()
	flashToken += 1
end

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
		holder = holder,
		alpha = 0,
		target = 1,
		speed = 1 / math.max(seconds, MinFadeInSeconds),
		flashes = sky.flashes == true,
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
	table.insert(sets, set)
	if set.flashes then
		startFlashes()
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
	end
end

function SkyController.start()
	workspace:GetAttributeChangedSignal("WatcherSky"):Connect(function()
		show(workspace:GetAttribute("WatcherSky"))
	end)
	show(workspace:GetAttribute("WatcherSky"))
	RunService.RenderStepped:Connect(step)
end

return SkyController
