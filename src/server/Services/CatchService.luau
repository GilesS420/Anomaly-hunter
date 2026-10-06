--!strict
-- Catching: press and hold on a wild monster. It freezes in your flashlight beam and a catch
-- meter fills by itself (1-3 seconds, longer for rarer monsters). Let go early, walk out of
-- reach or get knocked out and it escapes (dazed for a moment, so you can grab it again).
-- The client only says "start catching this" and "stop"; every rule is checked here.
--
-- Remotes in ReplicatedStorage.CatchRemotes:
--   StartCatch  client -> server (model)
--   StopCatch   client -> server ()
--   State       server -> client ("Holding", {model, seconds}) or ("Ended", {result, model})

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catching = require(ReplicatedStorage.Shared.Util.Catching)
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
	endTime: number, -- server time the meter is full
	glow: Highlight,
	beam: Beam,
	from: Attachment, -- on the hunter
	to: Attachment, -- on the monster
	died: RBXScriptConnection?,
}

local StartCooldown = 0.25 -- seconds between StartCatch requests (stops spam)

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
local State = remote("State") -- server -> client: ("Holding" | "Ended", info)

-- Shop names by item id ("CandleLamp" -> "Candle Lamp"), and vacuum names by tier.
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
	return hold
end

-- Lets the monster go (it stays dazed for the flashlight's stun time). message is toasted
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

local function finish(player: Player)
	local hold = clear(player)
	if not hold then
		return
	end
	local model = hold.model
	local data = DataService.get(player)
	if not data or HuntService.isCarrying(player) or not isHunting(player, hold.zoneId) then
		RoamService.release(model, hold.stunSeconds)
		State:FireClient(player, "Ended", { result = "Escaped", model = model })
		return
	end

	local equipped = { data.equipped.flashlight, data.equipped.vacuum, data.equipped.lens }
	local inHub = hold.zoneId == ""
	if inHub and not MansionService.hasRoom(player) then
		RoamService.release(model, hold.stunSeconds)
		Notify.toast(player, "Your mansion is full! Buy a new wing to catch more.")
		State:FireClient(player, "Ended", { result = "Escaped", model = model })
		return
	end
	local caught = if inHub
		then WatcherService.capture(model, equipped)
		else SpawnService.capture(model, equipped)
	if not caught then
		State:FireClient(player, "Ended", { result = "Gone", model = model })
		return
	end
	-- Main-area catches fly straight home; zone catches are carried to the Exit.
	local afterward = "Now bring it to the Exit."
	if inHub then
		MansionService.addMonster(player, caught)
		afterward = "It flew straight home to your mansion!"
	else
		HuntService.carry(player, caught)
	end

	local bonus = ""
	if #caught.effects > 0 then
		local names = {}
		for _, effectId in caught.effects do
			table.insert(names, Format.name(effectId))
		end
		bonus = ` Bonus: {table.concat(names, " and ")}!`
	end
	Notify.toast(player, `Caught a {caught.size} {hold.name}!{bonus} {afterward}`)
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
	local name = Format.name(spawned.monsterId)
	local holder = heldBy[model]
	if holder then
		if holder ~= player then
			Notify.toast(player, "Someone else is catching that one!")
		end
		return
	end

	-- 3. One monster per trip.
	if HuntService.isCarrying(player) then
		Notify.toast(player, "Your vacuum is full. Bring your catch home first!")
		return
	end

	-- 4. Room at home.
	if not MansionService.hasRoom(player) then
		Notify.toast(player, "Your mansion is full! Buy a new wing to catch more.")
		return
	end

	-- 5. Close enough for the flashlight.
	local flashlightId = data.equipped.flashlight
	local reach = Catching.reach(flashlightId)
	if distanceTo(player, model) > reach then
		local shown = math.floor(reach - Tools.ReachSlack)
		Notify.toast(player, `Get closer! Your {itemName(flashlightId)} reaches {shown} studs.`)
		return
	end

	-- 6. Strong enough vacuum.
	local vacuumId = data.equipped.vacuum
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

	local flashlight = Tools.Flashlights[flashlightId]
	local hold: Hold = {
		model = model,
		name = name,
		zoneId = zoneId,
		reach = reach,
		stunSeconds = if flashlight then flashlight.stunSeconds else 1,
		endTime = serverNow + seconds,
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
			release(player, `{name} got away! Hold until the meter is full.`)
		end)
	end

	State:FireClient(player, "Holding", { model = model, seconds = seconds })
end

-- Checks every catch in progress each frame.
local function update()
	local serverNow = workspace:GetServerTimeNow()
	for player, hold in holds do
		if wildMonster(hold.model) == nil then
			-- Gone (cleared by an event, or the zone was removed).
			clear(player)
			State:FireClient(player, "Ended", { result = "Gone", model = hold.model })
		elseif not isHunting(player, hold.zoneId) then
			-- Knocked out or went home (Exit, Return Charm): it just stays behind, no message.
			release(player, nil)
		elseif distanceTo(player, hold.model) > hold.reach then
			release(player, `{hold.name} got away!`)
		elseif serverNow >= hold.endTime then
			finish(player)
		end
	end
end

function CatchService.start()
	remotes.Parent = ReplicatedStorage

	StartCatch.OnServerEvent:Connect(onStartCatch)
	StopCatch.OnServerEvent:Connect(function(player)
		pendingStart[player] = nil
		local hold = holds[player]
		if hold then
			release(player, `{hold.name} got away! Hold until the meter is full.`)
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
