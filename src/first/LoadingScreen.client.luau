--!strict
-- The loading screen. It runs from ReplicatedFirst, before anything else on the client, so a
-- player who joins never sees the world, their mansion and their monsters pop in. It stays up
-- until all of that is ready, then fades out:
--   1. the place has loaded (game.Loaded)
--   2. their character exists
--   3. the server has built their mansion (player attribute MansionReady, set by MansionService)
--   4. the mansion's monsters have reached this client (attribute MansionMonsters is how many)
-- A step that takes too long never traps anyone: after SkipAfter seconds an "Enter anyway"
-- button shows up, and after GiveUpAfter seconds it fades out by itself.
--
-- When it is gone it sets the local player's "Loaded" attribute (only on this client), which
-- client/Loading waits for, so pop-ups like the "while you were away" book wait for it.
--
-- client/Scale isn't here yet when this runs (it lives in StarterPlayerScripts), so the screen
-- makes its own canvas with the same sizing as Shared.Util.UiScale: drawn as on a 1000 x 600
-- screen, shrunk down to 0.55 on a phone.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local SkipAfter = 15 -- seconds before the "Enter anyway" button appears
local GiveUpAfter = 45 -- seconds before it fades out whatever is still missing
local SettleSeconds = 0.75 -- a moment for the last parts to land before fading out
local FadeSeconds = 1.2

local Colors = { -- the hub's colours, as in client/Ui
	night = Color3.fromRGB(8, 6, 12),
	panel = Color3.fromRGB(18, 14, 26),
	rim = Color3.fromRGB(96, 74, 140),
	lamp = Color3.fromRGB(255, 176, 84),
	muted = Color3.fromRGB(190, 180, 210),
	eye = Color3.fromRGB(230, 40, 50),
	fog = Color3.fromRGB(70, 56, 96),
}

local Tips = {
	"Hold your vacuum on a monster and win its struggles to catch it.",
	"Cakes placed in your mansion slowly mutate the monsters inside.",
	"Watch the sky: when it changes, a hub event has started.",
	"Bigger, rarer and mutated monsters sell for more at the Collector.",
	"Buy new wings to make room for more monsters.",
	"Some effects combine into secret combos. Can you find them all?",
	"Lost on a hunt? A Return Charm takes you straight back to the hub.",
}

ReplicatedFirst:RemoveDefaultLoadingScreen()

---------------------------------------------------------------------------------------------
-- The screen

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000 -- over every other gui
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- One group so the whole screen can fade out together.
local root = Instance.new("CanvasGroup")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Colors.night
root.BorderSizePixel = 0
root.Active = true -- clicks don't fall through to the world underneath
root.Parent = gui

-- The gradient goes on its own backdrop: on the CanvasGroup itself it would tint everything
-- inside (title, text, bar) almost black.
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(1, 1, 1) -- the gradient gives the colour
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 0 -- under the fog and the canvas
backdrop.Parent = root

local shade = Instance.new("UIGradient")
shade.Rotation = 90
shade.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 3, 6)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(26, 16, 36)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 3, 6)),
})
shade.Parent = backdrop

-- Fog: big soft blobs drifting slowly across the screen (behind the canvas).
local fogs: { Frame } = {}
for i = 1, 6 do
	local fog = Instance.new("Frame")
	fog.Name = "Fog"
	fog.AnchorPoint = Vector2.new(0.5, 0.5)
	fog.Size = UDim2.fromScale(0.5 + (i % 3) * 0.15, 0.25 + (i % 2) * 0.1)
	fog.Position = UDim2.fromScale((i - 1) / 5, 0.55 + ((i * 37) % 40) / 100)
	fog.BackgroundColor3 = Colors.fog
	fog.BackgroundTransparency = 0.88
	fog.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = fog
	fog.Parent = root
	table.insert(fogs, fog)
end

-- Everything else is drawn as on a computer screen and shrunk on a phone (see the top).
local canvas = Instance.new("Frame")
canvas.Name = "Canvas"
canvas.BackgroundTransparency = 1
canvas.Size = UDim2.fromScale(1, 1)
canvas.Parent = root
local uiScale = Instance.new("UIScale")
uiScale.Parent = canvas

