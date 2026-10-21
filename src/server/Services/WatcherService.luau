--!strict
-- The Watcher: every 5 to 10 minutes it stirs and an event changes the sky for the whole
-- server (the clock and the events are in Shared.Config.Events, the rules in Util.Watcher).
-- The schedule is global: every server plays the same event at the same time, so hopping
-- servers never finds a rarer one.
-- Events are passive: the sky changes, and while one is live the mansion rolls read its
-- boosts from WatcherService.current() (effect, effectOddsMultiplier, growthMultiplier).
--   Flicker     the streetlights fail too
--   Blood Moon  Crimson Wisp and Moonhowler drift between the mansions (an optional bonus
--               to catch)
--   The Watcher Awakens  brings one of its monster sets: Phantoms, Nightmares or (rarely)
--               Eldritch monsters, the same set in every server (workspace attr WatcherMonsterSet)
-- Event monsters are caught in the main area like any other monster (CatchService) and fly
-- straight home to the mansion. Whatever is left when the event ends fades away.
--
-- The server changes Lighting (seen everywhere); the moon, eye, aurora, sparkles and flashes
-- are drawn by each client (client/Controllers/SkyController) from the attributes below.
--
-- World pieces (built as grey placeholders if missing, never moved or changed if there):
--   Workspace.Hub.WatcherMeter   a Part (or Model) in Watcher Square; the Watcher's eyes float above it
--   Workspace.Hub.WatcherSign    a Part; a noticeboard explaining the Watcher is painted on both faces
--   Workspace.Hub.Streetlights   a Folder; every light inside fails during Flicker
-- Event monsters appear in Workspace.Hub.EventMonsters.
--
-- Workspace attributes: WatcherEvent (id while one is live, else nil), WatcherEventEnd
-- (server time it ends), WatcherNext (id of the event being warned about), WatcherSky (id
-- whose sky is showing, from the warning to the end), WatcherSkyAt (server time that sky is
-- fully in), WatcherEyes (how many eyes are open).

local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local Roam = require(ReplicatedStorage.Shared.Util.Roam)
local Spawning = require(ReplicatedStorage.Shared.Util.Spawning)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Watcher = require(ReplicatedStorage.Shared.Util.Watcher)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)
local RoamService = require(script.Parent.RoamService)
local World = require(script.Parent.Parent.World)

local WatcherService = {}

-- Same shape as SpawnService.Spawned; zone is 0 for the main area.
export type Spawned = {
	monsterId: string,
	rarity: string,
	size: string,
	zone: number,
	reservedFor: number?, -- always nil: anyone in the main area can catch an event monster
	event: string,
}

type Handler = { start: () -> (), stop: () -> () }

type Phase = "Calm" | "Warning" | "Live"

local GroundTop = 0.1 -- top of the hub floor (see WorldBuilder)
local Group = "Hub:Event" -- RoamService group for event monsters
local FadeWaitMax = 10 -- seconds a monster being caught may stay after its event ends
local LightTween = TweenInfo.new(3, Enum.EasingStyle.Sine)
local SummonSkySeconds = 3 -- a summoned event skips the warning, so its sky comes in quickly

local random = Random.new()
local live: { [Model]: Spawned } = {}
local handlers: { [string]: Handler } = {}
local phase: Phase = "Calm"
local current: Events.WatcherEvent? = nil -- live event
local upcoming: Events.WatcherEvent? = nil -- the event being warned about
local endsAt = 0 -- server time the live event ends
local eyes = 0
-- Where the global schedule is (Util/Watcher.slotAt): every server plays the same events at
-- the same times. Set in start.
local schedule: Watcher.Slot? = nil
local summoned = false -- the live event was summoned in this server only (Studio /event)

-- The meter's eyes and count line, set in buildMeter. The live event and its time left are
-- shown on each player's screen instead (client/Controllers/EventIconController).
type MeterEye = { white: Frame, iris: Frame, glow: UIStroke }
local meterEyes: { MeterEye } = {}
local meterCount: TextLabel? = nil

