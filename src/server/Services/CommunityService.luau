--!strict
-- The Hunter's Guild: the game's Roblox group (Config/Community, Giles 2026-11-04).
--
-- Players join at the Guild stand in front of the shops (Hub.Landmarks.GuildStand, its Talk
-- dialogue in Config/Stands) or from Settings. Joining itself happens on the client: Roblox
-- only lets a LocalScript open its Join Group window (GroupService:PromptJoinAsync), see
-- client/Community. Afterwards the client asks here for the gift, and this server checks with
-- Roblox that the player really is in the group before giving anything.
--
-- Guild members (checked when they join the server, after they join the group, and every
-- Config/Community.RecheckSeconds, so leaving the group takes the perks away):
--   * get Config/Community.Gift once per save (data.guildGift)
--   * get Config/Community.GuildSellBonus at the Collector for as long as they stay in the
--     group (Perks.sellBonuses reads InGuild)
--   * wear a purple "Guild" tag over their head (above the VIP tag if they have one)
--
-- Remotes (ReplicatedStorage.CommunityRemotes):
--   Claim  RemoteFunction ("Guild") -> { ok: boolean, message: string }
--          ok is true only the one time the gift is given. Anything but "Guild" is junk.
--   FriendsChanged  RemoteEvent (no args): the client saw a friend request accepted (or a
--          friend removed) in game, so the server looks at the player's friends again soon.
--          It only ever recounts from Roblox's own list, so spamming it can't add friends.
-- Player attributes (set here only, so a client can't fake them): InGuild, GuildGift, and
-- FriendsHere (how many of the player's Roblox friends are in this server: the friend bonus).

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
local FriendsChanged = Instance.new("RemoteEvent")
FriendsChanged.Name = "FriendsChanged"
FriendsChanged.Parent = remotes

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
	if not head then
		return
	end
	local old = head:FindFirstChild("GuildTag")
	if player:GetAttribute("InGuild") ~= true then
		if old then
			old:Destroy() -- left the group
		end
		return
	elseif old then
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
	local was = player:GetAttribute("InGuild") == true
	player:SetAttribute("InGuild", member)
	if not member then
		guildTag(player) -- takes it off
		if was then
			Notify.toast(
				player,
				"You left the Hunter's Guild, so its 5% sell bonus is gone. Join again at the Guild stand!"
			)
		end
		return false, false
	end
	guildTag(player)
	return true, giveGift(player, data)
end

------------------------------------------------------------------------------------------
-- Friend bonus (Giles 2026-11-04): every Roblox friend in the same server makes the Collector
-- pay Config/Community.FriendSellBonus more. FriendsHere (a player attribute) is how many.
------------------------------------------------------------------------------------------

local friendsOf: { [Player]: { [Player]: boolean } } = {}

local function countFriends(player: Player)
	local count = 0
	for other in friendsOf[player] or {} do
		if other.Parent == Players then
			count += 1
		end
	end
	if player.Parent == Players then
		player:SetAttribute("FriendsHere", count)
	end
end

-- The player's Roblox friends as a set of user ids, asked fresh from Roblox
-- (Players:GetFriendsAsync). Player:IsFriendsWith is cached for the visit, so two players
-- who become friends in game would keep looking like strangers there. nil if Roblox didn't
-- answer.
local function friendIds(player: Player): { [number]: boolean }?
	local ok, pages = pcall(Players.GetFriendsAsync, Players, player.UserId)
	if not ok or not pages then
		return nil
	end
	local ids: { [number]: boolean } = {}
	while true do
		for _, friend in (pages :: any):GetCurrentPage() do
			if typeof(friend) == "table" and typeof(friend.Id) == "number" then
				ids[friend.Id] = true
			end
		end
		if (pages :: any).IsFinished then
			break
		end
		if not pcall((pages :: any).AdvanceToNextPageAsync, pages) then
			return nil
		end
	end
	return ids
end

-- Looks at the player's friends again and fixes FriendsHere for them and for everyone here
-- they became (or stopped being) friends with.
local function recheckFriends(player: Player)
	local ids = friendIds(player)
	if not ids or player.Parent ~= Players then
		return
	end
	friendsOf[player] = friendsOf[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local now = ids[other.UserId] == true
			if (friendsOf[player][other] == true) ~= now then
				friendsOf[other] = friendsOf[other] or {}
				friendsOf[player][other] = if now then true else nil
				friendsOf[other][player] = if now then true else nil
				countFriends(other)
			end
		end
	end
	countFriends(player)
end

-- One recheck at a time per player, and at most one every FriendPingSeconds when the client
-- asks, so the remote can't be used to flood Roblox's friends API.
local friendBusy: { [Player]: boolean } = {}
local friendAgain: { [Player]: boolean } = {} -- asked again while a recheck was running
local lastFriendPing: { [Player]: number } = {}

local function recheckSoon(player: Player)
	if friendBusy[player] then
		friendAgain[player] = true
		return
	end
	friendBusy[player] = true
	task.spawn(function()
		repeat
			friendAgain[player] = nil
			recheckFriends(player)
			-- Roblox's friends list can lag a moment behind the accept, so look once more.
			task.wait(Config.FriendLagSeconds)
			if player.Parent == Players then
				recheckFriends(player)
			end
		until not friendAgain[player] or player.Parent ~= Players
		friendBusy[player] = nil
		friendAgain[player] = nil
	end)
end

local function onFriendsChanged(player: Player)
	local now = os.clock()
	if now - (lastFriendPing[player] or -math.huge) < Config.FriendPingSeconds then
		return
	end
	lastFriendPing[player] = now
	recheckSoon(player)
end

-- Checks a newcomer against everyone already here (both ways count the same friendship).
local function meetEveryone(player: Player)
	friendsOf[player] = friendsOf[player] or {}
	countFriends(player)
	recheckSoon(player)
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
			message = `Welcome to the Guild! Here's {Config.GiftText}, and the Collector pays you 5% more for as long as you stay in the Guild.`,
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
	FriendsChanged.OnServerEvent:Connect(onFriendsChanged)

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
	Players.PlayerAdded:Connect(function(player)
		watch(player)
		meetEveryone(player)
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
		meetEveryone(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
		checking[player] = nil
		friendBusy[player] = nil
		friendAgain[player] = nil
		lastFriendPing[player] = nil
		for other in friendsOf[player] or {} do
			local theirs = friendsOf[other]
			if theirs then
				theirs[player] = nil
				countFriends(other)
			end
		end
		friendsOf[player] = nil
	end)

	-- Friends can also be added or removed outside the game (the website, the app), which no
	-- event tells the server about: look at everyone's friends again every so often.
	task.spawn(function()
		while true do
			task.wait(Config.FriendRecheckSeconds)
			for _, player in Players:GetPlayers() do
				if not friendBusy[player] then
					friendBusy[player] = true
					recheckFriends(player)
					friendBusy[player] = nil
					if friendAgain[player] then
						recheckSoon(player) -- a ping came in meanwhile
					end
				end
				task.wait(1) -- spread the calls out
			end
		end
	end)

	-- Guild perks last only while the player stays in the group: look again every few
	-- minutes, so leaving the group takes the bonus and the tag away during the visit too.
	if Config.GroupId ~= 0 then
		task.spawn(function()
			while true do
				task.wait(Config.RecheckSeconds)
				for _, player in Players:GetPlayers() do
					if DataService.isLoaded(player) and not checking[player] then
						checking[player] = true
						refresh(player)
						checking[player] = nil
					end
				end
			end
		end)
	end
end

return CommunityService
