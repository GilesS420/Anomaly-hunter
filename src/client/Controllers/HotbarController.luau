--!strict
-- Our own hotbar, in place of Roblox's, and the bottom row of the Backpack: nine numbered
-- slots holding Tools from your inventory (vacuums, Bait Bells, Return Charms, cakes and the
-- monsters in it). Press 1 to 9 or click/tap a slot to hold that Tool, again to put it away.
-- Like Roblox's: a Tool keeps its slot, and a new one goes in the first empty slot (tools,
-- then cakes, then monsters when several arrive at once). With the Backpack open every slot
-- shows, and you can drag a card onto a slot, drag slots onto each other to swap them, or
-- drag one off the bar to keep it in the Backpack only (InventoryController).
-- The server tags each Tool with Section ("Tool", "Cake" or "Monster") and Order
-- (HuntService, CakeService, InventoryService).
-- Where things sit is saved (Util/HotbarLayout, server HotbarService), so after a respawn or
-- rejoin every Tool goes back to its own slot, and a new one takes the first slot nothing
-- is remembered in (Giles 2026-10-24).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local HotbarLayout =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("HotbarLayout"))

local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local Drag = require(script.Parent.Parent:WaitForChild("Drag"))
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))

local HotbarController = {}

local Slots = 9
local SectionOrder = { Tool = 1, Cake = 2, Monster = 3 }
local SectionColor = {
	Tool = Ui.Colors.buy,
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
local saved = HotbarLayout.new() -- the saved layout, read in start()
local loaded = false -- Tools wait for it, so they don't fill in at random first

local function keyOf(tool: Tool): string?
	return HotbarLayout.key(
		tool:GetAttribute("ToolId"),
		tool:GetAttribute("CakeId"),
		tool:GetAttribute("MonsterUid")
	)
end

-- Sends the layout to the server a moment after the last change (dragging fires many).
local saveQueued = false
local function saveSoon()
	if saveQueued or not loaded then
		return
	end
	saveQueued = true
	task.delay(2, function()
		saveQueued = false
		local remotes = ReplicatedStorage:FindFirstChild("HotbarRemotes")
		local set = remotes and remotes:FindFirstChild("Set")
		if set and set:IsA("RemoteEvent") then
			set:FireServer(saved)
		end
	end)
end

local function remember(tool: Tool, slot: number)
	local key = keyOf(tool)
	if key then
		HotbarLayout.remember(saved, key, slot)
		saveSoon()
	end
end

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
			remember(other, from)
		else
			benched[other] = true
			local key = keyOf(other)
			if key then
				HotbarLayout.bench(saved, key)
			end
		end
	end
	slots[slot] = tool
	remember(tool, slot)
	refresh()
end

-- Takes a Tool off the bar; it stays in the Backpack.
function HotbarController.bench(tool: Tool)
	local from = slotOf(tool)
	if from then
		slots[from] = nil
	end
	benched[tool] = true
	local key = keyOf(tool)
	if key then
		HotbarLayout.bench(saved, key)
		saveSoon()
	end
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
	local canvas = Scale.canvas(gui) -- shrinks everything to fit a phone (client/Scale)
	gui.Name = "HotbarUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 6 -- over the Backpack window, which it is the bottom row of
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Sized for a computer screen; the Scale canvas shrinks it on a phone. The slot numbers
	-- are the keys 1 to 9, so only show them with a keyboard.
	local keys = UserInputService.KeyboardEnabled
	local size = 60
	local gap = 6
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -8)
	bar.Size = UDim2.fromOffset(Slots * size + (Slots - 1) * gap, size)
	bar.Parent = canvas
	-- A shop, the Collector or the Admin panel is open: the bar would cover its bottom
	-- buttons, so it hides until that window closes. It stays with the Backpack window.
	local function stepAside()
		bar.Visible = not Ui.anyWindowOpen("BackpackUi")
	end
	Ui.windowsChanged:Connect(stepAside)
	stepAside()
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
		button.Font = Enum.Font.FredokaOne
		button.TextWrapped = true
		local limit = button:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
		limit.MaxTextSize = 13
		if keys then
			local number = Ui.text(button, tostring(i), UDim2.fromOffset(14, 14), Ui.Colors.muted, true, 12)
			number.Position = UDim2.fromOffset(-6, -5)
		end
		button:SetAttribute("Paint", "")
		Locks.guard(button, "Hotbar") -- greyed out until the tutorial gets there
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
		local have = HotbarController.tools() -- sorted, so tools fill in first, then cakes, then monsters
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
		if not loaded then
			return -- the saved layout first
		end
		-- Tools with a remembered slot go back to it, benched ones stay off the bar.
		local placing: { Tool } = {}
		for _, tool in have do
			if slotOf(tool) or benched[tool] then
				continue
			end
			local key = keyOf(tool)
			local home = if key then saved.slots[key] else nil
			if key and HotbarLayout.isBenched(saved, key) then
				benched[tool] = true
			elseif home and not slots[home] then
				slots[home] = tool
			else
				table.insert(placing, tool)
			end
		end
		-- New ones take the first empty slot that isn't kept for a Tool that's away (a used-up
		-- cake), or else any empty slot.
		local kept: { [number]: boolean } = {}
		for _, slot in saved.slots do
			kept[slot] = true
		end
		for _, tool in placing do
			local free: number? = nil
			for i = 1, Slots do
				if not slots[i] and not kept[i] then
					free = i
					break
				end
			end
			if not free then
				for i = 1, Slots do
					if not slots[i] then
						free = i
						break
					end
				end
			end
			if free then
				slots[free] = tool
				kept[free] = true
				remember(tool, free)
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

	-- The saved layout (HotbarService sets it once the save has loaded). Without one after a
	-- while (an old server), Tools fill in as before.
	task.spawn(function()
		local deadline = os.clock() + 15
		while player:GetAttribute("HotbarLayout") == nil and os.clock() < deadline do
			task.wait(0.25)
		end
		local raw = player:GetAttribute("HotbarLayout")
		if typeof(raw) == "string" then
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok then
				saved = HotbarLayout.clean(decoded)
			end
		end
		loaded = true
		render()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or Locks.isLocked("Hotbar") then
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
