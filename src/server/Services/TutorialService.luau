--!strict
-- The first-timer tutorial and the optional Bakery quest after it (steps, unlocks and words in
-- Shared.Util.Tutorial). A brand-new save starts the tutorial; older saves count as done, so
-- existing players never see it. Each step moves on by itself when the player has done what it
-- asks, by watching the save and the hunt attributes.
-- The tutorial (short since 2026-11-05):
--   Gate    walk into Pumpkin Graveyard
--   Catch   catch the Gloomlet that waits there, reserved for them (and a free Return Charm)
--   Home    bring it home (the exit or the charm); it turns Cobwebbed and goes straight into the
--           Backpack, ready to sell
--   Sell    sell it at the Collector (their money has to go up, so an admin restarting the
--           tutorial with money still has to sell), who then tops it up to the Phantom Vac's price
--   Buy     buy the Phantom Vac (always in stock for them during this step, WorkshopService)
-- Losing the catch (knocked out, or leaving the zone or the game) goes back to Gate. Nothing
-- attacks a player in the tutorial (MonsterAiService) and fast travel to a locked button is
-- refused (TravelService). The player attribute Tutorial holds the step (nil once done) and
-- TutorialSince when it started (server time), for the client's "stuck?" hint.
-- The quest "Baker's first cake" starts when the tour ends. Nothing is locked and it can be
-- skipped (SkipQuest):
--   Bake    the Baker tops their money up to a Pumpkin Candy; buy it (always in stock, BakeryService)
--   Place   set it out in the mansion
--   Hunt    go back to Pumpkin Graveyard and catch a second monster (a Skittercrow waits there)
--   Return  bring it home (lost on the way: back to Hunt)
--   Feed    it walks to the cake, and the bite gives Pumpkin Head for sure (CakeService.hurry;
--           after Tutorial.FeedSeconds it gets the effect anyway); then Tutorial.QuestReward
-- The attribute Quest holds its step (nil when there's none) and QuestSince.
--
-- Remotes in ReplicatedStorage.TutorialRemotes:
--   SkipQuest  client -> server ()   no Bakery quest, thanks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Analytics = require(ReplicatedStorage.Shared.Util.Analytics)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Tutorial = require(ReplicatedStorage.Shared.Util.Tutorial)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CakeService = require(script.Parent.CakeService)
local DataService = require(script.Parent.DataService)
local HauntService = require(script.Parent.HauntService)
local HuntService = require(script.Parent.HuntService)
local MansionService = require(script.Parent.MansionService)
local SpawnService = require(script.Parent.SpawnService)
local Notify = require(script.Parent.Parent.Notify)

local TutorialService = {}

type State = {
	quest: boolean, -- the Bakery quest, not the tutorial
	step: string,
	monster: Model?, -- the Gloomlet (Catch) or Skittercrow (Hunt) waiting in the zone
	spawnAt: number?, -- os.clock() when to bring (another) one
	feedEnds: number?, -- os.clock() when the Feed step gives the effect anyway
	sellMoney: number?, -- their money when the Sell step was first checked
}

local CheckSeconds = 0.5

local states: { [Player]: State } = {}

local remotes = Instance.new("Folder")
remotes.Name = "TutorialRemotes"
local SkipQuest = Instance.new("RemoteEvent")
SkipQuest.Name = "SkipQuest"
SkipQuest.Parent = remotes

local firstVacuumPrice = 0
for _, item in Shop.Workshop do
	if item.id == Tutorial.FirstVacuum then
		firstVacuumPrice = item.price
	end
end
local cakePrice = 0
for _, item in Shop.Bakery do
	if item.id == Tutorial.Cake then
		cakePrice = item.price
	end
end

-- Shop items that cost something (the free starter vacuum doesn't count as owning anything).
local function paidItems(inventory: { [string]: number }): number
	local count = 0
	for _, list in { Shop.Workshop, Shop.Bakery } do
		for _, item in list do
			if item.price > 0 and (inventory[item.id] or 0) > 0 then
				count += 1
			end
		end
	end
	return count
end

-- Whether the tutorial's cake is out in their mansion.
local function hasCakeOut(data: DataService.Data): boolean
	for _, cake in data.cakes do
		if cake.itemId == Tutorial.Cake then
			return true
		end
	end
	return false
end

-- Whether a monster at home has the cake's effect (the Feed step is done).
local function fedOne(data: DataService.Data): boolean
	for _, caught in data.monsters do
		if table.find(caught.effects, Tutorial.CakeEffect) then
			return true
		end
	end
	return false
end

local function removeMonster(state: State)
	local monster = state.monster
	state.monster = nil
	if monster and monster.Parent then
		monster:Destroy()
	end
end

-- What happens the moment a step starts.
local function enter(player: Player, data: DataService.Data, state: State)
	local step = state.step
	if step == "Catch" then
		-- A free Return Charm, to show the quick way home (only one, however often they retry).
		if (data.inventory.ReturnCharm or 0) == 0 then
			data.inventory.ReturnCharm = 1
			HuntService.refreshItems(player)
		end
	elseif step == "Buy" then
		local gift = Tutorial.gift(data.money, firstVacuumPrice)
		if gift > 0 and DataService.addMoney(player, gift) then
			AnalyticsService.money(player, gift, "Onboarding", "WelcomeGift") -- the card says so
		end
	elseif step == "Bake" then
		local gift = Tutorial.gift(data.money, cakePrice)
		if gift > 0 and DataService.addMoney(player, gift) then
			AnalyticsService.money(player, gift, "Onboarding", "BakerGift") -- the card says so
		end
	elseif step == "Hunt" then
		data.tips.Cake = true -- they just learned cakes here: no "Your first cake" card later
	elseif step == "Feed" then
		state.feedEnds = os.clock() + Tutorial.FeedSeconds
	end
end

local setQuest: (Player, string, boolean) -> ()

-- Moves the player to this tutorial step (or "Done"), saves it and runs the step's start.
-- Done with run (they finished it themselves) offers the Bakery quest.
local function setStep(player: Player, step: string, run: boolean)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.tutorial = step
	DataService.saveSoon(player)
	local old = states[player]
	if old then
		removeMonster(old)
	end
	if step == "Done" then
		states[player] = nil
		player:SetAttribute("Tutorial", nil)
		player:SetAttribute("TutorialSince", nil)
		-- No "complete" toast: RookieService says the rookie hour started, and the quest card shows.
		if run then
			if data.quest == "" then
				setQuest(player, Tutorial.QuestSteps[1], true)
			end
		end
		return
	end
	local state: State = { quest = false, step = step }
	states[player] = state
	player:SetAttribute("Tutorial", step)
	player:SetAttribute("TutorialSince", workspace:GetServerTimeNow())
	if run then
		enter(player, data, state)
	end
end

-- Moves the player to this quest step (or "Done" / "Skipped"), like setStep.
setQuest = function(player: Player, step: string, run: boolean)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.quest = step
	DataService.saveSoon(player)
	local old = states[player]
	if old then
		removeMonster(old)
	end
	if run then
		AnalyticsService.questStep(player, Analytics.questStep(step))
	end
	if Tutorial.questIndex(step) == 0 then
		states[player] = nil
		player:SetAttribute("Quest", nil)
		player:SetAttribute("QuestSince", nil)
		if run and step == "Done" then
			local reward = Tutorial.QuestReward
			if DataService.addMoney(player, reward) then
				AnalyticsService.money(player, reward, "Onboarding", "QuestReward")
			end
			Notify.toast(
				player,
				`Quest complete: {Tutorial.QuestName}! The Baker pays you {Format.money(reward)}.`
			)
		end
		return
	end
	local state: State = { quest = true, step = step }
	states[player] = state
	player:SetAttribute("Quest", step)
	player:SetAttribute("QuestSince", workspace:GetServerTimeNow())
	if run then
		enter(player, data, state)
	end
end

-- Moves on in whichever list this state is in.
local function goTo(player: Player, state: State, step: string)
	if state.quest then
		setQuest(player, step, true)
	else
		setStep(player, step, true)
	end
end

-- Puts the newest monster at home into the Backpack, so it can be sold straight away.
local function storeNewest(player: Player, data: DataService.Data)
	if #data.storage > 0 then
		return
	end
	local newest = data.monsters[#data.monsters]
	if newest then
		MansionService.move(player, newest.uid)
	end
end

-- Brings the tutorial's monster to the player, marked so their client can point at it.
local function bringMonster(player: Player, state: State, monsterId: string)
	state.spawnAt = nil
	local ok, _, model = SpawnService.spawnFor(player, monsterId, "Normal")
	if ok and model then
		model:SetAttribute("TutorialFor", player.UserId)
		state.monster = model
	else
		state.spawnAt = os.clock() + Tutorial.RespawnSeconds -- too crowded: try again soon
	end
end

-- Keeps a tutorial monster waiting while the player is in the zone (it can wander off or
-- time out), and takes it away when they leave.
local function keepMonster(player: Player, state: State, zone: unknown, monsterId: string)
	if zone ~= Tutorial.Zone then
		removeMonster(state) -- not there (yet); a fresh one waits when they walk in
		state.spawnAt = nil
		return
	end
	local monster = state.monster
	if monster and not monster.Parent then
		state.monster = nil
	end
	if not state.monster then
		local at = state.spawnAt
		if not at then
			state.spawnAt = os.clock() + 1 -- just walked in (or it wandered off)
		elseif os.clock() >= at then
			bringMonster(player, state, monsterId)
		end
	end
end

-- Checks whether the player has done what their step asks, and moves them on.
local function check(player: Player, state: State)
	local data = DataService.get(player)
	if not data then
		return
	end
	local step = state.step
	local zone = player:GetAttribute("Zone")
	local carrying = HuntService.isCarrying(player)
	local owned = #data.monsters + #data.storage

	if step == "Gate" then
		if zone == Tutorial.Zone then
			setStep(player, "Catch", true)
		end
	elseif step == "Catch" then
		if carrying then
			setStep(player, "Home", true)
		elseif zone ~= Tutorial.Zone then
			setStep(player, "Gate", true) -- left without it
		else
			keepMonster(player, state, zone, Tutorial.Monster)
		end
	elseif step == "Home" then
		if zone == nil and not carrying then
			if owned > 0 then
				HauntService.give(player, Tutorial.Effect)
				storeNewest(player, data)
				setStep(player, "Sell", true)
			else
				setStep(player, "Gate", true) -- knocked out on the way
			end
		end
	elseif step == "Sell" then
		local before = state.sellMoney
		if not before then
			state.sellMoney = data.money
		elseif data.money > before then
			setStep(player, "Buy", true) -- sold
		elseif owned == 0 then
			setStep(player, "Gate", true)
		else
			storeNewest(player, data) -- an older save from the Pickup step
		end
	elseif step == "Buy" then
		if (data.inventory[Tutorial.FirstVacuum] or 0) > 0 then
			setStep(player, "Done", true)
		end
	elseif step == "Bake" then
		if hasCakeOut(data) then
			goTo(player, state, "Hunt")
		elseif (data.inventory[Tutorial.Cake] or 0) > 0 then
			goTo(player, state, "Place")
		end
	elseif step == "Place" then
		if hasCakeOut(data) then
			goTo(player, state, "Hunt")
		elseif (data.inventory[Tutorial.Cake] or 0) == 0 then
			goTo(player, state, "Bake") -- it's gone somehow: buy another
		end
	elseif step == "Hunt" then
		if carrying then
			goTo(player, state, "Return")
		else
			keepMonster(player, state, zone, Tutorial.SecondMonster)
		end
	elseif step == "Return" then
		if zone == nil and not carrying then
			goTo(player, state, if #data.monsters > 0 then "Feed" else "Hunt")
		end
	elseif step == "Feed" then
		if fedOne(data) then
			goTo(player, state, "Done")
		elseif #data.monsters > 0 then
			CakeService.hurry(player, Tutorial.Cake)
			local ends = state.feedEnds
			if not ends then
				state.feedEnds = os.clock() + Tutorial.FeedSeconds -- came back to this step
			elseif os.clock() >= ends then
				HauntService.give(player, Tutorial.CakeEffect) -- the bite never came: no waiting forever
			end
		elseif owned == 0 then
			goTo(player, state, "Hunt") -- sold it before the bite
		end
	end
end

local function onLoaded(player: Player, data: DataService.Data)
	local fresh = false
	if data.tutorial == "New" then
		fresh = Tutorial.isFresh(
			data.money,
			#data.monsters,
			#data.storage,
			data.wingsOwned,
			paidItems(data.inventory)
		)
		data.tutorial = if fresh then "Gate" else "Done"
	end
	-- A save from the longer tutorial that was in its Bakery part: that's the quest now.
	local moved = Tutorial.questFor(data.tutorial)
	if moved then
		data.tutorial = "Done"
		if data.quest == "" then
			data.quest = moved
		end
	end
	if data.tutorial ~= "Done" then
		local step = Tutorial.resumeAt(data.tutorial)
		if step == "Done" then
			setStep(player, "Done", true) -- was on the old button tour: on to the quest
			return
		elseif Tutorial.index(step) == 0 then
			step = Tutorial.Steps[1]
		end
		-- The step's start already ran in an earlier visit (the charm, the gift); no welcome
		-- toast, the guide card says what to do.
		setStep(player, step, false)
		return
	end
	if Tutorial.questIndex(data.quest) > 0 then
		setQuest(player, Tutorial.resumeQuestAt(data.quest), false)
	end
end

-- The player's tutorial step, or nil once they're done (or still loading). The Bakery
-- quest doesn't count.
function TutorialService.step(player: Player): string?
	local state = states[player]
	return if state and not state.quest then state.step else nil
end

-- Admin commands: skip the rest of the tutorial (and the quest), or start it again from the
-- first step (the quest is offered again at the end).
function TutorialService.skip(player: Player)
	local data = DataService.get(player)
	if data and Tutorial.questIndex(data.quest) > 0 then
		setQuest(player, "Skipped", false)
	end
	setStep(player, "Done", false)
	if data and data.quest == "" then
		data.quest = "Skipped"
	end
end

function TutorialService.restart(player: Player)
	local data = DataService.get(player)
	if data then
		data.quest = ""
		player:SetAttribute("Quest", nil)
		player:SetAttribute("QuestSince", nil)
	end
	setStep(player, Tutorial.Steps[1], true)
end

function TutorialService.start()
	remotes.Parent = ReplicatedStorage
	DataService.onLoaded(onLoaded)

	SkipQuest.OnServerEvent:Connect(function(player)
		local state = states[player]
		if state and state.quest then
			setQuest(player, "Skipped", true)
		end
	end)

	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited < CheckSeconds then
			return
		end
		waited = 0
		for player, state in states do
			local ok, err = pcall(check, player, state)
			if not ok then
				warn(`TutorialService: {player.Name} at {state.step}: {err}`)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state then
			removeMonster(state)
		end
		states[player] = nil
	end)
end

return TutorialService