local function driftRects(): { Roam.Rect }
	local rects = {}
	for _, area in Events.DriftAreas do
		table.insert(rects, Roam.rect(area.x, area.z, area.width, area.depth, GroundTop + Events.HoverHeight))
	end
	return rects
end

local function hubFolder(): Instance
	local hub = World.find(workspace, "Hub")
	if hub then
		return hub
	end
	local folder = Instance.new("Folder")
	folder.Name = "Hub"
	folder.Parent = workspace
	return folder
end

local function block(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

------------------------------------------------------------------------------------------
-- Lighting: each event saves the look it changes and puts it back when it ends.

type Saved = { [Instance]: { [string]: any } }

-- How each property looked before any event touched it (the night). Kept for good: nothing
-- else changes Lighting while the game runs, and a sky that replaces another mid-tween must
-- still go back to the night, not to the half-changed colours.
local saved: Saved = {}

local function tweenTo(instance: Instance, goal: { [string]: any }, info: TweenInfo)
	local before = saved[instance] or {}
	for property in goal do
		if before[property] == nil then
			before[property] = (instance :: any)[property]
		end
	end
	saved[instance] = before
	TweenService:Create(instance, info, goal):Play()
end

local function restoreLighting()
	for instance, before in saved do
		if instance.Parent then
			TweenService:Create(instance, LightTween, before):Play()
		end
	end
end

-- An effect made just for one event, removed again when it ends.
local function temporary<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local instance = Instance.new(className)
	instance.Name = name
	return (instance :: any) :: T
end

local function rgb(color: Events.Rgb): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local SkyNames = { "WatcherSkyTint", "WatcherSkyAtmosphere" }

-- Eases the sky into `event`'s look (its monster set's own, if it has one) over `seconds`
-- (the warning, so it's fully in when the event starts). Replaces whatever sky was showing.
local function applySky(event: Events.WatcherEvent, set: Events.MonsterSet?, seconds: number)
	local sky = Events.skyFor(event, if set then set.id else nil)
	if not sky then
		return
	end
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine)

	local goal: { [string]: any } = {}
	if sky.ambient then
		goal.Ambient = rgb(sky.ambient)
	end
	if sky.outdoorAmbient then
		goal.OutdoorAmbient = rgb(sky.outdoorAmbient)
	end
	-- Always set, so a sky that follows a darker one doesn't keep its brightness.
	goal.Brightness = sky.brightness
		or (saved[Lighting] and saved[Lighting].Brightness)
		or Lighting.Brightness
	tweenTo(Lighting, goal, info)

	local tint = temporary("ColorCorrectionEffect", "WatcherSkyTint") :: ColorCorrectionEffect
	tint.TintColor = Color3.new(1, 1, 1)
	tint.Parent = Lighting
	TweenService:Create(tint, info, {
		TintColor = if sky.tint then rgb(sky.tint) else Color3.new(1, 1, 1),
		Saturation = sky.saturation or 0,
	}):Play()

	local atmosphere = sky.atmosphere
	if atmosphere then
		local goalAtmosphere = {
			Color = rgb(atmosphere.color),
			Decay = rgb(atmosphere.decay),
			Density = atmosphere.density,
			Haze = atmosphere.haze,
		}
		local existing = Lighting:FindFirstChildOfClass("Atmosphere")
		if existing and existing.Name ~= "WatcherSkyAtmosphere" then
			tweenTo(existing, goalAtmosphere, info)
		else
			local made = temporary("Atmosphere", "WatcherSkyAtmosphere") :: Atmosphere
			made.Density = 0
			made.Parent = Lighting
			TweenService:Create(made, info, goalAtmosphere):Play()
		end
	end
end

-- Eases the sky back to the night.
local function clearSky()
	restoreLighting()
	for _, name in SkyNames do
		local made = Lighting:FindFirstChild(name)
		if made then
			made.Name = `{name}Fading` -- so the next sky makes a fresh one
			if made:IsA("ColorCorrectionEffect") then
				TweenService:Create(made, LightTween, { TintColor = Color3.new(1, 1, 1), Saturation = 0 })
					:Play()
			elseif made:IsA("Atmosphere") then
				TweenService:Create(made, LightTween, { Density = 0 }):Play()
			end
			task.delay(LightTween.Time, function()
				made:Destroy()
			end)
		end
	end
