--!strict
-- Short messages for players ("Caught a Big Gravepup!", "Your mansion is full!").
-- Every player-facing message on the server goes through here; the client's ToastController
-- shows them as little pop-ups near the top of the screen. Mutation news also goes in the
-- player's mutation log (client MutationLogController, bottom-left). Admin announcements show
-- as a big banner (client AnnouncementController). Uses three RemoteEvents:
--   ReplicatedStorage.Remotes.Toast          server -> client: (text: string)
--   ReplicatedStorage.Remotes.MutationLog    server -> client: (text: string)
--   ReplicatedStorage.Remotes.Announcement   server -> client: (text: string)

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

local function remoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = parent
	return created
end

local Toast = remoteEvent(folder(), "Toast")
local MutationLog = remoteEvent(folder(), "MutationLog")
local Announcement = remoteEvent(folder(), "Announcement")

-- Shows text to one player. Quietly does nothing if they already left.
function Notify.toast(player: Player, text: string)
	if text == "" or player.Parent ~= Players then
		return
	end
	Toast:FireClient(player, text)
end

-- Keys of the once-per-visit messages each player has seen (cleared when they leave).
local seenOnce: { [Player]: { [string]: true } } = {}
Players.PlayerRemoving:Connect(function(player)
	seenOnce[player] = nil
end)

-- True the first time it's asked about this key for this player this visit, false after
-- that (until they rejoin). For reminders that only need saying once (Giles 2026-11-05: too
-- many pop-ups).
function Notify.first(player: Player, key: string): boolean
	local seen = seenOnce[player]
	if not seen then
		seen = {}
		seenOnce[player] = seen
	end
	if seen[key] then
		return false
	end
	seen[key] = true
	return true
end

-- Shows the text only the first time for this key per visit ("Sunken Swamp: safe zone").
function Notify.once(player: Player, key: string, text: string)
	if Notify.first(player, key) then
		Notify.toast(player, text)
	end
end

-- Adds a line to the player's mutation log (a monster got an effect or combo). Doesn't toast:
-- callers toast as well, or a summary when there's a lot at once.
function Notify.log(player: Player, text: string)
	if text == "" or player.Parent ~= Players then
		return
	end
	MutationLog:FireClient(player, text)
end

-- Shows text to everyone in the server.
function Notify.toastAll(text: string)
	if text == "" then
		return
	end
	Toast:FireAllClients(text)
end

-- Shows an admin's announcement to everyone in the server. The text must already be filtered
-- (DevService's /announce does that).
function Notify.announceAll(text: string)
	if text == "" then
		return
	end
	Announcement:FireAllClients(text)
end

return Notify
