--!strict
-- The "Send feedback" window (Giles 2026-11-03), opened from the Settings window's
-- "💬 Send feedback" button. Pick what it's about (Bug, Idea or Other), write up to
-- 500 letters and press Send. The server (FeedbackService) checks the limits, runs Roblox's
-- text filter and puts it in the inbox admins read in the admin panel's Feedback tab (F2).
--   ReplicatedStorage.FeedbackRemotes.Send   (kind, text) -> { ok, message }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Feedback"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local FeedbackController = {}

local RowHeight = 40

local window: Ui.Window? = nil

local function build(): Ui.Window
	local made = Ui.window("FeedbackUi", "Send feedback")
	local limit = made.panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(560, 460)
	end
	local status = made.status
	local list = made.list
	list.ScrollingEnabled = false

	-- Bug / Idea / Other.
	local kinds = Instance.new("Frame")
	kinds.LayoutOrder = 2
	kinds.BackgroundTransparency = 1
	kinds.Size = UDim2.new(1, -11, 0, RowHeight)
	kinds.Parent = list
	local kindsLayout = Instance.new("UIListLayout")
	kindsLayout.FillDirection = Enum.FillDirection.Horizontal
	kindsLayout.Padding = UDim.new(0, 6)
	kindsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	kindsLayout.Parent = kinds
	local chosen = Config.Kinds[1].id
	local kindButtons: { [string]: TextButton } = {}
	local function paintKinds()
		for id, kindButton in kindButtons do
			Ui.paint(kindButton, if id == chosen then Ui.Colors.equip else Ui.Colors.off)
		end
	end
	local count = #Config.Kinds
	for i, kind in Config.Kinds do
		local kindButton = Ui.button(
			kinds,
			`{kind.icon} {kind.label}`,
			Ui.Colors.off,
			UDim2.new(1 / count, -6 * (count - 1) / count, 1, 0)
		)
		kindButton.LayoutOrder = i
		kindButton.Activated:Connect(function()
			chosen = kind.id
			paintKinds()
		end)
		kindButtons[kind.id] = kindButton
	end
	paintKinds()

	local box = Instance.new("TextBox")
	box.LayoutOrder = 3
	box.Size = UDim2.new(1, -11, 0, 170)
	box.BackgroundColor3 = Ui.Colors.row
	box.TextColor3 = Ui.Colors.text
	box.PlaceholderText = "What happened, or what's your idea?"
	box.PlaceholderColor3 = Ui.Colors.muted
	box.Text = ""
	box.Font = Enum.Font.FredokaOne
	box.TextSize = 18
	box.TextWrapped = true
	box.MultiLine = true
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	Ui.corner(box, 8)
	Ui.rim(box, Ui.Style.line, 1)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = box
	box.Parent = list

	-- Footer: letters used, Cancel, Send.
	local footerLayout = Instance.new("UIListLayout")
	footerLayout.FillDirection = Enum.FillDirection.Horizontal
	footerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	footerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	footerLayout.Padding = UDim.new(0, 8)
	footerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	footerLayout.Parent = made.footer
	local letters = Ui.text(made.footer, "", UDim2.fromOffset(110, RowHeight), Ui.Colors.muted, false, 16)
	letters.LayoutOrder = 1
	local cancel = Ui.button(made.footer, "Cancel", Ui.Colors.off, UDim2.fromOffset(100, RowHeight))
	cancel.LayoutOrder = 2
	local send = Ui.button(made.footer, "Send", Ui.Colors.buy, UDim2.fromOffset(130, RowHeight))
	send.LayoutOrder = 3

	local function showLetters()
		local length = utf8.len(box.Text) or #box.Text
		letters.Text = `{length}/{Config.MaxLength}`
		letters.TextColor3 = if length > Config.MaxLength then Ui.Colors.confirm else Ui.Colors.muted
	end
	box:GetPropertyChangedSignal("Text"):Connect(showLetters)
	showLetters()

	local busy = false
	send.Activated:Connect(function()
		if busy then
			return
		end
		local remotes = ReplicatedStorage:FindFirstChild("FeedbackRemotes")
		local remote = remotes and remotes:FindFirstChild("Send")
		if not remote or not remote:IsA("RemoteFunction") then
			status.Text = "Not ready yet. Try again soon."
			return
		end
		busy = true
		status.Text = "Sending..."
		local ok, answer = pcall(function()
			return remote:InvokeServer(chosen, box.Text)
		end)
		busy = false
		if not ok or type(answer) ~= "table" then
			status.Text = "Couldn't send. Try again in a minute."
			return
		end
		status.Text = if type(answer.message) == "string" then answer.message else ""
		status.TextColor3 = if answer.ok then Ui.Colors.money else Ui.Colors.muted
		if answer.ok then
			box.Text = ""
		end
	end)
	cancel.Activated:Connect(function()
		made.close()
	end)
	made.onClose = function()
		status.TextColor3 = Ui.Colors.muted
	end
	return made
end

function FeedbackController.open()
	if not window then
		window = build()
	end
	local shown = window :: Ui.Window
	shown.status.Text = "No passwords or personal info."
	shown.open(nil)
end

return FeedbackController
