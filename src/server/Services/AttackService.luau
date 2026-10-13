--!strict
-- Wild monsters fight back (#6). A monster that notices a hunter close by gets angry: it stops,
-- glows red with a "!" over its head, and a red circle on the ground shows where the attack
-- will land. Walk out of the circle before it goes off and you dodge it. Each monster has one
-- attack (Config/Attacks): Charge, Scream, Flash, Slime or Vanish.
--
-- Kept friendly on purpose: only one monster attacks you at a time, nothing attacks you just
-- after you arrive or just after you were hit, Bait Bell monsters never attack, and a monster
-- you are catching stops its attack. Hearts lost go through HuntService.damage.
--
-- Nothing here depends on how a monster looks: any Model with a PrimaryPart works, so the
-- placeholder orbs and real monster models behave the same.
--
-- Remotes in ReplicatedStorage.AttackRemotes:
--   Effect  server -> client (kind, data): "Hit", "Dodged", "Knock" (Vector3 push),
--           "Blind" (seconds), "Slowed" (seconds)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AttackConfig = require(ReplicatedStorage.Shared.Config.Attacks)
local Attacks = require(ReplicatedStorage.Shared.Util.Attacks)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Hunt = require(ReplicatedStorage.Shared.Util.Hunt)
local HuntService = require(script.Parent.HuntService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)
local RoamService = require(script.Parent.RoamService)
local SpawnService = require(script.Parent.SpawnService)

local AttackService = {}

local TickSeconds = 0.25 -- how often monsters look around for hunters
local AngryColor = Color3.fromRGB(255, 60, 60)
local RingColors: { [string]: Color3 } = {
	Flash = Color3.fromRGB(255, 240, 150),
	Slime = Color3.fromRGB(110, 230, 90),
}

local nextAttack: { [Model]: number } = {} -- os.clock() a monster may attack again
local attacking: { [Model]: boolean } = {}
local targeted: { [Player]: Model } = {} -- the one monster attacking this hunter
local safeUntil: { [Player]: number } = {} -- os.clock(); nothing attacks the hunter before this
local slowToken: { [Player]: number } = {}
local baseSpeed: { [Player]: number } = {}
local peaceful: { [Player]: boolean? } = {} -- Studio /peace

local remotes = Instance.new("Folder")
remotes.Name = "AttackRemotes"
local Effect = Instance.new("RemoteEvent") -- server -> client: (kind, data)
Effect.Name = "Effect"
Effect.Parent = remotes

local fxFolder = Instance.new("Folder") -- warning circles and slime balls
fxFolder.Name = "AttackEffects"

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

-- Height of the ground under a hunter's feet.
local function feetY(root: BasePart, humanoid: Humanoid): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent :: Instance, fxFolder }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -20, 0), params)
	return if hit then hit.Position.Y else root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
end

-- Where the monster really is (its glide is drawn by the clients).
local function monsterPosition(model: Model): Vector3?
	return RoamService.position(model) or (model.PrimaryPart and model.PrimaryPart.Position)
end

-- A flat glowing circle on the ground: "get out of here". Returns a function that removes it.
local function ring(position: Vector3, radius: number, color: Color3): () -> ()
	local part = Instance.new("Part")
	part.Name = "WarningCircle"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.2, radius * 2, radius * 2)
	part.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.55
	part.Parent = fxFolder
	return function()
		part:Destroy()
	end
end

-- Red glow and a "!" over the monster's head while it winds up. Returns a cleanup function.
local function showAngry(model: Model): () -> ()
	local highlight = Instance.new("Highlight")
	highlight.Name = "AttackGlow"
	highlight.FillColor = AngryColor
	highlight.FillTransparency = 0.45
	highlight.OutlineColor = AngryColor
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model

	local mark: BillboardGui? = nil
	local body = model.PrimaryPart
	if body then
		local gui = Instance.new("BillboardGui")
		gui.Name = "AttackMark"
		gui.Adornee = body
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Size = UDim2.fromOffset(60, 60)
		gui.StudsOffset = Vector3.new(0, model:GetExtentsSize().Y / 2 + 4.5, 0)
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBlack
		text.Text = "!"
		text.TextScaled = true
		text.TextColor3 = AngryColor
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = text
		text.Parent = gui
		gui.Parent = model
		mark = gui
	end
	return function()
		highlight:Destroy()
		if mark then
			mark:Destroy()
		end
	end
