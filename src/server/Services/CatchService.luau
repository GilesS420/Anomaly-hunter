--!strict
-- Catching: click or tap a wild monster. It freezes in your vacuum's beam and a catch meter
-- fills by itself (1-3 seconds, longer for rarer monsters); no holding (Giles 2026-10-22).
-- On the way the monster struggles (Config/Struggles): the meter stops and you must tap while
-- a sweeping needle is in a zone. Miss, or wait too long, and it breaks free. Rare and event
-- monsters then throw the Lucky Ring: tap as it lines up and the catch lands at once with a
-- better shot at a variant; miss and the meter drops back to half. Walking out of
-- reach or getting knocked out lets it escape too (dazed for a moment, so you can grab it
-- again).
-- The client only says "start catching this", "stop" and "tapped at"; every rule is checked
-- here.
--
-- Remotes in ReplicatedStorage.CatchRemotes:
--   StartCatch  client -> server (model)
--   StopCatch   client -> server () lets go (the client doesn't send it any more since
--               catching stopped needing a hold; kept so an older client can't break it)
--   Strike      client -> server (serverTime the player tapped)
--   State       server -> client ("Holding", {model, seconds}), ("Struggle", {model, startedAt,
--               speed, centre, width, timeout}), ("Struggled", {model}), ("Ring", {model,
--               startedAt, seconds, startScale, window}), ("Ringed", {model, hit}) or ("Ended",
--               {result, model})

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catching = require(ReplicatedStorage.Shared.Util.Catching)
local Struggles = require(ReplicatedStorage.Shared.Config.Struggles)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Hunt = require(ReplicatedStorage.Shared.Util.Hunt)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local MansionService = require(script.Parent.MansionService)
local Notify = require(script.Parent.Parent.Notify)
local RoamService = require(script.Parent.RoamService)
local SpawnService = require(script.Parent.SpawnService)
local WatcherService = require(script.Parent.WatcherService)

local CatchService = {}

type Hold = {
	model: Model,
	name: string, -- monster's display name, for messages
	zoneId: string, -- the zone the monster lives in; the hunter must stay in it ("" = main area)
	reach: number,
	stunSeconds: number,
	total: number, -- seconds of filling to catch it
	filled: number, -- seconds filled before fillStart
	fillStart: number, -- server time the meter last started filling
	plan: Catching.StrugglePlan,
	nextMark: number, -- index into plan.marks of the next struggle
	struggle: { startedAt: number, centre: number }?, -- the struggle going on now
	ring: number?, -- server time the Lucky Ring appeared, while it's up
	ringDone: boolean, -- the Lucky Ring has come (once per catch)
	glow: Highlight,
	beam: Beam,
	from: Attachment, -- on the hunter
	to: Attachment, -- on the monster
	died: RBXScriptConnection?,
}

local StartCooldown = 0.25 -- seconds between StartCatch requests (stops spam)
local random = Random.new()

local holds: { [Player]: Hold } = {}
local heldBy: { [Model]: Player } = {}
local lastStart: { [Player]: number } = {}
local pendingStart: { [Player]: Model } = {} -- a quick re-press waiting for the cooldown to pass

local remotes = Instance.new("Folder")
remotes.Name = "CatchRemotes"
local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
local StartCatch = remote("StartCatch") -- client -> server: (model)
local StopCatch = remote("StopCatch") -- client -> server: ()
local Strike = remote("Strike") -- client -> server: (serverTime of the tap)
local State = remote("State") -- server -> client: ("Holding" | "Struggle" | "Struggled" | "Ring" | "Ringed" | "Ended", info)

-- Shop names by item id ("PhantomVac" -> "Phantom Vac"), and vacuum names by tier.
local itemNames: { [string]: string } = {}
local vacuumByTier: { [number]: string } = {}
for _, item in Shop.Workshop do
	itemNames[item.id] = item.name
	if item.kind == "Vacuum" and item.tier then
		vacuumByTier[item.tier] = item.name
	end
end

local function itemName(id: string): string
	return itemNames[id] or Format.name(id)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- True while the hunter is alive and still in this zone (not knocked out, not gone home).
-- zoneId "" is the main area (Watcher event monsters): the hunter must not be in a zone.
local function isHunting(player: Player, zoneId: string): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local wanted = if zoneId == "" then nil else zoneId
	return humanoid ~= nil and humanoid.Health > 0 and player:GetAttribute("Zone") == wanted
end

-- A live wild monster: in a zone (SpawnService) or, during a Watcher event, in the main area.
local function wildMonster(model: Model): SpawnService.Spawned?
	return SpawnService.get(model) or WatcherService.get(model)
end

-- Studs from the hunter to where the monster really is (math.huge if either is missing).
local function distanceTo(player: Player, model: Model): number
	local root = rootOf(player)
	local position = RoamService.position(model) or (model.PrimaryPart and model.PrimaryPart.Position)
	if not root or not position then
		return math.huge
	end
	return (root.Position - position).Magnitude
end

-- Removes the glow, beam and attributes and forgets the hold. Doesn't touch the roaming.
local function clear(player: Player): Hold?
	local hold = holds[player]
	if not hold then
		return nil
	end
	holds[player] = nil
	if heldBy[hold.model] == player then
		heldBy[hold.model] = nil
	end
	if hold.died then
		hold.died:Disconnect()
	end
	hold.beam:Destroy()
	hold.from:Destroy()
	hold.to:Destroy()
	hold.glow:Destroy()
	hold.model:SetAttribute("HeldBy", nil)
	hold.model:SetAttribute("CatchStart", nil)
	hold.model:SetAttribute("CatchEnd", nil)
	hold.model:SetAttribute("CatchPaused", nil)
	return hold
end

-- Lets the monster go (it stays dazed for the vacuum's stun time). message is toasted
-- if given; nil when the player is leaving.
local function release(player: Player, message: string?)
	local hold = clear(player)
	if not hold then
		return
	end
	RoamService.release(hold.model, hold.stunSeconds)
	if message then
		Notify.toast(player, message)
	end
	if player.Parent == Players then
		State:FireClient(player, "Ended", { result = "Escaped", model = hold.model })
	end
end

-- lucky: landed with the Lucky Ring (a better shot at a variant).
local function finish(player: Player, lucky: boolean?)
	local hold = clear(player)
	if not hold then
		return
	end
	local model = hold.model
	local data = DataService.get(player)
	if not data or HuntService.isBagFull(player) or not isHunting(player, hold.zoneId) then
		RoamService.release(model, hold.stunSeconds)
		State:FireClient(player, "Ended", { result = "Escaped", model = model })
		return
	end

	local vacuumId = data.equipped.vacuum
	local inHub = hold.zoneId == ""
	if inHub and not MansionService.hasRoom(player) then
		RoamService.release(model, hold.stunSeconds)
		Notify.toast(
			player,
			"Your mansion and Storage are full! Sell some at the Collector or buy a new wing."
		)
		State:FireClient(player, "Ended", { result = "Escaped", model = model })
		return
	end
	local boost = if lucky then Struggles.Ring.variantBoost else nil
	local caught = if inHub
		then WatcherService.capture(model, vacuumId, boost)
		else SpawnService.capture(model, vacuumId, boost)
	if not caught then
		State:FireClient(player, "Ended", { result = "Gone", model = model })
		return
	end
	-- Main-area catches fly straight home; zone catches are carried to the Exit.
	local afterward = "Now bring it to the Exit."
	if inHub then
		afterward = if MansionService.addMonster(player, caught) == "Storage"
			then "Your mansion is full, so it went into Storage (your Backpack)."
			else "It flew straight home to your mansion!"
	else
		HuntService.carry(player, caught)
		local count = player:GetAttribute("CarryingCount")
		local size = player:GetAttribute("BagSize")
		if typeof(count) == "number" and typeof(size) == "number" and count < size then
			afterward = `Bag {count}/{size}: catch another or bring them to the Exit.`
		elseif typeof(size) == "number" and size > 1 then
			afterward = "Your bag is full! Bring them to the Exit."
		end
	end

	local bonus = ""
	if #caught.effects > 0 then
		local names = {}
		for _, effectId in caught.effects do
			table.insert(names, Format.name(effectId))
		end
		bonus = ` Bonus: {table.concat(names, " and ")}!`
	end
	local variant = if caught.variant then `{caught.variant} ` else ""
	local perfect = if lucky then "PERFECT CATCH! " else ""
	Notify.toast(player, `{perfect}Caught a {variant}{caught.size} {hold.name}!{bonus} {afterward}`)
	State:FireClient(player, "Ended", { result = "Caught", monsterId = caught.monsterId, model = model })
end

local function onStartCatch(player: Player, model: unknown)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end

	-- 1. Save loaded, not already catching, not spamming.
	local data = DataService.get(player)
	if not data then
		Notify.toast(player, "Your save is still loading. Try again in a moment!")
		return
	end
	if holds[player] then
		return
	end
	local now = os.clock()
	local remaining = StartCooldown - (now - (lastStart[player] or 0))
	if remaining > 0 then
		-- A quick re-press (a double tap): start it once the cooldown is over, unless they let
		-- go before then. Dropping it would leave them holding with no meter.
		pendingStart[player] = model
		task.delay(remaining, function()
			if pendingStart[player] == model then
				pendingStart[player] = nil
				onStartCatch(player, model)
			end
		end)
		return
	end
	pendingStart[player] = nil
	lastStart[player] = now

	-- 2. A live wild monster nobody else is catching, in the zone the hunter is in (or both
	-- in the main area), and the hunter is alive (a knocked-out hunter's body can't catch).
	local spawned = wildMonster(model)
	if not spawned then
		return
	end
	local zone = Hunt.zoneByIndex(spawned.zone)
	local zoneId = if spawned.zone == 0 then "" elseif zone then zone.id else nil
	if not zoneId or not isHunting(player, zoneId) then
		return
	end
	if spawned.reservedFor and spawned.reservedFor ~= player.UserId then
		Notify.toast(player, "That one came for someone else's Bait Bell!")
		return
	end
	local name = Format.name(spawned.monsterId)
	local holder = heldBy[model]
	if holder then
		if holder ~= player then
			Notify.toast(player, "Someone else is catching that one!")
		end
		return
	end

	-- 3. A vacuum in your hand (holding it also made it the vacuum you use).
	if not HuntService.heldVacuum(player) then
		Notify.toast(player, "Hold your vacuum to catch! Pick it in your hotbar.")
		return
	end

	-- 4. Room in the bag.
	if HuntService.isBagFull(player) then
		Notify.toast(player, "Your bag is full. Bring your catch home first!")
		return
	end

	-- 5. Room at home.
	if not MansionService.hasRoom(player) then
		Notify.toast(
			player,
			"Your mansion and Storage are full! Sell some at the Collector or buy a new wing."
		)
		return
	end

	-- 6. Close enough for the vacuum's beam.
	local vacuumId = data.equipped.vacuum
	local reach = Catching.reach(vacuumId)
	if distanceTo(player, model) > reach then
		local shown = math.floor(reach - Tools.ReachSlack)
		Notify.toast(player, `Get closer! Your {itemName(vacuumId)} reaches {shown} studs.`)
		return
	end

	-- 7. Strong enough vacuum. Event monsters name the vacuum they need.
	if not Catching.strongEnough(vacuumId, spawned.monsterId) then
		local needed = Catching.neededVacuum(spawned.monsterId) :: string
		Notify.toast(player, `Too strong! You need the {itemName(needed)} or a better vacuum.`)
		return
	end
	if not Catching.canVacuum(vacuumId, spawned.size, spawned.rarity) then
		local tier = Catching.requiredTier(spawned.size, spawned.rarity)
		local vacuumName = vacuumByTier[tier]
		local which = if vacuumName then ` (the {vacuumName})` else ""
		Notify.toast(player, `Too strong! You need a tier {tier} vacuum{which}.`)
		return
	end

	local root = rootOf(player)
	local body = model.PrimaryPart
	if not root or not body then
		return
	end

	-- Start holding: freeze it, light it up, and draw a beam from the hunter to it.
	RoamService.hold(model)
	local seconds = Catching.catchSeconds(vacuumId, spawned.rarity)
	local serverNow = workspace:GetServerTimeNow()
	local plan = Catching.strugglePlan(spawned.rarity, spawned.size)
	model:SetAttribute("HeldBy", player.UserId)
	model:SetAttribute("CatchStart", serverNow)
	model:SetAttribute("CatchEnd", serverNow + seconds)

	local glow = Instance.new("Highlight")
	glow.Name = "CatchGlow"
	glow.FillColor = Color3.fromRGB(255, 250, 200)
	glow.FillTransparency = 0.5
	glow.OutlineColor = Color3.fromRGB(255, 255, 255)
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = model

	local from = Instance.new("Attachment")
	from.Name = "CatchBeamFrom"
	from.Parent = root
	local to = Instance.new("Attachment")
	to.Name = "CatchBeamTo"
	to.Parent = body
	local beam = Instance.new("Beam")
	beam.Name = "CatchBeam"
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 245, 180))
	beam.Transparency = NumberSequence.new(0.2, 0.6)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = 0.4
	beam.Width1 = 1.6
	beam.Segments = 1
	beam.Parent = body

	local hold: Hold = {
		model = model,
		name = name,
		zoneId = zoneId,
		reach = reach,
		stunSeconds = Catching.stunSeconds(vacuumId),
		total = seconds,
		filled = 0,
		fillStart = serverNow,
		plan = plan,
		nextMark = 1,
		struggle = nil,
		ring = nil,
		ringDone = false,
		glow = glow,
		beam = beam,
		from = from,
		to = to,
		died = nil,
	}
	holds[player] = hold
	heldBy[model] = player

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		hold.died = humanoid.Died:Connect(function()
			release(player, `{name} got away!`)
		end)
	end

	State:FireClient(player, "Holding", { model = model, seconds = seconds })
