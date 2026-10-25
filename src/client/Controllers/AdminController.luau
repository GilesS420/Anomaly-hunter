--!strict
-- The admin panel: every admin command (server/Services/DevService.luau) as buttons and
-- dropdowns, so nobody has to remember the chat commands. Only admins see it: the server sets
-- an "Admin" attribute on them (see server/Admins.luau). Press F2 to open and close it
-- (there's no button on screen, Giles 2026-10-20).
--
-- Laid out to need little scrolling and few taps (Giles 2026-10-22, 2026-10-24): a "Works on"
-- dropdown at the top (Me, Everyone, or any player in the server), tabs down the left (Player,
-- Mansion, Items, Spawn, Events) and one short page per tab. Most things are one tap: quick
-- amounts, a button per wing and per size, and a button per Watcher event (the Awakening once
-- per monster set) with Stop next to them. Dropdowns only for long lists (items, monsters).
-- Events and "Reset my save" ignore "Works on".
--
-- Each button sends
--   ReplicatedStorage.Remotes.AdminCommand   client -> server: (command, argument?, targetUserId?)
-- (targetUserId 0 = everyone) and the server checks again that you're an admin before doing
-- anything. Results come back as the usual toasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local Watcher = require(ReplicatedStorage.Shared.Util.Watcher)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Sizes = require(ReplicatedStorage.Shared.Config.Sizes)
local Wings = require(ReplicatedStorage.Shared.Config.Wings)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Scale = require(script.Parent.Parent.Scale)
local Ui = require(script.Parent.Parent.Ui)

local AdminController = {}

type Option = { label: string, value: string }

local player = Players.LocalPlayer
local Everyone = "everyone"
local RowHeight = 34
local Gap = 8
local SideWidth = 110
local PopupMaxHeight = 240
local TimelineLength = 5 -- events shown on the Events tab's timeline

local remote: RemoteEvent
local window: Ui.Window
local target = "me" -- "me", Everyone, or a UserId as text

local function send(command: string, argument: string?)
	local targetId: number? = nil
	if target == Everyone then
		targetId = 0
	elseif target ~= "me" then
		targetId = tonumber(target)
	end
	remote:FireServer(command, argument, targetId)
end

-- ------------------------------------------------------------------ building blocks

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

-- A line of controls with a short name in front. It wraps onto a second line when narrow.
local function row(page: Frame, name: string): Frame
	local line = Instance.new("Frame")
	line.LayoutOrder = nextOrder()
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, 0, 0, RowHeight)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Wraps = true
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = line
	local label = Ui.text(line, name, UDim2.fromOffset(84, RowHeight), Ui.Colors.muted, false, 16)
	label.LayoutOrder = 0
	return line
end

