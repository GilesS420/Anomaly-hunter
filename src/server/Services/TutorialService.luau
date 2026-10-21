--!strict
-- The first-timer tutorial (steps, unlocks and words in Shared.Util.Tutorial). A brand-new
-- save starts it; older saves count as done, so existing players never see it. Each step
-- moves on by itself when the player has done what it asks, by watching the save and the
-- hunt attributes:
--   Gate    walk into Pumpkin Graveyard
--   Catch   catch the Gloomlet that waits there, reserved for them (and a free Return Charm)
--   Home    bring it home (the exit or the charm); it picks up Cobwebbed straight away
--   Pickup  pick it up into the Backpack (E next to it)
--   Sell    sell it at the Collector, who then tops their money up to the Phantom Vac's price
--   Buy     buy the Phantom Vac (always in stock for them during this step, WorkshopService)
--   Tour    the client shows what each button does, then fires Finish
-- Losing the catch (knocked out, or leaving the zone or the game) goes back to Gate. Nothing
-- attacks a player in the tutorial (MonsterAiService) and fast travel to a locked button
-- is refused (TravelService). The player attribute Tutorial holds the step (nil once done)
-- and TutorialSince when it started (server time), for the client's "stuck?" hint.
--
-- Remotes in ReplicatedStorage.TutorialRemotes:
--   Finish   client -> server ()   the tour is over

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Tutorial = require(ReplicatedStorage.Shared.Util.Tutorial)
local DataService = require(script.Parent.DataService)
local HauntService = require(script.Parent.HauntService)
local HuntService = require(script.Parent.HuntService)
local SpawnService = require(script.Parent.SpawnService)
local Notify = require(script.Parent.Parent.Notify)

local TutorialService = {}

type State = {
	step: string,
	monster: Model?, -- the Gloomlet waiting in the zone (Catch)
	spawnAt: number?, -- os.clock() when to bring (another) one
	tourEnds: number?, -- os.clock() when an unfinished tour ends by itself
}

local CheckSeconds = 0.5
local TourTimeout = 180 -- a tour nobody finishes (the window was closed, say) ends anyway

local states: { [Player]: State } = {}

local remotes = Instance.new("Folder")
remotes.Name = "TutorialRemotes"
local Finish = Instance.new("RemoteEvent")
Finish.Name = "Finish"
Finish.Parent = remotes

local firstVacuumPrice = 0
for _, item in Shop.Workshop do
	if item.id == Tutorial.FirstVacuum then
		firstVacuumPrice = item.price
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
		state.spawnAt = os.clock() + 1 -- once they've landed in the zone
	elseif step == "Pickup" then
		HauntService.give(player, Tutorial.Effect)
	elseif step == "Buy" then
		local gift = Tutorial.gift(data.money, firstVacuumPrice)
		if gift > 0 and DataService.addMoney(player, gift) then
			Notify.toast(
				player,
				`The Collector likes new hunters: {Format.money(gift)} for your first vacuum!`
			)
		end
	elseif step == "Tour" then
		state.tourEnds = os.clock() + TourTimeout
	end
end

-- Moves the player to this step (or "Done"), saves it and runs the step's start.
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
		if run then
			Notify.toast(player, "Tutorial complete! Everything is unlocked. Happy hunting!")
		end
		return
	end
	local state: State = { step = step }
	states[player] = state
	player:SetAttribute("Tutorial", step)
	player:SetAttribute("TutorialSince", workspace:GetServerTimeNow())
	if run then
		enter(player, data, state)
	end
end

-- Brings the tutorial's Gloomlet to the player, marked so their client can point at it.
local function bringMonster(player: Player, state: State)
	state.spawnAt = nil
	local ok, _, model = SpawnService.spawnFor(player, Tutorial.Monster, "Normal")
	if ok and model then
		model:SetAttribute("TutorialFor", player.UserId)
		state.monster = model
	else
		state.spawnAt = os.clock() + Tutorial.RespawnSeconds -- too crowded: try again soon
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
			local monster = state.monster
			if monster and not monster.Parent then
				state.monster = nil -- wandered off or timed out
			end
			if not state.monster then
				local at = state.spawnAt
				if not at then
					state.spawnAt = os.clock() + Tutorial.RespawnSeconds
				elseif os.clock() >= at then
					bringMonster(player, state)
				end
			end
		end
	elseif step == "Home" then
		if zone == nil and not carrying then
			setStep(player, if owned > 0 then "Pickup" else "Gate", true)
		end
	elseif step == "Pickup" then
		if #data.storage > 0 then
			setStep(player, "Sell", true)
		elseif owned == 0 then
			setStep(player, "Gate", true)
		end
	elseif step == "Sell" then
		if data.money > 0 then
			setStep(player, "Buy", true)
		elseif owned == 0 then
			setStep(player, "Gate", true)
		end
	elseif step == "Buy" then
		if (data.inventory[Tutorial.FirstVacuum] or 0) > 0 then
			setStep(player, "Tour", true)
		end
	elseif step == "Tour" then
		local ends = state.tourEnds
		if ends and os.clock() >= ends then
			setStep(player, "Done", true)
		end
	end
end

local function onLoaded(player: Player, data: DataService.Data)
	if data.tutorial == "New" then
		local fresh = Tutorial.isFresh(
			data.money,
			#data.monsters,
			#data.storage,
			data.wingsOwned,
			paidItems(data.inventory)
		)
		data.tutorial = if fresh then "Gate" else "Done"
	end
	if data.tutorial == "Done" then
		return
	end
	local step = Tutorial.resumeAt(data.tutorial)
	if Tutorial.index(step) == 0 then
		step = "Gate"
	end
	-- The step's start already ran in an earlier visit (the charm, the gift), except the tour.
	setStep(player, step, step == "Tour")
	if step == "Gate" then
		Notify.toast(player, "Welcome, hunter! Let's catch your first monster.")
	end
end

-- The player's step, or nil once they're done (or still loading).
function TutorialService.step(player: Player): string?
	local state = states[player]
	return if state then state.step else nil
end

-- Admin commands: skip the rest of the tutorial, or start it again from the first step.
function TutorialService.skip(player: Player)
	setStep(player, "Done", false)
end

function TutorialService.restart(player: Player)
	setStep(player, "Gate", true)
end

function TutorialService.start()
	remotes.Parent = ReplicatedStorage
	DataService.onLoaded(onLoaded)

	Finish.OnServerEvent:Connect(function(player)
		local state = states[player]
		if state and state.step == "Tour" then
			setStep(player, "Done", true)
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
