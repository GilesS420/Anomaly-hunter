--!strict
-- While a Watcher event is live, its icon sits in the bottom-right corner of the screen (on
-- phones, above the jump button). Hover over it (or tap it) to see the event's name and how
-- long is left, plus the effect the event gives mansion monsters and its chance
-- (Watcher.effectLines). It comes with the weather, at the start of the 30 second warning, and shows
-- how long until the event starts until then.
-- Reads the workspace attributes WatcherEvent, WatcherEventEnd, WatcherNext and WatcherSkyAt
-- (WatcherService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local Watcher = require(ReplicatedStorage.Shared.Util.Watcher)
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local EventIconController = {}

local function rgb(color: Events.Rgb?): Color3
	if not color then
		return Ui.Colors.equip
	end
	return Color3.fromRGB(color[1], color[2], color[3])
end

function EventIconController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EventIconUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local small = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local size = if small then 44 else 54
	local lift = if small then 150 else 16 -- phones keep the jump button in that corner

	local icon = Ui.button(gui, "", Ui.Colors.equip, UDim2.fromOffset(size, size))
	icon.Name = "EventIcon"
	icon.AnchorPoint = Vector2.new(1, 1)
	icon.Position = UDim2.new(1, -16, 1, -lift)
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.Visible = false
	Ui.corner(icon, 12)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = icon

	local tip = Instance.new("Frame")
	tip.Name = "Tooltip"
	tip.AnchorPoint = Vector2.new(1, 1) -- above the icon, kept on screen
	tip.Position = UDim2.new(1, 0, 0, -8)
	tip.Size = UDim2.fromOffset(250, 52)
	tip.BackgroundColor3 = Ui.Colors.panel
	tip.Visible = false
	Ui.corner(tip, 8)
	local rim = Ui.rim(tip, Ui.Colors.rim, 2)
	local title = Ui.text(tip, "", UDim2.new(1, -16, 0, 22), Ui.Colors.lamp, true, 18)
	title.Position = UDim2.fromOffset(8, 4)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local left = Ui.text(tip, "", UDim2.new(1, -16, 0, 20), Ui.Colors.text, false, 16)
	left.Position = UDim2.fromOffset(8, 27)
	left.TextXAlignment = Enum.TextXAlignment.Center
	-- The effect lines, under the time; rebuilt for each event.
	local details = Instance.new("Frame")
	details.Name = "Details"
	details.BackgroundTransparency = 1
	details.Position = UDim2.fromOffset(8, 50)
	details.Size = UDim2.new(1, -16, 0, 0)
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = details
	details.Parent = tip
	tip.Parent = icon

	local hovering = false
	local pinned = false -- a tap keeps the tooltip open until the next tap
	icon.MouseEnter:Connect(function()
		hovering = true
	end)
	icon.MouseLeave:Connect(function()
		hovering = false
	end)
	icon.Activated:Connect(function()
		pinned = not pinned
	end)

	-- The live event, or else the one being warned about.
	local function showing(): Events.WatcherEvent?
		return Events.find(workspace:GetAttribute("WatcherEvent"))
			or Events.find(workspace:GetAttribute("WatcherNext"))
	end

	local function refresh()
		local event = showing()
		icon.Visible = event ~= nil and not Ui.anyWindowOpen("BackpackUi")
		if not event then
			pinned = false
			return
		end
		local color = rgb(event.sky and event.sky.edge)
		Ui.paint(icon, color)
		rim.Color = color
		icon.Text = event.icon or "?"
		title.Text = event.name
		for _, child in details:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local lines = Watcher.effectLines(event)
		for index, line in lines do
			local last = index == #lines -- the Familiarity note, quieter
			local label = Ui.text(
				details,
				line,
				UDim2.new(1, 0, 0, 18),
				if last then Ui.Colors.muted else Ui.Colors.text,
				false,
				if last then 13 else 15
			)
			label.LayoutOrder = index
			label.TextXAlignment = Enum.TextXAlignment.Center
		end
		tip.Size = UDim2.fromOffset(250, 52 + #lines * 18 + (if #lines > 0 then 6 else 0))
	end
	workspace:GetAttributeChangedSignal("WatcherEvent"):Connect(refresh)
	workspace:GetAttributeChangedSignal("WatcherNext"):Connect(refresh)
	Ui.windowsChanged:Connect(refresh)
	refresh()

	RunService.Heartbeat:Connect(function()
		tip.Visible = icon.Visible and (hovering or pinned)
		if tip.Visible then
			local now = workspace:GetServerTimeNow()
			if workspace:GetAttribute("WatcherEvent") then
				local ends = tonumber(workspace:GetAttribute("WatcherEventEnd")) or 0
				left.Text = `{Watcher.clock(ends - now)} left`
			else
				local starts = tonumber(workspace:GetAttribute("WatcherSkyAt")) or 0
				left.Text = `Starts in {Watcher.clock(starts - now)}`
			end
		end
	end)
end

return EventIconController
