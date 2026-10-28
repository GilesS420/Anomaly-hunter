--!strict
-- The Haunted Bakery window. Opens when you use the prompt at the Bakery. One card per cake
-- (ShopCards): its picture, stock, price, rarity and what each bite can do; tap a card for
-- its Buy button. Bought cakes go into your hotbar, where you hold one in your mansion and click to set it out (CakeService).
-- The stock changes together with the Workshop's and a countdown shows when. The server
-- checks everything (server/Services/BakeryService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local ShopCards = require(script.Parent.Parent:WaitForChild("ShopCards"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local BakeryController = {}

type TreatRow = {
	id: string,
	name: string,
	price: number,
	description: string,
	rarity: string,
	rarityColor: Color3,
	look: string,
	inStock: boolean,
	count: number,
	bought: number,
	limit: number,
}
type View = { treats: { TreatRow }, secondsLeft: number, money: number }

local function countdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function BakeryController.start()
	local remotes = ReplicatedStorage:WaitForChild("BakeryRemotes")
	local Open = remotes:WaitForChild("Open") :: RemoteEvent
	local GetShop = remotes:WaitForChild("GetShop") :: RemoteFunction
	local Buy = remotes:WaitForChild("Buy") :: RemoteFunction

	local window = Ui.window("BakeryUi", "Haunted Bakery")
	ShopCards.prepare(window, false)
	local restockAt = 0 -- os.clock() when the stock changes
	local money = 0
	local waiting = false -- a request is on its way; ignore more taps until it answers
	local generation = 0 -- bumps each time the window opens, so an old countdown loop stops
	local render: (view: View?) -> ()

	local function updateStatus()
		window.status.Text =
			`New stock in {countdown(restockAt - os.clock())} · You have {Format.money(money)}`
	end

	-- One request at a time; shows the view that comes back.
	local function ask(remote: RemoteFunction, ...: any)
		if waiting then
			return
		end
		waiting = true
		local ok, result = pcall(remote.InvokeServer, remote, ...)
		waiting = false
		if ok and typeof(result) == "table" and result.view then
			render(result.view)
		end
	end

	local function showTreats(view: View)
		updateStatus()
		local cards: { ShopCards.Card } = {}
		for _, treat in view.treats do
			local left = treat.limit - treat.bought
			local stock, stockColor = `{left} in stock`, ShopCards.InStock
			local action: ShopCards.Action
			if not treat.inStock or left <= 0 then
				stock, stockColor = "No stock", ShopCards.NoStock
				action = { text = "No stock", color = Ui.Colors.off, enabled = false }
			else
				-- Too expensive still shows Buy (dimmed); the server says how much is missing.
				local treatId = treat.id
				action = {
					text = "Buy",
					color = if money >= treat.price then Ui.Colors.buy else Ui.Colors.off,
					enabled = true,
					run = function()
						ask(Buy, treatId)
					end,
				}
			end
			if treat.count > 0 then
				stock ..= ` · you have {treat.count}`
			end
			table.insert(cards, {
				key = treat.id,
				name = treat.name,
				look = treat.look,
				rarity = treat.rarity,
				rarityColor = treat.rarityColor,
				-- "Each bite" on its own line, under the reach.
				effect = (string.gsub(treat.description, " · Each bite: ", "\nEach bite: ")),
				stock = stock,
				stockColor = stockColor,
				price = treat.price,
				action = action,
			})
		end
		ShopCards.show(window.list, cards)
	end

	function render(view: View?)
		Ui.clear(window.list)
		for _, child in window.footer:GetChildren() do
			child:Destroy()
		end
		if not view then
			window.status.Text = "Your save is still loading..."
			return
		end
		restockAt = os.clock() + view.secondsLeft
		money = view.money
		showTreats(view)
	end

	local function refresh()
		local ok, view = pcall(GetShop.InvokeServer, GetShop)
		if window.isOpen() then
			render(if ok then view else nil)
		end
	end

	-- An admin restock started or ended (server/AdminRestock): show the new stock right away.
	workspace:GetAttributeChangedSignal("ShopRestock"):Connect(function()
		if window.isOpen() then
			refresh()
		end
	end)

	Open.OnClientEvent:Connect(function(counter: unknown)
		if typeof(counter) ~= "Vector3" then
			return
		end
		window.status.Text = "Loading..."
		window.open(counter)
		generation += 1
		local mine = generation
		refresh()
		-- Tick the countdown; fetch the new stock when it runs out.
		task.spawn(function()
			while window.isOpen() and generation == mine do
				task.wait(1)
				if not window.isOpen() or generation ~= mine then
					break
				end
				if os.clock() >= restockAt then
					task.wait(1) -- let the server's clock pass the restock too
					refresh()
				else
					updateStatus()
				end
			end
		end)
	end)
end

return BakeryController
