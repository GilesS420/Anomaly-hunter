--!strict
-- Roblox's text filter for words one player writes that other players see: monster names
-- (Name Tags, InventoryService) and admin announcements (DevService /announce). Roblox's rules
-- say this text must be filtered on the server before anyone else sees it. Broadcast means
-- one filtered copy for everyone in the server (and it's strict enough for under-13s).
--
-- When the filter hides any part of the text (Roblox puts # in its place), `hidden` is true
-- and the callers turn the text away instead of showing ####.
--
-- Roblox doesn't filter in Studio: the text comes back unchanged. So in Studio only, the test
-- words below are hidden here instead, to try the "not allowed" path (see the PR's test steps).
-- A real live server never uses them.

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local TextFilter = {}

TextFilter.StudioTestWords = { "badword", "hashtest" }

local function studioFake(text: string): string
	local lower = string.lower(text)
	for _, word in TextFilter.StudioTestWords do
		local at = 1
		while true do
			local first, last = string.find(lower, word, at, true)
			if not first then
				break
			end
			local hashes = string.rep("#", last - first + 1)
			text = string.sub(text, 1, first - 1) .. hashes .. string.sub(text, last + 1)
			lower = string.sub(lower, 1, first - 1) .. hashes .. string.sub(lower, last + 1)
			at = last + 1
		end
	end
	return text
end

-- The text as everyone may see it, and whether the filter hid anything. nil when the filter
-- can't be reached (it's a web call that can fail): then show nothing and save nothing.
function TextFilter.forEveryone(author: Player, text: string): (string?, boolean)
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, author.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or typeof(result) ~= "string" then
		return nil, false
	end
	if RunService:IsStudio() then
		result = studioFake(result)
	end
	return result, result ~= text
end

return TextFilter
