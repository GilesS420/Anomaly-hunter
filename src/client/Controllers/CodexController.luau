--!strict
-- The Codex window. Opens from the HUD's Codex button (or C on a keyboard). One tab per zone,
-- one for the Watcher event monsters, one for haunted effects and one for secret combos:
--   Monster pages  every monster of that zone as a card, Common first. Ones you haven't caught
--                  yet are a "?" with no name. Four dots on each card are the catch variants
--                  (Silver, Gold, Shiny, Rainbow): each one lights up once you've caught that
--                  monster in that colour. The strip above the cards counts how many you've
--                  found and how many of each variant, the extra goals for every page, with
--                  the money each goal pays once it's done (a tick once it's paid).
--   Effects        every effect (unfound ones say where they come from, found ones which
--                  combos you've made with them).
--   Combos         the secret combos, kept apart from the effects (Giles 2026-10-24): two
--                  effects on one monster merge into one stronger combo. A made combo shows
--                  its recipe ("Vampire + Batty"); a secret one only says how many of its two
--                  effects you've found, as a clue.
-- The look is a plain field journal: square numbered cards, flat tabs, and the goals as a
-- line of colour swatches rather than glowing pills. Tap a card to see it along the bottom. Everything comes from the server
-- (CodexRemotes.GetView, server/Services/CodexService); the pictures are preview models in
-- PlayerGui.InventoryPreviews.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))
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
type Rewards = { [string]: { amount: number, claimed: boolean } }
type Page = { id: string, title: string, progress: Progress, monsters: { MonsterCard }, rewards: Rewards? }
type EffectCard = {
	id: string,
	name: string,
	multiplier: number,
	found: boolean,
	hint: string,
	combo: boolean,
	recipe: { string }?,
	known: number?,
	usedIn: { string }?,
}
type View = { pages: { Page }, effects: { EffectCard }, effectRewards: Rewards?, variants: { string } }

-- "$250K" for a goal still to do, "✓ paid" once it's paid, "" for no reward.
local function rewardText(rewards: Rewards?, goal: string): string
	local reward = rewards and rewards[goal]
	if not reward or reward.amount <= 0 then
		return ""
	end
	return if reward.claimed then "✓ paid" else Format.money(reward.amount)
end

