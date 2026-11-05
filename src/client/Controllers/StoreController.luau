--!strict
-- The Robux Store window, from the coin button in the HUD menu: the Game Passes (Config/Robux)
-- and the once-only Starter Pack as a row of cards that scrolls sideways (Giles 2026-11-05).
-- Each card shows the picture set for it on the Creator Dashboard (a drawn stand-in until
-- there is one), its name, what it does and a Robux button (or Owned).
-- Shop items, the Shop Reroll and mission rerolls and skips are bought where they're used:
-- in the Bakery, Workshop, Vault and Missions windows.
-- Also gives VIP Hunters a gold [VIP] in front of their chat messages.
-- The server does the buying (server/Services/RobuxService); owning a pass shows as the player
-- attribute Pass<Key>, the Starter Pack as StarterPack.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Robux"))
local Icons = require(script.Parent.Parent:WaitForChild("Icons"))
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Robux = require(script.Parent.Parent:WaitForChild("Robux"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local StoreController = {}

local CardWidth = 188
local PictureSize = 168
local Gold = Color3.fromRGB(255, 211, 107)

-- What a card draws when its pass has no picture on the dashboard (or Roblox hasn't said yet).
local StandIns: { [string]: Icons.Kind } = {
	BigStorage = "Backpack",
	LuckyHunter = "Clover",
	VIP = "Crown",
	CakePlate = "Cake",
	FastWalk = "Boot",
	StarterPack = "Gift",
}

function StoreController.start()
	local player = Players.LocalPlayer
	local window = Ui.window("StoreUi", "Robux Store")

	-- The cards sit side by side in a strip that scrolls sideways (Giles 2026-11-05), in the
	-- window list's place.
	window.list.Visible = false
	-- Wider than the other windows (Giles 2026-11-05): it takes 92% of the screen's width, up
	-- to room for all six cards, so a wide screen shows every card and a phone scrolls.
	local limit = window.panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		local cards = #Config.PassOrder + 1 -- the passes and the Starter Pack
		local width = cards * (CardWidth + 10) - 10 + 4 + 28 -- gaps, strip edges, panel padding
		limit.MaxSize = Vector2.new(width, limit.MaxSize.Y)
	end
	local strip = Instance.new("ScrollingFrame")
	strip.Name = "Cards"
	strip.Position = window.list.Position
	strip.Size = window.list.Size
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.ScrollingDirection = Enum.ScrollingDirection.X
	strip.ScrollBarThickness = 6
	strip.ScrollBarImageColor3 = Ui.Colors.rim
	strip.AutomaticCanvasSize = Enum.AutomaticSize.X
	strip.CanvasSize = UDim2.new()
	strip.Parent = window.panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = strip
	local edges = Instance.new("UIPadding") -- room for the scroll bar under the cards
	edges.PaddingLeft = UDim.new(0, 2)
	edges.PaddingRight = UDim.new(0, 2)
	edges.PaddingBottom = UDim.new(0, 12)
	edges.Parent = strip

	-- Round < and > buttons on the strip's edges, for a mouse (a phone just swipes). Each
	-- press slides one card along; a button hides at its end of the strip.
	local function arrow(text: string, side: number, step: number): TextButton
		local button = Ui.button(window.panel, text, Ui.Colors.equip, UDim2.fromOffset(40, 40))
		button.AnchorPoint = Vector2.new(side, 0.5)
		button.Position = UDim2.new(side, if side == 0 then -6 else 6, 0, 68 + 4 + PictureSize / 2)
		button.ZIndex = 5
		local round = button:FindFirstChildOfClass("UICorner")
		if round then
			round.CornerRadius = UDim.new(0.5, 0)
		end
		button.Activated:Connect(function()
			-- CanvasPosition is in canvas units; Roblox stops it at the strip's far end.
			local x = strip.CanvasPosition.X + step * (CardWidth + 10)
			strip.CanvasPosition = Vector2.new(math.max(0, x), 0)
		end)
		return button
	end
	local back = arrow("<", 0, -1)
	local forward = arrow(">", 1, 1)
	local function showArrows()
		-- The Absolute sizes are screen pixels inside the Scale canvas: back to canvas units.
		local most = (strip.AbsoluteCanvasSize.X - strip.AbsoluteWindowSize.X) / Scale.factor()
		back.Visible = strip.CanvasPosition.X > 2
		forward.Visible = strip.CanvasPosition.X < most - 2
	end
	strip:GetPropertyChangedSignal("CanvasPosition"):Connect(showArrows)
	strip:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(showArrows)
	strip:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(showArrows)

	-- One card: the picture on top, the name and what it does under it, and the Robux
	-- button centred at the bottom.
	local function card(
		order: number,
		key: string,
		name: string,
		detail: string,
		owned: boolean,
		buy: () -> (),
		ribbon: string?
	)
		local price = Robux.price(key)
		local frame = Instance.new("Frame")
		frame.Name = key
		frame.LayoutOrder = order
		frame.Size = UDim2.new(0, CardWidth, 1, 0)
		frame.BackgroundColor3 = Ui.Colors.row
		frame.Parent = strip
		Ui.corner(frame, 12)
		Ui.rim(frame, if owned then Color3.fromRGB(58, 48, 78) else Color3.fromRGB(78, 64, 104), 1)

		-- The picture: the one set on the dashboard, or a drawn stand-in on a dark tile.
		local image = Robux.image(key)
		local picture: GuiObject
		if image then
			local label = Instance.new("ImageLabel")
			label.Image = image
			label.ScaleType = Enum.ScaleType.Crop
			label.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
			label.ImageColor3 = if owned then Color3.fromRGB(150, 145, 160) else Color3.new(1, 1, 1)
			picture = label
		else
			local tile = Instance.new("Frame")
			tile.BackgroundColor3 = Color3.fromRGB(46, 30, 74)
			local glow = Instance.new("UIGradient")
			glow.Rotation = 90
			glow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 100, 150))
			glow.Parent = tile
			Icons.draw(tile, StandIns[key] or "Coin", 0.16)
			picture = tile
		end
		picture.Name = "Picture"
		picture.AnchorPoint = Vector2.new(0.5, 0)
		picture.Position = UDim2.new(0.5, 0, 0, 10)
		picture.Size = UDim2.fromOffset(PictureSize, PictureSize)
		picture.Parent = frame
		Ui.corner(picture, 10)

		if ribbon then -- "Once only" on the Starter Pack
			local tag = Ui.text(frame, ribbon, UDim2.fromOffset(96, 22), Color3.fromRGB(26, 16, 32), true, 15)
			tag.AnchorPoint = Vector2.new(0.5, 0.5)
			tag.Position = UDim2.new(0.5, 0, 0, 10)
			tag.BackgroundTransparency = 0
			tag.BackgroundColor3 = Gold
			tag.TextXAlignment = Enum.TextXAlignment.Center
			tag.ZIndex = 2
			Ui.corner(tag, 11)
		end

		local top = 10 + PictureSize + 6
		local title = Ui.text(frame, name, UDim2.new(1, -16, 0, 26), Gold, true, 21)
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.new(0.5, 0, 0, top)
		title.TextXAlignment = Enum.TextXAlignment.Center
		local textSize = UDim2.new(1, -16, 1, -(top + 30 + 58)) -- down to the button
		local text = Ui.text(frame, detail, textSize, Ui.Colors.muted, false, 16)
		text.AnchorPoint = Vector2.new(0.5, 0)
		text.Position = UDim2.new(0.5, 0, 0, top + 30)
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.TextWrapped = true
		text.TextTruncate = Enum.TextTruncate.None

		local label = if owned then "Owned" else Robux.label(key)
		local color = if owned or not price then Ui.Colors.off else Robux.Color
		local action = Ui.button(frame, label, color, UDim2.fromOffset(PictureSize - 20, 44))
		action.Name = "Buy"
		action.AnchorPoint = Vector2.new(0.5, 1)
		action.Position = UDim2.new(0.5, 0, 1, -10)
		action.AutoButtonColor = not owned and price ~= nil
		if not owned and price then
			action.Activated:Connect(buy)
		end
	end

	local function render()
		for _, child in strip:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		window.status.Text = "Passes are yours forever. Paying only makes things faster."
		for order, key in Config.PassOrder do
			local pass = Config.Passes[key]
			local owned = player:GetAttribute(`Pass{key}`) == true
			card(order, key, pass.name, Config.PassText[key], owned, function()
				Robux.buy("Pass", key)
			end)
		end
		local starter = Config.Products.StarterPack
		card(
			20,
			"StarterPack",
			starter.name,
			Config.StarterText,
			player:GetAttribute("StarterPack") == true,
			function()
				Robux.buy("StarterPack")
			end,
			"Once only"
		)
		task.defer(showArrows)
	end

	local function toggle()
		if window.isOpen() then
			window.close()
		else
			render()
			window.open(nil)
		end
	end

	Robux.onGranted(function()
		if window.isOpen() then
			render()
		end
	end)
	Robux.infoLoaded:Connect(function() -- the dashboard pictures came in
		if window.isOpen() then
			render()
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if window.isOpen() and (string.sub(name, 1, 4) == "Pass" or name == "StarterPack") then
			render()
		end
	end)

	-- [VIP] in gold before a VIP Hunter's chat messages.
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		local speaker = if source then Players:GetPlayerByUserId(source.UserId) else nil
		if speaker and speaker:GetAttribute("PassVIP") == true then
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = `<font color="#FFD36B">[VIP]</font> {message.PrefixText}`
			return properties
		end
		return nil :: any
	end

	local hud =
		player:WaitForChild("PlayerGui"):WaitForChild("HuntUi"):WaitForChild("Canvas"):WaitForChild("Hud")
	local button = hud:WaitForChild("Menu"):WaitForChild("Store") :: TextButton
	button.Activated:Connect(toggle)
	Locks.guard(button, "Store") -- greyed out until the tutorial's tour gets there
end

return StoreController
