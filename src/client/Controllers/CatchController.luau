--!strict
-- Catch controls, the same with a mouse or a finger:
--   press and HOLD on a monster    your flashlight freezes it and the vacuum starts;
--                                  the catch meter fills by itself (about 1-3 seconds)
--   keep holding until it's full   caught! Bring it to the zone's Exit
--   let go early                   it gets away (but stays dazed for a moment, so try again)
-- No dragging and the camera never locks. The server decides everything (reach, vacuum
-- strength, timing, see server/Services/CatchService.luau); this only sends "start"/"stop"
-- and draws the meter.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local CatchController = {}

local player = Players.LocalPlayer

local RAY_LENGTH = 300 -- studs; the server checks the real reach
local TAP_SLACK = 28 -- pixels around an orb that still count as pressing it (fingers are big)
local BAR_MAX_WIDTH = 320

local pressing: InputObject? = nil -- the mouse button or finger currently held down on a monster
local target: Model? = nil -- the monster this press asked the server to catch (until let go)
local held: Model? = nil -- the monster the server says we're catching right now
local heldSeconds = 0 -- fallback timing if the model's attributes haven't arrived yet
local heldSince = 0

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

-- Every wild monster we can see right now (mansion pets are roamers too, but not catchable).
local function wildMonsters(): { Model }
	local result = {}
	for _, instance in CollectionService:GetTagged("Roamer") do
		if instance:IsA("Model") and instance:GetAttribute("Wild") == true and instance.PrimaryPart then
			table.insert(result, instance)
		end
	end
	return result
end

