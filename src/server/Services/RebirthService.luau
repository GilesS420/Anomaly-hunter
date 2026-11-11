--!strict
-- Rebirth (thread "Add patterns from top Roblox games", 2026-11-11). Numbers in
-- Config/Rebirth, rules in Util/Rebirth. Once every wing is owned, the expand sign becomes
-- the Rebirth sign; pressing it opens the client's Rebirth card (RebirthController).
-- Rebirthing resets money, wings, every monster (mansion, Backpack, Vault) and the cakes
-- standing out (they go back in the hotbar), and gives +50% Collector money for good
-- (Perks.sellBonuses reads the Rebirths attribute). Tools, items, the Codex, badges,
-- missions and Robux purchases stay.
--
-- Player attribute Rebirths (rebirths done, nil for none); leaderstats > Rebirths.
--
-- Remotes in ReplicatedStorage.RebirthRemotes:
--   Offer    server -> client (View)              the owner pressed the sign
--   Rebirth  client -> server ("Rebirth") -> Result   (the word guards against junk calls)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Rebirth = require(ReplicatedStorage.Shared.Util.Rebirth)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CakeService = require(script.Parent.CakeService)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local MansionService = require(script.Parent.MansionService)
local PlotService = require(script.Parent.PlotService)
local Notify = require(script.Parent.Parent.Notify)
local TradeService = require(script.Parent.TradeService)

local RebirthService = {}

export type View = {
	done: number, -- rebirths so far
	cost: number, -- money needed for the next one
	money: number,
	bonusNow: number, -- Collector bonus now, whole percent
	bonusNext: number, -- after the next rebirth
	ready: boolean, -- every wing owned and enough money
}
export type Result = { ok: boolean, message: string, view: View? }

local Word = "Rebirth"

local remotes = Instance.new("Folder")
remotes.Name = "RebirthRemotes"
local Offer = Instance.new("RemoteEvent")
Offer.Name = "Offer"
Offer.Parent = remotes
local RebirthRemote = Instance.new("RemoteFunction")
RebirthRemote.Name = "Rebirth"
RebirthRemote.Parent = remotes

local busy: { [Player]: boolean } = {}

local function viewFor(data: DataService.Data): View
	local done = Rebirth.count(data.rebirths)
	return {
		done = done,
		cost = Rebirth.cost(done),
		money = data.money,
		bonusNow = Rebirth.bonusPercent(done),
		bonusNext = Rebirth.bonusPercent(done + 1),
		ready = Rebirth.check(data.wingsOwned, data.money, done) == "Ok",
	}
end

local function show(player: Player, done: number)
	player:SetAttribute("Rebirths", if done > 0 then done else nil)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Rebirths")
	if value and value:IsA("IntValue") then
		value.Value = done
	end
end

-- Why this player can't rebirth right now, or nil when they can.
local function blocker(player: Player, data: DataService.Data): string?
	if data.tutorial ~= "Done" then
		return "Finish the tutorial first."
	end
	local done = Rebirth.count(data.rebirths)
	local check = Rebirth.check(data.wingsOwned, data.money, done)
	if check == "NotComplete" then
		return "Buy every wing first."
	elseif check == "TooPoor" then
		return `You need {Format.money(Rebirth.cost(done))}.`
	end
	if player:GetAttribute("Zone") ~= nil then
		return "Go home first."
	end
	if HuntService.isCarrying(player) then
		return "Drop off the monsters you're carrying first."
	end
	if TradeService.isTrading(player) then
		return "Finish your trade first."
	end
	if data.chamber and data.chamber.monster then
		return "Take your monster out of the Growth Chamber first."
	end
	return nil
end

local function reborn(player: Player, data: DataService.Data): Result
	local done = Rebirth.count(data.rebirths)
	-- Every monster goes: off the floor, out of the Backpack, out of the Vault.
	local uids: { [string]: boolean } = {}
	for _, list in { data.monsters, data.storage } do
		for _, caught in list do
			if caught.uid then
				uids[caught.uid] = true
			end
		end
	end
	MansionService.removeMonsters(player, uids)
	table.clear(data.monsters)
	table.clear(data.storage)
	table.clear(data.vault)
	CakeService.packUp(player)
	local money = data.money
	if money > 0 and DataService.addMoney(player, -money) then
		AnalyticsService.money(player, -money, "Gameplay", "Rebirth")
	end
	data.wingsOwned = 1
	data.rebirths = done + 1
	show(player, data.rebirths)
	MansionService.rebuild(player)
	MansionService.refreshMonsters(player)
	-- The wing they stood in may be gone: put them at their mansion's front door.
	local home = PlotService.spawnCFrame(player)
	if home then
		PlotService.teleport(player, home)
	end
	DataService.saveSoon(player)
	local bonus = Rebirth.bonusPercent(data.rebirths)
	Notify.toastAll(`{player.DisplayName} was reborn! Rebirth {data.rebirths} (+{bonus}% sell)`)
	return { ok = true, message = `Reborn! +{bonus}% sell forever.`, view = viewFor(data) }
end

RebirthRemote.OnServerInvoke = function(player: Player, word: unknown): Result
	if word ~= Word then
		return { ok = false, message = "" }
	end
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading." }
	end
	if busy[player] then
		return { ok = false, message = "" }
	end
	local why = blocker(player, data)
	if why then
		return { ok = false, message = why, view = viewFor(data) }
	end
	busy[player] = true
	local ok, result = pcall(reborn, player, data)
	busy[player] = nil
	if not ok then
		warn(`RebirthService: {player.Name}: {result}`)
		return { ok = false, message = "Something went wrong, try again." }
	end
	return result
end

-- Admin / Studio: sets how many rebirths a player has done (no reset).
function RebirthService.set(player: Player, count: number): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	data.rebirths = math.max(0, math.floor(count))
	show(player, data.rebirths)
	MansionService.refreshSign(player)
	return true
end

function RebirthService.start()
	remotes.Parent = ReplicatedStorage
	DataService.onLoaded(function(player, data)
		data.rebirths = Rebirth.count(data.rebirths)
		show(player, data.rebirths)
	end)
	MansionService.onRebirthPressed(function(player)
		local data = DataService.get(player)
		if data then
			Offer:FireClient(player, viewFor(data))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return RebirthService
