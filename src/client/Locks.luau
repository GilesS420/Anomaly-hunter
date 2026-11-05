--!strict
-- Greys out the buttons the tutorial hasn't unlocked yet (Shared.Util.Tutorial decides which;
-- the step is the player attribute Tutorial). Controllers hand their buttons to
-- Locks.guard(button, feature): while that feature is locked a grey cover with a lock sits on
-- top of the button and swallows clicks and taps. Keys (G, 1 to 9) ask Locks.isLocked.
-- Locks.glow(feature) makes that feature's buttons pulse, to point at what to press next.
-- Locks.glow(feature, true) also greys out the whole screen except those buttons (Giles
-- 2026-11-04: shows players where things really are), for the tour and the unlock tips.
-- Locks.mark(gui, name) tags a card or button that comes and goes (a shop card, the Sell
-- button on a monster, a dialogue choice) and Locks.point(names) makes the tagged ones pulse
-- too: the tutorial points at the exact card to sell or buy (Giles 2026-11-05).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
type Marked = { gui: GuiObject, name: string, glow: { frame: Frame, tween: Tween }? }
local marked: { Marked } = {}
local pointing: { [string]: boolean } = {}
local glowing: string? = nil
local dimmed = false

-- The grey: four see-through panels round a hole where the glowing buttons are. Over the HUD
-- (DisplayOrder 6 and below), under the tutorial card (8) and the toasts. Frames that aren't
-- Active let clicks through, so the game still works under it.
local DimTransparency = 0.45
local HolePadding = 8 -- screen pixels of room round the buttons
local dimGui = Instance.new("ScreenGui")
dimGui.Name = "TutorialSpotlight"
dimGui.IgnoreGuiInset = true
dimGui.ResetOnSpawn = false
dimGui.DisplayOrder = 7
dimGui.Enabled = false
-- An empty frame at the grey's own top-left corner: every AbsolutePosition is measured from
-- the same point, so a button's place minus this one's is where it is in the grey, whatever
-- each gui's IgnoreGuiInset (the top bar's buttons ignore it, the HUD doesn't).
local origin = Instance.new("Frame")
origin.Name = "Origin"
origin.BackgroundTransparency = 1
origin.Size = UDim2.fromOffset(0, 0)
origin.Parent = dimGui
local panels: { Frame } = {}
for i = 1, 4 do
	local panel = Instance.new("Frame")
	panel.Name = `Dim{i}`
	panel.Active = false
	panel.BorderSizePixel = 0
	panel.BackgroundColor3 = Color3.new(0, 0, 0)
	panel.BackgroundTransparency = DimTransparency
	panel.Parent = dimGui
	panels[i] = panel
end

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

local function stopGlow(entry: Guarded | Marked)
	local glow = entry.glow
	if glow then
		entry.glow = nil
		glow.tween:Cancel()
		glow.frame:Destroy()
	end
end

local function startGlow(entry: Guarded | Marked)
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

-- Whether a button really shows: it and every frame it sits in are visible.
local function showing(gui: GuiObject, screen: ScreenGui): boolean
	local at: Instance? = gui
	while at and at ~= screen do
		if at:IsA("GuiObject") and not at.Visible then
			return false
		end
		at = at.Parent
	end
	return at == screen and screen.Enabled
end

-- Where the glowing buttons are in the grey's own pixels, as one box, or
-- nil if none of them is showing.
local function holeRect(): (Vector2?, Vector2?)
	local low: Vector2?, high: Vector2? = nil, nil
	local zero = origin.AbsolutePosition
	for _, entry in guarded do
		local gui = entry.gui
		if entry.feature ~= glowing or entry.cover.Visible then
			continue
		end
		local screen = gui:FindFirstAncestorOfClass("ScreenGui")
		if not screen or not gui:IsDescendantOf(player.PlayerGui) or not showing(gui, screen) then
			continue
		end
		local at = gui.AbsolutePosition - zero
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			continue
		end
		local far = at + size
		low = if low then Vector2.new(math.min(low.X, at.X), math.min(low.Y, at.Y)) else at
		high = if high then Vector2.new(math.max(high.X, far.X), math.max(high.Y, far.Y)) else far
	end
	if not low or not high then
		return nil, nil
	end
	local pad = Vector2.new(HolePadding, HolePadding)
	return low - pad, high + pad
end

local function place(panel: Frame, x: number, y: number, w: number, h: number)
	panel.Position = UDim2.fromOffset(x, y)
	panel.Size = UDim2.fromOffset(math.max(w, 0), math.max(h, 0))
end

-- Lays the four panels round the hole (the whole screen grey when there is no hole).
local function drawDim()
	local camera = workspace.CurrentCamera
	local screen = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	local low, high = holeRect()
	if not low or not high then
		place(panels[1], 0, 0, screen.X, screen.Y)
		for i = 2, 4 do
			panels[i].Visible = false
		end
		panels[1].Visible = true
		return
	end
	for _, panel in panels do
		panel.Visible = true
	end
	place(panels[1], 0, 0, screen.X, low.Y) -- above
	place(panels[2], 0, high.Y, screen.X, screen.Y - high.Y) -- below
	place(panels[3], 0, low.Y, low.X, high.Y - low.Y) -- left
	place(panels[4], high.X, low.Y, screen.X - high.X, high.Y - low.Y) -- right
end

local dimConnection: RBXScriptConnection? = nil
local function setDim(on: boolean)
	dimmed = on
	if on and not dimConnection then
		if not dimGui.Parent then
			dimGui.Parent = player:WaitForChild("PlayerGui")
		end
		drawDim()
		dimGui.Enabled = true
		-- Buttons move (the mansion list slides, the screen turns): follow every frame.
		dimConnection = RunService.RenderStepped:Connect(drawDim)
	elseif not on then
		dimGui.Enabled = false
		if dimConnection then
			dimConnection:Disconnect()
			dimConnection = nil
		end
	end
end

-- Makes this feature's buttons pulse (nil: none). With `dim`, the rest of the screen goes
-- grey too (a dim with no feature greys the whole screen, round the tutorial card).
function Locks.glow(feature: string?, dim: boolean?)
	local wantDim = dim == true
	if wantDim ~= dimmed then
		setDim(wantDim)
	end
	if glowing == feature then
		return
	end
	glowing = feature
	for _, entry in guarded do
		refresh(entry)
	end
end

local function refreshMark(entry: Marked)
	if pointing[entry.name] then
		startGlow(entry)
	else
		stopGlow(entry)
	end
end

-- Tags a card or button so Locks.point can make it pulse. It's forgotten once destroyed
-- (shop windows redraw their cards all the time).
function Locks.mark(gui: GuiObject, name: string)
	local entry: Marked = { gui = gui, name = name }
	table.insert(marked, entry)
	gui.Destroying:Connect(function()
		local index = table.find(marked, entry)
		if index then
			table.remove(marked, index)
		end
	end)
	refreshMark(entry)
end

-- Makes the cards and buttons tagged with these names pulse (nil or {}: none).
function Locks.point(names: { string }?)
	local wanted: { [string]: boolean } = {}
	for _, name in names or {} do
		wanted[name] = true
	end
	local same = true
	for name in wanted do
		same = same and pointing[name] == true
	end
	for name in pointing do
		same = same and wanted[name] == true
	end
	if same then
		return
	end
	pointing = wanted
	for _, entry in marked do
		refreshMark(entry)
	end
end

player:GetAttributeChangedSignal("Tutorial"):Connect(function()
	for _, entry in guarded do
		refresh(entry)
	end
end)

return Locks
