--!strict
-- Player save data, loaded and saved through ProfileStore (session-locked, auto-saves
-- every few minutes and on leave). In Studio without API access ProfileStore falls back
-- to a mock store, so nothing persists between play tests. With API access, Studio play
-- tests save to their own store (StudioStoreName), so testing never touches real saves.
-- Money also shows in the player list (leaderstats > Money) and is only ever changed
-- through DataService.addMoney, so the two always match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cakes = require(ReplicatedStorage.Shared.Util.Cakes)
local Heists = require(ReplicatedStorage.Shared.Util.Heists)
local Missions = require(ReplicatedStorage.Shared.Util.Missions)
local Robux = require(ReplicatedStorage.Shared.Util.Robux)
local Trading = require(ReplicatedStorage.Shared.Util.Trading)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)

local DataService = {}

export type Data = {
	money: number,
	wingsOwned: number, -- the free Foyer counts as one
	monsters: { Value.CaughtMonster }, -- caught monsters roaming the mansion
	storage: { Value.CaughtMonster }, -- monsters that didn't fit, paused (Util/Storage)
	vault: { Value.CaughtMonster }, -- up to 3 monsters that can never be stolen
	inventory: { [string]: number }, -- shop items by id -> how many
	cakes: { Cakes.Placed }, -- cakes standing in the mansion (they keep going offline)
	equipped: { vacuum: string }, -- older saves also have flashlight/lens (cleared on load)
	codex: { [string]: any }, -- discovered monsters, effects and combo recipes
	shop: { slot: number, bought: { [string]: number } }, -- Workshop buys since the last restock
	stealingEnabled: boolean,
	tutorial: string, -- "New" until TutorialService looks, then the step, then "Done"
	settings: { [string]: any }, -- music, sounds, weather... (Util/Settings, SettingsService)
	seenAt: number, -- os.time() the player was last online (0: never); the "while you were away" book
	potion: { id: string, secondsLeft: number }, -- the luck potion going (Util/Potions), "" for none
	hotbar: { slots: { [string]: number }, benched: { string } }, -- Util/HotbarLayout, HotbarService
	-- The monster bubbling in the Growth Chamber (GrowthService); empty while it's free.
	chamber: {
		monster: Value.CaughtMonster?, -- already grown or shrunk; shown once endsAt passes
		mode: string?,
		endsAt: number?, -- os.time()
		won: boolean?,
		before: { kg: number, size: string, value: number }?,
		told: boolean?, -- the owner got the "it's done" toast
	},
	missions: Missions.State, -- today's daily missions and the streak (MissionService)
	robux: Robux.Record, -- Robux purchases paid out, credits and passes (RobuxService)
	heist: Heists.Record, -- play time and monsters stolen and lost (HeistService)
	trades: { Trading.LogEntry }, -- the newest trades and gifts, for checking scam reports (TradeService)
}

-- Bump when the save layout changes in a way Reconcile can't handle (renamed keys etc).
DataService.StoreName = "PlayerData_v1"
DataService.StudioStoreName = "PlayerData_Studio"

DataService.Template = {
	money = 0,
	wingsOwned = 1, -- Foyer is free
	monsters = {},
	storage = {},
	vault = {},
	inventory = {},
	cakes = {},
	equipped = { -- item ids in use; the starter vacuum is free
		vacuum = "DustBuster",
	},
	codex = {},
	shop = { slot = 0, bought = {} },
	stealingEnabled = false,
	tutorial = "New", -- older saves get this too; TutorialService marks those "Done"
	settings = {}, -- empty means the defaults (Util/Settings)
	seenAt = 0,
	potion = { id = "", secondsLeft = 0 },
	hotbar = { slots = {}, benched = {} },
	chamber = {},
	missions = Missions.empty(),
	robux = Robux.empty(),
	heist = Heists.empty(),
	trades = {},
} :: Data

local store = ProfileStore.New(
	if RunService:IsStudio() then DataService.StudioStoreName else DataService.StoreName,
	DataService.Template
)
local profiles: { [Player]: any } = {}
local moneyValues: { [Player]: NumberValue } = {}
local loadedCallbacks: { (Player, Data) -> () } = {}
local wiped: { [Player]: boolean } = {} -- reset by DataService.reset, on their way out

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
		if player.Parent == Players and not wiped[player] then
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
	data.robux = Robux.repair(data.robux)
	data.heist = Heists.repair(data.heist)

	profiles[player] = profile
	makeLeaderstats(player, data)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

-- Saves the player's profile a few seconds from now (once, however often it's asked), for
-- changes that shouldn't wait for the next auto-save or for leaving, like moving monsters.
local SaveDelay = 5
local saving: { [Player]: boolean } = {}
function DataService.saveSoon(player: Player)
	if saving[player] then
		return
	end
	saving[player] = true
	task.delay(SaveDelay, function()
		saving[player] = nil
		local profile = profiles[player]
		if profile and profile:IsActive() then
			profile:Save()
		end
	end)
end

-- Saves the player's profile now and waits until it is written (up to SaveWait seconds).
-- True once it is; false if their save isn't loaded or the write didn't finish in time. Robux
-- purchases wait on this before telling Roblox they're paid out.
local SaveWait = 30
function DataService.saveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	local saved = false
	local connection = profile.OnAfterSave:Connect(function()
		saved = true
	end)
	profile:Save()
	local deadline = os.clock() + SaveWait
	while not saved and os.clock() < deadline and profile:IsActive() do
		task.wait(0.2)
	end
	connection:Disconnect()
	return saved
end

-- Wipes this one player's save back to a brand-new one (the template) and kicks them, so
-- every service loads it fresh when they rejoin. Only this player's profile is touched.
-- Returns false if their save isn't loaded.
function DataService.reset(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	-- From here DataService.get returns nil for them, so no service's leave handler can
	-- write their old mansion, cakes or catch into the fresh save.
	profiles[player] = nil
	moneyValues[player] = nil
	wiped[player] = true
	profile.Data = {}
	profile:Reconcile() -- fills the empty table from the template, like a first join
	player:Kick("Your save was reset. Rejoin to start fresh.")
	profile:EndSession() -- saves the fresh data
	return true
end

local SeenSeconds = 30 -- how often data.seenAt is brought up to date (in case the server dies)
local present: { [Player]: boolean } = {}

-- From now on data.seenAt follows this player (MansionService calls it once it has played
-- back their time away, so a tick before that can't swallow it).
function DataService.markPresent(player: Player)
	present[player] = true
end

function DataService.start()
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player)
		wiped[player] = nil
		local profile = profiles[player]
		if profile and present[player] then
			profile.Data.seenAt = os.time()
		end
		present[player] = nil
		if profile then
			profile:EndSession()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SeenSeconds)
			for player in present do
				local profile = profiles[player]
				if profile then
					profile.Data.seenAt = os.time()
				end
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
end

return DataService
