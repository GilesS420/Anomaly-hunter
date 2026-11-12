--!strict
-- The Lucky Spin (server/Services/SpinService, numbers in Config/Spin): the HUD's wheel button
-- shows a red dot with the spins waiting and opens a small window: eight prize tiles in a ring
-- round a big Spin button. Pressing Spin asks the server for the prize, then a light runs
-- round the ring, slows down and stops on it. Flat and with as little text as possible
-- (Giles 2026-11-05).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Icons = require(script.Parent.Parent:WaitForChild("Icons"))
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local SpinController = {}

type Slice = {
	id: string,
	color: { number },
	cash: number,
	item: string?,
	itemName: string?,
	kind: string?,
	count: number,
	look: string?,
	jackpot: boolean,
}
type View = { left: number, nextIn: number?, resetIn: number, slices: { Slice } }
type Result = { ok: boolean, message: string, index: number?, view: View? }

local Tile = 112
local Gap = 8
local Gold = Color3.fromRGB(255, 211, 107)
local SpinWord = "Spin" -- the server only spins for this word

-- Ring positions clockwise from the top-left corner of a 3 x 3 grid (the middle is the button).
local Ring = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 2, 1 }, { 2, 2 }, { 1, 2 }, { 0, 2 }, { 0, 1 } }

-- 3:05, 12:00.
local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- The few words under a tile: the cash, or how many of the item.
local function caption(slice: Slice): string
	if slice.cash > 0 then
		return Format.money(slice.cash)
	end
	return if slice.count > 1 then `x{slice.count}` else (slice.itemName or "")
end

