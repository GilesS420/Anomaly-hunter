--!strict
-- Your settings on this client: read from the player attributes the server keeps
-- (server/Services/SettingsService), with the defaults from Shared.Util.Settings until your
-- save has loaded. Settings.set asks the server to change one; Settings.changed runs a
-- function whenever any of them changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Settings"))

local Settings = {}

local player = Players.LocalPlayer

function Settings.get(key: string): any
	return Shared.value(key, player:GetAttribute(Shared.attribute(key)))
end

-- Volume settings as 0 to 1.
function Settings.volume(key: string): number
	local value = Settings.get(key)
	return if typeof(value) == "number" then value / 100 else 1
end

function Settings.set(key: string, value: any)
	if not Shared.valid(key, value) then
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("SettingsRemotes")
	local remote = remotes:WaitForChild("Set") :: RemoteEvent
	remote:FireServer(key, value)
end

function Settings.changed(callback: (key: string) -> ())
	for _, setting in Shared.List do
		local key = setting.key
		player:GetAttributeChangedSignal(Shared.attribute(key)):Connect(function()
			callback(key)
		end)
	end
end

return Settings
