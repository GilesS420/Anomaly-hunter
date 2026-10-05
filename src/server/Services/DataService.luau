--!strict
-- Player save data. The template below is the shape of a save; loading and saving
-- will go through ProfileService (see the README for adding it).

local Players = game:GetService("Players")

local DataService = {}

DataService.Template = {
	money = 0,
	wingsOwned = 1, -- Foyer is free
	monsters = {}, -- caught monsters roaming the mansion
	vault = {}, -- up to 3 monsters that can never be stolen
	inventory = {}, -- shop items by id
	codex = {}, -- discovered monsters, effects and combo recipes
	stealingEnabled = false,
}

local profiles: { [Player]: typeof(DataService.Template) } = {}

function DataService.get(player: Player)
	return profiles[player]
end

function DataService.start()
	Players.PlayerAdded:Connect(function(player)
		-- TODO: load with ProfileService instead of a fresh copy.
		profiles[player] = table.clone(DataService.Template)
	end)
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)
end

return DataService
