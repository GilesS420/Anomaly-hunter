--!strict
-- Your settings on this client: read from the player attributes the server keeps
-- (server/Services/SettingsService), with the defaults from Shared.Util.Settings until your
-- save has loaded. Settings.set changes one straight away on this client and asks the server
-- to save it; Settings.changed runs a function whenever any of them changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Settings"))

local Settings = {}

local player = Players.LocalPlayer
local picked: { [string]: any } = {} -- set here, before the server's copy catches up
local listeners: { (key: string) -> () } = {}

local function fire(key: string)
	for _, callback in listeners do
		task.spawn(callback, key)
	end
end

for _, setting in Shared.List do
	local key = setting.key
	player:GetAttributeChangedSignal(Shared.attribute(key)):Connect(function()
		picked[key] = nil -- the server has it now
		fire(key)
	end)
end

function Settings.get(key: string): any
	if picked[key] ~= nil then
		return picked[key]
	end
	return Shared.value(key, player:GetAttribute(Shared.attribute(key)))
end

-- Volume settings as 0 to 1.
function Settings.volume(key: string): number
	local value = Settings.get(key)
	return if typeof(value) == "number" then value / Shared.VolumeMax else 1
end

-- Changes a setting on this client right away. `save` false only previews it (a slider
-- being dragged); the last value is saved when the drag ends.
function Settings.set(key: string, value: any, save: boolean?)
	if not Shared.valid(key, value) or Settings.get(key) == value and save == false then
		return
	end
	picked[key] = value
	fire(key)
	if save ~= false then
		local remotes = ReplicatedStorage:WaitForChild("SettingsRemotes")
		local remote = remotes:WaitForChild("Set") :: RemoteEvent
		remote:FireServer(key, value)
	end
end

function Settings.changed(callback: (key: string) -> ())
	table.insert(listeners, callback)
end

return Settings
