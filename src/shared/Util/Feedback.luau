--!strict
-- The rules for player feedback, shared by the server (which decides) and the client's form
-- (which shows the same limits). No Roblox services, so plain Luau can test it.

local Config = require("../Config/Feedback")

local Feedback = {}

-- How often one player has sent feedback (saved in their profile as `feedback`).
export type Record = { day: number, count: number, lastAt: number }

-- One note in the inbox.
export type Entry = {
	id: string,
	userId: number,
	name: string, -- @username at the time
	displayName: string,
	kind: string,
	text: string, -- already through Roblox's text filter
	at: number, -- os.time()
	read: boolean,
}

function Feedback.empty(): Record
	return { day = 0, count = 0, lastAt = 0 }
end

function Feedback.kind(id: unknown): { id: string, label: string, icon: string }?
	if type(id) ~= "string" then
		return nil
	end
	for _, kind in Config.Kinds do
		if kind.id == id then
			return kind
		end
	end
	return nil
end

-- The day number (UTC) of an os.time().
function Feedback.day(now: number): number
	return math.floor(now / 86400)
end

-- "just now", "5 min ago", "3 h ago", "2 days ago".
function Feedback.ago(seconds: number): string
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return `{math.floor(seconds / 60)} min ago`
	elseif seconds < 86400 then
		return `{math.floor(seconds / 3600)} h ago`
	end
	local days = math.floor(seconds / 86400)
	return if days == 1 then "1 day ago" else `{days} days ago`
end

-- The text as it will be saved: no control characters, line breaks kept (at most two in a
-- row), spaces squeezed, trimmed. nil and why when it's empty, too short or too long.
function Feedback.clean(text: unknown): (string?, string?)
	if type(text) ~= "string" then
		return nil, "Write something first."
	end
	if #text > Config.MaxLength * 4 then
		return nil, `That's too long: up to {Config.MaxLength} letters.`
	end
	if not utf8.len(text) then
		return nil, "That text has broken letters in it."
	end
	local cleaned = string.gsub(text, "\r\n?", "\n")
	cleaned = string.gsub(cleaned, "[%z\1-\9\11-\31\127]", "")
	cleaned = string.gsub(cleaned, "[ \t]+", " ")
	cleaned = string.gsub(cleaned, " *\n *", "\n")
	cleaned = string.gsub(cleaned, "\n\n\n+", "\n\n")
	cleaned = string.match(cleaned, "^%s*(.-)%s*$") or ""
	local length = utf8.len(cleaned) or 0
	if length < Config.MinLength then
		return nil, `Write a little more (at least {Config.MinLength} letters).`
	end
	if length > Config.MaxLength then
		return nil, `That's too long: up to {Config.MaxLength} letters.`
	end
	return cleaned, nil
end

-- Whether a player with this record may send a note now; why not when they can't.
function Feedback.canSend(record: Record, now: number): (boolean, string?)
	local wait = record.lastAt + Config.CooldownSeconds - now
	if wait > 0 then
		return false, `Thanks! You can send another note in {math.ceil(wait)} s.`
	end
	if record.day == Feedback.day(now) and record.count >= Config.PerDay then
		return false, `You've sent {Config.PerDay} notes today. Thanks! Try again tomorrow.`
	end
	return true, nil
end

-- The record after sending a note now.
function Feedback.sent(record: Record, now: number): Record
	local today = Feedback.day(now)
	local count = if record.day == today then record.count + 1 else 1
	return { day = today, count = count, lastAt = now }
end

-- A saved record cleaned up (missing, or broken by an old save).
function Feedback.fix(record: unknown): Record
	if type(record) ~= "table" then
		return Feedback.empty()
	end
	local raw = record :: { [string]: unknown }
	local function number(value: unknown): number
		return if type(value) == "number"
				and value == value
				and math.abs(value) ~= math.huge
			then value
			else 0
	end
	return { day = number(raw.day), count = number(raw.count), lastAt = number(raw.lastAt) }
end

-- New notes added to the front of the inbox (newest first), cut to InboxSize. Notes already in
-- it (same id: a retry after a write that did go through) aren't added twice.
function Feedback.add(inbox: { Entry }, new: { Entry }): { Entry }
	local seen: { [string]: boolean } = {}
	for _, entry in inbox do
		seen[entry.id] = true
	end
	local result: { Entry } = {}
	for i = #new, 1, -1 do
		local entry = new[i]
		if not seen[entry.id] then
			seen[entry.id] = true
			table.insert(result, entry)
		end
	end
	for _, entry in inbox do
		if #result >= Config.InboxSize then
			break
		end
		table.insert(result, entry)
	end
	while #result > Config.InboxSize do
		table.remove(result)
	end
	return result
end

return Feedback