end

-- The meter stops and the monster struggles: the client shows the needle and the zone.
local function beginStruggle(player: Player, hold: Hold, serverNow: number)
	hold.filled = hold.plan.marks[hold.nextMark] * hold.total
	hold.nextMark += 1
	local centre = Catching.zoneCentre(hold.plan.zone, random)
	hold.struggle = { startedAt = serverNow, centre = centre }
	hold.model:SetAttribute("CatchPaused", hold.filled / hold.total)
	State:FireClient(player, "Struggle", {
		model = hold.model,
		startedAt = serverNow,
		speed = hold.plan.speed,
		centre = centre,
		width = hold.plan.zone,
		timeout = Struggles.TimeoutSeconds,
	})
end

-- The tap landed: the meter fills on from where it stopped.
local function endStruggle(player: Player, hold: Hold, serverNow: number)
	hold.struggle = nil
	hold.fillStart = serverNow
	hold.model:SetAttribute("CatchPaused", nil)
	hold.model:SetAttribute("CatchStart", serverNow - hold.filled)
	hold.model:SetAttribute("CatchEnd", serverNow - hold.filled + hold.total)
	State:FireClient(player, "Struggled", { model = hold.model })
end

-- The Lucky Ring appears: the meter stops while it shrinks.
local function beginRing(player: Player, hold: Hold, serverNow: number)
	hold.filled = (hold.plan.ring :: number) * hold.total
	hold.ring = serverNow
	hold.ringDone = true
	hold.model:SetAttribute("CatchPaused", hold.filled / hold.total)
	local ring = Struggles.Ring
	State:FireClient(player, "Ring", {
		model = hold.model,
		startedAt = serverNow,
		seconds = ring.seconds,
		startScale = ring.startScale,
		window = ring.window,
	})
