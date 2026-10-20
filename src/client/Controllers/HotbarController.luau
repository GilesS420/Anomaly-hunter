--!strict
-- Our own hotbar, in place of Roblox's: nine slots along the bottom of the screen holding the
-- Tools in your Backpack, cakes first (cheapest first), then the monsters in Storage (most
-- valuable first). Press 1 to 9 or click/tap a slot to hold that Tool, again to put it away.
-- The bar stays centred on however many slots are in use, and a Tool keeps its place: new
-- ones slot in by section and order, but nothing reshuffles while you play.
-- The server sorts nothing; it tags each Tool with Section ("Cake" or "Monster") and Order
-- (CakeService, InventoryService). Anything past nine is still in the Backpack window.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

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

function HotbarController.start()
	task.spawn(hideRobloxBackpack)
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "HotbarUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
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

	local shown: { Tool } = {}
	local buttons: { TextButton } = {}
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
		button.Activated:Connect(function()
			local tool = shown[i]
			if tool then
				HotbarController.toggle(tool)
			end
		end)
		buttons[i] = button
	end

	-- Keeps the Tools already on the bar where they are, drops the ones that are gone and
	-- slots new ones in before the first one they sort ahead of.
	local function arrange(): { Tool }
		local have = HotbarController.tools()
		local present: { [Tool]: boolean } = {}
		for _, tool in have do
			present[tool] = true
		end
		local kept: { Tool } = {}
		local placed: { [Tool]: boolean } = {}
		for _, tool in shown do
			if present[tool] then
				table.insert(kept, tool)
				placed[tool] = true
			end
		end
		for _, tool in have do
			if not placed[tool] then
				local at = #kept + 1
				for i, other in kept do
					if before(tool, other) then
						at = i
						break
					end
				end
				table.insert(kept, at, tool)
			end
		end
		return kept
	end

	-- Only touches a slot when what it shows changed, so nothing flickers.
	local function render()
		shown = arrange()
		local character = player.Character
		for i, button in buttons do
			local tool: Tool? = shown[i]
			if button.Visible ~= (tool ~= nil) then
				button.Visible = tool ~= nil
			end
			if tool then
				if button.Text ~= tool.Name then
					button.Text = tool.Name
				end
				local held = tool.Parent == character
				local section = tool:GetAttribute("Section") :: string
				local paint = if held then "Held" else section or ""
				if button:GetAttribute("Paint") ~= paint then
					button:SetAttribute("Paint", paint)
					Ui.paint(button, if held then Ui.Colors.lamp else SectionColor[section] or Ui.Colors.off)
				end
			end
		end
	end

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
		container.ChildAdded:Connect(watchTool)
		container.ChildRemoved:Connect(changed)
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
		local tool = if slot then shown[slot] else nil
		if tool then
			HotbarController.toggle(tool)
		end
	end)
	render()
end

return HotbarController
