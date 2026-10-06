--!strict
-- The Collector's sell window. Opens when you use the prompt at the Collector; lists every
-- monster in your mansion with its price (highest first). Sell one, or Sell all. Legendary
-- and rarer monsters, and Sell all, need a second tap so nothing valuable goes by accident.
-- The server works out every price and does the selling (server/Services/CollectorService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local CollectorController = {}

type Row = {
	uid: string,
	name: string,
	details: string,
	color: Color3,
	price: number,
	confirm: boolean,
}
type Offer = { monsters: { Row }, total: number }

function CollectorController.start()
	local remotes = ReplicatedStorage:WaitForChild("CollectorRemotes")
	local Open = remotes:WaitForChild("Open") :: RemoteEvent
	local GetList = remotes:WaitForChild("GetList") :: RemoteFunction
	local Sell = remotes:WaitForChild("Sell") :: RemoteFunction

	local window = Ui.window("CollectorUi", "The Collector")
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
		local count = #offer.monsters
		if count == 0 then
			window.status.Text = "Your mansion is empty. Catch some monsters first!"
			return
		end
		window.status.Text =
			`{count} monster{if count == 1 then "" else "s"} · worth {Format.money(offer.total)}`

		for i, monster in offer.monsters do
			local _, actions = Ui.row(window.list, i, monster.name, monster.color, monster.details)
			local button = Ui.button(
				actions,
				`Sell {Format.money(monster.price)}`,
				Ui.Colors.sell,
				UDim2.fromScale(1, 1)
			)
			local uid = monster.uid
			if monster.confirm then
				Ui.confirmButton(button, "Sure?", function()
					sell({ uid })
				end)
			else
				button.Activated:Connect(function()
					sell({ uid })
				end)
			end
		end

		local all = Ui.button(
			window.footer,
			`Sell all {count} for {Format.money(offer.total)}`,
			Ui.Colors.sell,
			UDim2.fromScale(1, 1)
		)
		local uids = {}
		for _, monster in offer.monsters do
			table.insert(uids, monster.uid)
		end
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