end

------------------------------------------------------------------------------------------
-- Streetlights

type LampState = { light: Light?, part: BasePart?, enabled: boolean?, material: Enum.Material? }

local lamps: { LampState } = {}
local flickering = 0 -- bumped on every Flicker start and stop, so only the latest stutter loop runs

local function buildStreetlights(hub: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Streetlights"
	-- Two rows along the front of the plots, facing each other across the lanes.
	for _, z in { -72, 72 } do
		for x = -250, 250, 100 do
			local lamp = Instance.new("Model")
			lamp.Name = "Streetlight"
			local pole = block(
				"Pole",
				Vector3.new(0.6, 12, 0.6),
				CFrame.new(x, GroundTop + 6, z),
				Color3.fromRGB(40, 40, 46),
				Enum.Material.Metal
			)
			pole.Parent = lamp
			local head = block(
				"Head",
				Vector3.new(2, 1.4, 2),
				CFrame.new(x, GroundTop + 12.7, z),
				Color3.fromRGB(255, 214, 140),
				Enum.Material.Neon
			)
			head.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 214, 140)
			light.Range = 28
			light.Brightness = 1.5
			light.Parent = head
			head.Parent = lamp
			lamp.PrimaryPart = pole
			lamp.Parent = folder
		end
	end
	folder.Parent = hub
	print("WatcherService: built Hub.Streetlights")
end

-- Remembers every light and glowing part in Hub.Streetlights, as it looks with the lights on.
local function findLamps(hub: Instance)
	table.clear(lamps)
	local folder = World.find(hub, "Streetlights")
	if not folder then
		buildStreetlights(hub)
		folder = World.find(hub, "Streetlights")
	end
	if not folder then
		return
	end
	for _, child in folder:GetDescendants() do
		if child:IsA("Light") then
			table.insert(lamps, { light = child, enabled = child.Enabled })
		elseif child:IsA("BasePart") and child.Material == Enum.Material.Neon then
			table.insert(lamps, { part = child, material = child.Material })
		end
	end
end

local function setLamp(lamp: LampState, on: boolean)
	if lamp.light then
		lamp.light.Enabled = if on then lamp.enabled == true else false
	elseif lamp.part then
		lamp.part.Material = if on then lamp.material or Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

local function setAllLamps(on: boolean)
	for _, lamp in lamps do
		setLamp(lamp, on)
	end
end

------------------------------------------------------------------------------------------
-- The events

