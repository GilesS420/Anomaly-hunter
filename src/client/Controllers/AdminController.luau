--!strict
-- The admin panel: every admin command (server/Services/DevService.luau) as buttons and
-- dropdowns, so nobody has to remember the chat commands. Only admins see it: the server sets
-- an "Admin" attribute on them (see server/Admins.luau). Press F2 to open and close it
-- (there's no button on screen, Giles 2026-10-20).
--
-- Laid out like Giles's sketch (2026-10-30): across the top the "who" dropdown (Me, All
-- players, or any player in the server), the title and a "Make announcement" button; down the
-- left one tab per kind of thing, each holding the controls that belong to it:
--   Player    money add/remove, monster attacks on/off, daily missions (reset, change),
--             tutorial, and the red RESET SAVE / RESET PLAYER (respawn) buttons
--   Mansion   wings, growth spurts, skip hours, haunt, Growth Chamber
--   Items     Workshop items and Bakery cakes for free
--   Monsters  give a brand-new monster, add effects to one they have (both pick effects in a
--             big pop-up of tick boxes), remove all their monsters
--   Zones     spawn monsters in the zone they're in, make one attack now
--   Events    start or stop Watcher events, the Golden Ghost, the coming schedule
--   Shops     admin restocks (this server only)
-- Events, Shops and announcements reach the whole server, whoever is picked. Anything that
-- can't be undone (reset save, remove all monsters) asks first in a pop-up.
--
-- Each button sends
--   ReplicatedStorage.Remotes.AdminCommand   client -> server: (command, argument?, targetUserId?)
-- (targetUserId 0 = everyone) and the server checks again that you're an admin before doing
-- anything. Results come back as the usual toasts. The Monsters tab also asks
--   ReplicatedStorage.Remotes.AdminMonsters  (targetUserId?) -> { {uid, label, effects} }
-- for the picked player's monsters (admins only; anyone else gets an empty list).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Effects = require(ReplicatedStorage.Shared.Config.Effects)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local MissionConfig = require(ReplicatedStorage.Shared.Config.Missions)
local Restock = require(ReplicatedStorage.Shared.Util.Restock)
local Watcher = require(ReplicatedStorage.Shared.Util.Watcher)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Sizes = require(ReplicatedStorage.Shared.Config.Sizes)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local Wings = require(ReplicatedStorage.Shared.Config.Wings)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Scale = require(script.Parent.Parent.Scale)
local Ui = require(script.Parent.Parent.Ui)

local AdminController = {}

type Option = { label: string, value: string }
type TheirMonster = { uid: string, label: string, effects: { string } }

local player = Players.LocalPlayer
local Everyone = "everyone"
local RowHeight = 34
local Gap = 8
local SideWidth = 160
local HeaderHeight = 44
local PopupMaxHeight = 240
local TimelineLength = 5 -- events shown on the Events tab's timeline
local MaxAnnouncement = 150

local remote: RemoteEvent
local monstersRemote: RemoteFunction
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

-- Who the buttons work on, in words ("you", "Biggie", "all players").
local function targetName(): string
	if target == Everyone then
		return "all players"
	elseif target ~= "me" then
		local other = Players:GetPlayerByUserId(tonumber(target) or 0)
		return if other then other.DisplayName else "you"
	end
	return "you"
end

-- ------------------------------------------------------------------ building blocks

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

-- A line of controls with a short name in front. It wraps onto a second line when narrow.
local function row(page: Instance, name: string): Frame
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
	local label = Ui.text(line, name, UDim2.fromOffset(100, RowHeight), Ui.Colors.text, true, 18)
	label.LayoutOrder = 0
	return line
end

