--!strict
-- The Growth Chamber's window. Opens when you pick "Let's grow a monster!" at the chamber.
--   1. Pick a monster from your Backpack (how many of its 5 goes it has left is shown).
--   2. Pick Gentle, Strong or Reckless: each card shows the odds as a bar, what a win and a
--      loss do to its weight, and "GROW: $fee" on its button (red when you can't afford it).
--      Press it twice, so nothing goes by accident.
--   3. The monster bubbles in the chamber for about 20 minutes (Config/Growth.BubbleSeconds),
--      with a countdown. You can walk away; it keeps going while you're offline.
--   4. Then the result screen (Giles 2026-10-25): SUCCESS! or FAILED, the monster before and
--      after (size, weight, worth), and Try again / Pick up monster.
-- The server does the growing (server/Services/GrowthService); rules in Shared.Util.Growth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local ShopCards = require(script.Parent.Parent:WaitForChild("ShopCards"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local GrowthController = {}

type Option = { id: string, name: string, chance: number, win: number, lose: number, fee: number }
type Row = {
	uid: string,
	name: string,
	kind: string,
	weight: string,
	look: string,
	color: Color3,
	value: number,
	charges: number,
	options: { Option },
}
type Side = { size: string, weight: string, value: number }
type Chamber = {
	uid: string,
	name: string,
	look: string,
	color: Color3,
	mode: string,
	secondsLeft: number,
	won: boolean?,
	before: Side?,
	after: Side?,
	charges: number?,
}
type View = { monsters: { Row }, charges: number, chamber: Chamber? }

-- Pixel sizes for a computer screen; the window's Scale canvas shrinks them on a phone.
local Height = 112
local ButtonWidth = 140
local GrowWidth = 200
local Win = Color3.fromRGB(140, 230, 140)
local Lose = Color3.fromRGB(240, 120, 110)
local Grow = Color3.fromRGB(60, 160, 90)
local Rim = Color3.fromRGB(58, 48, 78)
local ModeIcons = { Gentle = "🌱", Strong = "💪", Reckless = "💥" } :: { [string]: string }

type Button = { text: string, color: Color3, enabled: boolean, run: (() -> ())?, confirm: string? }

local function makeButton(parent: Instance, button: Button, size: UDim2): TextButton
	local b = Ui.button(parent, button.text, button.color, size)
	b.AutoButtonColor = button.enabled
	local run = button.run
	if button.enabled and run then
		if button.confirm then
			Ui.confirmButton(b, button.confirm, run)
		else
			b.Activated:Connect(run)
		end
	else
		b.TextTransparency = 0.4
	end
	return b
end

local function box(list: ScrollingFrame, order: number, height: number, rim: Color3?): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundColor3 = Ui.Colors.row
	row.Parent = list
	Ui.corner(row, 10)
	Ui.rim(row, rim or Rim, if rim then 2 else 1)
	ShopCards.pad(row)
	return row
end

-- One monster card: picture, name, three lines and a button.
local function card(
	list: ScrollingFrame,
	order: number,
	title: string,
	color: Color3,
	look: string?,
	lines: { { text: string, color: Color3 } },
	button: Button,
	highlight: Color3?
)
	local inner = Height - 2 * ShopCards.Padding
	local row = box(list, order, Height, highlight)
	ShopCards.pictureBox(row, inner, color, look)
	local left = inner + 16
	local middle = Instance.new("Frame")
	middle.BackgroundTransparency = 1
	middle.Position = UDim2.fromOffset(left, 0)
	middle.Size = UDim2.new(1, -left - ButtonWidth - 12, 1, 0)
	middle.Parent = row
	Ui.text(middle, title, UDim2.fromScale(1, 0.3), color, true, 22)
	for i, line in lines do
		local label = Ui.text(middle, line.text, UDim2.fromScale(1, 0.22), line.color, false, 16)
		label.Position = UDim2.fromScale(0, 0.3 + (i - 1) * 0.235)
	end
	local b = makeButton(row, button, UDim2.fromOffset(ButtonWidth, 44))
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.fromScale(1, 0.5)
	if not button.enabled then
		row.BackgroundTransparency = 0.4
	end
end

local function percent(multiplier: number): string
	local change = math.floor((multiplier - 1) * 100 + 0.5)
	return if change >= 0 then `+{change}%` else `{change}%`
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function money(): number
	local stats = Players.LocalPlayer:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Money")
	return if value and value:IsA("NumberValue") then value.Value else math.huge
end

-- One mode: icon, name, the odds as a green/red bar, what a win and a loss do, and
-- "GROW: $fee".
local function modeCard(list: ScrollingFrame, order: number, option: Option, run: () -> ())
	local inner = Height - 2 * ShopCards.Padding
	local row = box(list, order, Height)
	ShopCards.pictureBox(row, inner, Grow, nil, ModeIcons[option.id])
	local left = inner + 16
	local middle = Instance.new("Frame")
	middle.BackgroundTransparency = 1
	middle.Position = UDim2.fromOffset(left, 0)
	middle.Size = UDim2.new(1, -left - GrowWidth - 16, 1, 0)
	middle.Parent = row
	local title = Ui.text(middle, option.name, UDim2.fromScale(1, 0.3), Ui.Colors.lamp, true, 24)
	title.Font = Ui.TitleFont

	-- The odds bar: green for the win share, red for the rest.
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0, 0.34)
	bar.Size = UDim2.new(1, 0, 0, 10)
	bar.BackgroundColor3 = Lose
	bar.BorderSizePixel = 0
	bar.Parent = middle
	Ui.corner(bar, 5)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(option.chance / 100, 1)
	fill.BackgroundColor3 = Win
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Ui.corner(fill, 5)

	local win = Ui.text(
		middle,
		`{option.chance}% · grows {percent(option.win)}`,
		UDim2.fromScale(1, 0.24),
		Win,
		false,
		17
	)
	win.Position = UDim2.fromScale(0, 0.5)
	local loseText = if option.lose >= 1
		then `{100 - option.chance}% · nothing happens`
		else `{100 - option.chance}% · shrinks {percent(option.lose)}`
	local lose = Ui.text(middle, loseText, UDim2.fromScale(1, 0.24), Lose, false, 17)
	lose.Position = UDim2.fromScale(0, 0.76)

	local affordable = money() >= option.fee
	local b = makeButton(row, {
		text = `GROW: {Format.money(option.fee)}`,
		color = if affordable then Grow else Ui.Colors.confirm,
		enabled = true,
		confirm = "Sure? Tap again",
		run = run,
	}, UDim2.fromOffset(GrowWidth, 54))
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.fromScale(1, 0.5)
	local limit = b:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MaxTextSize = 24
	end
end

-- Before or after on the result screen: picture, label, size and weight, worth.
local function side(
	parent: Instance,
	x: number,
	label: string,
	look: string,
	color: Color3,
	s: Side,
	accent: Color3
)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromScale(x, 0)
	frame.Size = UDim2.fromScale(0.42, 1)
	frame.Parent = parent
	local picture = ShopCards.pictureBox(frame, 96, color, look)
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.new(0.5, 0, 0, 22)
	local heading = Ui.text(frame, label, UDim2.new(1, 0, 0, 20), Ui.Colors.muted, true, 18)
	heading.TextXAlignment = Enum.TextXAlignment.Center
	local size = Ui.text(frame, `{s.size} · {s.weight}`, UDim2.new(1, 0, 0, 22), accent, true, 20)
	size.Position = UDim2.fromOffset(0, 124)
	size.TextXAlignment = Enum.TextXAlignment.Center
	local worth = Ui.text(frame, Format.money(s.value), UDim2.new(1, 0, 0, 26), Ui.Colors.money, true, 24)
	worth.Position = UDim2.fromOffset(0, 148)
	worth.TextXAlignment = Enum.TextXAlignment.Center
end

function GrowthController.start()
	local remotes = ReplicatedStorage:WaitForChild("GrowthRemotes")
	local Open = remotes:WaitForChild("Open") :: RemoteEvent
	local GetList = remotes:WaitForChild("GetList") :: RemoteFunction
	local GrowRemote = remotes:WaitForChild("Grow") :: RemoteFunction
	local PickUpRemote = remotes:WaitForChild("PickUp") :: RemoteFunction

	local window = Ui.window("GrowthUi", "Growth Chamber")
	ShopCards.prepare(window, false)

	local view: View? = nil
	local pickedUid: string? = nil
	local working = false
	local countdown: TextLabel? = nil -- the bubbling clock, while it shows
	local endsAt = 0 -- os.clock() the bubbling ends, for the countdown
	local render: () -> ()

	local function byUid(uid: string?): Row?
		local monsters: { Row } = if view then view.monsters else {}
		for _, monster in monsters do
			if monster.uid == uid then
				return monster
			end
		end
		return nil
	end

	local function say(text: string, color: Color3?)
		window.status.TextColor3 = color or Ui.Colors.muted
		window.status.Text = text
	end

	-- Calls the server and shows what came back (the message in red if it didn't work).
	local function call(remote: RemoteFunction, ...: any): boolean
		if working then
			return false
		end
		working = true
		local ok, result = pcall(remote.InvokeServer, remote, ...)
		working = false
		if not window.isOpen() then
			return false
		end
		if not ok or typeof(result) ~= "table" then
			say("Something went wrong. Try again.", Lose)
			return false
		end
		view = result.view or view
		render()
		if not result.ok then
			say(result.message, Lose)
		end
		return result.ok
	end

	local function grow(modeId: string)
		call(GrowRemote, pickedUid, modeId)
	end

	-- The monster bubbling in the chamber, with a countdown.
	local function bubbling(chamber: Chamber)
		local row = box(window.list, 1, 220, Ui.Colors.lamp)
		local picture = ShopCards.pictureBox(row, 110, chamber.color, chamber.look)
		picture.AnchorPoint = Vector2.new(0.5, 0)
		picture.Position = UDim2.fromScale(0.5, 0)
		local name =
			Ui.text(row, `{chamber.name} · {chamber.mode}`, UDim2.new(1, 0, 0, 24), chamber.color, true, 22)
		name.Position = UDim2.fromOffset(0, 116)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local clockLabel = Ui.text(row, clock(chamber.secondsLeft), UDim2.new(1, 0, 0, 44), Win, true, 44)
		clockLabel.Font = Ui.TitleFont
		clockLabel.Position = UDim2.fromOffset(0, 144)
		clockLabel.TextXAlignment = Enum.TextXAlignment.Center
		countdown = clockLabel
		endsAt = os.clock() + chamber.secondsLeft
		say("Bubbling... You can walk away; it keeps going while you're offline.", Ui.Colors.lamp)
	end

	-- SUCCESS! or FAILED, before -> after, Try again and Pick up monster.
	local function result(chamber: Chamber, before: Side, after: Side)
		local won = chamber.won == true
		local accent = if won then Win else Lose
		local titleRow = Instance.new("Frame")
		titleRow.LayoutOrder = 1
		titleRow.BackgroundTransparency = 1
		titleRow.Size = UDim2.new(1, 0, 0, 56)
		titleRow.Parent = window.list
		local title =
			Ui.text(titleRow, if won then "SUCCESS!" else "FAILED", UDim2.fromScale(1, 1), accent, true, 52)
		title.Font = Ui.TitleFont
		title.TextXAlignment = Enum.TextXAlignment.Center

		local compare = box(window.list, 2, 200, accent)
		side(compare, 0, "Before", chamber.look, chamber.color, before, Ui.Colors.text)
		local arrow = Ui.text(compare, "→", UDim2.fromScale(0.16, 1), accent, true, 56)
		arrow.Position = UDim2.fromScale(0.42, 0)
		arrow.TextXAlignment = Enum.TextXAlignment.Center
		side(compare, 0.58, "After", chamber.look, chamber.color, after, accent)

		local buttons = Instance.new("Frame")
		buttons.LayoutOrder = 3
		buttons.BackgroundTransparency = 1
		buttons.Size = UDim2.new(1, 0, 0, 56)
		buttons.Parent = window.list
		local left = chamber.charges or 0
		local uid = chamber.uid
		makeButton(buttons, {
			text = if left > 0 then `Try again ({left} left)` else "No goes left",
			color = if left > 0 then Grow else Ui.Colors.off,
			enabled = left > 0,
			run = function()
				if call(PickUpRemote) then
					pickedUid = uid
					render()
				end
			end,
		}, UDim2.new(0.5, -6, 1, 0))
		local pick = makeButton(buttons, {
			text = "Pick up monster",
			color = Ui.Colors.sell,
			enabled = true,
			run = function()
				if call(PickUpRemote) then
					say(`{chamber.name} is back in your Backpack.`, Win)
				end
			end,
		}, UDim2.new(0.5, -6, 1, 0))
		pick.AnchorPoint = Vector2.new(1, 0)
		pick.Position = UDim2.fromScale(1, 0)
		say(if won then `It worked! {chamber.name} grew.` else `It didn't work this time.`, accent)
	end

	function render()
		Ui.clear(window.list)
		countdown = nil
		say("")
		if not view then
			say("Your save is still loading...")
			return
		end
		local total = view.charges

		local chamber = view.chamber
		if chamber then
			local before, after = chamber.before, chamber.after
			if chamber.secondsLeft > 0 or not before or not after then
				bubbling(chamber)
			else
				result(chamber, before, after)
			end
			return
		end

		if #view.monsters == 0 then
			say("Your Backpack has no monsters. Pick some up in your mansion first.")
			return
		end

		local picked = byUid(pickedUid)
		if not picked then
			pickedUid = nil
			say(`Pick a monster to grow. Each can go in {total} times.`)
			for i, monster in view.monsters do
				local left = monster.charges
				card(window.list, i, monster.name, monster.color, monster.look, {
					{ text = `{monster.kind} · {monster.weight}`, color = Ui.Colors.muted },
					{ text = Format.money(monster.value), color = Ui.Colors.money },
					{
						text = `{left} of {total} goes left`,
						color = if left > 0 then Ui.Colors.muted else Lose,
					},
				}, {
					text = if left > 0 then "Pick" else "Used up",
					color = if left > 0 then Grow else Ui.Colors.off,
					enabled = left > 0,
					run = function()
						pickedUid = monster.uid
						render()
					end,
				})
			end
			return
		end

		local monster: Row = picked
		card(window.list, 1, monster.name, monster.color, monster.look, {
			{ text = `{monster.kind} · {monster.weight}`, color = Ui.Colors.muted },
			{ text = Format.money(monster.value), color = Ui.Colors.money },
			{ text = `{monster.charges} of {total} goes left`, color = Ui.Colors.muted },
		}, {
			text = "Change",
			color = Ui.Colors.off,
			enabled = true,
			run = function()
				pickedUid = nil
				render()
			end,
		}, Ui.Colors.lamp)
		if monster.charges <= 0 then
			say(`{monster.name} has been in the chamber {total} times. Pick another.`, Lose)
			return
		end
		say("How hard do you want to push it? Harder grows more, but fails more.")
		for i, option in monster.options do
			modeCard(window.list, i + 1, option, function()
				grow(option.id)
			end)
		end
	end

	window.onClose = function()
		pickedUid = nil
	end

	local function load()
		local ok, got = pcall(GetList.InvokeServer, GetList)
		if window.isOpen() then
			view = if ok and typeof(got) == "table" then got else nil
			render()
		end
	end

	Open.OnClientEvent:Connect(function(counter: unknown)
		if typeof(counter) ~= "Vector3" then
			return
		end
		pickedUid, view = nil, nil
		say("Loading...")
		window.open(counter)
		load()
	end)

	-- The countdown ticks while it shows; at 0 the result screen loads.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local label = countdown
			if label and label.Parent and window.isOpen() then
				local left = endsAt - os.clock()
				label.Text = clock(left)
				if left <= 0 and not working then
					countdown = nil
					load()
				end
			end
		end
	end)
end

return GrowthController