local function fit()
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1000, 600)
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local factor = math.clamp(math.min(size.X / 1000, size.Y / 600), 0.55, 1)
	uiScale.Scale = factor
	canvas.Size = UDim2.fromScale(1 / factor, 1 / factor)
end
fit()

local function label(
	name: string,
	text: string,
	font: Enum.Font,
	color: Color3,
	y: number,
	height: number
): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Position = UDim2.new(0.5, 0, 0.5, y)
	item.Size = UDim2.fromOffset(760, height)
	item.BackgroundTransparency = 1
	item.Font = font
	item.Text = text
	item.TextColor3 = color
	item.TextScaled = true
	item.TextStrokeColor3 = Color3.new(0, 0, 0)
	item.TextStrokeTransparency = 0.4
	item.Parent = canvas
	return item
end

-- Two red eyes in the dark that blink now and then.
local eyes = Instance.new("Frame")
eyes.Name = "Eyes"
eyes.AnchorPoint = Vector2.new(0.5, 0.5)
eyes.Position = UDim2.new(0.5, 0, 0.5, -150)
eyes.Size = UDim2.fromOffset(120, 26)
eyes.BackgroundTransparency = 1
eyes.Parent = canvas
local eyeParts: { Frame } = {}
for i, x in { 0.18, 0.82 } do
	local eye = Instance.new("Frame")
	eye.Name = `Eye{i}`
	eye.AnchorPoint = Vector2.new(0.5, 0.5)
	eye.Position = UDim2.fromScale(x, 0.5)
	eye.Size = UDim2.fromOffset(30, 14)
	eye.BackgroundColor3 = Colors.eye
	eye.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = eye
	local glow = Instance.new("UIStroke")
	glow.Color = Colors.eye
	glow.Thickness = 4
	glow.Transparency = 0.6
	glow.Parent = eye
	eye.Parent = eyes
	table.insert(eyeParts, eye)
end

local title = label("Title", "ANOMALY HUNTER", Enum.Font.Creepster, Colors.lamp, -70, 110)
local status = label("Status", "Opening the gates...", Enum.Font.FredokaOne, Colors.muted, 40, 30)

