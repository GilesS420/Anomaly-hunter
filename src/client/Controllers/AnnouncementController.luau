--!strict
-- Admin announcements: a big banner across the top of the screen for everyone in the server,
-- and the same line in the chat so it can be read again later. An admin sends one from the
-- admin panel (F2, Announce tab) or with /announce; the server filters it and fires
--   ReplicatedStorage.Remotes.Announcement   server -> client: (text: string)
-- (see server/Notify.luau). A new announcement replaces the one on screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Scale = require(script.Parent.Parent.Scale)
local Ui = require(script.Parent.Parent.Ui)

local AnnouncementController = {}

local player = Players.LocalPlayer

local SHOW_SECONDS = 7 -- a short one stays this long
local SECONDS_PER_LETTER = 0.07 -- longer ones stay longer
local MAX_SHOW_SECONDS = 15
local FADE_SECONDS = 0.6
local TOP = 150 -- below the toasts

local banner: Frame
local title: TextLabel
local body: TextLabel
local shown = 0 -- bumps with each announcement, so an old fade doesn't hide a new one

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AnnouncementUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11 -- above the toasts
	gui.IgnoreGuiInset = true
	local canvas = Scale.canvas(gui)

	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, TOP)
	banner.Size = UDim2.new(0.7, 0, 0, 0)
	banner.AutomaticSize = Enum.AutomaticSize.Y
	banner.BackgroundColor3 = Ui.Colors.panel
	banner.BackgroundTransparency = 0.1
	banner.Visible = false
	banner.Parent = canvas
	Ui.corner(banner, 12)
	Ui.rim(banner, Ui.Colors.lamp, 2)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(300, 0)
	limit.MaxSize = Vector2.new(720, math.huge)
	limit.Parent = banner
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = banner
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = banner

	title = Instance.new("TextLabel")
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 24
	title.TextColor3 = Ui.Colors.lamp
	title.Text = "📢 Announcement"
	title.Parent = banner

	body = Instance.new("TextLabel")
	body.LayoutOrder = 2
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.FredokaOne
	body.TextSize = 22
	body.TextWrapped = true
	body.TextColor3 = Ui.Colors.text
	body.TextStrokeTransparency = 0.6
	body.Parent = banner

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function setFade(amount: number)
	banner.BackgroundTransparency = 0.1 + 0.9 * amount
	title.TextTransparency = amount
	body.TextTransparency = amount
	body.TextStrokeTransparency = 0.6 + 0.4 * amount
	local rim = banner:FindFirstChildOfClass("UIStroke")
	if rim then
		rim.Transparency = amount
	end
end

-- Chat shows rich text, so < > & are written out.
local function escape(text: string): string
	return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function addToChat(text: string)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local channel = channels and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
		if channel and channel:IsA("TextChannel") then
			channel:DisplaySystemMessage(`<font color="#FFB054">📢 {escape(text)}</font>`)
		end
	end)
end

local function show(text: string)
	shown += 1
	local mine = shown
	body.Text = text
	setFade(0)
	banner.Visible = true
	addToChat(text)
	local seconds = math.clamp(2 + #text * SECONDS_PER_LETTER, SHOW_SECONDS, MAX_SHOW_SECONDS)
	task.delay(seconds, function()
		if mine ~= shown then
			return
		end
		local fade = Instance.new("NumberValue")
		fade.Changed:Connect(function(value)
			if mine == shown then
				setFade(value)
			end
		end)
		local tween = TweenService:Create(fade, TweenInfo.new(FADE_SECONDS), { Value = 1 })
		tween:Play()
		tween.Completed:Wait()
		fade:Destroy()
		if mine == shown then
			banner.Visible = false
		end
	end)
end

function AnnouncementController.start()
	build()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local Announcement = remotes:WaitForChild("Announcement") :: RemoteEvent
	Announcement.OnClientEvent:Connect(function(text: unknown)
		if typeof(text) == "string" and text ~= "" then
			show(text)
		end
	end)
end

return AnnouncementController
