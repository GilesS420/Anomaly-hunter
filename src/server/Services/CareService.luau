--!strict
-- Familiarity for the monsters in every mansion (rules in Util/Care, numbers in Config/Care).
-- A monster gets more familiar the longer it's in the mansion, which raises its sell value.
-- Every half minute this brings each player's monsters up to date and refreshes their labels.
-- Also keeps the Codex's list of combos the player has made.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(ReplicatedStorage.Shared.Util.Care)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)

local CareService = {}

local RefreshSeconds = 30

-- Brings the player's monsters up to date, then updates their labels.
function CareService.refresh(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local now = os.time()
	for _, caught in data.monsters do
		Care.settle(caught, now)
	end
	MansionService.refreshMonsters(player)
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

function CareService.start()
	DataService.onLoaded(function(player)
		CareService.refresh(player)
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
