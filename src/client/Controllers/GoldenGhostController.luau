--!strict
-- The Golden Ghost (server/Services/GoldenGhostService): click or tap it as it zips through the
-- hub. A press anywhere near it on screen counts (it's fast, and fingers are big); the server
-- checks the rest. While you have taps on it, a counter at the top says how many.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Scale = require(script.Parent.Parent:WaitForChild("Scale"))

local GoldenGhostController = {}

local TAP_SLACK = 50 -- pixels around the ghost that still count as tapping it

local function ghostModel(): Model?
	local hub = workspace:FindFirstChild("Hub")
	local model = hub and hub:FindFirstChild("GoldenGhost")
	return if model and model:IsA("Model") then model else nil
end

-- Whether a press at this screen position is on (or right next to) the ghost.
local function onGhost(model: Model, screenPosition: Vector3): boolean
	local head = model.PrimaryPart
	if not head then
		return false
	end
	local camera = workspace.CurrentCamera
	local screen, onScreen = camera:WorldToScreenPoint(head.Position)
	if not onScreen then
		return false
	end
	local edge = camera:WorldToScreenPoint(head.Position + camera.CFrame.RightVector * (head.Size.X / 2))
	local radius = (Vector2.new(edge.X, edge.Y) - Vector2.new(screen.X, screen.Y)).Magnitude
	local gap = (Vector2.new(screen.X, screen.Y) - Vector2.new(screenPosition.X, screenPosition.Y)).Magnitude
	return gap <= radius + TAP_SLACK
end

function GoldenGhostController.start()
	local remotes = ReplicatedStorage:WaitForChild("GoldenGhostRemotes")
	local Tap = remotes:WaitForChild("Tap") :: RemoteEvent
	local Progress = remotes:WaitForChild("Progress") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	local canvas = Scale.canvas(gui) -- shrinks everything to fit a phone (client/Scale)
	gui.Name = "GoldenGhostUi"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local counter = Instance.new("TextLabel")
	counter.Name = "Counter"
	counter.AnchorPoint = Vector2.new(0.5, 0)
	counter.Position = UDim2.new(0.5, 0, 0, 70)
	counter.Size = UDim2.fromOffset(260, 34)
	counter.BackgroundTransparency = 1
	counter.Font = Enum.Font.FredokaOne
	counter.TextScaled = true
	counter.TextColor3 = Color3.fromRGB(255, 205, 60)
	counter.TextStrokeTransparency = 0
	counter.Visible = false
	counter.Parent = canvas

	UserInputService.InputBegan:Connect(function(input, processed)
		local pointer = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		if processed or not pointer then
			return
		end
		local model = ghostModel()
		if model and onGhost(model, input.Position) then
			Tap:FireServer()
		end
	end)

	Progress.OnClientEvent:Connect(function(count: unknown, needed: unknown)
		if typeof(count) ~= "number" or typeof(needed) ~= "number" or count <= 0 then
			counter.Visible = false
			return
		end
		counter.Text = `Golden Ghost: {count}/{needed} taps!`
		counter.Visible = true
	end)
end

return GoldenGhostController
