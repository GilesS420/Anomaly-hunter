--!strict
-- One-time unlock tutorials (the list, conditions and words are in Shared.Util.Tips). Once a
-- player's first-timer tutorial is done, this looks every second whether one of their tips
-- has come due (they bought their first slapper, own the Ballroom, an event started...) and
-- shows the first unseen one by setting the player attribute Tip to its id. The client draws
-- it in the tutorial's card (TutorialController) and fires Seen when they press Got it; only
-- then is it saved as seen (data.tips), so leaving before that shows it again next time.
-- One at a time, Tips.GapSeconds apart. A live tip (an event, the Golden Ghost) whose
-- moment passes before Got it goes away unseen.
--
-- Remotes in ReplicatedStorage.TipRemotes:
--   Seen   client -> server (id: string)   the card on screen was closed

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Tips = require(ReplicatedStorage.Shared.Util.Tips)
local DataService = require(script.Parent.DataService)
local GoldenGhostService = require(script.Parent.GoldenGhostService)
local TutorialService = require(script.Parent.TutorialService)

local TipService = {}

local CheckSeconds = 1

-- os.clock() before which no new tip is shown to that player.
local waitUntil: { [Player]: number } = {}
-- A tip an admin showed with /tip: it stays up until Got it, even if its moment is over.
local forced: { [Player]: string } = {}

local remotes = Instance.new("Folder")
remotes.Name = "TipRemotes"
local Seen = Instance.new("RemoteEvent")
Seen.Name = "Seen"
Seen.Parent = remotes

-- Shop item id -> its kind (Slapper, Lure, Food...).
local kindOf: { [string]: string } = {}
for _, list in { Shop.Workshop, Shop.Bakery } do
	for _, item in list do
		kindOf[item.id] = item.kind
	end
end

local function factsFor(player: Player, data: DataService.Data): Tips.Facts
	local owns: { [string]: boolean } = {}
	for id, count in data.inventory do
		local kind = kindOf[id]
		if kind and typeof(count) == "number" and count > 0 then
			owns[kind] = true
		end
	end
	local combos = data.codex.combos
	return {
		wings = data.wingsOwned,
		owns = owns,
		pair = Tips.hasPair(data.storage),
		combo = typeof(combos) == "table" and next(combos) ~= nil,
		playSeconds = data.heist.playSeconds,
		event = workspace:GetAttribute("WatcherEvent") ~= nil,
		ghost = GoldenGhostService.isOut(),
		inHub = player:GetAttribute("Zone") == nil,
		gift = (tonumber(player:GetAttribute("PlaytimeReady")) or 0) > 0,
		spin = (tonumber(player:GetAttribute("SpinLeft")) or 0) > 0,
	}
end

local function show(player: Player, id: string?)
	player:SetAttribute("Tip", id)
end

local function check(player: Player)
	local data = DataService.get(player)
	-- No tips during the tutorial or the Bakery quest: one card at a time.
	local questing = data ~= nil and player:GetAttribute("Quest") ~= nil
	if not data or data.tutorial ~= "Done" or TutorialService.step(player) ~= nil or questing then
		if player:GetAttribute("Tip") ~= nil then
			show(player, nil) -- the tutorial was restarted
		end
		waitUntil[player] = os.clock() + Tips.FirstSeconds
		return
	end
	if not waitUntil[player] then
		waitUntil[player] = os.clock() + Tips.FirstSeconds -- just joined: let them land first
		return
	end
	local facts = factsFor(player, data)
	local current = player:GetAttribute("Tip")
	if typeof(current) == "string" then
		if forced[player] ~= current and Tips.expired(current, facts) then
			show(player, nil)
			waitUntil[player] = os.clock() + Tips.GapSeconds
		end
		return
	end
	if os.clock() < (waitUntil[player] or 0) then
		return
	end
	show(player, Tips.next(facts, data.tips))
end

-- Admin commands (DevService): forget every seen tip, or show one now whatever its condition.
function TipService.reset(player: Player)
	local data = DataService.get(player)
	if data then
		data.tips = {}
		DataService.saveSoon(player)
	end
	forced[player] = nil
	show(player, nil)
	waitUntil[player] = 0
end

function TipService.force(player: Player, id: string): boolean
	if not Tips.get(id) then
		return false
	end
	forced[player] = id
	show(player, id)
	return true
end

function TipService.start()
	remotes.Parent = ReplicatedStorage

	Seen.OnServerEvent:Connect(function(player, id)
		if typeof(id) ~= "string" or player:GetAttribute("Tip") ~= id then
			return
		end
		local data = DataService.get(player)
		if not data then
			return
		end
		data.tips[id] = true
		DataService.saveSoon(player)
		forced[player] = nil
		show(player, nil)
		waitUntil[player] = os.clock() + Tips.GapSeconds
	end)

	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited < CheckSeconds then
			return
		end
		waited = 0
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(check, player)
			if not ok then
				warn(`TipService: {player.Name}: {err}`)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		waitUntil[player] = nil
		forced[player] = nil
	end)
end

return TipService
