--!strict
-- The Watcher: every 5 to 10 minutes it stirs and an event changes the sky for the whole
-- server (the clock and the events are in Shared.Config.Events, the rules in Util.Watcher).
-- Events are passive: the sky changes, and while one is live the mansion rolls read its
-- boosts from WatcherService.current() (effect, effectOddsMultiplier, growthMultiplier).
--   Flicker     the streetlights fail too, and Flickerwick and Static Shade drift between
--               the mansions (an optional bonus to catch)
--   Blood Moon  Crimson Wisp and Moonhowler drift between the mansions, same as Flicker
-- Event monsters are caught in the main area like any other monster (CatchService) and fly
-- straight home to the mansion. Whatever is left when the event ends fades away.
--
-- The server changes Lighting (seen everywhere); the moon, eye, aurora, sparkles and flashes
-- are drawn by each client (client/Controllers/SkyController) from the attributes below.
--
-- World pieces (built as grey placeholders if missing, never moved or changed if there):
--   Workspace.Hub.WatcherMeter   a Part (or Model) in Watcher Square; the Watcher's eyes float above it
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
local nextAt = 0 -- server time the calm or the warning ends
local endsAt = 0 -- server time the live event ends
local eyes = 0
local lastId: string? = nil

-- Meter GUI pieces, set in buildMeter.
local meterEyes: { Frame } = {}
local meterText: TextLabel? = nil

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

-- Eases the sky into `event`'s look over `seconds` (the warning, so it's fully in when the
-- event starts). Replaces whatever sky was showing.
local function applySky(event: Events.WatcherEvent, seconds: number)
	local sky = event.sky
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

local function spawnOne(event: Events.WatcherEvent, rects: { Roam.Rect }): boolean
	local monster = Watcher.rollMonster(event, random)
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

local OpenEye = Color3.fromRGB(190, 110, 255)
local ClosedEye = Color3.fromRGB(35, 28, 45)

local function publish()
	local sky = if phase == "Live" then current elseif phase == "Warning" then upcoming else nil
	workspace:SetAttribute("WatcherEvent", if current then current.id else nil)
	workspace:SetAttribute("WatcherEventEnd", if current then endsAt else nil)
	workspace:SetAttribute("WatcherNext", if phase == "Warning" and upcoming then upcoming.id else nil)
	workspace:SetAttribute("WatcherSky", if sky then sky.id else nil)
	workspace:SetAttribute("WatcherEyes", eyes)

	for index, eye in meterEyes do
		eye.BackgroundColor3 = if index <= eyes then OpenEye else ClosedEye
	end
	local text = meterText
	if not text then
		return
	end
	if phase == "Live" and current then
		text.Text = `{string.upper(current.name)}! {Watcher.clock(endsAt - now())} left`
	elseif phase == "Warning" then
		text.Text = "Something stirs..."
	elseif eyes >= Events.EyesToAwaken then
		text.Text = "All eyes are open..."
	else
		text.Text = "The Watcher rests"
	end
end

local function startEvent(event: Events.WatcherEvent, skySeconds: number?)
	if skySeconds then
		applySky(event, skySeconds)
		workspace:SetAttribute("WatcherSkyAt", now() + skySeconds)
	end
	phase = "Live"
	current = event
	upcoming = nil
	endsAt = now() + (event.durationSeconds or 180)
	Notify.toastAll(event.announce or `{event.name} has begun!`)

	local handler = handlers[event.id]
	if handler then
		xpcall(handler.start, function(err)
			warn(`WatcherService: {event.id} failed to start its effects: {err}`)
		end)
	end

	if event.monsters then
		local rects = driftRects()
		for _ = 1, Watcher.monsterCount(#Players:GetPlayers()) do
			if not spawnOne(event, rects) then
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

	eyes = Watcher.eyesAfter(eyes, event)
	lastId = event.id
	phase = "Calm"
	nextAt = now() + Watcher.gap(random)
	publish()
end

local function startWarning(event: Events.WatcherEvent)
	phase = "Warning"
	upcoming = event
	nextAt = now() + Events.WarningSeconds
	applySky(event, Events.WarningSeconds)
	workspace:SetAttribute("WatcherSkyAt", nextAt)
	Notify.toastAll(event.warning or "The Watcher stirs...")
end

local function tick()
	if phase == "Live" then
		if now() >= endsAt then
			endEvent()
		end
	elseif phase == "Warning" then
		local event = upcoming
		if event and now() >= nextAt then
			startEvent(event)
		end
	elseif now() >= nextAt then
		startWarning(Watcher.pick(lastId, eyes, random))
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
	billboard.MaxDistance = 400
	billboard.Size = UDim2.fromOffset(320, 96)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 7, 0)

	local function label(text: string, y: number, height: number, bold: boolean): TextLabel
		local textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.Position = UDim2.fromScale(0, y)
		textLabel.Size = UDim2.fromScale(1, height)
		textLabel.Font = if bold then Enum.Font.GothamBlack else Enum.Font.GothamBold
		textLabel.Text = text
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextScaled = true
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Parent = textLabel
		textLabel.Parent = billboard
		return textLabel
	end
	label("THE WATCHER", 0, 0.3, true)

	-- One eye per event; all open means The Watcher Awakens is next.
	local row = Instance.new("Frame")
	row.Name = "Eyes"
	row.Position = UDim2.fromScale(0.15, 0.35)
	row.Size = UDim2.fromScale(0.7, 0.28)
	row.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row
	table.clear(meterEyes)
	for index = 1, Events.EyesToAwaken do
		local eye = Instance.new("Frame")
		eye.Name = `Eye{index}`
		eye.LayoutOrder = index
		eye.Size = UDim2.fromScale(0.16, 1)
		eye.SizeConstraint = Enum.SizeConstraint.RelativeYY
		eye.BackgroundColor3 = ClosedEye
		eye.BorderSizePixel = 0
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = eye
		local outline = Instance.new("UIStroke")
		outline.Color = Color3.fromRGB(200, 180, 230)
		outline.Thickness = 2
		outline.Parent = eye
		local pupil = Instance.new("Frame")
		pupil.Name = "Pupil"
		pupil.AnchorPoint = Vector2.new(0.5, 0.5)
		pupil.Position = UDim2.fromScale(0.5, 0.5)
		pupil.Size = UDim2.fromScale(0.35, 0.35)
		pupil.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
		pupil.BorderSizePixel = 0
		round:Clone().Parent = pupil
		pupil.Parent = eye
		eye.Parent = row
		table.insert(meterEyes, eye)
	end
	row.Parent = billboard

	meterText = label("", 0.68, 0.3, false)
	billboard.Parent = part
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

-- Starts an event right away, skipping the warning: the one named `id` (Studio /event), or
-- else the one the clock would pick next (/summon, and the "Summon an Event" developer
-- product, #27). False if an event is already playing or `id` isn't a launch event.
function WatcherService.summon(id: string?): boolean
	if phase == "Live" then
		return false
	end
	local event = if id then Events.find(id) else upcoming or Watcher.pick(lastId, eyes, random)
	if not event or not event.launch then
		return false
	end
	startEvent(event, SummonSkySeconds)
	return true
end

function WatcherService.start()
	local hub = hubFolder()
	findLamps(hub)
	buildMeter(hub)
	nextAt = now() + Watcher.gap(random)
	publish()

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