end

-- Missed the ring: the monster jerks the meter back, then it fills on from there.
local function missRing(player: Player, hold: Hold, serverNow: number)
	hold.ring = nil
	hold.filled = math.min(hold.filled, Struggles.Ring.fallBack * hold.total)
	hold.fillStart = serverNow
	hold.model:SetAttribute("CatchPaused", nil)
	hold.model:SetAttribute("CatchStart", serverNow - hold.filled)
	hold.model:SetAttribute("CatchEnd", serverNow - hold.filled + hold.total)
	State:FireClient(player, "Ringed", { model = hold.model, hit = false })
	Notify.toast(player, `{hold.name} jerked back! Keep going.`)
end

local function onStrike(player: Player, tappedAt: unknown)
	local hold = holds[player]
	if not hold or not (hold.struggle or hold.ring) then
		return
	end
	local serverNow = workspace:GetServerTimeNow()
	-- The client's own clock reading of the tap, so lag doesn't move the needle; trusted only
	-- within LagAllowance of when it arrived.
	local at = if typeof(tappedAt) == "number"
			and tappedAt <= serverNow
			and tappedAt >= serverNow - Struggles.LagAllowance
		then tappedAt
		else serverNow
	local ringAt = hold.ring
	if ringAt then
		if Catching.ringHit(at - ringAt) then
			State:FireClient(player, "Ringed", { model = hold.model, hit = true })
			finish(player, true)
		else
			missRing(player, hold, serverNow)
		end
		return
	end
	local struggle = hold.struggle :: { startedAt: number, centre: number }
	if Catching.struggleHit(at - struggle.startedAt, hold.plan.speed, struggle.centre, hold.plan.zone) then
		endStruggle(player, hold, serverNow)
	else
		release(player, `{hold.name} broke free! Tap when the needle is in the zone.`)
	end
