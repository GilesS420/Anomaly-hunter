--!strict
-- The Variant Machine's window, the Merger's second choice ("Try the Variant Machine").
-- Two steps:
--   1. Pick a monster from your Backpack. Ones with no effects, or already Rainbow, can't go in.
--   2. See the odds (rows it can't win are greyed out: its own variant and lower ones), the
--      fee, and press Pull (twice, so nothing goes by accident).
-- The machine whirs for a moment, then shows what it ate and what came out. The monster stays
-- picked so you can pull again. The server does the pull (server/Services/MergerService);
-- the rules are in Shared.Util.VariantMachine, the odds in Shared.Config.VariantMachine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local VariantMachine = require(Shared:WaitForChild("Util"):WaitForChild("VariantMachine"))
local MachineConfig = require(Shared:WaitForChild("Config"):WaitForChild("VariantMachine"))
local ShopCards = require(script.Parent.Parent:WaitForChild("ShopCards"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local VariantController = {}

type Row = {
	uid: string,
	monsterId: string,
	name: string,
	kind: string,
	effects: { string },
	weight: string,
	look: string,
	color: Color3,
	value: number,
	variant: string?,
	pullProblem: string?,
	pullFee: number,
}
type View = { monsters: { Row } }

-- Pixel sizes for a computer screen; the window's Scale canvas shrinks them on a phone.
local Height = 112
local ButtonWidth = 140
local Win = Color3.fromRGB(140, 230, 140)
local Lose = Color3.fromRGB(240, 120, 110)
local Pull = Color3.fromRGB(120, 70, 190)
local VariantColors: { [string]: Color3 } = {
	Silver = Color3.fromRGB(205, 210, 225),
	Gold = Color3.fromRGB(255, 205, 70),
	Shiny = Color3.fromRGB(120, 230, 255),
	Rainbow = Color3.fromRGB(255, 120, 220),
}

type Button = { text: string, color: Color3, enabled: boolean, run: (() -> ())? }

-- One monster: picture, name, kind and weight, value, its effects, and a button.
local function card(
	list: ScrollingFrame,
	order: number,
	monster: Row,
	title: string,
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

	ShopCards.pictureBox(row, inner, monster.color, monster.look)
	local left = inner + 16
	local middle = Instance.new("Frame")
	middle.BackgroundTransparency = 1
	middle.Position = UDim2.fromOffset(left, 0)
	middle.Size = UDim2.new(1, -left - ButtonWidth - 12, 1, 0)
	middle.Parent = row
	Ui.text(middle, title, UDim2.fromScale(1, 0.3), monster.color, true, 22)
	local effects = if #monster.effects == 0 then "No effects" else table.concat(monster.effects, ", ")
	local lines = { `{monster.kind} · {monster.weight}`, Format.money(monster.value), effects }
	for i, line in lines do
		local label = Ui.text(
			middle,
			line,
			UDim2.fromScale(1, 0.22),
			if i == 2 then Ui.Colors.money else Ui.Colors.muted,
			i == 2,
			if i == 2 then 20 else 15
		)
		label.Position = UDim2.fromScale(0, 0.3 + (i - 1) * 0.235)
	end

	local b = Ui.button(row, button.text, button.color, UDim2.fromOffset(ButtonWidth, 44))
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.fromScale(1, 0.5)
	b.AutoButtonColor = button.enabled
	local run = button.run
	if button.enabled and run then
		b.Activated:Connect(run)
	else
		row.BackgroundTransparency = 0.4
	end
end

-- One line of the odds table: the variant, its chance, and whether this monster can win it.
local function oddsRow(
	list: ScrollingFrame,
	order: number,
	name: string,
	color: Color3,
	detail: string,
	chance: number,
	dim: boolean
)
	local row, actions = Ui.row(list, order, name, color, detail)
	local percent = Ui.text(actions, `{chance}%`, UDim2.fromScale(1, 1), color, true, 26)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	if dim then
		row.BackgroundTransparency = 0.6
		for _, child in row:GetDescendants() do
			if child:IsA("TextLabel") then
				child.TextTransparency = 0.55
			end
		end
	end
end

function VariantController.start()
	local remotes = ReplicatedStorage:WaitForChild("MergerRemotes")
	local Open = remotes:WaitForChild("OpenVariant") :: RemoteEvent
	local GetList = remotes:WaitForChild("GetList") :: RemoteFunction
	local PullRemote = remotes:WaitForChild("Pull") :: RemoteFunction

	local window = Ui.window("VariantUi", "Variant Machine")
	ShopCards.prepare(window, true)

	local view: View? = nil
	local pickedUid: string? = nil
	local pulling = false
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

	local function clearFooter()
		for _, child in window.footer:GetChildren() do
			child:Destroy()
		end
	end

	local function pull()
		if pulling or not pickedUid then
			return
		end
		pulling = true
		clearFooter()
		window.status.TextColor3 = Ui.Colors.lamp
		window.status.Text = "The machine whirs and clanks..."
		local started = os.clock()
		local ok, result = pcall(PullRemote.InvokeServer, PullRemote, pickedUid)
		task.wait(math.max(0, MachineConfig.RevealSeconds - (os.clock() - started)))
		pulling = false
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
		clearFooter()
		window.status.TextColor3 = Ui.Colors.muted
		if not view then
			window.status.Text = "Your save is still loading..."
			return
		end
		local monsters = view.monsters
		if #monsters == 0 then
			window.status.Text = "Your Backpack has no monsters. Pick some up in your mansion first."
			return
		end

		local picked = byUid(pickedUid)
		if not picked then
			-- Step 1: pick a monster. Ones that can go in first, most valuable first.
			pickedUid = nil
			window.status.Text = "Pick a monster. Each try eats one of its effects, but it always comes back."
			local sorted = table.clone(monsters)
			table.sort(sorted, function(a, b)
				if (a.pullProblem == nil) ~= (b.pullProblem == nil) then
					return a.pullProblem == nil
				end
				return if a.value == b.value then a.uid < b.uid else a.value > b.value
			end)
			for i, monster in sorted do
				local can = monster.pullProblem == nil
				card(window.list, i, monster, monster.name, {
					text = if can then `Pick · {VariantMachine.chance(monster.variant)}%` else "Can't",
					color = if can then Pull else Ui.Colors.off,
					enabled = can,
					run = function()
						pickedUid = monster.uid
						render()
					end,
				})
			end
			return
		end

		-- Step 2: the odds, the fee and the Pull button.
		local monster: Row = picked
		card(window.list, 1, monster, monster.name, {
			text = "Change",
			color = Ui.Colors.off,
			enabled = true,
			run = function()
				pickedUid = nil
				render()
			end,
		}, Ui.Colors.lamp)
		local odds = VariantMachine.odds(monster.variant)
		local miss = 100
		for i, odd in odds do
			miss -= odd.chance
			local detail = if odd.possible
				then `Your {Format.name(monster.monsterId)} turns {odd.id}`
				elseif odd.id == monster.variant then "It's already this, so nothing happens"
				else "Lower than what it has, so nothing happens"
			oddsRow(
				window.list,
				1 + i,
				odd.id,
				VariantColors[odd.id] or Ui.Colors.text,
				detail,
				odd.chance,
				not odd.possible
			)
		end
		oddsRow(
			window.list,
			2 + #odds,
			"Nothing",
			Ui.Colors.muted,
			"The effect is used up, the variant stays",
			miss,
			false
		)

		if monster.pullProblem then
			window.status.Text = monster.pullProblem
			return
		end
		local chance = VariantMachine.chance(monster.variant)
		window.status.Text =
			`{chance}% to get a better variant. One random effect is used up. Fee {Format.money(
				monster.pullFee
			)}.`
		local go = Ui.button(
			window.footer,
			`Pull · {chance}% · fee {Format.money(monster.pullFee)}`,
			Pull,
			UDim2.fromScale(1, 1)
		)
		Ui.confirmButton(go, "Use up an effect? Tap again", pull)
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

return VariantController
