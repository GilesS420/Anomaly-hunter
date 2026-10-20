--!strict
-- Press E (or tap the prompt on a phone) next to one of your own mansion monsters to pick it
-- up into your inventory (Storage). The prompts are made here, on your own monsters only, so
-- nobody else sees a prompt on them; the server checks the monster is yours anyway
-- (InventoryRemotes.Move, server/Services/InventoryService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PickupController = {}

local function promptFor(model: Model, move: RemoteFunction)
	local body = model.PrimaryPart or model:FindFirstChild("Body")
	local uid = model:GetAttribute("Uid")
	if not body or not body:IsA("BasePart") or typeof(uid) ~= "string" or body:FindFirstChild("Pickup") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Pickup"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = model.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10 + body.Size.X / 2 -- from its middle, so big ones too
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	local busy = false
	prompt.Triggered:Connect(function()
		if busy then
			return
		end
		busy = true
		pcall(move.InvokeServer, move, uid)
		busy = false
	end)
end

function PickupController.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("InventoryRemotes")
	local move = remotes:WaitForChild("Move") :: RemoteFunction

	local function check(instance: Instance)
		if instance:IsA("Model") and instance:GetAttribute("OwnerId") == player.UserId then
			-- the Uid and body can land a moment after the model itself
			task.defer(promptFor, instance, move)
		end
	end
	workspace.DescendantAdded:Connect(check)
	for _, instance in workspace:GetDescendants() do
		check(instance)
	end
end

return PickupController
