--!strict
-- The admin panel: buttons for every admin command (server/Services/DevService.luau), so
-- nobody has to remember the chat commands. Only admins see it: the server sets an "Admin"
-- attribute on them (see server/Admins.luau). Press F2 to open and close it (there's
-- no button on screen, Giles 2026-10-20). Each button sends
--   ReplicatedStorage.Remotes.AdminCommand   client -> server: (command, argument?)
-- and the server checks again that you're an admin before doing anything. Results come
-- back as the usual toasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Sizes = require(ReplicatedStorage.Shared.Config.Sizes)
local Wings = require(ReplicatedStorage.Shared.Config.Wings)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Ui = require(script.Parent.Parent.Ui)

local AdminController = {}

local player = Players.LocalPlayer
local CellSize = UDim2.fromOffset(122, 34)

local remote: RemoteEvent
local window: Ui.Window
local order = 0

local function send(command: string, argument: string?)
	remote:FireServer(command, argument)
end

local function nextOrder(): number
	order += 1
	return order
end

-- A heading and a box of buttons under it that wraps onto new lines.
local function section(title: string): Frame
	local heading = Ui.text(window.list, title, UDim2.new(1, -8, 0, 24), Ui.Colors.lamp, true, 20)
	heading.LayoutOrder = nextOrder()

	local grid = Instance.new("Frame")
	grid.LayoutOrder = nextOrder()
	grid.Size = UDim2.new(1, -8, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = CellSize
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	grid.Parent = window.list
	return grid
end

local function button(grid: Frame, text: string, color: Color3, action: () -> ()): TextButton
	local made = Ui.button(grid, text, color, CellSize)
	made.LayoutOrder = nextOrder()
	made.Activated:Connect(action)
	return made
end

-- A box to type a number or word into; returns a function that reads it (nil when empty).
local function input(grid: Frame, placeholder: string, start: string?): () -> string?
	local box = Instance.new("TextBox")
	box.LayoutOrder = nextOrder()
	box.BackgroundColor3 = Ui.Colors.row
	box.TextColor3 = Ui.Colors.text
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Ui.Colors.muted
	box.Text = start or ""
	box.Font = Enum.Font.FredokaOne
	box.TextScaled = true
	box.ClearTextOnFocus = false
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 18
	limit.Parent = box
	Ui.corner(box, 8)
	Ui.rim(box, Ui.Colors.rim, 1)
	box.Parent = grid
	return function()
		local text = string.match(box.Text, "^%s*(.-)%s*$")
		return if text and text ~= "" then text else nil
	end
end

local function build()
	window = Ui.window("AdminPanel", "Admin panel")
	window.status.Text = "Changes your own game. Results pop up at the top."

	-- Money
	local money = section("Money")
	local amount = input(money, "amount: 5m, 1b, -1k", "1m")
	button(money, "Add amount", Ui.Colors.buy, function()
		send("/money", amount())
	end)
	for _, quick in { "1m", "100m", "10b" } do
		button(money, `+{string.upper(quick)}`, Ui.Colors.buy, function()
			send("/money", quick)
		end)
	end

	-- Wings
	local wings = section("Mansion wings (how many you own)")
	for index, wing in Wings.List do
		button(wings, `{index}: {wing.id}`, Ui.Colors.equip, function()
			send("/wings", tostring(index))
		end)
	end

	-- Monsters in the mansion
	local mansion = section("Your mansion monsters")
	local number = input(mansion, "number", "5")
	button(mansion, "Grow (spurts)", Ui.Colors.equip, function()
		send("/grow", number())
	end)
	button(mansion, "Skip (hours)", Ui.Colors.equip, function()
		send("/skip", number())
	end)
	button(mansion, "Haunt all", Ui.Colors.equip, function()
		send("/haunt")
	end)
	local clear = Ui.button(mansion, "Clear all", Ui.Colors.confirm, CellSize)
	clear.LayoutOrder = nextOrder()
	Ui.confirmButton(clear, "Sure?", function()
		send("/clearmonsters")
	end)

	-- Watcher events
	local events = section("Watcher events (start now)")
	button(events, "Next event", Ui.Colors.sell, function()
		send("/summon")
	end)
	for _, event in Events.List do
		if event.launch then
			button(events, event.name, Ui.Colors.sell, function()
				send("/event", event.id)
			end)
		end
	end

	-- Free items
	local give = section("Give items (tools get equipped)")
	local count = input(give, "how many", "1")
	for _, list in { Shop.Workshop, Shop.Bakery } do
		for _, item in list do
			button(give, item.name, Ui.Colors.buy, function()
				send("/give", `{item.id} {count() or "1"}`)
			end)
		end
	end

	-- Spawning: pick a size, then a monster (spawns in the zone you're standing in).
	local sizeGrid = section("Spawn: size")
	local sizeId = "Normal"
	local sizeButtons: { [string]: TextButton } = {}
	local function pickSize(id: string)
		sizeId = id
		for otherId, other in sizeButtons do
			Ui.paint(other, if otherId == id then Ui.Colors.lamp else Ui.Colors.off)
		end
	end
	for _, size in Sizes do
		sizeButtons[size.id] = button(sizeGrid, size.id, Ui.Colors.off, function()
			pickSize(size.id)
		end)
	end
	pickSize(sizeId)

	local spawnAll = section("Spawn: go into a zone first")
	button(spawnAll, "All of my zone", Ui.Colors.sell, function()
		send("/spawn", `all {sizeId}`)
	end)
	for _, zone in Zones.List do
		local ids: { string } = {}
		for id, monster in Monsters do
			if monster.zone == zone.index then
				table.insert(ids, id)
			end
		end
		if #ids > 0 then
			table.sort(ids, function(a, b)
				return Monsters[a].baseValue < Monsters[b].baseValue
			end)
			local grid = section(`Spawn: {zone.name}`)
			for _, id in ids do
				button(grid, id, Ui.Colors.equip, function()
					send("/spawn", `{id} {sizeId}`)
				end)
			end
		end
	end

	-- Yourself
	local me = section("You")
	button(me, "Calm on/off", Ui.Colors.off, function()
		send("/calm")
	end)
	button(me, "Attack me", Ui.Colors.confirm, function()
		send("/attack")
	end)
	button(me, "Skip tutorial", Ui.Colors.off, function()
		send("/tutorial", "skip")
	end)
	button(me, "Restart tutorial", Ui.Colors.off, function()
		send("/tutorial", "restart")
	end)
	-- Wipes only your own save and kicks you; rejoin to play as a brand-new player.
	local reset = Ui.button(me, "Reset my save", Ui.Colors.confirm, CellSize)
	reset.LayoutOrder = nextOrder()
	Ui.confirmButton(reset, "Wipe it all?", function()
		send("/reset", "confirm")
	end)
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
