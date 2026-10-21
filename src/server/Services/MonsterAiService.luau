--!strict
-- Zone monsters fight back (#6). Each wild monster has one attack (Config/Attacks, rules in
-- Util/Attacks). When a hunter comes within NoticeRadius it goes after them: it closes in
-- until they're in range, stops, shows a warning shape on the ground for WindupSeconds, then
-- hits whoever is still inside. After that it rests for its cooldown (shorter for rarer
-- monsters). At most MaxAttackersPerHunter monsters go after one hunter at a time.
--
-- A monster you're catching is stunned by your vacuum's beam and can't attack, but the others
-- can, and a hit that costs a heart makes the catch get away. They keep attacking while you
-- carry a catch; at 0 hearts you drop it and go home (HuntService.damage).
-- Players with the attribute Calm (Studio: /calm) or in the tutorial are left alone, and
-- Bait Bell monsters never attack. Studio /attack makes the closest monster attack you now (provoke).
--
-- Remotes in ReplicatedStorage.AttackRemotes:
--   Warn  server -> clients in the zone (Warning)   draw the warning shape until hitTime
--   Hit   server -> client (kind, seconds, pushX, pushZ)   you got hit: knockback or blind
--         (kind "Dodged": it was after you and missed)
-- Player attribute Slowed is true while a Slow attack holds you back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local AttackConfig = require(ReplicatedStorage.Shared.Config.Attacks)
local Attacks = require(ReplicatedStorage.Shared.Util.Attacks)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Hunt = require(ReplicatedStorage.Shared.Util.Hunt)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Roam = require(ReplicatedStorage.Shared.Util.Roam)
local CatchService = require(script.Parent.CatchService)
local HuntService = require(script.Parent.HuntService)
local Notify = require(script.Parent.Parent.Notify)
local RoamService = require(script.Parent.RoamService)
local SpawnService = require(script.Parent.SpawnService)

local MonsterAiService = {}

export type Warning = {
	kind: string,
	model: Model,
	harmful: boolean, -- costs a heart (drawn red)
	fromX: number, -- the monster
	fromZ: number,
	toX: number, -- where it's aimed
	toZ: number,
	y: number, -- floor height
	radius: number,
	hitTime: number, -- server time
}

type Windup = { hitTime: number, mx: number, mz: number, ax: number, az: number }

type Brain = {
	attack: Attacks.Attack?, -- nil: this monster never attacks
	name: string,
	cooldown: number,
	readyAt: number, -- server time it may attack again
	nextChase: number, -- server time of its next chase step
	target: Player?,
	windup: Windup?,
	destroying: RBXScriptConnection,
}

type Target = { player: Player, x: number, z: number }

local TickSeconds = 0.2
local ChaseStepSeconds = 0.8 -- a chasing monster re-aims this often
local BlinkMin, BlinkMax = 8, 14 -- studs a Blink jumps

local remotes = Instance.new("Folder")
remotes.Name = "AttackRemotes"
local Warn = Instance.new("RemoteEvent")
Warn.Name = "Warn"
Warn.Parent = remotes
local Hit = Instance.new("RemoteEvent")
Hit.Name = "Hit"
Hit.Parent = remotes

local random = Random.new()
local brains: { [Model]: Brain } = {}
local lastHit: { [Player]: number } = {}
local arrivedAt: { [Player]: number } = {}
local slowToken: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function brainFor(model: Model, spawned: SpawnService.Spawned): Brain
	local existing = brains[model]
	if existing then
		return existing
	end
	local rarity = Rarities[spawned.rarity]
	local order = if rarity then rarity.order else 1
	local brain: Brain = {
		attack = Attacks.forMonster(spawned.monsterId, order),
		name = Format.name(spawned.monsterId),
		cooldown = Attacks.cooldown(order),
		readyAt = now() + AttackConfig.FirstAttackDelay,
		nextChase = 0,
		target = nil,
		windup = nil,
		destroying = model.Destroying:Connect(function()
			local brain = brains[model]
			brains[model] = nil
			if brain then
				brain.destroying:Disconnect()
			end
		end),
	}
	brains[model] = brain
	return brain
end

-- Hunters who can be attacked right now, by zone id.
local function huntersByZone(): { [string]: { Target } }
	local result: { [string]: { Target } } = {}
	for _, player in Players:GetPlayers() do
		local zoneId = player:GetAttribute("Zone")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			typeof(zoneId) ~= "string"
			or player:GetAttribute("Calm")
			or player:GetAttribute("Tutorial") -- nothing attacks a first-timer
			or not root
			or not root:IsA("BasePart")
			or not humanoid
			or humanoid.Health <= 0
		then
			continue
		end
		local list = result[zoneId]
		if not list then
			list = {}
			result[zoneId] = list
		end
		table.insert(list, { player = player, x = root.Position.X, z = root.Position.Z })
	end
	return result
end

