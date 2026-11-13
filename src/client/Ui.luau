--!strict
-- Building blocks for the shop windows (Workshop, Bakery, Collector) and the other buttons:
-- a window in the middle of the screen with a title, a status line, a scrolling list, a
-- footer and a close button. Each window is drawn in a Scale canvas, so it shrinks to fit a
-- phone; every button works with a click or a tap.
--
-- Style rules (Giles 2026-11-05): flat and minimal. Small corners (Ui.corner caps them), solid
-- buttons in one colour (Ui.paint), no glowing rims, shine or mist gradients, no outlines on
-- text, and as few words as possible. New UI should use Ui.corner / Ui.paint / Ui.rim /
-- Ui.Style instead of making its own UICorner, UIStroke or UIGradient.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Scale = require(script.Parent:WaitForChild("Scale"))

local Ui = {}

-- Shared look for every menu. Change it here, not in each controller.
-- Palette "Lagoon teal" (Giles 2026-11-12/13: the old dark menus felt heavy and scared people
-- away, the cream "Golden hour" try was too light for the hub). A fresh mid-tone teal: the
-- opposite of the hub's orange sun, and still calm on the dark event sky. Gold titles, white
-- text. Text that lands on a background it can't be read on is fixed by Ui.watchContrast, so
-- a bright rarity colour or an old dark text colour stays readable.
Ui.Style = {
	maxRadius = 6, -- no card or button gets rounder than this (pixels)
	panelRadius = 7, -- the window itself
	line = Color3.fromRGB(63, 132, 148), -- the one thin outline colour for panels, rows and boxes
}

Ui.Colors = {
	panel = Color3.fromRGB(30, 88, 104), -- lagoon teal
	row = Color3.fromRGB(44, 110, 126), -- cards and rows on the panel, a step lighter
	rim = Color3.fromRGB(86, 150, 166), -- scroll bars and dividers (flat, no glow)
	lamp = Color3.fromRGB(255, 190, 92), -- titles, like the lanterns
	text = Color3.new(1, 1, 1), -- text on coloured buttons
	ink = Color3.fromRGB(252, 248, 240), -- text on panels and cards
	muted = Color3.fromRGB(205, 225, 230),
	money = Color3.fromRGB(150, 240, 150),
	buy = Color3.fromRGB(56, 168, 90),
	sell = Color3.fromRGB(226, 133, 31),
	equip = Color3.fromRGB(125, 91, 214),
	off = Color3.fromRGB(100, 140, 150),
	confirm = Color3.fromRGB(222, 72, 80),
}

-- A tile in a colour (a rarity, a mission tier) for picture boxes and tags on the cards: the
-- card colour with a wash of `color`. Its text is drawn in Ui.deep(color).
function Ui.tint(color: Color3): Color3
	return Ui.Colors.row:Lerp(color, 0.3)
end

-- Relative brightness of a colour as screens show it (WCAG), 0 = black, 1 = white.
local function luminance(color: Color3): number
	local function channel(c: number): number
		return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

-- How well text in one colour reads on another: 1 (not at all) to 21 (black on white).
function Ui.contrast(a: Color3, b: Color3): number
	local la, lb = luminance(a), luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

local DarkInk = Color3.fromRGB(40, 28, 56) -- text on light things (gold tags, pale buttons)
local Readable = 3 -- below this text is hard to read; it's then fixed to reach Wanted
local Wanted = 4.5

-- The colour to draw `color` text in on `background` so it can be read: unchanged when it
-- already reads well, otherwise a darker (on light backgrounds) or lighter shade of the same
-- hue. White or grey text on a light background becomes DarkInk.
function Ui.readable(color: Color3, background: Color3): Color3
	if Ui.contrast(color, background) >= Readable then
		return color
	end
	local h, s, v = color:ToHSV()
	if luminance(background) > 0.4 then
		if s < 0.15 then
			return DarkInk
		end
		s = math.max(s, 0.75)
		while v > 0.2 do
			v -= 0.05
			local shade = Color3.fromHSV(h, s, v)
			if Ui.contrast(shade, background) >= Wanted then
				return shade
			end
		end
		return DarkInk
	end
	-- A dark background: lighten towards white.
	for step = 1, 12 do
		local shade = Color3.fromHSV(h, s * (1 - step / 12), v + (1 - v) * step / 12)
		if Ui.contrast(shade, background) >= Wanted then
			return shade
		end
	end
	return Color3.new(1, 1, 1)
