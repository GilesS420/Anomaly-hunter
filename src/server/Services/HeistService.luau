--!strict
-- Monster Heists (Sprint E; rules in Util/Heists, numbers in Config/Heists). Every mansion's
-- worth sign has a "Rob this mansion" prompt for the other players. It uses one Heist Charge
-- (Robux, Config/Robux.Products HeistCharge and HeistBundle) and starts the heist:
--   1. Inside: the owner hears an alarm and everyone sees THIEF over the thief's head. The
--      thief has Config.InsideSeconds to vacuum one roaming monster that isn't hearted, with
--      the normal catch and its struggles (CatchService asks HeistService.target).
--   2. Carrying: the monster rides on the thief's head (its orb leaves the mansion, but it
--      stays in the owner's save) and the thief walks slower. Reaching their own plot within
--      Config.CarrySeconds makes it theirs (Util/Heists.handOver).
-- A slap (SlapService), getting knocked out, walking into a zone, teleporting or running out of
-- time ends the heist and the monster flies back home. The charge is used up then; it's given
-- back only when the owner leaves mid-heist. Nobody is robbed while offline or in another
-- server, in the tutorial, in their first 2 hours, with a mansion worth under $1M, more than
-- twice a day or twice by the same thief a day (Util/Heists.blocked).
--
-- Player attributes (on the thief):
--   Stealing      true during a heist (SlapService locks a slapped thief with StealLockedUntil)
--   HeistOwner    the robbed owner's UserId
--   HeistPhase    "Inside" or "Carrying"
--   HeistEndsAt   server time the current phase runs out
--   HeistCharges  charges left (set on every player, by RobuxService too)
-- Remotes in ReplicatedStorage.HeistRemotes:
--   Alarm   server -> owner (thief: Player)   someone started robbing your mansion

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Heists)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Heists = require(ReplicatedStorage.Shared.Util.Heists)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Mansion = require(ReplicatedStorage.Shared.Util.Mansion)
local Missions = require(ReplicatedStorage.Shared.Util.Missions)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Robux = require(ReplicatedStorage.Shared.Config.Robux)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)
local PlotService = require(script.Parent.PlotService)

local HeistService = {}

-- What CatchService needs to know about a monster a thief may vacuum (the same shape as a
-- wild monster in SpawnService).
export type Target = { monsterId: string, rarity: string, size: string, zone: number, reservedFor: number? }

type Heist = {
	owner: Player,
	phase: "Inside" | "Carrying",
	endsAt: number, -- server time
	uid: string?, -- the monster being carried off
	name: string?, -- its name, for messages
	copy: Model?, -- the copy on the thief's head
	lastX: number?, -- where the thief was at the last check (teleport check)
	lastZ: number?,
}

local CheckSeconds = 0.25
local PlaySeconds = 30 -- how often play time is counted
local PromptName = "HeistPrompt"

local heists: { [Player]: Heist } = {}

local remotes = Instance.new("Folder")
remotes.Name = "HeistRemotes"
local Alarm = Instance.new("RemoteEvent")
Alarm.Name = "Alarm"
Alarm.Parent = remotes

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- The owner's heist on now, by its thief, or nil.
local function robbing(owner: Player): Player?
	for thief, heist in heists do
		if heist.owner == owner then
			return thief
		end
	end
	return nil
end

-- What the monsters roaming the mansion sell for together.
local function worthOf(data: DataService.Data): number
	local values = {}
	for index, caught in data.monsters do
		local ok, value = pcall(Value.sellValue, caught, data.wingsOwned)
		values[index] = if ok then value else 0
	end
	return (Mansion.worth(values))
end

local function find(data: DataService.Data, uid: string): Value.CaughtMonster?
	for _, list in { data.monsters, data.storage } do
		for _, caught in list do
			if caught.uid == uid then
				return caught
			end
		end
	end
	return nil
end

-- True if (x, z) is on the player's own plot.
local function onOwnPlot(player: Player, position: Vector3): boolean
	local plot = PlotService.get(player)
	if not plot then
		return false
	end
	local here = plot.frame:PointToObjectSpace(position)
	return math.abs(here.X) <= Layout.PlotSize.x / 2 and math.abs(here.Z) <= Layout.PlotSize.z / 2
end

local function dropCopy(heist: Heist)
	if heist.copy then
		heist.copy:Destroy()
		heist.copy = nil
	end
end

