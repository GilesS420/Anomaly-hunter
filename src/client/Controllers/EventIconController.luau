--!strict
-- While a Watcher event is live, its icon sits in the bottom-right corner of the screen (on
-- phones, above the jump button). Hover over it (or tap it) to see the event's name and how
-- long is left.
-- Reads the workspace attributes WatcherEvent and WatcherEventEnd (WatcherService).

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
	tip.Size = UDim2.fromOffset(190, 52)
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

	local function refresh()
		local event = Events.find(workspace:GetAttribute("WatcherEvent"))
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
	end
	workspace:GetAttributeChangedSignal("WatcherEvent"):Connect(refresh)
	Ui.windowsChanged:Connect(refresh)
	refresh()

	RunService.Heartbeat:Connect(function()
		tip.Visible = icon.Visible and (hovering or pinned)
		if tip.Visible then
			local ends = tonumber(workspace:GetAttribute("WatcherEventEnd")) or 0
			left.Text = `{Watcher.clock(math.max(ends - workspace:GetServerTimeNow(), 0))} left`
		end
	end)
end

return EventIconController