-- A wrapping block of buttons with no name in front (the Events tab's event buttons).
local function grid(page: Instance): Frame
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

-- The thin line between the sections of a page, like the sketch.
local function divider(page: Instance)
	local line = Instance.new("Frame")
	line.LayoutOrder = nextOrder()
	line.BorderSizePixel = 0
	line.BackgroundColor3 = Ui.Colors.rim
	line.BackgroundTransparency = 0.4
	line.Size = UDim2.new(1, -8, 0, 2)
	line.Parent = page
end

-- A section title in lantern orange.
local function heading(page: Instance, text: string): TextLabel
	local label = Ui.text(page, text, UDim2.new(1, 0, 0, 24), Ui.Colors.lamp, true, 20)
	label.LayoutOrder = nextOrder()
	return label
end

-- A line of grey help text that wraps.
local function note(page: Instance, text: string): TextLabel
	local label = Ui.text(page, text, UDim2.new(1, -8, 0, 0), Ui.Colors.muted, false, 15)
	label.LayoutOrder = nextOrder()
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextScaled = false
	label.TextSize = 15
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
	return label
end

local function button(
	line: Instance,
	text: string,
	color: Color3,
	width: number,
	action: () -> ()
): TextButton
	local made = Ui.button(line, text, color, UDim2.fromOffset(width, RowHeight))
	made.LayoutOrder = nextOrder()
	made.Activated:Connect(action)
	return made
end

-- A box to type a number or word into; returns a function that reads it (nil when empty).
-- Pressing Enter in it runs `onEnter` (the row's main button), if given.
local function input(
	line: Instance,
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
-- behind it: tapping anywhere else closes it. Above the pop-ups, so dropdowns work in them.
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
	line: Instance,
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

-- A pop-up in the middle of the panel (the effect picker, announcements, missions, "are you
-- sure?"). A dark shade behind it blocks the panel; tapping the shade or X cancels.
type Modal = {
	body: ScrollingFrame,
	footer: Frame,
	title: TextLabel,
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
}

local modals: { Modal } = {}

local function modal(canvas: Frame, titleText: string, maxSize: Vector2): Modal
	local shade = Instance.new("TextButton")
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 30
	shade.Visible = false
	shade.Parent = canvas

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.9, 0.85)
	frame.BackgroundColor3 = Ui.Colors.panel
	frame.Active = true
	frame.ZIndex = 31
	frame.Visible = false
	frame.Parent = canvas
	Ui.corner(frame, 14)
	Ui.rim(frame, Ui.Colors.lamp, 2)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize
	limit.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = frame
	-- Everything inside draws above the pop-up itself: the window's ScreenGui stacks by ZIndex
	-- across the whole gui, so at the default 1 the contents hid behind the frame (Giles
	-- 2026-10-31: the effect picker was blank).
	frame.DescendantAdded:Connect(function(child)
		if child:IsA("GuiObject") then
			child.ZIndex = 32
		end
	end)

	local title = Ui.text(frame, titleText, UDim2.new(1, -54, 0, 32), Ui.Colors.lamp, true, 28)
	title.Font = Ui.TitleFont
	local close = Ui.button(frame, "X", Ui.Colors.off, UDim2.fromOffset(40, 40))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, -4)

	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(0, 42)
	body.Size = UDim2.new(1, 0, 1, -42 - 50)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = Ui.Colors.rim
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Gap)
	layout.Parent = body

	local footer = Instance.new("Frame")
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, 40)
	footer.BackgroundTransparency = 1
	footer.Parent = frame
	local footerLayout = Instance.new("UIListLayout")
	footerLayout.FillDirection = Enum.FillDirection.Horizontal
	footerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	footerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	footerLayout.Padding = UDim.new(0, 8)
	footerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	footerLayout.Parent = footer

	local made: Modal
	made = {
		body = body,
		footer = footer,
		title = title,
		open = function()
			closePopup()
			for _, other in modals do
				if other ~= made then
					other.close()
				end
			end
			body.CanvasPosition = Vector2.zero
			shade.Visible = true
			frame.Visible = true
		end,
		close = function()
			closePopup()
			shade.Visible = false
			frame.Visible = false
		end,
		isOpen = function()
			return frame.Visible
		end,
	}
	shade.Activated:Connect(made.close)
	close.Activated:Connect(made.close)
	table.insert(modals, made)
	return made
end

local function clearBody(frame: ScrollingFrame)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- ------------------------------------------------------------------ the lists

local function playerOptions(): { Option }
	local list: { Option } = { { label = "Me", value = "me" }, { label = "All players", value = Everyone } }
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(list, { label = other.DisplayName, value = tostring(other.UserId) })
		end
	end
	return list
end

local itemList: { Option } = {}
for _, shop in { { name = "Workshop", items = Shop.Workshop }, { name = "Bakery", items = Shop.Bakery } } do
	for _, item in shop.items do
		table.insert(itemList, { label = `{shop.name}: {item.name}`, value = item.id })
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

-- What an admin restock can put in stock: cakes first, event treats marked.
local restockList: { Option } = {}
local restockNames: { [string]: string } = {}
for _, item in Restock.items() do
	local shop = if Restock.isCake(item.id) then "Cake" else "Workshop"
	local event = if item.event then " (event)" else ""
	table.insert(restockList, { label = `{shop}: {item.name}{event}`, value = item.id })
	restockNames[item.id] = item.name
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

-- Variants for a given monster, plainest first.
local variantList: { Option } = { { label = "No variant", value = "None" } }
for i = #Variants, 1, -1 do
	local variant = Variants[i]
	table.insert(variantList, { label = `{variant.id} (x{variant.multiplier})`, value = variant.id })
end

-- The effect picker's groups: effects by where they come from, then combos (giving a combo
-- gives both its effects).
local sourceOrder = { "Roam", "Food", "Catch", "Survive", "Event", "Critter" }
local sourceTitles: { [string]: string } = {
	Roam = "Roaming effects",
	Food = "Cake effects",
	Catch = "Catch effects",
	Survive = "Survive effects",
	Event = "Event effects",
	Critter = `Critter effects (only on monsters worth up to {Format.money(Effects.CritterMaxValue)})`,
}
type EffectGroup = { title: string, ids: { string } }
local effectGroups: { EffectGroup } = {}
local effectNames: { [string]: string } = {}
do
	local bySource: { [string]: { string } } = {}
	for id, effect in Effects.List do
		local source = tostring(effect.source)
		if not table.find(sourceOrder, source) then
			table.insert(sourceOrder, source)
		end
		bySource[source] = bySource[source] or {}
		table.insert(bySource[source], id)
		effectNames[id] = Format.name(id)
	end
	for _, source in sourceOrder do
		local ids = bySource[source]
		if ids then
			table.sort(ids)
			table.insert(effectGroups, { title = sourceTitles[source] or `{source} effects`, ids = ids })
		end
	end
	local combos: { string } = {}
	for id in Effects.Combos do
		table.insert(combos, id)
		effectNames[id] = `{Format.name(id)} combo`
	end
	table.sort(combos)
	table.insert(effectGroups, { title = "Combos (gives both of its effects)", ids = combos })
end

local function effectLabel(id: string): string
	local combo = Effects.Combos[id]
	if combo then
		return `{Format.name(id)} x{combo.multiplier} ({Format.name(combo.recipe[1])} + {Format.name(
			combo.recipe[2]
		)})`
	end
	local effect = Effects.List[id]
	return if effect then `{Format.name(id)} x{effect.multiplier}` else Format.name(id)
end

