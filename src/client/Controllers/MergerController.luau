--!strict
-- The Merger's window. Opens when you pick "Let's merge!" at the Merger. Three steps:
--   1. Pick the monster to keep (the main). Kinds with a twin in your Backpack come first.
--   2. Pick a donor of the same kind (hearted ones can't be given away).
--   3. See what a win would make (weight, size, effects, combos, value), the odds and the
--      fee, and press Merge (twice, so nothing goes by accident).
-- The window bubbles for a moment before it shows how it went. The server does the merging
-- (server/Services/MergerService); the rules are in Shared.Util.Merge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local MergerConfig = require(Shared:WaitForChild("Config"):WaitForChild("Merger"))
local ShopCards = require(script.Parent.Parent:WaitForChild("ShopCards"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local MergerController = {}

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
	locked: boolean,
	twins: number,
	chance: number,
}
type View = { monsters: { Row } }
type Preview = {
	ok: boolean,
	message: string,
	weight: string?,
	size: string?,
	effects: { string }?,
	combos: { string }?,
	chance: number?,
	fee: number?,
	value: number?,
}

-- Pixel sizes for a computer screen; the window's Scale canvas shrinks them on a phone.
local Height = 112
local ButtonWidth = 140
local Win = Color3.fromRGB(140, 230, 140)
local Lose = Color3.fromRGB(240, 120, 110)
local Merge = Color3.fromRGB(120, 70, 190)

type Button = { text: string, color: Color3, enabled: boolean, run: (() -> ())? }

-- One monster: picture, name, kind and weight, value, its effects, and a button.
local function card(
	list: ScrollingFrame,
	order: number,
	name: string,
	color: Color3,
	look: string?,
	lines: { string },
	button: Button?,
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

	ShopCards.pictureBox(row, inner, color, look, if look then nil else "🧪")
	local left = inner + 16
	local middle = Instance.new("Frame")
	middle.BackgroundTransparency = 1
	middle.Position = UDim2.fromOffset(left, 0)
	middle.Size = UDim2.new(1, -left - (if button then ButtonWidth + 12 else 0), 1, 0)
	middle.Parent = row
	Ui.text(middle, name, UDim2.fromScale(1, 0.3), color, true, 22)
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

	if not button then
		return
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

local function effectsLine(effects: { string }): string
	return if #effects == 0 then "No effects" else table.concat(effects, ", ")
end

local function linesFor(monster: Row): { string }
	return { `{monster.kind} · {monster.weight}`, Format.money(monster.value), effectsLine(monster.effects) }
end

function MergerController.start()
	local remotes = ReplicatedStorage:WaitForChild("MergerRemotes")
	local Open = remotes:WaitForChild("Open") :: RemoteEvent
	local GetList = remotes:WaitForChild("GetList") :: RemoteFunction
	local PreviewRemote = remotes:WaitForChild("Preview") :: RemoteFunction
	local MergeRemote = remotes:WaitForChild("Merge") :: RemoteFunction

	local window = Ui.window("MergerUi", "The Merger")
	ShopCards.prepare(window, true)

	local view: View? = nil
	local mainUid: string? = nil
	local donorUid: string? = nil
	local preview: Preview? = nil
	local merging = false
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

	local function pickDonor(uid: string)
		donorUid = uid
		preview = nil
		render()
		local ok, result = pcall(PreviewRemote.InvokeServer, PreviewRemote, mainUid, uid)
		if donorUid == uid then
			preview = if ok and typeof(result) == "table" then result else nil
			render()
		end
	end

	local function merge()
		if merging or not mainUid or not donorUid then
			return
		end
		merging = true
		clearFooter()
		window.status.TextColor3 = Ui.Colors.lamp
		window.status.Text = "The cauldron bubbles..."
		local started = os.clock()
		local ok, result = pcall(MergeRemote.InvokeServer, MergeRemote, mainUid, donorUid)
		task.wait(math.max(0, MergerConfig.RevealSeconds - (os.clock() - started)))
		merging = false
		if not window.isOpen() then
			return
		end
		donorUid, preview = nil, nil
		if ok and typeof(result) == "table" then
			view = result.view or view
			if not byUid(mainUid) then
				mainUid = nil
			end
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

		local main = byUid(mainUid)
		if not main then
			-- Step 1: the one to keep.
			mainUid = nil
			window.status.Text = "Pick the monster to keep. It takes in a twin of the same kind."
			for i, monster in monsters do
				local hasTwin = monster.twins > 0
				card(window.list, i, monster.name, monster.color, monster.look, linesFor(monster), {
					text = if hasTwin then `Keep · {monster.chance}%` else "No twin",
					color = if hasTwin then Merge else Ui.Colors.off,
					enabled = hasTwin,
					run = function()
						mainUid = monster.uid
						render()
					end,
				})
			end
			return
		end

		local mainRow: Row = main
		card(window.list, 1, `Keep: {mainRow.name}`, mainRow.color, mainRow.look, linesFor(mainRow), {
			text = "Change",
			color = Ui.Colors.off,
			enabled = true,
			run = function()
				mainUid, donorUid, preview = nil, nil, nil
				render()
			end,
		}, Ui.Colors.lamp)

		local donor = byUid(donorUid)
		if not donor then
			-- Step 2: a donor of the same kind.
			donorUid = nil
			window.status.Text =
				`Pick the {Format.name(mainRow.monsterId)} to give. It's lost if the merge fails.`
			local order = 2
			for _, monster in monsters do
				if monster.monsterId ~= mainRow.monsterId or monster.uid == mainRow.uid then
					continue
				end
				card(window.list, order, monster.name, monster.color, monster.look, linesFor(monster), {
					text = if monster.locked then "♥ Kept" else "Give",
					color = if monster.locked then Ui.Colors.off else Ui.Colors.sell,
					enabled = not monster.locked,
					run = function()
						pickDonor(monster.uid)
					end,
				})
				order += 1
			end
			return
		end

		-- Step 3: what a win makes, the odds and the fee.
		local donorRow: Row = donor
		card(window.list, 2, `Give: {donorRow.name}`, donorRow.color, donorRow.look, linesFor(donorRow), {
			text = "Change",
			color = Ui.Colors.off,
			enabled = true,
			run = function()
				donorUid, preview = nil, nil
				render()
			end,
		})
		local p = preview
		if not p then
			window.status.Text = "Working out the odds..."
			return
		end
		if not p.ok then
			window.status.Text = p.message
			return
		end
		local chance = p.chance or 0
		local fee = p.fee or 0
		local combos = p.combos or {}
		local result = {
			`{p.size or ""} · {p.weight or ""}`,
			Format.money(p.value or 0),
			effectsLine(p.effects or {}),
		}
		local title = if #combos > 0
			then `If it works: {table.concat(combos, " + ")}!`
			else `If it works: {mainRow.name}`
		card(window.list, 3, title, Win, mainRow.look, result, nil, Win)
		window.status.Text =
			`{chance}% to work. If it fails you lose {donorRow.name}. Fee {Format.money(fee)}.`

		local go = Ui.button(
			window.footer,
			`Merge · {chance}% · fee {Format.money(fee)}`,
			Merge,
			UDim2.fromScale(1, 1)
		)
		Ui.confirmButton(go, `Merge them? Tap again`, merge)
	end

	window.onClose = function()
		mainUid, donorUid, preview = nil, nil, nil
	end

	Open.OnClientEvent:Connect(function(counter: unknown)
		if typeof(counter) ~= "Vector3" then
			return
		end
		mainUid, donorUid, preview, view = nil, nil, nil, nil
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

return MergerController