end

-- A shade of a colour that reads on the cards (rarity names, pills, prices).
function Ui.deep(color: Color3): Color3
	return Ui.readable(color, Ui.Colors.row)
end

-- Pictures for the Workshop's items, which have no preview model (Shop.Item kind).
Ui.Icons =
	{ Vacuum = "🌀", Lure = "🔔", Charm = "🧿", Tag = "🏷️", Potion = "🧪", Slapper = "✋" } :: { [string]: string }

export type Window = {
	gui: ScreenGui,
	canvas: Frame, -- the gui's Scale canvas, which holds the panel
	panel: Frame,
	title: TextLabel,
	status: TextLabel,
	list: ScrollingFrame,
	footer: Frame,
	open: (counter: Vector3?) -> (), -- with a counter, walking away from it closes the window
	close: () -> (),
	isOpen: () -> boolean,
	onClose: (() -> ())?,
}

local WalkAwayDistance = 22 -- studs from the counter before the window closes by itself

-- Every window made by Ui.window, so the hotbar can step aside while one is open.
local windows: { ScreenGui } = {}
-- How to close each window, so opening one can close the others.
local closers: { [ScreenGui]: () -> () } = {}

-- One menu at a time (Giles 2026-11-12: opening the Lucky Spin and then another menu froze the
-- game). Opening a window closes every other open window, so menus never pile up on top of
-- each other, half hidden, each waiting on the server. Except these, which other menus never
-- close: a running trade (closing it cancels the trade) and the Admin panel.
local Stays = { TradeUi = true, AdminPanel = true } :: { [string]: boolean }
local windowsChanged = Instance.new("BindableEvent")
Ui.windowsChanged = windowsChanged.Event -- fires when any window opens or closes

-- True when a window other than `except` (by name) is open.
function Ui.anyWindowOpen(except: string?): boolean
	for _, gui in windows do
		if gui.Enabled and gui.Name ~= except then
			return true
		end
	end
	return false
end

-- Small corners: the radius asked for is halved and capped at Ui.Style.maxRadius, so old calls
-- (8, 10, 12, 14...) all come out at 4-6 pixels.
function Ui.radius(pixels: number): UDim
	return UDim.new(0, math.clamp(math.floor(pixels / 2 + 0.5), 2, Ui.Style.maxRadius))
end

function Ui.corner(parent: Instance, pixels: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Ui.radius(pixels)
	corner.Parent = parent
	return corner
end

-- How many rewards wait behind a side button (Codex, Missions, Gifts), from a number
-- attribute on the player: a red circle with the count on the button's top-right corner
-- (Giles 2026-11-05: make them more obvious). It pops when the count goes up and pulses
-- slowly while anything waits. A circle on purpose: the one round shape the flat style keeps.
function Ui.countBadge(button: GuiObject, attribute: string): TextLabel
	local player = Players.LocalPlayer
	local badge = Instance.new("TextLabel")
	badge.Name = "Ready"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -6, 0, 6)
	badge.Size = UDim2.fromOffset(28, 28)
	badge.BackgroundColor3 = Color3.fromRGB(235, 45, 55)
	badge.Font = Enum.Font.FredokaOne
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.TextSize = 17
	badge.ZIndex = 10
	badge.Visible = false
	badge.Parent = button
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = badge
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = 2
	edge.Parent = badge
	local scale = Instance.new("UIScale")
	scale.Parent = badge
	local pulse = TweenService:Create(
		scale,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.15 }
	)
	local shown = 0
	local function show()
		local ready = player:GetAttribute(attribute)
		local count = if typeof(ready) == "number" then math.max(math.floor(ready), 0) else 0
		badge.Visible = count > 0
		badge.Text = if count > 99 then "99+" else tostring(count)
		if count > shown then
			pulse:Cancel()
			scale.Scale = 1.5 -- pop, then settle back into the slow pulse
			local pop = TweenService:Create(
				scale,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			)
			pop.Completed:Once(function()
				if badge.Visible then
					pulse:Play()
				end
			end)
			pop:Play()
		elseif count == 0 then
			pulse:Cancel()
			scale.Scale = 1
		end
		shown = count
	end
	player:GetAttributeChangedSignal(attribute):Connect(show)
	show()
	return badge
