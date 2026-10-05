--!strict
-- Catch controls (keyboard and mouse for now; touch and gamepad come with the UI work):
--   F       shine the flashlight at the monster under the mouse
--   E hold  vacuum a stunned monster; move left/right against its yank to fill the meter

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CatchController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local held: Model? = nil
local sentPull = 0

local function monsterUnderMouse(): Model?
	local part = mouse.Target
	local model = part and part:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("MonsterId") then
		return model
	end
	return nil
end

-- Simple meter + message UI. Placeholder until the UI pass (art epic).
local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CatchUi"
	gui.ResetOnSpawn = false

	local meter = Instance.new("Frame")
	meter.Name = "Meter"
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.new(0.5, 0, 1, -120)
	meter.Size = UDim2.fromOffset(320, 22)
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
	arrow.Size = UDim2.fromOffset(320, 36)
	arrow.BackgroundTransparency = 1
	arrow.TextColor3 = Color3.new(1, 1, 1)
	arrow.TextStrokeTransparency = 0
	arrow.TextScaled = true
	arrow.Font = Enum.Font.GothamBlack
	arrow.Parent = meter

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
	return meter, fill, arrow, message
end

-- -1, 0 or 1: which way the character is moving, sideways relative to the monster.
local function sidewaysInput(model: Model): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local body = model.PrimaryPart
	if not root or not humanoid or not body then
		return 0
	end
	local toMonster = (body.Position - root.Position) * Vector3.new(1, 0, 1)
	if toMonster.Magnitude < 0.1 then
		return 0
	end
	local right = toMonster.Unit:Cross(Vector3.yAxis)
	local side = humanoid.MoveDirection:Dot(right)
	return if side > 0.3 then 1 elseif side < -0.3 then -1 else 0
end

function CatchController.start()
	local remotes = ReplicatedStorage:WaitForChild("CatchRemotes")
	local Shine = remotes:WaitForChild("Shine") :: RemoteEvent
	local VacuumStart = remotes:WaitForChild("VacuumStart") :: RemoteEvent
	local VacuumStop = remotes:WaitForChild("VacuumStop") :: RemoteEvent
	local Pull = remotes:WaitForChild("Pull") :: RemoteEvent
	local Result = remotes:WaitForChild("Result") :: RemoteEvent

	local meter, fill, arrow, message = buildUi()
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

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
			local target = monsterUnderMouse()
			if target then
				Shine:FireServer(target)
			end
		elseif input.KeyCode == Enum.KeyCode.E then
			local target = monsterUnderMouse()
			if target then
				VacuumStart:FireServer(target)
			else
				say("Point at a stunned monster")
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.E and held then
			VacuumStop:FireServer()
		end
	end)

	Result.OnClientEvent:Connect(function(kind: string, monsterId: string?, info: any)
		if kind == "Holding" then
			held = info.model
			sentPull = 0
		else
			held = nil
		end
		if kind == "Caught" then
			local effects = if info and #info.effects > 0
				then " + " .. table.concat(info.effects, ", ")
				else ""
			say(`Caught a {info and info.size or ""} {monsterId}{effects}!`)
		elseif kind == "Escaped" then
			say(`{monsterId} broke free!`)
		elseif kind == "NotStunned" then
			say("Stun it with your flashlight first (F)")
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
		arrow.Text = if tug == 1 then "◄◄  PULL" elseif tug == -1 then "PULL  ►►" else ""

		local pull = sidewaysInput(model)
		if pull ~= sentPull then
			sentPull = pull
			Pull:FireServer(pull)
		end
	end)
end

return CatchController
