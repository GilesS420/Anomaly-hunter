--!strict
-- Catch controls, the same with a mouse or a finger:
--   click or tap a monster         your vacuum's beam freezes it, and the catch meter fills
--                                  by itself (about 1-3 seconds); no need to hold
--   it struggles                   the meter stops and a needle sweeps over a bar: click or
--                                  tap anywhere (or press F) while it's in the green zone.
--                                  Miss and it breaks free, dazed for a moment, so try again
--                                  (Config/Struggles)
--   the Lucky Ring (rare and        a ring shrinks onto a gold circle: click or tap (or F) as
--   event monsters)                it lines up and the catch lands at once, with a better
--                                  shot at a Silver or Gold variant. Miss and the meter drops
--                                  back to half
--   the meter is full              caught! Bring it to the zone's Exit
--   walk out of reach              it gets away
-- Only with a vacuum in your hand (or nothing, so the server can say to pick one): a press
-- while holding a cake, a monster or the Bait Bell is that item's click, not a catch.
-- No dragging and the camera never locks. The server decides everything (reach, vacuum
-- strength, timing, see server/Services/CatchService.luau); this only sends "start" and
-- "tapped at" and draws the meter.
-- So clicks never feel late, the meter doesn't wait for the server's answer: a click on a
-- monster flashes it and shows the meter at once. Each struggle (and the Lucky Ring) starts
-- here the moment the meter gets there, timed by this client's own clock, and a tap is judged
-- here against the needle as it was on screen (Util/Catching), then sent as "this far into
-- stop N". The server keeps the same timeline and only checks the number is possible for the
-- player's lag, so a good tap stays good on a slow connection (Giles 2026-11-12). The
-- server's answer still wins if it disagrees.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catching = require(Shared:WaitForChild("Util"):WaitForChild("Catching"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Struggles = require(Shared:WaitForChild("Config"):WaitForChild("Struggles"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))

local CatchController = {}

local player = Players.LocalPlayer

local RAY_LENGTH = 300 -- studs; the server checks the real reach
local TAP_SLACK = 28 -- pixels around an orb that still count as pressing it (fingers are big)
local BAR_MAX_WIDTH = 320
local PENDING_SECONDS = 1 -- hide the meter shown for a click if the server hasn't answered by then

local target: Model? = nil -- the monster the last click asked the server to catch
local held: Model? = nil -- the monster the server says we're catching right now
local heldSeconds = 0 -- fallback timing if the model's attributes haven't arrived yet
local heldSince = 0
-- The struggle going on now, or nil. startedAt is on the synced clock
-- (workspace:GetServerTimeNow()), worked out here from the meter; index is its stop number.
local struggle: { index: number, startedAt: number, speed: number, centre: number, width: number, timeout: number }? =
	nil
local struck = false -- tapped during this struggle (or ring), waiting for the server
-- The Lucky Ring that's up now, or nil.
local ring: { index: number, startedAt: number }? = nil
-- Seconds into the struggle (or ring) of the needle (or ring) last drawn: a tap is judged
-- against what was on screen, not against a moment later.
local shownSeconds = 0
-- Where the meter stops for the struggles and then the ring (0 to 1, from the server), and
-- which of them is next (its stop number).
local stops: { number } = {}
local nextStop = 1
-- The catch's struggles, from the server's "Holding": the zone of each one, the needle's
-- speed, the zone's width, the seconds before it breaks free, and whether the ring comes last.
local centres: { number } = {}
local plan = { speed = 1, width = 0.3, timeout = 4, ring = false }
-- Set when a tap here already ended the struggle (or missed the ring): the meter fills on from
-- `from` at server time `at` without waiting for the server's attributes.
local resume: { from: number, at: number }? = nil
local pendingSince: number? = nil -- os.clock() of the click whose answer we're waiting for

-- True unless the hand holds a Tool that isn't a vacuum.
local function handFree(): boolean
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	return tool == nil or tool:GetAttribute("VacuumId") ~= nil
end

-- Whether this vacuum is too weak for the monster (from the size and rarity on its model).
local function tooWeak(model: Model, vacuumId: string): boolean
	local sizeId = model:GetAttribute("Size")
	local rarityId = model:GetAttribute("Rarity")
	local monsterId = model:GetAttribute("MonsterId")
	if typeof(sizeId) ~= "string" or typeof(rarityId) ~= "string" then
		return false
	end
	local id = if typeof(monsterId) == "string" then monsterId else nil
	return Catching.vacuumNeeded(vacuumId, sizeId, rarityId, id) ~= nil
