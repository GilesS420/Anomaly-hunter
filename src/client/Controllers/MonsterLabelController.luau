--!strict
-- Monster labels (price tag, name, details; MonsterModel builds them on the server) stay
-- hidden until you point at the monster with the mouse, or tap it on a phone (then it shows
-- for a few seconds). Only this client hides them, so it's the same for every player.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MonsterLabelController = {}

local TapSeconds = 4

local function monsterOf(part: Instance?): Model?
	local at = part
	while at and at ~= workspace do
		if at:IsA("Model") and at:GetAttribute("MonsterId") ~= nil then
			return at
		end
		at = at.Parent
	end
	return nil
end

local function labelOf(model: Model): BillboardGui?
	local body = model.PrimaryPart
	local label = if body then body:FindFirstChild("Label") else nil
	return if label and label:IsA("BillboardGui") then label else nil
end

function MonsterLabelController.start()
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()
	local shown: BillboardGui? = nil
	local tapped: Model? = nil
	local tappedUntil = 0

	-- Every monster label starts hidden.
	local function hide(instance: Instance)
		if instance:IsA("BillboardGui") and instance.Name == "Label" and monsterOf(instance) then
			instance.Enabled = false
		end
	end
	workspace.DescendantAdded:Connect(hide)
	for _, instance in workspace:GetDescendants() do
		hide(instance)
	end

	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if processed then
			return
		end
		local ray = workspace.CurrentCamera:ViewportPointToRay(position.X, position.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500)
		tapped = monsterOf(if hit then hit.Instance else nil)
		tappedUntil = os.clock() + TapSeconds
	end)

	RunService.RenderStepped:Connect(function()
		local model = if UserInputService.MouseEnabled then monsterOf(mouse.Target) else nil
		if not model and tapped and os.clock() < tappedUntil and tapped.Parent then
			model = tapped
		end
		local label = if model then labelOf(model) else nil
		if label ~= shown then
			if shown then
				shown.Enabled = false
			end
			if label then
				label.Enabled = true
			end
			shown = label
		end
	end)
end

return MonsterLabelController
