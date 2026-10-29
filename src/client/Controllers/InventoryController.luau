--!strict
-- The Backpack window. Opens from the HUD's Backpack button (or G on a keyboard), anywhere in
-- the game. Tabs down the left, everything in your inventory as little picture cards, and
-- the hotbar as its bottom row (HotbarController):
--   Monsters   the monsters you picked up (press E on one in your mansion; Storage on the
--              server), most valuable first. Hold one and click in your mansion to put it
--              back.
--   Cakes      how many of each you have.
--   Tools      vacuums, Bait Bells and Return Charms.
--   Favorited  the monsters you hearted.
-- Tap a card to see what it is along the bottom, with its button: Hold (monster or cake) or
-- Equip (vacuum). Drag a monster or cake card onto a hotbar slot to put it there. The heart
-- on a monster favourites it, and the Collector never sells favourites.
-- The pictures are preview models the server keeps in PlayerGui.InventoryPreviews
-- (server/Services/InventoryService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Drag = require(script.Parent.Parent:WaitForChild("Drag"))
local HotbarController = require(script.Parent.HotbarController)
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local NamePrompt = require(script.Parent.Parent:WaitForChild("NamePrompt"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local InventoryController = {}

type MonsterRow = {
	uid: string,
	name: string,
	species: string,
	nickname: string?,
	details: string,
	color: Color3,
	value: string,
	look: string,
	stored: boolean,
	locked: boolean,
}
type ItemRow = {
	id: string,
	name: string,
	details: string,
	tool: boolean,
	equipped: boolean,
	cake: boolean,
	kind: string,
	count: number,
	look: string?,
}
type View = {
	monsters: { MonsterRow },
	items: { ItemRow },
	mansionCount: number,
	mansionCapacity: number,
	storageCount: number,
	storageCapacity: number,
}
type Tab = "Monsters" | "Cakes" | "Tools" | "Favorited"

local Tabs = { "Monsters", "Cakes", "Tools", "Favorited" } :: { Tab }
local Heart = Color3.fromRGB(235, 60, 90)

function InventoryController.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("InventoryRemotes")
	local GetView = remotes:WaitForChild("GetView") :: RemoteFunction
	local Lock = remotes:WaitForChild("Lock") :: RemoteFunction
	local Equip = remotes:WaitForChild("Equip") :: RemoteFunction

	local window = Ui.window("BackpackUi", "Backpack")
	local panel = window.panel
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(780, 600)
	end
	-- Sits just above the hotbar, which is the window's bottom row.
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -80)
	panel.Size = UDim2.new(0.92, 0, 1, -130)
	-- Pixel sizes for a computer screen; the window's Scale canvas shrinks them on a phone.
	local sideWidth = 116
	local cell = Vector2.new(100, 112)

	-- Tabs down the left; the cards fill the rest.
	local side = Instance.new("Frame")
	side.Name = "Tabs"
	side.BackgroundTransparency = 1
	side.Position = UDim2.fromOffset(0, 68)
	side.Size = UDim2.new(0, sideWidth, 1, -68 - 62)
	side.Parent = panel
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 8)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = side

	local list = window.list
	list.Position = UDim2.fromOffset(sideWidth + 10, 68)
	list.Size = UDim2.new(1, -(sideWidth + 10), 1, -68 - 62)
	local oldLayout = list:FindFirstChildOfClass("UIListLayout")
	if oldLayout then
		oldLayout:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 4)
	gridPadding.PaddingLeft = UDim.new(0, 4)
	gridPadding.Parent = list

	-- The bottom bar: what the selected card is, and its button.
	local footer = window.footer
	local pickName = Ui.text(footer, "", UDim2.new(1, -130, 0, 26), Ui.Colors.text, true, 22)
	local pickDetails = Ui.text(footer, "", UDim2.new(1, -130, 0, 20), Ui.Colors.muted, false, 16)
	pickDetails.Position = UDim2.fromOffset(0, 28)
	local action = Ui.button(footer, "", Ui.Colors.buy, UDim2.new(0, 120, 1, 0))
	action.AnchorPoint = Vector2.new(1, 0)
	action.Position = UDim2.fromScale(1, 0)
	action.Visible = false
	-- Next to it for monsters: give it a name with a Name Tag.
	local nameButton = Ui.button(footer, "Name", Ui.Colors.equip, UDim2.new(0, 90, 1, 0))
	nameButton.AnchorPoint = Vector2.new(1, 0)
	nameButton.Position = UDim2.new(1, -128, 0, 0)
	nameButton.Visible = false
	local onName: (() -> ())? = nil
	nameButton.Activated:Connect(function()
		if onName then
			onName()
		end
	end)

	local tab: Tab = "Monsters"
	local view: View? = nil
	local selected: string? = nil -- "m:<uid>" or "i:<itemId>"
	local busy = false
	local render: () -> ()
	local onAction: (() -> ())? = nil

	local tabButtons: { [Tab]: TextButton } = {}
	for i, name: Tab in Tabs do
		local button = Ui.button(side, name, Ui.Colors.off, UDim2.new(1, 0, 0, 44))
		button.LayoutOrder = i
		button.Activated:Connect(function()
			tab = name
			selected = nil
			render()
		end)
		tabButtons[name] = button
	end

	local function call(fn: RemoteFunction, ...: string)
		if busy then
			return
		end
		busy = true
		local ok, result = pcall(fn.InvokeServer, fn, ...)
		busy = false
		if ok and typeof(result) == "table" then
			if result.view then
				view = result.view
			end
			render()
			window.status.Text = result.message -- show the answer over the usual status line
		end
	end

	-- Puts the hotbar Tool with this attribute in your hand and closes the window, so the next
	-- click lands in the world.
	local function hold(attribute: string, value: string)
		for _, tool in HotbarController.tools() do
			if tool:GetAttribute(attribute) == value then
				if tool.Parent ~= player.Character then
					HotbarController.toggle(tool)
				end
				window.close()
				return
			end
		end
		window.status.Text = "Not in your hotbar yet. Try again in a second."
	end

	action.Activated:Connect(function()
		if onAction then
			onAction()
		end
	end)

	-- A card: a picture (or an icon), a small line along the bottom, a coloured rim.
	local function card(
		order: number,
		key: string,
		rim: Color3,
		look: string?,
		icon: string?,
		caption: string,
		toolTag: { string }? -- { attribute, value } of its hotbar Tool, to drag onto the hotbar
	)
		local button = Instance.new("TextButton")
		button.Name = key
		button.LayoutOrder = order
		button.Text = ""
		button.AutoButtonColor = true
		button.BackgroundColor3 = Ui.Colors.row
		button.Parent = list
		Ui.corner(button, 10)
		Ui.rim(button, if selected == key then Ui.Colors.lamp else rim, if selected == key then 3 else 2)

		if look or icon then
			Ui.picture(button, UDim2.new(1, 0, 1, -20), look, icon)
		end
		local label = Ui.text(button, caption, UDim2.new(1, -8, 0, 18), Ui.Colors.text, true, 15)
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.new(0.5, 0, 1, -3)
		label.TextXAlignment = Enum.TextXAlignment.Center
		local function select()
			selected = key
			render()
		end
		if toolTag then
			Drag.attach(
				button,
				function()
					return caption
				end,
				select,
				function(at)
					local slot = HotbarController.slotAt(at)
					if not slot then
						return
					end
					for _, tool in HotbarController.tools() do
						if tool:GetAttribute(toolTag[1]) == toolTag[2] then
							HotbarController.put(tool, slot)
							return
						end
					end
				end
			)
		else
			button.Activated:Connect(select)
		end
		return button, label
	end

	local function monsterCards(rows: { MonsterRow })
		for i, monster in rows do
			local key = `m:{monster.uid}`
			local button, label =
				card(i, key, monster.color, monster.look, nil, monster.value, { "MonsterUid", monster.uid })
			label.TextColor3 = Ui.Colors.money
			local heart = Instance.new("TextButton")
			heart.Name = "Heart"
			heart.BackgroundTransparency = 1
			heart.AnchorPoint = Vector2.new(1, 0)
			heart.Position = UDim2.new(1, -2, 0, 0)
			heart.Size = UDim2.fromOffset(28, 28)
			heart.Font = Enum.Font.FredokaOne
			heart.Text = if monster.locked then "♥" else "♡"
			heart.TextColor3 = if monster.locked then Heart else Ui.Colors.muted
			heart.TextSize = 24
			heart.ZIndex = 3
			heart.Parent = button
			local uid = monster.uid
			heart.Activated:Connect(function()
				call(Lock, uid)
			end)
			if selected == key then
				pickName.Text = monster.name
				pickName.TextColor3 = monster.color
				pickDetails.Text = monster.details
				action.Visible = true
				action.Text = "Hold"
				Ui.paint(action, Ui.Colors.buy)
				onAction = function()
					hold("MonsterUid", uid)
				end
				local tags = 0
				local items: { ItemRow } = if view then view.items else {}
				for _, item in items do
					if item.id == "NameTag" then
						tags = item.count
					end
				end
				nameButton.Visible = tags > 0 or monster.nickname ~= nil
				local species, nickname = monster.species, monster.nickname
				onName = function()
					NamePrompt.open(uid, species, nickname, tags, function(result)
						if result.view then
							view = result.view
						end
						render()
						window.status.Text = result.message
					end)
				end
			end
		end
	end

	local function itemCards(rows: { ItemRow })
		for i, item in rows do
			local key = `i:{item.id}`
			local caption = if item.tool
				then (if item.equipped then "Using" else item.name)
				elseif item.kind == "Slapper" then item.name -- kept forever, used by the Slap button
				else `x{item.count}`
			card(
				i,
				key,
				if item.cake then Ui.Colors.sell else Ui.Colors.equip,
				item.look,
				Ui.Icons[item.kind],
				caption,
				-- every Bakery cake and Workshop item has a hotbar Tool (CakeService, HuntService)
				if item.cake then { "CakeId", item.id } else { "ToolId", item.id }
			)
			if selected == key then
				pickName.Text = item.name
				pickName.TextColor3 = Ui.Colors.text
				pickDetails.Text = item.details
				local id = item.id
				if item.cake then
					action.Visible = true
					action.Text = "Hold"
					Ui.paint(action, Ui.Colors.sell)
					onAction = function()
						hold("CakeId", id)
					end
				elseif item.kind == "Tag" or item.kind == "Potion" then
					action.Visible = true
					action.Text = "Hold"
					Ui.paint(action, Ui.Colors.equip)
					onAction = function()
						hold("ToolId", id) -- then click a monster in your mansion (NameTagController)
					end
				elseif item.tool then
					action.Visible = true
					action.Text = if item.equipped then "Using" else "Equip"
					Ui.paint(action, if item.equipped then Ui.Colors.off else Ui.Colors.equip)
					onAction = function()
						call(Equip, id)
					end
				end
			end
		end
	end

	function render()
		Ui.clear(list)
		for name, button in tabButtons do
			Ui.paint(button, if name == tab then Ui.Colors.equip else Ui.Colors.off)
		end
		pickName.Text = ""
		pickDetails.Text = "Tap a card"
		action.Visible = false
		onAction = nil
		nameButton.Visible = false
		onName = nil
		local current = view
		if not current then
			window.status.Text = "Your save is still loading..."
			return
		end
		if tab == "Monsters" or tab == "Favorited" then
			local rows: { MonsterRow } = {}
			for _, monster in current.monsters do
				if monster.stored and (tab == "Monsters" or monster.locked) then
					table.insert(rows, monster)
				end
			end
			if tab == "Monsters" then
				window.status.Text =
					`{current.storageCount}/{current.storageCapacity} · Press E on a monster in your mansion to pick it up`
			else
				window.status.Text = if #rows > 0
					then "The Collector never sells these"
					else "Tap the heart on a monster to keep it safe"
			end
			monsterCards(rows)
		else
			local cakes = tab == "Cakes"
			local rows: { ItemRow } = {}
			for _, item in current.items do
				if item.cake == cakes then
					table.insert(rows, item)
				end
			end
			if #rows > 0 then
				window.status.Text = if cakes then "Hold a cake, then click in your mansion" else "Your tools"
			else
				window.status.Text = if cakes
					then "No cakes yet. Visit the Haunted Bakery!"
					else "No tools yet. Visit the Hunter's Workshop!"
			end
			itemCards(rows)
		end
		local room = if nameButton.Visible then -226 else -130
		pickName.Size = UDim2.new(1, room, 0, 26)
		pickDetails.Size = UDim2.new(1, room, 0, 20)
	end

	local function toggle()
		if window.isOpen() then
			window.close()
			return
		end
		window.status.Text = "Loading..."
		window.open(nil)
		HotbarController.setOpen(true)
		local ok, result = pcall(GetView.InvokeServer, GetView)
		view = if ok then result else nil
		if window.isOpen() then
			render()
		end
	end

	window.onClose = function()
		NamePrompt.close()
		HotbarController.setOpen(false)
	end
	-- Picking a monster up, placing one or using a cake changes the cards: fetch them again.
	local refetching = false
	HotbarController.onChange(function()
		if not window.isOpen() or refetching then
			return
		end
		refetching = true
		task.delay(0.3, function()
			refetching = false
			local ok, result = pcall(GetView.InvokeServer, GetView)
			if ok and result and window.isOpen() then
				view = result
				render()
			end
		end)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.G and not Locks.isLocked("Backpack") then
			toggle()
		end
	end)

	local hud =
		player:WaitForChild("PlayerGui"):WaitForChild("HuntUi"):WaitForChild("Canvas"):WaitForChild("Hud")
	local button = hud:WaitForChild("Menu"):WaitForChild("Backpack") :: TextButton
	button.Activated:Connect(toggle)
	Locks.guard(button, "Backpack") -- greyed out until the tutorial gets there
end

return InventoryController