-- A copy of the stolen monster on the thief's head, at its mansion size, so everyone can see
-- who has it.
local function carryCopy(thief: Player, caught: Value.CaughtMonster): Model?
	local character = thief.Character
	local head = character and character:FindFirstChild("Head")
	local monster = Monsters[caught.monsterId]
	if not character or not head or not head:IsA("BasePart") or not monster then
		return nil
	end
	local radius = MonsterModel.radius(caught.size, caught.monsterId, caught.kg)
	local model = MonsterModel.build({
		monsterId = caught.monsterId,
		rarity = monster.rarity,
		size = caught.size,
		kg = caught.kg,
		roamRadius = MonsterModel.roamRadius(radius),
		effects = Value.resolveEffects(caught.effects),
		variant = caught.variant,
	})
	model.Name = "StolenMonster"
	local body = model.PrimaryPart :: BasePart
	for _, child in body:GetChildren() do
		if child:IsA("BillboardGui") or child:IsA("PointLight") then
			child:Destroy()
		end
	end
	if body.Transparency >= 1 then
		body.Size = Vector3.one * 0.2 -- see InventoryService.monsterTool
	end
	local box, boxSize = model:GetBoundingBox()
	local fromBottom = (box * CFrame.new(0, -boxSize.Y / 2, 0)):ToObjectSpace(body.CFrame)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = head
	weld.Part1 = body
	weld.C0 = CFrame.new(0, head.Size.Y / 2 + 0.6, 0) * fromBottom
	weld.Parent = body
	model.Parent = character
	return model
end

local function clearAttributes(thief: Player)
	thief:SetAttribute("Stealing", nil)
	thief:SetAttribute("HeistOwner", nil)
	thief:SetAttribute("HeistPhase", nil)
	thief:SetAttribute("HeistEndsAt", nil)
end

-- Ends a heist that didn't work out: the monster (if any) flies back home. refund gives the
-- charge back.
local function fail(thief: Player, toThief: string?, toOwner: string?, refund: boolean?)
	local heist = heists[thief]
	if not heist then
		return
	end
	heists[thief] = nil
	clearAttributes(thief)
	dropCopy(heist)
	if heist.uid then
		MansionService.unhide(heist.owner, heist.uid)
	end
	if refund then
		local data = DataService.get(thief)
		if data then
			data.heist.charges += 1
			thief:SetAttribute("HeistCharges", data.heist.charges)
		end
	end
	if toThief then
		Notify.toast(thief, toThief)
	end
	if toOwner then
		Notify.toast(heist.owner, toOwner)
	end
end

-- The thief made it home: the monster moves from the owner's save into theirs.
local function deliver(thief: Player, heist: Heist)
	local uid = heist.uid :: string
	local name = heist.name or "monster"
	local owner = heist.owner
	local ownerData = DataService.get(owner)
	local thiefData = DataService.get(thief)
	local caught = if ownerData then find(ownerData, uid) else nil
	if not ownerData or not thiefData or not caught then
		fail(thief, `The {name} slipped away!`, nil)
		return
	end
	if not MansionService.hasRoom(thief) then
		fail(thief, `No room at home! The {name} flew back to {owner.DisplayName}.`, `Your {name} came back!`)
		return
	end
	heists[thief] = nil
	clearAttributes(thief)
	dropCopy(heist)
	MansionService.removeMonsters(owner, { [uid] = true })
	MansionService.unhide(owner, uid) -- not in the save any more, so this just forgets it
	Heists.handOver(caught, os.time())
	local where = MansionService.addMonster(thief, caught)
	if not where then
		-- Room went between the check and now: it goes back rather than vanish.
		MansionService.addMonster(owner, caught)
		Notify.toast(thief, `No room at home! The {name} flew back to {owner.DisplayName}.`)
		return
	end
	Heists.rollDay(ownerData.heist, Missions.day(os.time()))
	Heists.noteLoss(ownerData.heist, thief.UserId)
	thiefData.heist.stolen += 1
	local monsterName = Format.monsterName(caught)
	local place = if where == "Storage" then "your Storage" else "your mansion"
	Notify.toast(thief, `HEIST DONE! The {monsterName} is yours and roams {place} now.`)
	Notify.toast(owner, `{thief.DisplayName} got away with your {monsterName}!`)
	task.spawn(DataService.saveNow, thief) -- both saves written straight away
	task.spawn(DataService.saveNow, owner)
end

