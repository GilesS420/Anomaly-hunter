--!strict
-- The Watcher: server-wide Hunger rises while players hunt in zones, and each threshold
-- fires the next event in the main area (rules in Shared.Config.Events and Util.Watcher).
--   Flicker     the streetlights fail, night falls, Flickerwick and Static Shade drift
--               between the mansions
--   Blood Moon  red sky, Crimson Wisp and Moonhowler appear, and haunted effect odds double
--               (WatcherService.current().effectOddsMultiplier, for the mansion effect rolls)
-- Event monsters are caught in the main area like any other monster (CatchService) and fly
-- straight home to the mansion. Whatever is left when the event ends fades away.
--
-- World pieces (built as grey placeholders if missing, never moved or changed if there):
--   Workspace.Hub.WatcherMeter   a Part (or Model) in Watcher Square; the Hunger meter floats above it
--   Workspace.Hub.Streetlights   a Folder; every light inside fails during Flicker
-- Event monsters appear in Workspace.Hub.EventMonsters.
--
-- Workspace attributes, for a HUD later: WatcherEvent (id while one is live, else nil),
-- WatcherEventEnd (server time it ends), WatcherHunger, WatcherNext (id of the next event).

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
	event: string,
}

type Handler = { start: () -> (), stop: () -> () }

local GroundTop = 0.1 -- top of the hub floor (see WorldBuilder)
local Group = "Hub:Event" -- RoamService group for event monsters
local FadeWaitMax = 10 -- seconds a monster being caught may stay after its event ends
local LightTween = TweenInfo.new(3, Enum.EasingStyle.Sine)

local random = Random.new()
local live: { [Model]: Spawned } = {}
local handlers: { [string]: Handler } = {}
local steps: { Watcher.Step } = {}
local hunger = 0
local nextIndex = 1
local current: Events.WatcherEvent? = nil
local endsAt = 0

-- Meter GUI pieces, set in buildMeter.
local meterFill: Frame? = nil
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

local saved: Saved = {}

local function tweenTo(instance: Instance, goal: { [string]: any })
	local before = saved[instance] or {}
	for property in goal do
		if before[property] == nil then
			before[property] = (instance :: any)[property]
		end
	end
	saved[instance] = before
	TweenService:Create(instance, LightTween, goal):Play()
end

local function restoreLighting()
	for instance, before in saved do
		if instance.Parent then
			TweenService:Create(instance, LightTween, before):Play()
		end
	end
	table.clear(saved)
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

handlers.Flicker = {
	start = function()
		tweenTo(Lighting, { ClockTime = 0, Brightness = Lighting.Brightness * 0.5 })
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
		restoreLighting()
	end,
}

