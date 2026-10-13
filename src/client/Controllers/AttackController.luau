--!strict
-- What a monster attack feels like on your screen (the server decides every hit, see
-- server/Services/AttackService.luau): a red flash when you lose a heart, a white screen
-- when you're flashed, a green slimy edge while you're slowed, a little "Dodged!" when you
-- got out of the circle in time, and a push back when you're knocked.
--
-- Remote: ReplicatedStorage.AttackRemotes.Effect (kind, data).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AttackController = {}

local player = Players.LocalPlayer

local HitColor = Color3.fromRGB(255, 40, 60)
local SlimeColor = Color3.fromRGB(90, 220, 70)
local DodgeColor = Color3.fromRGB(150, 255, 170)

-- A frame covering the whole screen, see-through until something fades it in.
local function cover(gui: ScreenGui, name: string, color: Color3, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ZIndex = order
	frame.Parent = gui
	return frame
end

-- Glowing edges only (a hollow box made of a thick UIStroke), for hits and slime.
local function edges(gui: ScreenGui, name: string, color: Color3): UIStroke
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 40
	stroke.Color = color
	stroke.Transparency = 1
	stroke.Parent = frame
	return stroke
end

local function fade(instance: Instance, property: string, from: number, to: number, seconds: number)
	(instance :: any)[property] = from
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		[property] = to,
	}):Play()
end

function AttackController.start()
	local remotes = ReplicatedStorage:WaitForChild("AttackRemotes")
	local effect = remotes:WaitForChild("Effect") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "AttackUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	local white = cover(gui, "Blind", Color3.new(1, 1, 1), 3)
	local hit = edges(gui, "Hit", HitColor)
	local slime = edges(gui, "Slime", SlimeColor)

	local word = Instance.new("TextLabel")
	word.Name = "Word"
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Position = UDim2.fromScale(0.5, 0.35)
	word.Size = UDim2.fromScale(0.4, 0.08)
	word.BackgroundTransparency = 1
	word.Font = Enum.Font.GothamBlack
	word.TextScaled = true
	word.TextTransparency = 1
	word.TextStrokeTransparency = 1
	word.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	local function say(text: string, color: Color3, seconds: number)
		word.Text = text
		word.TextColor3 = color
		fade(word, "TextTransparency", 0, 1, seconds)
		fade(word, "TextStrokeTransparency", 0.2, 1, seconds)
	end

	effect.OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Hit" then
			fade(hit, "Transparency", 0.1, 1, 0.6)
		elseif kind == "Dodged" then
			say("Dodged!", DodgeColor, 0.9)
		elseif kind == "Blind" and typeof(data) == "number" then
			fade(white, "BackgroundTransparency", 0, 1, data)
		elseif kind == "Slowed" and typeof(data) == "number" then
			say("Slimed!", SlimeColor, 1.2)
			fade(slime, "Transparency", 0.2, 1, data)
		elseif kind == "Knock" and typeof(data) == "Vector3" then
			-- Your character moves on your own device, so the push happens here.
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping) -- off the ground, so the push carries
				root.AssemblyLinearVelocity = data + Vector3.new(0, 25, 0)
			end
		end
	end)
end

return AttackController
