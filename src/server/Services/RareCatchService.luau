--!strict
-- Rare catch shout-outs (thread "Add patterns from top Roblox games", 2026-11-11). Rules in
-- Util/RareCatch, numbers in Config/RareCatch. CatchService tells us about every catch:
--   Reveal  the catcher gets a reveal card in the rarity's colour
--   Server  + everyone in this server gets a banner and a chat line
--   Global  + every other server gets the chat line too (MessagingService)
--
-- One remote, ReplicatedStorage.Remotes.RareCatch, server -> client only:
--   (payload: { kind: "Reveal" | "Shout" | "Far", title: string, monster: string,
--               color: { number }, line: string, chat: boolean })
-- Reveal goes to the catcher, Shout to the rest of the server, Far is a line from another
-- server (chat only). Clients never send anything on it.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.RareCatch)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local RareCatch = require(ReplicatedStorage.Shared.Util.RareCatch)

local RareCatchService = {}

local Topic = "RareCatch"

local function remote(): RemoteEvent
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local existing = (folder :: Instance):FindFirstChild("RareCatch")
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = "RareCatch"
	created.Parent = folder
	return created
end

local Remote = remote()

local sentAt: { number } = {} -- os.clock() of the cross-server shouts sent in the last minute

local function canSendGlobal(): boolean
	local now = os.clock()
	for i = #sentAt, 1, -1 do
		if now - sentAt[i] > 60 then
			table.remove(sentAt, i)
		end
	end
	if #sentAt >= Config.GlobalPerMinute then
		return false
	end
	table.insert(sentAt, now)
	return true
end

-- A monster was just caught. caught needs monsterId and variant (Value.CaughtMonster).
function RareCatchService.caught(player: Player, caught: { monsterId: string, variant: string? })
	local monster = Monsters[caught.monsterId]
	if not monster then
		return
	end
	local level = RareCatch.level(monster.rarity, caught.variant)
	if level == "None" then
		return
	end
	local monsterName = Format.name(caught.monsterId)
	local payload = {
		kind = "Reveal",
		title = RareCatch.title(monster.rarity, caught.variant),
		monster = monsterName,
		color = RareCatch.color(monster.rarity, caught.variant),
		line = RareCatch.line(player.DisplayName, monsterName, monster.rarity, caught.variant),
		chat = RareCatch.shouts(level), -- the catcher's own chat gets the line too
	}
	Remote:FireClient(player, payload)
	if not RareCatch.shouts(level) then
		return
	end
	local shout = table.clone(payload)
	shout.kind = "Shout"
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remote:FireClient(other, shout)
		end
	end
	if level == "Global" and canSendGlobal() then
		task.spawn(function()
			local ok, err = pcall(function()
				MessagingService:PublishAsync(
					Topic,
					{ job = game.JobId, line = payload.line, color = payload.color }
				)
			end)
			if not ok then
				warn(`RareCatchService: couldn't tell the other servers: {err}`)
			end
		end)
	end
end

local function onFar(message: any)
	local data = typeof(message) == "table" and message.Data or nil
	if typeof(data) ~= "table" or data.job == game.JobId then
		return -- our own (already shown here) or junk
	end
	local line, color = data.line, data.color
	if typeof(line) ~= "string" or #line > 200 or typeof(color) ~= "table" then
		return
	end
	local rgb = {}
	for i = 1, 3 do
		rgb[i] = math.clamp(tonumber(color[i]) or 255, 0, 255)
	end
	Remote:FireAllClients({ kind = "Far", title = "", monster = "", color = rgb, line = line, chat = true })
end

function RareCatchService.start()
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(Topic, onFar)
		end)
		if not ok then
			warn(`RareCatchService: no cross-server shout-outs this server: {err}`)
		end
	end)
end

return RareCatchService
