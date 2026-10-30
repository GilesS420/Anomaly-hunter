--!strict
-- Trading and gifting monsters (server/Services/TradeService decides everything).
--   The booth   "I want to trade!" at the Trading Booth lists the other players at the booth;
--               pick one and they get a request card.
--   The trade   both sides on top: every monster put in, big, with its name and worth, and
--               each side's total. Your Backpack below: tap a monster to put it in or take it
--               back out. Ready (both) starts a short countdown, then the swap. Any change
--               un-readies both. Closing the window or walking away cancels it.
--   Gifts       while you hold a monster from your Backpack, every other player gets a
--               "Give" prompt: hold E (or hold the prompt on a phone) next to them. They get
--               a card with the monster on it to accept or say no.
-- Request and gift cards stack at the bottom of the screen, one at a time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local TradingConfig = require(Shared:WaitForChild("Config"):WaitForChild("Trading"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))
local ShopCards = require(script.Parent.Parent:WaitForChild("ShopCards"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local ToastController = require(script.Parent:WaitForChild("ToastController"))

local TradeController = {}

local player = Players.LocalPlayer

type Row = {
	uid: string,
	name: string,
	kind: string,
	weight: string,
	effects: { string },
	value: number,
	look: string,
	color: Color3,
	locked: boolean,
}
type State = {
	partner: string,
	mine: { Row },
	theirs: { Row },
	myTotal: number,
	theirTotal: number,
	myReady: boolean,
	theirReady: boolean,
	countdownEnds: number?,
	backpack: { Row },
	version: number,
}
type Invite = { kind: string, from: number, name: string, seconds: number, monster: Row? }
type Result = { ok: boolean, message: string }

-- Pixel sizes for a computer screen; the Scale canvas shrinks them on a phone.
local OfferTile = Vector2.new(124, 168) -- a monster on the table: big picture, name, worth
local PackTile = Vector2.new(100, 136) -- a monster in your Backpack strip
local Ready = Color3.fromRGB(70, 170, 90)
local Waiting = Color3.fromRGB(205, 135, 30)
local Teal = Color3.fromRGB(90, 240, 220) -- your side, like the broker's left eye
local Pink = Color3.fromRGB(255, 120, 200) -- their side

local function invoke(remote: RemoteFunction, ...: any): Result
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if ok and typeof(result) == "table" and typeof(result.message) == "string" then
		return result
	end
	return { ok = false, message = "Couldn't reach the server. Try again." }
end

-- A monster tile: big picture rimmed in its rarity colour, its name, and its worth.
local function tile(parent: Instance, order: number, row: Row, size: Vector2, dim: boolean, badge: string?): TextButton
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Text = ""
	button.AutoButtonColor = true
	button.Size = UDim2.fromOffset(size.X, size.Y)
	button.BackgroundColor3 = Ui.Colors.row
	button.BackgroundTransparency = if dim then 0.55 else 0
	button.Parent = parent
	Ui.corner(button, 10)
	Ui.rim(button, if badge == "✓" then Teal else Color3.fromRGB(58, 48, 78), if badge == "✓" then 2 else 1)
	local side = size.X - 12
	local box = ShopCards.pictureBox(button, side, row.color, row.look)
	box.Position = UDim2.fromOffset(6, 6)
	local name = Ui.text(button, row.name, UDim2.new(1, -8, 0, 22), row.color, true, 18)
	name.Position = UDim2.fromOffset(4, side + 8)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local worth = Ui.text(button, Format.money(row.value), UDim2.new(1, -8, 0, 18), Ui.Colors.money, true, 16)
	worth.Position = UDim2.new(0, 4, 1, -22)
	worth.TextXAlignment = Enum.TextXAlignment.Center
	if badge then
		local mark = Ui.text(button, badge, UDim2.fromOffset(28, 28), if badge == "♥" then Pink else Teal, true, 24)
		mark.AnchorPoint = Vector2.new(1, 0)
		mark.Position = UDim2.new(1, -4, 0, 2)
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.ZIndex = 3
	end
	return button
end

local function grid(parent: Instance, cell: Vector2, horizontal: boolean): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = Ui.Colors.rim
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
	frame.ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y
	frame.Parent = parent
	Ui.corner(frame, 10)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = if horizontal then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	layout.Parent = frame
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(padding :: any)[side] = UDim.new(0, 6)
	end
	padding.Parent = frame
	return frame
end

local function clearTiles(frame: ScrollingFrame)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function TradeController.start()
	local remotes = ReplicatedStorage:WaitForChild("TradeRemotes")
	local Open = remotes:WaitForChild("Open") :: RemoteEvent
	local Nearby = remotes:WaitForChild("Nearby") :: RemoteFunction
	local Request = remotes:WaitForChild("Request") :: RemoteFunction
	local InviteRemote = remotes:WaitForChild("Invite") :: RemoteEvent
	local Answer = remotes:WaitForChild("Answer") :: RemoteFunction
	local Offer = remotes:WaitForChild("Offer") :: RemoteFunction
	local ReadyRemote = remotes:WaitForChild("Ready") :: RemoteFunction
	local Cancel = remotes:WaitForChild("Cancel") :: RemoteEvent
	local StateRemote = remotes:WaitForChild("State") :: RemoteEvent
	local Gift = remotes:WaitForChild("Gift") :: RemoteFunction

	-- Picking who to trade with ---------------------------------------------------------------

	local picker = Ui.window("TradePickUi", "Trading Booth")
	local function fillPicker()
		Ui.clear(picker.list)
		picker.status.Text = "Looking around the booth..."
		local ok, list = pcall(Nearby.InvokeServer, Nearby)
		if not picker.isOpen() then
			return
		end
		local others: { { userId: number, name: string } } = if ok and typeof(list) == "table" then list else {}
		picker.status.Text = if #others == 0
			then "Nobody else is at the booth. Bring a friend over!"
			else "Pick who to trade with. They get a request to accept."
		for i, other in others do
			local _, actions = Ui.row(picker.list, i, other.name, Ui.Colors.text, "At the booth")
			local ask = Ui.button(actions, "Trade", Teal, UDim2.fromScale(1, 0.8))
			ask.AnchorPoint = Vector2.new(0, 0.5)
			ask.Position = UDim2.fromScale(0, 0.5)
			ask.Activated:Connect(function()
				local result = invoke(Request, other.userId)
				picker.status.Text = result.message
			end)
		end
	end
	local refresh = Ui.button(picker.footer, "Look again", Ui.Colors.off, UDim2.fromScale(1, 1))
	refresh.Activated:Connect(fillPicker)

	-- The trade window ------------------------------------------------------------------------

	local window = Ui.window("TradeUi", "Trade")
	local limit = window.panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(900, 660)
	end
	window.list.Visible = false
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 66)
	body.Size = UDim2.new(1, 0, 1, -66 - 60)
	body.Parent = window.panel

	local function side(right: boolean, color: Color3): (TextLabel, TextLabel, ScrollingFrame)
		local column = Instance.new("Frame")
		column.BackgroundTransparency = 1
		column.Position = if right then UDim2.new(0.5, 5, 0, 0) else UDim2.new()
		column.Size = UDim2.new(0.5, -5, 0.6, -4)
		column.Parent = body
		local heading = Ui.text(column, "", UDim2.new(1, 0, 0, 24), color, true, 22)
		local total = Ui.text(column, "", UDim2.new(1, 0, 0, 20), Ui.Colors.money, true, 18)
		total.Position = UDim2.fromOffset(0, 24)
		local offers = grid(column, OfferTile, false)
		offers.Position = UDim2.fromOffset(0, 48)
		offers.Size = UDim2.new(1, 0, 1, -48)
		Ui.rim(offers, color, 2)
		return heading, total, offers
	end
	local myHeading, myTotal, myTable = side(false, Teal)
	local theirHeading, theirTotal, theirTable = side(true, Pink)

	local packLabel = Ui.text(body, "Your Backpack: tap a monster to put it in or take it out", UDim2.new(1, 0, 0, 22), Ui.Colors.muted, false, 17)
	packLabel.Position = UDim2.fromScale(0, 0.6)
	local pack = grid(body, PackTile, true)
	pack.Position = UDim2.new(0, 0, 0.6, 26)
	pack.Size = UDim2.new(1, 0, 0.4, -26)

	local readyButton = Ui.button(window.footer, "Ready", Ready, UDim2.new(0.65, -6, 1, 0))
	local cancelButton = Ui.button(window.footer, "Cancel", Ui.Colors.off, UDim2.new(0.35, 0, 1, 0))
	cancelButton.AnchorPoint = Vector2.new(1, 0)
	cancelButton.Position = UDim2.fromScale(1, 0)

	local state: State? = nil
	local closedByServer = false
	local busy = false
	local note: string? = nil -- a message to show instead of the usual status line

	local function statusLine(s: State): string
		local ends = s.countdownEnds
		if ends then
			return `Both ready! Swapping in {math.max(0, math.ceil(ends - workspace:GetServerTimeNow()))}...`
		end
		if note then
			return note
		end
		if s.myReady and not s.theirReady then
			return `Waiting for {s.partner} to press Ready...`
		elseif s.theirReady and not s.myReady then
			return `{s.partner} is ready. Check their side, then press Ready.`
		end
		return "Put monsters in, check what they offer, then both press Ready."
	end

	local function sendOffer(uids: { string })
		if busy then
			return
		end
		busy = true
		local result = invoke(Offer, uids)
		busy = false
		note = if result.ok then nil else result.message
		if state then
			window.status.Text = statusLine(state)
		end
	end

	local function render()
		local s = state
		if not s then
			return
		end
		window.title.Text = `Trade with {s.partner}`
		window.status.Text = statusLine(s)
		myHeading.Text = if s.myReady then "You give  ✓ Ready" else "You give"
		theirHeading.Text = if s.theirReady then `{s.partner} gives  ✓ Ready` else `{s.partner} gives`
		myTotal.Text = `Total {Format.money(s.myTotal)} · {#s.mine} monster{if #s.mine == 1 then "" else "s"}`
		theirTotal.Text = `Total {Format.money(s.theirTotal)} · {#s.theirs} monster{if #s.theirs == 1 then "" else "s"}`

		local inTrade: { [string]: boolean } = {}
		local uids: { string } = {}
		for _, row in s.mine do
			inTrade[row.uid] = true
			table.insert(uids, row.uid)
		end

		clearTiles(myTable)
		for i, row in s.mine do
			tile(myTable, i, row, OfferTile, false).Activated:Connect(function()
				local without = {}
				for _, uid in uids do
					if uid ~= row.uid then
						table.insert(without, uid)
					end
				end
				sendOffer(without)
			end)
		end
		clearTiles(theirTable)
		for i, row in s.theirs do
			local button = tile(theirTable, i, row, OfferTile, false)
			button.AutoButtonColor = false
		end
		if #s.theirs == 0 then
			local empty = Ui.text(theirTable, "Nothing yet", UDim2.fromOffset(OfferTile.X, 30), Ui.Colors.muted, false, 16)
			empty.TextXAlignment = Enum.TextXAlignment.Center
		end

		clearTiles(pack)
		if #s.backpack == 0 then
			local empty = Ui.text(pack, "Your Backpack is empty. Pick up monsters in your mansion first.", UDim2.fromOffset(PackTile.X * 3, 30), Ui.Colors.muted, false, 16)
			empty.TextWrapped = true
		end
		for i, row in s.backpack do
			local chosen = inTrade[row.uid] == true
			local badge = if row.locked then "♥" elseif chosen then "✓" else nil
			tile(pack, i, row, PackTile, row.locked or chosen, badge).Activated:Connect(function()
				if row.locked then
					note = "Hearted (♥) monsters can't be traded. Un-heart it in your Backpack first."
					window.status.Text = note
					return
				end
				local changed = table.clone(uids)
				if chosen then
					table.remove(changed, table.find(changed, row.uid) :: number)
				else
					table.insert(changed, row.uid)
				end
				sendOffer(changed)
			end)
		end

		readyButton.Text = if s.myReady then "Not ready" else "Ready"
		Ui.paint(readyButton, if s.myReady then Waiting else Ready)
	end

	readyButton.Activated:Connect(function()
		local s = state
		if not s or busy then
			return
		end
		busy = true
		local result = invoke(ReadyRemote, not s.myReady, s.version)
		busy = false
		note = if result.ok then nil else result.message
		if state then
			window.status.Text = statusLine(state)
		end
	end)
	cancelButton.Activated:Connect(function()
		window.close()
	end)

	window.onClose = function()
		if state and not closedByServer then
			Cancel:FireServer()
		end
		state = nil
		closedByServer = false
	end

	-- The countdown ticks down in the status line.
	RunService.Heartbeat:Connect(function()
		local s = state
		if s and s.countdownEnds and window.isOpen() then
			window.status.Text = statusLine(s)
		end
	end)

	StateRemote.OnClientEvent:Connect(function(newState: unknown, message: unknown)
		if typeof(newState) ~= "table" then
			if state then
				closedByServer = true
				window.close()
			end
			if typeof(message) == "string" then
				ToastController.show(message)
			end
			return
		end
		state = newState :: any
		render()
	end)

	Open.OnClientEvent:Connect(function(counter: unknown, mode: unknown)
		if typeof(counter) ~= "Vector3" then
			return
		end
		if mode == "Trade" then
			picker.close()
			note = nil
			window.open(counter)
		else
			picker.open(counter)
			fillPicker()
		end
	end)

	-- Request and gift cards ------------------------------------------------------------------

	local gui = Instance.new("ScreenGui")
	gui.Name = "TradeInvites"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9 -- over the HUD and windows, under the toasts
	local canvas = Scale.canvas(gui)
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -150)
	card.Size = UDim2.fromOffset(460, 150)
	card.BackgroundColor3 = Ui.Colors.panel
	card.Visible = false
	card.Parent = canvas
	Ui.corner(card, 14)
	Ui.rim(card, Pink, 2)
	ShopCards.pad(card)
	gui.Parent = player:WaitForChild("PlayerGui")

	local queue: { Invite } = {}
	local showing: Invite? = nil
	local shownUntil = 0
	local showNext: () -> ()

	local function answer(invite: Invite, accept: boolean)
		if showing ~= invite then
			return
		end
		showing = nil
		card.Visible = false
		task.spawn(function()
			local result = invoke(Answer, invite.from, accept)
			if result.message ~= "" then
				ToastController.show(result.message)
			end
		end)
		showNext()
	end

	function showNext()
		if showing then
			return
		end
		local invite = table.remove(queue, 1)
		if not invite then
			return
		end
		showing = invite
		shownUntil = os.clock() + invite.seconds - 1
		for _, child in card:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local monster = invite.monster
		local left = 0
		if monster then
			ShopCards.pictureBox(card, 126, monster.color, monster.look)
			left = 138
		end
		local text = Instance.new("Frame")
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromOffset(left, 0)
		text.Size = UDim2.new(1, -left, 1, -46)
		text.Parent = card
		if monster then
			Ui.text(text, `{invite.name} wants to give you`, UDim2.new(1, 0, 0, 22), Ui.Colors.muted, false, 18)
			local name = Ui.text(text, monster.name, UDim2.new(1, 0, 0, 28), monster.color, true, 24)
			name.Position = UDim2.fromOffset(0, 22)
			local line = Ui.text(text, `{monster.kind} · {monster.weight} · {Format.money(monster.value)}`, UDim2.new(1, 0, 0, 20), Ui.Colors.money, false, 16)
			line.Position = UDim2.fromOffset(0, 52)
		else
			local who = Ui.text(text, `{invite.name} wants to trade!`, UDim2.new(1, 0, 0, 30), Pink, true, 26)
			who.Font = Ui.TitleFont
			local line = Ui.text(text, "Accept to open the trade window at the Trading Booth.", UDim2.new(1, 0, 0, 40), Ui.Colors.muted, false, 17)
			line.Position = UDim2.fromOffset(0, 34)
			line.TextWrapped = true
		end
		local yes = Ui.button(card, if monster then "Accept gift" else "Trade", Ready, UDim2.new(0.5, -left / 2 - 4, 0, 40))
		yes.AnchorPoint = Vector2.new(0, 1)
		yes.Position = UDim2.new(0, left, 1, 0)
		local no = Ui.button(card, "No thanks", Ui.Colors.off, UDim2.new(0.5, -left / 2 - 4, 0, 40))
		no.AnchorPoint = Vector2.new(1, 1)
		no.Position = UDim2.fromScale(1, 1)
		yes.Activated:Connect(function()
			answer(invite, true)
		end)
		no.Activated:Connect(function()
			answer(invite, false)
		end)
		card.Visible = true
	end

	-- A card nobody answers goes away by itself when its time is up.
	RunService.Heartbeat:Connect(function()
		local invite = showing
		if invite and os.clock() > shownUntil then
			showing = nil
			card.Visible = false
			showNext()
		end
	end)

	InviteRemote.OnClientEvent:Connect(function(invite: unknown)
		if typeof(invite) ~= "table" or typeof((invite :: any).from) ~= "number" then
			return
		end
		local new = invite :: Invite
		-- A newer one from the same player replaces theirs.
		for i = #queue, 1, -1 do
			if queue[i].from == new.from then
				table.remove(queue, i)
			end
		end
		table.insert(queue, new)
		showNext()
	end)

	-- Gift prompts on other players -----------------------------------------------------------

	local prompts: { [Player]: ProximityPrompt } = {}
	local asking = false

	local function heldMonster(): Tool?
		local character = player.Character
		if not character then
			return nil
		end
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and typeof(child:GetAttribute("MonsterUid")) == "string" then
				return child
			end
		end
		return nil
	end

	local function promptFor(other: Player): ProximityPrompt?
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return nil
		end
		local prompt = prompts[other]
		if prompt and prompt.Parent == root then
			return prompt
		end
		if prompt then
			prompt:Destroy()
		end
		local made = Instance.new("ProximityPrompt")
		made.Name = "GiftPrompt"
		made.ActionText = "Give monster"
		made.ObjectText = other.DisplayName
		made.KeyboardKeyCode = Enum.KeyCode.E
		made.HoldDuration = TradingConfig.GiftHoldSeconds
		made.MaxActivationDistance = TradingConfig.GiftReach
		made.RequiresLineOfSight = false
		made.Enabled = false
		made.Triggered:Connect(function()
			local tool = heldMonster()
			local uid = if tool then tool:GetAttribute("MonsterUid") else nil
			if asking or typeof(uid) ~= "string" then
				return
			end
			asking = true
			local result = invoke(Gift, other.UserId, uid)
			asking = false
			ToastController.show(result.message)
		end)
		made.Parent = root
		prompts[other] = made
		return made
	end

	Players.PlayerRemoving:Connect(function(other)
		local prompt = prompts[other]
		if prompt then
			prompt:Destroy()
			prompts[other] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local tool = heldMonster()
			for _, other in Players:GetPlayers() do
				if other ~= player then
					local prompt = promptFor(other)
					if prompt then
						prompt.Enabled = tool ~= nil
						if tool then
							prompt.ActionText = `Give {tool.Name}`
						end
					end
				end
			end
		end
	end)
end

return TradeController
