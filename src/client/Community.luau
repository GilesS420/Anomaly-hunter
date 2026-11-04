--!strict
-- Joining the Hunter's Guild (the game's Roblox group, Config/Community) and inviting friends,
-- from the Guild stand's dialogue (DialogueController) and from Settings. Both open Roblox's
-- own window, and only when the player picks that line: nothing here ever opens by itself.
-- Roblox only lets a LocalScript open the Join Group window, so joining happens here; the gift
-- is then asked for from the server (CommunityService), which checks the group itself.
--
-- Each function waits for the window to close and returns a line for the stand to say (or
-- for Settings to show as a toast).

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Config =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Community"))

local Community = {}

local player = Players.LocalPlayer
local busy = false -- one Roblox window at a time

local function claim(): { ok: boolean, message: string }?
	local remotes = ReplicatedStorage:WaitForChild("CommunityRemotes", 10)
	local remote = remotes and remotes:FindFirstChild("Claim")
	if not remote or not remote:IsA("RemoteFunction") then
		return nil
	end
	local ok, result = pcall(remote.InvokeServer, remote, "Guild")
	if ok and typeof(result) == "table" and typeof(result.message) == "string" then
		return result
	end
	return nil
end

-- Opens Roblox's Join Group window, then gives the gift the first time.
function Community.join(): string
	if Config.GroupId == 0 then
		warn("Hunter's Guild: set GroupId in ReplicatedStorage > Shared > Config > Community")
		return "The Guild isn't open yet. Check back soon!"
	end
	if busy then
		return "One window at a time, hunter."
	end
	busy = true
	local ok, status = pcall(function()
		return (GroupService :: any):PromptJoinAsync(Config.GroupId)
	end)
	busy = false
	if not ok then
		return "The Guild's door is stuck. Try again in a moment."
	end
	if status == Enum.GroupMembershipStatus.JoinRequestPending then
		return "Your request is in! You'll get your gift once the Guild lets you in."
	end
	if status ~= Enum.GroupMembershipStatus.Joined and status ~= Enum.GroupMembershipStatus.AlreadyMember then
		return "No worries. Come back any time you want to join."
	end
	if player:GetAttribute("GuildGift") == true then
		return "You're one of us. Thanks for being in the Guild, hunter!"
	end
	local result = claim()
	return if result then result.message else "Welcome to the Guild!"
end

-- Opens Roblox's Invite Friends window.
function Community.invite(): string
	if busy then
		return "One window at a time, hunter."
	end
	busy = true
	local canOk, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if not canOk or not can then
		busy = false
		return "Invites can't be sent from this account right now."
	end
	local ok = pcall(SocialService.PromptGameInvite, SocialService, player)
	busy = false
	return if ok
		then "The more hunters, the merrier!"
		else "The invite window didn't open. Try again in a moment."
end

return Community
