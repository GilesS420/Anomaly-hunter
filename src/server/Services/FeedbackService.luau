--!strict
-- Player feedback (Giles 2026-11-03). Players write a short note (a bug, an idea, anything)
-- from Settings > Send feedback (client FeedbackController); admins read it in the admin
-- panel's Feedback tab (F2, client AdminController).
--
-- Every server keeps the notes sent in it for a few seconds and then writes them all at once
-- to one DataStore key, the inbox (UpdateAsync, so two servers writing at the same moment
-- both keep their notes). The inbox keeps the newest Config/Feedback.InboxSize notes. Studio
-- play tests use their own inbox (StudioStoreName), so test notes never mix with real ones.
-- In Studio without API access the notes stay in this server only until the test stops.
--
-- Rules (Shared.Util.Feedback): 5 to 500 letters, one note a minute and 5 a day per player
-- (saved in their profile, so changing servers doesn't reset it), and the text goes through
-- Roblox's text filter (server/TextFilter) before it's saved. A note keeps the filter's ###:
-- only admins read it, and a bug report with one rude word in it is still worth reading.
--
-- Remotes (ReplicatedStorage.FeedbackRemotes):
--   Send   RemoteFunction (kind: string, text: string) -> { ok, message }
--   Admin  RemoteFunction (action: "list"|"read"|"unread"|"delete"|"readall", id: string?)
--          -> { ok, entries: { Entry } newest first, unread: number, message: string? }
--          Admins only; anyone else gets ok = false and no entries.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Feedback)
local Feedback = require(ReplicatedStorage.Shared.Util.Feedback)
local Admins = require(script.Parent.Parent.Admins)
local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Parent.Notify)
local TextFilter = require(script.Parent.Parent.TextFilter)

local FeedbackService = {}

FeedbackService.StoreName = "Feedback_v1"
FeedbackService.StudioStoreName = "Feedback_Studio"
local InboxKey = "Inbox"
local MaxPending = 100 -- notes waiting to be written when the DataStore is down

type Entry = Feedback.Entry
export type SendResult = { ok: boolean, message: string }
export type AdminResult = { ok: boolean, entries: { Entry }, unread: number, message: string? }

local remotes = Instance.new("Folder")
remotes.Name = "FeedbackRemotes"
local Send = Instance.new("RemoteFunction")
Send.Name = "Send"
Send.Parent = remotes
local Admin = Instance.new("RemoteFunction")
Admin.Name = "Admin"
Admin.Parent = remotes

local store: DataStore? = nil
local pending: { Entry } = {} -- sent in this server, not in the inbox yet (oldest first)
local lastInbox: { Entry } = {} -- the inbox as last read or written, for when a read fails
local sending: { [Player]: boolean } = {} -- one note at a time per player (the filter waits)
local flushing = false
local deleted: { [string]: boolean } = {} -- deleted by an admin here while maybe being written
local warned = false

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(
			if RunService:IsStudio() then FeedbackService.StudioStoreName else FeedbackService.StoreName
		)
	end)
	if ok then
		store = result
	end
	return store
end

-- The inbox as read from the DataStore, with anything broken left out.
local function cleanInbox(raw: unknown): { Entry }
	local list: { Entry } = {}
	if type(raw) ~= "table" then
		return list
	end
	for _, entry in raw :: { any } do
		if
			type(entry) == "table"
			and type(entry.id) == "string"
			and type(entry.text) == "string"
			and type(entry.userId) == "number"
			and type(entry.at) == "number"
		then
			table.insert(list, {
				id = entry.id,
				userId = entry.userId,
				name = if type(entry.name) == "string" then entry.name else "?",
				displayName = if type(entry.displayName) == "string" then entry.displayName else "?",
				kind = if Feedback.kind(entry.kind) then entry.kind else "Other",
				text = entry.text,
				at = entry.at,
				read = entry.read == true,
			})
		end
	end
	return list
end

local function dropPending(ids: { [string]: boolean })
	for i = #pending, 1, -1 do
		if ids[pending[i].id] then
			table.remove(pending, i)
		end
	end
end

-- Changes the inbox in the DataStore. `change` gets the inbox and changes it in place.
-- Returns the inbox after the change, or nil when the DataStore couldn't be reached.
local function update(change: ({ Entry }) -> ()): { Entry }?
	local dataStore = getStore()
	if not dataStore then
		return nil
	end
	local result: { Entry }? = nil
	local ok, err = pcall(function()
		dataStore:UpdateAsync(InboxKey, function(old: unknown)
			local inbox = cleanInbox(old)
			change(inbox)
			result = inbox
			return inbox
		end)
	end)
	if not ok then
		if not warned then
			warned = true -- once, not every few seconds while it's down
			warn(`FeedbackService: couldn't write the feedback inbox (notes wait here and retry): {err}`)
		end
		return nil
	end
	warned = false
	if result then
		lastInbox = result
	end
	return result
end

