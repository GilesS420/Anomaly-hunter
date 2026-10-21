--!strict
-- The Settings window, from the HUD's Settings button. One row per setting (Shared.Util.Settings):
-- its name, a line on what it does, and its choices as buttons (volumes in steps of 25%, or
-- On/Off). The chosen one is lit; tapping another saves it straight away (client/Settings).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Settings = require(script.Parent.Parent:WaitForChild("Settings"))
local Shared = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Settings"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local SettingsController = {}

local RowHeight = 96

-- The choices a setting shows, as (label, value) pairs.
local function choices(setting: Shared.Setting): { { label: string, value: any } }
	local list = {}
	if setting.kind == "Volume" then
		for _, step in Shared.VolumeSteps do
			table.insert(list, { label = if step == 0 then "Off" else `{step}%`, value = step })
		end
	elseif setting.kind == "Choice" then
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

	-- Every setting's buttons, to light the chosen one.
	local rows: { [string]: { { button: TextButton, value: any } } } = {}

	local function paint(key: string)
		local current = Settings.get(key)
		for _, entry in rows[key] or {} do
			Ui.paint(entry.button, if entry.value == current then Ui.Colors.equip else Ui.Colors.off)
		end
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

	local hud = player:WaitForChild("PlayerGui"):WaitForChild("HuntUi"):WaitForChild("Hud")
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
