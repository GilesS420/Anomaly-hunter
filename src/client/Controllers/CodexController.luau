--!strict
-- The Codex window. Opens from the HUD's Codex button (or C on a keyboard). One tab per zone,
-- one for the Watcher event monsters and one for haunted effects and secret combos:
--   Monster pages  every monster of that zone as a card, Common first. Ones you haven't caught
--                  yet are a "?" with no name. Four dots on each card are the catch variants
--                  (Silver, Gold, Shiny, Rainbow): each one lights up once you've caught that
--                  monster in that colour. The strip above the cards counts how many you've
--                  found and how many of each variant, the extra goals for every page.
--   Effects        every effect (unfound ones say where they come from) and the secret combos
--                  (the recipe shows once you've made one).
-- Tap a card to see it along the bottom. Everything comes from the server
-- (CodexRemotes.GetView, server/Services/CodexService); the pictures are preview models in
-- PlayerGui.InventoryPreviews.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local CodexController = {}

type Progress = { found: number, total: number, variants: { [string]: number } }
type MonsterCard = {
	id: string,
	name: string,
	rarity: string,
	color: Color3,
	found: boolean,
	variants: { [string]: boolean },
	look: string?,
}
type Page = { id: string, title: string, progress: Progress, monsters: { MonsterCard } }
type EffectCard = { id: string, name: string, multiplier: number, found: boolean, hint: string, combo: boolean }
type View = { pages: { Page }, effects: { EffectCard }, variants: { string } }

local EffectsTab = "Effects"

-- What each catch variant looks like on the cards (dots) and the goal strip.
local VariantColor = {
	Silver = Color3.fromRGB(205, 210, 225),
	Gold = Color3.fromRGB(255, 196, 60),
	Shiny = Color3.fromRGB(120, 235, 255),
	Rainbow = Color3.fromRGB(255, 120, 210),
} :: { [string]: Color3 }
local Unfound = Color3.fromRGB(58, 48, 78)

-- A rainbow across a dot or chip.
local function rainbow(parent: Instance)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 70)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
	})
	gradient.Parent = parent
end

