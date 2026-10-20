--!strict
-- The Backpack window. Opens from the HUD's Backpack button (or G on a keyboard), anywhere in
-- the game. Three tabs at the bottom:
--   Monsters  mansion and Storage, most valuable first. Store sends one to Storage; Hold puts
--             a stored one in your hand, then click in your mansion to place it. Lock keeps it
--             away from the Collector.
--   Cakes     how many of each you have; Hold one, then click in your mansion to set it out.
--   Tools     vacuums (tap Equip to use one), Bait Bells and Return Charms.
-- Holding uses the same Tools as our hotbar (HotbarController).
-- The server does every change and sends the new list back (server/Services/InventoryService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HotbarController = require(script.Parent.HotbarController)
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local InventoryController = {}

type MonsterRow = {
	uid: string,
	name: string,
	details: string,
	color: Color3,
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
}
type View = {
	monsters: { MonsterRow },
	items: { ItemRow },
	mansionCount: number,
	mansionCapacity: number,
	storageCount: number,
	storageCapacity: number,
}
type Tab = "Monsters" | "Cakes" | "Tools"

local StoredColor = Color3.fromRGB(120, 140, 170)

function InventoryController.start()
	local remotes = ReplicatedStorage:WaitForChild("InventoryRemotes")
	local GetView = remotes:WaitForChild("GetView") :: RemoteFunction
	local Move = remotes:WaitForChild("Move") :: RemoteFunction
	local Lock = remotes:WaitForChild("Lock") :: RemoteFunction
	local Equip = remotes:WaitForChild("Equip") :: RemoteFunction

	local window = Ui.window("BackpackUi", "Backpack")
	local tab: Tab = "Monsters"
	local view: View? = nil
	local busy = false
	local render: () -> ()

	-- Three tab buttons side by side in the footer.
	local tabs: { [Tab]: TextButton } = {}
	for i, name: Tab in { "Monsters", "Cakes", "Tools" } :: { Tab } do
		local button = Ui.button(window.footer, name, Ui.Colors.off, UDim2.new(1 / 3, -4, 1, 0))
		button.Position = UDim2.new((i - 1) / 3, if i == 1 then 0 else 2, 0, 0)
		button.Activated:Connect(function()
			tab = name
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

	-- Puts the hotbar Tool with this attribute in your hand and closes the window, so the next
	-- click lands in the world.
	local function hold(attribute: string, value: string)
		for _, tool in HotbarController.tools() do
			if tool:GetAttribute(attribute) == value then
				if tool.Parent ~= Players.LocalPlayer.Character then
					HotbarController.toggle(tool)
				end
				window.close()
				return
			end
		end
		window.status.Text = "Not in your hotbar yet. Try again in a second."
	end

	local function monsterRows(rows: { MonsterRow })
		for i, monster in rows do
			local details = monster.details
				.. (if monster.stored then " · Storage" else "")
				.. (if monster.locked then " · Locked" else "")
			local _, actions = Ui.row(window.list, i, monster.name, monster.color, details)
			local move = Ui.button(
				actions,
				if monster.stored then "Hold" else "Store",
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
			local stored = monster.stored
			move.Activated:Connect(function()
				if stored then
					hold("MonsterUid", uid)
				else
					call(Move, uid)
				end
			end)
			lock.Activated:Connect(function()
				call(Lock, uid)
			end)
		end
	end

	local function itemRows(rows: { ItemRow })
		for i, item in rows do
			local _, actions = Ui.row(window.list, i, item.name, Ui.Colors.text, item.details)
			if item.cake then
				local button = Ui.button(actions, "Hold", Ui.Colors.sell, UDim2.fromScale(1, 1))
				local id = item.id
				button.Activated:Connect(function()
					hold("CakeId", id)
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
			local cakes = tab == "Cakes"
			local rows: { ItemRow } = {}
			for _, item in current.items do
				if item.cake == cakes then
					table.insert(rows, item)
				end
			end
			if #rows > 0 then
				window.status.Text = if cakes
					then "Hold a cake, then click in your mansion to set it out"
					else "Your tools and supplies"
			else
				window.status.Text = if cakes
					then "No cakes yet. Visit the Haunted Bakery!"
					else "No tools yet. Visit the Hunter's Workshop!"
			end
			itemRows(rows)
		end
	end

	local function toggle()
		if window.isOpen() then
			window.close()
			return
		end
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
