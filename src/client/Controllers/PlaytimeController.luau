--!strict
-- Playtime gifts (server/Services/PlaytimeService, numbers in Config/Playtime): the HUD's gift
-- button shows the time to the next gift and a red dot when one is waiting; it opens a small
-- window with one row per gift (picture, what it is, when) and a Claim button once it's due.
-- Flat and with as little text as possible (Giles 2026-11-05).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Icons = require(script.Parent.Parent:WaitForChild("Icons"))
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local PlaytimeController = {}

type Gift = {
	minutes: number,
	cash: number,
	item: string?,
	itemName: string?,
	kind: string?,
	look: string?,
	ready: boolean,
	claimed: boolean,
}
type View = { seconds: number, resetIn: number, gifts: { Gift } }
type Result = { ok: boolean, message: string, view: View? }

local RowHeight = 72
local TileSize = 56
local Gold = Color3.fromRGB(255, 211, 107)

-- 3:05, 12:00.
local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function rewardText(gift: Gift): string
	local parts: { string } = {}
	if gift.itemName then
		table.insert(parts, gift.itemName)
	end
	if gift.cash > 0 then
		table.insert(parts, Format.money(gift.cash))
	end
	return table.concat(parts, " + ")
end

function PlaytimeController.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("PlaytimeRemotes")
	local GetView = remotes:WaitForChild("GetView") :: RemoteFunction
	local Claim = remotes:WaitForChild("Claim") :: RemoteFunction

	local window = Ui.window("PlaytimeUi", "Playtime Gifts")
	local view: View? = nil
	local busy = false

	local function played(): number
		local seconds = player:GetAttribute("PlaytimeSeconds")
		return if typeof(seconds) == "number" then seconds else (if view then view.seconds else 0)
	end

	local function statusText(): string
		return `Played today: {math.floor(played() / 60)} min`
	end

	local render: () -> ()

	local function claim(index: number)
		if busy then
			return
		end
		busy = true
		local ok, result = pcall(Claim.InvokeServer, Claim, index)
		busy = false
		if ok and typeof(result) == "table" and (result :: Result).view then
			view = (result :: Result).view
		end
		render()
	end

	local function row(order: number, gift: Gift, index: number)
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -8, 0, RowHeight)
		frame.BackgroundColor3 = Ui.Colors.row
		frame.Parent = window.list
		Ui.corner(frame, 6)
		Ui.rim(frame, if gift.ready then Gold else Ui.Style.line, if gift.ready then 2 else 1)

		local box = Instance.new("Frame")
		box.AnchorPoint = Vector2.new(0, 0.5)
		box.Position = UDim2.new(0, 8, 0.5, 0)
		box.Size = UDim2.fromOffset(TileSize, TileSize)
		box.BackgroundColor3 = Ui.Colors.panel
		box.Parent = frame
		Ui.corner(box, 6)
		if gift.look then
			Ui.picture(box, UDim2.fromScale(1, 1), gift.look)
		else
			Icons.draw(box, "MoneyBag", 0.12)
		end

		local name =
			Ui.text(frame, rewardText(gift), UDim2.new(1, -(TileSize + 140), 0, 26), Ui.Colors.text, true, 22)
		name.Position = UDim2.fromOffset(TileSize + 18, 12)
		local time = Ui.text(
			frame,
			`{gift.minutes} min`,
			UDim2.new(1, -(TileSize + 140), 0, 20),
			Ui.Colors.muted,
			false,
			16
		)
		time.Position = UDim2.fromOffset(TileSize + 18, 40)

		local size = UDim2.fromOffset(104, 40)
		if gift.ready then
			local button = Ui.button(frame, "Claim", Ui.Colors.buy, size)
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -10, 0.5, 0)
			button.Activated:Connect(function()
				claim(index)
			end)
		else
			local left = gift.minutes * 60 - played()
			local state = Ui.text(
				frame,
				if gift.claimed then "✓" elseif left > 0 then clock(left) else "",
				size,
				if gift.claimed then Ui.Colors.money else Ui.Colors.muted,
				true,
				22
			)
			state.Name = "State"
			state:SetAttribute("Minutes", if gift.claimed then nil else gift.minutes)
			state.AnchorPoint = Vector2.new(1, 0.5)
			state.Position = UDim2.new(1, -10, 0.5, 0)
			state.TextXAlignment = Enum.TextXAlignment.Center
		end
	end

	render = function()
		Ui.clear(window.list)
		window.status.Text = statusText()
		local current = view
		if not current then
			return
		end
		for index, gift in current.gifts do
			row(index, gift, index)
		end
	end

	local function load()
		local ok, result = pcall(GetView.InvokeServer, GetView)
		if ok and typeof(result) == "table" then
			view = result :: View
		end
	end

	local function toggle()
		if window.isOpen() then
			window.close()
			return
		end
		window.status.Text = "Loading..."
		window.open(nil)
		load()
		if window.isOpen() then
			render()
		end
	end

	local hud =
		player:WaitForChild("PlayerGui"):WaitForChild("HuntUi"):WaitForChild("Canvas"):WaitForChild("Hud")
	local button = hud:WaitForChild("Menu"):WaitForChild("Gifts") :: TextButton
	button.Activated:Connect(toggle)
	Locks.guard(button, "Gifts")

	-- The time to the next gift along the bottom of the button.
	local timer = Ui.text(button, "", UDim2.new(1, -4, 0, 16), Ui.Colors.text, true, 14)
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(0.5, 1)
	timer.Position = UDim2.new(0.5, 0, 1, -2)
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.BackgroundTransparency = 0.2
	timer.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
	timer.ZIndex = 2
	Ui.corner(timer, 4)

	Ui.countBadge(button, "PlaytimeReady") -- how many gifts wait

	-- PlaytimeNext only moves every few seconds on the server; count down between updates.
	local nextAt: number? = nil
	local function readNext()
		local left = player:GetAttribute("PlaytimeNext")
		nextAt = if typeof(left) == "number" then os.clock() + left else nil
	end
	local function showDot()
		if window.isOpen() and not busy then
			load()
			render()
		end
	end
	player:GetAttributeChangedSignal("PlaytimeNext"):Connect(readNext)
	player:GetAttributeChangedSignal("PlaytimeReady"):Connect(showDot)
	readNext()
	showDot()

	task.spawn(function()
		while true do
			local at = nextAt
			timer.Text = if at then clock(at - os.clock()) else ""
			timer.Visible = at ~= nil
			if window.isOpen() then
				window.status.Text = statusText()
				for _, child in window.list:GetDescendants() do
					local minutes = child:GetAttribute("Minutes")
					if child:IsA("TextLabel") and child.Name == "State" and typeof(minutes) == "number" then
						local left = minutes * 60 - played()
						child.Text = if left > 0 then clock(left) else ""
					end
				end
			end
			task.wait(1)
		end
	end)
end

return PlaytimeController
