--!strict
-- Saves where each player keeps things on their hotbar (Shared.Util.HotbarLayout) in
-- data.hotbar and hands it to their client as the player attribute HotbarLayout (JSON).
--
-- Remotes in ReplicatedStorage.HotbarRemotes:
--   Set  client -> server (layout)   the player's whole layout; anything not allowed is dropped

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HotbarLayout = require(ReplicatedStorage.Shared.Util.HotbarLayout)
local DataService = require(script.Parent.DataService)

local HotbarService = {}

local remotes = Instance.new("Folder")
remotes.Name = "HotbarRemotes"
local Set = Instance.new("RemoteEvent")
Set.Name = "Set"
Set.Parent = remotes

local lastSet: { [Player]: number } = {}
local MinSecondsBetween = 0.5 -- the client already waits a moment after a change

Set.OnServerEvent:Connect(function(player: Player, raw: unknown)
	local data = DataService.get(player)
	local now = os.clock()
	if not data or now - (lastSet[player] or 0) < MinSecondsBetween then
		return
	end
	lastSet[player] = now
	data.hotbar = HotbarLayout.clean(raw)
	DataService.saveSoon(player)
end)

function HotbarService.start()
	remotes.Parent = ReplicatedStorage
	DataService.onLoaded(function(player, data)
		data.hotbar = HotbarLayout.clean(data.hotbar)
		player:SetAttribute("HotbarLayout", HttpService:JSONEncode(data.hotbar))
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastSet[player] = nil
	end)
end

return HotbarService