local EffectsTab = "Effects"
local CombosTab = "Combos"
local ComboColor = Color3.fromRGB(190, 120, 255) -- combos are purple, effects lantern orange

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
	local panel = window.panel
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(780, 540)
	end
	-- A little lower and shorter than other windows, so the messages along the top of the
	-- screen don't sit over the title. A phone needs all the height it has for the cards.
	local function fitPanel()
		local small = Scale.isSmall()
		panel.Position = UDim2.fromScale(0.5, if small then 0.5 else 0.54)
		panel.Size = UDim2.fromScale(0.92, if small then 0.94 else 0.8)
	end
	Scale.changed:Connect(fitPanel)
	fitPanel()
	-- Pixel sizes for a computer screen; the window's Scale canvas shrinks them on a phone.
	local sideWidth = 140
	local stripHeight = 38 -- two lines per goal: the count, then its reward
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

	-- The goals: found, then one per variant, side by side in equal cells so they always fit.
	local strip = Instance.new("Frame")
	strip.Name = "Goals"
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.fromOffset(left, top)
	strip.Size = UDim2.new(1, -left, 0, stripHeight)
	strip.Parent = panel
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	stripLayout.Padding = UDim.new(0, Gap)
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
		-- AbsoluteSize is in screen pixels; the cards are sized inside the Scale canvas.
		local width = list.AbsoluteSize.X / Scale.factor() - list.ScrollBarThickness - 2
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
	-- One goal: a colour swatch and its count on the top line, its reward under it. `cells` is
	-- how many goals share the line, so each gets an equal slice of the width.
	local function chip(
		order: number,
		cells: number,
		text: string,
		reward: string,
		color: Color3,
		isRainbow: boolean
	)
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1 / cells, -Gap * (cells - 1) / cells, 1, 0)
		frame.BackgroundColor3 = CardColor
		frame.Parent = strip
		Ui.corner(frame, 4)
		local swatch = Instance.new("Frame")
		swatch.BorderSizePixel = 0
		swatch.AnchorPoint = Vector2.new(0, 0.5)
		swatch.Position = UDim2.new(0, 6, 0, 10)
		swatch.Size = UDim2.fromOffset(8, 8)
		swatch.BackgroundColor3 = if isRainbow then Color3.new(1, 1, 1) else color
		swatch.Parent = frame
		Ui.corner(swatch, 2)
		if isRainbow then
			rainbow(swatch)
		end
		local count = Ui.text(frame, text, UDim2.new(1, -22, 0, 16), Ui.Colors.text, false, 14)
		count.Position = UDim2.fromOffset(18, 2)
		local paid = string.sub(reward, 1, 1) == "✓"
		local money = Ui.text(
			frame,
			reward,
			UDim2.new(1, -12, 0, 14),
			if paid then Ui.Colors.muted else Ui.Colors.money,
			false,
			13
		)
		money.Position = UDim2.fromOffset(6, 20)
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
		local cells = #variants + 1
		chip(
			1,
			cells,
			`Found {progress.found}/{progress.total}`,
			rewardText(page.rewards, "Found"),
			Ui.Colors.lamp,
			false
		)
		for i, variant in variants do
			chip(
				i + 1,
				cells,
				`{variant} {progress.variants[variant] or 0}/{progress.total}`,
				rewardText(page.rewards, variant),
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

	local function effectsPage(effects: { EffectCard }, rewards: Rewards?)
		local found, total = 0, 0
		for _, effect in effects do
			if not effect.combo then
				total += 1
				found += if effect.found then 1 else 0
			end
		end
		chip(1, 1, `Effects found {found}/{total}`, rewardText(rewards, "Effects"), Ui.Colors.lamp, false)
		window.status.Text =
			"Effects make a monster worth more. Two of the right ones on one monster make a combo."
		local order = 0
		for _, effect in effects do
			if effect.combo then
				continue
			end
			order += 1
			local key = `e:{effect.id}`
			card(
				order,
				key,
				if effect.found then Ui.Colors.lamp else nil,
				nil,
				if effect.found then string.sub(effect.name, 1, 1) else "?",
				if effect.found then effect.name else "???"
			)
			if selected == key then
				pickName.Text = `{if effect.found then effect.name else "???"} · x{effect.multiplier}`
				pickName.TextColor3 = Ui.Colors.lamp
				local usedIn = effect.usedIn or {}
				pickDetails.Text = if #usedIn > 0
					then `{effect.hint}. In your combos: {table.concat(usedIn, ", ")}`
					else effect.hint
			end
		end
	end

	-- The secret combos, apart from the effects: what each one is made of once you've made it,
	-- and a clue (how many of its effects you've found) while it's still secret.
	local function combosPage(effects: { EffectCard }, rewards: Rewards?)
		local made, total = 0, 0
		for _, effect in effects do
			if effect.combo then
				total += 1
				made += if effect.found then 1 else 0
			end
		end
		chip(1, 1, `Combos made {made}/{total}`, rewardText(rewards, "Combos"), ComboColor, false)
		window.status.Text =
			"A combo forms when one monster has both of its effects at once. The two merge into one stronger effect."
		local order = 0
		for _, effect in effects do
			if not effect.combo then
				continue
			end
			order += 1
			local key = `c:{effect.id}`
			local recipe = effect.recipe
			-- The mark shows the recipe's first letters ("V+B"), or "?+?" while it's secret.
			local mark = if recipe and #recipe == 2
				then `{string.sub(recipe[1], 1, 1)}+{string.sub(recipe[2], 1, 1)}`
				else "?+?"
			card(
				order,
				key,
				if effect.found then ComboColor else nil,
				nil,
				mark,
				if effect.found then effect.name else "Secret"
			)
			if selected == key then
				pickName.TextColor3 = ComboColor
				if effect.found and recipe then
					pickName.Text = `{effect.name} · x{effect.multiplier}`
					pickDetails.Text =
						`{recipe[1]} + {recipe[2]} on one monster turns into {effect.name} (x{effect.multiplier})`
				else
					local known = effect.known or 0
					pickName.Text = `Secret combo · x{effect.multiplier}`
					pickDetails.Text = if known >= 2
						then "You've found both of its effects! Get them onto the same monster."
						elseif known == 1 then "Two effects make it. You've found 1 of them so far."
						else "Two effects make it. You haven't found either of them yet."
				end
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
			table.insert(names, { id = CombosTab, title = CombosTab })
			for i, entry in names do
				local button = Instance.new("TextButton")
				button.LayoutOrder = i
				button.Size = UDim2.new(1, 0, 0, 38)
				button.BackgroundColor3 = Color3.fromRGB(40, 32, 54)
				button.BorderSizePixel = 0
				button.AutoButtonColor = true
				button.Font = Enum.Font.FredokaOne
				button.TextScaled = true -- long zone names shrink instead of spilling out
				button.TextWrapped = true
				local fit = Instance.new("UITextSizeConstraint")
				fit.MaxTextSize = 15
				fit.Parent = button
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
			effectsPage(current.effects, current.effectRewards)
			return
		elseif shown == CombosTab then
			combosPage(current.effects, current.effectRewards)
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

	local hud =
		player:WaitForChild("PlayerGui"):WaitForChild("HuntUi"):WaitForChild("Canvas"):WaitForChild("Hud")
	local button = hud:WaitForChild("Codex") :: TextButton
	button.Activated:Connect(toggle)
	Locks.guard(button, "Codex") -- greyed out until the tutorial is done
end

return CodexController