end

-- Hides or shows the whole model (Vanish). Remembers how each piece looked before.
local function setVisible(model: Model, visible: boolean)
	for _, item in model:GetDescendants() do
		local saved = item:GetAttribute("VanishSaved")
		if item:IsA("BasePart") or item:IsA("Decal") then
			local thing = item :: any
			if visible and typeof(saved) == "number" then
				thing.Transparency = saved
				item:SetAttribute("VanishSaved", nil)
			elseif not visible and saved == nil then
				item:SetAttribute("VanishSaved", thing.Transparency)
				thing.Transparency = 1
			end
		elseif item:IsA("LayerCollector") or item:IsA("Light") or item:IsA("ParticleEmitter") then
			local thing = item :: any
			if visible and typeof(saved) == "boolean" then
				thing.Enabled = saved
				item:SetAttribute("VanishSaved", nil)
			elseif not visible and saved == nil then
				item:SetAttribute("VanishSaved", thing.Enabled)
				thing.Enabled = false
			end
		end
	end
end

-- A slime ball flying from the monster to the spot.
local function throwSlime(from: Vector3, to: Vector3, seconds: number)
	local ball = Instance.new("Part")
	ball.Name = "Slime"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 1.6
	ball.Material = Enum.Material.Neon
	ball.Color = RingColors.Slime
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanTouch = false
	ball.CanQuery = false
	ball.Position = from
	ball.Parent = fxFolder
	TweenService:Create(ball, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = to + Vector3.new(0, 0.8, 0),
	}):Play()
	task.delay(seconds + 0.1, ball.Destroy, ball)
end

-- Halves the hunter's walk speed for a while (a new slime restarts the timer).
local function slow(player: Player, humanoid: Humanoid, seconds: number, factor: number)
	if not baseSpeed[player] then
		baseSpeed[player] = humanoid.WalkSpeed
	end
	humanoid.WalkSpeed = (baseSpeed[player] :: number) * factor
	local token = (slowToken[player] or 0) + 1
	slowToken[player] = token
	task.delay(seconds, function()
		if slowToken[player] ~= token then
			return
		end
		local base = baseSpeed[player]
		baseSpeed[player] = nil
		if base and humanoid.Parent then
			humanoid.WalkSpeed = base
		end
	end)
end

-- The attack lands at (x, z): hits the hunter if they're still close and in the zone.
local function land(
	player: Player,
	zoneId: string,
	name: string,
	kind: AttackConfig.Kind,
	x: number,
	z: number
)
	local root, humanoid = rootOf(player)
	if not root or not humanoid or player:GetAttribute("Zone") ~= zoneId then
		return
	end
	local position = root.Position
	if not Attacks.hits(kind, x, z, position.X, position.Z) then
		Effect:FireClient(player, "Dodged")
		return
	end
	local stats = Attacks.stats(kind)
	safeUntil[player] = os.clock() + AttackConfig.HitGraceSeconds
	Notify.toast(player, `{name} {stats.verb}!`)
	if stats.knockback then
		local dx, dz = Attacks.pushDirection(x, z, position.X, position.Z)
		Effect:FireClient(player, "Knock", Vector3.new(dx, 0, dz) * stats.knockback)
	end
	if stats.blindSeconds then
		Effect:FireClient(player, "Blind", stats.blindSeconds)
	end
	if stats.slowSeconds then
		slow(player, humanoid, stats.slowSeconds, stats.slowFactor or 0.5)
		Effect:FireClient(player, "Slowed", stats.slowSeconds)
	end
	if stats.damage > 0 then
		Effect:FireClient(player, "Hit")
		HuntService.damage(player, stats.damage)
	end