end

-- Whether the server will most likely start this catch: a vacuum in hand, the monster within
-- its reach, and a vacuum strong enough for it. Only decides whether the meter shows before
-- the answer comes; the server still decides (and sends the "Too strong!" toast).
local function likelyCatch(model: Model): boolean
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	local vacuumId = if tool then tool:GetAttribute("VacuumId") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local body = model.PrimaryPart
	if typeof(vacuumId) ~= "string" or not root or not root:IsA("BasePart") or not body then
		return false
	end
	if (root.Position - body.Position).Magnitude > Catching.reach(vacuumId) then
		return false
	end
	return not tooWeak(model, vacuumId)
end

-- A quick flash on the clicked monster, so the click shows the moment it lands.
local function flash(model: Model)
	local glow = Instance.new("Highlight")
	glow.Name = "CatchClick"
	glow.FillColor = Color3.fromRGB(255, 245, 180)
	glow.FillTransparency = 0.4
	glow.OutlineColor = Color3.fromRGB(255, 245, 180)
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = model
	local fade =
		TweenService:Create(glow, TweenInfo.new(0.35), { FillTransparency = 1, OutlineTransparency = 1 })
	fade.Completed:Connect(function()
		glow:Destroy()
	end)
	fade:Play()
end

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

-- The meter near the bottom: "Catching Wisp Jack..." over a bar that fills up.
-- 320 pixels wide, or half the screen on small phones.
type Ui = {
	meter: Frame,
	title: TextLabel,
	fill: Frame,
	track: Frame,
	zone: Frame,
	needle: Frame,
	ring: Frame, -- the Lucky Ring: the gold circle and the ring shrinking onto it
	shrinking: Frame,
}

local RING_SIZE = 90 -- pixels: the gold circle

local function circle(name: string, color: Color3, thickness: number, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(RING_SIZE, RING_SIZE)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = frame
	return frame
end

local function buildUi(): Ui
	local gui = Instance.new("ScreenGui")
	local canvas = Scale.canvas(gui) -- shrinks everything to fit a phone (client/Scale)
	gui.Name = "CatchUi"
	gui.ResetOnSpawn = false

	local meter = Instance.new("Frame")
	meter.Name = "Meter"
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.new(0.5, 0, 1, -150)
	meter.Size = UDim2.new(0.5, 0, 0, 62)
	meter.BackgroundTransparency = 1
	meter.Visible = false
	meter.Parent = canvas
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(BAR_MAX_WIDTH, math.huge)
	limit.Parent = meter

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
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

	-- The struggle bar, above the meter: a dark track, the glowing zone and the needle.
	local track = Instance.new("Frame")
	track.Name = "Struggle"
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.new(0, 0, 0, -8)
	track.Size = UDim2.new(1, 0, 0, 30)
	track.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
	track.BorderSizePixel = 0
	track.Visible = false
	track.Parent = meter
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 8)
	trackCorner.Parent = track
	local trackOutline = Instance.new("UIStroke")
	trackOutline.Color = Color3.fromRGB(255, 120, 120)
	trackOutline.Thickness = 2
	trackOutline.Parent = track

	local zone = Instance.new("Frame")
	zone.Name = "Zone"
	zone.AnchorPoint = Vector2.new(0.5, 0)
	zone.Size = UDim2.fromScale(0.3, 1)
	zone.BackgroundColor3 = Color3.fromRGB(120, 255, 140)
	zone.BackgroundTransparency = 0.15
	zone.BorderSizePixel = 0
	zone.Parent = track

	local needle = Instance.new("Frame")
	needle.Name = "Needle"
	needle.AnchorPoint = Vector2.new(0.5, 0.5)
	needle.Position = UDim2.fromScale(0, 0.5)
	needle.Size = UDim2.new(0, 6, 1, 10)
	needle.BackgroundColor3 = Color3.new(1, 1, 1)
	needle.BorderSizePixel = 0
	needle.ZIndex = 2
	needle.Parent = track
	local needleStroke = Instance.new("UIStroke")
	needleStroke.Thickness = 1.5
	needleStroke.Parent = needle

	-- The Lucky Ring, above the meter: a gold circle and a white ring shrinking onto it.
	local ring = Instance.new("Frame")
	ring.Name = "LuckyRing"
	ring.AnchorPoint = Vector2.new(0.5, 1)
	ring.Position = UDim2.new(0.5, 0, 0, -50)
	ring.Size = UDim2.fromOffset(RING_SIZE, RING_SIZE)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.Parent = meter
	local gold = circle("Gold", Color3.fromRGB(255, 200, 60), 8, ring)
	gold.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	gold.BackgroundTransparency = 0.75
	local shrinking = circle("Shrinking", Color3.new(1, 1, 1), 4, ring)
	shrinking.ZIndex = 2

	gui.Parent = player:WaitForChild("PlayerGui")
	return {
		meter = meter,
		title = title,
		fill = fill,
		track = track,
		zone = zone,
		needle = needle,
		ring = ring,
		shrinking = shrinking,
	}
