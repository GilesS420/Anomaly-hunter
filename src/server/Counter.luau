--!strict
-- Shop counters in the hub: a "hold E" prompt on one of the landmarks
-- (Workspace.Hub.Landmarks.<Name>), on the side that faces the middle of the hub so it's
-- easy to walk up to. Works the same with a placeholder block or Giles's own build.

local World = require(script.Parent.World)

local Counter = {}

local PromptHeight = 3 -- studs above the bottom of the landmark
local PromptReach = 12 -- studs from the counter's front
local UseReach = 30 -- studs: buying and selling only work this close (the window closes at 22)

-- Adds the prompt and returns where it sits (for the client to close the window when the
-- player walks away). Nil, with a warning in Output, if the landmark doesn't exist.
function Counter.prompt(
	landmark: string,
	actionText: string,
	objectText: string,
	onTriggered: (Player) -> ()
): Attachment?
	local part = World.partAt(workspace, "Hub", "Landmarks", landmark)
	if not part then
		warn(`{objectText}: add a Part at Workspace > Hub > Landmarks > {landmark} so players can open it`)
		return nil
	end

	-- The point on the landmark's outside nearest the middle of the hub (0, 0).
	local half = part.Size / 2
	local towardMiddle = part.CFrame:PointToObjectSpace(Vector3.new(0, part.Position.Y, 0))
	local front = Vector3.new(
		math.clamp(towardMiddle.X, -half.X, half.X),
		math.clamp(-half.Y + PromptHeight, -half.Y, half.Y),
		math.clamp(towardMiddle.Z, -half.Z, half.Z)
	)

	local anchor = Instance.new("Attachment")
	anchor.Name = "CounterPrompt"
	anchor.Position = front
	anchor.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PromptReach
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(onTriggered)
	return anchor
end

-- True if the player is standing at this counter (in the hub, close enough). Every buy, sell
-- and equip checks this, so a changed client can't shop from inside a zone.
function Counter.isNear(player: Player, counter: Attachment?): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return counter ~= nil
		and root ~= nil
		and root:IsA("BasePart")
		and player:GetAttribute("Zone") == nil
		and (root.Position - counter.WorldPosition).Magnitude <= UseReach
end

return Counter