end

-- One whole attack, from the warning to the hit. Runs in its own thread.
local function attack(model: Model, spawned: SpawnService.Spawned, player: Player, zoneId: string)
	local kind: AttackConfig.Kind = Attacks.kindFor(spawned.monsterId)
	local aggression = Attacks.aggression(spawned.rarity)
	local name = Format.name(spawned.monsterId)
	local radius = MonsterModel.radius(spawned.size)
	attacking[model] = true
	targeted[player] = model

	local cleanups: { () -> () } = {}
	local function still(): boolean
		-- Caught, wandered off, being caught, or the hunter left: the attack is off.
		return SpawnService.get(model) ~= nil
			and not RoamService.isHeld(model)
			and player.Parent ~= nil
			and player:GetAttribute("Zone") == zoneId
	end

	xpcall(function()
		local root, humanoid = rootOf(player)
		local here = monsterPosition(model)
		if not root or not humanoid or not here then
			return
		end
		local floor = feetY(root, humanoid)
		local target = root.Position
		local stats = Attacks.stats(kind)

		-- Warning: freeze, glow red, show where it will land.
		RoamService.freeze(model, aggression.windup + 0.3)
		table.insert(cleanups, showAngry(model))
		local ringColor = RingColors[kind] or AngryColor
		local aimX, aimZ = here.X, here.Z
		if kind == "Vanish" then
			setVisible(model, false)
			table.insert(cleanups, function()
				setVisible(model, true)
			end)
		elseif Attacks.aimsAtHunter(kind) then
			aimX, aimZ = target.X, target.Z
			table.insert(cleanups, ring(Vector3.new(aimX, floor, aimZ), stats.hitRadius, ringColor))
		else
			local ground = here.Y - radius - 0.5
			table.insert(cleanups, ring(Vector3.new(aimX, ground, aimZ), stats.hitRadius, ringColor))
		end
		task.wait(aggression.windup)
		if not still() then
			return
		end

		if kind == "Charge" then
			local seconds = RoamService.dash(model, aimX, aimZ, AttackConfig.ChargeSpeed)
			task.wait(seconds)
		elseif kind == "Slime" then
			local from = monsterPosition(model) or here
			throwSlime(from, Vector3.new(aimX, floor, aimZ), 0.35)
			task.wait(0.35)
		elseif kind == "Vanish" then
			-- Pops up beside the hunter (wherever they are now), then a short last warning.
			local nowRoot = rootOf(player)
			if not nowRoot then
				return
			end
			local hunter = nowRoot.Position
			aimX, aimZ = Attacks.popSpot(here.X, here.Z, hunter.X, hunter.Z, AttackConfig.VanishPopDistance)
			RoamService.place(model, aimX, aimZ, AttackConfig.VanishWindup + 0.3)
			setVisible(model, true)
			table.insert(cleanups, ring(Vector3.new(aimX, floor, aimZ), stats.hitRadius, ringColor))
			task.wait(AttackConfig.VanishWindup)
		end
		if still() then
			land(player, zoneId, name, kind, aimX, aimZ)
		end
	end, function(err)
		warn(`AttackService: {spawned.monsterId} attack failed: {err}\n{debug.traceback()}`)
	end)

	for _, cleanup in cleanups do
		pcall(cleanup)
	end
	attacking[model] = nil
	if targeted[player] == model then
		targeted[player] = nil
	end
	nextAttack[model] = os.clock() + aggression.cooldown
end