end

-- Seconds of filling the whole meter takes.
local function totalSeconds(model: Model): number
	local startTime = model:GetAttribute("CatchStart")
	local endTime = model:GetAttribute("CatchEnd")
	if typeof(startTime) == "number" and typeof(endTime) == "number" and endTime > startTime then
		return endTime - startTime
	end
	return heldSeconds
end

-- The synced-clock time the meter was (or would have been) empty on its current run, so the
-- meter is (now - base) / total full: from our own tap if we just ended a struggle, otherwise
-- from the server's CatchStart. Nil until the server's attributes are here.
local function fillBase(model: Model): number?
	local total = totalSeconds(model)
	local predicted = resume
	if predicted and total > 0 then
		return predicted.at - predicted.from * total
	end
	local startTime = model:GetAttribute("CatchStart")
	local endTime = model:GetAttribute("CatchEnd")
	if typeof(startTime) == "number" and typeof(endTime) == "number" and endTime > startTime then
		return startTime
	end
	return nil
end

-- 0 to 1: how full the meter is. It never runs past the next stop, so it waits there for the
-- struggle instead of running on and jumping back.
local function progress(model: Model): number
	local amount = 0
	local base = fillBase(model)
	local total = totalSeconds(model)
	if base and total > 0 then
		amount = (workspace:GetServerTimeNow() - base) / total
	else
		local paused = model:GetAttribute("CatchPaused")
		if typeof(paused) == "number" then
			return paused
		elseif heldSeconds > 0 then
			amount = (os.clock() - heldSince) / heldSeconds
		end
	end
	local stop = stops[nextStop]
	if stop then
		amount = math.min(amount, stop)
	end
	return math.clamp(amount, 0, 1)
end

-- The synced-clock time the meter reaches the next stop, or nil if it isn't known yet.
local function nextStopAt(model: Model): number?
	local stop = stops[nextStop]
	local base = fillBase(model)
	local total = totalSeconds(model)
	if not stop or not base or total <= 0 then
		return nil
	end
	return base + stop * total
end

local EMPTY_COLOR = Color3.fromRGB(255, 200, 70)
local FULL_COLOR = Color3.fromRGB(120, 255, 140)