end

function Ui.text(
	parent: Instance,
	text: string,
	size: UDim2,
	color: Color3,
	bold: boolean,
	maxSize: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Font = if bold then Enum.Font.FredokaOne else Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.Parent = label
	label.Parent = parent
	return label
end

-- Fonts (Giles picked set B, 2026-10-21): Luckiest Guy for titles, signs and banners;
-- Fredoka One for all other text.
Ui.TitleFont = Enum.Font.LuckiestGuy

-- A thin outline round a frame or button. Flat style: 1 pixel for a plain outline, 2 at
-- most for something picked or highlighted.
function Ui.rim(parent: Instance, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = if thickness >= 2 then 2 else 1
	stroke.Parent = parent
	return stroke
end

-- Gives a button the flat look: one solid colour, no rim, no shine. Call again after
-- changing the colour.
function Ui.paint(button: GuiButton, color: Color3)
	local h, sat, v = color:ToHSV()
	button.BackgroundColor3 = Color3.fromHSV(h, sat * 0.9, v * 0.85)
	-- Old looks drawn before this rule: take them off.
	for _, name in { "Rim", "Shine" } do
		local old = button:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end

function Ui.button(parent: Instance, text: string, color: Color3, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Font = Enum.Font.FredokaOne
	button.Text = text
	button.TextColor3 = Ui.Colors.text
	button.TextStrokeTransparency = 1
	button.TextScaled = true
	button.AutoButtonColor = true
	Ui.corner(button, 8)
	Ui.paint(button, color)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = button
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 20
	limit.Parent = button
	button.Parent = parent
	return button
end

-- A button that needs two taps: the first turns it red and asks "Sure?", the second (within
-- a few seconds) runs action.
function Ui.confirmButton(button: TextButton, question: string, action: () -> ())
	local armed = false
	local text, color = button.Text, button.BackgroundColor3
	button.Activated:Connect(function()
		if armed then
			armed = false
			action()
			return
		end
		armed = true
		button.Text = question
		Ui.paint(button, Ui.Colors.confirm)
		task.delay(3, function()
			if armed and button.Parent then
				armed = false
				button.Text = text
				button.BackgroundColor3 = color
			end
		end)
	end)
end

-- Puts a copy of a preview model in a viewport, looking at it from the front.
local function frame(viewport: ViewportFrame, model: Model)
	local copy = model:Clone()
	copy.Parent = viewport
	local box, size = copy:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local from = box.Position + Vector3.new(reach * 0.5, reach * 0.35, -reach * 1.6)
	camera.CFrame = CFrame.lookAt(from, box.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- A picture of a monster or cake: `look` names one of the preview models the server keeps in
-- PlayerGui.InventoryPreviews (server/Services/InventoryService). Without a look (or for a
-- vacuum or charm) it shows `icon`, a big emoji, instead.
function Ui.picture(parent: Instance, size: UDim2, look: string?, icon: string?): GuiObject
	if not look then
		local glyph = Ui.text(parent, icon or "", size, Ui.Colors.text, false, 48)
		glyph.TextXAlignment = Enum.TextXAlignment.Center
		return glyph
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = size
	viewport.Ambient = Color3.fromRGB(170, 160, 190)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-0.4, -1, 0.6)
	viewport.Parent = parent
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local folder = playerGui:FindFirstChild("InventoryPreviews")
	local model = if folder then folder:FindFirstChild(look) else nil
	if model and model:IsA("Model") then
		frame(viewport, model)
	else
		-- Not built yet (just caught or bought, or you just joined): it turns up within seconds.
		task.spawn(function()
			local holder = playerGui:WaitForChild("InventoryPreviews", 5)
			local late = if holder then holder:WaitForChild(look, 5) else nil
			if late and late:IsA("Model") and viewport.Parent then
				frame(viewport, late)
			end
		end)
	end
	return viewport
end

-- True when two answers from the server hold the same things (tables compared all the way
-- down). Menus use it to redraw only when something really changed, so an open menu never
-- flickers (Giles 2026-11-12). Countdowns the server sends along (secondsLeft, resetIn, nextIn,
-- seconds) tick every second and are left out: the menus count those down themselves.
local Ticking = { secondsLeft = true, resetIn = true, nextIn = true, seconds = true }
function Ui.same(a: any, b: any): boolean
	if a == b then
		return true
	end
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not Ticking[key] and not Ui.same(value, b[key]) then
			return false
		end
	end
	for key in b do
		if not Ticking[key] and a[key] == nil then
			return false
		end
	end
	return true
end

-- Removes every row from a list (keeps its layout).
function Ui.clear(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function Ui.window(name: string, titleText: string): Window
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5
	local canvas = Scale.canvas(gui)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.92, 0.9) -- tall, so a landscape phone still shows a few rows
	panel.BackgroundColor3 = Ui.Colors.panel
	panel.BackgroundTransparency = 0.14 -- 10% more see-through (Giles 2026-11-13)
	panel.Active = true -- clicks in the gaps between rows stop here, not in the world behind
	panel.Parent = canvas
	local panelCorner = Ui.corner(panel, 14)
	panelCorner.CornerRadius = UDim.new(0, Ui.Style.panelRadius)
	Ui.rim(panel, Ui.Style.line, 1)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 600)
	limit.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = panel

	local title = Ui.text(panel, titleText, UDim2.new(1, -54, 0, 34), Ui.Colors.lamp, true, 34)
	title.Font = Ui.TitleFont

	local status = Ui.text(panel, "", UDim2.new(1, 0, 0, 22), Ui.Colors.muted, false, 18)
	status.Position = UDim2.fromOffset(0, 38)

	local close = Ui.button(panel, "X", Ui.Colors.off, UDim2.fromOffset(40, 40))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, -2)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 68)
	list.Size = UDim2.new(1, 0, 1, -68 - 62)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Ui.Colors.rim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	-- A little room on every side, so outlines on the first/last rows aren't cut off by the
	-- list's edge (the Send feedback box was clipped on the left, player report 2026-11-04).
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingLeft = UDim.new(0, 3)
	listPadding.PaddingTop = UDim.new(0, 3)
	listPadding.PaddingBottom = UDim.new(0, 3)
	listPadding.Parent = list

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, 52)
	footer.BackgroundTransparency = 1
	footer.Parent = panel

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(windows, gui)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		windowsChanged:Fire()
	end)

	local window: Window
	local watching: RBXScriptConnection? = nil

	local function closeWindow()
		if not gui.Enabled then
			return
		end
		gui.Enabled = false
		if watching then
			watching:Disconnect()
			watching = nil
		end
		local onClose = window.onClose
		if onClose then
			onClose()
		end
	end

	local function openWindow(counter: Vector3?)
		if not gui.Enabled then
			for other, closeOther in closers do
				if other ~= gui and other.Enabled and not Stays[other.Name] then
					closeOther()
				end
			end
		end
		gui.Enabled = true
		if watching then
			watching:Disconnect()
			watching = nil
		end
		if not counter then
			return -- not a shop window (the Backpack): stays open until closed
		end
		local at: Vector3 = counter
		-- Walking away from the counter closes the window.
		watching = RunService.Heartbeat:Connect(function()
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") or (root.Position - at).Magnitude > WalkAwayDistance then
				closeWindow()
			end
		end)
	end

	close.Activated:Connect(closeWindow)
	closers[gui] = closeWindow

	window = {
		gui = gui,
		canvas = canvas,
		panel = panel,
		title = title,
		status = status,
		list = list,
		footer = footer,
		open = openWindow,
		close = closeWindow,
		isOpen = function()
			return gui.Enabled
		end,
		onClose = nil,
	}
	return window
