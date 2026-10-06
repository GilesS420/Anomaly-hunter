--!strict
-- Player save data, loaded and saved through ProfileStore (session-locked, auto-saves
-- every few minutes and on leave). In Studio without API access ProfileStore falls back
-- to a mock store, so nothing persists between play tests.
-- Money also shows in the player list (leaderstats > Money) and is only ever changed
-- through DataService.addMoney, so the two always match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Value = require(ReplicatedStorage.Shared.Util.Value)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)

local DataService = {}

export type Data = {
	money: number,
	wingsOwned: number, -- the free Foyer counts as one
	monsters: { Value.CaughtMonster }, -- caught monsters roaming the mansion
	vault: { Value.CaughtMonster }, -- up to 3 monsters that can never be stolen
	inventory: { [string]: number }, -- shop items by id -> how many
	equipped: { flashlight: string, vacuum: string, lens: string },
	codex: { [string]: any }, -- discovered monsters, effects and combo recipes
	shop: { slot: number, bought: { [string]: number } }, -- Workshop buys since the last restock
	stealingEnabled: boolean,
}

-- Bump when the save layout changes in a way Reconcile can't handle (renamed keys etc).
DataService.StoreName = "PlayerData_v1"

DataService.Template = {
	money = 0,
	wingsOwned = 1, -- Foyer is free
	monsters = {},
	vault = {},
	inventory = {},
	equipped = { -- item ids in use; the starter tools are free
		flashlight = "CandleLamp",
		vacuum = "DustBuster",
		lens = "", -- "" for none
	},
	codex = {},
	shop = { slot = 0, bought = {} },
	stealingEnabled = false,
} :: Data

local store = ProfileStore.New(DataService.StoreName, DataService.Template)
local profiles: { [Player]: any } = {}
local moneyValues: { [Player]: NumberValue } = {}
local loadedCallbacks: { (Player, Data) -> () } = {}

-- Returns the player's data, or nil while it is still loading (or after they left).
function DataService.get(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- True once the player's save has loaded (and until they leave).
function DataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Runs callback for every player whose data finishes loading, including ones already loaded.
function DataService.onLoaded(callback: (Player, Data) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

-- Adds (or with a negative delta, takes away) money. Returns false and changes nothing if
-- the save isn't loaded or the player can't afford it.
function DataService.addMoney(player: Player, delta: number): boolean
	local data = DataService.get(player)
	if not data or delta ~= delta or math.abs(delta) == math.huge then
		return false -- not loaded, or NaN / infinity
	end
	local total = data.money + delta
	if total < 0 then
		return false
	end
	data.money = total
	local money = moneyValues[player]
	if money then
		money.Value = total
	end
	return true
end

-- The player list shows leaderstats > Money for everyone in the server.
local function makeLeaderstats(player: Player, data: Data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local money = Instance.new("NumberValue")
	money.Name = "Money"
	money.Value = data.money
	money.Parent = leaderstats
	leaderstats.Parent = player
	moneyValues[player] = money
end

local function loadPlayer(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Another server kept the session or DataStores are down; never play on unsaved data.
		if player.Parent == Players then
			player:Kick("Your save couldn't be loaded. Please rejoin.")
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR compliance
	profile:Reconcile() -- fills in keys added to the template since the last save

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		moneyValues[player] = nil
		-- Only kick if they're still here (the session also ends normally when they leave).
		if player.Parent == Players then
			player:Kick("Your save was opened on another server. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession() -- left while loading
		return
	end

	local data = profile.Data :: Data
	if typeof(data.money) ~= "number" or data.money ~= data.money or data.money < 0 then
		data.money = 0 -- repair a broken balance rather than carry it around
	end

	profiles[player] = profile
	makeLeaderstats(player, data)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

function DataService.start()
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
end

return DataService
