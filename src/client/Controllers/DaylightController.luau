--!strict
-- A bright hub, dark zones (Config/Daylight). In the hub and on the mansion plots this
-- client eases Lighting and the Atmosphere to a sunny afternoon; in a zone (player attribute
-- Zone) and during a Watcher event (Workspace attribute WatcherSky) it eases them back to
-- the server's night. Only on this screen: the server's Lighting stays the night, and the
-- events' sky changes (server/Services/WatcherService) still play over the night as before.
--
-- The night values are copied once, while no event is on, before the day is ever drawn, so
-- going back always lands on the server's own night.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Daylight = require(Shared:WaitForChild("Config"):WaitForChild("Daylight"))

local DaylightController = {}

local player = Players.LocalPlayer

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- Config tables to tween goals (colours as Color3).
local function goalOf(values: { [string]: any }): { [string]: any }
	local goal = {}
	for key, value in values do
		goal[key] = if typeof(value) == "table" then rgb(value) else value
	end
	return goal
end

local DayLighting = goalOf(Daylight.Lighting :: any)
local DayAtmosphere = goalOf(Daylight.Atmosphere :: any)
local DayTint = goalOf(Daylight.Tint :: any)

-- The night's own Atmosphere (not the temporary one an event may add).
local function atmosphere(): Atmosphere?
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") and not string.find(child.Name, "WatcherSky") then
			return child
		end
	end
	return nil
end

-- The current values of the properties a goal names.
local function copy(instance: Instance, goal: { [string]: any }): { [string]: any }
	local values = {}
	for key in goal do
		values[key] = (instance :: any)[key]
	end
	return values
end

function DaylightController.start()
	if not Daylight.Enabled then
		return
	end
	local info = TweenInfo.new(Daylight.FadeSeconds, Enum.EasingStyle.Sine)
	local nightLighting: { [string]: any }? = nil
	local nightAtmosphere: { [string]: any }? = nil
	local nightOf: Atmosphere? = nil
	local isDay = false
	local tint: ColorCorrectionEffect? = nil
	local token = 0

	local function eventOn(): boolean
		return workspace:GetAttribute("WatcherSky") ~= nil
	end

	local function wantDay(): boolean
		return player:GetAttribute("Zone") == nil and not eventOn()
	end

	local function toDay()
		if not nightLighting then
			nightLighting = copy(Lighting, DayLighting)
			nightOf = atmosphere()
			nightAtmosphere = if nightOf then copy(nightOf, DayAtmosphere) else nil
		end
		isDay = true
		TweenService:Create(Lighting, info, DayLighting):Play()
		local current = atmosphere()
		if current then
			TweenService:Create(current, info, DayAtmosphere):Play()
		end
		if not tint then
			local made = Instance.new("ColorCorrectionEffect")
			made.Name = "HubDaylight"
			made.Parent = Lighting
			tint = made
		end
		TweenService:Create(tint :: ColorCorrectionEffect, info, DayTint):Play()
	end

	local function toNight()
		isDay = false
		if nightLighting then
			TweenService:Create(Lighting, info, nightLighting):Play()
		end
		if nightOf and nightAtmosphere and nightOf.Parent then
			TweenService:Create(nightOf, info, nightAtmosphere):Play()
		end
		if tint then
			TweenService:Create(tint, info, {
				Brightness = 0,
				Contrast = 0,
				Saturation = 0,
				TintColor = Color3.new(1, 1, 1),
			}):Play()
		end
	end

	-- Day or night for where the player is now. Coming back after an event waits for the
	-- server's own fade back to the night first.
	local function update(afterEvent: boolean?)
		token += 1
		local mine = token
		if not wantDay() then
			if isDay then
				toNight()
			end
			return
		end
		if isDay then
			return
		end
		if afterEvent or not nightLighting then
			-- The first copy of the night also waits a moment, in case an event just ended.
			task.delay(if afterEvent then Daylight.AfterEventSeconds else 0, function()
				if mine == token and wantDay() and not isDay then
					toDay()
				end
			end)
		else
			toDay()
		end
	end

	player:GetAttributeChangedSignal("Zone"):Connect(function()
		update(false)
	end)
	workspace:GetAttributeChangedSignal("WatcherSky"):Connect(function()
		update(not eventOn())
	end)
	update(false)
end

return DaylightController
