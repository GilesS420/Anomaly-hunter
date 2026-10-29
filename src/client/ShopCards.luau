--!strict
-- The item cards in the Haunted Bakery and the Hunter's Workshop, laid out like the SHOP
-- sketch (2026-10-20):
--   [picture]  Name            [ Rarity ]
--              3 in stock      what it does + the odds
--              $1.2M
-- Tap a card to open it: Buy (or Equip) and Robux buttons appear underneath. The Robux button
-- (ShopCards.robuxAction) buys the item with Robux, even when it's sold out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Robux = require(script.Parent:WaitForChild("Robux"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local ShopCards = {}

export type Action = { text: string, color: Color3, enabled: boolean, run: (() -> ())? }
export type Card = {
	key: string, -- the item id
	name: string,
	look: string?, -- preview model (cakes), see Ui.picture
	icon: string?, -- emoji when there's no model (Workshop items)
	rarity: string,
	rarityColor: Color3,
	effect: string, -- what it does, with the odds
	stock: string, -- "3 in stock", "No stock", "Owned"...
	stockColor: Color3,
	price: number,
	action: Action,
	robux: Action?, -- the Robux button (nil: a grey "Robux" that does nothing)
}

ShopCards.InStock = Color3.fromRGB(140, 230, 140)
ShopCards.NoStock = Color3.fromRGB(230, 110, 110)

-- The Robux button for an item sold through product `product` (a row's `robux`), or nil if it
-- can't be bought with Robux (not set up yet, or a tool you own).
function ShopCards.robuxAction(product: string?, itemId: string): Action?
	if not product then
		return nil
	end
	local price = Robux.price(product)
	if not price then
		return { text = "Robux · soon", color = Ui.Colors.off, enabled = false }
	end
	return {
		text = `{Robux.Symbol} {price}`,
		color = Robux.Color,
		enabled = true,
		run = function()
			Robux.buy("Item", itemId)
		end,
	}
end

local Height = 112 -- a closed card (the window's Scale canvas shrinks it on a phone)
local ActionsHeight = 52 -- the Buy / Robux strip an open card adds
ShopCards.Padding = 12 -- inside a card, all round

local opened: { [ScrollingFrame]: string? } = {} -- the open card per window
local shown: { [ScrollingFrame]: { Card } } = {} -- what each window shows, to redraw on a tap
local headers: { [ScrollingFrame]: ((ScrollingFrame) -> ())? } = {}

-- Sets a window up for cards: wider than the default, a gap between cards, and room round
-- the list so a card's outline isn't cut off at the edges (or under the scrollbar). Without a
-- footer (the shops) the list runs to the bottom of the window.
function ShopCards.prepare(window: Ui.Window, hasFooter: boolean)
	local panel = window.panel
	local limit = panel and panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(760, 620)
	end
	local list = window.list
	if not hasFooter then
		list.Size = UDim2.new(1, 0, 1, -68)
	end
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, 10)
	end
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 3)
	padding.PaddingRight = UDim.new(0, list.ScrollBarThickness + 6)
	padding.PaddingTop = UDim.new(0, 3)
	padding.PaddingBottom = UDim.new(0, 3)
	padding.Parent = list
end

-- The padding inside a card.
function ShopCards.pad(card: GuiObject)
	local pad = UDim.new(0, ShopCards.Padding)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = pad
	padding.PaddingRight = pad
	padding.PaddingTop = pad
	padding.PaddingBottom = pad
	padding.Parent = card
end

-- A small rounded tag in the rarity's colour.
function ShopCards.pill(parent: Instance, text: string, color: Color3, size: UDim2): Frame
	local pill = Instance.new("Frame")
	pill.Size = size
	local h, s, v = color:ToHSV()
	pill.BackgroundColor3 = Color3.fromHSV(h, s, v * 0.35)
	pill.Parent = parent
	Ui.corner(pill, 6)
	Ui.rim(pill, color, 2)
	local label = Ui.text(pill, text, UDim2.fromScale(1, 1), color, true, 16)
	label.TextXAlignment = Enum.TextXAlignment.Center
	return pill
end

-- The square on the left of a card with the item's picture, rimmed in its rarity colour.
function ShopCards.pictureBox(parent: Instance, side: number, color: Color3, look: string?, icon: string?)
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(side, side)
	box.BackgroundColor3 = Color3.fromRGB(14, 11, 20)
	box.Parent = parent
	Ui.corner(box, 8)
	Ui.rim(box, color, 2)
	Ui.picture(box, UDim2.fromScale(1, 1), look, icon)
	return box
end

