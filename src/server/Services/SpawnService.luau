--!strict
-- Keeps each zone stocked with wandering monsters (Spawning.aliveTarget: 12, more when the
-- zone is crowded with hunters). Per zone it reads
--   Workspace.Zones.<ZoneId>.RoamArea     a Part (or a Folder/Model of Parts) the monsters wander over
--   Workspace.Zones.<ZoneId>.SpawnPoints  (older zones) parts; each one becomes a 30x30 area around it
-- WorldBuilder makes all of this as grey placeholders if it's missing.
-- RoamArea parts must lie flat; turning them 90 or 180 degrees is fine, tilting them is not.
-- Monsters appear in Workspace.Zones.<ZoneId>.Monsters, never inside another monster: if the
-- zone is too crowded, the spawn waits and tries again later.
-- Wild monsters wander off after a minute or two (unless someone is catching them) and a fresh
-- one takes their place, so monsters too strong for anyone here don't pile up in a zone.
-- A Bait Bell (SpawnService.lure) brings one extra, rarer monster close to the hunter who rang
-- it; only that hunter can catch it, and it leaves when they do or after LureSeconds.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catching = require(ReplicatedStorage.Shared.Util.Catching)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Roam = require(ReplicatedStorage.Shared.Util.Roam)
local Spawning = require(ReplicatedStorage.Shared.Util.Spawning)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local RoamService = require(script.Parent.RoamService)
local World = require(script.Parent.Parent.World)

local SpawnService = {}

export type Spawned = {
	monsterId: string,
	rarity: string,
	size: string,
	zone: number,
	reservedFor: number?, -- UserId of the hunter whose Bait Bell brought it (only they can catch it)
}

type ZoneState = {
	zone: Zones.Zone,
	folder: Instance, -- Workspace.Zones.<ZoneId>
	monsters: Folder?, -- where spawned models go (made on first spawn)
	rects: { Roam.Rect },
	group: string, -- RoamService group, so orbs only avoid others in the same zone
	alive: number,
	retrying: boolean, -- a "too crowded, try later" refill is already waiting
}

local SpawnPointAreaSize = 30 -- studs; area around each SpawnPoints part when there's no RoamArea
local LifetimeMin, LifetimeMax = 60, 120 -- seconds a wild monster stays before wandering off
local HeldRecheck = 5 -- seconds to wait when it's due to leave but someone is catching it

