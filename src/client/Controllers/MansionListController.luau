--!strict
-- A slim arrow tab on the right edge of the screen that slides out a small list of the
-- monsters in your mansion (Giles 2026-10-22: a sideways hamburger menu, not too big). Each
-- row has a Pick up button, and the list sorts by price, rarity or name. M toggles it on a
-- keyboard. Rows come from InventoryRemotes.GetView and picking up uses InventoryRemotes.Move,
-- the same as E on the monster itself (server/Services/InventoryService). The ✎ button names
-- a monster with a Name Tag (NamePrompt).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HotbarController = require(script.Parent.HotbarController)
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local NamePrompt = require(script.Parent.Parent:WaitForChild("NamePrompt"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))

local MansionListController = {}

type MonsterRow = {
	uid: string,
	name: string,
	species: string,
	nickname: string?,
	color: Color3,
	value: string,
	worth: number,
	rarityOrder: number,
	stored: boolean,
}
type View = {
	monsters: { MonsterRow },
	items: { { id: string, count: number } },
	mansionCount: number,
	mansionCapacity: number,
}
type Result = { ok: boolean, message: string, view: View? }
type Sort = string -- "Price", "Rarity" or "Name"

local PANEL_WIDTH = 240
local TAB_WIDTH = 26
local ROW_HEIGHT = 40
local Sorts: { Sort } = { "Price", "Rarity", "Name" }

local function sorted(rows: { MonsterRow }, by: Sort): { MonsterRow }
	local list = {}
	for _, row in rows do
		if not row.stored then
			table.insert(list, row)
		end
	end
	table.sort(list, function(a, b)
		if by == "Rarity" and a.rarityOrder ~= b.rarityOrder then
			return a.rarityOrder > b.rarityOrder
		elseif by == "Name" and a.name ~= b.name then
			return a.name < b.name
		elseif a.worth ~= b.worth then
			return a.worth > b.worth
		end
		return a.uid < b.uid
	end)
	return list
end