-- The wild monster under a screen position: first a ray that only looks at monsters (so
-- see-through walls don't get in the way), then the nearest orb within a few pixels of the
-- finger, because orbs can be small on a phone.
local function monsterAt(screenPosition: Vector3): Model?
	local camera = workspace.CurrentCamera
	local monsters = wildMonsters()
	if #monsters == 0 then
		return nil
	end

	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = monsters :: { any } -- a list of Models is a list of Instances
	local hit = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("Wild") == true then
			return model
		end
	end

	local best: Model? = nil
	local bestGap = math.huge
	local pointer = Vector2.new(screenPosition.X, screenPosition.Y)
	for _, model in monsters do
		local body = model.PrimaryPart :: BasePart
		local centre = body.Position
		if (centre - camera.CFrame.Position).Magnitude > RAY_LENGTH then
			continue
		end
		local screen, onScreen = camera:WorldToScreenPoint(centre)
		if not onScreen then
			continue
		end
		-- How big the orb looks on screen, from a point on its edge.
		local edge = camera:WorldToScreenPoint(centre + camera.CFrame.RightVector * (body.Size.X / 2))
		local radius = (Vector2.new(edge.X, edge.Y) - Vector2.new(screen.X, screen.Y)).Magnitude
		local gap = (Vector2.new(screen.X, screen.Y) - pointer).Magnitude - radius
		if gap <= TAP_SLACK and gap < bestGap then
			best = model
			bestGap = gap
		end
	end
	return best
end

-- The meter near the bottom: "Hold! Catching Wisp Jack" over a bar that fills up.
-- 320 pixels wide, or half the screen on small phones.
local function buildUi(): (Frame, TextLabel, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CatchUi"
	gui.ResetOnSpawn = false

	local meter = Instance.new("Frame")
	meter.Name = "Meter"
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.new(0.5, 0, 1, -150)
	meter.Size = UDim2.new(0.5, 0, 0, 62)
	meter.BackgroundTransparency = 1
	meter.Visible = false
	meter.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(BAR_MAX_WIDTH, math.huge)
	limit.Parent = meter

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.TextScaled = true
	title.Text = ""
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MaxTextSize = 26
	titleSize.Parent = title
	title.Parent = meter

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(1, 0, 0, 24)
	bar.BackgroundColor3 = Color3.fromRGB(30, 25, 40)
	bar.BorderSizePixel = 0
	bar.ClipsDescendants = true
	bar.Parent = meter
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = bar
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(1, 1, 1)
	outline.Thickness = 2
	outline.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 200, 70)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = fill

	gui.Parent = player:WaitForChild("PlayerGui")
	return meter, title, fill
end

-- 0 to 1: how full the meter is. Uses the server's CatchStart/CatchEnd on the model.
local function progress(model: Model): number
	local startTime = model:GetAttribute("CatchStart")
	local endTime = model:GetAttribute("CatchEnd")
	if typeof(startTime) == "number" and typeof(endTime) == "number" and endTime > startTime then
		return math.clamp((workspace:GetServerTimeNow() - startTime) / (endTime - startTime), 0, 1)
	end
	if heldSeconds > 0 then
		return math.clamp((os.clock() - heldSince) / heldSeconds, 0, 1)
	end
	return 0
end

local EMPTY_COLOR = Color3.fromRGB(255, 200, 70)
local FULL_COLOR = Color3.fromRGB(120, 255, 140)

function CatchController.start()
	local remotes = ReplicatedStorage:WaitForChild("CatchRemotes")
	local StartCatch = remotes:WaitForChild("StartCatch") :: RemoteEvent
	local StopCatch = remotes:WaitForChild("StopCatch") :: RemoteEvent
	local State = remotes:WaitForChild("State") :: RemoteEvent

	local meter, title, fill = buildUi()

	-- The finger or button came up (or the window lost focus): stop if we started anything.
	local function letGo()
		local wasCatching = target ~= nil or held ~= nil
		pressing = nil
		target = nil
		held = nil
		meter.Visible = false
		if wasCatching then
			StopCatch:FireServer()
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		-- A finger whose release never arrived (it can happen on some phones) would otherwise
		-- block every new press.
		local current = pressing
		if
			current
			and (
				current.UserInputState == Enum.UserInputState.End
				or current.UserInputState == Enum.UserInputState.Cancel
			)
		then
			letGo()
		end
		if processed or not isPointer(input) or pressing then
			return
		end
		local model = monsterAt(input.Position)
		if not model then
			return
		end
		pressing = input
		target = model
		StartCatch:FireServer(model)
	end)

	UserInputService.InputEnded:Connect(function(input)
		local current = pressing
		if not current then
			return
		end
		local isSameTouch = rawequal(input, current)
		local isMouseRelease = current.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseButton1
		if isSameTouch or isMouseRelease then
			letGo()
		end
	end)

	-- Alt-tabbing away while holding the mouse never sends a release, so count it as one.
	UserInputService.WindowFocusReleased:Connect(function()
		if pressing then
			letGo()
		end
	end)

	State.OnClientEvent:Connect(function(kind: unknown, info: unknown)
		if kind == "Holding" then
			local model = if typeof(info) == "table" then (info :: any).model else nil
			local seconds = if typeof(info) == "table" then (info :: any).seconds else nil
			if not pressing then
				-- Let go before the server answered: stop straight away.
				StopCatch:FireServer()
				return
			end
			if typeof(model) ~= "Instance" or not model:IsA("Model") or model ~= target then
				-- An answer for an older press that we already stopped; ignore it.
				return
			end
			held = model
			heldSeconds = if typeof(seconds) == "number" then seconds else 0
			heldSince = os.clock()
			local monsterId = model:GetAttribute("MonsterId")
			local name = if typeof(monsterId) == "string" then Format.name(monsterId) else model.Name
			title.Text = `Hold! Catching {name}`
			fill.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = EMPTY_COLOR
			meter.Visible = true
		elseif kind == "Ended" then
			-- Caught, escaped or gone; the server sends a message saying which.
			-- An end for an older press (a quick re-tap on another monster) must not cancel
			-- the new one. A caught monster is already gone, so it arrives as nil.
			local model = if typeof(info) == "table" then (info :: any).model else nil
			if typeof(model) == "Instance" and model ~= target then
				return
			end
			-- target stays set until the press ends, so letting go still sends StopCatch
			-- (the server ignores it when nothing is being caught).
			held = nil
			meter.Visible = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		local model = held
		if not model then
			return
		end
		if not model.Parent then
			-- Caught (or vanished); wait for the server's "Ended" but hide the meter now.
			meter.Visible = false
			return
		end
		local amount = progress(model)
		fill.Size = UDim2.fromScale(amount, 1)
		fill.BackgroundColor3 = EMPTY_COLOR:Lerp(FULL_COLOR, amount)
	end)
end

return CatchController
