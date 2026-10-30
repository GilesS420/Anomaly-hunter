--!strict
-- Trading and gifting monsters (Giles 2026-10-30, numbers in Shared.Config.Trading, rules in
-- Shared.Util.Trading). Only Backpack (Storage) monsters change hands.
--   Trading  at the Trading Booth. Talk to the broker, pick a player who is at the booth too;
--            they get a request card. Once they accept, both get the trade window: tap Backpack
--            monsters to put them in (as many as you like), see every monster's worth and both
--            totals, and press Ready. Any change un-readies both. When both are ready a short
--            countdown runs, then the server checks everything again and swaps.
--   Gifting  anywhere. Hold a Backpack monster and hold E on another player (client
--            TradeController makes those prompts); they get a card to accept or say no.
-- Traded and gifted monsters lose their name tag and heart (Util/Trading.handOver). Every trade
-- and gift goes in both saves' `trades` log.
--
-- Remotes in ReplicatedStorage.TradeRemotes:
--   Open     server -> client (counter: Vector3)               picked "enter" at the booth
--   Nearby   client -> server () -> { { userId, name } }       other players at the booth
--   Request  client -> server (userId) -> Result               asks someone to trade
--   Invite   server -> client (Invite)                         a trade request or a gift for you
--   Answer   client -> server (fromUserId, accept) -> Result   yes or no to an Invite
--   Offer    client -> server ({ uid }) -> Result              everything you put in, every time
--   Ready    client -> server (ready, version) -> Result       version: the State you looked at
--   Cancel   client -> server ()                               closes the trade for both
--   State    server -> client (State?, message?)              the trade as you see it; nil = over
--   Gift     client -> server (userId, uid) -> Result          offers the held monster

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Storage = require(ReplicatedStorage.Shared.Util.Storage)
local Trading = require(ReplicatedStorage.Shared.Util.Trading)
local TradingConfig = require(ReplicatedStorage.Shared.Config.Trading)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Weight = require(ReplicatedStorage.Shared.Util.Weight)
local Counter = require(script.Parent.Parent.Counter)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MansionService = require(script.Parent.MansionService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)
local Perks = require(script.Parent.Parent.Perks)
local PriceLevels = require(script.Parent.Parent.PriceLevels)
local World = require(script.Parent.Parent.World)

local TradeService = {}

export type Row = {
	uid: string,
	name: string,
	kind: string, -- "Silver Big Rare"
	weight: string, -- "54 kg"
	effects: { string },
	value: number,
	look: string,
	color: Color3,
	locked: boolean,
}
export type State = {
	partner: string, -- their display name
	mine: { Row }, -- what you put in
	theirs: { Row }, -- what they put in
	myTotal: number,
	theirTotal: number,
	myReady: boolean,
	theirReady: boolean,
	countdownEnds: number?, -- workspace:GetServerTimeNow() the swap happens, while both are ready
	backpack: { Row }, -- your whole Backpack, to pick from
	version: number,
}
export type Invite = {
	kind: string, -- "Trade" or "Gift"
	from: number, -- their UserId
	name: string, -- their display name
	seconds: number, -- to answer
	monster: Row?, -- the gift
}
export type Result = { ok: boolean, message: string }

type Session = {
	players: { Player },
	offers: { [Player]: { string } },
	ready: { [Player]: boolean },
	version: number,
	token: number, -- bumped to stop a running countdown
	countdownEnds: number?,
	over: boolean,
}
type Pending = { kind: string, expires: number, uid: string? }

