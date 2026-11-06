--!strict
-- A bright hub and dark zones (Config/AreaLight). Picks the look from where this player is
-- (their Zone attribute, set by HuntService) and whether a Watcher event sky is showing
-- (Workspace attribute WatcherSky), then blends this client's Lighting to it:
--   into or out of a zone   at once (you've just gone through a portal)
--   an event coming         over the warning, so the sun has set when the event starts
--   an event over           after the server's own sky has faded back, over FadeSeconds
-- Only ClockTime, ExposureCompensation and our own "AreaLight" ColorCorrectionEffect are
-- touched; everything the server sets on Lighting is left alone.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AreaLight = require(ReplicatedStorage.Shared.Config.AreaLight)

type Look = AreaLight.Look

local AreaLightController = {}

local player = Players.LocalPlayer

local effect: ColorCorrectionEffect
local current: Look -- what's on screen now
local from: Look
local to: Look
local toName = ""
local startedAt = 0
local duration = 0
local blending = false
local pending: thread? -- a fade waiting for the server's sky to go

local function copy(look: Look): Look
	return table.clone(look)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function blend(a: Look, b: Look, t: number): Look
	return {
		clockTime = lerp(a.clockTime, b.clockTime, t),
		exposure = lerp(a.exposure, b.exposure, t),
		brightness = lerp(a.brightness, b.brightness, t),
		contrast = lerp(a.contrast, b.contrast, t),
		saturation = lerp(a.saturation, b.saturation, t),
		tint = {
			lerp(a.tint[1], b.tint[1], t),
			lerp(a.tint[2], b.tint[2], t),
			lerp(a.tint[3], b.tint[3], t),
		},
	}
end

local function apply(look: Look)
	current = look
	Lighting.ClockTime = look.clockTime % 24
	Lighting.ExposureCompensation = look.exposure
	effect.Brightness = look.brightness
	effect.Contrast = look.contrast
	effect.Saturation = look.saturation
	effect.TintColor = Color3.fromRGB(look.tint[1], look.tint[2], look.tint[3])
end

local function goTo(name: string, seconds: number)
	local look = AreaLight.Looks[name]
	if not look then
		return
	end
	toName = name
	if seconds <= 0 then
		blending = false
		apply(copy(look))
		return
	end
	from = copy(current)
	to = look
	startedAt = os.clock()
	duration = seconds
	blending = true
end

local function step()
	if not blending then
		return
	end
	local t = math.clamp((os.clock() - startedAt) / duration, 0, 1)
	-- Ease in and out, like the server's Sine tweens.
	apply(blend(from, to, 0.5 - math.cos(t * math.pi) / 2))
	if t >= 1 then
		blending = false
	end
end

local function warningLeft(): number
	local skyAt = workspace:GetAttribute("WatcherSkyAt")
	if typeof(skyAt) == "number" then
		return math.max(skyAt - workspace:GetServerTimeNow(), 3)
	end
	return AreaLight.FadeSeconds
end

local function update(reason: "zone" | "sky" | "start")
	local inZone = player:GetAttribute("Zone") ~= nil
	local eventSky = workspace:GetAttribute("WatcherSky") ~= nil
	local name = AreaLight.lookFor(inZone, eventSky)
	if pending then
		task.cancel(pending)
		pending = nil
	end
	if name == toName then
		return
	end
	if reason ~= "sky" then
		goTo(name, 0) -- joining, or through a portal: no fade
	elseif name == "HubEvent" then
		goTo(name, warningLeft())
	else
		-- The event is over: let the server's sky fade back first, then bring the sun up.
		pending = task.delay(AreaLight.AfterEventDelay, function()
			pending = nil
			goTo(name, AreaLight.FadeSeconds)
		end)
	end
end

function AreaLightController.start()
	local existing = Lighting:FindFirstChild("AreaLight")
	if existing then
		existing:Destroy()
	end
	effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "AreaLight"
	effect.Parent = Lighting
	current = copy(AreaLight.Looks.Zone)

	player:GetAttributeChangedSignal("Zone"):Connect(function()
		update("zone")
	end)
	workspace:GetAttributeChangedSignal("WatcherSky"):Connect(function()
		update("sky")
	end)
	update("start")
	RunService.RenderStepped:Connect(step)
end

return AreaLightController
