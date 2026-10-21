--!strict
-- Fast-travel buttons in a row at the top middle of the screen: Portals, Shops, Sell
-- (Config/Travel.Destinations). Tap or click one to jump there. They only show in the hub
-- (player attribute Zone is not set); in a zone the exit or a Return Charm takes you home.
-- The server checks everything again, see TravelService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TravelConfig = require(Shared:WaitForChild("Config"):WaitForChild("Travel"))
local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local TravelController = {}

local player = Players.LocalPlayer

local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 44 -- big enough for a thumb

local function buildUi(): (Frame, { TextButton })
	local gui = Instance.new("ScreenGui")
	gui.Name = "TravelUi"
	gui.ResetOnSpawn = false
	-- Up in the top bar, level with Roblox's own menu buttons.
	gui.IgnoreGuiInset = true

	-- Centred at the top; the toasts sit just below it (ToastController).
	local bar = Instance.new("Frame")
	bar.Name = "FastTravel"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 10)
	bar.Size = UDim2.fromOffset(0, BUTTON_HEIGHT)
	bar.AutomaticSize = Enum.AutomaticSize.X
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = bar

	local buttons = {}
	for order, destination in TravelConfig.Destinations do
		local button = Instance.new("TextButton")
		button.Name = destination.id
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT)
		local rgb = destination.color
		local color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		-- The hub look (Ui.paint), with the label in the spooky font and its own colour.
		local h, sat = color:ToHSV()
		button.TextColor3 = Color3.fromHSV(h, sat * 0.45, 1)
		button.TextStrokeTransparency = 0.3
		button.Font = Ui.TitleFont
		button.TextScaled = true
		button.AutoButtonColor = true
		button.Text = destination.label
		button:SetAttribute("Destination", destination.id)
		Ui.paint(button, color) -- square corners, unlike the other buttons
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = button
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 26
		limit.Parent = button
		button.Parent = bar
		Locks.guard(button, destination.id) -- greyed out until the tutorial gets there
		table.insert(buttons, button)
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	return bar, buttons
end

function TravelController.start()
	local bar, buttons = buildUi()

	local function refresh()
		bar.Visible = player:GetAttribute("Zone") == nil
	end
	player:GetAttributeChangedSignal("Zone"):Connect(refresh)
	refresh()

	local remotes = ReplicatedStorage:WaitForChild("TravelRemotes")
	local FastTravel = remotes:WaitForChild("FastTravel") :: RemoteEvent

	-- The same cooldown as the server, so a double tap doesn't look broken.
	local lastTrip = -math.huge
	for _, button in buttons do
		-- Activated works for mouse clicks and taps alike.
		button.Activated:Connect(function()
			if os.clock() - lastTrip < TravelConfig.Cooldown then
				return
			end
			lastTrip = os.clock()
			FastTravel:FireServer(button:GetAttribute("Destination"))
		end)
	end
end

return TravelController
