--!strict
-- The Haunted Bakery window. Opens when you use the prompt at the Bakery. Lists the treats
-- for sale with what each one does, its price and a Buy button; a treat you have also gets a
-- Give button, which shows your monsters (most valuable first) so you can pick who eats it.
-- Feed all at the bottom feeds every monster for free. The stock changes together with the
-- Workshop's and a countdown shows when. The server checks everything
-- (server/Services/BakeryService and CareService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local BakeryController = {}

type TreatRow = {
	id: string,
	name: string,
	price: number,
	description: string,
	inStock: boolean,
	count: number,
	bought: number,
	limit: number,
}
type MonsterRow = {
	uid: string,
	name: string,
	details: string,
	color: Color3,
	hungry: boolean,
	blocked: { [string]: string },
}
type View = { treats: { TreatRow }, monsters: { MonsterRow }, secondsLeft: number, money: number }

local TreatColor = Color3.fromRGB(255, 170, 90)
local HungryColor = Color3.fromRGB(215, 95, 50)
local ConfirmFrom = 1_000_000 -- giving a treat this expensive needs a second tap

local function countdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function BakeryController.start()
	local remotes = ReplicatedStorage:WaitForChild("BakeryRemotes")
	local Open = remotes:WaitForChild("Open") :: RemoteEvent
	local GetShop = remotes:WaitForChild("GetShop") :: RemoteFunction
	local Buy = remotes:WaitForChild("Buy") :: RemoteFunction
	local Give = remotes:WaitForChild("Give") :: RemoteFunction
	local FeedAll = ReplicatedStorage:WaitForChild("CareRemotes"):WaitForChild("FeedAll") :: RemoteFunction

	local window = Ui.window("BakeryUi", "Haunted Bakery")
	local restockAt = 0 -- os.clock() when the stock changes
	local money = 0
	local waiting = false -- a request is on its way; ignore more taps until it answers
	local generation = 0 -- bumps each time the window opens, so an old countdown loop stops
	local picking: string? = nil -- the treat being given: the list shows your monsters instead
	local lastView: View? = nil
	local render: (view: View?) -> ()

	local function updateStatus()
		if not picking then
			window.status.Text =
				`New stock in {countdown(restockAt - os.clock())} · You have {Format.money(money)}`
		end
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

	local function feedAll()
		if waiting then
			return
		end
		waiting = true
		pcall(FeedAll.InvokeServer, FeedAll)
		local ok, view = pcall(GetShop.InvokeServer, GetShop)
		waiting = false
		if ok and window.isOpen() then
			render(view)
		end
	end

	local function showTreats(view: View)
		updateStatus()
		local half = UDim2.fromScale(0.48, 1)
		local full = UDim2.fromScale(1, 1)
		for i, treat in view.treats do
			local detail = treat.description
			if treat.count > 0 then
				detail = `You have {treat.count} · {detail}`
			end
			local name = `{treat.name} · {Format.money(treat.price)}`
			local _, actions = Ui.row(window.list, i, name, TreatColor, detail)
			local size = if treat.count > 0 then half else full
			local treatId = treat.id

			if not treat.inStock then
				Ui.button(actions, "Out of stock", Ui.Colors.off, size).AutoButtonColor = false
			elseif treat.bought >= treat.limit then
				Ui.button(actions, "Sold out", Ui.Colors.off, size).AutoButtonColor = false
			else
				-- Too expensive still shows Buy (dimmed); the server says how much is missing.
				local color = if money >= treat.price then Ui.Colors.buy else Ui.Colors.off
				Ui.button(actions, "Buy", color, size).Activated:Connect(function()
					ask(Buy, treatId)
				end)
			end
			if treat.count > 0 then
				local give = Ui.button(actions, "Give", Ui.Colors.equip, half)
				give.Position = UDim2.fromScale(0.52, 0)
				give.Activated:Connect(function()
					picking = treatId
					render(lastView)
				end)
			end
		end

		local count, hungry = #view.monsters, 0
		for _, monster in view.monsters do
			if monster.hungry then
				hungry += 1
			end
		end
		local text = if count == 0
			then "Feed all · no monsters yet"
			elseif hungry > 0 then `Feed all {count} · {hungry} hungry · free`
			else `Feed all {count} · free`
		local color = if hungry > 0 then HungryColor else Ui.Colors.buy
		Ui.button(window.footer, text, color, full).Activated:Connect(feedAll)
	end

	local function showMonsters(view: View, treat: TreatRow)
		window.status.Text = if #view.monsters == 0
			then "Your mansion is empty. Catch some monsters first!"
			else `Who gets the {treat.name}? You have {treat.count}.`
		local full = UDim2.fromScale(1, 1)
		for i, monster in view.monsters do
			local _, actions = Ui.row(window.list, i, monster.name, monster.color, monster.details)
			local reason = monster.blocked[treat.id]
			if reason then
				Ui.button(actions, reason, Ui.Colors.off, full).AutoButtonColor = false
				continue
			end
			local button = Ui.button(actions, "Give", Ui.Colors.buy, full)
			local treatId, uid = treat.id, monster.uid
			local function give()
				ask(Give, treatId, uid)
			end
			if treat.price >= ConfirmFrom then
				Ui.confirmButton(button, "Sure?", give)
			else
				button.Activated:Connect(give)
			end
		end
		Ui.button(window.footer, "Back to the treats", Ui.Colors.off, full).Activated:Connect(function()
			picking = nil
			render(lastView)
		end)
	end

	function render(view: View?)
		Ui.clear(window.list)
		for _, child in window.footer:GetChildren() do
			child:Destroy()
		end
		lastView = view
		if not view then
			window.status.Text = "Your save is still loading..."
			return
		end
		restockAt = os.clock() + view.secondsLeft
		money = view.money

		-- Stay on the monster list while you still have that treat (to give the next one).
		local treat: TreatRow? = nil
		for _, row in view.treats do
			if row.id == picking and row.count > 0 then
				treat = row
			end
		end
		if treat then
			showMonsters(view, treat)
		else
			picking = nil
			showTreats(view)
		end
	end

	local function refresh()
		local ok, view = pcall(GetShop.InvokeServer, GetShop)
		if window.isOpen() then
			render(if ok then view else nil)
		end
	end

	window.onClose = function()
		picking = nil
	end

	Open.OnClientEvent:Connect(function(counter: unknown)
		if typeof(counter) ~= "Vector3" then
			return
		end
		picking = nil
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
