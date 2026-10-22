--!strict
-- Monster names given with a Name Tag (Config/Shop NameTag). clean() tidies what the player
-- typed; the server then runs it through Roblox's text filter (InventoryService.rename)
-- before it's saved, because other players see it over the monster.

local Nickname = {}

Nickname.MaxLength = 20

-- The name with spaces trimmed and squeezed, without control characters. Too long gives
-- nil; "" means the player wants the name taken off.
function Nickname.clean(text: string): string?
	if not utf8.len(text) then
		return nil -- not valid text
	end
	local tidy = string.gsub(text, "%c", "")
	tidy = string.gsub(tidy, "%s+", " ")
	tidy = string.match(tidy, "^%s*(.-)%s*$") or ""
	local length = utf8.len(tidy) or math.huge
	return if length <= Nickname.MaxLength then tidy else nil
end

return Nickname