-- The zone's rects cut down to a box around (x, z).
local function rectsNear(rects: { Roam.Rect }, x: number, z: number, half: number): { Roam.Rect }
	local near = {}
	for _, r in rects do
		local minX, maxX = math.max(r.minX, x - half), math.min(r.maxX, x + half)
		local minZ, maxZ = math.max(r.minZ, z - half), math.min(r.maxZ, z + half)
		if maxX > minX and maxZ > minZ then
			table.insert(near, { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ, y = r.y })
		end
	end
	return near
end

local function slow(player: Player, seconds: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local token = (slowToken[player] or 0) + 1
	slowToken[player] = token
	humanoid.WalkSpeed = AttackConfig.SlowWalkSpeed
	player:SetAttribute("Slowed", true)
	task.delay(seconds, function()
		if slowToken[player] == token then
			humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
			player:SetAttribute("Slowed", nil)
		end
	end)
end

local function hitPlayer(player: Player, brain: Brain, attack: Attacks.Attack, windup: Windup, target: Target)
	local at = now()
	if at - (lastHit[player] or -math.huge) < AttackConfig.HitGraceSeconds then
		return
	end
	lastHit[player] = at

	Notify.toast(player, Attacks.hitMessage(brain.name, attack))
	if attack.damage > 0 then
		CatchService.interrupt(player, "The monster you were catching got away!")
		HuntService.damage(player, attack.damage)
		if player:GetAttribute("Zone") == nil then
			return -- that was the last heart: they're on their way home
		end
	end

	local kind = attack.kind
	if kind == "Slow" then
		slow(player, attack.effectSeconds)
	elseif kind == "Blind" then
		Hit:FireClient(player, kind, attack.effectSeconds, 0, 0)
	elseif kind == "Charge" or kind == "Shockwave" then
		local px, pz =
			Attacks.pushDirection(attack, windup.mx, windup.mz, windup.ax, windup.az, target.x, target.z)
		Hit:FireClient(player, kind, 0, px, pz)
	end
end

-- The warning is over: the attack happens.
local function strike(
	model: Model,
	brain: Brain,
	attack: Attacks.Attack,
	windup: Windup,
	hunters: { Target }?
)
	brain.windup = nil
	brain.readyAt = now() + brain.cooldown

	if attack.kind == "Blink" then
		-- A spot BlinkMin to BlinkMax studs away (or the furthest of a few tries).
		local rects, radius = RoamService.area(model)
		local box = if rects then rectsNear(rects, windup.mx, windup.mz, BlinkMax) else {}
		local best: Roam.Point? = nil
		local bestDistance = 0
		for _ = 1, 5 do
			local spot = Roam.randomPoint(box, radius, random)
			local distance = if spot
				then math.sqrt((spot.x - windup.mx) ^ 2 + (spot.z - windup.mz) ^ 2)
				else 0
			if spot and distance > bestDistance then
				best, bestDistance = spot, distance
			end
			if bestDistance >= BlinkMin then
				break
			end
		end
		if best then
			RoamService.teleport(model, best.x, best.z, 1)
		end
		return
	end

	if attack.kind == "Charge" then
		RoamService.moveTo(model, windup.ax, windup.az, AttackConfig.ChargeSeconds, 0.8)
	end
	if not hunters then
		return
	end
	for _, target in hunters do
		if Attacks.hits(attack, windup.mx, windup.mz, windup.ax, windup.az, target.x, target.z) then
			hitPlayer(target.player, brain, attack, windup, target)
		elseif target.player == brain.target then
			Hit:FireClient(target.player, "Dodged", 0, 0, 0) -- it was after you and you got out
		end
	end
end

-- Stops and shows the warning; strike() follows when it runs out.
local function windUp(model: Model, brain: Brain, attack: Attacks.Attack, zoneId: string, target: Target)
	local position = RoamService.position(model)
	if not position then
		return
	end
	local _, radius = RoamService.area(model)
	local at = now()
	local ax, az = Attacks.aim(attack, position.X, position.Z, target.x, target.z)
	local windup: Windup = {
		hitTime = at + AttackConfig.WindupSeconds,
		mx = position.X,
		mz = position.Z,
		ax = ax,
		az = az,
	}
	brain.windup = windup
	RoamService.stop(model, AttackConfig.WindupSeconds + 0.1)

	local warning: Warning = {
		kind = attack.kind,
		model = model,
		harmful = attack.damage > 0,
		fromX = windup.mx,
		fromZ = windup.mz,
		toX = ax,
		toZ = az,
		y = position.Y - radius - 0.5,
		radius = attack.radius,
		hitTime = windup.hitTime,
	}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Zone") == zoneId then
			Warn:FireClient(player, warning)
		end
	end
end

local function step()
	local at = now()
	local byZone = huntersByZone()

	-- How many monsters are already after each hunter.
	local attackers: { [Player]: number } = {}
	for _, brain in brains do
		local target = brain.target
		if target then
			attackers[target] = (attackers[target] or 0) + 1
		end
	end

	for model, spawned in SpawnService.all() do
		if spawned.reservedFor then
			continue -- a Bait Bell's monster came to be caught, not to fight
		end
		local brain = brainFor(model, spawned)
		local attack = brain.attack
		local zone = Hunt.zoneByIndex(spawned.zone)
		if not attack or not zone then
			continue
		end
		local hunters = byZone[zone.id]

		-- Caught in a vacuum beam: no attacking, and a moment to recover once let go.
		if RoamService.isHeld(model) then
			brain.windup = nil
			brain.target = nil
			brain.readyAt = math.max(brain.readyAt, at + AttackConfig.FirstAttackDelay)
			continue
		end

		local windup = brain.windup
		if windup then
			if at >= windup.hitTime then
				strike(model, brain, attack, windup, hunters)
			end
			continue
		end
		if at < brain.readyAt or not hunters then
			if not hunters then
				brain.target = nil
			end
			continue
		end

		local position = RoamService.position(model)
		if not position then
			continue
		end

		-- A Blink is a dodge, not a hunt: it doesn't chase, it just vanishes when you get close.
		if attack.kind == "Blink" then
			for _, hunter in hunters do
				local close = math.sqrt((hunter.x - position.X) ^ 2 + (hunter.z - position.Z) ^ 2)
					<= attack.range
				if close and at >= (arrivedAt[hunter.player] or 0) + AttackConfig.ArrivalGraceSeconds then
					windUp(model, brain, attack, zone.id, hunter)
					break
				end
			end
			continue
		end

		local candidates: { Attacks.Hunter } = {}
		for _, hunter in hunters do
			table.insert(candidates, {
				x = hunter.x,
				z = hunter.z,
				attackers = attackers[hunter.player] or 0,
				mine = brain.target == hunter.player,
			})
		end
		local index = Attacks.pickTarget(position.X, position.Z, candidates)
		local target = if index then hunters[index] else nil
		if brain.target ~= (target and target.player) then
			local old = brain.target
			if old then
				attackers[old] = (attackers[old] or 1) - 1
			end
			if target then
				attackers[target.player] = (attackers[target.player] or 0) + 1
			end
			brain.target = if target then target.player else nil
		end
		if not target or at < (arrivedAt[target.player] or 0) + AttackConfig.ArrivalGraceSeconds then
			continue
		end

		local dx, dz = target.x - position.X, target.z - position.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance <= attack.range then
			windUp(model, brain, attack, zone.id, target)
		elseif at >= brain.nextChase then
			brain.nextChase = at + ChaseStepSeconds
			local cx, cz = Attacks.chaseSpot(position.X, position.Z, target.x, target.z, attack.range)
			local speed = (RoamService.speed(model) or 6) * AttackConfig.ChaseSpeed
			local length = math.sqrt((cx - position.X) ^ 2 + (cz - position.Z) ^ 2)
			RoamService.moveTo(model, cx, cz, length / speed, 0.5)
		end
	end
end

-- Studio /attack: the closest monster in the hunter's zone winds up an attack on them right
-- now, skipping its cooldown and the arrival grace. False if there is none to do it.
function MonsterAiService.provoke(player: Player): boolean
	local zone = Hunt.zoneById(player:GetAttribute("Zone"))
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not zone or not root or not root:IsA("BasePart") then
		return false
	end
	local hunter: Target = { player = player, x = root.Position.X, z = root.Position.Z }
	local best: Model? = nil
	local bestDistance = math.huge
	for model, spawned in SpawnService.all() do
		local brain = brainFor(model, spawned)
		local position = RoamService.position(model)
		if
			spawned.zone == zone.index
			and not spawned.reservedFor
			and brain.attack
			and not brain.windup
			and position
			and not RoamService.isHeld(model)
		then
			local distance = math.sqrt((position.X - hunter.x) ^ 2 + (position.Z - hunter.z) ^ 2)
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	local brain = best and brains[best]
	local attack = brain and brain.attack
	if not best or not brain or not attack then
		return false
	end
	lastHit[player] = nil
	brain.target = player
	windUp(best, brain, attack, zone.id, hunter)
	return true
end

function MonsterAiService.start()
	remotes.Parent = ReplicatedStorage

	local function watch(player: Player)
		player:GetAttributeChangedSignal("Zone"):Connect(function()
			if player:GetAttribute("Zone") ~= nil then
				arrivedAt[player] = now()
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
		arrivedAt[player] = nil
		slowToken[player] = nil
		for _, brain in brains do
			if brain.target == player then
				brain.target = nil
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TickSeconds)
			-- One bad monster must never stop the others from fighting back.
			xpcall(step, function(err)
				warn(`MonsterAiService: {err}\n{debug.traceback()}`)
			end)
		end
	end)
end

return MonsterAiService