end

-- Checks every catch in progress each frame.
local function update()
	local serverNow = workspace:GetServerTimeNow()
	for player, hold in holds do
		local struggle = hold.struggle
		if wildMonster(hold.model) == nil then
			-- Gone (cleared by an event, or the zone was removed).
			clear(player)
			State:FireClient(player, "Ended", { result = "Gone", model = hold.model })
		elseif not isHunting(player, hold.zoneId) then
			-- Knocked out or went home (Exit, Return Charm): it just stays behind, no message.
			release(player, nil)
		elseif distanceTo(player, hold.model) > hold.reach then
			release(player, `{hold.name} got away!`)
		elseif struggle then
			if serverNow - struggle.startedAt > Struggles.TimeoutSeconds + Struggles.LagAllowance then
				release(player, `{hold.name} broke free! Tap when the needle is in the zone.`)
			end
		elseif hold.ring then
			if serverNow - hold.ring > Struggles.Ring.seconds + Struggles.LagAllowance then
				missRing(player, hold, serverNow)
			end
		else
			local filled = hold.filled + (serverNow - hold.fillStart)
			local mark = hold.plan.marks[hold.nextMark]
			local ring = hold.plan.ring
			if mark and filled >= mark * hold.total then
				beginStruggle(player, hold, serverNow)
			elseif ring and not hold.ringDone and filled >= ring * hold.total then
				beginRing(player, hold, serverNow)
			elseif filled >= hold.total then
				finish(player)
			end
		end
	end
end

-- A monster hit the hunter: whatever they were catching gets away (message is toasted).
function CatchService.interrupt(player: Player, message: string)
	if holds[player] then
		release(player, message)
	end
end

function CatchService.start()
	remotes.Parent = ReplicatedStorage

	StartCatch.OnServerEvent:Connect(onStartCatch)
	Strike.OnServerEvent:Connect(onStrike)
	StopCatch.OnServerEvent:Connect(function(player)
		pendingStart[player] = nil
		local hold = holds[player]
		if hold and not hold.struggle and not hold.ring then -- an old client lets go to tap
			release(player, `{hold.name} got away!`)
		end
	end)

	RunService.Heartbeat:Connect(update)

	Players.PlayerRemoving:Connect(function(player)
		release(player, nil)
		lastStart[player] = nil
		pendingStart[player] = nil
	end)
end

return CatchService
