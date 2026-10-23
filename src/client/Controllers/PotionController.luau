--!strict
-- While a luck potion is going, a small flask icon sits just left of the event icon in the
-- bottom-right corner, with the time it has left inside it. Hover over it (or tap it) to see
-- the potion's name and boost. Reads the player attributes Potion and PotionLeft
-- (server/Services/HuntService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Potions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Potions"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local PotionController = {}

local Colors: { [string]: Color3 } = {
	LuckyTonic = Color3.fromRGB(90, 230, 120),
	GildedElixir = Color3.fromRGB(255, 200, 50),
	PrismDraught = Color3.fromRGB(200, 120, 255),
}

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function PotionController.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	local canvas = Scale.canvas(gui)
	gui.Name = "PotionUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Same row as the event icon (EventIconController), one icon to its left.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local size = 54
	local lift = if touch then 170 else 16

	local icon = Ui.button(canvas, "", Ui.Colors.equip, UDim2.fromOffset(size, size))
	icon.Name = "PotionIcon"
	icon.AnchorPoint = Vector2.new(1, 1)
	icon.Position = UDim2.new(1, -16 - size - 10, 1, -lift)
	icon.Visible = false
	Ui.corner(icon, 12)
	-- The flask on top, the time left under it, both inside the icon.
	local flask = Ui.text(icon, "🧪", UDim2.fromScale(1, 0.58), Ui.Colors.text, true, 26)
	flask.TextXAlignment = Enum.TextXAlignment.Center
	local left = Ui.text(icon, "", UDim2.fromScale(1, 0.42), Ui.Colors.text, true, 14)
	left.Position = UDim2.fromScale(0, 0.58)
	left.TextXAlignment = Enum.TextXAlignment.Center

	local tip = Instance.new("Frame")
	tip.AnchorPoint = Vector2.new(1, 1)
	tip.Position = UDim2.new(1, 0, 0, -8)
	tip.Size = UDim2.fromOffset(230, 50)
	tip.BackgroundColor3 = Ui.Colors.panel
	tip.Visible = false
	tip.Parent = icon
	Ui.corner(tip, 8)
	Ui.rim(tip, Ui.Colors.rim, 2)
	local name = Ui.text(tip, "", UDim2.new(1, -16, 0, 22), Ui.Colors.lamp, true, 18)
	name.Position = UDim2.fromOffset(8, 4)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local boost = Ui.text(tip, "", UDim2.new(1, -16, 0, 18), Ui.Colors.text, false, 15)
	boost.Position = UDim2.fromOffset(8, 27)
	boost.TextXAlignment = Enum.TextXAlignment.Center

	icon.MouseEnter:Connect(function()
		tip.Visible = true
	end)
	icon.MouseLeave:Connect(function()
		tip.Visible = false
	end)
	icon.Activated:Connect(function()
		tip.Visible = not tip.Visible
	end)

	local function update()
		local id = player:GetAttribute("Potion")
		local seconds = player:GetAttribute("PotionLeft")
		local item = if typeof(id) == "string" then Potions.item(id) else nil
		if not item or typeof(seconds) ~= "number" or seconds <= 0 then
			icon.Visible = false
			tip.Visible = false
			return
		end
		Ui.paint(icon, Colors[item.id] or Ui.Colors.equip)
		left.Text = clock(seconds)
		name.Text = item.name
		boost.Text = `Rare colours x{item.potionBoost or 1}`
		icon.Visible = true
	end
	player:GetAttributeChangedSignal("Potion"):Connect(update)
	player:GetAttributeChangedSignal("PotionLeft"):Connect(update)
	update()
end

return PotionController