-- The progress bar under the status line.
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 0.5)
bar.Position = UDim2.new(0.5, 0, 0.5, 82)
bar.Size = UDim2.fromOffset(420, 12)
bar.BackgroundColor3 = Colors.panel
bar.BorderSizePixel = 0
bar.Parent = canvas
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = bar
local barRim = Instance.new("UIStroke")
barRim.Color = Colors.rim
barRim.Thickness = 1.5
barRim.Parent = bar
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Colors.lamp
fill.BorderSizePixel = 0
fill.Parent = bar
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local tip = label("Tip", Tips[math.random(#Tips)], Enum.Font.FredokaOne, Colors.muted, 0, 26)
tip.AnchorPoint = Vector2.new(0.5, 1)
tip.Position = UDim2.new(0.5, 0, 1, -36)
tip.TextTransparency = 0.25

local skip = Instance.new("TextButton")
skip.Name = "Skip"
skip.AnchorPoint = Vector2.new(0.5, 0.5)
skip.Position = UDim2.new(0.5, 0, 0.5, 140)
skip.Size = UDim2.fromOffset(200, 44)
skip.BackgroundColor3 = Colors.panel
skip.Font = Enum.Font.FredokaOne
skip.Text = "Enter anyway"
skip.TextColor3 = Colors.lamp
skip.TextScaled = true
skip.Visible = false
skip.Parent = canvas
local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 8)
skipCorner.Parent = skip
local skipRim = Instance.new("UIStroke")
skipRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
skipRim.Color = Colors.rim
skipRim.Thickness = 2
skipRim.Parent = skip
local skipPadding = Instance.new("UIPadding")
skipPadding.PaddingTop = UDim.new(0, 8)
skipPadding.PaddingBottom = UDim.new(0, 8)
skipPadding.Parent = skip

gui.Parent = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------------------------------
-- Animation: drifting fog, a flickering title, blinking eyes and changing tips

local done = false
local started = os.clock()

task.spawn(function()
	while not done do
		fit()
		local t = os.clock() - started
		for i, fog in fogs do
			local speed = 0.012 + i * 0.003
			local x = ((i - 1) / 5 + t * speed) % 1.6 - 0.3
			fog.Position = UDim2.fromScale(x, fog.Position.Y.Scale)
		end
		task.wait(1 / 30)
	end
end)

task.spawn(function()
	while not done do
		task.wait(1.5 + math.random() * 3)
		for _ = 1, math.random(1, 3) do -- a quick flicker, like a dying lantern
			title.TextTransparency = 0.6 + math.random() * 0.3
			task.wait(0.04 + math.random() * 0.06)
			title.TextTransparency = 0
			task.wait(0.05 + math.random() * 0.1)
		end
	end
end)

task.spawn(function()
	while not done do
		task.wait(2 + math.random() * 3)
		for _, eye in eyeParts do
			eye.Size = UDim2.fromOffset(30, 2)
		end
		task.wait(0.12)
		for _, eye in eyeParts do
			eye.Size = UDim2.fromOffset(30, 14)
		end
	end
end)

task.spawn(function()
	local index = table.find(Tips, tip.Text) or 1
	while not done do
		task.wait(5)
		index = index % #Tips + 1
		tip.Text = Tips[index]
	end
end)

---------------------------------------------------------------------------------------------
-- Waiting until everything is ready

local skipped = false
skip.Activated:Connect(function()
	skipped = true
end)

local function timeUp(): boolean
	local waited = os.clock() - started
	if waited >= SkipAfter then
		skip.Visible = true
	end
	return skipped or waited >= GiveUpAfter
end

-- Moves the bar to `progress` (0 to 1) and shows what is loading now.
local function stage(text: string, progress: number)
	status.Text = text
	TweenService
		:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(progress, 1) })
		:Play()
end

-- Waits until check() is true (or time is up).
local function waitFor(check: () -> boolean)
	while not timeUp() and not check() do
		task.wait(0.1)
	end
end

-- The player's own mansion model (MansionService puts it in Workspace.Mansions).
local function myMansion(): Instance?
	local folder = workspace:FindFirstChild("Mansions")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:GetAttribute("OwnerId") == player.UserId then
			return model
		end
	end
	return nil
end

stage("Opening the gates...", 0.1)
-- The gui itself has no pictures, but this also gives the Creepster font a moment to load.
task.spawn(pcall, ContentProvider.PreloadAsync, ContentProvider, { title, status })
waitFor(function()
	return game:IsLoaded()
end)

stage("Waking the dead...", 0.3)
waitFor(function()
	local character = player.Character
	return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
end)

stage("Building your mansion...", 0.55)
waitFor(function()
	return player:GetAttribute("MansionReady") == true
end)

stage("Letting the monsters out...", 0.8)
local character = player.Character
local rootPart = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
if workspace.StreamingEnabled and rootPart then
	-- Make sure the area around the player (their mansion) has streamed in.
	task.spawn(pcall, player.RequestStreamAroundAsync, player, rootPart.Position)
end
waitFor(function()
	local expected = player:GetAttribute("MansionMonsters")
	if typeof(expected) ~= "number" or expected <= 0 then
		return true -- no monsters (yet), or no mansion because every plot was taken
	end
	local mansion = myMansion()
	local monsters = if mansion then mansion:FindFirstChild("Monsters") else nil
	return monsters ~= nil and #monsters:GetChildren() >= expected
end)

stage("Ready. Good luck, hunter.", 1)
task.wait(SettleSeconds)

---------------------------------------------------------------------------------------------
-- Fade out and get out of the way

skip.Visible = false
local fade = TweenService:Create(
	root,
	TweenInfo.new(FadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	{ GroupTransparency = 1 }
)
fade:Play()
task.wait(FadeSeconds * 0.5)
root.Active = false -- the player can already click through while the last of it fades
player:SetAttribute("Loaded", true)
fade.Completed:Wait()
done = true
gui:Destroy()
