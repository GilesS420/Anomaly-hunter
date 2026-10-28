--!strict
-- The Golden Ghost (quick time event B, Config/GoldenGhost): once in the calm between two
-- Watcher events it zips through the main area for a few seconds. The first player to tap
-- it Taps times wins a prize (Util/GoldenGhost). It never shows up during a warning or an
-- event, but one that's already out keeps flying when an event starts, until it's caught or
-- its time is up. When it gets away nobody loses anything.
--
-- It's a golden ghost built from a few parts in Workspace.Hub.GoldenGhost, flown by the
-- server's physics (AlignPosition), so it moves smoothly for everyone.
--
-- Remotes in ReplicatedStorage.GoldenGhostRemotes:
--   Tap       client -> server ()                     I tapped the ghost
--   Progress  server -> client (taps, needed)        your taps on it so far (0 when it's gone)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GoldenGhost)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local GoldenGhost = require(ReplicatedStorage.Shared.Util.GoldenGhost)
local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local CakeService = require(script.Parent.CakeService)
local DataService = require(script.Parent.DataService)
local MissionService = require(script.Parent.MissionService)
local Notify = require(script.Parent.Parent.Notify)
local World = require(script.Parent.Parent.World)

local GoldenGhostService = {}

local GroundTop = 0.1 -- top of the hub floor (see WorldBuilder)
local Gold = Color3.fromRGB(255, 205, 60)

local random = Random.new()
local ghost: Model? = nil
local mover: AlignPosition? = nil
local endsAt = 0
local taps: { [Player]: number } = {}
local lastTap: { [Player]: number } = {}
local wasCalm = false
local comesAt: number? = nil -- os.clock() it comes in this calm (nil: already came, or not calm)

local remotes = Instance.new("Folder")
remotes.Name = "GoldenGhostRemotes"
local Tap = Instance.new("RemoteEvent")
Tap.Name = "Tap"
Tap.Parent = remotes
local Progress = Instance.new("RemoteEvent")
Progress.Name = "Progress"
Progress.Parent = remotes

local function hubFolder(): Instance
	return World.find(workspace, "Hub") or workspace
end

-- A random spot over one of the lanes the event monsters drift in.
local function waypoint(): Vector3
	local area = Events.DriftAreas[random:NextInteger(1, #Events.DriftAreas)]
	local x = area.x + (random:NextNumber() - 0.5) * area.width
	local z = area.z + (random:NextNumber() - 0.5) * area.depth
	local low, high = Config.Height[1], Config.Height[2]
	return Vector3.new(x, GroundTop + low + (high - low) * random:NextNumber(), z)
end

local function ball(name: string, size: number, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	return part
end

-- A glowing gold head with two black eyes and a tail of shrinking puffs, sparkling.
local function build(at: Vector3): (Model, AlignPosition)
	local model = Instance.new("Model")
	model.Name = "GoldenGhost"
	local head = ball("Head", 3.2, Gold, Enum.Material.Neon)
	head.Massless = false
	head.CFrame = CFrame.new(at)
	head.Parent = model
	model.PrimaryPart = head
	local function stick(part: Part, offset: CFrame)
		part.CFrame = head.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	for side = -1, 1, 2 do
		stick(
			ball("Eye", 0.7, Color3.fromRGB(20, 15, 5), Enum.Material.SmoothPlastic),
			CFrame.new(side * 0.6, 0.35, -1.35)
		)
	end
	for puff, size in { 2.5, 1.9, 1.3 } do
		stick(ball("Tail", size, Gold, Enum.Material.Neon), CFrame.new(0, -0.3 * puff, 1.5 * puff))
	end

	local light = Instance.new("PointLight")
	light.Color = Gold
	light.Brightness = 3
	light.Range = 18
	light.Parent = head
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Gold)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Rate = 30
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = head

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(200, 30)
	label.StudsOffset = Vector3.new(0, 3, 0)
	label.AlwaysOnTop = true
	label.Parent = head
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Gold
	text.TextStrokeTransparency = 0
	text.Text = `Golden Ghost! Tap it {Config.Taps}x`
	text.Parent = label

	-- Flown by physics, so it glides smoothly on every screen.
	local attachment = Instance.new("Attachment")
	attachment.Parent = head
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxVelocity = Config.Speed
	align.MaxForce = math.huge
	align.Responsiveness = 40
	align.Position = at
	align.Parent = head
	local turn = Instance.new("AlignOrientation")
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = attachment
	turn.Responsiveness = 20
	turn.MaxTorque = math.huge
	turn.Parent = head

	model.Parent = hubFolder()
	head:SetNetworkOwner(nil)
	return model, align
end

-- Flies on to a new spot, facing where it's going.
local function flyOn()
	local model, align = ghost, mover
	if not model or not align or not model.PrimaryPart then
		return
	end
	local from = model.PrimaryPart.Position
	local to = waypoint()
	align.Position = to
	local turn = model.PrimaryPart:FindFirstChildOfClass("AlignOrientation")
	if turn and (to - from).Magnitude > 0.1 then
		turn.CFrame = CFrame.lookAt(from, to).Rotation
	end
end

local function remove()
	if ghost then
		ghost:Destroy()
	end
	ghost = nil
	mover = nil
	for player in taps do
		if player.Parent == Players then
			Progress:FireClient(player, 0, Config.Taps)
		end
	end
	table.clear(taps)
	table.clear(lastTap)
end

-- What the player's mansion monsters would sell for, all together.
local function mansionValue(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, caught in data.monsters do
		local ok, value = pcall(Value.sellValue, caught, data.wingsOwned)
		if ok then
			total += value
		end
	end
	return total
end

local function award(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local cash = GoldenGhost.cash(mansionValue(player))
	local prize: string
	local cakes = GoldenGhost.cakeChoices(cash)
	if #cakes > 0 and Rng.chance(Config.CakeChance, random) then
		local cake = cakes[random:NextInteger(1, #cakes)]
		data.inventory[cake.id] = (data.inventory[cake.id] or 0) + 1
		CakeService.syncTools(player)
		prize = `a {cake.name}`
	else
		DataService.addMoney(player, cash)
		prize = Format.money(cash)
	end
	DataService.saveSoon(player)
	Notify.toast(player, `You caught the Golden Ghost! You win {prize}!`)
	MissionService.record(player, "GoldenGhost")
	Notify.toastAll(`{player.DisplayName} caught the Golden Ghost and won {prize}!`)
end

local function onTap(player: Player)
	local model = ghost
	local head = model and model.PrimaryPart
	if not model or not head or player:GetAttribute("Zone") ~= nil then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not root
		or not root:IsA("BasePart")
		or (root.Position - head.Position).Magnitude > Config.TapReach
	then
		return
	end
	local time = os.clock()
	if time - (lastTap[player] or -math.huge) < Config.TapCooldown then
		return
	end
	lastTap[player] = time
	local count = (taps[player] or 0) + 1
	taps[player] = count
	if count >= Config.Taps then
		remove()
		award(player)
		return
	end
	Progress:FireClient(player, count, Config.Taps)
	flyOn() -- it darts away from the tap
end

-- Brings the Golden Ghost out now (also the /ghost admin command). False if one is out.
function GoldenGhostService.spawn(): boolean
	if ghost then
		return false
	end
	local model, align = build(waypoint())
	ghost = model
	mover = align
	endsAt = os.clock() + Config.Seconds
	Notify.toastAll(
		`A Golden Ghost is zipping through the hub! First to tap it {Config.Taps} times wins a prize!`
	)
	return true
end

local function tick()
	-- Calm: no event live and none being warned about.
	local calm = workspace:GetAttribute("WatcherEvent") == nil
		and workspace:GetAttribute("WatcherNext") == nil
	if calm and not wasCalm then
		comesAt = os.clock()
			+ Config.EarliestSeconds
			+ (Config.LatestSeconds - Config.EarliestSeconds) * random:NextNumber()
	elseif not calm then
		comesAt = nil
	end
	wasCalm = calm

	local model = ghost
	if model then
		local head = model.PrimaryPart
		-- It stays out its full time even if an event starts meanwhile (Giles 2026-10-24).
		if os.clock() >= endsAt then
			remove()
			Notify.toastAll("The Golden Ghost got away...")
		elseif head and (head.Position - (mover :: AlignPosition).Position).Magnitude < 4 then
			flyOn()
		end
	elseif comesAt and os.clock() >= comesAt and #Players:GetPlayers() > 0 then
		comesAt = nil
		GoldenGhostService.spawn()
	end
end

function GoldenGhostService.start()
	remotes.Parent = ReplicatedStorage
	Tap.OnServerEvent:Connect(onTap)
	Players.PlayerRemoving:Connect(function(player)
		taps[player] = nil
		lastTap[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			xpcall(tick, function(err)
				warn(`GoldenGhostService: {err}\n{debug.traceback()}`)
			end)
		end
	end)
end

return GoldenGhostService