function SpinController.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("SpinRemotes")
	local GetView = remotes:WaitForChild("GetView") :: RemoteFunction
	local SpinRemote = remotes:WaitForChild("Spin") :: RemoteFunction

	local window = Ui.window("SpinUi", "Lucky Spin")
	local layout = window.list:FindFirstChildWhichIsA("UIListLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	local view: View? = nil
	local rolling = false
	local lit = 0 -- the ring tile lit up (0 none)
	local tiles: { Frame } = {}
	local center: TextButton? = nil

	local function spinsLeft(): number
		local left = player:GetAttribute("SpinLeft")
		return if typeof(left) == "number" then left else (if view then view.left else 0)
	end

	local function statusText(): string
		local left = spinsLeft()
		if left > 0 then
			return if left == 1 then "1 spin" else `{left} spins`
		end
		local nextIn = player:GetAttribute("SpinNext")
		if typeof(nextIn) == "number" then
			return `Next spin: {clock(nextIn)} of play`
		end
		return if view then `New spin in {clock(view.resetIn)}` else ""
	end

	local function paintCenter()
		local button = center
		if not button then
			return
		end
		local ready = spinsLeft() > 0 and not rolling
		button.Text = if rolling then "..." else "SPIN"
		Ui.paint(button, if ready then Ui.Colors.buy else Ui.Colors.off)
		button.AutoButtonColor = ready
	end

	local function light(index: number)
		lit = index
		for i, tile in tiles do
			local stroke = tile:FindFirstChildWhichIsA("UIStroke")
			if stroke then
				stroke.Color = if i == index then Gold else Ui.Style.line
				stroke.Thickness = if i == index then 2 else 1
			end
			tile.BackgroundColor3 = if i == index then Ui.Colors.row:Lerp(Gold, 0.35) else Ui.Colors.row
		end
	end

	local spin: () -> ()

	local function render()
		Ui.clear(window.list)
		table.clear(tiles)
		center = nil
		window.status.Text = statusText()
		local current = view
		if not current then
			return
		end
		local grid = Instance.new("Frame")
		grid.Name = "Wheel"
		grid.Size = UDim2.fromOffset(Tile * 3 + Gap * 2, Tile * 3 + Gap * 2)
		grid.BackgroundTransparency = 1
		grid.Parent = window.list
		for index, slice in current.slices do
			local spot = Ring[index]
			if not spot then
				break
			end
			local tile = Instance.new("Frame")
			tile.Name = slice.id
			tile.Position = UDim2.fromOffset(spot[1] * (Tile + Gap), spot[2] * (Tile + Gap))
			tile.Size = UDim2.fromOffset(Tile, Tile)
			tile.BackgroundColor3 = Ui.Colors.row
			tile.Parent = grid
			Ui.corner(tile, 6)
			Ui.rim(tile, Ui.Style.line, 1)
			local band = Instance.new("Frame") -- the slice's colour along the top
			band.Size = UDim2.new(1, 0, 0, 6)
			band.BackgroundColor3 = rgb(slice.color)
			band.BorderSizePixel = 0
			band.Parent = tile
			local pictureBox = Instance.new("Frame")
			pictureBox.BackgroundTransparency = 1
			pictureBox.Position = UDim2.new(0.5, 0, 0, 10)
			pictureBox.AnchorPoint = Vector2.new(0.5, 0)
			pictureBox.Size = UDim2.fromOffset(Tile - 34, Tile - 34)
			pictureBox.Parent = tile
			if slice.look then
				Ui.picture(pictureBox, UDim2.fromScale(1, 1), slice.look)
			elseif slice.item then
				Ui.picture(pictureBox, UDim2.fromScale(1, 1), nil, Ui.Icons[slice.kind or ""] or "🎁")
			else
				Icons.draw(pictureBox, if slice.jackpot then "Chest" else "MoneyBag", 0.08)
			end
			local text = Ui.text(
				tile,
				caption(slice),
				UDim2.new(1, -8, 0, 20),
				if slice.jackpot then Gold else Ui.Colors.text,
				true,
				18
			)
			text.AnchorPoint = Vector2.new(0.5, 1)
			text.Position = UDim2.new(0.5, 0, 1, -4)
			text.TextXAlignment = Enum.TextXAlignment.Center
			tiles[index] = tile
		end
		local button = Ui.button(grid, "SPIN", Ui.Colors.buy, UDim2.fromOffset(Tile, Tile))
		button.Position = UDim2.fromOffset(Tile + Gap, Tile + Gap)
		local limit = button:FindFirstChildWhichIsA("UITextSizeConstraint")
		if limit then
			limit.MaxTextSize = 30
		end
		button.Font = Ui.TitleFont
		button.Activated:Connect(function()
			spin()
		end)
		center = button
		paintCenter()
		light(lit)
	end

	local function load()
		local ok, result = pcall(GetView.InvokeServer, GetView)
		if ok and typeof(result) == "table" then
			view = result :: View
		end
	end

	-- The light runs round the ring two and a half times, slowing down, and stops on `target`.
	local function roll(target: number)
		local count = #tiles
		if count == 0 then
			return
		end
		local from = if lit > 0 then lit else 1
		local steps = count * 3 + ((target - from) % count)
		for step = 1, steps do
			if not window.isOpen() then
				break
			end
			light((from + step - 1) % count + 1)
			local t = step / steps
			task.wait(0.035 + 0.3 * t * t * t)
		end
		light(target)
	end

	spin = function()
		if rolling or spinsLeft() <= 0 then
			return
		end
		rolling = true
		paintCenter()
		local ok, result = pcall(SpinRemote.InvokeServer, SpinRemote, SpinWord)
		local answer = if ok and typeof(result) == "table" then result :: Result else nil
		if answer and answer.ok and typeof(answer.index) == "number" then
			roll(answer.index)
		end
		if answer and answer.view then
			view = answer.view
		end
		rolling = false
		if window.isOpen() then
			render()
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
	local button = hud:WaitForChild("Menu"):WaitForChild("Spin") :: TextButton
	button.Activated:Connect(toggle)
	Locks.guard(button, "Spin")
	Ui.countBadge(button, "SpinLeft") -- how many spins wait

	player:GetAttributeChangedSignal("SpinLeft"):Connect(function()
		if window.isOpen() and not rolling then
			window.status.Text = statusText()
			paintCenter()
		end
	end)

	task.spawn(function()
		while true do
			if window.isOpen() and not rolling then
				window.status.Text = statusText()
			end
			task.wait(1)
		end
	end)
end

return SpinController
