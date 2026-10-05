--!strict
-- Short messages for players ("Caught a Big Wisp Jack!", "Your mansion is full!").
-- Every player-facing message on the server goes through here; the client's ToastController
-- shows them as little pop-ups near the top of the screen. Uses one RemoteEvent:
--   ReplicatedStorage.Remotes.Toast   server -> client: (text: string)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Notify = {}

-- Made as soon as this module is required, so the client's WaitForChild finds them early.
local function folder(): Instance
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Remotes"
	created.Parent = ReplicatedStorage
	return created
end

local function toastEvent(parent: Instance): RemoteEvent
	local existing = parent:FindFirstChild("Toast")
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = "Toast"
	created.Parent = parent
	return created
end

local Toast = toastEvent(folder())

-- Shows text to one player. Quietly does nothing if they already left.
function Notify.toast(player: Player, text: string)
	if text == "" or player.Parent ~= Players then
		return
	end
	Toast:FireClient(player, text)
end

-- Shows text to everyone in the server.
function Notify.toastAll(text: string)
	if text == "" then
		return
	end
	Toast:FireAllClients(text)
end

return Notify
