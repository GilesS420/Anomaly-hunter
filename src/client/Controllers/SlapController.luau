--!strict
-- Slapping (server/Services/SlapService.luau decides). Only with a slapper from the Workshop
-- (the player attribute Slapper, your best one; its reach is how close you must be). When
-- another hunter is close enough to slap (Util/Slap: same zone or both in the open hub, not on a mansion plot, not in the
-- tutorial, not just slapped), a round Slap button shows in the bottom-right corner with
-- their name. Tap or click it, or press Q. Slapping someone who is catching makes their
-- monster break loose, so you can try to catch it first.
-- Everyone sees a "SLAP!" pop over the slapped hunter; the slapped hunter's own client throws
-- their character back (its physics runs here).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SlapConfig = require(Shared:WaitForChild("Config"):WaitForChild("Slap"))
local Slap = require(Shared:WaitForChild("Util"):WaitForChild("Slap"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))

local SlapController = {}

local player = Players.LocalPlayer

local CHECK_SECONDS = 0.1
local SlapColor = Color3.fromRGB(235, 90, 120)

-- The rules' view of a player, or nil without a character.
local function hunter(who: Player): Slap.Hunter?
	local character = who.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end
	local zone = who:GetAttribute("Zone")
	return {
		alive = humanoid.Health > 0,
		zone = if typeof(zone) == "string" then zone else nil,
		tutorial = who:GetAttribute("Tutorial") ~= nil,
		x = root.Position.X,
		z = root.Position.Z,
	}
end

-- The closest hunter a slap would land on (the cooldown aside), or nil.
local function closestTarget(): Player?
	local me = hunter(player)
	local tool = Slap.get(player:GetAttribute("Slapper") :: string?)
	if not me or not tool then
		return nil
	end
	local now = workspace:GetServerTimeNow()
	local best: Player? = nil
	local bestDistance = math.huge
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local them = hunter(other)
			local guard = other:GetAttribute("SlapGuardUntil")
			if
				them
				and Slap.blocked(me, them, now, 0, if typeof(guard) == "number" then guard else 0, tool.reach)
					== nil
			then
				local distance = (me.x - them.x) ^ 2 + (me.z - them.z) ^ 2
				if distance < bestDistance then
					best, bestDistance = other, distance
				end
			end
		end
	end
	return best
end

-- A big "SLAP!" that pops over the slapped hunter and floats away.
local function pop(target: Player)
	local character = target.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "SlapPop"
	gui.Size = UDim2.fromOffset(140, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.4, 0.4)
	label.BackgroundTransparency = 1
	label.Font = Ui.TitleFont
	label.Text = "SLAP!"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 225, 120)
	label.TextStrokeColor3 = Color3.fromRGB(120, 20, 40)
	label.TextStrokeTransparency = 0
	label.Rotation = math.random(-15, 15)
	label.Parent = gui
	gui.Parent = head
	local grow = TweenInfo.new(0.15, Enum.EasingStyle.Back)
	TweenService:Create(label, grow, { Size = UDim2.fromScale(1, 1) }):Play()
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
		StudsOffsetWorldSpace = Vector3.new(0, 5, 0),
	}):Play()
	task.delay(0.45, function()
		local fade = TweenInfo.new(0.45)
		TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(0.95, function()
		gui:Destroy()
	end)
end

local function onSlapped(slapper: Player, target: Player, pushX: number, pushZ: number, speed: number)
	if typeof(target) ~= "Instance" or not target:IsA("Player") then
		return
	end
	pop(target)
	if target ~= player or typeof(pushX) ~= "number" or typeof(pushZ) ~= "number" then
		return
	end
	if typeof(speed) ~= "number" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity =
			Vector3.new(pushX * speed, SlapConfig.PushUp, pushZ * speed)
	end
end

function SlapController.start()
	local remotes = ReplicatedStorage:WaitForChild("SlapRemotes")
	local SlapRemote = remotes:WaitForChild("Slap") :: RemoteEvent
	local Slapped = remotes:WaitForChild("Slapped") :: RemoteEvent
	Slapped.OnClientEvent:Connect(onSlapped)

	local gui = Instance.new("ScreenGui")
	gui.Name = "SlapUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	local canvas = Scale.canvas(gui) -- shrinks everything to fit a phone (client/Scale)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Above the event icon (EventIconController), which is above the jump button on phones.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local size = 76
	local lift = (if touch then 170 else 16) + 54 + 14

	local button = Ui.button(canvas, "", SlapColor, UDim2.fromOffset(size, size))
	button.Name = "SlapButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -16, 1, -lift)
	button.Visible = false
	Ui.corner(button, size // 2)
	local hand = Ui.text(button, "✋", UDim2.fromScale(1, 0.55), Ui.Colors.text, true, 40)
	hand.TextXAlignment = Enum.TextXAlignment.Center
	hand.Position = UDim2.fromScale(0, 0.08)
	local word = Ui.text(button, "SLAP", UDim2.fromScale(1, 0.28), Ui.Colors.text, true, 22)
	word.TextXAlignment = Enum.TextXAlignment.Center
	word.Position = UDim2.fromScale(0, 0.62)
	local name = Ui.text(button, "", UDim2.new(1.6, 0, 0, 20), Ui.Colors.lamp, true, 18)
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 0, 1, 4)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextStrokeTransparency = 0.3

	local target: Player? = nil
	local readyAt = 0 -- server time our cooldown ends

	local function slap()
		local who = target
		if not who or workspace:GetServerTimeNow() < readyAt then
			return
		end
		readyAt = workspace:GetServerTimeNow() + SlapConfig.CooldownSeconds
		SlapRemote:FireServer(who)
	end

	button.Activated:Connect(slap)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Q then
			slap()
		end
	end)

	local since = 0
	local cooling = false
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < CHECK_SECONDS then
			return
		end
		since = 0
		target = closestTarget()
		local who = target
		button.Visible = who ~= nil
		if not who then
			return
		end
		name.Text = who.DisplayName
		local left = readyAt - workspace:GetServerTimeNow()
		word.Text = if left > 0 then `{math.ceil(left)}s` elseif touch then "SLAP" else "SLAP (Q)"
		if (left > 0) ~= cooling then
			cooling = left > 0
			button.AutoButtonColor = not cooling
			Ui.paint(button, if cooling then Ui.Colors.off else SlapColor)
		end
	end)
end

return SlapController