function CatchController.start()
	local remotes = ReplicatedStorage:WaitForChild("CatchRemotes")
	local StartCatch = remotes:WaitForChild("StartCatch") :: RemoteEvent
	local State = remotes:WaitForChild("State") :: RemoteEvent

	local Strike = remotes:WaitForChild("Strike") :: RemoteEvent
	local ui = buildUi()
	local meter, title, fill, track, zone, needle = ui.meter, ui.title, ui.fill, ui.track, ui.zone, ui.needle
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local holdText = ""

	local function endStruggle()
		struggle = nil
		ring = nil
		struck = false
		track.Visible = false
		ui.ring.Visible = false
	end

	local function stopShowing()
		target = nil
		held = nil
		pendingSince = nil
		resume = nil
		stops = {}
		nextStop = 1
		centres = {}
		meter.Visible = false
		endStruggle()
	end

	-- Stop number `index` is over: the meter may run on to the next stop. Called by our own
	-- judgement and again by the server's, but counts once.
	local function passStop(index: number)
		if nextStop == index then
			nextStop += 1
		end
	end

	local strugglingText = if touch
		then "It's struggling! TAP when the needle is in the green!"
		else "It's struggling! CLICK (or F) when the needle is in the green!"
	local ringText = if touch
		then "LUCKY RING! TAP when the rings line up!"
		else "LUCKY RING! CLICK (or F) when the rings line up!"

	-- Starts stop number `index` (a struggle, or the ring after the last one) from synced-clock
	-- time `startedAt`: the moment the meter got there.
	local function beginStop(index: number, startedAt: number)
		struck = false
		shownSeconds = math.max(workspace:GetServerTimeNow() - startedAt, 0)
		if index <= #centres then
			local active = {
				index = index,
				startedAt = startedAt,
				speed = plan.speed,
				centre = centres[index],
				width = plan.width,
				timeout = plan.timeout,
			}
			struggle = active
			ring = nil
			needle.BackgroundColor3 = Color3.new(1, 1, 1)
			needle.Position = UDim2.fromScale(Catching.needle(shownSeconds, active.speed), 0.5)
			zone.Position = UDim2.fromScale(active.centre, 0)
			zone.Size = UDim2.fromScale(active.width, 1)
			track.Visible = true
			ui.ring.Visible = false
			title.Text = strugglingText
		else
			ring = { index = index, startedAt = startedAt }
			struggle = nil
			track.Visible = false
			local scale = Catching.ringScale(shownSeconds)
			ui.shrinking.Size = UDim2.fromOffset(RING_SIZE * scale, RING_SIZE * scale)
			ui.ring.Visible = true
			title.Text = ringText
		end
	end

	-- Missed the Lucky Ring (a wrong tap, or none in time): the meter drops back to half and
	-- fills on from `at`. The server's "Ringed" follows.
	local function missRing(model: Model, index: number, at: number)
		resume = { from = math.min(progress(model), Struggles.Ring.fallBack), at = at }
		passStop(index)
		endStruggle()
		title.Text = holdText
	end

	-- A tap during a struggle or the Lucky Ring, judged right here so it shows at once, against
	-- the needle (or ring) as it was last drawn.
	local function strike(model: Model)
		local current, lucky = struggle, ring
		local seconds = shownSeconds
		struck = true
		if current then
			Strike:FireServer(current.index, seconds)
			local hit = seconds <= current.timeout
				and Catching.struggleHit(seconds, current.speed, current.centre, current.width)
			if hit then
				-- The meter fills on straight away; the server confirms with "Struggled".
				resume = { from = progress(model), at = current.startedAt + seconds }
				passStop(current.index)
				endStruggle()
				struck = true -- still waiting for the server; no second tap
				title.Text = holdText
			else
				-- It broke free; the server's "Ended" and message follow.
				needle.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
				title.Text = "It broke free!"
			end
		elseif lucky then
			Strike:FireServer(lucky.index, seconds)
			if Catching.ringHit(seconds) then
				fill.Size = UDim2.fromScale(1, 1)
				fill.BackgroundColor3 = FULL_COLOR
				resume = { from = 1, at = lucky.startedAt + seconds }
				passStop(lucky.index)
				endStruggle()
				title.Text = "PERFECT CATCH!"
			else
				missRing(model, lucky.index, lucky.startedAt + seconds)
			end
			struck = true
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if held then
			-- Catching: the meter fills by itself. Mid-struggle any click or tap (or F) is the
			-- tap; other clicks do nothing, so they can't start a second catch.
			local key = input.KeyCode == Enum.KeyCode.F
			-- A click counts even over a button (the struggle says "click anywhere"); a
			-- finger on the thumbstick or jump button, or F while typing in chat, doesn't.
			local mouse = input.UserInputType == Enum.UserInputType.MouseButton1
			local counts = (key and not processed) or mouse or (isPointer(input) and not processed)
			if (struggle or ring) and not struck and counts then
				strike(held)
			end
			return
		end
		if processed or not isPointer(input) or not handFree() then
			return
		end
		local model = monsterAt(input.Position)
		if not model then
			return
		end
		target = model
		StartCatch:FireServer(model)
		-- Show it straight away instead of after the server's answer. A vacuum that's too weak
		-- shows nothing here: the server's "Too strong!" toast is the only answer.
		if likelyCatch(model) then
			flash(model)
			local monsterId = model:GetAttribute("MonsterId")
			local name = if typeof(monsterId) == "string" then Format.name(monsterId) else model.Name
			holdText = `Catching {name}...`
			title.Text = holdText
			fill.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = EMPTY_COLOR
			meter.Visible = true
			pendingSince = os.clock()
		end
	end)

	State.OnClientEvent:Connect(function(kind: unknown, info: unknown)
		if kind == "Holding" then
			local model = if typeof(info) == "table" then (info :: any).model else nil
			local seconds = if typeof(info) == "table" then (info :: any).seconds else nil
			if typeof(model) ~= "Instance" or not model:IsA("Model") or model ~= target then
				-- An answer for an older press that we already stopped; ignore it.
				return
			end
			held = model
			pendingSince = nil
			resume = nil
			endStruggle()
			heldSeconds = if typeof(seconds) == "number" then seconds else 0
			heldSince = os.clock()
			stops = {}
			nextStop = 1
			centres = {}
			local data = info :: any
			if typeof(data.stops) == "table" then
				for _, stop in data.stops do
					if typeof(stop) == "number" then
						table.insert(stops, stop)
					end
				end
			end
			if typeof(data.centres) == "table" then
				for _, centre in data.centres do
					if typeof(centre) == "number" then
						table.insert(centres, centre)
					end
				end
			end
			plan = {
				speed = tonumber(data.speed) or 1,
				width = tonumber(data.width) or 0.3,
				timeout = tonumber(data.timeout) or Struggles.TimeoutSeconds,
				ring = data.ring == true,
			}
			local monsterId = model:GetAttribute("MonsterId")
			local name = if typeof(monsterId) == "string" then Format.name(monsterId) else model.Name
			holdText = `Catching {name}...`
			title.Text = holdText
			fill.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = EMPTY_COLOR
			meter.Visible = true
		elseif kind == "Struggle" or kind == "Ring" then
			-- Normally we started it already, the moment our meter got there. This is for
			-- when the server's meter got there first; it also catches up a late "Holding".
			local data = if typeof(info) == "table" then info :: any else nil
			if not data or data.model ~= held then
				return
			end
			local index = tonumber(data.index)
			if not index or index ~= nextStop or struggle or ring then
				return
			end
			if kind == "Struggle" and typeof(data.centre) == "number" then
				centres[index] = data.centre
			end
			resume = nil
			beginStop(index, tonumber(data.startedAt) or workspace:GetServerTimeNow())
		elseif kind == "Struggled" or kind == "Ringed" then
			local data = if typeof(info) == "table" then info :: any else nil
			if not data or data.model ~= held then
				return
			end
			local index = tonumber(data.index) or nextStop
			local current = struggle or ring
			if current and current.index == index then
				endStruggle()
			end
			passStop(index)
			-- The server's CatchStart says where the meter is from here on.
			resume = nil
			if kind == "Ringed" and (data :: any).hit == true then
				title.Text = "PERFECT CATCH!"
			else
				title.Text = holdText
			end
		elseif kind == "Ended" then
			-- Caught, escaped or gone; the server sends a message saying which.
			-- An end for an older press (a quick re-tap on another monster) must not cancel
			-- the new one. A caught monster is already gone, so it arrives as nil.
			local model = if typeof(info) == "table" then (info :: any).model else nil
			if typeof(model) == "Instance" and model ~= target then
				return
			end
			stopShowing()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local model = held
		if not model then
			-- The meter shown for a click: hide it if the server said no (its message explains why).
			if pendingSince and os.clock() - pendingSince > PENDING_SECONDS then
				pendingSince = nil
				meter.Visible = false
			end
			return
		end
		if not model.Parent then
			-- Caught (or vanished); wait for the server's "Ended" but hide the meter now.
			meter.Visible = false
			return
		end
		local now = workspace:GetServerTimeNow()
		if not struggle and not ring then
			-- The meter got to the next stop: start that struggle (or the ring) right here.
			local at = nextStopAt(model)
			if at and at <= now and nextStop <= #centres + (if plan.ring then 1 else 0) then
				beginStop(nextStop, at)
			end
		end
		local current = struggle
		if current then
			shownSeconds = math.max(now - current.startedAt, 0)
			needle.Position = UDim2.fromScale(Catching.needle(shownSeconds, current.speed), 0.5)
			if not struck and shownSeconds > current.timeout then
				-- Waited too long: it breaks free (the server's "Ended" follows).
				struck = true
				needle.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
				title.Text = "It broke free!"
			end
		end
		local lucky = ring
		if lucky then
			shownSeconds = math.max(now - lucky.startedAt, 0)
			local scale = Catching.ringScale(shownSeconds)
			ui.shrinking.Size = UDim2.fromOffset(RING_SIZE * scale, RING_SIZE * scale)
			if not struck and shownSeconds > Struggles.Ring.seconds then
				missRing(model, lucky.index, lucky.startedAt + Struggles.Ring.seconds)
			end
		end
		local amount = progress(model)
		fill.Size = UDim2.fromScale(amount, 1)
		fill.BackgroundColor3 = EMPTY_COLOR:Lerp(FULL_COLOR, amount)
	end)
end

return CatchController
