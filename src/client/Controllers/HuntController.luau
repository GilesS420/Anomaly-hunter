--!strict
-- Hunt run HUD: hearts, what you're carrying, and zone messages. R uses a Return Charm.
-- Placeholder UI until the HUD pass (#28).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HuntController = {}

local player = Players.LocalPlayer

local function label(name: string, position: UDim2, parent: Instance): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.AnchorPoint = Vector2.new(0, 0)
	text.Position = position
	text.Size = UDim2.fromOffset(420, 32)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Font = Enum.Font.GothamBold
	text.Text = ""
	text.Parent = parent
	return text
end

function HuntController.start()
	local remotes = ReplicatedStorage:WaitForChild("HuntRemotes")
	local UseReturnCharm = remotes:WaitForChild("UseReturnCharm") :: RemoteEvent
	local Notice = remotes:WaitForChild("Notice") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "HuntUi"
	gui.ResetOnSpawn = false
	local hearts = label("Hearts", UDim2.fromOffset(20, 20), gui)
	hearts.TextColor3 = Color3.fromRGB(255, 90, 110)
	local carry = label("Carrying", UDim2.fromOffset(20, 56), gui)
	local notice = label("Notice", UDim2.new(0.5, -210, 0, 130), gui)
	notice.TextXAlignment = Enum.TextXAlignment.Center
	gui.Parent = player:WaitForChild("PlayerGui")

	local function refresh()
		local inZone = player:GetAttribute("Zone") ~= nil
		local count = player:GetAttribute("Hearts")
		hearts.Text = if inZone and typeof(count) == "number" then string.rep("♥ ", count) else ""
		local carrying = player:GetAttribute("Carrying")
		carry.Text = if carrying
			then `Carrying: {player:GetAttribute("CarryingSize") or ""} {carrying}  (R = Return Charm)`
			else ""
	end
	for _, attribute in { "Zone", "Hearts", "Carrying", "CarryingSize" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()

	local token = 0
	local function say(text: string)
		token += 1
		local mine = token
		notice.Text = text
		task.delay(3, function()
			if mine == token then
				notice.Text = ""
			end
		end)
	end

	Notice.OnClientEvent:Connect(function(kind: string, info: any)
		if kind == "Entered" then
			say(`Entering {info.zone}`)
		elseif kind == "Locked" then
			say(`{info.zone} is locked. Buy the {info.wing} to open it.`)
		elseif kind == "Delivered" then
			say(`{info.size} {info.monsterId} is home!`)
		elseif kind == "Dropped" then
			say(`You dropped {info.monsterId}!`)
		elseif kind == "NoCharm" then
			say("You don't have a Return Charm.")
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.R then
			UseReturnCharm:FireServer()
		end
	end)
end

return HuntController
