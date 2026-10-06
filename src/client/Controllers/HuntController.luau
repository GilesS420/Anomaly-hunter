--!strict
-- Hunt HUD on the left side, halfway down (the top-left corner belongs to Roblox's chat
-- window, the top-right to the player list): your money, your hearts while you're in a zone, the
-- monster you're carrying, a big "Return Charm" button (tap or click it; R works too on
-- a keyboard) that takes you home, and in a zone a "Bait Bell" button (B) that brings a rarer
-- monster to you. Each button shows only if you own one. Everything shown comes from the
-- server: player attributes Zone / Hearts / Carrying / CarryingSize / ReturnCharms / BaitBells
-- and leaderstats.Money.
-- Messages ("Entering Murky Bayou") are toasts now, see ToastController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local HuntController = {}

local player = Players.LocalPlayer

local ROW_HEIGHT = 30
local HUD_WIDTH = 300

local function label(name: string, order: number, color: Color3, parent: Instance): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.LayoutOrder = order
	text.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	text.BackgroundTransparency = 1
	text.TextColor3 = color
	text.TextStrokeTransparency = 0
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Font = Enum.Font.GothamBold
	text.Text = ""
	text.Visible = false
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 26
	size.Parent = text
	text.Parent = parent
	return text
end

local function buildUi(): (TextLabel, TextLabel, TextLabel, TextButton, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HuntUi"
	gui.ResetOnSpawn = false

	-- One column; hidden rows take no space, so whatever is showing stays packed together.
	local column = Instance.new("Frame")
	column.Name = "Hud"
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, 16, 0.5, 0)
	column.Size = UDim2.fromOffset(HUD_WIDTH, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.BackgroundTransparency = 1
	column.Parent = gui
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = column

	local money = label("Money", 1, Color3.fromRGB(140, 255, 140), column)
	local hearts = label("Hearts", 2, Color3.fromRGB(255, 90, 110), column)
	local carrying = label("Carrying", 3, Color3.new(1, 1, 1), column)

	-- Big enough to hit with a thumb on a tablet.
	local function itemButton(name: string, order: number, color: Color3, text: string): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(200, 48)
		button.BackgroundColor3 = color
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.GothamBold
		button.TextScaled = true
		button.AutoButtonColor = true
		button.Text = text
		button.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = button
		button.Parent = column
		return button
	end
	local keys = UserInputService.KeyboardEnabled
	local charm = itemButton(
		"ReturnCharm",
		4,
		Color3.fromRGB(120, 70, 200),
		if keys then "Return Charm (R)" else "Return Charm"
	)
	local bell =
		itemButton("BaitBell", 5, Color3.fromRGB(190, 110, 50), if keys then "Bait Bell (B)" else "Bait Bell")

	gui.Parent = player:WaitForChild("PlayerGui")
	return money, hearts, carrying, charm, bell
end

-- Keeps the money row in step with leaderstats.Money, which the server makes once your
-- save has loaded (so it may not exist yet when we start).
local function watchMoney(money: TextLabel)
	local function showValue(value: NumberValue)
		local function update()
			money.Text = `Money: {Format.money(value.Value)}`
			money.Visible = true
		end
		value:GetPropertyChangedSignal("Value"):Connect(update)
		update()
	end

	local function watchStats(stats: Instance)
		if stats.Name ~= "leaderstats" then
			return
		end
		local function check(child: Instance)
			if child.Name == "Money" and child:IsA("NumberValue") then
				showValue(child)
			end
		end
		stats.ChildAdded:Connect(check)
		for _, child in stats:GetChildren() do
			check(child)
		end
	end

	player.ChildAdded:Connect(watchStats)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		watchStats(stats)
	end
end

function HuntController.start()
	local money, hearts, carrying, button, bell = buildUi()
	watchMoney(money)

	local function refresh()
		local inZone = player:GetAttribute("Zone") ~= nil
		local count = player:GetAttribute("Hearts")
		hearts.Text = if inZone and typeof(count) == "number" then string.rep("♥ ", count) else ""
		hearts.Visible = hearts.Text ~= ""

		local monsterId = player:GetAttribute("Carrying")
		local size = player:GetAttribute("CarryingSize")
		if typeof(monsterId) == "string" then
			local sizeText = if typeof(size) == "string" then `{size} ` else ""
			carrying.Text = `Carrying: {sizeText}{Format.name(monsterId)}`
		else
			carrying.Text = ""
		end
		carrying.Visible = carrying.Text ~= ""

		-- The charm only makes sense away from home, and only if you own one.
		local charms = player:GetAttribute("ReturnCharms")
		local hasCharm = typeof(charms) == "number" and charms > 0
		button.Visible = hasCharm and (inZone or typeof(monsterId) == "string")

		-- The bell only works in a zone with an empty vacuum, and only if you own one.
		local bells = player:GetAttribute("BaitBells")
		bell.Visible = inZone and typeof(monsterId) ~= "string" and typeof(bells) == "number" and bells > 0
		if bell.Visible then
			local keyText = if UserInputService.KeyboardEnabled then " (B)" else ""
			bell.Text = `Bait Bell x{bells}{keyText}`
		end
	end
	for _, attribute in { "Zone", "Hearts", "Carrying", "CarryingSize", "ReturnCharms", "BaitBells" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()

	local remotes = ReplicatedStorage:WaitForChild("HuntRemotes")
	local UseReturnCharm = remotes:WaitForChild("UseReturnCharm") :: RemoteEvent
	local UseBaitBell = remotes:WaitForChild("UseBaitBell") :: RemoteEvent

	-- A short cooldown so a double tap doesn't use two charms.
	local lastUsed = 0
	local function useCharm()
		if os.clock() - lastUsed < 1 then
			return
		end
		lastUsed = os.clock()
		UseReturnCharm:FireServer()
	end

	local lastRung = 0
	local function ringBell()
		if os.clock() - lastRung < 1 then
			return
		end
		lastRung = os.clock()
		UseBaitBell:FireServer()
	end

	-- Activated works for mouse clicks and taps alike.
	button.Activated:Connect(useCharm)
	bell.Activated:Connect(ringBell)

	-- Optional keyboard shortcuts.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R and button.Visible then
			useCharm()
		elseif input.KeyCode == Enum.KeyCode.B and bell.Visible then
			ringBell()
		end
	end)
end

return HuntController
