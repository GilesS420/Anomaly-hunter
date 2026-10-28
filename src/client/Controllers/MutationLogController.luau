--!strict
-- The mutation log (Giles 2026-10-24): a small button in the bottom-left corner (on a phone:
-- along the bottom, just left of the hotbar) opens a list
-- of the latest mutation messages ("Your Gravepup picked up Vampire!", cake bites that gave
-- an effect, combos, and what happened while you were away), newest at the top, so a toast
-- you missed can still be read. The server sends each line through
-- ReplicatedStorage.Remotes.MutationLog (server/Notify.log). Kept for this visit only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HotbarController = require(script.Parent:WaitForChild("HotbarController"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local MutationLogController = {}

local MaxEntries = 50
local IconSize = 54
local PanelWidth = 340
local PanelHeight = 300

function MutationLogController.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	local canvas = Scale.canvas(gui)
	gui.Name = "MutationLogUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Phones keep the bottom-left for the thumbstick, so there the button sits along the
	-- bottom just left of the hotbar instead (Giles 2026-10-28), level with its slots.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local lift = if touch then 8 else 16
	local left = if touch then UDim.new(0.5, -HotbarController.Width / 2 - 10 - IconSize) else UDim.new(0, 16)

	local icon = Ui.button(canvas, "", Ui.Colors.equip, UDim2.fromOffset(IconSize, IconSize))
	icon.Name = "MutationLogIcon"
	icon.AnchorPoint = Vector2.new(0, 1)
	icon.Position = UDim2.new(left, UDim.new(1, -lift))
	Ui.corner(icon, 12)
	local glyph = Ui.text(icon, "🧬", UDim2.fromScale(1, 0.62), Ui.Colors.text, true, 26)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	local caption = Ui.text(icon, "Log", UDim2.fromScale(1, 0.38), Ui.Colors.text, true, 13)
	caption.Position = UDim2.fromScale(0, 0.62)
	caption.TextXAlignment = Enum.TextXAlignment.Center

	-- A red dot with how many new lines came in since the log was last open.
	local badge = Instance.new("TextLabel")
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Size = UDim2.fromOffset(22, 22)
	badge.BackgroundColor3 = Ui.Colors.confirm
	badge.Font = Enum.Font.FredokaOne
	badge.TextColor3 = Ui.Colors.text
	badge.TextSize = 13
	badge.Visible = false
	badge.ZIndex = 3
	badge.Parent = icon
	Ui.corner(badge, 11)

	local panel = Instance.new("Frame")
	panel.Name = "MutationLog"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(left, UDim.new(1, -lift - IconSize - 10))
	panel.Size = UDim2.fromOffset(PanelWidth, PanelHeight)
	panel.BackgroundColor3 = Ui.Colors.panel
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = canvas
	Ui.corner(panel, 10)
	Ui.rim(panel, Ui.Colors.rim, 2)

	local title = Ui.text(panel, "Mutations", UDim2.new(1, -60, 0, 30), Ui.Colors.lamp, true, 22)
	title.Font = Ui.TitleFont
	title.Position = UDim2.fromOffset(12, 6)
	local close = Ui.button(panel, "X", Ui.Colors.confirm, UDim2.fromOffset(32, 30))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 6)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(8, 42)
	list.Size = UDim2.new(1, -16, 1, -50)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list

	local empty =
		Ui.text(list, "No mutations yet this visit.", UDim2.new(1, 0, 0, 24), Ui.Colors.muted, false, 16)
	empty.LayoutOrder = 1

	local rows: { Frame } = {} -- oldest first
	local order = 0 -- falls with every new line, so the newest sorts to the top
	local unread = 0

	local function showBadge()
		badge.Visible = unread > 0
		badge.Text = if unread > 9 then "9+" else tostring(unread)
	end

	local function setOpen(open: boolean)
		panel.Visible = open
		if open then
			unread = 0
			showBadge()
			list.CanvasPosition = Vector2.zero
		end
	end
	icon.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)

	local function add(text: string)
		empty.Visible = false
		order -= 1
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundColor3 = Ui.Colors.row
		row.Parent = list
		Ui.corner(row, 6)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.Parent = row
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 15
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Ui.Colors.text
		label.RichText = true
		local escaped = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
		label.Text = `<font color="#BEB4D2">{os.date("%H:%M")}</font>  {escaped}`
		label.Parent = row
		table.insert(rows, row)
		while #rows > MaxEntries do
			(table.remove(rows, 1) :: Frame):Destroy()
		end
		if not panel.Visible then
			unread += 1
			showBadge()
		end
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local event = remotes:WaitForChild("MutationLog") :: RemoteEvent
	event.OnClientEvent:Connect(function(text: unknown)
		if typeof(text) == "string" and text ~= "" then
			add(text)
		end
	end)
end

return MutationLogController
