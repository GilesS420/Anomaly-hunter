--!strict
-- Hunt HUD on the left side, halfway down (the top-left corner belongs to Roblox's chat
-- window, the top-right to the player list): your money, your hearts while you're in a zone, the
-- monster you're carrying, a big "Return Charm" button (tap or click it; R works too on
-- a keyboard) that takes you home, and in a zone a button per kind of Bait Bell (Bait, Silver,
-- Gold; B rings the cheapest you own) that brings a rarer monster to you. Each button shows
-- only if you own one. Under them a row of square picture buttons is always there: a
-- backpack (G, your items and monsters, InventoryController), a book (C, CodexController), a
-- scroll (J, MissionController), a gear (SettingsController) and a coin (the Robux Store,
-- StoreController), in Hud.Menu.
-- Everything shown comes from the server: player attributes Zone / Hearts / Carrying /
-- CarryingSize / CarryingCount / BagSize / ReturnCharms / BaitBells / SilverBells / GoldBells and
-- leaderstats.Money.
-- Messages ("Entering Murky Bayou") are toasts now, see ToastController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Icons = require(script.Parent.Parent:WaitForChild("Icons"))

local HuntController = {}

local player = Players.LocalPlayer

local ROW_HEIGHT = 30
local HUD_WIDTH = 300
local MENU_SIZE = 52 -- the square menu buttons, about a thumb wide on a phone (5 fit in HUD_WIDTH)

-- The square menu buttons, left to right: the name (other controllers find the button by
-- it), the picture, the key and the colour.
local MenuButtons: { { name: string, icon: Icons.Kind, key: string?, color: Color3 } } = {
	{ name = "Backpack", icon = "Backpack", key = "G", color = Color3.fromRGB(110, 90, 170) },
	{ name = "Codex", icon = "Book", key = "C", color = Color3.fromRGB(180, 115, 60) },
	{ name = "Missions", icon = "Scroll", key = "J", color = Color3.fromRGB(210, 160, 50) },
	{ name = "Settings", icon = "Gear", key = nil, color = Color3.fromRGB(130, 130, 150) },
	{ name = "Store", icon = "Coin", key = nil, color = Color3.fromRGB(0, 140, 90) },
}

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
	text.Font = Enum.Font.FredokaOne
	text.Text = ""
	text.Visible = false
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 26
	size.Parent = text
	text.Parent = parent
	return text
end

-- The kinds of Bait Bell, cheapest first: Workshop id, name, button color.
local Bells = {
	{ id = "BaitBell", name = "Bait Bell", color = Color3.fromRGB(190, 110, 50) },
	{ id = "SilverBell", name = "Silver Bell", color = Color3.fromRGB(110, 125, 160) },
	{ id = "GoldBell", name = "Gold Bell", color = Color3.fromRGB(200, 150, 20) },
}