-- Extra pieces for one event, on top of its sky (Config/Events).
handlers.Flicker = {
	start = function()
		flickering += 1
		local mine = flickering
		task.spawn(function()
			-- A few seconds of stuttering, then the lights die, with a sputter now and then.
			local stutterUntil = os.clock() + 4
			while flickering == mine and os.clock() < stutterUntil do
				for _, lamp in lamps do
					setLamp(lamp, random:NextNumber() < 0.5)
				end
				task.wait(random:NextNumber(0.05, 0.25))
			end
			while flickering == mine do
				setAllLamps(false)
				task.wait(random:NextNumber(2, 6))
				if flickering == mine and #lamps > 0 then
					local lamp = lamps[random:NextInteger(1, #lamps)]
					setLamp(lamp, true)
					task.wait(random:NextNumber(0.05, 0.2))
				end
			end
		end)
	end,
	stop = function()
		flickering += 1 -- ends the stutter loop
		setAllLamps(true)
	end,
}

------------------------------------------------------------------------------------------
-- Event monsters

local function eventMonstersFolder(): Folder
	local hub = hubFolder()
	local found = hub:FindFirstChild("EventMonsters")
	if found and found:IsA("Folder") then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = "EventMonsters"
	folder.Parent = hub
	return folder
end

local function spawnOne(event: Events.WatcherEvent, monster: Monsters.Monster, rects: { Roam.Rect }): boolean
	local size = Spawning.rollSize(random)
	local radius = MonsterModel.radius(size.id, monster.id)
	local point = Roam.findFreePoint(rects, radius, RoamService.bodies(Group), random)
	if not point then
		return false
	end
	local model = MonsterModel.build({ monsterId = monster.id, rarity = monster.rarity, size = size.id })
	model:SetAttribute("Wild", true)
	model:SetAttribute("Event", event.id)
	live[model] =
		{ monsterId = monster.id, rarity = monster.rarity, size = size.id, zone = 0, event = event.id }
	model.Destroying:Connect(function()
		live[model] = nil
	end)
	RoamService.add(model, {
		rects = rects,
		radius = radius,
		speed = Events.DriftSpeed,
		group = Group,
		at = Vector3.new(point.x, point.y + radius + 0.5, point.z),
	})
	model.Parent = eventMonstersFolder()
	return true
end

-- Removes a leftover event monster, but lets anyone halfway through catching it finish.
local function fadeOut(model: Model)
	local waited = 0
	while live[model] and RoamService.isHeld(model) and waited < FadeWaitMax do
		task.wait(1)
		waited += 1
	end
	if live[model] then
		live[model] = nil
		model:Destroy()
	end
end

------------------------------------------------------------------------------------------
-- The event clock

local function now(): number
	return workspace:GetServerTimeNow()
end

local EyeWhite = Color3.fromRGB(235, 225, 240)
local ClosedEye = Color3.fromRGB(40, 32, 52)
local Glow = Color3.fromRGB(190, 110, 255)
local Lamp = Color3.fromRGB(255, 176, 84) -- the lantern orange of the shop titles

-- The eyes in Watcher Square: the glowing ball over each of the four ways in, then the one on
-- the meter's pillar, open one by one with the meter (an eye per event). A closed eye is dark
-- stone; an open one glows purple with a black pupil looking out of the square, and the
-- pillar's eye follows the nearest player. With all five open they burn red: The Watcher
-- Awakens is next.

type WorldEye = { ball: BasePart, pupil: Part, light: PointLight, out: Vector3, open: boolean? }

local worldEyes: { WorldEye } = {}
local EyeAwake = Color3.fromRGB(255, 50, 80)
local EyeTween = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function pupilAt(eye: WorldEye, look: Vector3): CFrame
	local center = eye.ball.Position
	local radius = eye.ball.Size.X / 2
	-- A flat disc on the ball's surface, facing `look` (a cylinder's round faces point along X).
	return CFrame.lookAt(center + look * (radius - 0.05), center + look * (radius + 1))
		* CFrame.Angles(0, math.rad(90), 0)
end

local function addWorldEye(ball: BasePart, out: Vector3)
	local pupil = Instance.new("Part")
	pupil.Name = "Pupil"
	pupil.Shape = Enum.PartType.Cylinder
	pupil.Anchored = true
	pupil.CanCollide = false
	pupil.CanQuery = false
	pupil.CanTouch = false
	pupil.CastShadow = false
	pupil.Material = Enum.Material.SmoothPlastic
	pupil.Color = Color3.fromRGB(10, 6, 14)
	pupil.Size = Vector3.new(0.1, 0.05, 0.05)
	pupil.Parent = ball
	local light = ball:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
	light.Color = Glow
	light.Range = 14
	light.Parent = ball
	local eye: WorldEye = { ball = ball, pupil = pupil, light = light, out = out }
	pupil.CFrame = pupilAt(eye, out)
	table.insert(worldEyes, eye)
end

local function findWorldEyes(hub: Instance)
	local meter = World.part(World.find(hub, "WatcherMeter"))
	local center = if meter then meter.Position else Vector3.zero
	for gate = 1, 4 do
		local ball = hub:FindFirstChild(`Gate{gate}Eye`, true)
		if ball and ball:IsA("BasePart") then
			local flat = Vector3.new(ball.Position.X - center.X, 0, ball.Position.Z - center.Z)
			addWorldEye(ball, if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis)
		end
	end
	if meter then
		local ball = meter:FindFirstChild("Eye")
		if not (ball and ball:IsA("BasePart")) then
			local made = block(
				"Eye",
				Vector3.new(3, 3, 3),
				CFrame.new(meter.Position + Vector3.new(0, meter.Size.Y / 2 + 1.5, 0)),
				ClosedEye,
				Enum.Material.Slate
			)
			made.Shape = Enum.PartType.Ball
			made.CanCollide = false
			made.Parent = meter
			ball = made
		end
		addWorldEye(ball :: BasePart, Vector3.zAxis)
	end
	if #worldEyes < Events.EyesToAwaken then
		warn(`WatcherService: found {#worldEyes} of {Events.EyesToAwaken} eyes in Watcher Square`)
	end
end

local function showWorldEyes()
	local awake = eyes >= Events.EyesToAwaken or (current ~= nil and current.awakening == true)
	for index, eye in worldEyes do
		local open = awake or index <= eyes
		local ball = eye.ball
		ball.Material = if open then Enum.Material.Neon else Enum.Material.Slate
		ball.Color = if not open then ClosedEye elseif awake then EyeAwake else Glow
		eye.light.Enabled = open
		eye.light.Color = if awake then EyeAwake else Glow
		if open ~= eye.open then
			eye.open = open
			-- The pupil opens (or shuts) like a lid lifting.
			local d = ball.Size.X * 0.5
			TweenService:Create(eye.pupil, EyeTween, {
				Size = if open then Vector3.new(0.1, d, d) else Vector3.new(0.1, 0.05, 0.05),
			}):Play()
		end
	end
	-- The pillar's eye watches the nearest player.
	local pillar = worldEyes[Events.EyesToAwaken]
	if pillar and pillar.open then
		local nearest: Vector3? = nil
		local best = 120
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local distance = (root.Position - pillar.ball.Position).Magnitude
				if distance < best then
					best = distance
					nearest = root.Position
				end
			end
		end
		local look = if nearest then (nearest - pillar.ball.Position).Unit else pillar.out
		TweenService:Create(pillar.pupil, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {
			CFrame = pupilAt(pillar, look),
		}):Play()
	end
end

local function publish()
	local sky = if phase == "Live" then current elseif phase == "Warning" then upcoming else nil
	workspace:SetAttribute("WatcherEvent", if current then current.id else nil)
	workspace:SetAttribute("WatcherEventEnd", if current then endsAt else nil)
	workspace:SetAttribute("WatcherNext", if phase == "Warning" and upcoming then upcoming.id else nil)
	workspace:SetAttribute("WatcherSky", if sky then sky.id else nil)
	workspace:SetAttribute("WatcherEyes", eyes)

	showWorldEyes()
	for index, eye in meterEyes do
		local open = index <= eyes
		eye.white.BackgroundColor3 = if open then EyeWhite else ClosedEye
		eye.iris.Visible = open
		eye.glow.Color = if open then Glow else Color3.fromRGB(90, 75, 110)
		eye.glow.Thickness = if open then 3 else 2
	end
	local count = meterCount
	if count then
		count.Text = if eyes >= Events.EyesToAwaken
			then "All eyes are open... it awakens next!"
			else `{eyes} of {Events.EyesToAwaken} eyes open`
		count.TextColor3 = if eyes >= Events.EyesToAwaken then Glow else Color3.new(1, 1, 1)
	end
end

local function startEvent(
	event: Events.WatcherEvent,
	ends: number,
	set: Events.MonsterSet?,
	skySeconds: number?
)
	if skySeconds then
		applySky(event, set, skySeconds)
		workspace:SetAttribute("WatcherSkyAt", now() + skySeconds)
	end
	phase = "Live"
	current = event
	upcoming = nil
	endsAt = ends
	Notify.toastAll(event.announce or `{event.name} has begun!`)
	if set then
		Notify.toastAll(set.announce)
	end
	workspace:SetAttribute("WatcherMonsterSet", if set then set.id else nil)

	local handler = handlers[event.id]
	if handler then
		xpcall(handler.start, function(err)
			warn(`WatcherService: {event.id} failed to start its effects: {err}`)
		end)
	end

	local weights, count = Watcher.spawns(event, set, #Players:GetPlayers())
	if weights then
		local rects = driftRects()
		for _, monster in Watcher.monsterBatch(weights, count, random) do
			if not spawnOne(event, monster, rects) then
				break -- too crowded
			end
		end
	end
	publish()
end

local function endEvent()
	local event = current
	if not event then
		return
	end
	current = nil
	local handler = handlers[event.id]
	if handler then
		xpcall(handler.stop, function(err)
			warn(`WatcherService: {event.id} failed to clean up its effects: {err}`)
		end)
	end
	clearSky()
	for model, spawned in live do
		if spawned.event == event.id then
			task.spawn(fadeOut, model)
		end
	end
	Notify.toastAll(`{event.name} is over. The sky calms down.`)

	phase = "Calm"
	summoned = false
	publish()
	-- After WatcherSky clears, so clients fade the set's sky out instead of switching skies.
	workspace:SetAttribute("WatcherMonsterSet", nil)
end

local function startWarning(event: Events.WatcherEvent, set: Events.MonsterSet?, startsAt: number)
	phase = "Warning"
	upcoming = event
	-- Before WatcherSky (publish), so clients draw the set's sky straight away.
	workspace:SetAttribute("WatcherMonsterSet", if set then set.id else nil)
	applySky(event, set, math.max(startsAt - now(), 1))
	workspace:SetAttribute("WatcherSkyAt", startsAt)
	Notify.toastAll(event.warning or "The Watcher stirs...")
end

local function tick()
	local slot = schedule :: Watcher.Slot
	local time = now()
	if summoned and time >= endsAt then
		endEvent()
	end
	-- Step the schedule on, ending its event as its slot runs out.
	while time >= slot.endAt do
		if phase == "Live" and not summoned then
			endEvent()
		end
		slot = Watcher.nextSlot(slot)
	end
	schedule = slot
	eyes = slot.eyes

	-- A summoned event holds the sky until it ends; then the schedule picks up where it is.
	if not summoned then
		-- The set is rolled from the slot too, so every server gets the same monsters and sky.
		local set = Watcher.pickSet(slot.event, Rng.seeded(`watcher-set:{slot.index}`))
		if time >= slot.startAt then
			if phase ~= "Live" then
				-- Straight from the warning the sky is already in; joining late, it comes in fast.
				local skySeconds = if phase == "Warning" and upcoming == slot.event
					then nil
					else SummonSkySeconds
				startEvent(slot.event, slot.endAt, set, skySeconds)
			end
		elseif time >= slot.warnAt and phase ~= "Warning" then
			startWarning(slot.event, set, slot.startAt)
		end
	end
	publish()
end

------------------------------------------------------------------------------------------
-- The meter in Watcher Square

local function buildMeterPart(hub: Instance): BasePart
	local pillar = block(
		"WatcherMeter",
		Vector3.new(4, 14, 4),
		CFrame.new(0, GroundTop + 1 + 7, 0), -- standing on Watcher Square (1 stud high)
		Color3.fromRGB(45, 40, 55),
		Enum.Material.Slate
	)
	local eye = block(
		"Eye",
		Vector3.new(3, 3, 3),
		CFrame.new(0, GroundTop + 1 + 14 + 1.5, 0),
		Color3.fromRGB(170, 90, 255),
		Enum.Material.Neon
	)
	eye.Shape = Enum.PartType.Ball
	eye.CanCollide = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = pillar
	weld.Part1 = eye
	weld.Parent = eye
	eye.Parent = pillar
	pillar.Parent = hub
	print("WatcherService: built Hub.WatcherMeter")
	return pillar
end

local function text(parent: Instance, value: string, y: number, height: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.05, y)
	label.Size = UDim2.fromScale(0.9, height)
	label.Font = font
	label.Text = value
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function round(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = parent
end

-- A dark panel floating over the meter: "The Watcher" in the spooky font, five eyes (one
-- opens per event; all open means The Watcher Awakens is next) and how many are open.
local function buildMeter(hub: Instance)
	local part = World.part(World.find(hub, "WatcherMeter")) or buildMeterPart(hub)
	local existing = part:FindFirstChild("HungerMeter") or part:FindFirstChild("EyeMeter")
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EyeMeter"
	billboard.Adornee = part
	billboard.LightInfluence = 0
	billboard.MaxDistance = 300
	billboard.Size = UDim2.fromScale(16, 8) -- studs, so it sits in the world like a sign
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 6, 0)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
	panel.BackgroundTransparency = 0.15
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = panel
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.fromRGB(96, 74, 140)
	rim.Thickness = 3
	rim.Parent = panel
	panel.Parent = billboard

	local title = text(panel, "The Watcher", 0.04, 0.32, Enum.Font.LuckiestGuy)
	title.TextColor3 = Lamp

	local row = Instance.new("Frame")
	row.Name = "Eyes"
	row.Position = UDim2.fromScale(0.05, 0.4)
	row.Size = UDim2.fromScale(0.9, 0.3)
	row.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.03, 0)
	layout.Parent = row
	table.clear(meterEyes)
	for index = 1, Events.EyesToAwaken do
		-- An almond: a wide oval white with a purple iris and a slit pupil.
		local white = Instance.new("Frame")
		white.Name = `Eye{index}`
		white.LayoutOrder = index
		white.Size = UDim2.fromScale(0.16, 1)
		white.BackgroundColor3 = ClosedEye
		white.BorderSizePixel = 0
		local shape = Instance.new("UIAspectRatioConstraint")
		shape.AspectRatio = 1.7
		shape.Parent = white
		round(white)
		local glow = Instance.new("UIStroke")
		glow.Parent = white
		local iris = Instance.new("Frame")
		iris.Name = "Iris"
		iris.AnchorPoint = Vector2.new(0.5, 0.5)
		iris.Position = UDim2.fromScale(0.5, 0.5)
		iris.Size = UDim2.fromScale(0.9, 0.9)
		iris.SizeConstraint = Enum.SizeConstraint.RelativeYY
		iris.BackgroundColor3 = Glow
		iris.BorderSizePixel = 0
		iris.Visible = false
		round(iris)
		local pupil = Instance.new("Frame")
		pupil.Name = "Pupil"
		pupil.AnchorPoint = Vector2.new(0.5, 0.5)
		pupil.Position = UDim2.fromScale(0.5, 0.5)
		pupil.Size = UDim2.fromScale(0.28, 0.8)
		pupil.BackgroundColor3 = Color3.fromRGB(10, 6, 14)
		pupil.BorderSizePixel = 0
		round(pupil)
		pupil.Parent = iris
		iris.Parent = white
		white.Parent = row
		table.insert(meterEyes, { white = white, iris = iris, glow = glow })
	end
	row.Parent = panel

	meterCount = text(panel, "", 0.75, 0.2, Enum.Font.FredokaOne)
	billboard.Parent = part
end

-- What the Watcher is, written on a noticeboard in Watcher Square (both sides). Built at
-- Hub.WatcherSign if it's missing; move it anywhere in Studio and it stays put.
local SignText = {
	"Every 5 to 10 minutes the Watcher stirs and an event begins, at the same time in every server.",
	"The sky changes, with a 30 second warning first.",
	"Monsters in your mansion can catch the event's special effect.",
	"The shops and the Collector get boosts, and some events bring a limited Bakery treat.",
	"Each event opens one eye. When all 5 are open, The Watcher Awakens!",
	"Hover over the event icon in the bottom-right corner to see how long it has left.",
}

local function paintSign(board: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = `Info{face.Name}`
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.3
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.03)
	title.Size = UDim2.fromScale(0.9, 0.17)
	title.Font = Enum.Font.LuckiestGuy
	title.Text = "The Watcher"
	title.TextColor3 = Lamp
	title.TextScaled = true
	title.Parent = gui
	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromScale(0.07, 0.22)
	body.Size = UDim2.fromScale(0.86, 0.74)
	body.Font = Enum.Font.FredokaOne
	body.Text = "• " .. table.concat(SignText, "\n• ")
	body.TextColor3 = Color3.fromRGB(235, 225, 240)
	body.TextScaled = true
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.LineHeight = 1.15
	body.Parent = gui
	gui.Parent = board
end

local function buildSign(hub: Instance)
	local board = World.part(World.find(hub, "WatcherSign"))
	if not board then
		-- On the edge of the eye in the stones, in front of the meter, with two posts.
		local base = CFrame.new(0, GroundTop + 1, -12)
		local sign = block(
			"WatcherSign",
			Vector3.new(10, 6, 0.4),
			base * CFrame.new(0, 4.5, 0),
			Color3.fromRGB(30, 22, 38),
			Enum.Material.WoodPlanks
		)
		for _, x in { -4.6, 4.6 } do
			local post = block(
				"Post",
				Vector3.new(0.6, 7.5, 0.6),
				base * CFrame.new(x, 3.75, 0),
				Color3.fromRGB(40, 36, 46),
				Enum.Material.Metal
			)
			post.Parent = sign
		end
		sign.Parent = hub
		print("WatcherService: built Hub.WatcherSign")
		board = sign
	end
	local found = board :: BasePart
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local old = found:FindFirstChild(`Info{face.Name}`)
		if old then
			old:Destroy()
		end
		paintSign(found, face)
	end
end

------------------------------------------------------------------------------------------
-- API

-- The live event monster for this model, or nil (not one, or already caught).
function WatcherService.get(model: Model): Spawned?
	return live[model]
end

-- Removes a caught event monster and returns it as a save-ready entry (rolling catch
-- effects and a variant from the hunter's vacuum, like SpawnService.capture). Nil if someone was faster.
function WatcherService.capture(model: Model, vacuumId: string): Value.CaughtMonster?
	local spawned = live[model]
	if not spawned then
		return nil
	end
	live[model] = nil
	model:Destroy()
	return {
		uid = HttpService:GenerateGUID(false),
		monsterId = spawned.monsterId,
		size = spawned.size,
		effects = Spawning.rollCatchEffects(vacuumId, random),
		variant = Spawning.rollVariant(vacuumId, random),
		familiarity = 0,
	}
end

-- The event playing right now, or nil. Mansion rolls read its effect, effectOddsMultiplier
-- and growthMultiplier from here.
function WatcherService.current(): Events.WatcherEvent?
	return current
end

-- Starts an event right away in this server only, skipping the warning: the one named `id`
-- (Studio /event), or else the schedule's next one (/summon). It opens no eye, and when it
-- ends the server goes back to the global schedule. False if an event is already playing or
-- `id` isn't a launch event.
function WatcherService.summon(id: string?): boolean
	local slot = schedule
	if phase == "Live" or not slot then
		return false
	end
	local event = if id then Events.find(id) else slot.event
	if not event or not event.launch then
		return false
	end
	summoned = true
	startEvent(
		event,
		now() + (event.durationSeconds or 180),
		Watcher.pickSet(event, random),
		SummonSkySeconds
	)
	return true
end

function WatcherService.start()
	local hub = hubFolder()
	findLamps(hub)
	buildMeter(hub)
	buildSign(hub)
	findWorldEyes(hub)
	-- Walks the schedule from its start, once; tick steps it on from here, and joins an
	-- event or warning that is already under way.
	schedule = Watcher.slotAt(now())
	tick()

	task.spawn(function()
		while true do
			task.wait(1)
			-- One bad second must never stop the Watcher for good.
			xpcall(tick, function(err)
				warn(`WatcherService: {err}\n{debug.traceback()}`)
			end)
		end
	end)
end

return WatcherService
