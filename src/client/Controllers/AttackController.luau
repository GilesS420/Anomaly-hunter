--!strict
-- Draws monster attacks (server/Services/MonsterAiService.luau decides them):
--   a warning shape on the ground while a monster winds up (red: costs a heart, blue: slows,
--   yellow: blinds, purple: it's about to vanish) and a "!" over the monster. Step out of
--   the shape before it disappears and the attack misses.
--   when you get hit: Charge and Shockwave knock you back, Blind whites out the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackConfig = require(Shared:WaitForChild("Config"):WaitForChild("Attacks"))

local AttackController = {}

local player = Players.LocalPlayer

type Warning = {
	kind: string,
	model: Model,
	harmful: boolean,
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	y: number,
	radius: number,
	hitTime: number,
}

local Colors = {
	harmful = Color3.fromRGB(255, 60, 60),
	Slow = Color3.fromRGB(80, 140, 255),
	Blind = Color3.fromRGB(255, 240, 150),
	Blink = Color3.fromRGB(190, 120, 255),
}

local folder: Folder? = nil
local blindFrame: Frame? = nil

local function warningsFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "AttackWarnings" -- only on this client
	created.Parent = workspace
	folder = created
	return created
end

local function flatPart(color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.75
	return part
end

-- A flat disc of this radius centred on (x, y, z).
local function disc(color: Color3, x: number, y: number, z: number, radius: number): Part
	local part = flatPart(color)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.2, radius * 2, radius * 2)
	-- A cylinder's round faces point along X; turn it so it lies flat.
	part.CFrame = CFrame.new(x, y + 0.15, z) * CFrame.Angles(0, 0, math.pi / 2)
	return part
end

-- A flat lane from (ax, az) to (bx, bz), halfWidth studs either side.
local function lane(
	color: Color3,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	y: number,
	halfWidth: number
): Part
	local part = flatPart(color)
	local from = Vector3.new(ax, y + 0.15, az)
	local to = Vector3.new(bx, y + 0.15, bz)
	local length = math.max((to - from).Magnitude, 0.5)
	part.Size = Vector3.new(halfWidth * 2, 0.2, length)
	part.CFrame = if length > 0.5 then CFrame.lookAt((from + to) / 2, to) else CFrame.new(from)
	return part
end

local function exclamation(model: Model): BillboardGui?
	local body = model.PrimaryPart
	if not body then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "AttackWarning"
	gui.Size = UDim2.fromOffset(40, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, body.Size.Y / 2 + 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "!"
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 70, 70)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = body
	return gui
end

local function onWarn(info: Warning)
	if typeof(info) ~= "table" or typeof(info.model) ~= "Instance" then
		return
	end
	local color = if info.kind == "Blink"
		then Colors.Blink
		elseif info.harmful then Colors.harmful
		elseif info.kind == "Slow" then Colors.Slow
		else Colors.Blind
	local shape: Part? = nil
	if info.kind == "Charge" then
		shape = lane(color, info.fromX, info.fromZ, info.toX, info.toZ, info.y, info.radius)
	elseif info.kind == "Throw" or info.kind == "Slow" then
		shape = disc(color, info.toX, info.y, info.toZ, info.radius)
	elseif info.kind == "Shockwave" or info.kind == "Blind" then
		shape = disc(color, info.fromX, info.y, info.fromZ, info.radius)
	end
	local mark = exclamation(info.model)

	local seconds = math.max(info.hitTime - workspace:GetServerTimeNow(), 0.05)
	if shape then
		shape.Parent = warningsFolder()
		-- Fills in as the hit gets closer.
		TweenService:Create(shape, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Transparency = 0.35 })
			:Play()
	end

	local function clear()
		if shape then
			shape:Destroy()
		end
		if mark then
			mark:Destroy()
		end
	end
	task.delay(seconds, clear)
	-- Caught in a flashlight (or gone) mid wind-up: the attack is off.
	local connections: { RBXScriptConnection } = {}
	local function stop()
		for _, connection in connections do
			connection:Disconnect()
		end
		clear()
	end
	table.insert(connections, info.model:GetAttributeChangedSignal("HeldBy"):Connect(stop))
	table.insert(connections, info.model.Destroying:Connect(stop))
	task.delay(seconds, function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
end

local function blind(seconds: number)
	local frame = blindFrame
	if not frame or not frame.Parent then
		local gui = Instance.new("ScreenGui")
		gui.Name = "BlindUi"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 5 -- under the toasts, so you can still read what hit you
		local created = Instance.new("Frame")
		created.Size = UDim2.fromScale(1, 1)
		created.BackgroundColor3 = Color3.fromRGB(255, 252, 235)
		created.BorderSizePixel = 0
		created.BackgroundTransparency = 1
		created.Parent = gui
		gui.Parent = player:WaitForChild("PlayerGui")
		blindFrame = created
		frame = created
	end
	assert(frame)
	frame.BackgroundTransparency = 0.05
	TweenService:Create(
		frame,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	):Play()
end

local function onHit(kind: string, seconds: number, pushX: number, pushZ: number)
	if kind == "Blind" then
		blind(seconds)
		return
	end
	-- Our own character's physics runs here, so the knockback is applied on this side.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and typeof(pushX) == "number" and typeof(pushZ) == "number" then
		local speed = AttackConfig.KnockbackSpeed
		root.AssemblyLinearVelocity = Vector3.new(pushX * speed, 30, pushZ * speed)
	end
end

function AttackController.start()
	local remotes = ReplicatedStorage:WaitForChild("AttackRemotes")
	local Warn = remotes:WaitForChild("Warn") :: RemoteEvent
	local Hit = remotes:WaitForChild("Hit") :: RemoteEvent
	Warn.OnClientEvent:Connect(onWarn)
	Hit.OnClientEvent:Connect(onHit)
end

return AttackController
