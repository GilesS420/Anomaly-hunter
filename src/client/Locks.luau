--!strict
-- Greys out the buttons the tutorial hasn't unlocked yet (Shared.Util.Tutorial decides which;
-- the step is the player attribute Tutorial). Controllers hand their buttons to
-- Locks.guard(button, feature): while that feature is locked a grey cover with a lock sits on
-- top of the button and swallows clicks and taps. Keys (G, 1 to 9) ask Locks.isLocked.
-- Locks.glow(feature) makes that feature's buttons pulse, to point at what to press next.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Tutorial =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Tutorial"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Locks = {}

-- glow: a ring round the button while it pulses (its own frame, so repainting the button
-- never fights with it).
type Guarded = {
	gui: GuiObject,
	feature: string,
	cover: TextButton,
	glow: { frame: Frame, tween: Tween }?,
}

local player = Players.LocalPlayer
local guarded: { Guarded } = {}
local glowing: string? = nil

local function step(): string?
	local current = player:GetAttribute("Tutorial")
	return if typeof(current) == "string" then current else nil
end

function Locks.isLocked(feature: string): boolean
	return not Tutorial.isUnlocked(step(), feature)
end

-- Sizes a cover or glow frame to the whole button, reaching over the button's own padding.
local function fill(frame: GuiObject, gui: GuiObject)
	local padding = gui:FindFirstChildOfClass("UIPadding")
	local left = if padding then padding.PaddingLeft else UDim.new()
	local right = if padding then padding.PaddingRight else UDim.new()
	local top = if padding then padding.PaddingTop else UDim.new()
	local bottom = if padding then padding.PaddingBottom else UDim.new()
	frame.Position = UDim2.new(-left.Scale, -left.Offset, -top.Scale, -top.Offset)
	frame.Size = UDim2.new(
		1 + left.Scale + right.Scale,
		left.Offset + right.Offset,
		1 + top.Scale + bottom.Scale,
		top.Offset + bottom.Offset
	)
	local round = gui:FindFirstChildOfClass("UICorner")
	if round then
		round:Clone().Parent = frame
	end
end

local function stopGlow(entry: Guarded)
	local glow = entry.glow
	if glow then
		entry.glow = nil
		glow.tween:Cancel()
		glow.frame:Destroy()
	end
end

local function startGlow(entry: Guarded)
	if entry.glow then
		return
	end
	local frame = Instance.new("Frame")
	frame.Name = "TutorialGlow"
	frame.BackgroundTransparency = 1
	frame.ZIndex = entry.gui.ZIndex + 9
	fill(frame, entry.gui)
	local ring = Ui.rim(frame, Ui.Colors.lamp, 2)
	frame.Parent = entry.gui
	local tween = TweenService:Create(
		ring,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Thickness = 6 }
	)
	tween:Play()
	entry.glow = { frame = frame, tween = tween }
end

local function refresh(entry: Guarded)
	entry.cover.Visible = Locks.isLocked(entry.feature)
	if glowing == entry.feature and not entry.cover.Visible then
		startGlow(entry)
	else
		stopGlow(entry)
	end
end

-- Puts a lock cover over `gui` while `feature` is locked.
function Locks.guard(gui: GuiObject, feature: string)
	local cover = Instance.new("TextButton")
	cover.Name = "TutorialLock"
	cover.AutoButtonColor = false
	cover.BackgroundColor3 = Color3.fromRGB(24, 22, 30)
	cover.BackgroundTransparency = 0.25
	cover.BorderSizePixel = 0
	cover.Text = "🔒"
	cover.TextColor3 = Ui.Colors.muted
	cover.TextScaled = true
	cover.ZIndex = gui.ZIndex + 10
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 22
	limit.Parent = cover
	fill(cover, gui)
	cover.Parent = gui
	local entry: Guarded = { gui = gui, feature = feature, cover = cover }
	table.insert(guarded, entry)
	refresh(entry)
end

-- Makes this feature's buttons pulse (nil: none).
function Locks.glow(feature: string?)
	if glowing == feature then
		return
	end
	glowing = feature
	for _, entry in guarded do
		refresh(entry)
	end
end

player:GetAttributeChangedSignal("Tutorial"):Connect(function()
	for _, entry in guarded do
		refresh(entry)
	end
end)

return Locks