-- Hunters per zone index, with where they are and whether a monster may go for them.
local function huntersByZone(now: number): { [number]: { Attacks.Hunter } }
	local result: { [number]: { Attacks.Hunter } } = {}
	for _, player in Players:GetPlayers() do
		local zone = Hunt.zoneById(player:GetAttribute("Zone"))
		local root = if zone then rootOf(player) else nil
		if zone and root then
			local list = result[zone.index] or {}
			result[zone.index] = list
			table.insert(list, {
				id = player.UserId,
				x = root.Position.X,
				z = root.Position.Z,
				ready = not targeted[player] and now >= (safeUntil[player] or 0) and not peaceful[player],
			})
		end
	end
	return result
end

local function step()
	local now = os.clock()
	local hunters = huntersByZone(now)
	local live = SpawnService.all()

	-- Forget monsters that are gone.
	for model in nextAttack do
		if not live[model] then
			nextAttack[model] = nil
		end
	end

	for model, spawned in live do
		if spawned.reservedFor or attacking[model] or RoamService.isHeld(model) then
			continue -- Bait Bell monsters are a gift; held monsters are being caught
		end
		local due = nextAttack[model]
		if not due then
			nextAttack[model] = now + AttackConfig.FirstAttackDelay
			continue
		end
		local list = hunters[spawned.zone]
		if not list or now < due then
			continue
		end
		local position = monsterPosition(model)
		local zone = Hunt.zoneByIndex(spawned.zone)
		if not position or not zone then
			continue
		end
		local targetId =
			Attacks.pickTarget(position.X, position.Z, Attacks.aggression(spawned.rarity).notice, list)
		local player = targetId and Players:GetPlayerByUserId(targetId)
		if player then
			-- Mark them now so a second monster in this same step doesn't pick them too.
			for _, hunter in list do
				if hunter.id == targetId then
					hunter.ready = false
				end
			end
			targeted[player] = model
			attacking[model] = true
			task.spawn(attack, model, spawned, player, zone.id)
		end
	end
end

-- Studio /peace: monsters leave this hunter alone (or attack again).
function AttackService.setPeaceful(player: Player, on: boolean)
	peaceful[player] = if on then true else nil
end

function AttackService.isPeaceful(player: Player): boolean
	return peaceful[player] == true
end

-- Studio /attack: the closest monster in the hunter's zone attacks them right now.
-- Returns false if there's no monster to do it.
function AttackService.provoke(player: Player): boolean
	local zone = Hunt.zoneById(player:GetAttribute("Zone"))
	local root = rootOf(player)
	if not zone or not root or targeted[player] then
		return false
	end
	local best: Model? = nil
	local bestDistance = math.huge
	local bestSpawned: SpawnService.Spawned? = nil
	for model, spawned in SpawnService.all() do
		local position = monsterPosition(model)
		if
			spawned.zone == zone.index
			and position
			and not attacking[model]
			and not RoamService.isHeld(model)
		then
			local distance = (position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance, bestSpawned = model, distance, spawned
			end
		end
	end
	if not best or not bestSpawned then
		return false
	end
	safeUntil[player] = nil
	targeted[player] = best
	attacking[best] = true
	task.spawn(attack, best, bestSpawned, player, zone.id)
	return true
end

function AttackService.start()
	remotes.Parent = ReplicatedStorage
	fxFolder.Parent = workspace

	local function onPlayer(player: Player)
		-- A short safe moment every time a hunter steps into a zone.
		player:GetAttributeChangedSignal("Zone"):Connect(function()
			if player:GetAttribute("Zone") ~= nil then
				safeUntil[player] = os.clock() + AttackConfig.ArrivalGraceSeconds
			end
		end)
		player.CharacterAdded:Connect(function()
			baseSpeed[player] = nil -- a new character has its normal speed again
			slowToken[player] = nil
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		targeted[player] = nil
		safeUntil[player] = nil
		slowToken[player] = nil
		baseSpeed[player] = nil
		peaceful[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TickSeconds)
			-- One bad monster must never stop every attack.
			xpcall(step, function(e)
				warn(`AttackService: {e}\n{debug.traceback()}`)
			end)
		end
	end)
end

return AttackService
