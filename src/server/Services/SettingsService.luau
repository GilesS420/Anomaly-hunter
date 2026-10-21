--!strict
-- Saves each player's settings (Shared.Util.Settings lists them) in data.settings and copies
-- them to player attributes (SettingMusic, SettingWeather, ...) so their client can use them.
--
-- Remotes in ReplicatedStorage.SettingsRemotes:
--   Set  client -> server (key, value)   changes one setting; anything not allowed is ignored

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Util.Settings)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

local remotes = Instance.new("Folder")
remotes.Name = "SettingsRemotes"
local Set = Instance.new("RemoteEvent")
Set.Name = "Set"
Set.Parent = remotes

local function publish(player: Player, data: DataService.Data)
	-- Only what the player picked is kept in the save, so a changed default reaches everyone
	-- who never touched that setting. Broken values and old keys are dropped.
	for key, saved in data.settings do
		if not Settings.valid(key, saved) then
			data.settings[key] = nil
		end
	end
	for _, setting in Settings.List do
		player:SetAttribute(
			Settings.attribute(setting.key),
			Settings.value(setting.key, data.settings[setting.key])
		)
	end
end

Set.OnServerEvent:Connect(function(player: Player, key: unknown, value: unknown)
	local data = DataService.get(player)
	if not data or typeof(key) ~= "string" or not Settings.valid(key, value) then
		return
	end
	data.settings[key] = value
	player:SetAttribute(Settings.attribute(key), value)
	DataService.saveSoon(player)
end)

function SettingsService.start()
	remotes.Parent = ReplicatedStorage
	DataService.onLoaded(publish)
end

return SettingsService
