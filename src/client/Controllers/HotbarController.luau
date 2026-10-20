--!strict
-- Our own hotbar, in place of Roblox's, and the bottom row of the Backpack: nine numbered
-- slots holding Tools from your inventory (cakes and the monsters in it). Press 1 to 9 or
-- click/tap a slot to hold that Tool, again to put it away.
-- Like Roblox's: a Tool keeps its slot, and a new one goes in the first empty slot (cakes
-- before monsters when several arrive at once). With the Backpack open every slot shows, and
-- you can drag a card onto a slot, drag slots onto each other to swap them, or drag one off
-- the bar to keep it in the Backpack only (InventoryController).
-- The server tags each Tool with Section ("Cake" or "Monster") and Order (CakeService,
-- InventoryService).

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local Drag = require(script.Parent.Parent:WaitForChild("Drag"))

local HotbarController = {}

local Slots = 9
local SectionOrder = { Cake = 1, Monster = 2 }
local SectionColor = {
	Cake = Ui.Colors.sell,
	Monster = Ui.Colors.equip,
}
local Keys = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

-- Roblox's own hotbar can't be turned off until the core scripts are ready, so keep trying.
local function hideRobloxBackpack()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
			return
		end
		task.wait(0.5)
	end
end

local function before(a: Tool, b: Tool): boolean
	local sa = SectionOrder[a:GetAttribute("Section") :: string] or 9
	local sb = SectionOrder[b:GetAttribute("Section") :: string] or 9
	if sa ~= sb then
		return sa < sb
	end
	local oa = tonumber(a:GetAttribute("Order")) or 0
	local ob = tonumber(b:GetAttribute("Order")) or 0
	if oa ~= ob then
		return oa < ob
	end
	return a.Name < b.Name
end

-- Every Tool you have: in the Backpack, and the one in your hand.
function HotbarController.tools(): { Tool }
	local player = Players.LocalPlayer
	local tools: { Tool } = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } :: { Instance? } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					table.insert(tools, child)
				end
			end
		end
	end
	table.sort(tools, before)
	return tools
end

-- Holds the tool, or puts it away if it's already in your hand.
function HotbarController.toggle(tool: Tool)
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return
	end
	if tool.Parent == character then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
end

-- Filled in by start().
local slots: { [number]: Tool } = {} -- slot number -> Tool
local benched: { [Tool]: boolean } = {} -- dragged off the bar: Backpack only
local open = false
local buttons: { TextButton } = {}
local refresh: () -> () = function() end

local function slotOf(tool: Tool): number?
	for i = 1, Slots do
		if slots[i] == tool then
			return i
		end
	end
	return nil
end

-- The slot under a screen point, if any.
function HotbarController.slotAt(at: Vector2): number?
	for i, button in buttons do
		if Drag.over(button, at) then
			return i
		end
	end
	return nil
end

-- Puts a Tool in a slot. Whatever was there moves to the Tool's old slot, or off the bar.
function HotbarController.put(tool: Tool, slot: number)
	local from = slotOf(tool)
	local other = slots[slot]
	benched[tool] = nil
	if from then
		slots[from] = nil
	end
	if other and other ~= tool then
		if from then
			slots[from] = other
		else
			benched[other] = true
		end
	end
	slots[slot] = tool
	refresh()
end

-- Takes a Tool off the bar; it stays in the Backpack.
function HotbarController.bench(tool: Tool)
	local from = slotOf(tool)
	if from then
		slots[from] = nil
	end
	benched[tool] = true
	refresh()
end

-- Calls `fn` whenever a Tool comes or goes (picked up, placed, bought, used).
local changeHooks: { () -> () } = {}
function HotbarController.onChange(fn: () -> ())
	table.insert(changeHooks, fn)
end

-- The Backpack opened or closed: open shows every slot, to drop things on.
function HotbarController.setOpen(isOpen: boolean)
	open = isOpen
	refresh()
end