local function buildUi(): (TextLabel, TextLabel, TextLabel, TextButton, { TextButton })
	local gui = Instance.new("ScreenGui")
	local canvas = Scale.canvas(gui) -- shrinks everything to fit a phone (client/Scale)
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
	column.Parent = canvas
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
		button.Font = Enum.Font.FredokaOne
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
	-- LayoutOrder 5.1, 5.2, 5.3: between the charm and the menu row.
	local bells: { TextButton } = {}
	for i, kind in Bells do
		table.insert(bells, itemButton(kind.id, 5 + i / 10, kind.color, kind.name))
	end
	-- A row of little square picture buttons, always there: Backpack (G, InventoryController),
	-- Codex (C, CodexController), Missions (J, MissionController) and Settings
	-- (SettingsController). With a keyboard each shows its key in the corner, and the name
	-- pops up above it while the mouse is over it.
	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.LayoutOrder = 7
	menu.Size = UDim2.new(1, 0, 0, MENU_SIZE)
	menu.BackgroundTransparency = 1
	menu.Parent = column
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, 8)
	row.Parent = menu
	for order, entry in MenuButtons do
		local button = Instance.new("TextButton")
		button.Name = entry.name
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(MENU_SIZE, MENU_SIZE)
		button.Text = ""
		button.AutoButtonColor = true
		Ui.paint(button, entry.color)
		Ui.corner(button, 10)
		Icons.draw(button, entry.icon)
		if keys and entry.key then
			local key = Ui.text(button, entry.key, UDim2.fromOffset(18, 18), Ui.Colors.text, true, 14)
			key.Name = "Key"
			key.AnchorPoint = Vector2.new(1, 1)
			key.Position = UDim2.new(1, -2, 1, -2)
			key.BackgroundTransparency = 0.2
			key.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
			key.TextXAlignment = Enum.TextXAlignment.Center
			key.ZIndex = 2
			Ui.corner(key, 5)
		end
		if UserInputService.MouseEnabled then -- a tap would leave the name stuck on a phone
			local tip = Ui.text(button, entry.name, UDim2.fromOffset(110, 22), Ui.Colors.text, true, 18)
			tip.Name = "Tip"
			tip.AnchorPoint = Vector2.new(0.5, 1)
			tip.Position = UDim2.new(0.5, 0, 0, -4)
			tip.TextXAlignment = Enum.TextXAlignment.Center
			tip.TextStrokeTransparency = 0
			tip.ZIndex = 3
			tip.Visible = false
			button.MouseEnter:Connect(function()
				tip.Visible = true
			end)
			button.MouseLeave:Connect(function()
				tip.Visible = false
			end)
		end
		button.Parent = menu
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	return money, hearts, carrying, charm, bells
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
	local money, hearts, carrying, button, bells = buildUi()
	watchMoney(money)

	local function refresh()
		local inZone = player:GetAttribute("Zone") ~= nil
		local count = player:GetAttribute("Hearts")
		hearts.Text = if inZone and typeof(count) == "number" then string.rep("♥ ", count) else ""
		hearts.Visible = hearts.Text ~= ""

		local monsterId = player:GetAttribute("Carrying")
		local size = player:GetAttribute("CarryingSize")
		local inBag = player:GetAttribute("CarryingCount")
		local bagSize = player:GetAttribute("BagSize")
		local bagFull = typeof(inBag) == "number" and typeof(bagSize) == "number" and inBag >= bagSize
		if typeof(monsterId) == "string" then
			local sizeText = if typeof(size) == "string" then `{size} ` else ""
			local bagText = if typeof(inBag) == "number"
					and typeof(bagSize) == "number"
					and bagSize > 1
				then ` ({inBag}/{bagSize})`
				else ""
			carrying.Text = `Carrying: {sizeText}{Format.name(monsterId)}{bagText}`
			-- With room for more than one, list everything in the vacuum.
			local bagList = player:GetAttribute("BagList")
			if typeof(bagList) == "string" and typeof(bagSize) == "number" and bagSize > 1 then
				local lines = string.split(bagList, "\n")
				carrying.Text = `In your vacuum ({#lines}/{bagSize}):\n• {table.concat(lines, "\n• ")}`
			end
		else
			carrying.Text = ""
		end
		local _, lineCount = string.gsub(carrying.Text, "\n", "")
		carrying.Size = UDim2.new(1, 0, 0, ROW_HEIGHT * (lineCount + 1))
		carrying.Visible = carrying.Text ~= ""

		-- The charm only makes sense away from home, and only if you own one.
		local charms = player:GetAttribute("ReturnCharms")
		local hasCharm = typeof(charms) == "number" and charms > 0
		button.Visible = hasCharm and (inZone or typeof(monsterId) == "string")

		-- A bell only works in a zone with room in the bag, and only if you own one. The B key
		-- rings the first (cheapest) one showing.
		local keyShown = false
		for i, kind in Bells do
			local bell = bells[i]
			local owned = player:GetAttribute(`{kind.id}s`)
			bell.Visible = inZone and not bagFull and typeof(owned) == "number" and owned > 0
			if bell.Visible then
				local keyText = if UserInputService.KeyboardEnabled and not keyShown then " (B)" else ""
				keyShown = true
				bell.Text = `{kind.name} x{owned}{keyText}`
			end
		end
	end
	for _, attribute in
		{
			"Zone",
			"Hearts",
			"Carrying",
			"CarryingSize",
			"CarryingCount",
			"BagSize",
			"BagList",
			"ReturnCharms",
			"BaitBells",
			"SilverBells",
			"GoldBells",
		}
	do
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
	local function ringBell(bellId: string)
		if os.clock() - lastRung < 1 then
			return
		end
		lastRung = os.clock()
		UseBaitBell:FireServer(bellId)
	end

	-- Activated works for mouse clicks and taps alike.
	button.Activated:Connect(useCharm)
	for i, kind in Bells do
		bells[i].Activated:Connect(function()
			ringBell(kind.id)
		end)
	end

	-- Optional keyboard shortcuts.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R and button.Visible then
			useCharm()
		elseif input.KeyCode == Enum.KeyCode.B then
			for i, kind in Bells do
				if bells[i].Visible then
					ringBell(kind.id)
					break
				end
			end
		end
	end)
end

return HuntController
