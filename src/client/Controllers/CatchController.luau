--!strict
-- Catch controls, the same with a mouse or a finger:
--   click / tap a monster          shine the flashlight on it (stuns it)
--   press and hold a stunned one   vacuum it; the camera holds still
--   drag left or right             keep the knob on the side the arrow points to,
--                                  against the monster's yank, to fill the meter
--   let go                         stop vacuuming (it gets away)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CatchController = {}

local player = Players.LocalPlayer

local BAR_WIDTH = 320
local DEAD_ZONE = 24 -- pixels from the middle before a drag counts as pulling

local held: Model? = nil
local pointer: InputObject? = nil -- the mouse button or finger that started the vacuum
local startX = 0
local pointerX = 0
local sentPull = 0
local savedCameraType: Enum.CameraType? = nil

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function monsterAt(screenPosition: Vector3): Model?
	local camera = workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("MonsterId") then
		return model
	end
	return nil
end

local function isStunned(model: Model): boolean
	local until_ = model:GetAttribute("StunnedUntil")
	return typeof(until_) == "number" and until_ > workspace:GetServerTimeNow()
end

-- Freeze the camera while vacuuming so dragging moves the knob, not the view.
local function freezeCamera(frozen: boolean)
	local camera = workspace.CurrentCamera
	if frozen and savedCameraType == nil then
		savedCameraType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
	elseif not frozen and savedCameraType then
		camera.CameraType = savedCameraType
		savedCameraType = nil
	end
end

-- Meter, drag bar and message. Placeholder until the HUD pass (#28).
local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CatchUi"
	gui.ResetOnSpawn = false

	local meter = Instance.new("Frame")
	meter.Name = "Meter"
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.new(0.5, 0, 1, -150)
	meter.Size = UDim2.fromOffset(BAR_WIDTH, 18)
	meter.BackgroundColor3 = Color3.fromRGB(30, 25, 40)
	meter.Visible = false
	meter.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(140, 255, 160)
	fill.BorderSizePixel = 0
	fill.Parent = meter

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 1)
	arrow.Position = UDim2.new(0.5, 0, 0, -4)
	arrow.Size = UDim2.fromOffset(BAR_WIDTH, 36)
	arrow.BackgroundTransparency = 1
	arrow.TextColor3 = Color3.new(1, 1, 1)
	arrow.TextStrokeTransparency = 0
	arrow.TextScaled = true
	arrow.Font = Enum.Font.GothamBlack
	arrow.Parent = meter

	-- The drag bar: the knob follows your mouse or finger left and right.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 1, 16)
	track.Size = UDim2.fromOffset(BAR_WIDTH, 6)
	track.BackgroundColor3 = Color3.fromRGB(90, 80, 110)
	track.BorderSizePixel = 0
	track.Parent = meter
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromOffset(28, 28)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = track
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = knob

	local message = Instance.new("TextLabel")
	message.Name = "Message"
	message.AnchorPoint = Vector2.new(0.5, 0)
	message.Position = UDim2.new(0.5, 0, 0, 80)
	message.Size = UDim2.fromOffset(500, 40)
	message.BackgroundTransparency = 1
	message.TextColor3 = Color3.new(1, 1, 1)
	message.TextStrokeTransparency = 0
	message.TextScaled = true
	message.Font = Enum.Font.GothamBold
	message.Text = ""
	message.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	return meter, fill, arrow, knob, message
end

function CatchController.start()
	local remotes = ReplicatedStorage:WaitForChild("CatchRemotes")
	local Shine = remotes:WaitForChild("Shine") :: RemoteEvent
	local VacuumStart = remotes:WaitForChild("VacuumStart") :: RemoteEvent
	local VacuumStop = remotes:WaitForChild("VacuumStop") :: RemoteEvent
	local Pull = remotes:WaitForChild("Pull") :: RemoteEvent
	local Result = remotes:WaitForChild("Result") :: RemoteEvent

	local meter, fill, arrow, knob, message = buildUi()
	local messageToken = 0
	local function say(text: string)
		messageToken += 1
		local token = messageToken
		message.Text = text
		task.delay(2.5, function()
			if token == messageToken then
				message.Text = ""
			end
		end)
	end

	local function stopHolding()
		held = nil
		pointer = nil
		freezeCamera(false)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not isPointer(input) or pointer then
			return
		end
		local target = monsterAt(input.Position)
		if not target then
			return
		end
		if isStunned(target) then
			pointer = input
			startX = input.Position.X
			pointerX = startX
			VacuumStart:FireServer(target)
		else
			Shine:FireServer(target)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not pointer then
			return
		end
		local isSameTouch = input == pointer
		local isMouseMove = pointer.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseMovement
		if isSameTouch or isMouseMove then
			pointerX = input.Position.X
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not pointer then
			return
		end
		local isSameTouch = input == pointer
		local isMouseRelease = pointer.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseButton1
		if isSameTouch or isMouseRelease then
			if held then
				VacuumStop:FireServer()
			end
			stopHolding()
		end
	end)

	Result.OnClientEvent:Connect(function(kind: string, monsterId: string?, info: any)
		if kind == "Holding" then
			if pointer then
				held = info.model
				sentPull = 0
				freezeCamera(true)
			else
				-- Let go before the server answered.
				VacuumStop:FireServer()
			end
		else
			stopHolding()
		end
		if kind == "Caught" then
			local effects = if info and #info.effects > 0
				then " + " .. table.concat(info.effects, ", ")
				else ""
			say(`Caught a {info and info.size or ""} {monsterId}{effects}! Bring it back to the exit.`)
		elseif kind == "VacuumFull" then
			say("Your vacuum is full. Bring your catch home first!")
		elseif kind == "Escaped" then
			say(`{monsterId} broke free!`)
		elseif kind == "NotStunned" then
			say("Tap it once to stun it with your flashlight first")
		elseif kind == "TooStrong" then
			say(`Too strong! You need a tier {info and info.needTier or "?"} vacuum.`)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local model = held
		if not model or not model.Parent or model:GetAttribute("HeldBy") ~= player.UserId then
			meter.Visible = false
			return
		end
		meter.Visible = true
		local progress = model:GetAttribute("CatchProgress")
		fill.Size = UDim2.fromScale(if typeof(progress) == "number" then progress else 0, 1)
		local tug = model:GetAttribute("Tug")
		arrow.Text = if tug == 1 then "◄◄  DRAG" elseif tug == -1 then "DRAG  ►►" else ""

		local offset = math.clamp(pointerX - startX, -BAR_WIDTH / 2, BAR_WIDTH / 2)
		knob.Position = UDim2.new(0.5, offset, 0.5, 0)
		local pull = if offset > DEAD_ZONE then 1 elseif offset < -DEAD_ZONE then -1 else 0
		if pull ~= sentPull then
			sentPull = pull
			Pull:FireServer(pull)
		end
	end)
end

return CatchController