-- A wrapping block of buttons with no name in front (the Events tab's event buttons).
local function grid(page: Frame): Frame
	local block = Instance.new("Frame")
	block.LayoutOrder = nextOrder()
	block.BackgroundTransparency = 1
	block.Size = UDim2.new(1, 0, 0, RowHeight)
	block.AutomaticSize = Enum.AutomaticSize.Y
	block.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Wraps = true
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = block
	return block
end

local function button(line: Frame, text: string, color: Color3, width: number, action: () -> ()): TextButton
	local made = Ui.button(line, text, color, UDim2.fromOffset(width, RowHeight))
	made.LayoutOrder = nextOrder()
	made.Activated:Connect(action)
	return made
end

-- A box to type a number or word into; returns a function that reads it (nil when empty).
-- Pressing Enter in it runs `onEnter` (the row's main button), if given.
local function input(
	line: Frame,
	placeholder: string,
	start: string?,
	width: number,
	onEnter: ((text: string?) -> ())?
): () -> string?
	local box = Instance.new("TextBox")
	box.LayoutOrder = nextOrder()
	box.Size = UDim2.fromOffset(width, RowHeight)
	box.BackgroundColor3 = Ui.Colors.row
	box.TextColor3 = Ui.Colors.text
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Ui.Colors.muted
	box.Text = start or ""
	box.Font = Enum.Font.FredokaOne
	box.TextScaled = true
	box.ClearTextOnFocus = false
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 16
	limit.Parent = box
	Ui.corner(box, 8)
	Ui.rim(box, Ui.Colors.rim, 1)
	box.Parent = line
	local function read(): string?
		local text = string.match(box.Text, "^%s*(.-)%s*$")
		return if text and text ~= "" then text else nil
	end
	if onEnter then
		box.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				onEnter(read())
			end
		end)
	end
	return read
end

-- The one list that drops down under whichever dropdown was tapped, and a see-through cover
-- behind it: tapping anywhere else closes it.
local popup: ScrollingFrame
local cover: TextButton

local function closePopup()
	popup.Visible = false
	cover.Visible = false
end

local function buildPopup(gui: Frame)
	cover = Instance.new("TextButton")
	cover.Text = ""
	cover.BackgroundTransparency = 1
	cover.Size = UDim2.fromScale(1, 1)
	cover.ZIndex = 40
	cover.Visible = false
	cover.Parent = gui
	cover.Activated:Connect(closePopup)

	popup = Instance.new("ScrollingFrame")
	popup.BackgroundColor3 = Ui.Colors.panel
	popup.BorderSizePixel = 0
	popup.ScrollBarThickness = 5
	popup.ScrollBarImageColor3 = Ui.Colors.rim
	popup.AutomaticCanvasSize = Enum.AutomaticSize.Y
	popup.CanvasSize = UDim2.new()
	popup.ZIndex = 41
	popup.Visible = false
	popup.Parent = gui
	Ui.corner(popup, 8)
	Ui.rim(popup, Ui.Colors.rim, 2)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = popup
end

-- A dropdown: shows the chosen option; tapping it lists `options()` (worked out each time it
-- opens, so a list of players stays current). Returns a function that reads the chosen value,
-- and one that picks a value.
local function dropdown(
	line: Frame,
	width: number,
	options: () -> { Option },
	start: string?,
	onPick: ((value: string) -> ())?
): (() -> string?, (value: string) -> ())
	local chosen: string? = start
	local made = Ui.button(line, "", Ui.Colors.off, UDim2.fromOffset(width, RowHeight))
	made.LayoutOrder = nextOrder()
	made.TextXAlignment = Enum.TextXAlignment.Left

	local function labelFor(value: string?): string
		for _, option in options() do
			if option.value == value then
				return option.label
			end
		end
		return "Pick..."
	end
	local function show()
		made.Text = `{labelFor(chosen)}  ▾`
	end
	local function pick(value: string)
		chosen = value
		show()
		if onPick then
			onPick(value)
		end
	end
	show()

	made.Activated:Connect(function()
		if popup.Visible then
			closePopup()
			return
		end
		for _, child in popup:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local list = options()
		for i, option in list do
			local entry = Instance.new("TextButton")
			entry.LayoutOrder = i
			entry.Size = UDim2.new(1, -6, 0, 30)
			entry.BackgroundColor3 = if option.value == chosen then Ui.Colors.equip else Ui.Colors.panel
			entry.BorderSizePixel = 0
			entry.Font = Enum.Font.FredokaOne
			entry.TextSize = 16
			entry.TextColor3 = Ui.Colors.text
			entry.TextXAlignment = Enum.TextXAlignment.Left
			entry.TextTruncate = Enum.TextTruncate.AtEnd
			entry.Text = `  {option.label}`
			entry.ZIndex = 42
			entry.Parent = popup
			entry.Activated:Connect(function()
				closePopup()
				pick(option.value)
			end)
		end
		-- From screen pixels to offsets in the window's Scale canvas.
		local at = Scale.toCanvas(popup.Parent :: GuiObject, made.AbsolutePosition)
		local height = math.min(#list * 30 + 4, PopupMaxHeight)
		popup.Size = UDim2.fromOffset(math.max(width, 180), height)
		popup.Position = UDim2.fromOffset(at.X, at.Y + made.AbsoluteSize.Y / Scale.factor() + 2)
		popup.CanvasPosition = Vector2.zero
		cover.Visible = true
		popup.Visible = true
	end)

	return function()
		return chosen
	end, pick
end

-- ------------------------------------------------------------------ the lists

local function playerOptions(): { Option }
	local list: { Option } = { { label = "Me", value = "me" }, { label = "Everyone", value = Everyone } }
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(list, { label = other.DisplayName, value = tostring(other.UserId) })
		end
	end
	return list
end

local function wingOptions(): { Option }
	local list: { Option } = {}
	for index, wing in Wings.List do
		table.insert(list, { label = wing.id, value = tostring(index) })
	end
	return list
end

local itemList: { Option } = {}
for _, shop in { Shop.Workshop, Shop.Bakery } do
	for _, item in shop do
		table.insert(itemList, { label = item.name, value = item.id })
	end
end

-- Every monster, zone by zone, cheapest first; the zone in front so the list reads in groups.
local monsterList: { Option } = {}
for _, zone in Zones.List do
	local ids: { string } = {}
	for id, monster in Monsters do
		if monster.zone == zone.index then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Monsters[a].baseValue < Monsters[b].baseValue
	end)
	for _, id in ids do
		table.insert(monsterList, { label = `{zone.name}: {id}`, value = id })
	end
end

local sizeList: { Option } = {}
for _, size in Sizes do
	table.insert(sizeList, { label = size.id, value = size.id })
end

-- One button per launch event; The Watcher Awakens once per monster set (its argument says
-- which: "WatcherAwakens Eldritch").
local eventButtons: { Option } = {}
for _, event in Events.List do
	if event.launch then
		local icon = if event.icon then `{event.icon} ` else ""
		if event.monsterSets then
			for _, set in event.monsterSets do
				table.insert(
					eventButtons,
					{ label = `{icon}Awakens: {set.name}`, value = `{event.id} {set.id}` }
				)
			end
		else
			table.insert(eventButtons, { label = `{icon}{event.name}`, value = event.id })
		end
	end
end

local function fixed(list: { Option }): () -> { Option }
	return function()
		return list
	end
end

-- ------------------------------------------------------------------ the panel

local function build()
	window = Ui.window("AdminPanel", "Admin panel")
	local panel = window.panel
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(820, 560)
	end
	buildPopup(window.canvas)
	window.onClose = closePopup

	-- "Works on" across the top.
	local top = 68
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.Position = UDim2.fromOffset(0, top)
	bar.Size = UDim2.new(1, 0, 0, RowHeight)
	bar.Parent = panel
	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	barLayout.Padding = UDim.new(0, 6)
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Parent = bar
	local barLabel = Ui.text(bar, "Works on", UDim2.fromOffset(84, RowHeight), Ui.Colors.lamp, true, 18)
	barLabel.LayoutOrder = 0
	local function describe()
		local name = "you"
		if target == Everyone then
			name = "everyone in the server"
		elseif target ~= "me" then
			local other = Players:GetPlayerByUserId(tonumber(target) or 0)
			name = if other then other.DisplayName else "you"
		end
		window.status.Text = `Buttons work on {name}. Events and Reset my save don't change.`
	end
	local _, pickTarget = dropdown(bar, 200, playerOptions, "me", function(value)
		target = value
		describe()
	end)
	describe()
	Players.PlayerRemoving:Connect(function(other)
		if target == tostring(other.UserId) then
			pickTarget("me") -- they left: back to yourself
		end
	end)

	-- Tabs down the left, pages on the right (in the window's list).
	local below = top + RowHeight + Gap
	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.Position = UDim2.fromOffset(0, below)
	side.Size = UDim2.new(0, SideWidth, 1, -below - 62)
	side.Parent = panel
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 4)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = side

	local list = window.list
	list.Position = UDim2.fromOffset(SideWidth + Gap * 2, below)
	list.Size = UDim2.new(1, -(SideWidth + Gap * 2), 1, -below - 62)

	local pages: { [string]: Frame } = {}
	local tabs: { [string]: TextButton } = {}
	local function openTab(name: string)
		closePopup()
		for other, page in pages do
			page.Visible = other == name
			Ui.paint(tabs[other], if other == name then Ui.Colors.lamp else Ui.Colors.off)
		end
		list.CanvasPosition = Vector2.zero
	end
	local function page(name: string): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, -8, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Visible = false
		frame.Parent = list
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, Gap)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = frame
		pages[name] = frame
		local tab = Ui.button(side, name, Ui.Colors.off, UDim2.new(1, 0, 0, RowHeight))
		tab.LayoutOrder = nextOrder()
		tab.Activated:Connect(function()
			openTab(name)
		end)
		tabs[name] = tab
		return frame
	end

	-- Player
	local you = page("Player")
	local moneyRow = row(you, "Money")
	local amount = input(moneyRow, "5m, 1b, -1k", "1m", 90, function(text)
		send("/money", text)
	end)
	button(moneyRow, "Add", Ui.Colors.buy, 60, function()
		send("/money", amount())
	end)
	for _, quick in { "1m", "100m", "10b" } do
		button(moneyRow, `+{string.upper(quick)}`, Ui.Colors.buy, 64, function()
			send("/money", quick)
		end)
	end
	local wingRow = row(you, "Wings")
	for _, option in wingOptions() do
		button(wingRow, option.value, Ui.Colors.equip, 40, function()
			send("/wings", option.value)
		end)
	end
	local tutorialRow = row(you, "Tutorial")
	button(tutorialRow, "Skip", Ui.Colors.off, 80, function()
		send("/tutorial", "skip")
	end)
	button(tutorialRow, "Restart", Ui.Colors.off, 80, function()
		send("/tutorial", "restart")
	end)
	local fightRow = row(you, "Monsters")
	button(fightRow, "Calm on/off", Ui.Colors.off, 110, function()
		send("/calm")
	end)
	button(fightRow, "Attack", Ui.Colors.confirm, 80, function()
		send("/attack")
	end)
	local resetRow = row(you, "Your save")
	-- Wipes only your own save and kicks you; rejoin to play as a brand-new player.
	local reset = Ui.button(resetRow, "Reset my save", Ui.Colors.confirm, UDim2.fromOffset(130, RowHeight))
	reset.LayoutOrder = nextOrder()
	Ui.confirmButton(reset, "Wipe it all?", function()
		remote:FireServer("/reset", "confirm") -- always your own save, whoever is picked
	end)

	-- Mansion
	local mansion = page("Mansion")
	local growRow = row(mansion, "Grow spurts")
	for _, spurts in { "1", "5", "25" } do
		button(growRow, spurts, Ui.Colors.equip, 50, function()
			send("/grow", spurts)
		end)
	end
	local spurtsBox = input(growRow, "#", nil, 50, function(text)
		send("/grow", text)
	end)
	button(growRow, "Go", Ui.Colors.equip, 50, function()
		send("/grow", spurtsBox())
	end)
	local skipRow = row(mansion, "Skip hours")
	for _, hours in { "1", "12", "48" } do
		button(skipRow, `{hours}h`, Ui.Colors.equip, 50, function()
			send("/skip", hours)
		end)
	end
	local hoursBox = input(skipRow, "#", nil, 50, function(text)
		send("/skip", text)
	end)
	button(skipRow, "Go", Ui.Colors.equip, 50, function()
		send("/skip", hoursBox())
	end)
	local allRow = row(mansion, "All monsters")
	button(allRow, "Haunt all", Ui.Colors.equip, 100, function()
		send("/haunt")
	end)
	button(allRow, "Refill goes", Ui.Colors.equip, 110, function()
		send("/charges") -- Growth Chamber
	end)
	button(allRow, "Chamber done", Ui.Colors.equip, 120, function()
		send("/chamber") -- the Growth Chamber's 20 minutes are up
	end)
	local clear = Ui.button(allRow, "Clear all", Ui.Colors.confirm, UDim2.fromOffset(100, RowHeight))
	clear.LayoutOrder = nextOrder()
	Ui.confirmButton(clear, "Sure?", function()
		send("/clearmonsters")
	end)

	-- Items
	local items = page("Items")
	local itemRow = row(items, "Item")
	local item = dropdown(itemRow, 230, fixed(itemList), itemList[1] and itemList[1].value)
	local countRow = row(items, "Give")
	local function give(count: string?)
		local id = item()
		if id then
			send("/give", `{id} {count or "1"}`)
		end
	end
	for _, count in { "1", "5", "25" } do
		button(countRow, `x{count}`, Ui.Colors.buy, 54, function()
			give(count)
		end)
	end
	local countBox = input(countRow, "#", nil, 50, give)
	button(countRow, "Go", Ui.Colors.buy, 50, function()
		give(countBox())
	end)

	-- Spawn (in the zone the player is standing in)
	local spawn = page("Spawn")
	local monsterRow = row(spawn, "Monster")
	local monster = dropdown(monsterRow, 230, fixed(monsterList), monsterList[1] and monsterList[1].value)
	-- One tap spawns the picked monster at that size, in the zone you're standing in.
	local sizeRow = row(spawn, "Spawn as")
	for _, option in sizeList do
		button(sizeRow, option.label, Ui.Colors.sell, 78, function()
			local id = monster()
			if id then
				send("/spawn", `{id} {option.value}`)
			end
		end)
	end
	local zoneRow = row(spawn, "Whole zone")
	button(zoneRow, "Every monster of my zone", Ui.Colors.sell, 210, function()
		send("/spawn", "all Normal")
	end)

	-- Events (Watcher events reach everyone). Tapping one starts it now, ending one that's
	-- playing.
	local server = page("Events")
	local live = Ui.text(server, "", UDim2.new(1, 0, 0, 24), Ui.Colors.lamp, true, 18)
	live.LayoutOrder = nextOrder()
	live.TextXAlignment = Enum.TextXAlignment.Left
	local controlRow = row(server, "Now")
	button(controlRow, "Stop event", Ui.Colors.confirm, 110, function()
		send("/stopevent")
	end)
	button(controlRow, "Next one now", Ui.Colors.sell, 120, function()
		send("/summon")
	end)
	button(controlRow, "Golden Ghost", Ui.Colors.sell, 120, function()
		send("/ghost")
	end)
	local events = grid(server)
	for _, option in eventButtons do
		button(events, option.label, Ui.Colors.off, 184, function()
			send("/event", option.value)
		end)
	end

	-- The global schedule (the same in every server; a started event doesn't change it).
	local timeline = Ui.text(server, "", UDim2.new(1, 0, 0, 0), Ui.Colors.text, false, 16)
	timeline.LayoutOrder = nextOrder()
	timeline.AutomaticSize = Enum.AutomaticSize.Y
	timeline.TextScaled = false
	timeline.TextSize = 16
	timeline.TextWrapped = true
	timeline.TextTruncate = Enum.TextTruncate.None
	timeline.TextYAlignment = Enum.TextYAlignment.Top
	task.spawn(function()
		while timeline.Parent do
			if window.isOpen() and server.Visible then
				local now = workspace:GetServerTimeNow()
				local playing = Events.find(workspace:GetAttribute("WatcherEvent") :: string?)
				local ends = workspace:GetAttribute("WatcherEventEnd")
				live.Text = if playing and type(ends) == "number"
					then `Playing: {playing.icon or ""} {playing.name} ({Watcher.clock(
						math.max(ends - now, 0)
					)} left)`
					else "No event playing"
				local lines = { "Coming up (every server):" }
				for _, slot in Watcher.upcoming(now, TimelineLength) do
					local when = if now >= slot.startAt
						then `live, {Watcher.clock(slot.endAt - now)} left`
						else `in {Watcher.clock(slot.startAt - now)}`
					table.insert(lines, `{slot.icon} {slot.name}  ({when})`)
				end
				timeline.Text = table.concat(lines, "\n")
			end
			task.wait(1)
		end
	end)

	openTab("Player")
end

local function toggle()
	if window.isOpen() then
		window.close()
	else
		window.open()
	end
end

function AdminController.start()
	while not player:GetAttribute("Admin") do
		player:GetAttributeChangedSignal("Admin"):Wait()
	end
	remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminCommand") :: RemoteEvent
	build()
	UserInputService.InputBegan:Connect(function(inputObject, processed)
		if not processed and inputObject.KeyCode == Enum.KeyCode.F2 then
			toggle()
		end
	end)
end

return AdminController