local function start(thief: Player, owner: Player)
	local thiefData = DataService.get(thief)
	local ownerData = DataService.get(owner)
	if not thiefData or not ownerData then
		Notify.toast(thief, "Still loading. Try again in a moment!")
		return
	end
	if thief == owner then
		return
	end
	local now = workspace:GetServerTimeNow()
	Heists.rollDay(ownerData.heist, Missions.day(os.time()))
	local stealable = 0
	for _, caught in ownerData.monsters do
		if Heists.canTake(caught) then
			stealable += 1
		end
	end
	local locked = thief:GetAttribute("StealLockedUntil")
	local lockedUntil = if typeof(locked) == "number" then locked else 0
	local reason = Heists.blocked({
		tutorial = owner:GetAttribute("Tutorial") ~= nil,
		playSeconds = ownerData.heist.playSeconds,
		shield = Config.ShieldInStudio or not RunService:IsStudio(),
		worth = worthOf(ownerData),
		stealable = stealable,
		record = ownerData.heist,
		beingRobbed = robbing(owner) ~= nil,
	}, {
		userId = thief.UserId,
		tutorial = thief:GetAttribute("Tutorial") ~= nil,
		inHeist = heists[thief] ~= nil,
		lockedUntil = lockedUntil,
		charges = thiefData.heist.charges,
		hasRoom = MansionService.hasRoom(thief),
	}, now)
	if reason then
		Notify.toast(thief, Heists.message(reason, owner.DisplayName, lockedUntil - now))
		local product = Robux.Products.HeistCharge
		if reason == "NoCharge" and product.id ~= 0 then
			MarketplaceService:PromptProductPurchase(thief, product.id)
		end
		return
	end

	thiefData.heist.charges -= 1
	thief:SetAttribute("HeistCharges", thiefData.heist.charges)
	DataService.saveSoon(thief)
	local root = rootOf(thief)
	heists[thief] = {
		owner = owner,
		phase = "Inside",
		endsAt = now + Config.InsideSeconds,
		lastX = root and root.Position.X,
		lastZ = root and root.Position.Z,
	}
	thief:SetAttribute("Stealing", true)
	thief:SetAttribute("HeistOwner", owner.UserId)
	thief:SetAttribute("HeistPhase", "Inside")
	thief:SetAttribute("HeistEndsAt", now + Config.InsideSeconds)
	Alarm:FireClient(owner, thief)
	Notify.toast(
		thief,
		`HEIST! Vacuum one of {owner.DisplayName}'s monsters within {Config.InsideSeconds} seconds. Hearted ones can't be taken.`
	)
	Notify.toast(owner, `ALARM! {thief.DisplayName} is robbing your mansion! Slap them to stop it.`)
end

-- A mansion monster this thief may vacuum right now, or nil. The second value says why not,
-- when that's worth telling them.
function HeistService.target(thief: Player, model: Model): (Target?, string?)
	local heist = heists[thief]
	if not heist or heist.phase ~= "Inside" or model:GetAttribute("OwnerId") ~= heist.owner.UserId then
		return nil, nil
	end
	local home = MansionService.model(heist.owner)
	local uid = model:GetAttribute("Uid")
	local data = DataService.get(heist.owner)
	if not home or not model:IsDescendantOf(home) or typeof(uid) ~= "string" or not data then
		return nil, nil
	end
	local caught = nil
	for _, monster in data.monsters do
		if monster.uid == uid then
			caught = monster
		end
	end
	local monster = if caught then Monsters[caught.monsterId] else nil
	if not caught or not monster then
		return nil, nil
	end
	if not Heists.canTake(caught) then
		return nil, "That one is hearted, so it can't be stolen. Pick another!"
	end
	return { monsterId = caught.monsterId, rarity = monster.rarity, size = caught.size, zone = 0 }, nil
end

-- The thief finished vacuuming `model` (CatchService): off it goes on their head. False if
-- the heist is over or it can't be taken any more.
function HeistService.grab(thief: Player, model: Model): boolean
	local target = HeistService.target(thief, model)
	local heist = heists[thief]
	local uid = model:GetAttribute("Uid")
	local data = if heist then DataService.get(heist.owner) else nil
	local caught = if data and typeof(uid) == "string" then find(data, uid) else nil
	if not target or not heist or not caught or typeof(uid) ~= "string" then
		return false
	end
	local now = workspace:GetServerTimeNow()
	heist.phase = "Carrying"
	heist.uid = uid
	heist.name = Format.monsterName(caught)
	heist.endsAt = now + Config.CarrySeconds
	MansionService.hide(heist.owner, uid)
	heist.copy = carryCopy(thief, caught)
	thief:SetAttribute("HeistPhase", "Carrying")
	thief:SetAttribute("HeistEndsAt", heist.endsAt)
	Notify.toast(
		thief,
		`Got the {heist.name}! Run it to your own mansion within {Config.CarrySeconds} seconds. One slap and it flies back!`
	)
	Notify.toast(
		heist.owner,
		`{thief.DisplayName} has your {heist.name}! Slap them before they reach their mansion!`
	)
	return true
