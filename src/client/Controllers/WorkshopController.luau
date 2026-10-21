--!strict
-- The Hunter's Workshop window. Opens when you use the prompt at the Workshop. One card per
-- item (ShopCards): its icon, stock, price, rarity and what it does; tap a card for its
-- button: Buy, Equip, Using or No stock.
-- A countdown shows when the stock changes; the window refreshes by itself when it does.
-- The server checks every purchase (server/Services/WorkshopService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local ShopCards = require(script.Parent.Parent:WaitForChild("ShopCards"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local WorkshopController = {}

type Row = {
	id: string,
	name: string,
	kind: string,
	price: number,
	description: string,
	rarity: string,
	rarityColor: Color3,
	tool: boolean,
	inStock: boolean,
	owned: boolean,
	equipped: boolean,
	count: number,
	bought: number,
	limit: number,
	look: string?, -- preview model in InventoryPreviews
}
type View = { items: { Row }, secondsLeft: number, money: number }

local function countdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function WorkshopController.start()
	local remotes = ReplicatedStorage:WaitForChild("WorkshopRemotes")
	local Open = remotes:WaitForChild("Open") :: RemoteEvent
	local GetShop = remotes:WaitForChild("GetShop") :: RemoteFunction
	local Buy = remotes:WaitForChild("Buy") :: RemoteFunction
	local Equip = remotes:WaitForChild("Equip") :: RemoteFunction

	local window = Ui.window("WorkshopUi", "Hunter's Workshop")
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

	local function ask(remote: RemoteFunction, itemId: string)
		if waiting then
			return
		end
		waiting = true
		local ok, result = pcall(remote.InvokeServer, remote, itemId)
		waiting = false
		if ok and typeof(result) == "table" and result.view then
			render(result.view)
		end
	end

	function render(view: View?)
		Ui.clear(window.list)
		if not view then
			window.status.Text = "Your save is still loading..."
			return
		end
		restockAt = os.clock() + view.secondsLeft
		money = view.money
		updateStatus()

		local cards: { ShopCards.Card } = {}
		for _, item in view.items do
			local itemId = item.id
			local left = item.limit - item.bought
			local stock, stockColor = `{left} in stock`, ShopCards.InStock
			local action: ShopCards.Action
			if item.tool and item.owned then
				stock = if item.equipped then "Owned · using it" else "Owned"
				action = if item.equipped
					then { text = "Using", color = Ui.Colors.off, enabled = false }
					else {
						text = "Equip",
						color = Ui.Colors.equip,
						enabled = true,
						run = function()
							ask(Equip, itemId)
						end,
					}
			elseif not item.inStock or left <= 0 then
				stock, stockColor = "No stock", ShopCards.NoStock
				action = { text = "No stock", color = Ui.Colors.off, enabled = false }
			else
				-- Too expensive still shows Buy (dimmed); the server says how much is missing.
				action = {
					text = "Buy",
					color = if money >= item.price then Ui.Colors.buy else Ui.Colors.off,
					enabled = true,
					run = function()
						ask(Buy, itemId)
					end,
				}
			end
			if not item.tool and item.count > 0 then
				stock ..= ` · you have {item.count}`
			end
			table.insert(cards, {
				key = item.id,
				name = item.name,
				look = item.look,
				icon = Ui.Icons[item.kind],
				rarity = item.rarity,
				rarityColor = item.rarityColor,
				effect = item.description,
				stock = stock,
				stockColor = stockColor,
				price = item.price,
				action = action,
			})
		end
		ShopCards.show(window.list, cards)
	end

	local function refresh()
		local ok, view = pcall(GetShop.InvokeServer, GetShop)
		if window.isOpen() then
			render(if ok then view else nil)
		end
	end

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

return WorkshopController
