--!strict
-- Prompts only a mansion's owner should see (the wing buy prompts on the expand sign and the
-- next wing's door, server/Services/MansionService): the server tags them "OwnerPrompt" with
-- an OwnerId attribute, and this hides them on everyone else's screen. The server checks
-- who pressed anyway, so this is only about not showing a prompt that would be refused.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local OwnerPromptController = {}

function OwnerPromptController.start()
	local player = Players.LocalPlayer

	local function check(prompt: Instance)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		local function apply()
			if prompt:GetAttribute("OwnerId") ~= player.UserId then
				prompt.Enabled = false
			end
		end
		apply()
		-- The server turns the expand prompt on and off as wings are bought: keep it hidden.
		prompt:GetPropertyChangedSignal("Enabled"):Connect(apply)
		prompt:GetAttributeChangedSignal("OwnerId"):Connect(apply)
	end

	CollectionService:GetInstanceAddedSignal("OwnerPrompt"):Connect(check)
	for _, prompt in CollectionService:GetTagged("OwnerPrompt") do
		check(prompt)
	end
end

return OwnerPromptController
