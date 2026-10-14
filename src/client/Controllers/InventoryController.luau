--!strict
-- The Backpack window. Opens from the HUD's Backpack button (or G on a keyboard), anywhere in
-- the game. Two tabs at the bottom:
--   Monsters  mansion and Storage, most valuable first. Store / Place moves one between them,
--             Lock keeps it away from the Collector.
--   Items     tools (tap Equip to use one) and how many treats, bells and charms you have.
--             Give on a treat lists your mansion monsters so you pick who eats it.
-- The server does every change and sends the new list back (server/Services/InventoryService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local InventoryController = {}

type MonsterRow = {
	uid: string,
	name: string,
	details: string,
	color: Color3,
	stored: boolean,
	locked: boolean,
	blocked: { [string]: string },
}
type ItemRow = {
	id: string,
	name: string,
	details: string,
	tool: boolean,
	equipped: boolean,
	treat: boolean,
	confirm: boolean,
}
type View = {
	monsters: { MonsterRow },
	items: { ItemRow },
	mansionCount: number,
	mansionCapacity: number,
	storageCount: number,
	storageCapacity: number,
}
type Tab = "Monsters" | "Items"

local StoredColor = Color3.fromRGB(120, 140, 170)

function InventoryController.start()
	local remotes = ReplicatedStorage:WaitForChild("InventoryRemotes")
	local GetView = remotes:WaitForChild("GetView") :: RemoteFunction
	local Move = remotes:WaitForChild("Move") :: RemoteFunction
	local Lock = remotes:WaitForChild("Lock") :: RemoteFunction
	local Equip = remotes:WaitForChild("Equip") :: RemoteFunction
	local Give = remotes:WaitForChild("Give") :: RemoteFunction

	local window = Ui.window("BackpackUi", "Backpack")
	local tab: Tab = "Monsters"
	local view: View? = nil
	local busy = false
	local picking: string? = nil -- the treat being given: the list shows your monsters instead
	local render: () -> ()

	-- Two tab buttons side by side in the footer.
	local tabs: { [Tab]: TextButton } = {}
	for i, name: Tab in { "Monsters", "Items" } :: { Tab } do
		local button = Ui.button(window.footer, name, Ui.Colors.off, UDim2.new(0.5, -4, 1, 0))
		button.Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 4, 0, 0)
		button.Activated:Connect(function()
			tab = name
			picking = nil
			render()
		end)
		tabs[name] = button
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

	local function monsterRows(rows: { MonsterRow })
		for i, monster in rows do
			local details = monster.details
				.. (if monster.stored then " · Storage" else "")
				.. (if monster.locked then " · Locked" else "")
			local _, actions = Ui.row(window.list, i, monster.name, monster.color, details)
			local move = Ui.button(
				actions,
				if monster.stored then "Place" else "Store",
				if monster.stored then Ui.Colors.buy else StoredColor,
				UDim2.new(0.6, -4, 1, 0)
			)
			local lock = Ui.button(
				actions,
				if monster.locked then "Unlock" else "Lock",
				if monster.locked then Ui.Colors.confirm else Ui.Colors.off,
				UDim2.new(0.4, 0, 1, 0)
			)
			lock.Position = UDim2.fromScale(0.6, 0)
			local uid = monster.uid
			move.Activated:Connect(function()
				call(Move, uid)
			end)
			lock.Activated:Connect(function()
				call(Lock, uid)
			end)
		end
	end

	local function itemRows(rows: { ItemRow })
		for i, item in rows do
			local _, actions = Ui.row(window.list, i, item.name, Ui.Colors.text, item.details)
			if item.treat then
				local button = Ui.button(actions, "Give", Ui.Colors.buy, UDim2.fromScale(1, 1))
				local id = item.id
				button.Activated:Connect(function()
					picking = id
					render()
				end)
			elseif item.tool then
				local button = Ui.button(
					actions,
					if item.equipped then "Using" else "Equip",
					if item.equipped then Ui.Colors.off else Ui.Colors.equip,
					UDim2.fromScale(1, 1)
				)
				local id = item.id
				button.Activated:Connect(function()
					call(Equip, id)
				end)
			end
		end
	end

	-- Picking who eats a treat: your mansion monsters, each with Give (or why it can't).
	local function giveRows(rows: { MonsterRow }, treat: ItemRow)
		local order = 0
		for _, monster in rows do
			if monster.stored then
				continue -- paused in Storage: place it back first
			end
			order += 1
			local _, actions = Ui.row(window.list, order, monster.name, monster.color, monster.details)
			local reason = monster.blocked[treat.id]
			if reason then
				Ui.button(actions, reason, Ui.Colors.off, UDim2.fromScale(1, 1)).AutoButtonColor = false
				continue
			end
			local button = Ui.button(actions, "Give", Ui.Colors.buy, UDim2.fromScale(1, 1))
			local treatId, uid = treat.id, monster.uid
			local function give()
				call(Give, treatId, uid)
			end
			if treat.confirm then
				Ui.confirmButton(button, "Sure?", give)
			else
				button.Activated:Connect(give)
			end
		end
		window.status.Text = if order == 0
			then "No monsters in your mansion to give it to. Tap Items to go back."
			else `Who gets the {treat.name}? Tap Items to go back.`
	end

	function render()
		Ui.clear(window.list)
		for name, button in tabs do
			Ui.paint(button, if name == tab then Ui.Colors.equip else Ui.Colors.off)
		end
		local current = view
		if not current then
			window.status.Text = "Your save is still loading..."
			return
		end
		if tab == "Monsters" then
			window.status.Text =
				`Mansion {current.mansionCount}/{current.mansionCapacity} · Storage {current.storageCount}/{current.storageCapacity}`
			if #current.monsters == 0 then
				window.status.Text ..= " · Catch some monsters first!"
			end
			monsterRows(current.monsters)
		else
			-- Stay on the monster list while you still have that treat (to give the next one).
			for _, item in current.items do
				if item.id == picking then
					giveRows(current.monsters, item)
					return
				end
			end
			picking = nil
			window.status.Text = if #current.items == 0
				then "Nothing yet. Visit the Workshop and the Bakery!"
				else "Your tools and supplies"
			itemRows(current.items)
		end
	end

	local function toggle()
		if window.isOpen() then
			window.close()
			return
		end
		picking = nil
		window.status.Text = "Loading..."
		window.open(nil)
		local ok, result = pcall(GetView.InvokeServer, GetView)
		view = if ok then result else nil
		if window.isOpen() then
			render()
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.G then
			toggle()
		end
	end)

	local hud = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("HuntUi"):WaitForChild("Hud")
	local button = hud:WaitForChild("Backpack") :: TextButton
	button.Activated:Connect(toggle)
end

return InventoryController
