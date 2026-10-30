--!strict
-- Hold E (or the prompt on a phone) on a monster roaming someone else's mansion to steal it
-- for Robux (server/Services/HeistService, Config/Heists). The prompts are made here, on other
-- players' monsters only, and show the price; the server checks everything again.
-- The price is the monster's StealProduct attribute (MansionService keeps it up to date).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Heists"))
local Robux = require(script.Parent.Parent:WaitForChild("Robux"))

local StealController = {}

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
	local function price()
		local key = model:GetAttribute("StealProduct")
		prompt.ObjectText = if typeof(key) == "string" then Robux.label(key) else ""
	end
	price()
	model:GetAttributeChangedSignal("StealProduct"):Connect(price)
	prompt.Triggered:Connect(function()
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
	workspace.DescendantAdded:Connect(check)
	for _, instance in workspace:GetDescendants() do
		check(instance)
	end
end

return StealController
