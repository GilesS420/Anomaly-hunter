--!strict
-- Draws the first-timer tutorial (the server runs it, server/Services/TutorialService): a
-- guide card on the right saying what to do, a glowing trail from you to where to go (with
-- the target lit up), the button to press pulsing, and after 2 minutes on one step a bigger
-- hint. The last step is a short tour of the buttons; its Next button ends the tutorial
-- (TutorialRemotes.Finish). Locked buttons are greyed out by client/Locks.
-- Reads the player attribute Tutorial (the step, nil once done) and TutorialSince.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tutorial =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Tutorial"))
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local TutorialController = {}

local player = Players.LocalPlayer

local TargetCheckSeconds = 0.5
local TrailColor = Color3.fromRGB(255, 176, 84) -- lantern orange, like the shop titles

-- The button that pulses during each step (the tour picks its own).
local StepGlow = {
	Gate = "Portals",
	Catch = "Hotbar",
	Pickup = "Backpack",
	Sell = "Sell",
	Buy = "Shops",
} :: { [string]: string }

local function step(): string?
	local current = player:GetAttribute("Tutorial")
	return if typeof(current) == "string" then current else nil
end

-- The part to point the trail at: a part itself, or a model's main part.
local function partOf(instance: Instance?): BasePart?
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function path(...: string): Instance?
	local at: Instance? = workspace
	for _, name in { ... } do
		at = if at then at:FindFirstChild(name) else nil
	end
	return at
end

-- The Gloomlet waiting for you in the zone (TutorialService marks it with your UserId).
local function tutorialMonster(): Model?
	local folder = path("Zones", Tutorial.Zone, "Monsters")
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("TutorialFor") == player.UserId then
			return child
		end
	end
	return nil
end

-- A monster roaming your own mansion.
local function myMansionMonster(): Model?
	local mansions = workspace:FindFirstChild("Mansions")
	if not mansions then
		return nil
	end
	for _, mansion in mansions:GetChildren() do
		local monsters = mansion:FindFirstChild("Monsters")
		if mansion:GetAttribute("OwnerId") == player.UserId and monsters then
			for _, child in monsters:GetChildren() do
				if child:IsA("Model") then
					return child
				end
			end
		end
	end
	return nil
end

-- What the trail points at during this step, if anything.
local function targetFor(current: string?): Instance?
	if current == "Gate" then
		return path("Hub", "ZoneGates", Tutorial.Zone)
	elseif current == "Catch" then
		return tutorialMonster()
	elseif current == "Home" then
		return path("Zones", Tutorial.Zone, "Exit")
	elseif current == "Pickup" then
		return myMansionMonster()
	elseif current == "Sell" then
		return path("Hub", "Landmarks", "Collector")
	elseif current == "Buy" then
		return path("Hub", "Landmarks", "Workshop")
	end
	return nil
end

