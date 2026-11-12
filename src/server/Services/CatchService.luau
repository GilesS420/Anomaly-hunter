--!strict
-- Catching: click or tap a wild monster. It freezes in your vacuum's beam and a catch meter
-- fills by itself (1-3 seconds, longer for rarer monsters); no holding (Giles 2026-10-22).
-- On the way the monster struggles (Config/Struggles): the meter stops and you must tap while
-- a sweeping needle is in a zone. Miss, or wait too long, and it breaks free. Rare and event
-- monsters then throw the Lucky Ring: tap as it lines up and the catch lands at once with a
-- better shot at a variant; miss and the meter drops back to half. Walking out of
-- reach or getting knocked out lets it escape too (dazed for a moment, so you can grab it
-- again).
-- The client only says "start catching this", "stop" and "tapped this far into the struggle";
-- every rule is checked here. The struggles and the ring are timed by the client's own clock
-- (Giles 2026-11-12: taps in the middle counted as misses, like input lag): it starts each
-- one itself the moment its meter gets there and says how many seconds in the tap came. The
-- server keeps the same timeline (each struggle starts at the exact moment the meter reaches
-- it, not at the next frame) and only checks that the count is possible for the player's
-- ping and the server's own frame times (Catching.tapElapsed).
--
-- Remotes in ReplicatedStorage.CatchRemotes:
--   StartCatch  client -> server (model)
--   StopCatch   client -> server () lets go (the client doesn't send it any more since
--               catching stopped needing a hold; kept so an older client can't break it)
--   Strike      client -> server (stop number, seconds into that struggle or ring)
--   State       server -> client ("Holding", {model, seconds, stops, centres, speed, width,
--               ring, timeout}), ("Struggle", {model, index, startedAt, speed, centre, width,
--               timeout}), ("Struggled", {model, index}), ("Ring", {model, index, startedAt,
--               seconds, startScale, window}), ("Ringed", {model, index, hit}) or ("Ended",
--               {result, model})
--   A stop number counts the struggles and then the ring from 1, the order the meter
--   reaches them.

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
local Perks = require(script.Parent.Parent.Perks)
local MissionService = require(script.Parent.MissionService)
local RoamService = require(script.Parent.RoamService)
local SpawnService = require(script.Parent.SpawnService)
local WatcherService = require(script.Parent.WatcherService)
local Perf = require(script.Parent.Parent.Perf)

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
	centres: { number }, -- where the zone sits in each struggle (sent to the client up front)
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
-- The server's slowest frame of the last couple of seconds: a tap that arrives during a slow
-- frame is that much later, so it gets that much more lag allowance.
local hitch = 0
local hitchAt = 0
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

-- Shop names by item id ("PhantomVac" -> "Phantom Vac").
local itemNames: { [string]: string } = {}
for _, item in Shop.Workshop do
	itemNames[item.id] = item.name
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

-- How much lag this player's taps may have right now (Catching.allowance).
local function allowanceFor(player: Player): number
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	return Catching.allowance(if ok then ping else nil, hitch)
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
	-- A lucky ring, a luck potion and the Lucky Hunter and VIP passes all multiply the chance
	-- of a Silver, Gold, Shiny or Rainbow.
	local boost = (if lucky then Struggles.Ring.variantBoost else 1)
		* HuntService.potionBoost(player)
		* Perks.variantBoost(player)
	local effectBoost = if lucky then Struggles.Ring.effectBoost else nil
	-- A potion also gives vacuums without a Rainbow of their own a small Rainbow chance.
	local potion = HuntService.potionBoost(player) > 1
	local caught = if inHub
		then WatcherService.capture(model, vacuumId, boost, potion, effectBoost)
		else SpawnService.capture(model, vacuumId, boost, potion, effectBoost)
	if not caught then
		State:FireClient(player, "Ended", { result = "Gone", model = model })
		return
	end
	-- Main-area catches fly straight home; zone catches are carried to the Exit. The "what now"
	-- part is a reminder, so it only shows once per visit, except a full bag or mansion
	-- (Giles 2026-11-05: too many pop-ups).
	local afterward = ""
	if inHub then
		if MansionService.addMonster(player, caught) == "Storage" then
			afterward = " Mansion full: it went to your Backpack."
		end
	else
		HuntService.carry(player, caught)
		local count = player:GetAttribute("CarryingCount")
		local size = player:GetAttribute("BagSize")
		if typeof(count) == "number" and typeof(size) == "number" and count >= size and size > 1 then
			afterward = " Bag full!"
		elseif Notify.first(player, "BringToExit") then
			afterward = " Bring it to the Exit!"
		end
	end

	local bonus = ""
	if #caught.effects > 0 then
		local names = {}
		for _, effectId in caught.effects do
			table.insert(names, Format.name(effectId))
		end
		bonus = ` +{table.concat(names, " +")}`
	end
	local variant = if caught.variant then `{caught.variant} ` else ""
	local perfect = if lucky then "PERFECT CATCH! " else ""
	Notify.toast(player, `{perfect}Caught a {variant}{caught.size} {hold.name}!{bonus}{afterward}`)
	MissionService.record(
		player,
		"Catch",
		{ monsterId = caught.monsterId, zone = hold.zoneId, variant = caught.variant, lucky = lucky }
	)
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

	-- 7. Strong enough vacuum: name the weakest vacuum that can catch it.
	local needed = Catching.vacuumNeeded(vacuumId, spawned.size, spawned.rarity, spawned.monsterId)
	if needed then
		Notify.toast(player, `Too strong! You need the {itemName(needed)}.`)
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
	glow.FillColor = Color3.fromRGB(30, 10, 45) -- a dark shroud, not a white flash
	glow.FillTransparency = 0.45
	glow.OutlineColor = Color3.fromRGB(150, 90, 220)
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
		centres = Catching.zoneCentres(plan, random),
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

	State:FireClient(player, "Holding", {
		model = model,
		seconds = seconds,
		stops = Catching.stops(plan),
		centres = hold.centres,
		speed = plan.speed,
		width = plan.zone,
		ring = plan.ring ~= nil,
		timeout = Struggles.TimeoutSeconds,
	})
end

-- The stop number of the struggle going on now (or the ring: one after the last struggle).
local function currentStop(hold: Hold): number
	return if hold.ring then #hold.plan.marks + 1 else hold.nextMark - 1
end

-- The server time the meter reaches `share` (0 to 1) of the way, filling from where it is.
local function reachesAt(hold: Hold, share: number): number
	return hold.fillStart + (share * hold.total - hold.filled)
end

-- The meter stops and the monster struggles, from the moment the meter got to the mark
-- (startedAt), which the client works out the same way.
local function beginStruggle(player: Player, hold: Hold, startedAt: number)
	local index = hold.nextMark
	hold.filled = hold.plan.marks[index] * hold.total
	hold.nextMark += 1
	local centre = hold.centres[index] or 0.5
	hold.struggle = { startedAt = startedAt, centre = centre }
	hold.model:SetAttribute("CatchPaused", hold.filled / hold.total)
	State:FireClient(player, "Struggle", {
		model = hold.model,
		index = index,
		startedAt = startedAt,
		speed = hold.plan.speed,
		centre = centre,
		width = hold.plan.zone,
		timeout = Struggles.TimeoutSeconds,
	})
end

-- The tap landed: the meter fills on from where it stopped, from the moment of the tap.
local function endStruggle(player: Player, hold: Hold, at: number)
	local index = currentStop(hold)
	hold.struggle = nil
	hold.fillStart = at
	hold.model:SetAttribute("CatchPaused", nil)
	hold.model:SetAttribute("CatchStart", at - hold.filled)
	hold.model:SetAttribute("CatchEnd", at - hold.filled + hold.total)
	State:FireClient(player, "Struggled", { model = hold.model, index = index })
end

-- The Lucky Ring appears: the meter stops while it shrinks.
local function beginRing(player: Player, hold: Hold, startedAt: number)
	hold.filled = (hold.plan.ring :: number) * hold.total
	hold.ring = startedAt
	hold.ringDone = true
	hold.model:SetAttribute("CatchPaused", hold.filled / hold.total)
	local ring = Struggles.Ring
	State:FireClient(player, "Ring", {
		model = hold.model,
		index = #hold.plan.marks + 1,
		startedAt = startedAt,
		seconds = ring.seconds,
		startScale = ring.startScale,
		window = ring.window,
	})
end

-- Missed the ring: the monster jerks the meter back, then it fills on from there (from `at`).
local function missRing(player: Player, hold: Hold, at: number)
	hold.ring = nil
	hold.filled = math.min(hold.filled, Struggles.Ring.fallBack * hold.total)
	hold.fillStart = at
	hold.model:SetAttribute("CatchPaused", nil)
	hold.model:SetAttribute("CatchStart", at - hold.filled)
	hold.model:SetAttribute("CatchEnd", at - hold.filled + hold.total)
	State:FireClient(player, "Ringed", { model = hold.model, index = #hold.plan.marks + 1, hit = false })
end

-- While filling: starts the next struggle or the ring if the meter gets there by `horizon`
-- (server time), dated to the moment it gets there. True if one started.
local function beginDue(player: Player, hold: Hold, horizon: number): boolean
	if hold.struggle or hold.ring then
		return false
	end
	local mark = hold.plan.marks[hold.nextMark]
	if mark then
		local at = reachesAt(hold, mark)
		if at <= horizon then
			beginStruggle(player, hold, at)
			return true
		end
		return false
	end
	local ring = hold.plan.ring
	if ring and not hold.ringDone then
		local at = reachesAt(hold, ring)
		if at <= horizon then
			beginRing(player, hold, at)
			return true
		end
	end
	return false
end

local function onStrike(player: Player, stop: unknown, claimed: unknown)
	local hold = holds[player]
	if not hold then
		return
	end
	local serverNow = workspace:GetServerTimeNow()
	if not (hold.struggle or hold.ring) then
		-- The client's meter can get to a struggle a moment before this server's frame does
		-- (a busy server); a tap that comes in just before counts for it.
		beginDue(player, hold, serverNow + Struggles.ClockSlack)
	end
	if not (hold.struggle or hold.ring) then
		return
	end
	if typeof(stop) == "number" and stop ~= currentStop(hold) then
		return -- a tap meant for a struggle that's already over
	end
	local allowance = allowanceFor(player)
	local ringAt = hold.ring
	if ringAt then
		local seconds = Catching.tapElapsed(claimed, serverNow - ringAt, allowance)
		if Catching.ringHit(seconds) then
			State:FireClient(player, "Ringed", { model = hold.model, index = currentStop(hold), hit = true })
			finish(player, true)
		else
			missRing(player, hold, ringAt + seconds)
		end
		return
	end
	local struggle = hold.struggle :: { startedAt: number, centre: number }
	local seconds = Catching.tapElapsed(claimed, serverNow - struggle.startedAt, allowance)
	if
		seconds <= Struggles.TimeoutSeconds
		and Catching.struggleHit(seconds, hold.plan.speed, struggle.centre, hold.plan.zone)
	then
		endStruggle(player, hold, struggle.startedAt + seconds)
	else
		release(player, `{hold.name} broke free! Tap when the needle is in the zone.`)
	end
end

-- Checks every catch in progress each frame.
local function update(dt: number)
	local clock = os.clock()
	if dt >= hitch or clock - hitchAt > 2 then
		hitch = dt
		hitchAt = clock
	end
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
			if serverNow - struggle.startedAt > Struggles.TimeoutSeconds + allowanceFor(player) then
				release(player, `{hold.name} broke free! Tap when the needle is in the zone.`)
			end
		elseif hold.ring then
			if serverNow - hold.ring > Struggles.Ring.seconds + allowanceFor(player) then
				missRing(player, hold, hold.ring + Struggles.Ring.seconds)
			end
		elseif not beginDue(player, hold, serverNow) then
			if hold.filled + (serverNow - hold.fillStart) >= hold.total then
				finish(player)
			end
		end
	end
end

-- The name of the monster this player is catching right now, or nil.
function CatchService.catching(player: Player): string?
	local hold = holds[player]
	return hold and hold.name
end

-- A monster hit the hunter (or another hunter slapped them): whatever they were catching gets away (message is toasted).
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

	RunService.Heartbeat:Connect(Perf.wrap("Catching", update))

	Players.PlayerRemoving:Connect(function(player)
		release(player, nil)
		lastStart[player] = nil
		pendingStart[player] = nil
	end)
end

return CatchService
