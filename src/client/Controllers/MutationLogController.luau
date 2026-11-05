--!strict
-- The mutation log (Giles 2026-10-24): a small button in the bottom-left corner (on a phone:
-- along the bottom, just left of the hotbar) opens a list
-- of the latest mutation messages ("Your Gravepup picked up Vampire!", cake bites that gave
-- an effect, combos, and what happened while you were away), newest at the top, so a toast
-- you missed can still be read. The server sends each line through
-- ReplicatedStorage.Remotes.MutationLog (server/Notify.log). Kept for this visit only.
-- Next to it sits the friend bonus (Giles 2026-11-04): how much more the Collector pays for
-- the Roblox friends in this server (the FriendsHere attribute, server CommunityService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Community =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Community"))
local HotbarController = require(script.Parent:WaitForChild("HotbarController"))
local ToastController = require(script.Parent:WaitForChild("ToastController"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Icons = require(script.Parent.Parent:WaitForChild("Icons"))

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
	local glyph = Instance.new("Frame") -- a logbook (client/Icons)
	glyph.Size = UDim2.fromScale(1, 0.62)
	glyph.BackgroundTransparency = 1
	glyph.Parent = icon
	Icons.draw(glyph, "Notebook", 0.08)
	local caption = Ui.text(icon, "Log", UDim2.fromScale(1, 0.38), Ui.Colors.text, true, 13)
	caption.Position = UDim2.fromScale(0, 0.62)
	caption.TextXAlignment = Enum.TextXAlignment.Center

	-- The friend bonus, just right of the Log button (left of it on a phone, toward the edge).
	local friendWidth = 78
	local friendLeft = if touch then left - UDim.new(0, friendWidth + 8) else left + UDim.new(0, IconSize + 8)
	local friend = Ui.button(canvas, "", Ui.Colors.off, UDim2.fromOffset(friendWidth, IconSize))
	friend.Name = "FriendBonus"
	friend.AnchorPoint = Vector2.new(0, 1)
	friend.Position = UDim2.new(friendLeft, UDim.new(1, -lift))
	Ui.corner(friend, 12)
	local friendTop = Ui.text(friend, "👥 +0%", UDim2.new(1, -8, 0.6, 0), Ui.Colors.text, true, 20)
	friendTop.Position = UDim2.fromOffset(4, 2)
	friendTop.TextXAlignment = Enum.TextXAlignment.Center
	local friendCaption = Ui.text(friend, "Friends", UDim2.new(1, -8, 0.36, 0), Ui.Colors.muted, true, 13)
	friendCaption.Position = UDim2.new(0, 4, 0.6, 0)
	friendCaption.TextXAlignment = Enum.TextXAlignment.Center
	local perFriend = math.floor(Community.FriendSellBonus * 100 + 0.5)
	local function showFriends()
		local count = tonumber(player:GetAttribute("FriendsHere")) or 0
		friendTop.Text = `👥 +{count * perFriend}%`
		friendTop.TextColor3 = if count > 0 then Ui.Colors.money else Ui.Colors.muted
		friend.BackgroundColor3 = if count > 0 then Ui.Colors.buy else Ui.Colors.off
	end
	player:GetAttributeChangedSignal("FriendsHere"):Connect(showFriends)
	showFriends()
	friend.Activated:Connect(function()
		local count = tonumber(player:GetAttribute("FriendsHere")) or 0
		ToastController.show(
			if count == 0
				then `Friend bonus: +{perFriend}% sell per friend here.`
				else `Friend bonus: {count} {if count == 1 then "friend" else "friends"} here, so the Collector pays {count * perFriend}% more.`
		)
	end)

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
	Ui.rim(panel, Ui.Style.line, 1)

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