function CodexController.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("CodexRemotes")
	local GetView = remotes:WaitForChild("GetView") :: RemoteFunction

	local window = Ui.window("CodexUi", "Codex")
	local panel = window.gui:FindFirstChild("Panel") :: Frame
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(780, 620)
	end
	local small = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local sideWidth = if small then 104 else 132
	local cell = if small then Vector2.new(84, 104) else Vector2.new(100, 120)
	local stripHeight = 30
	local top = 68 + stripHeight + 6

	-- Tabs down the left.
	local side = Instance.new("ScrollingFrame")
	side.Name = "Tabs"
	side.BackgroundTransparency = 1
	side.BorderSizePixel = 0
	side.ScrollBarThickness = 4
	side.AutomaticCanvasSize = Enum.AutomaticSize.Y
	side.CanvasSize = UDim2.new()
	side.Position = UDim2.fromOffset(0, 68)
	side.Size = UDim2.new(0, sideWidth, 1, -68 - 62)
	side.Parent = panel
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 8)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = side

	-- The goal strip: found, then one chip per variant.
	local strip = Instance.new("Frame")
	strip.Name = "Goals"
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.fromOffset(sideWidth + 10, 68)
	strip.Size = UDim2.new(1, -(sideWidth + 10), 0, stripHeight)
	strip.Parent = panel
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.Padding = UDim.new(0, 6)
	stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stripLayout.Parent = strip

	local list = window.list
	list.Position = UDim2.fromOffset(sideWidth + 10, top)
	list.Size = UDim2.new(1, -(sideWidth + 10), 1, -top - 62)
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

	-- The bottom bar: the selected card.
	local footer = window.footer
	local pickName = Ui.text(footer, "", UDim2.new(1, 0, 0, 26), Ui.Colors.text, true, 22)
	local pickDetails = Ui.text(footer, "", UDim2.new(1, 0, 0, 20), Ui.Colors.muted, false, 16)
	pickDetails.Position = UDim2.fromOffset(0, 28)

	local view: View? = nil
	local tab: string? = nil -- a page id, or EffectsTab
	local selected: string? = nil
	local render: () -> ()
	local tabButtons: { [string]: TextButton } = {}

	local function chip(order: number, text: string, color: Color3, isRainbow: boolean)
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.Size = UDim2.new(0, 0, 1, 0)
		frame.AutomaticSize = Enum.AutomaticSize.X
		frame.BackgroundColor3 = Ui.Colors.row
		frame.Parent = strip
		Ui.corner(frame, 8)
		local rim = Ui.rim(frame, color, 2)
		if isRainbow then
			rim.Color = Color3.new(1, 1, 1)
			rainbow(rim)
		end
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = frame
		local label = Ui.text(frame, text, UDim2.new(0, 0, 1, 0), color, true, 16)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.TextScaled = false
		label.TextSize = if small then 13 else 15
	end

	local function clearStrip()
		for _, child in strip:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	-- A card: picture (or icon), caption along the bottom, coloured rim.
	local function card(
		order: number,
		key: string,
		rim: Color3,
		look: string?,
		icon: string?,
		caption: string
	): TextButton
		local button = Instance.new("TextButton")
		button.Name = key
		button.LayoutOrder = order
		button.Text = ""
		button.AutoButtonColor = true
		button.BackgroundColor3 = Ui.Colors.row
		button.Parent = list
		Ui.corner(button, 10)
		Ui.rim(button, if selected == key then Ui.Colors.lamp else rim, if selected == key then 3 else 2)
		Ui.picture(button, UDim2.new(1, 0, 1, -36), look, icon)
		local label = Ui.text(button, caption, UDim2.new(1, -8, 0, 16), Ui.Colors.text, true, 14)
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.new(0.5, 0, 1, -18)
		label.TextXAlignment = Enum.TextXAlignment.Center
		button.Activated:Connect(function()
			selected = key
			render()
		end)
		return button
	end

	-- The four variant dots along the bottom of a monster card.
	local function dots(button: TextButton, variants: { string }, caught: { [string]: boolean })
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 1)
		row.Position = UDim2.new(0.5, 0, 1, -4)
		row.Size = UDim2.new(1, -8, 0, 12)
		row.Parent = button
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, 5)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row
		for i, variant in variants do
			local dot = Instance.new("Frame")
			dot.LayoutOrder = i
			dot.Size = UDim2.fromOffset(12, 12)
			local color = VariantColor[variant] or Ui.Colors.muted
			local has = caught[variant] == true
			dot.BackgroundColor3 = if has
				then (if variant == "Rainbow" then Color3.new(1, 1, 1) else color)
				else Unfound
			dot.Parent = row
			Ui.corner(dot, 6)
			if has and variant == "Rainbow" then
				rainbow(dot)
			end
			if not has then
				Ui.rim(dot, color, 1).Transparency = 0.4
			end
		end
	end

	local function monsterPage(page: Page, variants: { string })
		local progress = page.progress
		chip(1, `Found {progress.found}/{progress.total}`, Ui.Colors.lamp, false)
		for i, variant in variants do
			chip(
				i + 1,
				`{variant} {progress.variants[variant] or 0}/{progress.total}`,
				VariantColor[variant] or Ui.Colors.muted,
				variant == "Rainbow"
			)
		end
		window.status.Text = if progress.found < progress.total
			then `{page.title}: catch them all, then find each one in every colour`
			else `{page.title}: all found! Now catch each one in every colour`
		for i, monster in page.monsters do
			local key = `m:{monster.id}`
			local button = card(
				i,
				key,
				if monster.found then monster.color else Unfound,
				monster.look,
				if monster.found then nil else "❓",
				monster.name
			)
			dots(button, variants, monster.variants)
			if selected == key then
				pickName.Text = if monster.found
					then `{monster.name} · {monster.rarity}`
					else `??? · {monster.rarity}`
				pickName.TextColor3 = monster.color
				if monster.found then
					local parts = {}
					for _, variant in variants do
						table.insert(parts, `{variant} {if monster.variants[variant] then "✓" else "–"}`)
					end
					pickDetails.Text = table.concat(parts, "   ")
				else
					pickDetails.Text = if page.id == "Events"
						then "Not caught yet. It drifts through the hub during a Watcher event."
						else `Not caught yet. It lives in {page.title}.`
				end
			end
		end
	end

	local function effectsPage(effects: { EffectCard })
		local found, total, combos, comboTotal = 0, 0, 0, 0
		for _, effect in effects do
			if effect.combo then
				comboTotal += 1
				combos += if effect.found then 1 else 0
			else
				total += 1
				found += if effect.found then 1 else 0
			end
		end
		chip(1, `Effects {found}/{total}`, Ui.Colors.lamp, false)
		chip(2, `Secret combos {combos}/{comboTotal}`, Ui.Colors.equip, false)
		window.status.Text = "Haunted effects make monsters worth more. Combos are secret until you make one."
		for i, effect in effects do
			local key = `e:{effect.id}`
			local caption = if effect.found then effect.name elseif effect.combo then "Secret" else "???"
			card(
				i,
				key,
				if effect.found then (if effect.combo then Ui.Colors.equip else Ui.Colors.lamp) else Unfound,
				nil,
				if effect.found then (if effect.combo then "🔮" else "✨") else "❓",
				caption
			)
			if selected == key then
				pickName.Text = if effect.found or not effect.combo
					then `{if effect.found then effect.name else "???"} · x{effect.multiplier}`
					else `Secret combo · x{effect.multiplier}`
				pickName.TextColor3 = Ui.Colors.text
				pickDetails.Text = if effect.combo
					then (if effect.found
						then `Recipe: {effect.hint}`
						else "Mix the right two effects on one monster")
					else effect.hint
			end
		end
	end

	function render()
		Ui.clear(list)
		clearStrip()
		pickName.Text = ""
		pickDetails.Text = "Tap a card"
		local current = view
		if not current then
			window.status.Text = "Your save is still loading..."
			return
		end
		-- Tabs: made once, from the first view.
		if next(tabButtons) == nil then
			local names: { { id: string, title: string } } = {}
			for _, page in current.pages do
				table.insert(names, { id = page.id, title = page.title })
			end
			table.insert(names, { id = EffectsTab, title = EffectsTab })
			for i, entry in names do
				local button = Ui.button(side, entry.title, Ui.Colors.off, UDim2.new(1, -6, 0, 44))
				button.LayoutOrder = i
				local id = entry.id
				button.Activated:Connect(function()
					tab = id
					selected = nil
					render()
				end)
				tabButtons[id] = button
			end
		end
		local shown = tab or (current.pages[1] and current.pages[1].id) or EffectsTab
		for id, button in tabButtons do
			Ui.paint(button, if id == shown then Ui.Colors.equip else Ui.Colors.off)
		end
		if shown == EffectsTab then
			effectsPage(current.effects)
			return
		end
		for _, page in current.pages do
			if page.id == shown then
				monsterPage(page, current.variants)
			end
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
		if not processed and input.KeyCode == Enum.KeyCode.C and not Locks.isLocked("Codex") then
			toggle()
		end
	end)

	local hud = player:WaitForChild("PlayerGui"):WaitForChild("HuntUi"):WaitForChild("Hud")
	local button = hud:WaitForChild("Codex") :: TextButton
	button.Activated:Connect(toggle)
	Locks.guard(button, "Codex") -- greyed out until the tutorial is done
end

return CodexController
