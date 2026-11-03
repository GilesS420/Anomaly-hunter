--!strict
-- Player feedback (Giles 2026-11-03): players write a short note from Settings > Send feedback,
-- and admins read it in the admin panel's Feedback tab (F2). Kept across servers in one
-- DataStore inbox (server/Services/FeedbackService).

local Feedback = {}

-- What the note is about. The id is saved; label and icon are what players and admins see.
Feedback.Kinds = {
	{ id = "Bug", label = "Bug", icon = "🐞" },
	{ id = "Idea", label = "Idea", icon = "💡" },
	{ id = "Other", label = "Other", icon = "💬" },
}

Feedback.MinLength = 5 -- letters, so "hi" or "." isn't a note
Feedback.MaxLength = 500
Feedback.CooldownSeconds = 60 -- between two notes from the same player
Feedback.PerDay = 5 -- notes one player can send in a day (UTC), across all servers
Feedback.InboxSize = 300 -- the newest notes kept; older ones drop off the end
Feedback.FlushSeconds = 15 -- how often a server writes its new notes to the inbox

return Feedback
