--!strict
-- The Hunter's Guild: the game's Roblox group (Config/Community, Giles 2026-11-04).
--
-- Players join at the Guild stand in front of the shops (Hub.Landmarks.GuildStand, its Talk
-- dialogue in Config/Stands) or from Settings. Joining itself happens on the client: Roblox
-- only lets a LocalScript open its Join Group window (GroupService:PromptJoinAsync), see
-- client/Community. Afterwards the client asks here for the gift, and this server checks with
-- Roblox that the player really is in the group before giving anything.
--
-- Guild members (checked when they join the server, and again after they join the group):
--   * get Config/Community.Gift once per save (data.guildGift)
--   * get Config/Community.SellBoost at the Collector (Perks.sellBoost reads InGuild)
--   * wear a purple "Guild" tag over their head (above the VIP tag if they have one)
--
-- Remotes (ReplicatedStorage.CommunityRemotes):
--   Claim  RemoteFunction ("Guild") -> { ok: boolean, message: string }
--          ok is true only the one time the gift is given. Anything but "Guild" is junk.
-- Player attributes (set here only, so a client can't fake them): InGuild, GuildGift.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Community)
local Counter = require(script.Parent.Parent.Counter)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local Notify = require(script.Parent.Parent.Notify)

local CommunityService = {}

export type ClaimResult = { ok: boolean, message: string }

local remotes = Instance.new("Folder")
remotes.Name = "CommunityRemotes"
local Claim = Instance.new("RemoteFunction")
Claim.Name = "Claim"
Claim.Parent = remotes

local lastClaim: { [Player]: number } = {}
local checking: { [Player]: boolean } = {}

local TagPurple = Color3.fromRGB(190, 130, 255)
local TagHeight = 3.2 -- studs over the head, like the VIP tag
local TagHeightOverVip = 4.4

-- Asks Roblox whether the player is in the group right now. Player:IsInGroup is cached for
-- the whole visit, so a player who just joined would still look like a non-member there;
-- GroupService:GetGroupsAsync asks Roblox fresh. nil if Roblox didn't answer.
local function inGroup(player: Player): boolean?
	if Config.GroupId == 0 then
		return false
	end
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if ok and typeof(groups) == "table" then
		for _, group in groups :: { any } do
			if typeof(group) == "table" and group.Id == Config.GroupId then
				return true
			end
		end
		return false
	end
	local cachedOk, cached = pcall(player.IsInGroup, player, Config.GroupId)
	return if cachedOk then cached == true else nil
end

-- The purple "Guild" tag over a member's head, moved up when the VIP tag is there too.
local function placeTag(head: Instance, tag: BillboardGui)
	local height = if head:FindFirstChild("VipTag") then TagHeightOverVip else TagHeight
	tag.StudsOffset = Vector3.new(0, height, 0)
end

local function guildTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or player:GetAttribute("InGuild") ~= true or head:FindFirstChild("GuildTag") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "GuildTag"
	tag.Size = UDim2.fromOffset(80, 24)
	tag.MaxDistance = 80
	tag.AlwaysOnTop = false
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "Guild"
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = TagPurple
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(40, 10, 70)
	text.Parent = tag
	placeTag(head, tag)
	head.ChildAdded:Connect(function()
		placeTag(head, tag)
	end)
	tag.Parent = head
end

-- Gives the one-time gift. True if it was given now.
local function giveGift(player: Player, data: DataService.Data): boolean
	if data.guildGift then
		return false
	end
	data.guildGift = true
	player:SetAttribute("GuildGift", true)
	for id, count in Config.Gift do
		data.inventory[id] = (data.inventory[id] or 0) + count
	end
	HuntService.refreshItems(player)
	DataService.saveSoon(player)
	return true
end

-- Checks the player's membership with Roblox and gives them what members get. Returns the
-- check's result (nil if Roblox didn't answer) and whether the gift was given now.
local function refresh(player: Player): (boolean?, boolean)
	local member = inGroup(player)
	local data = DataService.get(player)
	if member == nil or not data or player.Parent ~= Players then
		return member, false
	end
	player:SetAttribute("InGuild", member)
	if not member then
		return false, false
	end
	guildTag(player)
	return true, giveGift(player, data)
end

local function onClaim(player: Player, which: unknown): ClaimResult
	if which ~= "Guild" then
		return { ok = false, message = "Nothing to claim." }
	end
	if Config.GroupId == 0 then
		return { ok = false, message = "The Guild isn't open yet. Check back soon!" }
	end
	if not DataService.isLoaded(player) then
		return { ok = false, message = "Your save is still loading, try again in a moment." }
	end
	local now = os.clock()
	if checking[player] or now - (lastClaim[player] or -math.huge) < Config.ClaimCooldown then
		return { ok = false, message = "One moment, the Guild is checking its books..." }
	end
	if player:GetAttribute("GuildGift") == true then
		return { ok = false, message = "You already got your Guild gift. Thanks for being with us, hunter!" }
	end
	lastClaim[player] = now
	checking[player] = true
	local member, given = refresh(player)
	checking[player] = nil
	if given then
		return {
			ok = true,
			message = `Welcome to the Guild! Here's {Config.GiftText}, and the Collector pays you 5% more from now on.`,
		}
	elseif member == nil then
		return { ok = false, message = "Roblox didn't answer. Try again in a moment." }
	elseif member then
		return { ok = false, message = "You already got your Guild gift. Thanks for being with us, hunter!" }
	end
	return { ok = false, message = 'You\'re not in the Guild yet. Pick "Join the Guild!" to join.' }
end

function CommunityService.start()
	remotes.Parent = ReplicatedStorage
	Claim.OnServerInvoke = onClaim

	-- The stand only talks: joining happens in the dialogue on the client.
	Counter.prompt("GuildStand", "Hunter's Guild", function() end)

	if Config.GroupId == 0 then
		warn(
			"Hunter's Guild: set GroupId in ReplicatedStorage > Shared > Config > Community to your group's number"
		)
	end

	DataService.onLoaded(function(player, data)
		player:SetAttribute("GuildGift", data.guildGift)
		local _, given = refresh(player)
		if given then
			Notify.toast(player, `Thanks for being in the Hunter's Guild! You got {Config.GiftText}.`)
		end
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			guildTag(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
		checking[player] = nil
	end)
end

return CommunityService