local remotes = Instance.new("Folder")
remotes.Name = "TradeRemotes"
local function event(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end
local function fn(name: string): RemoteFunction
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotes
	return remote
end
local Open = event("Open")
local Nearby = fn("Nearby")
local Request = fn("Request")
local InviteRemote = event("Invite")
local Answer = fn("Answer")
local Offer = fn("Offer")
local Ready = fn("Ready")
local Cancel = event("Cancel")
local StateRemote = event("State")
local Gift = fn("Gift")

local counter: Attachment? = nil
local sessions: { [Player]: Session } = {}
local pending: { [Player]: { [Player]: Pending } } = {} -- pending[receiver][sender]
local tradeReadyAt: { [Player]: number } = {}
local giftReadyAt: { [Player]: number } = {}
local requestReadyAt: { [Player]: number } = {}

local Loading: Result = { ok = false, message = "Your save is still loading. Try again in a moment!" }

local Problems: { [Trading.Problem]: string } = {
	Missing = "That monster isn't in the Backpack any more.",
	Hearted = "Hearted (♥) monsters can't be traded. Un-heart it in your Backpack first.",
	Twice = "That monster is already in.",
}

local function valueOf(caught: Value.CaughtMonster, wingsOwned: number): number
	local ok, value = pcall(Value.sellValue, caught, wingsOwned)
	return if ok then value else 0
end

local function rowFor(caught: Value.CaughtMonster, wingsOwned: number): Row?
	local monster = Monsters[caught.monsterId]
	if not monster or not caught.uid then
		return nil
	end
	local effects = {}
	for _, effectId in Value.resolveEffects(caught.effects) do
		table.insert(effects, Format.name(effectId))
	end
	local variant = if caught.variant then `{caught.variant} ` else ""
	return {
		uid = caught.uid,
		name = Format.monsterName(caught),
		kind = `{variant}{caught.size} {monster.rarity}`,
		weight = Weight.text(caught.kg or 0),
		effects = effects,
		value = valueOf(caught, wingsOwned),
		look = InventoryService.lookOf(caught),
		color = MonsterModel.color(monster.rarity),
		locked = caught.locked == true,
	}
end

local function stored(data: DataService.Data, uid: string): Value.CaughtMonster?
	for _, caught in data.storage do
		if caught.uid == uid then
			return caught
		end
	end
	return nil
end

local function namesOf(list: { Value.CaughtMonster }): { string }
	local names = {}
	for _, caught in list do
		table.insert(names, Format.monsterName(caught))
	end
	return names
end

local function nearBooth(player: Player): boolean
	return Counter.isNear(player, counter)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function otherPlayer(userId: unknown, me: Player): Player?
	if typeof(userId) ~= "number" or userId % 1 ~= 0 or math.abs(userId) > 2 ^ 53 then
		return nil -- not a whole number (NaN and infinity aren't either)
	end
	local other = Players:GetPlayerByUserId(userId)
	return if other and other ~= me and DataService.isLoaded(other) then other else nil
end

local function waitText(seconds: number): string
	return `Wait {math.ceil(seconds)}s before trading again.`
end

-- The trade -----------------------------------------------------------------------------------

local function partnerOf(session: Session, player: Player): Player
	return if session.players[1] == player then session.players[2] else session.players[1]
end

-- The monsters a player put in, as rows and as the monsters themselves (missing ones skipped).
local function offered(session: Session, player: Player, data: DataService.Data): ({ Row }, { Value.CaughtMonster }, number)
	local rows, monsters, total = {}, {}, 0
	for _, uid in session.offers[player] do
		local caught = stored(data, uid)
		local row = if caught then rowFor(caught, data.wingsOwned) else nil
		if caught and row then
			table.insert(rows, row)
			table.insert(monsters, caught)
			total += row.value
		end
	end
	return rows, monsters, total
end

local function push(session: Session)
	for _, player in session.players do
		local partner = partnerOf(session, player)
		local data, theirData = DataService.get(player), DataService.get(partner)
		if not data or not theirData then
			continue
		end
		local mine, _, myTotal = offered(session, player, data)
		local theirs, theirMonsters, theirTotal = offered(session, partner, theirData)
		-- Their monsters' pictures are built in your PlayerGui while they're on offer.
		InventoryService.showLooks(player, "Trade", theirMonsters)
		local backpack = {}
		for _, caught in data.storage do
			local row = rowFor(caught, data.wingsOwned)
			if row then
				table.insert(backpack, row)
			end
		end
		table.sort(backpack, function(a, b)
			return if a.value == b.value then a.uid < b.uid else a.value > b.value
		end)
		local state: State = {
			partner = partner.DisplayName,
			mine = mine,
			theirs = theirs,
			myTotal = myTotal,
			theirTotal = theirTotal,
			myReady = session.ready[player] == true,
			theirReady = session.ready[partner] == true,
			countdownEnds = session.countdownEnds,
			backpack = backpack,
			version = session.version,
		}
		StateRemote:FireClient(player, state)
	end
end

-- Ends the trade for both. `messages` per player is shown in their closing window.
local function finish(session: Session, messages: { [Player]: string })
	if session.over then
		return
	end
	session.over = true
	session.token += 1
	for _, player in session.players do
		if sessions[player] == session then
			sessions[player] = nil
		end
		InventoryService.showLooks(player, "Trade", {})
		if player.Parent == Players then
			StateRemote:FireClient(player, nil, messages[player] or "The trade was closed.")
		end
	end
end

local function cancelBoth(session: Session, message: string)
	local messages = {}
	for _, player in session.players do
		messages[player] = message
	end
	finish(session, messages)
end

local function stopCountdown(session: Session)
	session.token += 1
	session.countdownEnds = nil
end

local function swap(session: Session)
	local a, b = session.players[1], session.players[2]
	local dataA, dataB = DataService.get(a), DataService.get(b)
	if not dataA or not dataB then
		cancelBoth(session, "The trade was cancelled.")
		return
	end
	if not nearBooth(a) or not nearBooth(b) then
		cancelBoth(session, "Both of you have to stay at the Trading Booth. Nothing was swapped.")
		return
	end
	local giveA, giveB = session.offers[a], session.offers[b]
	local problem = Trading.problem(dataA.storage, giveA) or Trading.problem(dataB.storage, giveB)
	if problem then
		cancelBoth(session, `{Problems[problem]} Nothing was swapped.`)
		return
	end
	local tooFull = if not Trading.fits(#dataA.storage, #giveA, #giveB, Perks.storageSlots(a))
		then a
		elseif not Trading.fits(#dataB.storage, #giveB, #giveA, Perks.storageSlots(b)) then b
		else nil
	if tooFull then
		cancelBoth(session, `{tooFull.DisplayName}'s Backpack is too full for this trade. Nothing was swapped.`)
		return
	end

	-- Everything checked: swap in one go (nothing here waits, so nothing can change halfway).
	local function set(uids: { string }): { [string]: boolean }
		local result = {}
		for _, uid in uids do
			result[uid] = true
		end
		return result
	end
	local fromA = MansionService.removeMonsters(a, set(giveA))
	local fromB = MansionService.removeMonsters(b, set(giveB))
	local gaveA, gaveB = namesOf(fromA), namesOf(fromB)
	for _, caught in fromA do
		Trading.handOver(caught)
		table.insert(dataB.storage, caught)
	end
	for _, caught in fromB do
		Trading.handOver(caught)
		table.insert(dataA.storage, caught)
	end
	local now = os.time()
	Trading.log(dataA.trades, { at = now, kind = "Trade", with = b.UserId, gave = gaveA, got = gaveB }, TradingConfig.LogKept)
	Trading.log(dataB.trades, { at = now, kind = "Trade", with = a.UserId, gave = gaveB, got = gaveA }, TradingConfig.LogKept)
	local readyAt = os.clock() + TradingConfig.TradeCooldown
	tradeReadyAt[a], tradeReadyAt[b] = readyAt, readyAt

	local function summary(got: number, partner: Player): string
		return if got == 0
			then `Trade done with {partner.DisplayName}!`
			else `Trade done! You got {got} monster{if got == 1 then "" else "s"} from {partner.DisplayName}. They're in your Backpack.`
	end
	finish(session, { [a] = summary(#fromB, b), [b] = summary(#fromA, a) })
	for _, player in { a, b } do
		Notify.toast(player, summary(if player == a then #fromB else #fromA, partnerOf(session, player)))
		InventoryService.syncMonsterTools(player)
		task.spawn(DataService.saveNow, player) -- both saves written straight away
	end
end

local function start(a: Player, b: Player)
	local session: Session = {
		players = { a, b },
		offers = { [a] = {}, [b] = {} },
		ready = {},
		version = 1,
		token = 0,
		countdownEnds = nil,
		over = false,
	}
	sessions[a], sessions[b] = session, session
	local at = counter
	for _, player in session.players do
		if at then
			Open:FireClient(player, at.WorldPosition, "Trade")
		end
	end
	push(session)
end

-- Gifts ---------------------------------------------------------------------------------------

local function giveGift(sender: Player, receiver: Player, uid: string): Result
	local from, to = DataService.get(sender), DataService.get(receiver)
	if not from or not to then
		return { ok = false, message = "The gift was cancelled." }
	end
	local caught = stored(from, uid)
	if not caught then
		Notify.toast(sender, `{receiver.DisplayName} accepted, but the monster wasn't in your Backpack any more.`)
		return { ok = false, message = "That monster isn't on offer any more." }
	end
	if caught.locked then
		return { ok = false, message = "They hearted it before you accepted, so it stays with them." }
	end
	if not Storage.hasRoom(#to.storage, Perks.storageSlots(receiver)) then
		Notify.toast(sender, `{receiver.DisplayName}'s Backpack is full.`)
		return { ok = false, message = "Your Backpack is full. Sell or place a monster first." }
	end
	local name = Format.monsterName(caught)
	local moved = MansionService.removeMonsters(sender, { [uid] = true })[1]
	if not moved then
		return { ok = false, message = "That monster isn't on offer any more." }
	end
	Trading.handOver(moved)
	table.insert(to.storage, moved)
	local now = os.time()
	Trading.log(from.trades, { at = now, kind = "GiftSent", with = receiver.UserId, gave = { name }, got = {} }, TradingConfig.LogKept)
	Trading.log(to.trades, { at = now, kind = "GiftGot", with = sender.UserId, gave = {}, got = { name } }, TradingConfig.LogKept)
	Notify.toast(sender, `{receiver.DisplayName} accepted your {name}!`)
	for _, player in { sender, receiver } do
		InventoryService.syncMonsterTools(player)
		task.spawn(DataService.saveNow, player)
	end
	local got = Format.monsterName(moved)
	return { ok = true, message = `{sender.DisplayName} gave you a {got}! It's in your Backpack.` }
end

-- Remotes -------------------------------------------------------------------------------------

Nearby.OnServerInvoke = function(player: Player): { { userId: number, name: string } }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and DataService.isLoaded(other) and nearBooth(other) then
			table.insert(list, { userId = other.UserId, name = other.DisplayName })
		end
	end
	return list
end

Request.OnServerInvoke = function(player: Player, userId: unknown): Result
	if not DataService.isLoaded(player) then
		return Loading
	end
	local target = otherPlayer(userId, player)
	if not target then
		return { ok = false, message = "That player isn't here any more." }
	end
	if sessions[player] then
		return { ok = false, message = "You're already trading." }
	end
	if not nearBooth(player) then
		return { ok = false, message = "Walk up to the Trading Booth to trade." }
	end
	if not nearBooth(target) then
		return { ok = false, message = `{target.DisplayName} has to be at the Trading Booth too.` }
	end
	if sessions[target] then
		return { ok = false, message = `{target.DisplayName} is busy trading.` }
	end
	local now = os.clock()
	if (tradeReadyAt[player] or 0) > now then
		return { ok = false, message = waitText(tradeReadyAt[player] - now) }
	end
	if (requestReadyAt[player] or 0) > now then
		return { ok = false, message = "One moment before asking again." }
	end
	requestReadyAt[player] = now + TradingConfig.RequestCooldown
	local theirs = pending[target] or {}
	pending[target] = theirs
	theirs[player] = { kind = "Trade", expires = now + TradingConfig.AnswerSeconds }
	InviteRemote:FireClient(target, {
		kind = "Trade",
		from = player.UserId,
		name = player.DisplayName,
		seconds = TradingConfig.AnswerSeconds,
	} :: Invite)
	return { ok = true, message = `Asked {target.DisplayName} to trade. Waiting for an answer...` }
end

Answer.OnServerInvoke = function(player: Player, fromUserId: unknown, accept: unknown): Result
	if not DataService.isLoaded(player) then
		return Loading
	end
	local sender = otherPlayer(fromUserId, player)
	local mine = pending[player]
	local invite = if sender and mine then mine[sender] else nil
	if not sender or not invite or not mine then
		return { ok = false, message = "That request is gone." }
	end
	mine[sender] = nil
	if invite.kind == "Gift" then
		InventoryService.showLooks(player, `Gift{sender.UserId}`, {})
	end
	if invite.expires < os.clock() then
		return { ok = false, message = "Too late, that request ran out." }
	end
	if accept ~= true then
		Notify.toast(sender, `{player.DisplayName} said no{if invite.kind == "Gift" then " to your gift" else ""}.`)
		return { ok = true, message = "" }
	end

	if invite.kind == "Gift" then
		return giveGift(sender, player, invite.uid or "")
	end
	if sessions[player] or sessions[sender] then
		return { ok = false, message = `{sender.DisplayName} is busy trading.` }
	end
	if not nearBooth(player) or not nearBooth(sender) then
		return { ok = false, message = "You both have to be at the Trading Booth." }
	end
	local now = os.clock()
	for _, who in { player, sender } do
		if (tradeReadyAt[who] or 0) > now then
			return { ok = false, message = waitText(tradeReadyAt[who] - now) }
		end
	end
	Notify.toast(sender, `{player.DisplayName} wants to trade!`)
	start(sender, player)
	return { ok = true, message = "" }
end

Offer.OnServerInvoke = function(player: Player, uids: unknown): Result
	local session = sessions[player]
	local data = DataService.get(player)
	if not session or not data then
		return { ok = false, message = "You're not trading." }
	end
	if typeof(uids) ~= "table" then
		return { ok = false, message = "That isn't a list of monsters." }
	end
	local list: { string } = {}
	for _, uid in uids :: { any } do
		if typeof(uid) ~= "string" or #list >= 1000 then
			return { ok = false, message = "That isn't a list of monsters." }
		end
		table.insert(list, uid)
	end
	local problem = Trading.problem(data.storage, list)
	if problem then
		return { ok = false, message = Problems[problem] }
	end
	session.offers[player] = list
	session.ready = {}
	session.version += 1
	stopCountdown(session)
	push(session)
	return { ok = true, message = "" }
end

Ready.OnServerInvoke = function(player: Player, ready: unknown, version: unknown): Result
	local session = sessions[player]
	if not session then
		return { ok = false, message = "You're not trading." }
	end
	if version ~= session.version then
		return { ok = false, message = "The trade just changed. Check it again." }
	end
	session.ready[player] = ready == true
	local a, b = session.players[1], session.players[2]
	if session.ready[a] and session.ready[b] then
		if #session.offers[a] == 0 and #session.offers[b] == 0 then
			session.ready = {}
			push(session)
			return { ok = false, message = "Put a monster in first." }
		end
		if not session.countdownEnds then
			session.token += 1
			local token = session.token
			session.countdownEnds = workspace:GetServerTimeNow() + TradingConfig.CountdownSeconds
			task.delay(TradingConfig.CountdownSeconds, function()
				if not session.over and session.token == token then
					swap(session)
				end
			end)
		end
	else
		stopCountdown(session)
	end
	push(session)
	return { ok = true, message = "" }
end

Cancel.OnServerEvent:Connect(function(player: Player)
	local session = sessions[player]
	if session then
		finish(session, {
			[player] = "You closed the trade.",
			[partnerOf(session, player)] = `{player.DisplayName} closed the trade.`,
		})
	end
end)

Gift.OnServerInvoke = function(player: Player, userId: unknown, uid: unknown): Result
	local data = DataService.get(player)
	if not data then
		return Loading
	end
	local target = otherPlayer(userId, player)
	if not target or typeof(uid) ~= "string" then
		return { ok = false, message = "That player isn't here any more." }
	end
	local now = os.clock()
	if (giftReadyAt[player] or 0) > now then
		return { ok = false, message = `Wait {math.ceil(giftReadyAt[player] - now)}s before giving another gift.` }
	end
	local mine, theirs = rootOf(player), rootOf(target)
	if not mine or not theirs or (mine.Position - theirs.Position).Magnitude > TradingConfig.GiftReach + 4 then
		return { ok = false, message = `Stand next to {target.DisplayName} to give a gift.` }
	end
	local caught = stored(data, uid)
	if not caught then
		return { ok = false, message = "Hold a monster from your Backpack to give it." }
	end
	if caught.locked then
		return { ok = false, message = "Hearted (♥) monsters can't be given away. Un-heart it in your Backpack first." }
	end
	local waiting = pending[target]
	if waiting and waiting[player] and waiting[player].expires > now then
		return { ok = false, message = `{target.DisplayName} hasn't answered your last request yet.` }
	end
	local row = rowFor(caught, data.wingsOwned)
	if not row then
		return { ok = false, message = "That monster can't be given." }
	end
	giftReadyAt[player] = now + TradingConfig.GiftCooldown
	waiting = waiting or {}
	pending[target] = waiting
	local invite: Pending = { kind = "Gift", expires = now + TradingConfig.AnswerSeconds, uid = uid }
	waiting[player] = invite
	InventoryService.showLooks(target, `Gift{player.UserId}`, { caught })
	InviteRemote:FireClient(target, {
		kind = "Gift",
		from = player.UserId,
		name = player.DisplayName,
		seconds = TradingConfig.AnswerSeconds,
		monster = row,
	} :: Invite)
	-- Unanswered: tidy up.
	task.delay(TradingConfig.AnswerSeconds + 1, function()
		local still = pending[target]
		if still and still[player] == invite then
			still[player] = nil
			InventoryService.showLooks(target, `Gift{player.UserId}`, {})
			Notify.toast(player, `{target.DisplayName} didn't answer your gift.`)
		end
	end)
	return { ok = true, message = `Offered {row.name} to {target.DisplayName}. Waiting for them to accept...` }
end

-- The booth had a "Coming soon" plank nailed across its counter; a booth built and saved into
-- the place before trading opened still has it.
local function removePlank()
	local booth = World.find(World.find(World.find(workspace, "Hub"), "Landmarks"), "TradingBooth")
	if booth then
		for _, part in booth:GetDescendants() do
			if part.Name == "SoonPlank" then
				part:Destroy()
			end
		end
	end
end

function TradeService.start()
	remotes.Parent = ReplicatedStorage
	PriceLevels.start()
	removePlank()
	counter = Counter.prompt("TradingBooth", "Trading Booth", function(player)
		local at = counter
		if at and DataService.isLoaded(player) and not sessions[player] then
			Open:FireClient(player, at.WorldPosition, "Pick")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			finish(session, { [partnerOf(session, player)] = `{player.DisplayName} left. Nothing was swapped.` })
		end
		pending[player] = nil
		for _, waiting in pending do
			waiting[player] = nil
		end
		tradeReadyAt[player], giftReadyAt[player], requestReadyAt[player] = nil, nil, nil
	end)
end

return TradeService