function MansionListController.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("InventoryRemotes")
	local GetView = remotes:WaitForChild("GetView") :: RemoteFunction
	local Move = remotes:WaitForChild("Move") :: RemoteFunction

	local gui = Instance.new("ScreenGui")
	local canvas = Scale.canvas(gui) -- shrinks everything to fit a phone (client/Scale)
	gui.Name = "MansionTabUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4 -- over the HUD, under the shop windows

	-- The panel and its tab move together: shut, only the tab shows at the screen's edge.
	local drawer = Instance.new("Frame")
	drawer.Name = "Drawer"
	drawer.AnchorPoint = Vector2.new(1, 0.5) -- on the right edge: the left one holds the HUD
	drawer.Size = UDim2.new(0, PANEL_WIDTH + TAB_WIDTH, 0.55, 0)
	drawer.BackgroundTransparency = 1
	drawer.Parent = canvas
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(0, 200)
	limit.MaxSize = Vector2.new(math.huge, 420)
	limit.Parent = drawer

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Position = UDim2.fromOffset(TAB_WIDTH - 2, 0)
	panel.Size = UDim2.new(0, PANEL_WIDTH, 1, 0)
	panel.BackgroundColor3 = Ui.Colors.panel
	panel.BackgroundTransparency = 0.08
	panel.Parent = drawer
	Ui.corner(panel, 10)
	Ui.rim(panel, Ui.Colors.rim, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = panel

	local title = Ui.text(panel, "Your mansion", UDim2.new(1, 0, 0, 24), Ui.Colors.lamp, true, 22)
	title.Font = Ui.TitleFont

	local sortBar = Instance.new("Frame")
	sortBar.Position = UDim2.fromOffset(0, 28)
	sortBar.Size = UDim2.new(1, 0, 0, 26)
	sortBar.BackgroundTransparency = 1
	sortBar.Parent = panel
	local sortLayout = Instance.new("UIListLayout")
	sortLayout.FillDirection = Enum.FillDirection.Horizontal
	sortLayout.Padding = UDim.new(0, 4)
	sortLayout.Parent = sortBar

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 60)
	list.Size = UDim2.new(1, 0, 1, -60)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = list

	local tab = Instance.new("TextButton")
	tab.Name = "Tab"
	tab.AnchorPoint = Vector2.new(0, 0.5)
	tab.Position = UDim2.fromScale(0, 0.5)
	tab.Size = UDim2.fromOffset(TAB_WIDTH, 64)
	tab.Font = Enum.Font.FredokaOne
	tab.Text = "◀"
	tab.TextSize = 18
	tab.TextColor3 = Ui.Colors.text
	tab.Parent = drawer
	Ui.corner(tab, 8)
	Ui.paint(tab, Ui.Colors.equip)

	gui.Parent = player:WaitForChild("PlayerGui")

	local isOpen = false
	local sortBy: Sort = "Price"
	local view: View? = nil
	local busy = false
	local sortButtons: { [Sort]: TextButton } = {}

	local function render()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for sort, button in sortButtons do
			Ui.paint(button, if sort == sortBy then Ui.Colors.equip else Ui.Colors.off)
		end
		local current = view
		if not current then
			title.Text = "Your mansion"
			return
		end
		title.Text = `Your mansion {current.mansionCount}/{current.mansionCapacity}`
		local rows = sorted(current.monsters, sortBy)
		for i, row in rows do
			local frame = Instance.new("Frame")
			frame.LayoutOrder = i
			frame.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
			frame.BackgroundColor3 = Ui.Colors.row
			frame.Parent = list
			Ui.corner(frame, 6)
			local name = Ui.text(frame, row.name, UDim2.new(1, -112, 0, 20), row.color, true, 16)
			name.Position = UDim2.fromOffset(6, 2)
			local price = Ui.text(frame, row.value, UDim2.new(1, -112, 0, 16), Ui.Colors.money, false, 13)
			price.Position = UDim2.fromOffset(6, 22)
			local pick = Ui.button(frame, "Pick up", Ui.Colors.buy, UDim2.fromOffset(68, ROW_HEIGHT - 8))
			pick.AnchorPoint = Vector2.new(1, 0.5)
			pick.Position = UDim2.new(1, -4, 0.5, 0)
			local rename = Ui.button(frame, "✎", Ui.Colors.equip, UDim2.fromOffset(30, ROW_HEIGHT - 8))
			rename.AnchorPoint = Vector2.new(1, 0.5)
			rename.Position = UDim2.new(1, -76, 0.5, 0)
			local padding = rename:FindFirstChildOfClass("UIPadding")
			if padding then
				padding.PaddingLeft = UDim.new(0, 2)
				padding.PaddingRight = UDim.new(0, 2)
			end
			rename.Activated:Connect(function()
				local tags = 0
				for _, item in current.items do
					if item.id == "NameTag" then
						tags = item.count
					end
				end
				NamePrompt.open(row.uid, row.species, row.nickname, tags, function(result)
					if result.view then
						view = result.view
						render()
					end
				end)
			end)
			pick.Activated:Connect(function()
				if busy then
					return
				end
				busy = true
				local ok, result = pcall(Move.InvokeServer, Move, row.uid)
				busy = false
				local answer: Result? = if ok then result else nil
				if answer and answer.view then
					view = answer.view
					render()
				end
			end)
		end
		if #rows == 0 then
			local empty = Ui.text(
				list,
				"No monsters here yet. Catch some and place them!",
				UDim2.new(1, -6, 0, 40),
				Ui.Colors.muted,
				false,
				14
			)
			empty.TextWrapped = true
		end
	end

	for i, sort in Sorts do
		local button = Ui.button(sortBar, sort, Ui.Colors.off, UDim2.new(1 / #Sorts, -3, 1, 0))
		button.LayoutOrder = i
		sortButtons[sort] = button
		button.Activated:Connect(function()
			sortBy = sort
			render()
		end)
	end

	local function fetch()
		local ok, result = pcall(GetView.InvokeServer, GetView)
		if ok and result and isOpen then
			view = result
			render()
		end
	end

	-- Shut, the drawer sits off screen so only the tab sticks out.
	local function place(animate: boolean)
		local target = UDim2.new(1, if isOpen then -8 else PANEL_WIDTH, 0.5, 0)
		tab.Text = if isOpen then "▶" else "◀"
		if animate then
			TweenService:Create(drawer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = target })
				:Play()
		else
			drawer.Position = target
		end
	end
	place(false)

	local function toggle()
		if Locks.isLocked("Backpack") then
			return
		end
		isOpen = not isOpen
		place(true)
		if isOpen then
			render()
			task.spawn(fetch)
		end
	end

	tab.Activated:Connect(toggle)
	Locks.guard(tab, "Backpack") -- unlocks together with the Backpack

	-- Placing or picking up a monster elsewhere changes the list: fetch it again.
	local refetching = false
	HotbarController.onChange(function()
		if not isOpen or refetching then
			return
		end
		refetching = true
		task.delay(0.3, function()
			refetching = false
			fetch()
		end)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			toggle()
		end
	end)
end

return MansionListController
