--!strict
-- The Collector's sell window. Opens when you use the prompt at the Collector; lists every
-- monster in your Backpack (not the ones roaming the mansion), most valuable first, laid out like the SELL sketch (2026-10-20):
--   [picture]  Name     Effects:  [ Vampire, Slimed ]   [ Sell ]
--              $1.2M · 54 kg
-- and a Sell All button that stays at the bottom while the list scrolls. Legendary and rarer
-- monsters, and Sell all, need a second tap so nothing valuable goes by accident.
-- The server works out every price and does the selling (server/Services/CollectorService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local ShopCards = require(script.Parent.Parent:WaitForChild("ShopCards"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local CollectorController = {}

type Row = {
	uid: string,
	name: string,
	details: string,
	kind: string,
	effects: { string },
	weight: string?,
	look: string,
	color: Color3,
	price: number,
	confirm: boolean,
	locked: boolean,
}
type Offer = { monsters: { Row }, total: number }

local small = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local Height = if small then 96 else 112
local SellWidth = if small then 84 else 120

-- One monster: picture, name, kind, price and weight, its effects in a box, and Sell.
local function card(list: ScrollingFrame, order: number, monster: Row, sell: () -> ())
	local inner = Height - 2 * ShopCards.Padding
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, Height)
	row.BackgroundColor3 = Ui.Colors.row
	row.Parent = list
	Ui.corner(row, 10)
	Ui.rim(row, Color3.fromRGB(58, 48, 78), 1)
	ShopCards.pad(row)

	ShopCards.pictureBox(row, inner, monster.color, monster.look)
	local left = inner + 16

	local middle = Instance.new("Frame")
	middle.BackgroundTransparency = 1
	middle.Position = UDim2.fromOffset(left, 0)
	middle.Size = UDim2.new(0.5, -left, 1, 0)
	middle.Parent = row
	Ui.text(middle, monster.name, UDim2.fromScale(1, 0.28), monster.color, true, 22)
	local kind = Ui.text(middle, monster.kind, UDim2.fromScale(1, 0.2), Ui.Colors.muted, false, 15)
	kind.Position = UDim2.fromScale(0, 0.3)
	local price =
		Ui.text(middle, Format.money(monster.price), UDim2.fromScale(1, 0.3), Ui.Colors.money, true, 26)
	price.Position = UDim2.fromScale(0, 0.5)
	local weight = Ui.text(middle, monster.weight or "", UDim2.fromScale(1, 0.2), Ui.Colors.muted, false, 15)
	weight.Position = UDim2.fromScale(0, 0.8)

	-- Effects in a box, like the sketch.
	local effects = Instance.new("Frame")
	effects.BackgroundTransparency = 1
	effects.Position = UDim2.fromScale(0.5, 0)
	effects.Size = UDim2.new(0.5, -SellWidth - 16, 1, 0)
	effects.Parent = row
	Ui.text(effects, "Effects:", UDim2.new(1, 0, 0, 18), Ui.Colors.muted, true, 15)
	local box = Instance.new("Frame")
	box.Position = UDim2.fromOffset(0, 22)
	box.Size = UDim2.new(1, 0, 1, -22)
	box.BackgroundColor3 = Color3.fromRGB(14, 11, 20)
	box.Parent = effects
	Ui.corner(box, 6)
	Ui.rim(box, Color3.fromRGB(58, 48, 78), 1)
	local boxPadding = Instance.new("UIPadding")
	boxPadding.PaddingLeft = UDim.new(0, 8)
	boxPadding.PaddingRight = UDim.new(0, 8)
	boxPadding.PaddingTop = UDim.new(0, 6)
	boxPadding.PaddingBottom = UDim.new(0, 6)
	boxPadding.Parent = box
	local none = #monster.effects == 0
	local names = if none then "None" else table.concat(monster.effects, ", ")
	local text = Ui.text(
		box,
		names,
		UDim2.fromScale(1, 1),
		if none then Ui.Colors.muted else Ui.Colors.text,
		false,
		15
	)
	text.TextWrapped = true
	text.TextYAlignment = Enum.TextYAlignment.Top

	local button = Ui.button(
		row,
		if monster.locked then "♥ Kept" else "Sell",
		if monster.locked then Ui.Colors.off else Ui.Colors.sell,
		UDim2.fromOffset(SellWidth, 44)
	)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.fromScale(1, 0.5)
	if monster.locked then
		-- Hearted in the Backpack: un-heart it there to sell it.
		button.AutoButtonColor = false
		row.BackgroundTransparency = 0.4
	elseif monster.confirm then
		Ui.confirmButton(button, "Sure?", sell)
	else
		button.Activated:Connect(sell)
	end
end

function CollectorController.start()
	local remotes = ReplicatedStorage:WaitForChild("CollectorRemotes")
	local Open = remotes:WaitForChild("Open") :: RemoteEvent
	local GetList = remotes:WaitForChild("GetList") :: RemoteFunction
	local Sell = remotes:WaitForChild("Sell") :: RemoteFunction

	local window = Ui.window("CollectorUi", "The Collector")
	ShopCards.prepare(window, true)
	local selling = false
	local render: (offer: Offer?) -> ()

	local function sell(uids: { string })
		if selling then
			return
		end
		selling = true
		local ok, result = pcall(Sell.InvokeServer, Sell, uids)
		selling = false
		if ok and typeof(result) == "table" then
			render(result.offer)
		end
	end

	function render(offer: Offer?)
		Ui.clear(window.list)
		for _, child in window.footer:GetChildren() do
			child:Destroy()
		end
		if not offer then
			window.status.Text = "Your save is still loading..."
			return
		end
		local uids = {}
		for _, monster in offer.monsters do
			if not monster.locked then
				table.insert(uids, monster.uid)
			end
		end
		local count = #uids
		if #offer.monsters == 0 then
			window.status.Text =
				"Your Backpack has no monsters. Press E next to one in your mansion to pick it up."
			return
		end
		window.status.Text = if count == 0
			then "Every monster here is hearted (♥ Kept). Un-heart one in your Backpack to sell it."
			else `{count} to sell · worth {Format.money(offer.total)} · most valuable first`

		for i, monster in offer.monsters do
			local uid = monster.uid
			card(window.list, i, monster, function()
				sell({ uid })
			end)
		end

		if count == 0 then
			return
		end
		local all = Ui.button(
			window.footer,
			`Sell All · {count} for {Format.money(offer.total)}`,
			Ui.Colors.sell,
			UDim2.fromScale(1, 1)
		)
		Ui.confirmButton(all, `Sell all {count}? Tap again`, function()
			sell(uids)
		end)
	end

	Open.OnClientEvent:Connect(function(counter: unknown)
		if typeof(counter) ~= "Vector3" then
			return
		end
		window.status.Text = "Loading..."
		window.open(counter)
		local ok, offer = pcall(GetList.InvokeServer, GetList)
		if window.isOpen() then
			render(if ok then offer else nil)
		end
	end)
end

return CollectorController