end

-- One row in a list: a name line, a detail line, and room on the right for a button.
-- Returns the row and the frame to put buttons in.
function Ui.row(
	list: ScrollingFrame,
	order: number,
	name: string,
	nameColor: Color3,
	detail: string
): (Frame, Frame)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, 62)
	row.BackgroundColor3 = Ui.Colors.row
	row.Parent = list
	Ui.corner(row, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = row

	local nameLabel = Ui.text(row, name, UDim2.new(0.62, -8, 0, 26), nameColor, true, 22)
	nameLabel.Position = UDim2.fromOffset(0, 0)
	local detailLabel = Ui.text(row, detail, UDim2.new(0.62, -8, 0, 20), Ui.Colors.muted, false, 16)
	detailLabel.Position = UDim2.fromOffset(0, 28)
	detailLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.AnchorPoint = Vector2.new(1, 0.5)
	actions.Position = UDim2.fromScale(1, 0.5)
	actions.Size = UDim2.new(0.38, 0, 1, 0)
	actions.BackgroundTransparency = 1
	actions.Parent = row
	return row, actions
end

-- Readable text everywhere (Giles 2026-11-12, light menus). Watches every text in `root`
-- (the PlayerGui) and, when its colour can't be read on what's behind it, swaps in
-- Ui.readable's shade. Only text on a solid background is touched: HUD text floating over the
-- 3D world, text with an outline, text over a picture and anything inside a frame with the
-- attribute KeepTextColor = true are left alone.
local function backgroundOf(text: GuiObject): Color3?
	local at: Instance? = text
	while at and not at:IsA("LayerCollector") do
		if at:GetAttribute("KeepTextColor") then
			return nil
		end
		if at:IsA("GuiObject") then
			if at.BackgroundTransparency < 0.4 then
				return at.BackgroundColor3
			end
			if at ~= text then
				local picture = (at:IsA("ImageLabel") or at:IsA("ImageButton")) and (at :: any).Image ~= ""
				if picture or at:IsA("ViewportFrame") then
					return nil -- drawn over a picture: can't tell what's behind
				end
			end
		end
		at = at.Parent
	end
	return nil
end

local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local pending: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function fix(text: TextLabel | TextButton | TextBox)
	pending[text] = nil
	if not text.Parent or text.TextStrokeTransparency < 0.6 then
		return
	end
	local background = backgroundOf(text)
	if not background then
		return
	end
	local color = Ui.readable(text.TextColor3, background)
	if color ~= text.TextColor3 then
		text.TextColor3 = color
	end
end

local function later(text: Instance)
	if pending[text] then
		return
	end
	pending[text] = true
	task.defer(fix, text :: any)
end

local function watch(object: Instance)
	if not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
		return
	end
	later(object)
	if watched[object] then
		return
	end
	watched[object] = true
	local function again()
		later(object)
	end
	object:GetPropertyChangedSignal("TextColor3"):Connect(again)
	object:GetPropertyChangedSignal("BackgroundColor3"):Connect(again)
	object:GetPropertyChangedSignal("BackgroundTransparency"):Connect(again)
end

function Ui.watchContrast(root: Instance)
	for _, object in root:GetDescendants() do
		watch(object)
	end
	root.DescendantAdded:Connect(watch)
end

return Ui
