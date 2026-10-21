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
-- The look is a plain field journal: square numbered cards, flat tabs, and the goals as a
-- line of colour swatches rather than glowing pills. Tap a card to see it along the bottom. Everything comes from the server
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
local CardColor = Color3.fromRGB(26, 21, 36)
local Line = Color3.fromRGB(52, 44, 68) -- thin card and tab edges
local Gap = 8 -- between cards, and the margin round the content
local CardTarget = 112 -- cards are about this wide, then stretched to fill the row

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
		limit.MaxSize = Vector2.new(780, 540)
	end
	-- A little lower and shorter than other windows, so the messages along the top of the
	-- screen don't sit over the title.
	panel.Position = UDim2.fromScale(0.5, 0.54)
	panel.Size = UDim2.fromScale(0.92, 0.8)
	local small = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local sideWidth = if small then 110 else 140
	local stripHeight = 20
	local top = 68 -- under the title and the status line
	local left = sideWidth + Gap * 2
	local footerHeight = 52

	-- Tabs down the left.
	local side = Instance.new("ScrollingFrame")
	side.Name = "Tabs"
	side.BackgroundTransparency = 1
	side.BorderSizePixel = 0
	side.ScrollBarThickness = 0
	side.AutomaticCanvasSize = Enum.AutomaticSize.Y
	side.CanvasSize = UDim2.new()
	side.Position = UDim2.fromOffset(0, top)
	side.Size = UDim2.new(0, sideWidth, 1, -top - footerHeight - Gap)
	side.Parent = panel
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 2)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = side

	-- A thin line between the tabs and the cards.
	local divider = Instance.new("Frame")
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = Line
	divider.Position = UDim2.fromOffset(sideWidth + Gap, top)
	divider.Size = UDim2.new(0, 1, 1, -top - footerHeight - Gap)
	divider.Parent = panel

	-- The goals: found, then one swatch per variant, on one line.
	local strip = Instance.new("Frame")
	strip.Name = "Goals"
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.fromOffset(left, top)
	strip.Size = UDim2.new(1, -left, 0, stripHeight)
	strip.Parent = panel
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	stripLayout.Padding = UDim.new(0, if small then 10 else 16)
	stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stripLayout.Parent = strip

	local list = window.list
	local listTop = top + stripHeight + Gap
	list.Position = UDim2.fromOffset(left, listTop)
	list.Size = UDim2.new(1, -left, 1, -listTop - footerHeight - Gap)
	list.ScrollBarThickness = 4
	local oldLayout = list:FindFirstChildOfClass("UIListLayout")
	if oldLayout then
		oldLayout:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(Gap, Gap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	-- Room for the card edges, which are drawn just outside each card.
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 1)
	gridPadding.PaddingLeft = UDim.new(0, 1)
	gridPadding.PaddingBottom = UDim.new(0, 1)
	gridPadding.Parent = list

	-- Square cards that fill the row exactly, however wide the window is.
	local function fitCards()
		local width = list.AbsoluteSize.X - list.ScrollBarThickness - 2
		if width <= 0 then
			return
		end
		local columns = math.max(math.floor((width + Gap) / (CardTarget + Gap)), 3)
		local size = math.floor((width - Gap * (columns - 1)) / columns)
		grid.CellSize = UDim2.fromOffset(size, size)
	end
	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCards)
	fitCards()

	-- The bottom bar has a line above it too.
	local footerLine = Instance.new("Frame")
	footerLine.BorderSizePixel = 0
	footerLine.BackgroundColor3 = Line
	footerLine.AnchorPoint = Vector2.new(0, 1)
	footerLine.Position = UDim2.new(0, 0, 1, -footerHeight - Gap / 2)
	footerLine.Size = UDim2.new(1, 0, 0, 1)
	footerLine.Parent = panel

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

	-- One goal: a small colour swatch and a count.
	local function chip(order: number, text: string, color: Color3, isRainbow: boolean)
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.Size = UDim2.new(0, 0, 1, 0)
		frame.AutomaticSize = Enum.AutomaticSize.X
		frame.BackgroundTransparency = 1
		frame.Parent = strip
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = frame
		local swatch = Instance.new("Frame")
		swatch.BorderSizePixel = 0
		swatch.Size = UDim2.fromOffset(10, 10)
		swatch.BackgroundColor3 = if isRainbow then Color3.new(1, 1, 1) else color
		swatch.Parent = frame
		Ui.corner(swatch, 2)
		if isRainbow then
			rainbow(swatch)
		end
		local label = Instance.new("TextLabel")
		label.LayoutOrder = 2
		label.BackgroundTransparency = 1
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.new(0, 0, 1, 0)
		label.Font = Enum.Font.FredokaOne
		label.TextSize = if small then 13 else 15
		label.TextColor3 = Ui.Colors.muted
		label.Text = text
		label.Parent = frame
	end

	local function clearStrip()
		for _, child in strip:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	-- A square card: its number in the corner, the picture (or a big "?"), the name under it
	-- and a thin bar along the top in its rarity colour once found.
	local function card(
		order: number,
		key: string,
		accent: Color3?,
		look: string?,
		mark: string?,
		caption: string
	): TextButton
		local chosen = selected == key
		local button = Instance.new("TextButton")
		button.Name = key
		button.LayoutOrder = order
		button.Text = ""
		button.AutoButtonColor = true
		button.BackgroundColor3 = if chosen then Color3.fromRGB(40, 32, 54) else CardColor
		button.ClipsDescendants = true
		button.Parent = list
		Ui.corner(button, 6)
		Ui.rim(button, if chosen then Ui.Colors.lamp else Line, if chosen then 2 else 1)
		if accent then
			local bar = Instance.new("Frame")
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = accent
			bar.Size = UDim2.new(1, 0, 0, 3)
			bar.Parent = button
		end
		local number = Ui.text(
			button,
			string.format("%02d", order),
			UDim2.fromOffset(28, 14),
			Ui.Colors.muted,
			false,
			12
		)
		number.Position = UDim2.fromOffset(7, 7)
		number.TextTransparency = 0.35
		if look then
			local picture = Ui.picture(button, UDim2.new(1, -16, 1, -48), look, nil)
			picture.Position = UDim2.fromOffset(8, 12)
		else
			local glyph = Ui.text(button, mark or "?", UDim2.new(1, 0, 1, -48), Unfound, false, 56)
			glyph.Font = Ui.TitleFont
			glyph.Position = UDim2.fromOffset(0, 12)
			glyph.TextXAlignment = Enum.TextXAlignment.Center
			glyph.TextColor3 = if accent then accent else Color3.fromRGB(84, 72, 108)
		end
		local label = Ui.text(
			button,
			caption,
			UDim2.new(1, -12, 0, 15),
			if look or accent then Ui.Colors.text else Ui.Colors.muted,
			true,
			14
		)
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
		row.Position = UDim2.new(0.5, 0, 1, -7)
		row.Size = UDim2.new(1, -8, 0, 8)
		row.Parent = button
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row
		for i, variant in variants do
			local dot = Instance.new("Frame")
			dot.LayoutOrder = i
			dot.Size = UDim2.fromOffset(8, 8)
			local color = VariantColor[variant] or Ui.Colors.muted
			local has = caught[variant] == true
			dot.BackgroundColor3 = if has
				then (if variant == "Rainbow" then Color3.new(1, 1, 1) else color)
				else Unfound
			dot.Parent = row
			Ui.corner(dot, 4)
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
			local button =
				card(i, key, if monster.found then monster.color else nil, monster.look, nil, monster.name)
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
				if effect.found then (if effect.combo then Ui.Colors.equip else Ui.Colors.lamp) else nil,
				nil,
				if effect.found then string.sub(effect.name, 1, 1) else "?",
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
				local button = Instance.new("TextButton")
				button.LayoutOrder = i
				button.Size = UDim2.new(1, 0, 0, if small then 34 else 38)
				button.BackgroundColor3 = Color3.fromRGB(40, 32, 54)
				button.BorderSizePixel = 0
				button.AutoButtonColor = true
				button.Font = Enum.Font.FredokaOne
				button.TextSize = if small then 13 else 15
				button.TextWrapped = true
				button.TextXAlignment = Enum.TextXAlignment.Left
				button.Text = entry.title
				button.Parent = side
				Ui.corner(button, 4)
				local padding = Instance.new("UIPadding")
				padding.PaddingLeft = UDim.new(0, 12)
				padding.PaddingRight = UDim.new(0, 6)
				padding.Parent = button
				-- The open tab gets a lantern-coloured mark down its left edge.
				local mark = Instance.new("Frame")
				mark.Name = "Mark"
				mark.BorderSizePixel = 0
				mark.BackgroundColor3 = Ui.Colors.lamp
				mark.Position = UDim2.new(0, -12, 0, 6)
				mark.Size = UDim2.new(0, 3, 1, -12)
				mark.Parent = button
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
			local open = id == shown
			button.BackgroundTransparency = if open then 0 else 1
			button.TextColor3 = if open then Ui.Colors.text else Ui.Colors.muted
			local mark = button:FindFirstChild("Mark") :: Frame?
			if mark then
				mark.Visible = open
			end
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
