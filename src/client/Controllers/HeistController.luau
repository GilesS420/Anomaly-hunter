--!strict
-- Monster Heists on screen (server/Services/HeistService):
--   - your own mansion's "Rob this mansion" prompt is hidden (only other players see it)
--   - on a heist, a banner along the top counts down: grab a monster, then run it home
--   - every thief has a red THIEF! marker over their head, seen through walls, so the owner
--     and their friends can find and slap them
--   - when someone robs your mansion, an alarm bell rings
-- Reads the player attributes Stealing, HeistPhase and HeistEndsAt, and HeistRemotes.Alarm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SoundController = require(script.Parent:WaitForChild("SoundController"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local HeistController = {}

local PromptName = "HeistPrompt"
local MarkerName = "ThiefMarker"
local Red = Color3.fromRGB(235, 50, 60)

local player = Players.LocalPlayer

-- Your own mansion's prompt: switched off on your screen only.
local function hideOwnPrompt(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance.Name == PromptName then
		if instance:GetAttribute("OwnerId") == player.UserId then
			instance.Enabled = false
		end
	end
end

-- The red marker and outline on a thief's character, or none when they stop stealing.
local function updateMarker(who: Player)
	local character = who.Character
	local head = character and character:FindFirstChild("Head")
	local old = character and character:FindFirstChild(MarkerName)
	local stealing = who:GetAttribute("Stealing") == true
	if not stealing or not character or not head then
		if old then
			old:Destroy()
		end
		return
	end
	if old then
		return
	end
	local marker = Instance.new("Folder")
	marker.Name = MarkerName
	local glow = Instance.new("Highlight")
	glow.FillColor = Red
	glow.FillTransparency = 0.7
	glow.OutlineColor = Red
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Adornee = character
	glow.Parent = marker
	local sign = Instance.new("BillboardGui")
	sign.Adornee = head :: BasePart
	sign.AlwaysOnTop = true
	sign.Size = UDim2.fromOffset(120, 54)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	sign.MaxDistance = 1000
	sign.Parent = marker
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Ui.TitleFont
	text.Text = "THIEF!\n▼"
	text.TextColor3 = Red
	text.TextStrokeTransparency = 0
	text.TextScaled = true
	text.Parent = sign
	marker.Parent = character
end

local function watch(who: Player)
	who:GetAttributeChangedSignal("Stealing"):Connect(function()
		updateMarker(who)
	end)
	who.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		updateMarker(who)
	end)
	updateMarker(who)
end

local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function HeistController.start()
	for _, instance in workspace:GetDescendants() do
		hideOwnPrompt(instance)
	end
	workspace.DescendantAdded:Connect(hideOwnPrompt)

	Players.PlayerAdded:Connect(watch)
	for _, who in Players:GetPlayers() do
		watch(who)
	end

	-- The banner along the top while you're on a heist.
	local gui = Instance.new("ScreenGui")
	gui.Name = "HeistUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	local canvas = Scale.canvas(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 70)
	banner.Size = UDim2.fromOffset(420, 58)
	banner.BackgroundColor3 = Ui.Colors.panel
	banner.Visible = false
	banner.Parent = canvas
	Ui.corner(banner, 12)
	Ui.rim(banner, Red, 2)
	local title = Ui.text(banner, "", UDim2.new(1, -20, 0, 28), Red, true, 26)
	title.Font = Ui.TitleFont
	title.Position = UDim2.fromOffset(10, 4)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local hint = Ui.text(banner, "", UDim2.new(1, -20, 0, 20), Ui.Colors.text, false, 16)
	hint.Position = UDim2.fromOffset(10, 32)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	RunService.Heartbeat:Connect(function()
		local phase = player:GetAttribute("HeistPhase")
		local endsAt = player:GetAttribute("HeistEndsAt")
		if typeof(endsAt) ~= "number" or (phase ~= "Inside" and phase ~= "Carrying") then
			banner.Visible = false
			return
		end
		local left = clock(endsAt - workspace:GetServerTimeNow())
		banner.Visible = true
		if phase == "Inside" then
			title.Text = `HEIST {left}`
			hint.Text = "Vacuum a monster that isn't hearted!"
		else
			title.Text = `RUN HOME {left}`
			hint.Text = "Get to your own mansion. One slap and it flies back!"
		end
	end)

	local remotes = ReplicatedStorage:WaitForChild("HeistRemotes")
	local alarm = remotes:WaitForChild("Alarm") :: RemoteEvent
	alarm.OnClientEvent:Connect(function()
		SoundController.alarm()
	end)
end

return HeistController
