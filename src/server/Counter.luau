--!strict
-- Shop counters in the hub: a "Talk" prompt on one of the landmarks
-- (Workspace.Hub.Landmarks.<Name>), on the side that faces the middle of the hub so it's
-- easy to walk up to. Works the same with a placeholder block or Giles's own build.
-- Using the prompt opens the stand's dialogue on the client (DialogueController, lines in
-- Shared.Config.Stands): info, enter or quit. Enter comes back here and opens the stand's
-- window through onEnter, only while the player still stands at the counter.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(script.Parent.World)

local Counter = {}

local PromptHeight = 3 -- studs above the bottom of the landmark
local PromptReach = 12 -- studs from the counter's front
local UseReach = 30 -- studs: buying and selling only work this close (the window closes at 22)

-- Talk (server to client: stand id, counter position) opens the dialogue; Enter (client to
-- server: stand id, and the `extra` option for a stand's second window) is the "enter" choice.
local remotes = Instance.new("Folder")
remotes.Name = "StandRemotes"
local Talk = Instance.new("RemoteEvent")
Talk.Name = "Talk"
Talk.Parent = remotes
local Enter = Instance.new("RemoteEvent")
Enter.Name = "Enter"
Enter.Parent = remotes

type OnEnter = (Player, string?) -> () -- the player, and the `extra` option they picked (nil for enter)
local stands: { [string]: { anchor: Attachment, onEnter: OnEnter? } } = {}

-- Adds the stand's prompt to anchor. id names the stand's lines in Config/Stands; onEnter
-- opens its window (nil for a stand that only talks, like the Watcher).
function Counter.stand(id: string, anchor: Attachment, objectText: string, onEnter: OnEnter?)
	if not remotes.Parent then
		remotes.Parent = ReplicatedStorage
		Enter.OnServerEvent:Connect(function(player, which, option)
			local stand = if typeof(which) == "string" then stands[which] else nil
			if stand and stand.onEnter and Counter.isNear(player, stand.anchor) then
				stand.onEnter(player, if typeof(option) == "string" then option else nil)
			end
		end)
	end
	stands[id] = { anchor = anchor, onEnter = onEnter }

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PromptReach
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	-- The client hides these while a stand's dialogue or window is open (DialogueController).
	CollectionService:AddTag(prompt, "StandPrompt")
	prompt.Triggered:Connect(function(player)
		Talk:FireClient(player, id, anchor.WorldPosition)
	end)
end

-- Adds the prompt at a hub landmark and returns where it sits (for the client to close the
-- window when the player walks away). onTriggered opens the window once the player picks
-- "enter" in the dialogue. Nil, with a warning in Output, if the landmark doesn't exist.
function Counter.prompt(landmark: string, objectText: string, onTriggered: OnEnter): Attachment?
	-- A built landmark is a Model whose PrimaryPart is the spot in front of its counter.
	local found = World.find(World.find(World.find(workspace, "Hub"), "Landmarks"), landmark)
	local part = if found
			and found:IsA("Model")
			and found.PrimaryPart
		then found.PrimaryPart
		else World.part(found)
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
	Counter.stand(landmark, anchor, objectText, onTriggered)
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
