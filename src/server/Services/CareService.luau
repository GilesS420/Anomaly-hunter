--!strict
-- Feeding and Familiarity for the monsters in every mansion (rules in Util/Care, numbers in
-- Config/Care). A monster stays fed for a day after it's caught or fed. While it's fed its
-- Familiarity grows, which raises its sell value; once it's hungry it stops growing and its
-- effects fall asleep until it's fed again. Every half minute this brings each player's
-- monsters up to date, refreshes their labels and tells the client how many need food.
--
-- Remotes in ReplicatedStorage.CareRemotes:
--   FeedAll  client -> server () -> string   feeds every monster in your mansion, for free
-- Player attributes (for the Feed all button):
--   Hungry      how many of your monsters are hungry right now
--   HungrySoon  how many are hungry or get hungry within Config/Care.HungrySoonHours

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(ReplicatedStorage.Shared.Util.Care)
local CareConfig = require(ReplicatedStorage.Shared.Config.Care)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)
local Notify = require(script.Parent.Parent.Notify)

local CareService = {}

local RefreshSeconds = 30
local FeedCooldown = 1 -- seconds between two Feed all taps

local remotes = Instance.new("Folder")
remotes.Name = "CareRemotes"
local FeedAll = Instance.new("RemoteFunction")
FeedAll.Name = "FeedAll"
FeedAll.Parent = remotes

local lastFed: { [Player]: number } = {}

-- Brings the player's monsters up to date, then updates their labels and the Feed all button.
function CareService.refresh(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local now = os.time()
	local hungry, soon = 0, 0
	for _, caught in data.monsters do
		Care.settle(caught, now)
		if not caught.fed then
			hungry += 1
		end
		if Care.needsFood(caught, now) then
			soon += 1
		end
	end
	player:SetAttribute("Hungry", hungry)
	player:SetAttribute("HungrySoon", soon)
	MansionService.refreshMonsters(player)
end

-- Feeds every monster in the player's mansion and returns the message for them.
function CareService.feedAll(player: Player): string
	local data = DataService.get(player)
	if not data then
		return "Your save is still loading. Try again in a moment!"
	end
	if #data.monsters == 0 then
		return "Your mansion is empty. Catch some monsters first!"
	end
	local now = os.time()
	for _, caught in data.monsters do
		Care.feed(caught, now)
	end
	CareService.refresh(player)
	local count = #data.monsters
	local what = if count == 1 then "your monster" else `all {count} monsters`
	return `You fed {what}! They stay fed for {CareConfig.FedHours} hours.`
end

-- Remembers a combo the player has made, for the Codex (data.codex.combos[id] = true).
function CareService.discoverCombo(data: DataService.Data, comboId: string)
	local combos = data.codex.combos
	if typeof(combos) ~= "table" then
		combos = {}
		data.codex.combos = combos
	end
	combos[comboId] = true
end

FeedAll.OnServerInvoke = function(player: Player): string
	local now = os.clock()
	if now - (lastFed[player] or 0) < FeedCooldown then
		return ""
	end
	lastFed[player] = now
	local message = CareService.feedAll(player)
	Notify.toast(player, message)
	return message
end

function CareService.start()
	remotes.Parent = ReplicatedStorage
	DataService.onLoaded(function(player)
		CareService.refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastFed[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(RefreshSeconds)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					CareService.refresh(player)
				end)
				if not ok then
					warn(`CareService: refreshing {player.Name} failed: {err}`)
				end
			end
		end
	end)
end

return CareService