end

-- True if this mansion monster is being carried off right now (so its owner can't heart,
-- move or sell it until the heist is over).
function HeistService.isCarried(owner: Player, uid: string): boolean
	for _, heist in heists do
		if heist.owner == owner and heist.uid == uid then
			return true
		end
	end
	return false
end

-- SlapService: someone slapped this player while they were stealing.
function HeistService.slapped(thief: Player, slapper: Player)
	local heist = heists[thief]
	if not heist then
		return
	end
	local name = heist.name
	if name then
		local hero = if slapper == heist.owner then "You" else slapper.DisplayName
		fail(thief, `The {name} flew back to {heist.owner.DisplayName}!`, `{hero} got your {name} back!`)
	else
		fail(thief, "Heist over!", `{slapper.DisplayName} stopped the thief!`)
	end
end

-- Checks every heist going on.
local function update()
	local now = workspace:GetServerTimeNow()
	for thief, heist in heists do
		local name = heist.name or "monster"
		local root = rootOf(thief)
		if not alive(thief) or not root then
			fail(
				thief,
				"You were knocked out. Heist over!",
				if heist.name then `Your {name} came back!` else nil
			)
		elseif thief:GetAttribute("Zone") ~= nil then
			fail(
				thief,
				"You left for a zone. Heist over!",
				if heist.name then `Your {name} came back!` else nil
			)
		elseif now > heist.endsAt then
			if heist.phase == "Inside" then
				fail(thief, "Time's up! You didn't grab a monster.", "The thief gave up!")
			else
				fail(thief, `Too slow! The {name} flew back home.`, `Your {name} came back!`)
			end
		else
			local position = root.Position
			if
				heist.lastX
				and heist.lastZ
				and Heists.teleported(position.X - heist.lastX, position.Z - heist.lastZ, CheckSeconds)
			then
				fail(
					thief,
					`No fast travel during a heist! The {name} flew back home.`,
					if heist.name then `Your {name} came back!` else nil
				)
			elseif heist.phase == "Carrying" and onOwnPlot(thief, position) then
				deliver(thief, heist)
			else
				heist.lastX = position.X
				heist.lastZ = position.Z
			end
		end
	end
end

-- Puts a "Rob this mansion" prompt on every mansion's worth sign that doesn't have one yet.
local function addPrompts()
	for _, owner in Players:GetPlayers() do
		local home = MansionService.model(owner)
		local sign = home and home:FindFirstChild("WorthSign")
		local board = sign and sign:FindFirstChild("Board")
		if board and board:IsA("BasePart") and not board:FindFirstChild(PromptName) then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = PromptName
			prompt.ActionText = "Rob this mansion"
			prompt.ObjectText = "Monster Heist (1 charge)"
			prompt.HoldDuration = 1
			prompt.MaxActivationDistance = Config.DoorReach
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.H
			prompt:SetAttribute("OwnerId", owner.UserId) -- the owner's own client hides it
			prompt.Triggered:Connect(function(thief)
				-- A cheat can fire a prompt from anywhere: check they really are at the sign.
				local root = rootOf(thief)
				if root and (root.Position - board.Position).Magnitude <= Config.DoorReach + 8 then
					start(thief, owner)
				end
			end)
			prompt.Parent = board
		end
	end
end

function HeistService.start()
	remotes.Parent = ReplicatedStorage
	DataService.onLoaded(function(player, data)
		player:SetAttribute("HeistCharges", data.heist.charges)
	end)

	local waited, promptWait, playWait = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		promptWait += dt
		playWait += dt
		if waited >= CheckSeconds then
			waited = 0
			update()
		end
		if promptWait >= 1 then
			promptWait = 0
			addPrompts()
		end
		if playWait >= PlaySeconds then
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					data.heist.playSeconds += playWait
				end
			end
			playWait = 0
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- The thief left: the monster flies home. The owner left: the heist is off and the
		-- thief gets the charge back (nobody is robbed offline).
		fail(
			player,
			nil,
			if heists[player] and heists[player].name then "The thief left. Your monster came back!" else nil
		)
		for thief, heist in heists do
			if heist.owner == player then
				fail(
					thief,
					`{player.DisplayName} left, so the heist is off. You got your charge back.`,
					nil,
					true
				)
			end
		end
	end)
end

return HeistService
