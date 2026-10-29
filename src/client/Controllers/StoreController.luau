--!strict
-- The Robux Store window, from the coin button in the HUD menu: the Game Passes (Config/Robux)
-- and the once-only Starter Pack, each with what it does and a Robux button (or Owned).
-- Shop items, the Shop Reroll and mission rerolls and skips are bought where they're used:
-- in the Bakery, Workshop, Vault and Missions windows.
-- Also gives VIP Hunters a gold [VIP] in front of their chat messages.
-- The server does the buying (server/Services/RobuxService); owning a pass shows as the player
-- attribute Pass<Key>, the Starter Pack as StarterPack.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Robux"))
local Robux = require(script.Parent.Parent:WaitForChild("Robux"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local StoreController = {}

local RowHeight = 92
local Gold = Color3.fromRGB(255, 211, 107)

function StoreController.start()
	local player = Players.LocalPlayer
	local window = Ui.window("StoreUi", "Robux Store")

	-- One row: name, what it does (wrapped) and the button on the right.
	local function row(
		order: number,
		name: string,
		detail: string,
		button: string,
		color: Color3,
		buy: (() -> ())?
	)
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -8, 0, RowHeight)
		frame.BackgroundColor3 = Ui.Colors.row
		frame.Parent = window.list
		Ui.corner(frame, 10)
		Ui.rim(frame, Color3.fromRGB(58, 48, 78), 1)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 12)
		padding.PaddingRight = UDim.new(0, 10)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = frame
		Ui.text(frame, name, UDim2.new(0.66, 0, 0, 26), Gold, true, 22)
		local text = Ui.text(frame, detail, UDim2.new(0.66, 0, 1, -30), Ui.Colors.muted, false, 16)
		text.Position = UDim2.fromOffset(0, 30)
		text.TextWrapped = true
		text.TextTruncate = Enum.TextTruncate.None
		text.TextYAlignment = Enum.TextYAlignment.Top
		local action = Ui.button(frame, button, color, UDim2.new(0.32, -6, 0, 44))
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.fromScale(1, 0.5)
		action.AutoButtonColor = buy ~= nil
		if buy then
			action.Activated:Connect(buy)
		end
	end

	local function render()
		Ui.clear(window.list)
		window.status.Text = "Passes are yours forever. Paying only makes things faster."
		for order, key in Config.PassOrder do
			local pass = Config.Passes[key]
			local owned = player:GetAttribute(`Pass{key}`) == true
			local price = Robux.price(key)
			if owned then
				row(order, pass.name, Config.PassText[key], "Owned", Ui.Colors.off, nil)
			else
				row(
					order,
					pass.name,
					Config.PassText[key],
					Robux.label(key),
					if price then Robux.Color else Ui.Colors.off,
					if price
						then function()
							Robux.buy("Pass", key)
						end
						else nil
				)
			end
		end
		local starter = Config.Products.StarterPack
		if player:GetAttribute("StarterPack") == true then
			row(20, starter.name, Config.StarterText, "Owned", Ui.Colors.off, nil)
		else
			local price = Robux.price("StarterPack")
			row(
				20,
				starter.name,
				Config.StarterText,
				Robux.label("StarterPack"),
				if price then Robux.Color else Ui.Colors.off,
				if price
					then function()
						Robux.buy("StarterPack")
					end
					else nil
			)
		end
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
end

return StoreController