-- "Effects: Gilded, Count combo" or "No effects".
local function effectSummary(ids: { string }): string
	local names: { string } = {}
	for _, id in ids do
		table.insert(names, effectNames[id] or id)
	end
	return if #names > 0 then `Effects: {table.concat(names, ", ")}` else "No effects picked."
end

-- Today's missions to pick from, tier by tier ({n} filled in; zones and money depend on the
-- player, so they stay general).
local function missionOptions(tierId: string): { Option }
	local list: { Option } = {}
	for _, mission in MissionConfig.Pool do
		if mission.tier == tierId then
			local text = string.gsub(mission.text, "{n}", tostring(mission.count or 1))
			text = string.gsub(text, "{zone}", "a zone")
			text = string.gsub(text, "{money}", "some money")
			table.insert(list, { label = text, value = mission.id })
		end
	end
	return list
end

local function fixed(list: { Option }): () -> { Option }
	return function()
		return list
	end
end

-- ------------------------------------------------------------------ the pop-ups

local confirmModal: Modal
local confirmText: TextLabel
local confirmYes: TextButton
local confirmAction: (() -> ())? = nil

-- "Are you sure?" for anything that can't be undone.
local function askFirst(question: string, yesText: string, action: () -> ())
	confirmText.Text = question
	confirmYes.Text = yesText
	confirmAction = action
	confirmModal.open()
end

local function buildConfirm(canvas: Frame)
	confirmModal = modal(canvas, "Are you sure?", Vector2.new(460, 260))
	confirmText = note(confirmModal.body, "")
	confirmText.TextColor3 = Ui.Colors.text
	confirmText.TextSize = 18
	button(confirmModal.footer, "Cancel", Ui.Colors.off, 100, confirmModal.close)
	confirmYes = button(confirmModal.footer, "Yes", Ui.Colors.confirm, 180, function()
		local action = confirmAction
		confirmAction = nil
		confirmModal.close()
		if action then
			action()
		end
	end)
end

-- The big effect picker: a tick box per effect and combo. `owned` effects (a monster they
-- already have) show ticked and can't be changed. Done hands the ticked ones to `onDone`.
local pickerModal: Modal
local pickerCount: TextLabel
local pickerDone: ((ids: { string }) -> ())? = nil
local pickerWorking: { string } = {}