-- Writes this server's new notes to the inbox. They stay in `pending` until that works.
local function flush()
	if flushing or #pending == 0 then
		return
	end
	flushing = true
	local batch = table.clone(pending)
	local written: { Entry }? = nil
	written = update(function(inbox)
		local fresh: { Entry } = {}
		for _, entry in batch do
			if not deleted[entry.id] then
				table.insert(fresh, entry)
			end
		end
		local merged = Feedback.add(inbox, fresh)
		table.clear(inbox)
		table.move(merged, 1, #merged, 1, inbox)
	end)
	if written then
		local ids: { [string]: boolean } = {}
		for _, entry in batch do
			ids[entry.id] = true
		end
		dropPending(ids)
	end
	flushing = false
end

-- The inbox as admins see it: what's saved plus this server's notes not written yet.
local function readInbox(): ({ Entry }, string?)
	local dataStore = getStore()
	local inbox = lastInbox
	local message: string? = nil
	local ok, raw = false, nil
	if dataStore then
		ok, raw = pcall(function()
			return dataStore:GetAsync(InboxKey)
		end)
	end
	if ok then
		inbox = cleanInbox(raw)
		lastInbox = inbox
	else
		message = if RunService:IsStudio()
			then "Studio has no DataStore access: showing this server's notes only (Game Settings > Security > Enable Studio Access to API Services)."
			else "Couldn't reach the feedback inbox: showing what was loaded last. Try Refresh in a minute."
	end
	return Feedback.add(inbox, pending), message
end

local function result(entries: { Entry }, message: string?): AdminResult
	local unread = 0
	for _, entry in entries do
		if not entry.read then
			unread += 1
		end
	end
	return { ok = true, entries = entries, unread = unread, message = message }
end

-- Marks or deletes notes: the ones still in `pending` here, then the saved inbox.
local function changeNotes(action: string, id: string?): AdminResult
	local function apply(list: { Entry })
		for i = #list, 1, -1 do
			local entry = list[i]
			if action == "readall" then
				entry.read = true
			elseif entry.id == id then
				if action == "delete" then
					deleted[entry.id] = true
					table.remove(list, i)
				else
					entry.read = action == "read"
				end
			end
		end
	end
	apply(pending)
	local saved = update(apply)
	if not saved then
		local entries = readInbox()
		apply(entries)
		return result(entries, "Couldn't save that change to the inbox. Try again in a minute.")
	end
	return result(Feedback.add(saved, pending), nil)
end

Admin.OnServerInvoke = function(player: Player, action: unknown, id: unknown): AdminResult
	if not Admins.isAdmin(player) then
		return { ok = false, entries = {}, unread = 0 }
	end
	if action == "list" then
		local entries, message = readInbox()
		return result(entries, message)
	end
	if action == "readall" then
		return changeNotes("readall", nil)
	end
	local valid = action == "read" or action == "unread" or action == "delete"
	if not valid or type(id) ~= "string" or #id > 64 then
		return { ok = false, entries = {}, unread = 0, message = "Unknown feedback action." }
	end
	return changeNotes(action :: string, id)
end

Send.OnServerInvoke = function(player: Player, kindId: unknown, text: unknown): SendResult
	local data = DataService.get(player)
	if not data then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	local kind = Feedback.kind(kindId)
	if not kind then
		return { ok = false, message = "Pick what it's about: Bug, Idea or Other." }
	end
	local cleaned, why = Feedback.clean(text)
	if not cleaned then
		return { ok = false, message = why or "Write something first." }
	end
	if sending[player] then
		return { ok = false, message = "Still sending your last note..." }
	end
	local record = Feedback.fix(data.feedback)
	local now = os.time()
	local allowed, wait = Feedback.canSend(record, now)
	if not allowed then
		return { ok = false, message = wait or "Try again later." }
	end
	if #pending >= MaxPending then
		return { ok = false, message = "Feedback is busy right now. Try again in a few minutes." }
	end

	sending[player] = true
	local filtered = TextFilter.forEveryone(player, cleaned)
	sending[player] = nil
	if not filtered then
		return { ok = false, message = "Couldn't send it right now. Try again in a minute." }
	end
	local current = DataService.get(player) -- they may have left while the filter worked
	if not current then
		return { ok = false, message = "Your save is still loading. Try again in a moment!" }
	end
	current.feedback = Feedback.sent(Feedback.fix(current.feedback), os.time())

	table.insert(pending, {
		id = HttpService:GenerateGUID(false),
		userId = player.UserId,
		name = player.Name,
		displayName = player.DisplayName,
		kind = kind.id,
		text = filtered,
		at = now,
		read = false,
	})
	for _, other in Players:GetPlayers() do
		if other ~= player and Admins.isAdmin(other) then
			Notify.toast(other, `{kind.icon} New feedback from {player.DisplayName} (F2 > Feedback)`)
		end
	end
	return { ok = true, message = "Thanks! Your feedback was sent to the team." }
end

function FeedbackService.start()
	Players.PlayerRemoving:Connect(function(player)
		sending[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.FlushSeconds)
			flush()
		end
	end)
	game:BindToClose(function()
		local waited = 0
		while flushing and waited < 10 do
			waited += task.wait(0.2)
		end
		flush()
	end)
	remotes.Parent = ReplicatedStorage
end

return FeedbackService
