--!strict
-- Catching, Luigi's Mansion style: shine the flashlight to stun a monster, then vacuum it
-- while dragging against the way it yanks. The client only sends intent (shine at this,
-- start/stop vacuuming, which way I'm pulling); every rule is checked here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catching = require(ReplicatedStorage.Shared.Util.Catching)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local SpawnService = require(script.Parent.SpawnService)

local CatchService = {}

type Hold = {
	model: Model,
	progress: number,
	pull: number,
	tug: number,
	nextFlip: number,
	rate: number,
	range: number,
}

local random = Random.new()
local holds: { [Player]: Hold } = {}
local heldBy: { [Model]: Player } = {}
local lastShine: { [Player]: number } = {}

local remotes = Instance.new("Folder")
remotes.Name = "CatchRemotes"
local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
local Shine = remote("Shine") -- client -> server: (model)
local VacuumStart = remote("VacuumStart") -- client -> server: (model)
local VacuumStop = remote("VacuumStop") -- client -> server: ()
local Pull = remote("Pull") -- client -> server: (-1 | 0 | 1)
local Result = remote("Result") -- server -> client: (kind, monsterId?, info?)

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function distanceTo(player: Player, model: Model): number
	local root = rootOf(player)
	local body = model.PrimaryPart
	if not root or not body then
		return math.huge
	end
	return (root.Position - body.Position).Magnitude
end

local function isLiveMonster(model: any): boolean
	return typeof(model) == "Instance" and model:IsA("Model") and SpawnService.get(model) ~= nil
end

local function setStunned(model: Model, seconds: number)
	model:SetAttribute("StunnedUntil", workspace:GetServerTimeNow() + seconds)
	local body = model.PrimaryPart
	if body and not body:FindFirstChild("StunGlow") then
		local glow = Instance.new("Highlight")
		glow.Name = "StunGlow"
		glow.FillColor = Color3.new(1, 1, 0.7)
		glow.FillTransparency = 0.4
		glow.Parent = body
	end
	task.delay(seconds, function()
		local until_ = model:GetAttribute("StunnedUntil")
		if body and not heldBy[model] and (until_ == nil or until_ <= workspace:GetServerTimeNow()) then
			local glow = body:FindFirstChild("StunGlow")
			if glow then
				glow:Destroy()
			end
		end
	end)
end

local function isStunned(model: Model): boolean
	local until_ = model:GetAttribute("StunnedUntil")
	return typeof(until_) == "number" and until_ > workspace:GetServerTimeNow()
end

local function release(player: Player, reason: string?)
	local hold = holds[player]
	if not hold then
		return
	end
	holds[player] = nil
	heldBy[hold.model] = nil
	hold.model:SetAttribute("HeldBy", nil)
	hold.model:SetAttribute("Tug", nil)
	hold.model:SetAttribute("CatchProgress", nil)
	local body = hold.model.PrimaryPart
	local glow = body and body:FindFirstChild("StunGlow")
	if glow then
		glow:Destroy()
	end
	if reason then
		Result:FireClient(player, reason, hold.model:GetAttribute("MonsterId"))
	end
end

local function finishCatch(player: Player, hold: Hold)
	local data = DataService.get(player)
	local model = hold.model
	release(player)
	if not data then
		return
	end
	local equipped = { data.equipped.flashlight, data.equipped.vacuum, data.equipped.lens }
	local caught = SpawnService.capture(model, equipped)
	if not caught then
		return
	end
	-- VacuumStart refuses a hunter who is already carrying, so this always fits.
	HuntService.carry(player, caught)
	Result:FireClient(player, "Caught", caught.monsterId, { size = caught.size, effects = caught.effects })
end

Shine.OnServerEvent:Connect(function(player, model)
	local data = DataService.get(player)
	if not data or not isLiveMonster(model) or heldBy[model] then
		return
	end
	local flashlight = Tools.Flashlights[data.equipped.flashlight]
	if not flashlight then
		return
	end
	local now = os.clock()
	if now - (lastShine[player] or 0) < flashlight.cooldown then
		return
	end
	-- Small allowance for lag between what the client saw and where things are now.
	if distanceTo(player, model) > flashlight.range + 4 then
		return
	end
	lastShine[player] = now
	setStunned(model, flashlight.stunSeconds)
end)

VacuumStart.OnServerEvent:Connect(function(player, model)
	local data = DataService.get(player)
	if not data or holds[player] or not isLiveMonster(model) or heldBy[model] then
		return
	end
	local spawned = SpawnService.get(model) :: SpawnService.Spawned
	if HuntService.isCarrying(player) then
		Result:FireClient(player, "VacuumFull", spawned.monsterId)
		return
	end
	local vacuumId = data.equipped.vacuum
	local vacuum = Tools.Vacuums[vacuumId]
	if not vacuum or distanceTo(player, model) > vacuum.range + 4 then
		return
	end
	if not isStunned(model) then
		Result:FireClient(player, "NotStunned", spawned.monsterId)
		return
	end
	if not Catching.canVacuum(vacuumId, spawned.size, spawned.rarity) then
		Result:FireClient(player, "TooStrong", spawned.monsterId, {
			needTier = Catching.requiredTier(spawned.size, spawned.rarity),
		})
		return
	end

	local hold: Hold = {
		model = model,
		progress = Tools.Tug.StartProgress,
		pull = 0,
		tug = if random:NextNumber() < 0.5 then -1 else 1,
		nextFlip = os.clock() + random:NextNumber(Tools.Tug.FlipMin, Tools.Tug.FlipMax),
		rate = Catching.catchRate(vacuumId, spawned.rarity),
		range = vacuum.range,
	}
	holds[player] = hold
	heldBy[model] = player
	model:SetAttribute("HeldBy", player.UserId)
	model:SetAttribute("Tug", hold.tug)
	model:SetAttribute("CatchProgress", hold.progress)
	Result:FireClient(player, "Holding", spawned.monsterId, { model = model })
end)

VacuumStop.OnServerEvent:Connect(function(player)
	release(player, "Stopped")
end)

Pull.OnServerEvent:Connect(function(player, pull)
	local hold = holds[player]
	if hold and (pull == -1 or pull == 0 or pull == 1) then
		hold.pull = pull
	end
end)

function CatchService.start()
	remotes.Parent = ReplicatedStorage

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for player, hold in holds do
			if not isLiveMonster(hold.model) then
				release(player)
				continue
			end
			if distanceTo(player, hold.model) > hold.range + 4 then
				release(player, "Escaped")
				continue
			end
			if now >= hold.nextFlip then
				hold.tug = -hold.tug
				hold.nextFlip = now + random:NextNumber(Tools.Tug.FlipMin, Tools.Tug.FlipMax)
				hold.model:SetAttribute("Tug", hold.tug)
			end
			hold.progress = Catching.step(hold.progress, hold.pull, hold.tug, hold.rate, dt)
			hold.model:SetAttribute("CatchProgress", hold.progress)
			if hold.progress >= 1 then
				finishCatch(player, hold)
			elseif hold.progress <= 0 then
				release(player, "Escaped")
			end
		end
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		release(player)
		lastShine[player] = nil
	end)
end

return CatchService
