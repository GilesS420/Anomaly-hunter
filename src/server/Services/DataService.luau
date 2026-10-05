--!strict
-- Player save data, loaded and saved through ProfileStore (session-locked, auto-saves
-- every few minutes and on leave). In Studio without API access ProfileStore falls back
-- to a mock store, so nothing persists between play tests.

local Players = game:GetService("Players")

local ProfileStore = require("../Vendor/ProfileStore")

local DataService = {}

-- Bump when the save layout changes in a way Reconcile can't handle (renamed keys etc).
DataService.StoreName = "PlayerData_v1"

DataService.Template = {
	money = 0,
	wingsOwned = 1, -- Foyer is free
	monsters = {}, -- caught monsters roaming the mansion
	vault = {}, -- up to 3 monsters that can never be stolen
	inventory = {}, -- shop items by id
	codex = {}, -- discovered monsters, effects and combo recipes
	stealingEnabled = false,
}

export type Data = typeof(DataService.Template)

local store = ProfileStore.New(DataService.StoreName, DataService.Template)
local profiles: { [Player]: any } = {}
local loadedCallbacks: { (Player, Data) -> () } = {}

-- Returns the player's data, or nil while it is still loading (or after they left).
function DataService.get(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Runs callback for every player whose data finishes loading, including ones already loaded.
function DataService.onLoaded(callback: (Player, Data) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

local function loadPlayer(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Another server kept the session or DataStores are down; never play on unsaved data.
		player:Kick("Your save couldn't be loaded. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR compliance
	profile:Reconcile() -- fills in keys added to the template since the last save

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save was opened on another server. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession() -- left while loading
		return
	end

	profiles[player] = profile
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile.Data)
	end
end

function DataService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
