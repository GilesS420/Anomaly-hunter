--!strict
-- The Daily Missions window, from the HUD's Missions button (or J on a keyboard). One card per
-- mission (Easy, Medium, Hard): what to do, a progress bar, the reward and a button (Claim
-- once it's done, Reroll while there's a free reroll left), then the bonus chest for claiming
-- all three. The status line shows the streak, when new missions come and the rerolls left.
-- A red dot on the button means a reward is waiting (player attribute MissionsReady).
-- Everything comes from the server (MissionRemotes, server/Services/MissionService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local MissionController = {}

type Card = {
	tier: string,
	text: string,
	progress: number,
	target: number,
	money: boolean,
	reward: number,
	done: boolean,
	claimed: boolean,
}
type View = {
	streakDay: number,
	bonus: number,
	secondsLeft: number,
	rerolls: number,
	missions: { Card },
	chest: { reward: number, ready: boolean, claimed: boolean },
}
type Result = { ok: boolean, message: string, view: View? }

local CardHeight = 104
local TierColors: { [string]: Color3 } = {
	Easy = Color3.fromRGB(111, 207, 142),
	Medium = Color3.fromRGB(111, 168, 242),
	Hard = Color3.fromRGB(224, 106, 138),
}
local Gold = Color3.fromRGB(255, 211, 107)

-- 7h 12m, 12m 30s.
local function countdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m {seconds % 60}s`
end

function MissionController.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("MissionRemotes")
	local GetView = remotes:WaitForChild("GetView") :: RemoteFunction
	local Claim = remotes:WaitForChild("Claim") :: RemoteFunction
	local Reroll = remotes:WaitForChild("Reroll") :: RemoteFunction
	local Changed = remotes:WaitForChild("Changed") :: RemoteEvent

	local window = Ui.window("MissionUi", "Daily Missions")
	local view: View? = nil
	local endsAt = 0 -- os.clock() when today's missions end
	local busy = false

	local function statusText(): string
		local current = view
		if not current then
			return "Loading..."
		end
		local streak = `Day {current.streakDay} streak`
		if current.bonus > 0 then
			streak ..= ` (+{math.floor(current.bonus * 100 + 0.5)}%)`
		end
		local rerolls = if current.rerolls == 1 then "1 reroll left" else `{current.rerolls} rerolls left`
		return `{streak}  ·  New missions in {countdown(endsAt - os.clock())}  ·  {rerolls}`
	end

	local render: () -> ()

	local function send(remote: RemoteFunction, index: number)
		if busy then
			return
		end
		busy = true
		local ok, result = pcall(remote.InvokeServer, remote, index)
		busy = false
		if ok and typeof(result) == "table" then
			local answer = result :: Result
			if answer.view then
				view = answer.view
			end
			if not answer.ok then
				window.status.Text = answer.message
				task.delay(2, function()
					if window.isOpen() then
						window.status.Text = statusText()
					end
				end)
			end
		end
		render()
	end

	local function card(order: number, mission: Card, index: number)
		local color = TierColors[mission.tier] or Ui.Colors.muted
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -8, 0, CardHeight)
		frame.BackgroundColor3 = Ui.Colors.row
		frame.Parent = window.list
		Ui.corner(frame, 10)
		Ui.rim(frame, if mission.done and not mission.claimed then color else Color3.fromRGB(58, 48, 78), 1)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 12)
		padding.PaddingRight = UDim.new(0, 10)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = frame

		local tier = Ui.text(frame, string.upper(mission.tier), UDim2.new(0.68, 0, 0, 16), color, true, 15)
		local goal = Ui.text(frame, mission.text, UDim2.new(0.68, 0, 0, 40), Ui.Colors.text, true, 20)
		goal.Position = UDim2.fromOffset(0, 18)
		goal.TextWrapped = true
		goal.TextTruncate = Enum.TextTruncate.None
		goal.TextYAlignment = Enum.TextYAlignment.Top
		tier.Position = UDim2.fromOffset(0, 0)

		-- The bar and the "2 / 4" under it.
		local bar = Instance.new("Frame")
		bar.Position = UDim2.new(0, 0, 1, -24)
		bar.Size = UDim2.new(0.68, -70, 0, 12)
		bar.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
		bar.Parent = frame
		Ui.corner(bar, 6)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(mission.progress / math.max(1, mission.target), 0, 1), 1)
		fill.BackgroundColor3 = color
		fill.Parent = bar
		Ui.corner(fill, 6)
		local shown = if mission.money
			then `{Format.money(mission.progress)} / {Format.money(mission.target)}`
			else `{mission.progress} / {mission.target}`
		local count = Ui.text(frame, shown, UDim2.fromOffset(66, 18), Ui.Colors.muted, false, 15)
		count.AnchorPoint = Vector2.new(0, 0)
		count.Position = UDim2.new(0.68, -64, 1, -27)
		count.TextXAlignment = Enum.TextXAlignment.Right

		-- The reward and the button, on the right.
		local reward =
			Ui.text(frame, Format.money(mission.reward), UDim2.new(0.32, -6, 0, 26), Gold, true, 24)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.Position = UDim2.new(1, 0, 0, 4)
		reward.TextXAlignment = Enum.TextXAlignment.Right
		local label, buttonColor
		if mission.claimed then
			label, buttonColor = "Claimed", Ui.Colors.off
		elseif mission.done then
			label, buttonColor = "Claim", Ui.Colors.buy
		elseif view and view.rerolls > 0 then
			label, buttonColor = "Reroll", Ui.Colors.equip
		end
		if label then
			local button = Ui.button(frame, label, buttonColor, UDim2.new(0.32, -6, 0, 40))
			button.AnchorPoint = Vector2.new(1, 1)
			button.Position = UDim2.fromScale(1, 1)
			if mission.claimed then
				button.AutoButtonColor = false
			elseif mission.done then
				button.Activated:Connect(function()
					send(Claim, index)
				end)
			else
				Ui.confirmButton(button, "Swap it?", function()
					send(Reroll, index)
				end)
			end
		end
	end

	local function chestRow(order: number, chest: { reward: number, ready: boolean, claimed: boolean })
		local detail = if chest.claimed
			then "Opened. Come back tomorrow!"
			elseif chest.ready then "Ready to open!"
			else "Claim all three missions to open it."
		local _, actions =
			Ui.row(window.list, order, `Bonus chest: {Format.money(chest.reward)} + a cake`, Gold, detail)
		if chest.ready then
			local open = Ui.button(actions, "Open", Ui.Colors.buy, UDim2.new(1, 0, 1, 0))
			open.Activated:Connect(function()
				send(Claim, 0)
			end)
		end
	end

	render = function()
		Ui.clear(window.list)
		local current = view
		window.status.Text = statusText()
		if not current then
			return
		end
		for i, mission in current.missions do
			card(i, mission, i)
		end
		chestRow(10, current.chest)
	end

	local function load()
		local ok, result = pcall(GetView.InvokeServer, GetView)
		if ok and typeof(result) == "table" then
			view = result :: View
			endsAt = os.clock() + (result :: View).secondsLeft
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

	Changed.OnClientEvent:Connect(function(latest: View)
		local fresh = view == nil or latest.secondsLeft > (endsAt - os.clock()) + 5 -- a new day
		view = latest
		if fresh then
			endsAt = os.clock() + latest.secondsLeft
		end
		if window.isOpen() then
			render()
		end
	end)

	-- The countdown ticks while the window is open.
	task.spawn(function()
		while true do
			task.wait(1)
			if
				window.isOpen()
				and view
				and not busy
				and string.find(window.status.Text, "streak", 1, true)
			then
				window.status.Text = statusText()
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.J and not Locks.isLocked("Missions") then
			toggle()
		end
	end)

	local hud =
		player:WaitForChild("PlayerGui"):WaitForChild("HuntUi"):WaitForChild("Canvas"):WaitForChild("Hud")
	local button = hud:WaitForChild("Menu"):WaitForChild("Missions") :: TextButton
	button.Activated:Connect(toggle)
	Locks.guard(button, "Missions") -- greyed out until the tutorial is done

	-- The red dot: a reward is waiting.
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -5, 0, 5) -- top-right corner of the square button
	dot.Size = UDim2.fromOffset(16, 16)
	dot.BackgroundColor3 = Color3.fromRGB(230, 50, 60)
	dot.ZIndex = 5
	dot.Parent = button
	Ui.corner(dot, 8)
	Ui.rim(dot, Color3.new(1, 1, 1), 1.5)
	local function showDot()
		local ready = player:GetAttribute("MissionsReady")
		dot.Visible = typeof(ready) == "number" and ready > 0
	end
	player:GetAttributeChangedSignal("MissionsReady"):Connect(showDot)
	showDot()
end

return MissionController