local function openPicker(
	titleText: string,
	selected: { string },
	owned: { string },
	onDone: (ids: { string }) -> ()
)
	pickerModal.title.Text = titleText
	pickerDone = onDone
	pickerWorking = table.clone(selected)
	local body = pickerModal.body
	clearBody(body)

	local function has(id: string): boolean
		local combo = Effects.Combos[id]
		if combo then
			return table.find(owned, combo.recipe[1]) ~= nil and table.find(owned, combo.recipe[2]) ~= nil
		end
		return table.find(owned, id) ~= nil
	end
	local function showCount()
		pickerCount.Text = `{#pickerWorking} picked`
	end

	for _, group in effectGroups do
		heading(body, group.title)
		local block = Instance.new("Frame")
		block.LayoutOrder = nextOrder()
		block.BackgroundTransparency = 1
		block.Size = UDim2.new(1, -8, 0, 0)
		block.AutomaticSize = Enum.AutomaticSize.Y
		block.Parent = body
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(1 / 3, -6, 0, RowHeight)
		layout.CellPadding = UDim2.fromOffset(6, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = block
		for i, id in group.ids do
			local box = Ui.button(block, "", Ui.Colors.off, UDim2.fromOffset(100, RowHeight))
			box.LayoutOrder = i
			box.TextXAlignment = Enum.TextXAlignment.Left
			local owns = has(id)
			local function paint()
				local ticked = table.find(pickerWorking, id) ~= nil
				if owns then
					box.Text = `✔ {effectLabel(id)} (has it)`
					Ui.paint(box, Ui.Colors.off)
					box.TextTransparency = 0.4
				else
					box.Text = `{if ticked then "☑" else "☐"} {effectLabel(id)}`
					Ui.paint(box, if ticked then Ui.Colors.buy else Ui.Colors.off)
				end
			end
			paint()
			box.Activated:Connect(function()
				if owns then
					return
				end
				local at = table.find(pickerWorking, id)
				if at then
					table.remove(pickerWorking, at)
				else
					table.insert(pickerWorking, id)
				end
				paint()
				showCount()
			end)
		end
	end
	showCount()
	pickerModal.open()
end

local function buildPicker(canvas: Frame)
	pickerModal = modal(canvas, "Pick effects", Vector2.new(820, 560))
	pickerCount =
		Ui.text(pickerModal.footer, "", UDim2.fromOffset(140, RowHeight), Ui.Colors.muted, false, 18)
	pickerCount.LayoutOrder = nextOrder()
	button(pickerModal.footer, "Untick all", Ui.Colors.off, 110, function()
		-- The "has it" ones stay as they are.
		pickerWorking = {}
		for _, child in pickerModal.body:GetDescendants() do
			if child:IsA("TextButton") and string.sub(child.Text, 1, #"☑") == "☑" then
				child.Text = "☐" .. string.sub(child.Text, #"☑" + 1)
				Ui.paint(child, Ui.Colors.off)
			end
		end
		pickerCount.Text = "0 picked"
	end)
	button(pickerModal.footer, "Cancel", Ui.Colors.off, 90, pickerModal.close)
	button(pickerModal.footer, "Done", Ui.Colors.buy, 100, function()
		local done = pickerDone
		pickerModal.close()
		if done then
			done(table.clone(pickerWorking))
		end
	end)
end

-- ------------------------------------------------------------------ the panel

local function build()
	window = Ui.window("AdminPanel", "ADMIN PANEL")
	local panel = window.panel
	local canvas = window.canvas
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(900, 600)
	end
	buildPopup(canvas)
	buildConfirm(canvas)
	buildPicker(canvas)
	window.onClose = function()
		closePopup()
		for _, other in modals do
			other.close()
		end
	end
	local right = SideWidth + Gap * 2 -- where the pages start

	-- Top left: who the buttons work on.
	local who = Instance.new("Frame")
	who.BackgroundTransparency = 1
	who.Position = UDim2.fromOffset(0, 0)
	who.Size = UDim2.fromOffset(SideWidth, HeaderHeight)
	who.Parent = panel
	local whoLayout = Instance.new("UIListLayout")
	whoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	whoLayout.Parent = who
	local onTargetChanged: { () -> () } = {}
	local function describe()
		window.status.Text =
			`Working on: {targetName()}. Events, Shops and announcements reach the whole server.`
	end
	local _, pickTarget = dropdown(who, SideWidth, playerOptions, "me", function(value)
		target = value
		describe()
		for _, changed in onTargetChanged do
			task.spawn(changed)
		end
	end)
	Players.PlayerRemoving:Connect(function(other)
		if target == tostring(other.UserId) then
			pickTarget("me") -- they left: back to yourself
		end
	end)

	-- The title in the middle, "Make announcement" top right (next to X).
	window.title.Position = UDim2.fromOffset(right, 4)
	window.title.Size = UDim2.new(1, -(right + 54 + 220), 0, 34)
	window.title.TextXAlignment = Enum.TextXAlignment.Center
	local announceButton =
		Ui.button(panel, "📢 Make announcement", Ui.Colors.sell, UDim2.fromOffset(210, 40))
	announceButton.AnchorPoint = Vector2.new(1, 0)
	announceButton.Position = UDim2.new(1, -54, 0, -2)
	window.status.Position = UDim2.fromOffset(right, HeaderHeight + 4)
	window.status.Size = UDim2.new(1, -right, 0, 20)
	describe()

	-- The lines of the sketch: under the header and between the tabs and the pages.
	local below = HeaderHeight + 30
	local across = Instance.new("Frame")
	across.BorderSizePixel = 0
	across.BackgroundColor3 = Ui.Colors.rim
	across.Position = UDim2.fromOffset(0, HeaderHeight + 26)
	across.Size = UDim2.new(1, 0, 0, 2)
	across.Parent = panel
	local down = Instance.new("Frame")
	down.BorderSizePixel = 0
	down.BackgroundColor3 = Ui.Colors.rim
	down.Position = UDim2.fromOffset(SideWidth + Gap - 1, 0)
	down.Size = UDim2.new(0, 2, 1, 0)
	down.Parent = panel

	-- Tabs down the left, pages on the right (in the window's list).
	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.Position = UDim2.fromOffset(0, below + Gap)
	side.Size = UDim2.new(0, SideWidth, 1, -below - Gap)
	side.Parent = panel
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 6)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = side

	local list = window.list
	list.Position = UDim2.fromOffset(right, below + Gap)
	list.Size = UDim2.new(1, -right, 1, -below - Gap)

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
		local tab = Ui.button(side, name, Ui.Colors.off, UDim2.new(1, 0, 0, RowHeight + 4))
		tab.LayoutOrder = nextOrder()
		tab.Activated:Connect(function()
			openTab(name)
		end)
		tabs[name] = tab
		return frame
	end

	-- ============================================================== Player
	local you = page("Player")
	local moneyRow = row(you, "Money")
	local amount = input(moneyRow, "amount: 5m, 1b", "1m", 120, function(text)
		send("/money", text)
	end)
	local function money(sign: string)
		local text = amount()
		if not text then
			window.status.Text = "Type an amount first, like 5m or 1b."
			return
		end
		send("/money", sign .. (string.gsub(text, "^%-", "")))
	end
	button(moneyRow, "Add", Ui.Colors.buy, 80, function()
		money("")
	end)
	button(moneyRow, "Remove", Ui.Colors.confirm, 90, function()
		money("-")
	end)
	for _, quick in { "1m", "100m", "10b" } do
		button(moneyRow, `+{string.upper(quick)}`, Ui.Colors.buy, 66, function()
			send("/money", quick)
		end)
	end
	divider(you)

	-- Monster attacks: a switch, on = zone monsters attack (the "Calm" attribute is off).
	local attackRow = row(you, "Attacks")
	local onLabel = Ui.text(attackRow, "On", UDim2.fromOffset(30, RowHeight), Ui.Colors.text, true, 18)
	onLabel.LayoutOrder = nextOrder()
	local switch = Instance.new("TextButton")
	switch.LayoutOrder = nextOrder()
	switch.Text = ""
	switch.AutoButtonColor = false
	switch.Size = UDim2.fromOffset(90, RowHeight)
	switch.BackgroundColor3 = Ui.Colors.row
	switch.Parent = attackRow
	Ui.corner(switch, RowHeight)
	Ui.rim(switch, Ui.Colors.rim, 2)
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.fromOffset(RowHeight - 8, RowHeight - 8)
	knob.Parent = switch
	Ui.corner(knob, RowHeight)
	local offLabel = Ui.text(attackRow, "Off", UDim2.fromOffset(34, RowHeight), Ui.Colors.text, true, 18)
	offLabel.LayoutOrder = nextOrder()
	local attackNote = Ui.text(attackRow, "", UDim2.fromOffset(220, RowHeight), Ui.Colors.muted, false, 14)
	attackNote.LayoutOrder = nextOrder()
	-- On unless the picked player is calm (All players: on unless every one of them is).
	local function attacksOn(): boolean
		if target == Everyone then
			for _, other in Players:GetPlayers() do
				if not other:GetAttribute("Calm") then
					return true
				end
			end
			return false
		end
		local picked = if target == "me" then player else Players:GetPlayerByUserId(tonumber(target) or 0)
		return not (picked and picked:GetAttribute("Calm"))
	end
	local function showSwitch()
		local on = attacksOn()
		knob.Position = if on then UDim2.new(0, 4, 0.5, 0) else UDim2.new(1, -(RowHeight - 4), 0.5, 0)
		knob.BackgroundColor3 = if on then Ui.Colors.money else Ui.Colors.muted
		attackNote.Text = if on then "zone monsters attack" else "zone monsters leave them alone"
	end
	switch.Activated:Connect(function()
		send("/attacks", if attacksOn() then "off" else "on")
		task.delay(0.4, showSwitch)
	end)
	showSwitch()
	table.insert(onTargetChanged, showSwitch)
	divider(you)

	local missionRow = row(you, "Missions")
	local missionModal = modal(canvas, "Change daily missions", Vector2.new(640, 400))
	button(missionRow, "Reset missions", Ui.Colors.equip, 150, function()
		send("/missions", "reset")
	end)
	button(missionRow, "Change daily missions", Ui.Colors.equip, 210, function()
		missionModal.title.Text = `Change daily missions ({targetName()})`
		missionModal.open()
	end)
	local moreRow = row(you, "")
	button(moreRow, "Finish all", Ui.Colors.buy, 100, function()
		send("/missions", "done")
	end)
	for _, days in { "0", "3", "7" } do
		button(moreRow, `Streak {days}`, Ui.Colors.off, 90, function()
			send("/missions", `streak {days}`)
		end)
	end
	note(you, "Reset missions: today's missions start over (no progress, claimable again).")

	-- The missions pop-up: one dropdown per tier; Set swaps in that mission.
	note(
		missionModal.body,
		"Pick a mission for a tier and press Set: it replaces today's mission of that tier."
	)
	for _, tier in MissionConfig.Tiers do
		local tierRow = row(missionModal.body, tier.id)
		local options = missionOptions(tier.id)
		local chosen = dropdown(tierRow, 330, fixed(options), options[1] and options[1].value)
		button(tierRow, "Set", Ui.Colors.buy, 70, function()
			local id = chosen()
			if id then
				send("/missions", `set {id}`)
			end
		end)
	end
	button(missionModal.footer, "Random new set", Ui.Colors.equip, 170, function()
		send("/missions", "new")
	end)
	button(missionModal.footer, "Close", Ui.Colors.off, 90, missionModal.close)
	divider(you)

	local tutorialRow = row(you, "Tutorial")
	button(tutorialRow, "Skip", Ui.Colors.off, 80, function()
		send("/tutorial", "skip")
	end)
	button(tutorialRow, "Restart", Ui.Colors.off, 90, function()
		send("/tutorial", "restart")
	end)
	divider(you)

	-- The two red buttons, bottom right like the sketch.
	local dangerRow = Instance.new("Frame")
	dangerRow.LayoutOrder = nextOrder()
	dangerRow.BackgroundTransparency = 1
	dangerRow.Size = UDim2.new(1, -8, 0, RowHeight + 12)
	dangerRow.Parent = you
	local dangerLayout = Instance.new("UIListLayout")
	dangerLayout.FillDirection = Enum.FillDirection.Horizontal
	dangerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	dangerLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	dangerLayout.Padding = UDim.new(0, 16)
	dangerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dangerLayout.Parent = dangerRow
	local resetSave = button(dangerRow, "RESET SAVE", Ui.Colors.confirm, 150, function()
		if target == Everyone then
			window.status.Text = "Reset save works on one player at a time: pick them top left."
			return
		end
		local whose = if target == "me" then "your" else `{targetName()}'s`
		local savedTarget = target
		askFirst(
			`Wipe {whose} whole save? Money, monsters, wings, everything goes back to a brand-new player's and they're sent out of the game. This can't be undone.`,
			"Yes, wipe the save",
			function()
				if target ~= savedTarget then
					return -- the pick changed while the pop-up was open
				end
				send("/reset", "confirm")
			end
		)
	end)
	resetSave.Size = UDim2.fromOffset(150, RowHeight + 8)
	local resetPlayer = button(dangerRow, "RESET PLAYER", Ui.Colors.confirm, 160, function()
		askFirst(
			`Respawn {targetName()}? A fresh body back home, like the Reset button in the Roblox menu (a hunt in a zone ends). Their save is not touched.`,
			"Yes, respawn",
			function()
				send("/respawn")
			end
		)
	end)
	resetPlayer.Size = UDim2.fromOffset(160, RowHeight + 8)

	-- ============================================================== Mansion
	local mansion = page("Mansion")
	local wingRow = row(mansion, "Wings")
	for index, wing in Wings.List do
		button(wingRow, `{index} {wing.id}`, Ui.Colors.equip, 104, function()
			send("/wings", tostring(index))
		end)
	end
	note(mansion, "How many wings the mansion has (1 = only the Foyer). It rebuilds right away.")
	divider(mansion)
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
	local hauntRow = row(mansion, "Effects")
	button(hauntRow, "Haunt all", Ui.Colors.equip, 100, function()
		send("/haunt")
	end)
	note(
		mansion,
		"Haunt all: every monster in the mansion picks up a roaming effect (the event's during an event)."
	)
	divider(mansion)
	local chamberRow = row(mansion, "Growth Chamber")
	button(chamberRow, "Chamber done", Ui.Colors.equip, 130, function()
		send("/chamber") -- the Growth Chamber's 20 minutes are up
	end)
	button(chamberRow, "Refill goes", Ui.Colors.equip, 120, function()
		send("/charges")
	end)

	-- ============================================================== Items
	local items = page("Items")
	local itemRow = row(items, "Item")
	local item = dropdown(itemRow, 280, fixed(itemList), itemList[1] and itemList[1].value)
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
	note(items, "Vacuums and slappers are given once and put in their hand; cakes and other items stack.")

	-- ============================================================== Monsters
	local monstersPage = page("Monsters")
	local refreshTheirs: () -> ()
	heading(monstersPage, "Give a new monster")
	local giveMonsterRow = row(monstersPage, "Monster")
	local giveMonster =
		dropdown(giveMonsterRow, 280, fixed(monsterList), monsterList[1] and monsterList[1].value)
	local giveSizeRow = row(monstersPage, "Size")
	local giveSize = dropdown(giveSizeRow, 120, fixed(sizeList), "Normal")
	local giveKg = input(giveSizeRow, "or kg", nil, 70)
	local kgNote =
		Ui.text(giveSizeRow, "a weight sets the size", UDim2.fromOffset(160, RowHeight), Ui.Colors.muted, false, 14)
	kgNote.LayoutOrder = nextOrder()
	local giveVariantRow = row(monstersPage, "Variant")
	local giveVariant = dropdown(giveVariantRow, 160, fixed(variantList), "None")
	local giveEffects: { string } = {}
	local giveEffectRow = row(monstersPage, "Effects")
	local giveSummary: TextLabel
	button(giveEffectRow, "✚ Pick effects...", Ui.Colors.equip, 170, function()
		openPicker("Effects for the new monster", giveEffects, {}, function(ids)
			giveEffects = ids
			giveSummary.Text = effectSummary(giveEffects)
		end)
	end)
	giveSummary = note(monstersPage, effectSummary(giveEffects))
	giveSummary.TextColor3 = Ui.Colors.text
	local giveRow = row(monstersPage, "")
	button(giveRow, "Give monster", Ui.Colors.buy, 150, function()
		local id = giveMonster()
		if not id then
			return
		end
		local parts = { id }
		local kgText = giveKg()
		if kgText then
			local kg = tonumber(kgText)
			if not kg or kg ~= kg or kg <= 0 then
				window.status.Text = "Weight: a number of kg, like 120 (or leave it empty)."
				return
			end
			table.insert(parts, `{kg}kg`)
		else
			table.insert(parts, giveSize() or "Normal")
		end
		local variant = giveVariant()
		if variant and variant ~= "None" then
			table.insert(parts, variant)
		end
		for _, effectId in giveEffects do
			table.insert(parts, effectId)
		end
		send("/givemonster", table.concat(parts, " "))
		task.delay(1, refreshTheirs)
	end)
	button(giveRow, "Untick effects", Ui.Colors.off, 140, function()
		giveEffects = {}
		giveSummary.Text = effectSummary(giveEffects)
	end)
	divider(monstersPage)

	-- More effects on a monster they already have (one player at a time).
	heading(monstersPage, "Add effects to one of their monsters")
	local theirs: { TheirMonster } = {}
	local theirRow = row(monstersPage, "Theirs")
	local theirMonster, pickTheirs = dropdown(theirRow, 400, function()
		local options: { Option } = {}
		for _, monster in theirs do
			table.insert(options, { label = monster.label, value = monster.uid })
		end
		return if #options > 0
			then options
			else { { label = "No monsters (or All players is picked)", value = "" } }
	end, "")
	button(theirRow, "Refresh", Ui.Colors.off, 80, function()
		task.spawn(refreshTheirs)
	end)
	local addEffects: { string } = {}
	local addRow = row(monstersPage, "Effects")
	local addSummary: TextLabel
	button(addRow, "✚ Pick effects...", Ui.Colors.equip, 170, function()
		if target == Everyone then
			window.status.Text = "Add effects works on one player: pick them top left."
			return
		end
		local uid = theirMonster()
		local owned: { string } = {}
		local name = "their monster"
		for _, monster in theirs do
			if monster.uid == uid then
				owned = monster.effects
				name = string.match(monster.label, "^(.-)%s*·") or monster.label
			end
		end
		openPicker(`Add effects: {name}`, addEffects, owned, function(ids)
			addEffects = ids
			addSummary.Text = effectSummary(addEffects)
		end)
	end)
	addSummary = note(monstersPage, effectSummary(addEffects))
	addSummary.TextColor3 = Ui.Colors.text
	local addGoRow = row(monstersPage, "")
	button(addGoRow, "Add effects", Ui.Colors.buy, 140, function()
		local uid = theirMonster()
		if target == Everyone then
			window.status.Text = "Add effects works on one player: pick them top left."
			return
		end
		if not uid or uid == "" then
			window.status.Text = "Pick one of their monsters first."
			return
		end
		if #addEffects == 0 then
			window.status.Text = "Pick effects first (✚ Pick effects...)."
			return
		end
		send("/addeffect", `{uid} {table.concat(addEffects, " ")}`)
		addEffects = {}
		addSummary.Text = effectSummary(addEffects)
		task.delay(1, refreshTheirs)
	end)
	divider(monstersPage)
	local clearRow = row(monstersPage, "Remove all")
	button(clearRow, "Remove all their monsters", Ui.Colors.confirm, 240, function()
		askFirst(
			`Remove every monster {targetName()} owns? The mansion, Storage and Growth Chamber are emptied. This can't be undone.`,
			"Yes, remove them",
			function()
				send("/clearmonsters")
				task.delay(1, refreshTheirs)
			end
		)
	end)

	-- Asks the server for the picked player's monsters (only admins get an answer).
	local refreshing = false
	refreshTheirs = function()
		if refreshing then
			return
		end
		refreshing = true
		table.clear(theirs)
		if target ~= Everyone then
			local targetId = if target == "me" then nil else tonumber(target)
			local ok, rows = pcall(function()
				return monstersRemote:InvokeServer(targetId)
			end)
			if ok and type(rows) == "table" then
				for _, monsterRow in rows do
					if
						type(monsterRow) == "table"
						and type(monsterRow.uid) == "string"
						and type(monsterRow.label) == "string"
					then
						local effects: { string } = {}
						if type(monsterRow.effects) == "table" then
							for _, id in monsterRow.effects do
								if type(id) == "string" then
									table.insert(effects, id)
								end
							end
						end
						table.insert(
							theirs,
							{ uid = monsterRow.uid, label = monsterRow.label, effects = effects }
						)
					end
				end
			end
		end
		local current = theirMonster()
		local kept = false
		for _, monster in theirs do
			kept = kept or monster.uid == current
		end
		pickTheirs(if kept and current then current elseif theirs[1] then theirs[1].uid else "")
		refreshing = false
	end
	table.insert(onTargetChanged, refreshTheirs)
	tabs["Monsters"].Activated:Connect(function()
		task.spawn(refreshTheirs)
	end)

	-- ============================================================== Zones
	local zonesPage = page("Zones")
	note(
		zonesPage,
		"Works in the zone the picked player is standing in. Spawned monsters are theirs alone to catch and never attack."
	)
	local monsterRow = row(zonesPage, "Monster")
	local spawnMonster =
		dropdown(monsterRow, 280, fixed(monsterList), monsterList[1] and monsterList[1].value)
	local sizeRow = row(zonesPage, "Spawn as")
	for _, option in sizeList do
		button(sizeRow, option.label, Ui.Colors.sell, 78, function()
			local id = spawnMonster()
			if id then
				send("/spawn", `{id} {option.value}`)
			end
		end)
	end
	local zoneRow = row(zonesPage, "Whole zone")
	button(zoneRow, "Every monster of the zone", Ui.Colors.sell, 230, function()
		send("/spawn", "all Normal")
	end)
	divider(zonesPage)
	local fightRow = row(zonesPage, "Attacks")
	button(fightRow, "Attack now", Ui.Colors.confirm, 120, function()
		send("/attack")
	end)
	note(
		zonesPage,
		"Attack now: the closest monster in their zone attacks right away. Turn attacks on or off on the Player tab."
	)

	-- ============================================================== Events
	-- Watcher events reach everyone. Tapping one starts it now, ending one that's playing.
	local server = page("Events")
	local live = Ui.text(server, "", UDim2.new(1, 0, 0, 24), Ui.Colors.lamp, true, 18)
	live.LayoutOrder = nextOrder()
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
	local timeline = note(server, "")
	timeline.TextColor3 = Ui.Colors.text
	timeline.TextSize = 16
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
				local skipped = workspace:GetAttribute("WatcherSkipped")
				local skip = if type(skipped) == "number" then skipped else nil
				for _, slot in Watcher.upcoming(now, TimelineLength, skip) do
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

	-- ============================================================== Shops
	-- Admin restocks (this server only): pick items and amounts, then restock.
	local restock = page("Shops")
	heading(restock, "Restock the Bakery and Workshop")
	local restockLive = Ui.text(restock, "", UDim2.new(1, 0, 0, 22), Ui.Colors.muted, false, 16)
	restockLive.LayoutOrder = nextOrder()
	local planned: { [string]: number } = {}
	local plannedText: TextLabel
	local function showPlanned()
		local ids: { string } = {}
		for id in planned do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			return restockNames[a] < restockNames[b]
		end)
		local parts: { string } = {}
		for _, id in ids do
			table.insert(parts, `{restockNames[id]} x{planned[id]}`)
		end
		plannedText.Text = if #parts > 0
			then `In this restock: {table.concat(parts, ", ")}`
			else "Nothing picked yet: use the buttons above."
	end
	local amountRow = row(restock, "Amount")
	local amountBox = input(amountRow, "per player", "10", 80)
	Ui.text(
		amountRow,
		"each player can buy (0 = sold out)",
		UDim2.fromOffset(250, RowHeight),
		Ui.Colors.muted,
		false,
		14
	).LayoutOrder =
		nextOrder()
	local function restockAmount(): number?
		local value = tonumber(amountBox())
		if not value or value ~= value or value < 0 or value > Restock.MaxAmount then
			window.status.Text = `Amount: a number from 0 to {Restock.MaxAmount}.`
			return nil
		end
		return math.floor(value)
	end
	local function addAll(cakes: boolean?)
		local count = restockAmount()
		if not count then
			return
		end
		for _, restockItem in Restock.items() do
			if not restockItem.event and (cakes == nil or Restock.isCake(restockItem.id) == cakes) then
				planned[restockItem.id] = count
			end
		end
		showPlanned()
	end
	local quickRow = row(restock, "Add")
	button(quickRow, "All cakes", Ui.Colors.equip, 100, function()
		addAll(true)
	end)
	button(quickRow, "All Workshop", Ui.Colors.equip, 120, function()
		addAll(false)
	end)
	button(quickRow, "Everything", Ui.Colors.equip, 100, function()
		addAll(nil)
	end)
	local pickRow = row(restock, "One item")
	local restockItem = dropdown(pickRow, 260, fixed(restockList), restockList[1] and restockList[1].value)
	button(pickRow, "Add", Ui.Colors.equip, 60, function()
		local id, count = restockItem(), restockAmount()
		if id and count then
			planned[id] = count
			showPlanned()
		end
	end)
	button(pickRow, "Remove", Ui.Colors.off, 80, function()
		local id = restockItem()
		if id then
			planned[id] = nil
			showPlanned()
		end
	end)
	plannedText = note(restock, "")
	plannedText.TextColor3 = Ui.Colors.text
	plannedText.TextSize = 16
	showPlanned()
	local minutesRow = row(restock, "Lasts")
	local minutesBox = input(minutesRow, "min", tostring(Restock.DefaultMinutes), 60)
	Ui.text(
		minutesRow,
		`minutes (1 to {Restock.MaxMinutes})`,
		UDim2.fromOffset(160, RowHeight),
		Ui.Colors.muted,
		false,
		14
	).LayoutOrder =
		nextOrder()
	local goRow = row(restock, "Go")
	button(goRow, "Restock now", Ui.Colors.buy, 120, function()
		if next(planned) == nil then
			window.status.Text = "Pick items first (All cakes, All Workshop or one item)."
			return
		end
		local minutes = tonumber(minutesBox()) or Restock.DefaultMinutes
		minutes = math.clamp(math.floor(minutes), 1, Restock.MaxMinutes)
		send("/restock", Restock.argument(planned, minutes))
	end)
	button(goRow, "Clear list", Ui.Colors.off, 100, function()
		table.clear(planned)
		showPlanned()
	end)
	button(goRow, "End restock", Ui.Colors.confirm, 110, function()
		send("/restock", "end")
	end)
	note(restock, "Restocks are for this server only and replace the normal stock of the items picked.")
	task.spawn(function()
		while restockLive.Parent do
			if window.isOpen() and restock.Visible then
				local ends = workspace:GetAttribute("AdminRestockEnd")
				restockLive.Text = if type(ends) == "number"
					then `Admin restock on: {Watcher.clock(math.max(ends - workspace:GetServerTimeNow(), 0))} left`
					else "No admin restock: the shops have their normal stock"
			end
			task.wait(1)
		end
	end)

	-- ============================================================== Make announcement
	-- A banner for everyone in this server (Roblox filters it like chat).
	local announceModal = modal(canvas, "Make announcement", Vector2.new(560, 320))
	note(
		announceModal.body,
		`Everyone in this server sees it at the top of their screen and in the chat. Up to {MaxAnnouncement} letters.`
	)
	local messageBox = Instance.new("TextBox")
	messageBox.LayoutOrder = nextOrder()
	messageBox.Size = UDim2.new(1, -8, 0, RowHeight * 3)
	messageBox.BackgroundColor3 = Ui.Colors.row
	messageBox.TextColor3 = Ui.Colors.text
	messageBox.PlaceholderText = "Double money for the next hour!"
	messageBox.PlaceholderColor3 = Ui.Colors.muted
	messageBox.Text = ""
	messageBox.Font = Enum.Font.FredokaOne
	messageBox.TextSize = 18
	messageBox.TextWrapped = true
	messageBox.TextXAlignment = Enum.TextXAlignment.Left
	messageBox.TextYAlignment = Enum.TextYAlignment.Top
	messageBox.ClearTextOnFocus = false
	Ui.corner(messageBox, 8)
	Ui.rim(messageBox, Ui.Colors.rim, 1)
	local messagePadding = Instance.new("UIPadding")
	messagePadding.PaddingLeft = UDim.new(0, 8)
	messagePadding.PaddingTop = UDim.new(0, 6)
	messagePadding.Parent = messageBox
	messageBox.Parent = announceModal.body
	local letters =
		Ui.text(announceModal.footer, "", UDim2.fromOffset(120, RowHeight), Ui.Colors.muted, false, 16)
	letters.LayoutOrder = nextOrder()
	messageBox:GetPropertyChangedSignal("Text"):Connect(function()
		letters.Text = `{#messageBox.Text}/{MaxAnnouncement}`
		letters.TextColor3 = if #messageBox.Text > MaxAnnouncement then Ui.Colors.confirm else Ui.Colors.muted
	end)
	local function sendAnnouncement()
		local text = string.match(messageBox.Text, "^%s*(.-)%s*$") or ""
		if text == "" then
			return
		end
		if #text > MaxAnnouncement then
			return -- the counter is red
		end
		send("/announce", text)
		messageBox.Text = ""
		announceModal.close()
	end
	messageBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			sendAnnouncement()
		end
	end)
	button(announceModal.footer, "Cancel", Ui.Colors.off, 90, announceModal.close)
	button(announceModal.footer, "📢 Announce", Ui.Colors.sell, 140, sendAnnouncement)
	announceButton.Activated:Connect(function()
		letters.Text = `{#messageBox.Text}/{MaxAnnouncement}`
		announceModal.open()
	end)

	-- The attacks switch follows the picked player (another admin may flip it too).
	task.spawn(function()
		while switch.Parent do
			if window.isOpen() and you.Visible then
				showSwitch()
			end
			task.wait(0.5)
		end
	end)

	openTab("Player")
end

local function toggle()
	if not player:GetAttribute("Admin") then
		return -- no longer an admin (the Studio TestAsPlayer switch)
	end
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
	monstersRemote = ReplicatedStorage.Remotes:WaitForChild("AdminMonsters") :: RemoteFunction
	build()
	UserInputService.InputBegan:Connect(function(inputObject, processed)
		if not processed and inputObject.KeyCode == Enum.KeyCode.F2 then
			toggle()
		end
	end)
	player:GetAttributeChangedSignal("Admin"):Connect(function()
		if not player:GetAttribute("Admin") and window.isOpen() then
			window.close()
		end
	end)
end

return AdminController
