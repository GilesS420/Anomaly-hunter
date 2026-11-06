--!strict
-- Sends Roblox analytics events for Creator Hub > Analytics (rules in Shared.Util.Analytics):
--   Funnels   Onboarding (one-time): join > first catch > ... > tutorial done > first wings
--             NewPlayersV4 (one-time): the same steps, versioned (Analytics.OnboardingFunnel)
--             FirstVisitV1 (one-time): minutes played on a new player's first day
--             BakeryQuest (one-time): the optional cake quest after the tutorial
--             Comeback (one-time): played on 1, 2, 3, 5, 7, 14 different days
--             Robux purchase (recurring): prompt shown > paid, per product
--             Playtime (recurring, one session a day): playtime gifts 1 to 6 claimed
--   Economy   every Money source (selling, missions...) and sink (shops, wings, fees)
--   Custom    RobuxSpent (value = Robux paid for a developer product)
--             SessionMinutes (everyone) and NewPlayerLeft (new players, first day): sent when
--             a player leaves, value = minutes this visit, fields = stage (tutorial step,
--             quest step or free play), place (zone or Hub) and the length bucket
-- Server only: Roblox ignores these from the client and from Studio (Studio prints them in
-- Output instead when DebugInStudio is on). Every call is wrapped in pcall, so analytics can
-- never break gameplay.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Analytics = require(ReplicatedStorage.Shared.Util.Analytics)
local DataService = require(script.Parent.DataService)

local Service = {}

local IsStudio = RunService:IsStudio()
local DebugInStudio = true -- Studio: print what would be sent
local CheckSeconds = 1
local Currency = "Money"
-- The first custom field's key ("CustomField01"); looked up safely so a missing enum can
-- never stop the services that require this one.
local Field1, Field2, Field3 = "CustomField01", "CustomField02", "CustomField03"
pcall(function()
	local keys = (Enum :: any).AnalyticsCustomFieldKeys
	Field1, Field2, Field3 = keys.CustomField01.Name, keys.CustomField02.Name, keys.CustomField03.Name
end)

-- Robux funnel sessions waiting for the payment: player -> product key -> session id.
local robuxSessions: { [Player]: { [string]: string } } = {}

-- This visit, per player: when it started and what they were last doing (kept up to date every
-- check, because the save may already be gone by the time PlayerRemoving fires).
type Visit = { started: number, stage: string, place: string, newPlayer: boolean }
local visits: { [Player]: Visit } = {}

local function send(what: string, fn: () -> ())
	if IsStudio then
		if DebugInStudio then
			print(`[Analytics] {what}`)
		end
		return
	end
	local ok, err = pcall(fn)
	if not ok then
		warn(`AnalyticsService: {what} failed: {err}`)
	end
end

local function onboardStep(player: Player, step: number)
	local name = Analytics.Onboarding[step]
	send(`{player.Name} onboarding {step} {name}`, function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
		-- The same step in a versioned funnel (Analytics.OnboardingFunnel), clean of old numbering.
		AnalyticsService:LogFunnelStepEvent(player, Analytics.OnboardingFunnel, nil :: any, step, name)
	end)
end

local function comebackStep(player: Player, step: number)
	local name = Analytics.comebackName(step)
	send(`{player.Name} Comeback {step} {name}`, function()
		-- One-time funnel: no session id.
		AnalyticsService:LogFunnelStepEvent(player, "Comeback", nil :: any, step, name)
	end)
end