handlers.BloodMoon = {
	start = function()
		local red = Color3.fromRGB(150, 30, 30)
		tweenTo(Lighting, { ClockTime = 0, OutdoorAmbient = red, Ambient = Color3.fromRGB(70, 20, 20) })

		local tint = temporary("ColorCorrectionEffect", "BloodMoonTint") :: ColorCorrectionEffect
		tint.TintColor = Color3.new(1, 1, 1)
		tint.Parent = Lighting
		TweenService:Create(tint, LightTween, { TintColor = Color3.fromRGB(255, 170, 170) }):Play()

		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere and atmosphere.Name ~= "BloodMoonAtmosphere" then
			tweenTo(atmosphere, { Color = Color3.fromRGB(190, 50, 50), Decay = Color3.fromRGB(100, 0, 0) })
		else
			local made = temporary("Atmosphere", "BloodMoonAtmosphere") :: Atmosphere
			made.Density = 0.35
			made.Haze = 1.5
			made.Glare = 0
			made.Color = Color3.fromRGB(190, 50, 50)
			made.Decay = Color3.fromRGB(100, 0, 0)
			made.Parent = Lighting
		end
	end,
	stop = function()
		restoreLighting()
		for _, name in { "BloodMoonTint", "BloodMoonAtmosphere" } do
			local made = Lighting:FindFirstChild(name)
			if made then
				-- Let the colours ease back first.
				task.delay(LightTween.Time, function()
					if current == nil or current.id ~= "BloodMoon" then
						made:Destroy()
					end
				end)
				if made:IsA("ColorCorrectionEffect") then
					TweenService:Create(made, LightTween, { TintColor = Color3.new(1, 1, 1) }):Play()
				end
			end
		end
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
	local radius = MonsterModel.radius(size.id)
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
-- Hunger and the event clock

local function publish()
	local step = steps[nextIndex]
	workspace:SetAttribute("WatcherHunger", math.floor(hunger))
	workspace:SetAttribute("WatcherNext", if step then step.event.id else nil)
	workspace:SetAttribute("WatcherEvent", if current then current.id else nil)
	workspace:SetAttribute("WatcherEventEnd", if current then endsAt else nil)

	local fill, text = meterFill, meterText
	if not fill or not text then
		return
	end
	local event = current
	if event then
		local left = endsAt - workspace:GetServerTimeNow()
		local duration = event.durationSeconds or 1
		fill.Size = UDim2.fromScale(math.clamp(left / duration, 0, 1), 1)
		fill.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
		text.Text = `{string.upper(event.name)}! {Watcher.clock(left)} left`
	elseif step then
		fill.Size = UDim2.fromScale(Watcher.meter(hunger, steps, nextIndex), 1)
		fill.BackgroundColor3 = Color3.fromRGB(150, 70, 220)
		text.Text = `Next: {step.event.name} ({math.floor(hunger)} / {step.threshold})`
	else
		fill.Size = UDim2.fromScale(0, 1)
		text.Text = "The Watcher sleeps"
	end
end

local function startEvent(step: Watcher.Step)
	local event = step.event
	current = event
	endsAt = workspace:GetServerTimeNow() + (event.durationSeconds or 120)
	Notify.toastAll(event.announce or `{event.name} has begun!`)

	xpcall(handlers[event.id].start, function(err)
		warn(`WatcherService: {event.id} failed to start its effects: {err}`)
	end)

	local rects = driftRects()
	for _ = 1, Watcher.monsterCount(#Players:GetPlayers()) do
		if not spawnOne(event, rects) then
			break -- too crowded
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
	xpcall(handlers[event.id].stop, function(err)
		warn(`WatcherService: {event.id} failed to clean up its effects: {err}`)
	end)
	for model, spawned in live do
		if spawned.event == event.id then
			task.spawn(fadeOut, model)
		end
	end
	Notify.toastAll(`{event.name} is over. The Watcher grows hungry again...`)

	nextIndex += 1
	if nextIndex > #steps then
		nextIndex = 1
		hunger = 0 -- a new cycle
	end
	publish()
end

local function playersInZones(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Zone") ~= nil then
			count += 1
		end
	end
	return count
end

local function tick(seconds: number)
	if current then
		if workspace:GetServerTimeNow() >= endsAt then
			endEvent()
		end
	else
		hunger += Watcher.gain(playersInZones(), seconds)
		local step = steps[nextIndex]
		if step and hunger >= step.threshold then
			startEvent(step)
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

local function buildMeter(hub: Instance)
	local part = World.part(World.find(hub, "WatcherMeter")) or buildMeterPart(hub)
	local existing = part:FindFirstChild("HungerMeter")
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HungerMeter"
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
	label("THE WATCHER'S HUNGER", 0, 0.3, true)

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromScale(0.05, 0.36)
	bar.Size = UDim2.fromScale(0.9, 0.26)
	bar.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
	bar.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bar
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(200, 180, 230)
	outline.Thickness = 2
	outline.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.fromRGB(150, 70, 220)
	corner:Clone().Parent = fill
	fill.Parent = bar
	bar.Parent = billboard

	meterFill = fill
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
-- effects from the hunter's tools, like SpawnService.capture). Nil if someone was faster.
function WatcherService.capture(model: Model, equippedItemIds: { string }): Value.CaughtMonster?
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
		effects = Spawning.rollCatchEffects(equippedItemIds, random),
		familiarity = 0,
		fed = true,
	}
end

-- The event playing right now, or nil. Mansion effect rolls (#11) read its
-- effectOddsMultiplier and effect from here.
function WatcherService.current(): Events.WatcherEvent?
	return current
end

-- Starts the next event right away (the "Summon an Event" developer product, #27, and the
-- /summon test command). False if an event is already playing.
function WatcherService.summon(): boolean
	local step = steps[nextIndex]
	if current or not step then
		return false
	end
	hunger = math.max(hunger, step.threshold)
	startEvent(step)
	return true
end

function WatcherService.start()
	local built: { [string]: boolean } = {}
	for id in handlers do
		built[id] = true
	end
	steps = Watcher.cycle(built)

	local hub = hubFolder()
	findLamps(hub)
	buildMeter(hub)
	publish()

	task.spawn(function()
		while true do
			local seconds = task.wait(1)
			-- One bad second must never stop the Watcher for good.
			xpcall(tick, function(err)
				warn(`WatcherService: {err}\n{debug.traceback()}`)
			end, seconds)
		end
	end)
end

return WatcherService
