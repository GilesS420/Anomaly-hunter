--!strict
-- The Settings window, from the HUD's Settings button. One row per setting (Shared.Util.Settings):
-- its name, a line on what it does, and either a slider (volumes, 0 to 100%: you hear it change
-- while you drag, it's saved when you let go) or its choices as buttons (the chosen one is lit;
-- tapping another saves it straight away, see client/Settings).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Settings = require(script.Parent.Parent:WaitForChild("Settings"))
local Shared = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Settings"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local SettingsController = {}

local RowHeight = 96

-- The choices a setting shows, as (label, value) pairs.
local function choices(setting: Shared.Setting): { { label: string, value: any } }
	local list = {}
	if setting.kind == "Choice" then
		for _, option in setting.options :: { string } do
			table.insert(list, { label = option, value = option })
		end
	else
		list = { { label = "On", value = true }, { label = "Off", value = false } }
	end
	return list
end

function SettingsController.start()
	local player = Players.LocalPlayer
	local window = Ui.window("SettingsUi", "Settings")
	window.status.Text = "Saved for next time too"

	-- Every setting's buttons, to light the chosen one, and every slider, to move it.
	local rows: { [string]: { { button: TextButton, value: any } } } = {}
	local sliders: { [string]: (value: number) -> () } = {}

	local function paint(key: string)
		local current = Settings.get(key)
		local slider = sliders[key]
		if slider and typeof(current) == "number" then
			slider(current)
		end
		for _, entry in rows[key] or {} do
			Ui.paint(entry.button, if entry.value == current then Ui.Colors.equip else Ui.Colors.off)
		end
	end

	-- A volume slider: a track, the filled part, a round knob and the percent on the right.
	local function slider(strip: Frame, key: string)
		local layout = strip:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout:Destroy() -- placed by hand instead
		end
		local track = Instance.new("TextButton")
		track.Text = ""
		track.AutoButtonColor = false
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Position = UDim2.new(0, 10, 0.5, 0)
		track.Size = UDim2.new(1, -86, 0, 8)
		track.BackgroundColor3 = Ui.Colors.off
		track.Parent = strip
		Ui.corner(track, 4)
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = Ui.Colors.lamp
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = track
		Ui.corner(fill, 4)
		local knob = Instance.new("Frame")
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.Position = UDim2.fromScale(1, 0.5)
		knob.Size = UDim2.fromOffset(22, 22)
		knob.BackgroundColor3 = Color3.fromRGB(245, 235, 220)
		knob.Parent = track
		Ui.corner(knob, 11)
		Ui.rim(knob, Ui.Colors.lamp, 2)
		local label = Ui.text(strip, "", UDim2.new(0, 60, 1, 0), Ui.Colors.text, true, 18)
		label.AnchorPoint = Vector2.new(1, 0)
		label.Position = UDim2.fromScale(1, 0)
		label.TextXAlignment = Enum.TextXAlignment.Right

		sliders[key] = function(value: number)
			local share = value / Shared.VolumeMax
			fill.Size = UDim2.fromScale(share, 1)
			knob.Position = UDim2.fromScale(share, 0.5)
			label.Text = if value == 0 then "Off" else `{value}%`
		end

		-- The value under a screen x position.
		local function at(x: number): number
			local share = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
			return math.floor(math.clamp(share, 0, 1) * Shared.VolumeMax + 0.5)
		end
		local dragging: InputObject? = nil
		track.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				dragging = input
				Settings.set(key, at(input.Position.X), false)
			end
		end)
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if not dragging then
				return
			end
			local mouse = input.UserInputType == Enum.UserInputType.MouseMovement
			if mouse or input == dragging then
				Settings.set(key, at(input.Position.X), false)
			end
		end)
		UserInputService.InputEnded:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if dragging and (input == dragging or kind == Enum.UserInputType.MouseButton1) then
				dragging = nil
				Settings.set(key, at(input.Position.X), true)
			end
		end)
	end

	for order, setting in Shared.List do
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, RowHeight)
		row.BackgroundColor3 = Ui.Colors.row
		row.Parent = window.list
		Ui.corner(row, 10)
		Ui.rim(row, Color3.fromRGB(58, 48, 78), 1)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.PaddingTop = UDim.new(0, 6)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = row

		Ui.text(row, setting.name, UDim2.new(1, 0, 0, 24), Ui.Colors.text, true, 20)
		local detail = Ui.text(row, setting.detail, UDim2.new(1, 0, 0, 18), Ui.Colors.muted, false, 14)
		detail.Position = UDim2.fromOffset(0, 26)

		local strip = Instance.new("Frame")
		strip.BackgroundTransparency = 1
		strip.AnchorPoint = Vector2.new(0, 1)
		strip.Position = UDim2.fromScale(0, 1)
		strip.Size = UDim2.new(1, 0, 0, 36)
		strip.Parent = row
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = strip

		if setting.kind == "Volume" then
			slider(strip, setting.key)
			paint(setting.key)
			continue
		end
		local options = choices(setting)
		local entries = {}
		for i, choice in options do
			local button = Ui.button(
				strip,
				choice.label,
				Ui.Colors.off,
				UDim2.new(1 / #options, -6 * (#options - 1) / #options, 1, 0)
			)
			button.LayoutOrder = i
			local key, value = setting.key, choice.value
			button.Activated:Connect(function()
				Settings.set(key, value)
			end)
			table.insert(entries, { button = button, value = value })
		end
		rows[setting.key] = entries
		paint(setting.key)
	end

	Settings.changed(paint)

	local hud =
		player:WaitForChild("PlayerGui"):WaitForChild("HuntUi"):WaitForChild("Canvas"):WaitForChild("Hud")
	local button = hud:WaitForChild("Settings") :: TextButton
	button.Activated:Connect(function()
		if window.isOpen() then
			window.close()
		else
			window.open(nil)
		end
	end)
	Locks.guard(button, "Settings")
end

return SettingsController
