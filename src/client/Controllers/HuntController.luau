--!strict
-- Hunt HUD. Your money sits big in the top-left corner, just under Roblox's own menu buttons
-- (Giles 2026-10-29). Under it, from the top down, a stack of square picture buttons is always
-- there: a backpack (G, your items and monsters, InventoryController), a book (C,
-- CodexController), a scroll (J, MissionController), a gift (playtime gifts, PlaytimeController),
-- a gear (SettingsController) and a coin (the Robux Store, StoreController), in Hud.Menu. Right of that stack, in Hud.Side: your hearts
-- while you're in a zone, the monster you're carrying, a "Return Charm" button (tap or click
-- it; R works too on a keyboard) that takes you home, and in a zone a button per kind of Bait
-- Bell (Bait, Silver, Gold; B rings the cheapest you own) that brings a rarer monster to you.
-- Each button shows only if you own one.
-- Both stacks hang from the top (they used to be centred on the left edge, so in a zone on a
-- phone the bells pushed everything up into the money and Roblox's top bar and down into the
-- Log/Friends buttons; Giles 2026-11-05). Side buttons sit beside the menu, never above it, so
-- however many show, the menu stays put.
-- Everything shown comes from the server: player attributes Zone / Hearts / Carrying /
-- CarryingSize / CarryingCount / BagSize / ReturnCharms / BaitBells / SilverBells / GoldBells and
-- leaderstats.Money.
-- Messages are toasts, see ToastController (zone entry: one line on the first trip per visit).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Attacks = require(Shared:WaitForChild("Util"):WaitForChild("Attacks"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Goals = require(Shared:WaitForChild("Util"):WaitForChild("Goals"))
local Rookie = require(Shared:WaitForChild("Config"):WaitForChild("Rookie"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Icons = require(script.Parent.Parent:WaitForChild("Icons"))

local HuntController = {}

local player = Players.LocalPlayer

local ROW_HEIGHT = 30
local HUD_WIDTH = 260 -- the Side stack right of the menu
local MENU_SIZE = 58 -- the square menu buttons, about a thumb wide on a phone
local MENU_GAP = 8
local MONEY_TOP = 6
local MONEY_HEIGHT = 44 -- text size of the money in the top-left corner
local ITEM_WIDTH, ITEM_HEIGHT = 180, 42 -- Return Charm and bell buttons

-- The square menu buttons, top to bottom: the name (other controllers find the button by
-- it), the picture, the key and the colour.
local MenuButtons: { { name: string, icon: Icons.Kind, key: string?, color: Color3 } } = {
	{ name = "Backpack", icon = "Backpack", key = "G", color = Color3.fromRGB(110, 90, 170) },
	{ name = "Codex", icon = "Book", key = "C", color = Color3.fromRGB(180, 115, 60) },
	{ name = "Missions", icon = "Scroll", key = "J", color = Color3.fromRGB(210, 160, 50) },
	{ name = "Gifts", icon = "Gift", key = nil, color = Color3.fromRGB(200, 80, 110) },
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

-- The player's money, or nil before the save has loaded.
local function moneyNow(): number?
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Money")
	return if value and value:IsA("NumberValue") then value.Value else nil
end

-- The "Next goal" bar at the top of the side column (Giles 2026-11-05): the cheapest vacuum or
-- wing you don't own yet (the server picks it, Util/Goals, attributes GoalName and GoalPrice),
-- filling up with your money. Under it, while it lasts, the rookie hour's countdown
-- (RookieSeconds). Both stay hidden during the tutorial (the server sets nothing then).
local function buildGoal(column: Frame)
	local box = Instance.new("Frame")
	box.Name = "NextGoal"
	box.LayoutOrder = 0
	box.Size = UDim2.new(1, 0, 0, 52)
	box.BackgroundColor3 = Ui.Colors.panel
	box.BackgroundTransparency = 0.25
	box.Visible = false
	box.Parent = column
	Ui.corner(box, 8)
	Ui.rim(box, Ui.Style.line, 1)

	local title = Ui.text(box, "", UDim2.new(1, -16, 0, 20), Ui.Colors.lamp, true, 18)
	title.Position = UDim2.fromOffset(8, 4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(8, 30)
	track.Size = UDim2.new(1, -16, 0, 16)
	track.BackgroundColor3 = Ui.Colors.row
	track.Parent = box
	Ui.corner(track, 8)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Ui.Colors.sell
	fill.Parent = track
	Ui.corner(fill, 8)
	local amount = Ui.text(track, "", UDim2.fromScale(1, 1), Ui.Colors.text, true, 13)
	amount.ZIndex = 2
	amount.TextXAlignment = Enum.TextXAlignment.Center
	amount.TextStrokeTransparency = 0.3

	local rookie = label("Rookie", 1, Ui.Colors.lamp, column)
	-- The new-hunter steal shield (StealShield, server/Services/HeistService): hours:minutes left.
	local shield = label("StealShield", 1, Color3.fromRGB(150, 200, 255), column)

	local function refresh()
		local name = player:GetAttribute("GoalName")
		local price = player:GetAttribute("GoalPrice")
		local money = moneyNow()
		box.Visible = typeof(name) == "string" and typeof(price) == "number" and money ~= nil
		if box.Visible and money and typeof(price) == "number" then
			local ready = money >= price
			title.Text = if ready then `Ready to buy: {name}!` else `Next goal: {name}`
			fill.Size = UDim2.fromScale(Goals.progress(money, price), 1)
			fill.BackgroundColor3 = if ready then Ui.Colors.buy else Ui.Colors.sell
			amount.Text = `{Format.money(math.min(money, price))} / {Format.money(price)}`
		end

		local left = player:GetAttribute("RookieSeconds")
		rookie.Visible = typeof(left) == "number" and left > 0
		if typeof(left) == "number" and left > 0 then
			local whole = math.floor(left)
			local times = 1 + Rookie.SellBonusPercent / 100
			local clock = string.format("%d:%02d", whole // 60, whole % 60)
			rookie.Text = `Rookie hour: x{times} sell money ({clock})`
		end

		local guard = player:GetAttribute("StealShield")
		shield.Visible = typeof(guard) == "number" and guard > 0 and player:GetAttribute("Tutorial") == nil
		if typeof(guard) == "number" and guard > 0 then
			local minutes = math.ceil(guard / 60)
			shield.Text = string.format("🛡 Steal shield %dh %02dm", minutes // 60, minutes % 60)
		end
	end
	player:GetAttributeChangedSignal("StealShield"):Connect(refresh)
	player:GetAttributeChangedSignal("GoalName"):Connect(refresh)
	player:GetAttributeChangedSignal("GoalPrice"):Connect(refresh)
	player:GetAttributeChangedSignal("RookieSeconds"):Connect(refresh)
	-- Money changes all the time; check it twice a second rather than hooking leaderstats,
	-- which may not exist yet.
	task.spawn(function()
		while box.Parent do
			refresh()
			task.wait(0.5)
		end
	end)
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

	-- Hud: the menu stack and, right of it, the Side stack, both hanging from just under the
	-- money. Hidden rows take no space, so whatever is showing stays packed together.
	local hud = Instance.new("Frame")
	hud.Name = "Hud"
	hud.Position = UDim2.fromOffset(16, MONEY_TOP + MONEY_HEIGHT + 10)
	hud.Size = UDim2.fromOffset(MENU_SIZE + 10 + HUD_WIDTH, 0)
	hud.AutomaticSize = Enum.AutomaticSize.Y
	hud.BackgroundTransparency = 1
	hud.Parent = canvas
	local column = Instance.new("Frame")
	column.Name = "Side"
	column.Position = UDim2.fromOffset(MENU_SIZE + 10, 0)
	column.Size = UDim2.fromOffset(HUD_WIDTH, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.BackgroundTransparency = 1
	column.Parent = hud
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = column

	-- Money: top-left, big. The gui leaves Roblox's top bar out, so y = 0 is just under it.
	local money = label("Money", 1, Color3.fromRGB(140, 255, 140), canvas)
	money.Position = UDim2.fromOffset(16, MONEY_TOP)
	money.Size = UDim2.fromOffset(0, MONEY_HEIGHT)
	money.AutomaticSize = Enum.AutomaticSize.X
	money.TextScaled = false
	money.TextSize = MONEY_HEIGHT
	money.TextStrokeTransparency = 0.2
	local limit = money:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit:Destroy()
	end
	buildGoal(column)
	local hearts = label("Hearts", 2, Color3.fromRGB(255, 90, 110), column)
	local carrying = label("Carrying", 3, Color3.new(1, 1, 1), column)

	-- Big enough to hit with a thumb, small enough to leave the view free on a phone.
	local function itemButton(name: string, order: number, color: Color3, text: string): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(ITEM_WIDTH, ITEM_HEIGHT)
		button.BackgroundColor3 = color
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.FredokaOne
		button.TextScaled = true
		button.AutoButtonColor = true
		button.Text = text
		button.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = Ui.radius(10)
		corner.Parent = button
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.PaddingTop = UDim.new(0, 7)
		padding.PaddingBottom = UDim.new(0, 7)
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
	-- LayoutOrder 5.1, 5.2, 5.3: under the charm.
	local bells: { TextButton } = {}
	for i, kind in Bells do
		table.insert(bells, itemButton(kind.id, 5 + i / 10, kind.color, kind.name))
	end
	-- A stack of little square picture buttons, always there: Backpack (G, InventoryController),
	-- Codex (C, CodexController), Missions (J, MissionController) and Settings
	-- (SettingsController). With a keyboard each shows its key in the corner, and the name
	-- pops up beside it while the mouse is over it.
	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.Size = UDim2.fromOffset(MENU_SIZE, 0)
	menu.AutomaticSize = Enum.AutomaticSize.Y
	menu.BackgroundTransparency = 1
	menu.ZIndex = 2 -- the hover names draw over the Side buttons next to it
	menu.Parent = hud
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, MENU_GAP)
	stack.Parent = menu
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
			tip.AnchorPoint = Vector2.new(0, 0.5)
			tip.Position = UDim2.new(1, 8, 0.5, 0)
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
		local zoneId = player:GetAttribute("Zone")
		local inZone = zoneId ~= nil
		local count = player:GetAttribute("Hearts")
		-- No hearts in a calm zone: nothing there can take one.
		local calm = typeof(zoneId) == "string" and Attacks.calmZone(zoneId)
		hearts.Text = if inZone and not calm and typeof(count) == "number"
			then string.rep("♥ ", count)
			else ""
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
