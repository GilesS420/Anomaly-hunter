--!strict
-- Little pop-up messages near the top of the screen ("Caught a Big Wisp Jack!").
-- The server sends them through ReplicatedStorage.Remotes.Toast (see server/Notify.luau).
-- Up to 3 show at once, newest at the bottom; each fades away after a few seconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ToastController = {}

local player = Players.LocalPlayer

local MAX_TOASTS = 3
local SHOW_SECONDS = 3
local FADE_SECONDS = 0.5
local ROW_HEIGHT = 40

type Toast = { frame: Frame, label: TextLabel, text: string, token: number, tweens: { Tween } }

local shown: { Toast } = {} -- oldest first
local order = 0 -- LayoutOrder for the next toast, so new ones go to the bottom

local function buildUi(): Frame
	local gui = Instance.new("ScreenGui")
	gui.Name = "ToastUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10 -- above the other HUD pieces

	-- Centred near the top; 60% of the screen wide but never narrower than 280 pixels.
	local holder = Instance.new("Frame")
	holder.Name = "Toasts"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 12)
	holder.Size = UDim2.new(0.6, 0, 0, (ROW_HEIGHT + 6) * MAX_TOASTS)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(280, 0)
	limit.Parent = holder

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.Parent = holder

	gui.Parent = player:WaitForChild("PlayerGui")
	return holder
end

local function remove(toast: Toast)
	local index = table.find(shown, toast)
	if index then
		table.remove(shown, index)
	end
	toast.frame:Destroy()
end

-- Waits SHOW_SECONDS, then fades the toast out. A newer token (same text shown again)
-- cancels the old countdown.
local function scheduleFade(toast: Toast)
	toast.token += 1
	local token = toast.token
	task.delay(SHOW_SECONDS, function()
		if token ~= toast.token or not toast.frame.Parent then
			return
		end
		local info = TweenInfo.new(FADE_SECONDS)
		toast.tweens = {
			TweenService:Create(toast.frame, info, { BackgroundTransparency = 1 }),
			TweenService:Create(toast.label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }),
		}
		for _, tween in toast.tweens do
			tween:Play()
		end
		task.delay(FADE_SECONDS, function()
			if token == toast.token then
				remove(toast)
			end
		end)
	end)
end

local function show(holder: Frame, text: string)
	-- The same message again (e.g. tapping a locked gate twice): keep the one on screen.
	local newest = shown[#shown]
	if newest and newest.text == text then
		for _, tween in newest.tweens do
			tween:Cancel() -- stop a fade that already started
		end
		newest.tweens = {}
		newest.frame.BackgroundTransparency = 0.35
		newest.label.TextTransparency = 0
		newest.label.TextStrokeTransparency = 0.6
		scheduleFade(newest)
		return
	end

	-- Make room: the oldest message goes first.
	while #shown >= MAX_TOASTS do
		remove(shown[1])
	end

	order += 1
	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -20, 1, -8)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.6
	label.TextScaled = true -- shrinks long messages to fit on small screens
	label.TextWrapped = true
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 28
	size.MinTextSize = 10
	size.Parent = label
	label.Parent = frame
	frame.Parent = holder

	local toast: Toast = { frame = frame, label = label, text = text, token = 0, tweens = {} }
	table.insert(shown, toast)
	scheduleFade(toast)
end

function ToastController.start()
	local holder = buildUi()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local Toast = remotes:WaitForChild("Toast") :: RemoteEvent
	Toast.OnClientEvent:Connect(function(text: unknown)
		if typeof(text) == "string" and text ~= "" then
			show(holder, text)
		end
	end)
end

return ToastController
