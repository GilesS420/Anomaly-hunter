--!strict
-- Building blocks for the shop windows (Workshop, Bakery, Collector) and the other buttons:
-- a window in the middle of the screen with a title, a status line, a scrolling list, a
-- footer and a close button. The look matches the haunted hub: near-black purple panels,
-- lantern-orange spooky titles and dark buttons rimmed in their colour. Sizes scale down on
-- phones; every button works with a mouse click or a tap.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Ui = {}

Ui.Colors = {
	panel = Color3.fromRGB(18, 14, 26),
	row = Color3.fromRGB(32, 26, 44),
	rim = Color3.fromRGB(96, 74, 140), -- panel and row outlines
	lamp = Color3.fromRGB(255, 176, 84), -- titles, like the lanterns
	text = Color3.new(1, 1, 1),
	muted = Color3.fromRGB(190, 180, 210),
	money = Color3.fromRGB(140, 255, 140),
	buy = Color3.fromRGB(60, 150, 80),
	sell = Color3.fromRGB(205, 135, 30),
	equip = Color3.fromRGB(110, 80, 200),
	off = Color3.fromRGB(86, 78, 100),
	confirm = Color3.fromRGB(200, 60, 70),
}

export type Window = {
	gui: ScreenGui,
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

function Ui.corner(parent: Instance, pixels: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, pixels)
	corner.Parent = parent
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
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
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

-- The spooky title font.
Ui.TitleFont = Enum.Font.Creepster

-- A thin outline round a frame or button.
function Ui.rim(parent: Instance, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = parent
	return stroke
end

-- Gives a button the hub look: a dark body tinted with its colour, a rim in the colour and
-- a soft shine from the top. Call again after changing the colour (Ui.paint).
function Ui.paint(button: GuiButton, color: Color3)
	local h, sat, v = color:ToHSV()
	button.BackgroundColor3 = Color3.fromHSV(h, math.min(sat * 1.1, 1), v * 0.45)
	local stroke = button:FindFirstChild("Rim") :: UIStroke?
	if not stroke then
		stroke = Ui.rim(button, color, 2);
		(stroke :: UIStroke).Name = "Rim"
	end
	(stroke :: UIStroke).Color = Color3.fromHSV(h, sat * 0.8, math.min(v * 1.25, 1))
	if not button:FindFirstChild("Shine") then
		local shine = Instance.new("UIGradient")
		shine.Name = "Shine"
		shine.Rotation = 90
		shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 140, 165))
		shine.Parent = button
	end
end

function Ui.button(parent: Instance, text: string, color: Color3, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = Ui.Colors.text
	button.TextStrokeTransparency = 0.6
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
	local rim = button:FindFirstChild("Rim")
	local rimColor = if rim and rim:IsA("UIStroke") then rim.Color else color
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
				local rim = button:FindFirstChild("Rim")
				if rim and rim:IsA("UIStroke") then
					rim.Color = rimColor
				end
			end
		end)
	end)
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

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.92, 0.9) -- tall, so a landscape phone still shows a few rows
	panel.BackgroundColor3 = Ui.Colors.panel
	panel.BackgroundTransparency = 0.04
	panel.Parent = gui
	Ui.corner(panel, 14)
	Ui.rim(panel, Ui.Colors.rim, 2)
	-- A faint purple mist rising from the bottom, like the hub at night.
	local mist = Instance.new("UIGradient")
	mist.Rotation = 90
	mist.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 170, 255))
	mist.Parent = panel
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
	title.TextStrokeTransparency = 0.4
	title.TextStrokeColor3 = Color3.fromRGB(60, 20, 0)

	local status = Ui.text(panel, "", UDim2.new(1, 0, 0, 22), Ui.Colors.muted, false, 18)
	status.Position = UDim2.fromOffset(0, 38)

	local close = Ui.button(panel, "X", Ui.Colors.off, UDim2.fromOffset(44, 44))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, -4)
	local round = close:FindFirstChildOfClass("UICorner")
	if round then
		round.CornerRadius = UDim.new(0.5, 0)
	end

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

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, 52)
	footer.BackgroundTransparency = 1
	footer.Parent = panel

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

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

	window = {
		gui = gui,
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
	Ui.rim(row, Color3.fromRGB(58, 48, 78), 1)
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

return Ui