function HotbarController.start()
	task.spawn(hideRobloxBackpack)
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "HotbarUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 6 -- over the Backpack window, which it is the bottom row of
	gui.Parent = player:WaitForChild("PlayerGui")

	local small = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local size = if small then 46 else 60
	local gap = 6
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -8)
	bar.Size = UDim2.fromOffset(Slots * size + (Slots - 1) * gap, size)
	bar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = bar

	for i = 1, Slots do
		local button = Ui.button(bar, "", Ui.Colors.off, UDim2.fromOffset(size, size))
		button.Name = `Slot{i}`
		button.LayoutOrder = i
		button.Visible = false
		button.Font = Enum.Font.GothamBold
		button.TextWrapped = true
		local limit = button:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
		limit.MaxTextSize = 13
		if not small then
			local number = Ui.text(button, tostring(i), UDim2.fromOffset(14, 14), Ui.Colors.muted, true, 12)
			number.Position = UDim2.fromOffset(-6, -5)
		end
		button:SetAttribute("Paint", "")
		Drag.attach(button, function()
			local tool = slots[i]
			return if tool then tool.Name else ""
		end, function()
			local tool = slots[i]
			if tool then
				HotbarController.toggle(tool)
			end
		end, function(at)
			local tool = slots[i]
			if not tool then
				return
			end
			local target = HotbarController.slotAt(at)
			if target then
				HotbarController.put(tool, target)
			else
				HotbarController.bench(tool)
			end
		end, function()
			local tool: Tool? = slots[i]
			return open and tool ~= nil
		end)
		buttons[i] = button
	end

	-- Drops Tools that are gone and puts new ones in the first empty slots.
	local function arrange()
		local have = HotbarController.tools() -- sorted, so cakes fill in before monsters
		local present: { [Tool]: boolean } = {}
		for _, tool in have do
			present[tool] = true
		end
		for i = 1, Slots do
			local tool = slots[i]
			if tool and not present[tool] then
				slots[i] = nil
			end
		end
		for tool in benched do
			if not present[tool] then
				benched[tool] = nil
			end
		end
		for _, tool in have do
			if not slotOf(tool) and not benched[tool] then
				for i = 1, Slots do
					if not slots[i] then
						slots[i] = tool
						break
					end
				end
			end
		end
	end

	-- Only touches a slot when what it shows changed, so nothing flickers. Closed, the bar
	-- shows the slots up to the last one in use; open, all nine.
	local function render()
		arrange()
		local last = 0
		for i = 1, Slots do
			if slots[i] then
				last = i
			end
		end
		local character = player.Character
		for i, button in buttons do
			local tool: Tool? = slots[i]
			local visible = open or i <= last
			if button.Visible ~= visible then
				button.Visible = visible
			end
			local text = if tool then tool.Name else ""
			if button.Text ~= text then
				button.Text = text
			end
			local held = tool ~= nil and tool.Parent == character
			local section = if tool then tool:GetAttribute("Section") :: string else nil
			local paint = if held then "Held" elseif tool then section or "" else "Empty"
			if button:GetAttribute("Paint") ~= paint then
				button:SetAttribute("Paint", paint)
				Ui.paint(
					button,
					if held
						then Ui.Colors.lamp
						elseif tool then SectionColor[section] or Ui.Colors.off
						else Ui.Colors.off
				)
				button.BackgroundTransparency = if tool then 0 else 0.6
			end
		end
	end
	refresh = render

	-- Redraw once per frame at most, whenever a Tool comes, goes, moves to your hand or is
	-- renamed. Waiting a frame also skips the moment a Tool is between Backpack and hand.
	local queued = false
	local function changed()
		if not queued then
			queued = true
			task.defer(function()
				queued = false
				render()
			end)
		end
	end
	local watching: { [Instance]: { RBXScriptConnection } } = {}
	local function watchTool(tool: Instance)
		if tool:IsA("Tool") and not watching[tool] then
			watching[tool] = {
				tool:GetPropertyChangedSignal("Name"):Connect(changed),
				tool.AncestryChanged:Connect(function()
					if not tool.Parent then
						local connections: { RBXScriptConnection } = watching[tool] or {}
						for _, connection in connections do
							connection:Disconnect()
						end
						watching[tool] = nil
					end
				end),
			}
		end
		changed()
	end
	local function watch(container: Instance)
		local function toolsChanged(child: Instance)
			if child:IsA("Tool") then
				for _, hook in changeHooks do
					task.spawn(hook)
				end
			end
		end
		container.ChildAdded:Connect(function(child)
			watchTool(child)
			toolsChanged(child)
		end)
		container.ChildRemoved:Connect(function(child)
			changed()
			toolsChanged(child)
		end)
		for _, child in container:GetChildren() do
			watchTool(child)
		end
	end
	watch(player:WaitForChild("Backpack"))
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child) -- a new Backpack comes with every respawn
		end
	end)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local slot = table.find(Keys, input.KeyCode)
		local tool = if slot then slots[slot] else nil
		if tool then
			HotbarController.toggle(tool)
		end
	end)
	render()
end

return HotbarController
