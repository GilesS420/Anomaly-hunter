--!strict
-- Who may use the admin panel and the admin chat commands (DevService). An admin is:
--   * anyone playing in Roblox Studio (play testing),
--   * the game's owner, when the game is published under a user account (not a group),
--   * anyone whose UserId is in the list below.
-- To find a UserId: open your Roblox profile in a browser; it's the number in the address
-- (roblox.com/users/123456789/profile -> 123456789).
--
-- This lives on the server only, so players can't see or change the list. The server sets
-- an "Admin" attribute on admins so their client knows to show the panel, but every action
-- is checked again here on the server.

local RunService = game:GetService("RunService")

local Admins = {}

Admins.UserIds = {
	-- 123456789, -- Giles (put your own UserId here)
}

-- Studio test switch: with the attribute TestAsPlayer ticked on Workspace (Properties >
-- Attributes, before pressing Play, or `workspace:SetAttribute("TestAsPlayer", true)` in the
-- Server command bar), nobody is an admin in Studio, so you can check what a normal player
-- can and can't do. Only the server's copy counts: a client setting it changes nothing.
function Admins.testingAsPlayer(): boolean
	return RunService:IsStudio() and workspace:GetAttribute("TestAsPlayer") == true
end

function Admins.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return not Admins.testingAsPlayer()
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(Admins.UserIds, player.UserId) ~= nil
end

return Admins
