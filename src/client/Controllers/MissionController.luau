--!strict
-- The Daily Missions window, from the HUD's Missions button (or J on a keyboard). One card per
-- mission (Easy, Medium, Hard): what to do, a progress bar, the reward and its buttons (Claim
-- once it's done; before that Reroll while there's a free reroll left and Skip for Robux),
-- then the bonus chest for claiming all three and a row to reroll every unfinished mission at
-- once for Robux (server/Services/RobuxService). Every card has a picture on the left of what
-- it's about (Giles 2026-11-05), drawn by client/Icons. The status line shows the streak,
-- when new missions come and the rerolls left.
-- A red number on the button counts the rewards waiting (player attribute MissionsReady).
-- Everything comes from the server (MissionRemotes, server/Services/MissionService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Icons = require(script.Parent.Parent:WaitForChild("Icons"))
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Robux = require(script.Parent.Parent:WaitForChild("Robux"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local MissionController = {}

type Card = {
	tier: string,
	kind: string?,
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
local TileSize = 80

-- The picture on each mission card, by its kind (Config/Missions). Giles 2026-11-05: pictures
-- instead of text only.
local KindPictures: { [string]: Icons.Kind } = {
	Catch = "Vacuum",
	Sell = "MoneyBag",
	PlaceCake = "Cake",
	Effect = "Sparkle",
	Combo = "Sparkle",
	Species = "Book",
	Merge = "Merge",
	Grow = "Grow",
	ZoneSet = "Map",
	GoldenGhost = "Ghost",
}

-- A square picture tile on the left of a card, tinted in `color`: a drawn picture, or an
-- image (a product's dashboard picture) when one is given.
local function tile(parent: Frame, color: Color3, kind: Icons.Kind, image: string?)
	local box = Instance.new("Frame")
	box.Name = "Picture"
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.Position = UDim2.fromScale(0, 0.5)
	box.Size = UDim2.fromOffset(TileSize, TileSize)
	local h, s, v = color:ToHSV()
	box.BackgroundColor3 = Color3.fromHSV(h, s * 0.75, v * 0.42)
	box.Parent = parent
	Ui.corner(box, 12)
	if image then
		local picture = Instance.new("ImageLabel")
		picture.BackgroundTransparency = 1
		picture.Size = UDim2.fromScale(1, 1)
		picture.Image = image
		picture.ScaleType = Enum.ScaleType.Crop
		picture.Parent = box
		Ui.corner(picture, 12)
	else
		Icons.draw(box, kind, 0.12)
	end
end

-- The rest of a card, right of its picture tile.
local function body(parent: Frame): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Body"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(TileSize + 12, 0)
	frame.Size = UDim2.new(1, -(TileSize + 12), 1, 0)
	frame.Parent = parent
	return frame
end

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

	-- A card with a picture tile on the left; returns the card and the body to fill.
	local function shell(order: number, height: number, rim: Color3): (Frame, Frame)
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -8, 0, height)
		frame.BackgroundColor3 = Ui.Colors.row
		frame.Parent = window.list
		Ui.corner(frame, 10)
		Ui.rim(frame, rim, 1)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = frame
		return frame, body(frame)
	end

	local function card(order: number, mission: Card, index: number)
		local color = TierColors[mission.tier] or Ui.Colors.muted
		local outer, frame = shell(
			order,
			CardHeight,
			if mission.done and not mission.claimed then color else Ui.Style.line
		)
		tile(outer, color, KindPictures[mission.kind or ""] or "Scroll")

		-- The tier as a small coloured pill.
		local tier =
			Ui.text(frame, string.upper(mission.tier), UDim2.fromOffset(70, 18), Ui.Colors.panel, true, 14)
		tier.BackgroundTransparency = 0
		tier.BackgroundColor3 = color
		tier.TextXAlignment = Enum.TextXAlignment.Center
		Ui.corner(tier, 9)
		local goal = Ui.text(frame, mission.text, UDim2.new(0.68, 0, 0, 40), Ui.Colors.text, true, 20)
		goal.Position = UDim2.fromOffset(0, 21)
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
		local function place(button: TextButton) -- bottom-right corner
			button.AnchorPoint = Vector2.new(1, 1)
			button.Position = UDim2.fromScale(1, 1)
		end
		if mission.claimed or mission.done then
			local button = Ui.button(
				frame,
				if mission.claimed then "Claimed" else "Claim",
				if mission.claimed then Ui.Colors.off else Ui.Colors.buy,
				UDim2.new(0.32, -6, 0, 40)
			)
			place(button)
			if mission.claimed then
				button.AutoButtonColor = false
			else
				button.Activated:Connect(function()
					send(Claim, index)
				end)
			end
			return
		end
		-- Not done yet: Skip for Robux on the right, a free Reroll next to it while one is left.
		local free = view ~= nil and view.rerolls > 0
		local width = if free then UDim2.new(0.16, -6, 0, 40) else UDim2.new(0.32, -6, 0, 40)
		local skipPrice = Robux.price("MissionSkip")
		local skip = Ui.button(
			frame,
			if skipPrice then `Skip {Robux.Symbol} {skipPrice}` else "Skip · soon",
			if skipPrice then Robux.Color else Ui.Colors.off,
			width
		)
		place(skip)
		skip.AutoButtonColor = skipPrice ~= nil
		if skipPrice then
			Ui.confirmButton(skip, "Skip it?", function()
				Robux.buy("MissionSkip", index)
			end)
		end
		if free then
			local reroll = Ui.button(frame, "Reroll", Ui.Colors.equip, width)
			reroll.AnchorPoint = Vector2.new(1, 1)
			reroll.Position = UDim2.new(0.84, 0, 1, 0)
			Ui.confirmButton(reroll, "Swap it?", function()
				send(Reroll, index)
			end)
		end
	end

	-- A smaller card with a picture, a name, a line under it and room for a button on the
	-- right (the bonus chest and Reroll all). Returns the frame to put the button in.
	local function pictureRow(
		order: number,
		color: Color3,
		kind: Icons.Kind,
		image: string?,
		name: string,
		detail: string
	): Frame
		local outer, frame = shell(order, TileSize + 16, Ui.Style.line)
		tile(outer, color, kind, image)
		local title = Ui.text(frame, name, UDim2.new(0.66, -8, 0, 26), color, true, 22)
		title.Position = UDim2.fromOffset(0, 8)
		local line = Ui.text(frame, detail, UDim2.new(0.66, -8, 0, 34), Ui.Colors.muted, false, 16)
		line.Position = UDim2.fromOffset(0, 36)
		line.TextWrapped = true
		line.TextTruncate = Enum.TextTruncate.None
		line.TextYAlignment = Enum.TextYAlignment.Top
		local actions = Instance.new("Frame")
		actions.Name = "Actions"
		actions.AnchorPoint = Vector2.new(1, 0.5)
		actions.Position = UDim2.fromScale(1, 0.5)
		actions.Size = UDim2.new(0.34, 0, 0, 44)
		actions.BackgroundTransparency = 1
		actions.Parent = frame
		return actions
	end

	local function chestRow(order: number, chest: { reward: number, ready: boolean, claimed: boolean })
		local detail = if chest.claimed
			then "Opened. Come back tomorrow!"
			elseif chest.ready then "Ready to open!"
			else "Claim all three missions to open it."
		local name = `Bonus chest: {Format.money(chest.reward)} + a cake`
		local actions = pictureRow(order, Gold, "Chest", nil, name, detail)
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
		-- Reroll every unfinished mission at once for Robux (Giles 2026-10-29).
		local open = false
		for _, mission in current.missions do
			open = open or not (mission.done or mission.claimed)
		end
		if open then
			local actions = pictureRow(
				11,
				Ui.Colors.lamp,
				"Dice",
				Robux.image("MissionReroll"), -- its dashboard picture, if it has one
				"Reroll all missions",
				"Every mission that isn't done yet gets swapped"
			)
			local price = Robux.price("MissionReroll")
			local button = Ui.button(
				actions,
				Robux.label("MissionReroll"),
				if price then Robux.Color else Ui.Colors.off,
				UDim2.fromScale(1, 1)
			)
			button.AutoButtonColor = price ~= nil
			if price then
				button.Activated:Connect(function()
					Robux.buy("MissionReroll")
				end)
			end
		end
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
		-- Drawn before it shows, from what it already has (fetched ahead, see below), so it
		-- opens complete with no "Loading..." and no flicker; the server's latest then only
		-- redraws it if something changed (Giles 2026-11-12).
		if not view then
			load() -- only the very first time, if the early fetch hasn't come back yet
		end
		render()
		window.open(nil)
		local before = view
		load()
		if window.isOpen() and not Ui.same(before, view) then
			render()
		end
	end
	task.spawn(load) -- fetched ahead, so the first open is instant

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

	Ui.countBadge(button, "MissionsReady") -- how many mission rewards wait
end

return MissionController
