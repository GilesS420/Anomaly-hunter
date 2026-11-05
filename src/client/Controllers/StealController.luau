--!strict
-- Hold E (or the prompt on a phone) on a monster roaming someone else's mansion to steal it
-- for Robux (server/Services/HeistService, Config/Heists). The prompts are made here, on other
-- players' monsters only, and show the price; the server checks everything again.
-- The price is the monster's StealProduct attribute (MansionService keeps it up to date).
-- New hunters (in the tutorial, or StealShield set: their first 2 hours of play, Config/Heists)
-- are shielded: a shield floats over their head, their monsters' prompts say "Shielded", and
-- holding E only explains why, without ever opening a Robux prompt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Heists"))
local Heists = require(Shared:WaitForChild("Util"):WaitForChild("Heists"))
local Robux = require(script.Parent.Parent:WaitForChild("Robux"))
local ToastController = require(script.Parent.ToastController)

local StealController = {}

-- Whether `player`'s monsters can't be stolen yet (the server checks this again).
local function shielded(player: Player?): boolean
	if not player then
		return false
	end
	local left = player:GetAttribute("StealShield")
	return player:GetAttribute("Tutorial") ~= nil or (typeof(left) == "number" and left > 0)
end

-- A small shield over the head of every shielded player but you.
local function badge(player: Player)
	local function refresh()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local old = head and head:FindFirstChild("StealShield")
		if not head then
			return
		end
		if not shielded(player) then
			if old then
				old:Destroy()
			end
			return
		elseif old then
			return
		end
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "StealShield"
		billboard.Size = UDim2.fromOffset(26, 26)
		billboard.StudsOffset = Vector3.new(0, 3.2, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 80
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(1, 1)
		icon.BackgroundTransparency = 1
		icon.Text = "🛡"
		icon.TextScaled = true
		icon.Parent = billboard
		billboard.Parent = head
	end
	player:GetAttributeChangedSignal("StealShield"):Connect(refresh)
	player:GetAttributeChangedSignal("Tutorial"):Connect(refresh)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		refresh()
	end)
	refresh()
end

local function promptFor(model: Model, me: Player)
	local owner = model:GetAttribute("OwnerId")
	local body = model.PrimaryPart or model:FindFirstChild("Body")
	local uid = model:GetAttribute("Uid")
	if
		typeof(owner) ~= "number"
		or owner == me.UserId
		or not body
		or not body:IsA("BasePart")
		or typeof(uid) ~= "string"
		or body:FindFirstChild("Steal")
	then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Steal"
	prompt.ActionText = "Steal"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.HoldSeconds
	prompt.MaxActivationDistance = Config.Reach + body.Size.X / 2 -- from its middle, so big ones too
	prompt.RequiresLineOfSight = false
	local ownerPlayer = Players:GetPlayerByUserId(owner)
	local function price()
		if shielded(ownerPlayer) then
			prompt.ActionText = "Shielded"
			prompt.ObjectText = "🛡 New hunter"
			return
		end
		prompt.ActionText = "Steal"
		local key = model:GetAttribute("StealProduct")
		prompt.ObjectText = if typeof(key) == "string" then Robux.label(key) else ""
	end
	price()
	model:GetAttributeChangedSignal("StealProduct"):Connect(price)
	if ownerPlayer then
		ownerPlayer:GetAttributeChangedSignal("StealShield"):Connect(price)
		ownerPlayer:GetAttributeChangedSignal("Tutorial"):Connect(price)
	end
	prompt.Triggered:Connect(function()
		if ownerPlayer and shielded(ownerPlayer) then
			ToastController.show(Heists.message("NewPlayer", ownerPlayer.DisplayName))
			return
		end
		Robux.buy("Steal", { owner = owner, uid = uid })
	end)
	prompt.Parent = body
end

function StealController.start()
	local me = Players.LocalPlayer
	local function check(instance: Instance)
		if instance:IsA("Model") and instance:GetAttribute("OwnerId") ~= nil then
			-- the Uid and body can land a moment after the model itself
			task.defer(promptFor, instance, me)
		end
	end
	for _, player in Players:GetPlayers() do
		if player ~= me then
			badge(player)
		end
	end
	Players.PlayerAdded:Connect(badge)
	workspace.DescendantAdded:Connect(check)
	for _, instance in workspace:GetDescendants() do
		check(instance)
	end
end

return StealController
