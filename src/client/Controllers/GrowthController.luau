--!strict
-- The Growth Chamber's window. Opens when you pick "Let's grow a monster!" at the chamber.
--   1. Pick a monster from your Backpack (how many of its 5 goes it has left is shown).
--   2. Pick Gentle, Strong or Reckless: each card shows the odds, what a win and a loss do to
--      its weight, and the fee. Press Grow twice, so nothing goes by accident.
-- The chamber bubbles for a moment before it shows how it went, then you can go again. The
-- server does the growing (server/Services/GrowthService); rules in Shared.Util.Growth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local GrowthConfig = require(Shared:WaitForChild("Config"):WaitForChild("Growth"))
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
type View = { monsters: { Row }, charges: number }

-- Pixel sizes for a computer screen; the window's Scale canvas shrinks them on a phone.
local Height = 112
local ButtonWidth = 140
local Win = Color3.fromRGB(140, 230, 140)
local Lose = Color3.fromRGB(240, 120, 110)
local Grow = Color3.fromRGB(60, 160, 90)
local ModeIcons = { Gentle = "🌱", Strong = "💪", Reckless = "💥" } :: { [string]: string }

type Button = { text: string, color: Color3, enabled: boolean, run: (() -> ())?, confirm: string? }

-- One card: picture (or icon), a title and three lines, and a button.
local function card(
	list: ScrollingFrame,
	order: number,
	title: string,
	color: Color3,
	look: string?,
	icon: string?,
	lines: { { text: string, color: Color3 } },
	button: Button,
	highlight: Color3?
)
	local inner = Height - 2 * ShopCards.Padding
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, Height)
	row.BackgroundColor3 = Ui.Colors.row
	row.Parent = list
	Ui.corner(row, 10)
	Ui.rim(row, highlight or Color3.fromRGB(58, 48, 78), if highlight then 2 else 1)
	ShopCards.pad(row)

	ShopCards.pictureBox(row, inner, color, look, icon)
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

	local b = Ui.button(row, button.text, button.color, UDim2.fromOffset(ButtonWidth, 44))
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.fromScale(1, 0.5)
	b.AutoButtonColor = button.enabled
	local run = button.run
	if button.enabled and run then
		if button.confirm then
			Ui.confirmButton(b, button.confirm, run)
		else
			b.Activated:Connect(run)
		end
	else
		row.BackgroundTransparency = 0.4
	end
end

local function percent(multiplier: number): string
	local change = math.floor((multiplier - 1) * 100 + 0.5)
	return if change >= 0 then `+{change}%` else `{change}%`
end

function GrowthController.start()
	local remotes = ReplicatedStorage:WaitForChild("GrowthRemotes")
	local Open = remotes:WaitForChild("Open") :: RemoteEvent
	local GetList = remotes:WaitForChild("GetList") :: RemoteFunction
	local GrowRemote = remotes:WaitForChild("Grow") :: RemoteFunction

	local window = Ui.window("GrowthUi", "Growth Chamber")
	ShopCards.prepare(window, false)

	local view: View? = nil
	local pickedUid: string? = nil
	local growing = false
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

	local function grow(modeId: string)
		if growing or not pickedUid then
			return
		end
		growing = true
		Ui.clear(window.list)
		window.status.TextColor3 = Ui.Colors.lamp
		window.status.Text = "The chamber bubbles..."
		local started = os.clock()
		local ok, result = pcall(GrowRemote.InvokeServer, GrowRemote, pickedUid, modeId)
		task.wait(math.max(0, GrowthConfig.RevealSeconds - (os.clock() - started)))
		growing = false
		if not window.isOpen() then
			return
		end
		if ok and typeof(result) == "table" then
			view = result.view or view
			render()
			window.status.TextColor3 = if result.won then Win elseif result.ok then Lose else Ui.Colors.muted
			window.status.Text = result.message
		else
			render()
		end
	end

	function render()
		Ui.clear(window.list)
		window.status.TextColor3 = Ui.Colors.muted
		if not view then
			window.status.Text = "Your save is still loading..."
			return
		end
		local total = view.charges
		if #view.monsters == 0 then
			window.status.Text = "Your Backpack has no monsters. Pick some up in your mansion first."
			return
		end

		local picked = byUid(pickedUid)
		if not picked then
			pickedUid = nil
			window.status.Text = `Pick a monster to grow. Each can go in {total} times.`
			for i, monster in view.monsters do
				local left = monster.charges
				card(window.list, i, monster.name, monster.color, monster.look, nil, {
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
		card(window.list, 1, monster.name, monster.color, monster.look, nil, {
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
			window.status.Text = `{monster.name} has been in the chamber {total} times. Pick another.`
			return
		end
		window.status.Text = "Pick how hard to push it. Harder grows more, but fails more."
		for i, option in monster.options do
			local loss = if option.lose >= 1
				then `{100 - option.chance}% · nothing happens`
				else `{100 - option.chance}% · shrinks {percent(option.lose)}`
			card(window.list, i + 1, option.name, Grow, nil, ModeIcons[option.id], {
				{ text = `{option.chance}% · grows {percent(option.win)}`, color = Win },
				{ text = loss, color = Lose },
				{ text = `Fee {Format.money(option.fee)}`, color = Ui.Colors.money },
			}, {
				text = "Grow",
				color = Grow,
				enabled = true,
				confirm = "Sure? Tap again",
				run = function()
					grow(option.id)
				end,
			})
		end
	end

	window.onClose = function()
		pickedUid = nil
	end

	Open.OnClientEvent:Connect(function(counter: unknown)
		if typeof(counter) ~= "Vector3" then
			return
		end
		pickedUid, view = nil, nil
		window.status.TextColor3 = Ui.Colors.muted
		window.status.Text = "Loading..."
		window.open(counter)
		local ok, result = pcall(GetList.InvokeServer, GetList)
		if window.isOpen() then
			view = if ok and typeof(result) == "table" then result else nil
			render()
		end
	end)
end

return GrowthController
