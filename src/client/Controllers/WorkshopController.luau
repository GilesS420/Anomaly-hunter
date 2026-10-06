--!strict
-- The Hunter's Workshop window. Opens when you use the prompt at the Workshop; shows every
-- item with what it does, its price and a button: Buy, Equip, Using, Out of stock or Sold out.
-- A countdown shows when the stock changes; the window refreshes by itself when it does.
-- The server checks every purchase (server/Services/WorkshopService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local WorkshopController = {}

type Row = {
	id: string,
	name: string,
	kind: string,
	price: number,
	description: string,
	tool: boolean,
	inStock: boolean,
	owned: boolean,
	equipped: boolean,
	count: number,
	bought: number,
	limit: number,
}
type View = { items: { Row }, secondsLeft: number, money: number }

local kindColors: { [string]: Color3 } = {
	Vacuum = Color3.fromRGB(120, 200, 255),
	Flashlight = Color3.fromRGB(255, 225, 120),
	Lens = Color3.fromRGB(200, 170, 255),
	Lure = Color3.fromRGB(255, 160, 120),
	Charm = Color3.fromRGB(160, 255, 200),
}

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

		for i, item in view.items do
			local detail = item.description
			if not item.tool and item.count > 0 then
				detail = `You have {item.count} · {detail}`
			end
			local name = if item.price > 0 then `{item.name} · {Format.money(item.price)}` else item.name
			local _, actions = Ui.row(window.list, i, name, kindColors[item.kind] or Ui.Colors.text, detail)
			local size = UDim2.fromScale(1, 1)
			local itemId = item.id

			if item.tool and item.owned then
				if item.equipped and item.kind == "Lens" then
					Ui.button(actions, "Take off", Ui.Colors.equip, size).Activated:Connect(function()
						ask(Equip, itemId)
					end)
				elseif item.equipped then
					local using = Ui.button(actions, "Using", Ui.Colors.off, size)
					using.AutoButtonColor = false
				else
					Ui.button(actions, "Equip", Ui.Colors.equip, size).Activated:Connect(function()
						ask(Equip, itemId)
					end)
				end
			elseif not item.inStock then
				local out = Ui.button(actions, "Out of stock", Ui.Colors.off, size)
				out.AutoButtonColor = false
			elseif not item.tool and item.bought >= item.limit then
				local sold = Ui.button(actions, "Sold out", Ui.Colors.off, size)
				sold.AutoButtonColor = false
			else
				-- Too expensive still shows Buy (dimmed); the server says how much is missing.
				local color = if money >= item.price then Ui.Colors.buy else Ui.Colors.off
				Ui.button(actions, "Buy", color, size).Activated:Connect(function()
					ask(Buy, itemId)
				end)
			end
		end
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
