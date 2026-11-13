--!strict
-- The Lucky Spin (server/Services/SpinService, numbers in Config/Spin): the HUD's wheel button
-- shows a red dot with the spins waiting and opens a window with a real prize wheel (Giles
-- 2026-11-12, thread "Turn lucky spin into a real wheel"): a round disc of equal coloured
-- slices, each with its picture, its prize and its odds, a pointer on top and a SPIN hub in
-- the middle. Pressing SPIN asks the server for the prize, then the disc spins round, slows
-- down and stops with that slice under the pointer. Under the wheel, the Robux buttons for
-- more spins (only for players who may buy them, player attribute SpinShop).
-- Flat and with as little text as possible (Giles 2026-11-05).
--
-- Roblox has no pie shapes, so each slice is a fan of thin bars from the centre, inside a
-- CanvasGroup with a round corner that clips them to a circle. A GuiObject turns round its
-- own middle, so each bar is a full-width see-through frame centred on the disc with only its
-- top half filled. The pictures (real monster, cake and item previews, which are
-- ViewportFrames and stay out of the CanvasGroup) and the text sit on a plain "Face" frame on
-- top that turns with the disc. All sizes are a share of the disc, so the wheel fits any
-- window size.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Icons = require(script.Parent.Parent:WaitForChild("Icons"))
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Robux = require(script.Parent.Parent:WaitForChild("Robux"))
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
	odds: number,
	monster: string?,
}
type View = { left: number, nextIn: number?, resetIn: number, slices: { Slice } }
type Result = { ok: boolean, message: string, index: number?, view: View? }

local Gold = Color3.fromRGB(255, 211, 107)
local Ink = Color3.fromRGB(24, 18, 32) -- the thin lines between slices and round the disc
local SpinWord = "Spin" -- the server only spins for this word
local SpinSeconds = 4 -- the server waits 4.5 s before the next spin or the jackpot shout
local Turns = 5 -- whole turns before it stops
local BarStep = 1 -- degrees between the bars that fill a slice
local BarWidth = 0.013 -- a bar's width, as a share of the disc (a little more than the gap)
local LabelRadius = 0.31 -- where a slice's picture and text sit, as a share of the disc
local LabelWidth = 0.14 -- a slice's picture and text, as a share of the disc (12 slices)
local LabelHeight = 0.32
local Bundles = { "Spins1", "Spins5" } -- Robux products, in the order of their buttons
local BundleCount = { Spins1 = 1, Spins5 = 5 }

-- 3:05, 12:00.
local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- The few words on a slice: the cash, the rarity, or how many of the item.
local function caption(slice: Slice): string
	if slice.monster then
		return slice.monster
	end
	if slice.cash > 0 then
		return Format.money(slice.cash)
	end
	return if slice.count > 1 then `x{slice.count}` else (slice.itemName or "")
end

-- "30%", "2.5%", "0.5%".
local function odds(percent: number): string
	if percent >= 10 or percent == math.floor(percent) then
		return `{math.floor(percent + 0.5)}%`
	end
	return `{string.format("%.1f", percent)}%`
end