local LureSeconds = 120 -- how long a Bait Bell's monster waits for its hunter
local LureDistance = 25 -- studs around the hunter where it appears (if there's room)

local random = Random.new()
local live: { [Model]: Spawned } = {}
local states: { [number]: ZoneState } = {} -- by zone index
local lures: { [Player]: Model } = {} -- each hunter's Bait Bell monster, while it's here

-- True if the part is turned a quarter (90 or 270 degrees), so its X size runs along world Z.
local function turnedSideways(part: BasePart): boolean
	local right = part.CFrame.RightVector
	return math.abs(right.Z) > math.abs(right.X)
end

-- Floor rectangles monsters may wander over in this zone (empty if nothing was built).
local function zoneRects(zone: Zones.Zone, zoneFolder: Instance): { Roam.Rect }
	local rects = {}
	local roamArea = World.find(zoneFolder, "RoamArea")
	if roamArea then
		for _, part in World.parts(roamArea) do
			local width, depth = part.Size.X, part.Size.Z
			if turnedSideways(part) then
				width, depth = depth, width
			end
			local top = part.Position.Y + part.Size.Y / 2
			table.insert(rects, Roam.rect(part.Position.X, part.Position.Z, width, depth, top))
		end
		if #rects == 0 then
			warn(`SpawnService: {zone.id} has a RoamArea with no Part in it, so nothing spawns there`)
		end
		return rects
	end

	local spawnPoints = World.find(zoneFolder, "SpawnPoints")
	if spawnPoints then
		for _, part in World.parts(spawnPoints) do
			local top = part.Position.Y + part.Size.Y / 2
			table.insert(
				rects,
				Roam.rect(part.Position.X, part.Position.Z, SpawnPointAreaSize, SpawnPointAreaSize, top)
			)
		end
	end
	if #rects == 0 then
		warn(
			`SpawnService: {zone.id} has nowhere for monsters to roam. Add a flat Part at `
				.. `Workspace > Zones > {zone.id} > RoamArea (it can be invisible)`
		)
	end
	return rects
end

-- The zone's Monsters folder, made if needed. Nil if the zone itself was removed.
local function monstersFolder(state: ZoneState): Folder?
	local existing = state.monsters
	if existing and existing.Parent == state.folder then
		return existing
	end
	if not state.folder:IsDescendantOf(workspace) then
		return nil
	end
	local found = state.folder:FindFirstChild("Monsters")
	local folder: Folder
	if found and found:IsA("Folder") then
		folder = found
	else
		folder = Instance.new("Folder")
		folder.Name = "Monsters"
		folder.Parent = state.folder
	end
	state.monsters = folder
	return folder
end

local refill: (state: ZoneState) -> ()

-- Time's up: the monster leaves the zone (its Destroying handler schedules a fresh one).
-- Never while a hunter is holding it; it waits for them to finish.
local function wanderOff(model: Model)
	if not live[model] then
		return -- already caught
	end
	if RoamService.isHeld(model) then
		task.delay(HeldRecheck, wanderOff, model)
		return
	end
	live[model] = nil
	model:Destroy()
end

-- Spawns one monster at a free spot. False if the zone is too crowded (or gone).
local function spawnOne(state: ZoneState): boolean
	local folder = monstersFolder(state)
	if not folder then
		return false
	end

	local monster = Spawning.rollMonster(state.zone.index, random)
	local size = Spawning.rollSize(random)
	local radius = MonsterModel.radius(size.id)
	local point = Roam.findFreePoint(state.rects, radius, RoamService.bodies(state.group), random)
	if not point then
		return false
	end

	local model = MonsterModel.build({ monsterId = monster.id, rarity = monster.rarity, size = size.id })
	model:SetAttribute("Wild", true)
	model:SetAttribute("Zone", state.zone.index)

	local spawned: Spawned =
		{ monsterId = monster.id, rarity = monster.rarity, size = size.id, zone = state.zone.index }
	live[model] = spawned
	state.alive += 1

	-- However a monster leaves (caught, cleared by an event), replace it after a delay.
	model.Destroying:Connect(function()
		live[model] = nil
		state.alive -= 1
		task.delay(Zones.RespawnSeconds, refill, state)
	end)

	local rarity = Rarities[monster.rarity]
	RoamService.add(model, {
		rects = state.rects,
		radius = radius,
		speed = 6 + 0.5 * (if rarity then rarity.order else 1),
		group = state.group,
		at = Vector3.new(point.x, point.y + radius + 0.5, point.z),
	})
	model.Parent = folder
	task.delay(random:NextNumber(LifetimeMin, LifetimeMax), wanderOff, model)
	return true
end

-- Hunters in this zone right now.
local function huntersIn(zoneId: string): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Zone") == zoneId then
			count += 1
		end
	end
	return count
end

-- Tops the zone up to its alive target (it grows with the hunters in the zone and catches up
-- as monsters leave). When it's too crowded it tries again after RespawnSeconds.
function refill(state: ZoneState)
	local target = Spawning.aliveTarget(huntersIn(state.zone.id))
	while state.alive < target do
		if not spawnOne(state) then
			if not state.retrying and state.folder:IsDescendantOf(workspace) then
				state.retrying = true
				task.delay(Zones.RespawnSeconds, function()
					state.retrying = false
					refill(state)
				end)
			end
			return
		end
	end
end

-- What a spawned model is, or nil if it isn't a live wild monster (already caught, or not one).
function SpawnService.get(model: Model): Spawned?
	return live[model]
end

-- Removes a caught monster from the zone and returns it as a save-ready entry, rolling any
-- catch effects from the hunter's equipped tools. Returns nil if someone caught it first.
function SpawnService.capture(model: Model, equippedItemIds: { string }): Value.CaughtMonster?
	local spawned = live[model]
	if not spawned then
		return nil
	end
	live[model] = nil
	model:Destroy()
	return {
		uid = HttpService:GenerateGUID(false),
		monsterId = spawned.monsterId,
		size = spawned.size,
		effects = Spawning.rollCatchEffects(equippedItemIds, random),
		familiarity = 0,
		fed = true,
	}
end

-- The zone rects, cut down to a square around a point (empty if the point is far from all of them).
local function rectsNear(rects: { Roam.Rect }, x: number, z: number, half: number): { Roam.Rect }
	local near = {}
	for _, rect in rects do
		local minX, maxX = math.max(rect.minX, x - half), math.min(rect.maxX, x + half)
		local minZ, maxZ = math.max(rect.minZ, z - half), math.min(rect.maxZ, z + half)
		if maxX - minX > 4 and maxZ - minZ > 4 then
			table.insert(near, { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ, y = rect.y })
		end
	end
	return near
end

-- A size this vacuum can hold (a bell's monster you can't catch would waste the bell).
local function rollSizeFor(tier: number): string
	for _ = 1, 20 do
		local size = Spawning.rollSize(random)
		if size.vacuumTier <= tier then
			return size.id
		end
	end
	return "Normal"
end

-- Bait Bell: brings one rarer monster near the hunter in their zone. Returns whether it
-- worked and a message for them. The caller uses up the bell only when it worked.
function SpawnService.lure(player: Player, zoneIndex: number, vacuumId: string): (boolean, string)
	local state = states[zoneIndex]
	local folder = if state then monstersFolder(state) else nil
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state or not folder or not root or not root:IsA("BasePart") then
		return false, "Nothing can hear your bell here."
	end
	local existing = lures[player]
	if existing and live[existing] then
		return false, "Your bell's monster is still here. Catch it first!"
	end

	-- One rarity up, but never one the hunter's vacuum can't hold.
	local tier = Catching.vacuumTier(vacuumId)
	local monster = Spawning.rollLured(zoneIndex, random)
	for _ = 1, 20 do
		local rarity = Rarities[monster.rarity]
		if not rarity.vacuumTier or rarity.vacuumTier <= tier then
			break
		end
		monster = Spawning.rollLured(zoneIndex, random)
	end
	local rarity = Rarities[monster.rarity]
	if rarity.vacuumTier and rarity.vacuumTier > tier then
		return false, "Only monsters too strong for your vacuum answered. Try a better vacuum!"
	end
	local size = rollSizeFor(tier)
	local radius = MonsterModel.radius(size)
	local others = RoamService.bodies(state.group)
	local position = root.Position
	local point = Roam.findFreePoint(
		rectsNear(state.rects, position.X, position.Z, LureDistance),
		radius,
		others,
		random
	) or Roam.findFreePoint(state.rects, radius, others, random)
	if not point then
		return false, "It's too crowded here for anything to come. Try again in a moment."
	end

	local model = MonsterModel.build({ monsterId = monster.id, rarity = monster.rarity, size = size })
	model:SetAttribute("Wild", true)
	model:SetAttribute("Zone", zoneIndex)
	model:SetAttribute("LuredBy", player.UserId)
	local body = model.PrimaryPart
	local light = body and body:FindFirstChildOfClass("PointLight")
	if light then
		light.Range *= 2 -- a bell's monster glows brighter so it's easy to spot
		light.Brightness *= 2
	end
	live[model] = {
		monsterId = monster.id,
		rarity = monster.rarity,
		size = size,
		zone = zoneIndex,
		reservedFor = player.UserId,
	}
	lures[player] = model
	model.Destroying:Connect(function()
		live[model] = nil
		if lures[player] == model then
			lures[player] = nil
		end
	end)
	RoamService.add(model, {
		rects = state.rects,
		radius = radius,
		speed = 5, -- slower than the zone's own monsters
		group = state.group,
		at = Vector3.new(point.x, point.y + radius + 0.5, point.z),
	})
	model.Parent = folder

	-- It waits for its hunter: gone when they leave the zone or the game, or after LureSeconds.
	local zoneId = state.zone.id
	task.spawn(function()
		local deadline = os.clock() + LureSeconds
		while live[model] do
			task.wait(1)
			local away = player.Parent == nil or player:GetAttribute("Zone") ~= zoneId
			if live[model] and (away or os.clock() >= deadline) and not RoamService.isHeld(model) then
				live[model] = nil
				model:Destroy()
			end
		end
	end)

	local sizeText = if size == "Normal" then "" else `{size} `
	return true,
		`A {sizeText}{monster.rarity} {Format.name(monster.id)} answers your bell! Only you can catch it.`
end

function SpawnService.start()
	local zonesFolder = World.find(workspace, "Zones")
	if not zonesFolder then
		warn("SpawnService: no Workspace > Zones folder, so no monsters will spawn")
		return
	end
	for _, zone in Zones.List do
		if not zone.launch then
			continue
		end
		local zoneFolder = World.find(zonesFolder, zone.id)
		if not zoneFolder then
			warn(`SpawnService: no Workspace > Zones > {zone.id} folder, so nothing spawns there`)
			continue
		end
		local rects = zoneRects(zone, zoneFolder)
		if #rects == 0 then
			continue
		end
		local state: ZoneState = {
			zone = zone,
			folder = zoneFolder,
			monsters = nil,
			rects = rects,
			group = "Zone:" .. zone.id,
			alive = 0,
			retrying = false,
		}
		states[zone.index] = state
		refill(state)
	end
end

return SpawnService