local function draw(list: ScrollingFrame, order: number, card: Card)
	local isOpen = opened[list] == card.key
	local inner = Height - 2 * ShopCards.Padding

	local row = Instance.new("TextButton")
	row.Name = card.key
	row.LayoutOrder = order
	row.Text = ""
	row.AutoButtonColor = false
	row.Size = UDim2.new(1, 0, 0, Height + (if isOpen then ActionsHeight else 0))
	row.BackgroundColor3 = Ui.Colors.row
	row.Parent = list
	Ui.corner(row, 10)
	Ui.rim(row, if isOpen then Ui.Colors.lamp else Color3.fromRGB(58, 48, 78), if isOpen then 2 else 1)
	ShopCards.pad(row)

	ShopCards.pictureBox(row, inner, card.rarityColor, card.look, card.icon)
	local left = inner + 16

	-- Name, stock and price.
	local middle = Instance.new("Frame")
	middle.BackgroundTransparency = 1
	middle.Position = UDim2.fromOffset(left, 0)
	middle.Size = UDim2.new(0.55, -left, 0, inner)
	middle.Parent = row
	Ui.text(middle, card.name, UDim2.new(1, 0, 0.3, 0), Ui.Colors.text, true, 22)
	local stock = Ui.text(middle, card.stock, UDim2.new(1, 0, 0.22, 0), card.stockColor, false, 16)
	stock.Position = UDim2.fromScale(0, 0.32)
	local priceText = if card.price > 0 then Format.money(card.price) else "Free"
	local price = Ui.text(middle, priceText, UDim2.new(1, 0, 0.4, 0), Ui.Colors.money, true, 28)
	price.Position = UDim2.fromScale(0, 0.58)

	-- Rarity and what it does.
	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Size = UDim2.new(0.45, -12, 0, inner)
	right.Parent = row
	ShopCards.pill(right, card.rarity, card.rarityColor, UDim2.new(0.6, 0, 0, 26))
	local effect = Ui.text(right, card.effect, UDim2.new(1, 0, 1, -34), Ui.Colors.muted, false, 15)
	effect.Position = UDim2.fromOffset(0, 34)
	effect.TextWrapped = true
	effect.TextYAlignment = Enum.TextYAlignment.Top

	if isOpen then
		local actions = Instance.new("Frame")
		actions.BackgroundTransparency = 1
		actions.Position = UDim2.fromOffset(left, inner + 12)
		actions.Size = UDim2.new(1, -left, 0, ActionsHeight - 12)
		actions.Parent = row
		local action = card.action
		local main = Ui.button(actions, action.text, action.color, UDim2.new(0.5, -6, 1, 0))
		main.AutoButtonColor = action.enabled
		local run = action.run
		if action.enabled and run then
			main.Activated:Connect(run)
		end
		local paid: Action = card.robux or { text = "Robux", color = Ui.Colors.off, enabled = false }
		local robux = Ui.button(actions, paid.text, paid.color, UDim2.new(0.5, -6, 1, 0))
		robux.AnchorPoint = Vector2.new(1, 0)
		robux.Position = UDim2.fromScale(1, 0)
		robux.AutoButtonColor = paid.enabled
		local pay = paid.run
		if paid.enabled and pay then
			robux.Activated:Connect(pay)
		else
			robux.TextTransparency = 0.4
		end
	end

	row.Activated:Connect(function()
		opened[list] = if isOpen then nil else card.key
		ShopCards.show(list, shown[list] or {}, headers[list])
	end)
end

-- The row above the Bakery's and Workshop's cards that rerolls their stock for Robux, for this
-- player only until the next restock.
function ShopCards.rerollRow(list: ScrollingFrame)
	local _, actions = Ui.row(
		list,
		0,
		"Reroll the stock",
		Ui.Colors.lamp,
		"New Bakery and Workshop stock, just for you, until the restock"
	)
	local price = Robux.price("ShopReroll")
	local button = Ui.button(
		actions,
		Robux.label("ShopReroll"),
		if price then Robux.Color else Ui.Colors.off,
		UDim2.fromScale(1, 1)
	)
	button.AutoButtonColor = price ~= nil
	if price then
		button.Activated:Connect(function()
			Robux.buy("ShopReroll")
		end)
	end
end

-- Draws the cards in a window's list. The open card stays open across redraws (a buy, the
-- countdown's refresh) while that item is still listed. `header` draws anything that goes
-- above the cards (LayoutOrder 0), like the Shop Reroll row.
function ShopCards.show(list: ScrollingFrame, cards: { Card }, header: ((ScrollingFrame) -> ())?)
	shown[list] = cards
	headers[list] = header
	local keep = false
	for _, card in cards do
		keep = keep or card.key == opened[list]
	end
	if not keep then
		opened[list] = nil
	end
	Ui.clear(list)
	if header then
		header(list)
	end
	for i, card in cards do
		draw(list, i, card)
	end
end

return ShopCards