-- Sends the steps this player has newly reached (each only once, saved in their profile).
local function check(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local rec = data.analytics
	if rec.onboard == 0 then
		if data.tutorial == "New" then
			return -- TutorialService hasn't looked at the save yet
		elseif data.tutorial == "Done" then
			rec.onboard = -1 -- an older player: not part of the new-player funnels
			DataService.saveSoon(player)
			return
		end
	end
	if rec.onboard < 0 then
		return
	end
	local changed = false

	local reached = Analytics.onboardStep(data.tutorial, data.wingsOwned)
	while rec.onboard < reached do
		rec.onboard += 1
		onboardStep(player, rec.onboard)
		changed = true
	end

	local today = Analytics.day(os.time())
	if rec.lastDay ~= today then
		rec.lastDay = today
		rec.days += 1
		local step = Analytics.comebackStep(rec.days)
		if step then
			comebackStep(player, step)
		end
		changed = true
	end

	-- New players on their first day: minutes played, for the FirstVisit funnel.
	if rec.days == 1 then
		rec.firstSeconds += CheckSeconds
		local marks = Analytics.marksReached(rec.firstSeconds / 60)
		while rec.marks < marks do
			rec.marks += 1
			local step, name = rec.marks, Analytics.markName(rec.marks)
			send(`{player.Name} first visit {name}`, function()
				AnalyticsService:LogFunnelStepEvent(player, Analytics.FirstVisitFunnel, nil :: any, step, name)
			end)
			changed = true
		end
	end

	if changed then
		DataService.saveSoon(player)
	end
end

-- What the player is doing right now, for the custom event when they leave.
local function track(player: Player)
	local visit = visits[player]
	local data = DataService.get(player)
	if not visit or not data then
		return
	end
	visit.stage = Analytics.stageOf(data.tutorial, data.quest)
	local zone = player:GetAttribute("Zone")
	visit.place = if typeof(zone) == "string" then zone else "Hub"
	visit.newPlayer = data.analytics.onboard > 0 and data.analytics.days <= 1
end

-- They left: how long they stayed and what they were doing.
local function left(player: Player)
	local visit = visits[player]
	visits[player] = nil
	if not visit then
		return
	end
	local minutes = math.floor((os.clock() - visit.started) / 6) / 10 -- one decimal
	local bucket = Analytics.lengthBucket(minutes)
	send(`{player.Name} left after {minutes} min ({visit.stage}, {visit.place})`, function()
		local fields = { [Field1] = visit.stage, [Field2] = visit.place, [Field3] = bucket }
		AnalyticsService:LogCustomEvent(player, "SessionMinutes", minutes, fields)
		if visit.newPlayer then
			AnalyticsService:LogCustomEvent(player, "NewPlayerLeft", minutes, fields)
		end
	end)
end

-- Money came in (delta > 0) or went out (delta < 0), already applied to the save.
-- kind: an Enum.AnalyticsEconomyTransactionType name (Shop, Gameplay, TimedReward,
-- Onboarding...) or our own short word; sku: what it was for (an item id, "Sell"...).
function Service.money(player: Player, delta: number, kind: string, sku: string)
	if delta == 0 or delta ~= delta then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local source = delta > 0
	local amount = math.abs(delta)
	local balance = data.money
	local sign = if source then "+" else "-"
	send(`{player.Name} {sign}{amount} {Currency} ({kind}/{sku}), now {balance}`, function()
		local flows = Enum.AnalyticsEconomyFlowType
		local flow = if source then flows.Source else flows.Sink
		AnalyticsService:LogEconomyEvent(player, flow, Currency, amount, balance, kind, sku)
	end)
end

-- A player reached this step of the Bakery quest (Analytics.questStep).
function Service.questStep(player: Player, step: number)
	local name = Analytics.Quest[step]
	if not name then
		return
	end
	send(`{player.Name} quest {step} {name}`, function()
		AnalyticsService:LogFunnelStepEvent(player, "BakeryQuest", nil :: any, step, name)
	end)
end

-- A playtime gift was claimed (step 1 to 6 of Config/Playtime.Steps), in that day's funnel.
function Service.playtimeGift(player: Player, day: number, step: number, minutes: number)
	local name = `{minutes} min gift`
	send(`{player.Name} playtime {step} {name}`, function()
		AnalyticsService:LogFunnelStepEvent(player, "Playtime", `{player.UserId}-{day}`, step, name)
	end)
end

-- A Robux prompt for this product (developer product key or pass name) was opened.
function Service.robuxPrompt(player: Player, product: string)
	local sessions = robuxSessions[player]
	if not sessions then
		sessions = {}
		robuxSessions[player] = sessions
	end
	local id = HttpService:GenerateGUID(false)
	sessions[product] = id
	send(`{player.Name} Robux prompt {product}`, function()
		local fields = { [Field1] = product }
		AnalyticsService:LogFunnelStepEvent(player, "RobuxPurchase", id, 1, "Prompt shown", fields)
	end)
end

-- The Robux were paid (robux: how many, 0 when not known, like for a pass).
function Service.robuxPaid(player: Player, product: string, robux: number)
	local sessions = robuxSessions[player]
	local id = sessions and sessions[product]
	if sessions then
		sessions[product] = nil
	end
	-- Paid with no prompt this visit (Roblox retries a receipt after a rejoin): its own session.
	local session = id or HttpService:GenerateGUID(false)
	send(`{player.Name} Robux paid {product} ({robux} R$)`, function()
		local fields = { [Field1] = product }
		AnalyticsService:LogFunnelStepEvent(player, "RobuxPurchase", session, 2, "Paid", fields)
		if robux > 0 then
			AnalyticsService:LogCustomEvent(player, "RobuxSpent", robux, fields)
		end
	end)
end

function Service.start()
	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited < CheckSeconds then
			return
		end
		waited = 0
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(check, player)
			if ok then
				ok, err = pcall(track, player)
			end
			if not ok then
				warn(`AnalyticsService: {player.Name}: {err}`)
			end
		end
	end)
	local function joined(player: Player)
		visits[player] = { started = os.clock(), stage = "Loading", place = "Hub", newPlayer = false }
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		robuxSessions[player] = nil
		left(player)
	end)
end

return Service