local function buildCard(): (ScreenGui, TextLabel, TextLabel, TextLabel, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8 -- over the HUD, under the toasts
	gui.Enabled = false

	-- On the right, halfway down: clear of the HUD column on the left, the top bar, the
	-- toasts, the hotbar and the event icon.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(1, 0.5)
	card.Position = UDim2.new(1, -12, 0.45, 0)
	card.Size = UDim2.new(0.3, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Ui.Colors.panel
	card.BackgroundTransparency = 0.08
	card.Parent = gui
	Ui.corner(card, 12)
	Ui.rim(card, Ui.Colors.lamp, 2)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(220, 0)
	limit.MaxSize = Vector2.new(340, math.huge)
	limit.Parent = card
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = card

	local function line(order: number, color: Color3, size: number, font: Enum.Font): TextLabel
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Font = font
		label.TextSize = size
		label.TextColor3 = color
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = ""
		label.Parent = card
		return label
	end
	local title = line(1, Ui.Colors.lamp, 26, Ui.TitleFont)
	local body = line(2, Ui.Colors.text, 17, Enum.Font.FredokaOne)
	local hint = line(3, Ui.Colors.muted, 14, Enum.Font.FredokaOne)
	local nextButton = Ui.button(card, "Next", Ui.Colors.buy, UDim2.new(0, 110, 0, 40))
	nextButton.LayoutOrder = 4

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, title, body, hint, nextButton
end

function TutorialController.start()
	local gui, title, body, hint, nextButton = buildCard()
	local remotes = ReplicatedStorage:WaitForChild("TutorialRemotes")
	local Finish = remotes:WaitForChild("Finish") :: RemoteEvent

	-- The trail: from an attachment on you to one on the target, plus a glow on the target.
	local trail = Instance.new("Beam")
	trail.Name = "TutorialTrail"
	trail.Color = ColorSequence.new(TrailColor)
	trail.Transparency = NumberSequence.new(0.2, 0.6)
	trail.Width0 = 1.2
	trail.Width1 = 0.6
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Segments = 20
	trail.TextureSpeed = 2
	local fromAttachment = Instance.new("Attachment")
	fromAttachment.Name = "TutorialFrom"
	local toAttachment = Instance.new("Attachment")
	toAttachment.Name = "TutorialTo"
	trail.Attachment0 = fromAttachment
	trail.Attachment1 = toAttachment
	local highlight = Instance.new("Highlight")
	highlight.Name = "TutorialHighlight"
	highlight.FillColor = TrailColor
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = TrailColor
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	local tourIndex = 1

	local function hideTrail()
		trail.Parent = nil
		toAttachment.Parent = nil
		highlight.Parent = nil
	end

	local function pointAt(target: Instance?)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local part = partOf(target)
		if not part or not root or not root:IsA("BasePart") or not target then
			hideTrail()
			return
		end
		if fromAttachment.Parent ~= root then
			fromAttachment.Parent = root
		end
		if toAttachment.Parent ~= part then
			toAttachment.Parent = part
		end
		if trail.Parent ~= root then
			trail.Parent = root
		end
		local glowAt = if target:IsA("Model") or target:IsA("BasePart") then target else part
		if highlight.Adornee ~= glowAt then
			highlight.Adornee = glowAt
		end
		if highlight.Parent ~= workspace.CurrentCamera then
			highlight.Parent = workspace.CurrentCamera -- only you see it
		end
	end

	local function render()
		local current = step()
		gui.Enabled = current ~= nil
		if not current then
			hideTrail()
			Locks.glow(nil)
			return
		end
		local index = Tutorial.index(current)
		title.Text = `Tutorial · {index}/{#Tutorial.Steps}`
		if current == "Tour" then
			local stop = Tutorial.Tour[tourIndex]
			body.Text = if stop then stop.text else Tutorial.Text.Tour
			hint.Text = `{math.min(tourIndex, #Tutorial.Tour)} of {#Tutorial.Tour}`
			nextButton.Visible = true
			nextButton.Text = if tourIndex >= #Tutorial.Tour then "Let's hunt!" else "Next"
			Locks.glow(if stop then stop.feature else nil)
			hideTrail()
			return
		end
		nextButton.Visible = false
		body.Text = Tutorial.Text[current :: Tutorial.Step] or ""
		local since = player:GetAttribute("TutorialSince")
		local stuck = typeof(since) == "number"
			and workspace:GetServerTimeNow() - since >= Tutorial.HintSeconds
		hint.Text = if stuck then `Stuck? {Tutorial.Hints[current :: Tutorial.Step] or ""}` else ""
		Locks.glow(StepGlow[current])
	end

	nextButton.Activated:Connect(function()
		if step() ~= "Tour" then
			return
		end
		if tourIndex >= #Tutorial.Tour then
			Finish:FireServer()
			return
		end
		tourIndex += 1
		render()
	end)

	player:GetAttributeChangedSignal("Tutorial"):Connect(function()
		tourIndex = 1
		render()
	end)
	render()

	-- The target moves (a monster) or appears late (your mansion, the zone): look again often.
	local waited = TargetCheckSeconds
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited < TargetCheckSeconds then
			return
		end
		waited = 0
		local current = step()
		if current then
			pointAt(targetFor(current))
			if current ~= "Tour" and hint.Text == "" then
				render() -- the 2 minute hint
			end
		end
	end)
end

return TutorialController