local function round(gui: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = gui
end

local function square(gui: GuiObject)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = gui
end

-- A label that fills its box and scales its text to it.
local function label(
	parent: Instance,
	text: string,
	y: number,
	height: number,
	color: Color3,
	bold: boolean
): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.AnchorPoint = Vector2.new(0.5, 0)
	textLabel.Position = UDim2.fromScale(0.5, y)
	textLabel.Size = UDim2.fromScale(1, height)
	textLabel.Font = if bold then Ui.TitleFont else Enum.Font.GothamBold
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextScaled = true
	textLabel.TextStrokeColor3 = Ink
	textLabel.TextStrokeTransparency = 0.55 -- readable on the light slices too
	textLabel.ZIndex = 4
	textLabel.Parent = parent
	return textLabel
end

-- The picture on a slice: the real monster, cake or item (its preview model), or a
-- frame-drawn money bag or chest for cash.
local function picture(box: Frame, slice: Slice)
	if slice.look then
		local view = Ui.picture(box, UDim2.fromScale(1, 1), slice.look)
		view.ZIndex = 4
		return
	end
	local kind: Icons.Kind? = nil
	if slice.monster then
		kind = "Ghost"
	elseif slice.jackpot then
		kind = "Chest"
	elseif slice.cash > 0 then
		kind = "MoneyBag"
	elseif slice.kind == "Food" then
		kind = "Cake"
	end
	if kind then
		local icon = Icons.draw(box, kind, 0.04)
		for _, child in icon:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = 4
			end
		end
		return
	end
	local glyph = label(box, Ui.Icons[slice.kind or ""] or "🎁", 0, 1, Color3.new(1, 1, 1), false)
	glyph.TextStrokeTransparency = 1
end

function SpinController.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("SpinRemotes")
	local GetView = remotes:WaitForChild("GetView") :: RemoteFunction
	local SpinRemote = remotes:WaitForChild("Spin") :: RemoteFunction

	local window = Ui.window("SpinUi", "Lucky Spin")
	window.list.Visible = false -- the wheel has its own body, sized to the window
	-- A bigger window than the other menus, so the wheel is big (Giles 2026-11-13): it still
	-- takes the same share of a small screen, but grows to 760 x 860 on a big one.
	window.panel.Size = UDim2.fromScale(0.92, 0.94)
	local limit = window.panel:FindFirstChildWhichIsA("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(760, 860)
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = window.list.Position
	body.Size = window.list.Size
	body.Parent = window.panel

	-- The wheel: as big a square as fits above the prize line.
	local wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.BackgroundTransparency = 1
	wheel.AnchorPoint = Vector2.new(0.5, 0)
	wheel.Position = UDim2.fromScale(0.5, 0)
	wheel.Size = UDim2.new(1, 0, 1, -30)
	wheel.Parent = body
	square(wheel)

	local rim = Instance.new("Frame") -- a flat dark ring round the disc
	rim.Name = "Rim"
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromScale(0.5, 0.5)
	rim.Size = UDim2.fromScale(1, 1)
	rim.BackgroundColor3 = Ink
	rim.Parent = wheel
	round(rim)

	local disc = Instance.new("CanvasGroup")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(0.96, 0.96)
	disc.BackgroundColor3 = Ui.Colors.row
	disc.Parent = wheel
	round(disc)

	local face = Instance.new("Frame") -- the pictures and text, turned with the disc
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = disc.Size
	face.BackgroundTransparency = 1
	face.ZIndex = 3
	face.Parent = wheel

	local hub = Instance.new("TextButton")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromScale(0.26, 0.26)
	hub.Font = Ui.TitleFont
	hub.Text = "SPIN"
	hub.TextScaled = true
	hub.TextColor3 = Color3.new(1, 1, 1)
	hub.ZIndex = 6
	hub.Parent = wheel
	round(hub)
	Ui.rim(hub, Ink, 2)
	local hubPadding = Instance.new("UIPadding")
	hubPadding.PaddingLeft = UDim.new(0.16, 0)
	hubPadding.PaddingRight = UDim.new(0.16, 0)
	hubPadding.PaddingTop = UDim.new(0.3, 0)
	hubPadding.PaddingBottom = UDim.new(0.3, 0)
	hubPadding.Parent = hub

	-- The pointer: a gold diamond on the rim at the top, its lower point on the slice that wins.
	local pointer = Instance.new("Frame")
	pointer.Name = "Pointer"
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Position = UDim2.fromScale(0.5, 0.03)
	pointer.Size = UDim2.fromScale(0.075, 0.075)
	pointer.Rotation = 45
	pointer.BackgroundColor3 = Gold
	pointer.ZIndex = 6
	pointer.Parent = wheel
	Ui.rim(pointer, Ink, 2)

	-- What was won, under the wheel.
	local prize = Ui.text(body, "", UDim2.new(1, 0, 0, 28), Gold, true, 24)
	prize.Name = "Prize"
	prize.AnchorPoint = Vector2.new(0.5, 1)
	prize.Position = UDim2.fromScale(0.5, 1)
	prize.TextXAlignment = Enum.TextXAlignment.Center

	-- The Robux buttons for more spins, in the footer.
	local buyRow = Instance.new("Frame")
	buyRow.Name = "Buy"
	buyRow.BackgroundTransparency = 1
	buyRow.Size = UDim2.fromScale(1, 1)
	buyRow.Parent = window.footer
	local buyLayout = Instance.new("UIListLayout")
	buyLayout.FillDirection = Enum.FillDirection.Horizontal
	buyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buyLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buyLayout.Padding = UDim.new(0, 8)
	buyLayout.Parent = buyRow
	local buyButtons: { [string]: TextButton } = {}
	for order, key in Bundles do
		local button = Ui.button(buyRow, "", Robux.Color, UDim2.new(0.5, -4, 0, 44))
		button.LayoutOrder = order
		button.Activated:Connect(function()
			Robux.buy("Spins", key)
		end)
		buyButtons[key] = button
	end
	local function paintBuy()
		buyRow.Visible = player:GetAttribute("SpinShop") == true
		for key, button in buyButtons do
			button.Text = `+{BundleCount[key]}   {Robux.label(key)}`
		end
	end
	paintBuy()
	player:GetAttributeChangedSignal("SpinShop"):Connect(paintBuy)
	Robux.infoLoaded:Connect(paintBuy)
	-- The server reads the prices from Roblox a moment after it starts.
	task.spawn(function()
		local prices = ReplicatedStorage:WaitForChild("RobuxPrices")
		prices.AttributeChanged:Connect(paintBuy)
		paintBuy()
	end)

	local view: View? = nil
	local rolling = false
	local built: string? = nil -- the slice ids the disc was drawn for
	local captions: { TextLabel } = {}
	local sliceAngle = 360

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

	local function paintHub()
		local ready = spinsLeft() > 0 and not rolling
		hub.BackgroundColor3 = if ready then Ui.Colors.buy else Ui.Colors.off
		hub.AutoButtonColor = ready
	end

	-- One spoke from the centre to the rim at `angle` (clockwise from the top): a see-through
	-- frame across the whole disc, turned round its middle (the disc's centre), with only the
	-- half above the centre filled.
	local function ray(angle: number, width: number, color: Color3, z: number)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromScale(width, 1)
		frame.Rotation = angle
		frame.BackgroundTransparency = 1
		frame.ZIndex = z
		frame.Parent = disc
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 0.5)
		fill.BackgroundColor3 = color
		fill.BorderSizePixel = 0
		fill.ZIndex = z
		fill.Parent = frame
	end

	-- Draws the slices (once, and again only if the prizes on the wheel change).
	local function build(slices: { Slice })
		local ids = {}
		for _, slice in slices do
			table.insert(ids, `{slice.id}={slice.look or ""}`)
		end
		local key = table.concat(ids, ",")
		if built == key then
			for index, slice in slices do
				local text = captions[index]
				if text then
					text.Text = caption(slice)
				end
			end
			return
		end
		built = key
		table.clear(captions)
		for _, layer in { disc, face } :: { GuiObject } do
			for _, child in layer:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
		end
		local count = #slices
		if count == 0 then
			return
		end
		sliceAngle = 360 / count
		local bars = math.max(1, math.ceil(sliceAngle / BarStep))
		local step = sliceAngle / bars
		for index, slice in slices do
			-- Slice 1 is centred on the top; the rest follow clockwise.
			local middle = (index - 1) * sliceAngle
			local start = middle - sliceAngle / 2
			local color = rgb(slice.color)
			for bar = 0, bars - 1 do
				ray(start + (bar + 0.5) * step, BarWidth, color, 1)
			end
			-- A thin dark line on the slice's left edge (hides where the bars overlap).
			ray(start, 0.008, Ink, 2)

			-- The picture, the prize and the odds, reading outwards from the hub.
			local radians = math.rad(middle)
			local holder = Instance.new("Frame")
			holder.Name = slice.id
			holder.BackgroundTransparency = 1
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.Position =
				UDim2.fromScale(0.5 + LabelRadius * math.sin(radians), 0.5 - LabelRadius * math.cos(radians))
			holder.Size = UDim2.fromScale(LabelWidth, LabelHeight)
			holder.Rotation = middle
			holder.ZIndex = 3
			holder.Parent = face
			local box = Instance.new("Frame")
			box.BackgroundTransparency = 1
			box.AnchorPoint = Vector2.new(0.5, 0)
			box.Position = UDim2.fromScale(0.5, 0)
			box.Size = UDim2.fromScale(1, LabelWidth / LabelHeight)
			box.Parent = holder
			square(box)
			picture(box, slice)
			local text = label(
				holder,
				caption(slice),
				0.47,
				0.17,
				if slice.jackpot then Gold else Color3.new(1, 1, 1),
				true
			)
			captions[index] = text
			local chance = label(holder, odds(slice.odds), 0.65, 0.12, Color3.new(1, 1, 1), false)
			chance.TextTransparency = 0.15
		end
	end

	local function render()
		window.status.Text = statusText()
		local current = view
		if current then
			build(current.slices)
		end
		paintHub()
	end

	local function load()
		local ok, result = pcall(GetView.InvokeServer, GetView)
		if ok and typeof(result) == "table" then
			view = result :: View
		end
	end

	-- Turns the disc so slice `index` stops under the pointer, a little off its middle so it
	-- doesn't look rigged.
	local function roll(index: number)
		local from = disc.Rotation % 360
		disc.Rotation = from
		face.Rotation = from
		local middle = (index - 1) * sliceAngle
		local wobble = (math.random() - 0.5) * sliceAngle * 0.6
		local stop = (-middle + wobble) % 360
		local target = from + Turns * 360 + ((stop - from) % 360)
		local info = TweenInfo.new(SpinSeconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		local tween = TweenService:Create(disc, info, { Rotation = target })
		local faceTween = TweenService:Create(face, info, { Rotation = target })
		tween:Play()
		faceTween:Play()
		local deadline = os.clock() + SpinSeconds + 0.5
		while tween.PlaybackState == Enum.PlaybackState.Playing and os.clock() < deadline do
			if not window.isOpen() then
				tween:Cancel()
				faceTween:Cancel()
				disc.Rotation = target
				face.Rotation = target
				break
			end
			task.wait(0.05)
		end
	end

	local function spin()
		if rolling or spinsLeft() <= 0 then
			return
		end
		rolling = true
		prize.Text = ""
		paintHub()
		local ok, result = pcall(SpinRemote.InvokeServer, SpinRemote, SpinWord)
		local answer = if ok and typeof(result) == "table" then result :: Result else nil
		if answer and answer.ok and typeof(answer.index) == "number" then
			roll(answer.index)
		end
		if answer then
			prize.Text = answer.message
			prize.TextColor3 = if answer.ok then Gold else Ui.Colors.muted
			if answer.view then
				view = answer.view
			end
		end
		rolling = false
		if window.isOpen() then
			render()
		end
	end
	hub.Activated:Connect(spin)

	local function toggle()
		if window.isOpen() then
			window.close()
			return
		end
		prize.Text = ""
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
		if window.isOpen() and not rolling and not Ui.same(before, view) then
			render()
		end
	end
	-- Fetched and drawn ahead, so the first open is instant.
	task.spawn(function()
		load()
		render()
	end)

	local hud =
		player:WaitForChild("PlayerGui"):WaitForChild("HuntUi"):WaitForChild("Canvas"):WaitForChild("Hud")
	local button = hud:WaitForChild("Menu"):WaitForChild("Spin") :: TextButton
	button.Activated:Connect(toggle)
	Locks.guard(button, "Spin")
	Ui.countBadge(button, "SpinLeft") -- how many spins wait

	player:GetAttributeChangedSignal("SpinLeft"):Connect(function()
		if window.isOpen() and not rolling then
			window.status.Text = statusText()
			paintHub()
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
