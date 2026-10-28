--!strict
-- Admin commands for play testing. Only admins can use them (see server/Admins.luau: anyone
-- in Studio, the game's owner and the UserIds listed there); for everyone else they do
-- nothing. Admins can press the buttons in the admin panel (client AdminController, F2 or
-- the Admin button) or type them in the chat box:
--   /money 1000000    adds money (a negative number takes some away; 5k, 2.5m and 1b work too)
--   /wings 3          sets how many wings your mansion has (1 to 6) and rebuilds it
--   /clearmonsters    empties your mansion, Storage and Growth Chamber
--   /tutorial skip    ends your tutorial now (/tutorial restart starts it again from the gate)
--   /reset confirm    wipes YOUR save back to a brand-new player's and kicks you; rejoin to
--                     start fresh (replay the tutorial and early game). Nobody else is touched.
--   /summon           starts the next Watcher event right away (skipping its warning)
--   /event BloodMoon  starts that Watcher event right away, ending one that's playing
--                     (/event alone lists them; any capitals: /event frostfog works too;
--                     /event WatcherAwakens Eldritch picks the Awakening's monster set)
--   /stopevent        ends the event playing right now
--   /ghost            the Golden Ghost zips through the hub right now
--   /give VoidVac     gives a Workshop item or Bakery cake for free (tools are equipped;
--                     /give BaitBell 5 or /give PumpkinCandy 3 gives several)
--   /haunt            every monster in your mansion picks up a roaming effect right now
--                     (during a Watcher event: the event's own effect instead)
--   /skip 12          your monsters live 12 hours ahead: they grow Familiarity
--   /grow 5           every monster in your mansion has 5 growth spurts right now, ignoring
--                     luck and growth genes (/grow 25 makes Titans)
--   /charges          every monster you own gets all its Growth Chamber goes back
--   /chamber          the monster bubbling in your Growth Chamber is done right now
--   /missions done    finishes all of today's daily missions (/missions done 2: only the second);
--                     /missions new deals a fresh set, /missions streak 3 sets the streak to
--                     3 days and deals a fresh set so the bonus shows
--   /calm             zone monsters leave you alone (type it again to let them attack)
--   /attack           the closest monster in your zone attacks you right now
--   /spawn Gravepup   brings that monster to you in the zone you're in (any monster, any zone;
--                     add a size: /spawn TheBogKing Huge). Only you can catch it and it never
--                     attacks. /spawn all brings every monster of the zone you're in.
-- Works with the new chat (TextChatService) and the old one (LegacyChatService).
-- Any command but /summon, /event, /stopevent, /ghost and /reset can be run on another player in the server, or
-- on everyone in it: pick them at the top of the panel, or end a chat command with @name
-- (/money 5m @Biggie) or @all.
-- The results come back to the admin, starting with that player's name.
-- The panel uses one RemoteEvent, made only on the server:
--   ReplicatedStorage.Remotes.AdminCommand   client -> server: (command: string, argument: string?,
--                                            targetUserId: number?; 0 = everyone)
-- The server checks the player is an admin and the command exists before running it, so a
-- player who fires it by hand gets nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Sizes = require(ReplicatedStorage.Shared.Config.Sizes)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Mansion = require(ReplicatedStorage.Shared.Util.Mansion)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Wings = require(ReplicatedStorage.Shared.Config.Wings)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local CakeService = require(script.Parent.CakeService)
local CareService = require(script.Parent.CareService)
local DataService = require(script.Parent.DataService)
local GoldenGhostService = require(script.Parent.GoldenGhostService)
local GrowthService = require(script.Parent.GrowthService)
local HauntService = require(script.Parent.HauntService)
local HuntService = require(script.Parent.HuntService)
local MonsterAiService = require(script.Parent.MonsterAiService)
local MansionService = require(script.Parent.MansionService)
local MissionService = require(script.Parent.MissionService)
local Notify = require(script.Parent.Parent.Notify)
local SpawnService = require(script.Parent.SpawnService)
local TutorialService = require(script.Parent.TutorialService)
local WatcherService = require(script.Parent.WatcherService)
local Admins = require(script.Parent.Parent.Admins)

local DevService = {}

local MaxWings = #Wings.List
local multipliers: { [string]: number } = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }

-- "1000", "5k", "2.5M", "-1b" -> number, or nil if it isn't one.
local function parseAmount(text: string?): number?
	if not text then
		return nil
	end
	local number, suffix = string.match(string.lower(text), "^(%-?[%d%.]+)([kmbt]?)$")
	local value = number and tonumber(number)
	if not value or not suffix then
		return nil
	end
	return value * (multipliers[suffix] or 1)
end

local function wingNames(wingsOwned: number): string
	local names = {}
	for _, wing in Mansion.ownedWings(wingsOwned) do
		table.insert(names, wing.id)
	end
	return table.concat(names, ", ")
end

-- `player` is who the command is for (the admin, or the player they picked); `tell` sends a
-- result back to the admin who ran it.
type Command = (player: Player, argument: string?, tell: (text: string) -> ()) -> ...any

local commands: { [string]: Command } = {}

commands["/money"] = function(player, argument, tell)
	local amount = parseAmount(argument)
	local data = DataService.get(player)
	if not amount or not data then
		tell("Try: /money 1000000 (or /money 5m)")
		return
	end
	if DataService.addMoney(player, math.floor(amount)) then
		tell(`You now have {Format.money(data.money)}.`)
	else
		tell(`You can't go below $0 (you have {Format.money(data.money)}).`)
	end
end

commands["/wings"] = function(player, argument, tell)
	local count = tonumber(argument)
	local data = DataService.get(player)
	if not count or not data then
		tell(`Try: /wings 3 (any number from 1 to {MaxWings})`)
		return
	end
	data.wingsOwned = math.clamp(math.floor(count), 1, MaxWings)
	MansionService.rebuild(player)
	tell(`Your mansion now has: {wingNames(data.wingsOwned)}.`)
end

commands["/clearmonsters"] = function(player, _, tell)
	local data = DataService.get(player)
	if not data then
		return
	end
	table.clear(data.monsters)
	table.clear(data.storage)
	data.chamber = {}
	MansionService.rebuild(player)
	tell("Your mansion and Storage are empty now.")
end

commands["/tutorial"] = function(player, argument, tell)
	local wanted = string.lower(argument or "")
	if wanted == "skip" then
		TutorialService.skip(player)
		tell("Tutorial skipped. Everything is unlocked.")
	elseif wanted == "restart" then
		TutorialService.restart(player)
		tell("Tutorial restarted from the first step.")
	else
		tell("Try: /tutorial skip or /tutorial restart")
	end
end

-- Only ever the player who typed it: runCommand never sends it to another player.
commands["/reset"] = function(player, argument, tell)
	if string.lower(argument or "") ~= "confirm" then
		tell("This wipes your whole save. Type /reset confirm to do it.")
		return
	end
	if not DataService.reset(player) then
		tell("Your save is still loading. Try again in a moment.")
	end
end

commands["/summon"] = function(_, _, tell)
	if not WatcherService.summon() then
		tell("Couldn't start the next event.")
	end
end

commands["/stopevent"] = function(_, _, tell)
	if not WatcherService.stop() then
		tell("No event is playing.")
	end
end

commands["/ghost"] = function(_, _, tell)
	if not GoldenGhostService.spawn() then
		tell("The Golden Ghost is already out.")
	end
end

commands["/event"] = function(_, argument, tell)
	local wantedEvent, wantedSet = string.match(argument or "", "^(%S*)%s*(%S*)")
	local wanted, setWanted = string.lower(wantedEvent or ""), string.lower(wantedSet or "")
	local ids: { string } = {}
	for _, event in Events.List do
		if event.launch then
			table.insert(ids, event.id)
			if string.lower(event.id) == wanted then
				local setId: string? = nil
				local setIds: { string } = {}
				for _, set in event.monsterSets or ({} :: { Events.MonsterSet }) do
					table.insert(setIds, set.id)
					if string.lower(set.id) == setWanted then
						setId = set.id
					end
				end
				if setWanted ~= "" and not setId then
					tell(`{event.name} has these: {table.concat(setIds, ", ")}`)
				elseif not WatcherService.summon(event.id, setId) then
					tell("Couldn't start that event.")
				end
				return
			end
		end
	end
	tell(`Try /event with one of: {table.concat(ids, ", ")}`)
end

commands["/give"] = function(player, argument, tell)
	local data = DataService.get(player)
	local itemId, countText = string.match(argument or "", "^(%S+)%s*(%S*)")
	local item = nil
	if itemId then
		-- Any capitals: "/give voidvac" works too.
		for _, list in { Shop.Workshop, Shop.Bakery } do
			for _, candidate in list do
				if string.lower(candidate.id) == string.lower(itemId) then
					item = candidate
				end
			end
		end
	end
	if not data or not item then
		tell("Try: /give VoidVac, /give MoonVac, /give BaitBell 5 or /give PumpkinCandy 3")
		return
	end
	local count = math.clamp(math.floor(tonumber(countText) or 1), 1, 99)
	local equipSlot = Workshop.equipSlot(item)
	if equipSlot then
		local equipped: { [string]: string } = data.equipped
		data.inventory[item.id] = 1
		equipped[equipSlot] = item.id
		tell(`You got the {item.name} and you're using it.`)
	else
		data.inventory[item.id] = (data.inventory[item.id] or 0) + count
		tell(`You now have {data.inventory[item.id]} x {item.name}.`)
	end
	HuntService.refreshItems(player)
	CakeService.syncTools(player)
end

commands["/haunt"] = function(player, _, tell)
	local event = WatcherService.current()
	local gained = if event and event.effect
		then HauntService.eventRollFor(player, event, true)
		else HauntService.rollFor(player, true)
	if gained == 0 then
		tell("No monster could take an effect (they already have them all).")
	end
end

commands["/skip"] = function(player, argument, tell)
	local hours = tonumber(argument)
	local data = DataService.get(player)
	if not hours or hours <= 0 or not data then
		tell("Try: /skip 12 (hours)")
		return
	end
	-- Moving every timestamp back is the same as that much time passing.
	local seconds = math.floor(hours * 3600)
	for _, caught in data.monsters do
		caught.grownAt = (caught.grownAt or os.time()) - seconds
	end
	CareService.refresh(player)
	tell(`Your monsters skipped {hours} hours ahead.`)
end

commands["/grow"] = function(player, argument, tell)
	local spurts = tonumber(argument)
	if not spurts or spurts < 1 or spurts > 200 then
		tell("Try: /grow 5 (growth spurts for every monster; /grow 25 makes Titans)")
		return
	end
	MansionService.grow(player, math.floor(spurts))
	tell(`Your monsters had {math.floor(spurts)} growth spurts.`)
end

commands["/charges"] = function(player, _, tell)
	local data = DataService.get(player)
	if not data then
		tell("Your save is still loading.")
		return
	end
	for _, list in { data.monsters, data.storage, data.vault } do
		for _, caught in list do
			caught.growUsed = nil
		end
	end
	tell("Every monster has all its Growth Chamber goes back.")
end

commands["/chamber"] = function(player, _, tell)
	tell(
		if GrowthService.finish(player)
			then "Your Growth Chamber is done. Walk up to it to see how it went."
			else "Nothing is bubbling in your Growth Chamber."
	)
end

commands["/missions"] = function(player, argument, tell)
	local what, number = string.match(string.lower(argument or ""), "^(%a+)%s*(%d*)$")
	local count = tonumber(number)
	if what == "done" then
		tell(
			if MissionService.finish(player, count)
				then "Done! Open Missions to claim the rewards."
				else "Nothing to finish (already claimed?)."
		)
	elseif what == "new" then
		tell(
			if MissionService.redeal(player)
				then "Fresh daily missions dealt."
				else "Your save is still loading."
		)
	elseif what == "streak" and count then
		tell(
			if MissionService.setStreak(player, count)
				then `Streak set to {count} days, with fresh missions.`
				else "Your save is still loading."
		)
	else
		tell("Try: /missions done, /missions done 2, /missions new or /missions streak 3")
	end
end

commands["/calm"] = function(player, _, tell)
	local calm = not player:GetAttribute("Calm")
	player:SetAttribute("Calm", if calm then true else nil)
	tell(if calm then "Monsters leave you alone now. /calm again to undo." else "Monsters attack you again.")
end

commands["/attack"] = function(player, _, tell)
	if not MonsterAiService.provoke(player) then
		tell("Go into a zone first, with a monster in it.")
	end
end

-- "the bog king", "TheBogKing" and "thebogking" all find TheBogKing.
local function squash(text: string): string
	return string.lower((string.gsub(text, "[%s_]", "")))
end

commands["/spawn"] = function(player, argument, tell)
	local words = string.split(argument or "", " ")
	local sizeId = "Normal"
	local last = words[#words]
	for _, size in Sizes do
		if #words > 1 and last and string.lower(size.id) == string.lower(last) then
			sizeId = size.id
			table.remove(words)
		end
	end
	local wanted = squash(table.concat(words, ""))
	if wanted == "" then
		tell("Try: /spawn Gravepup, /spawn TheBogKing Huge or /spawn all")
		return
	end

	if wanted == "all" then
		local zoneIndex = nil
		for _, zone in Zones.List do
			if zone.id == player:GetAttribute("Zone") then
				zoneIndex = zone.index
			end
		end
		if not zoneIndex then
			tell("Go into a zone first, then try /spawn all again.")
			return
		end
		local count = 0
		for _, monster in Monsters do
			if monster.zone == zoneIndex and SpawnService.spawnFor(player, monster.id, sizeId) then
				count += 1
			end
		end
		tell(`{count} monsters came to you. Only you can catch them.`)
		return
	end

	for id in Monsters do
		if squash(id) == wanted then
			local _, message = SpawnService.spawnFor(player, id, sizeId)
			tell(message)
			return
		end
	end
	tell(`There's no monster called "{argument}". Try /spawn Gravepup`)
end

local MaxArgumentLength = 60

-- Commands that act on the whole server or only ever on yourself: a picked player is ignored.
local untargeted: { [string]: boolean } =
	{ ["/summon"] = true, ["/event"] = true, ["/stopevent"] = true, ["/ghost"] = true, ["/reset"] = true }

-- Runs one command for an admin, on `target` (another player in the server) or on the admin.
-- Anything else (not an admin, unknown command, odd argument) is ignored.
local function runCommand(admin: Player, name: string, argument: string?, target: Player?)
	local key = string.lower(name)
	local command = commands[key]
	if not command or not Admins.isAdmin(admin) then
		return
	end
	if argument and (argument == "" or #argument > MaxArgumentLength) then
		argument = nil
	end
	local who = if target and target.Parent == Players and not untargeted[key] then target else admin
	if target and target ~= admin and key == "/reset" then
		Notify.toast(admin, "Reset only ever wipes your own save.")
		return
	end
	local function tell(text: string)
		Notify.toast(admin, if who ~= admin then `{who.DisplayName}: {text}` else text)
	end
	local ok, err = pcall(command, who, argument, tell)
	if not ok then
		warn(`DevService: {name} failed: {err}`)
	elseif who ~= admin then
		print(`DevService: {admin.Name} ran {name} {argument or ""} on {who.Name}`)
	end
end

-- The player a chat command names with "@name" at the end (name or display name, any
-- capitals, the start of it is enough), or nil.
local function findPlayer(wanted: string): Player?
	wanted = string.lower(wanted)
	for _, other in Players:GetPlayers() do
		local name, display = string.lower(other.Name), string.lower(other.DisplayName)
		if string.sub(name, 1, #wanted) == wanted or string.sub(display, 1, #wanted) == wanted then
			return other
		end
	end
	return nil
end

-- Runs a command on every player in the server (once, for the server-wide ones).
local function runForEveryone(admin: Player, name: string, argument: string?)
	if string.lower(name) == "/reset" then
		if Admins.isAdmin(admin) then
			Notify.toast(admin, "Reset only ever wipes your own save.")
		end
		return
	end
	if untargeted[string.lower(name)] then
		runCommand(admin, name, argument)
		return
	end
	for _, other in Players:GetPlayers() do
		runCommand(admin, name, argument, other)
	end
end

-- Runs a chat message if it's one of the commands above. "/money 5m @Biggie" runs it on
-- that player instead of yourself.
local function run(player: Player, message: string)
	local name, rest = string.match(message, "^%s*(/%S+)%s*(.-)%s*$")
	if not name then
		return
	end
	local before, wanted = string.match(rest or "", "^(.-)%s*@(%S+)$")
	if wanted and string.lower(wanted) == "all" then
		runForEveryone(player, name, before)
	elseif wanted then
		local target = findPlayer(wanted)
		if not target then
			if Admins.isAdmin(player) then
				Notify.toast(player, `Nobody called "{wanted}" is in this server.`)
			end
			return
		end
		runCommand(player, name, before, target)
	else
		runCommand(player, name, rest)
	end
end

-- The admin panel's buttons. Values from the client are checked: both must be strings.
local function useAdminRemote()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = Instance.new("RemoteEvent")
	remote.Name = "AdminCommand"
	remote.OnServerEvent:Connect(function(player: Player, name: unknown, argument: unknown, targetId: unknown)
		if type(name) ~= "string" or #name > 20 then
			return
		end
		local text = if type(argument) == "string" then argument else nil
		if targetId == 0 then
			runForEveryone(player, name, text)
			return
		end
		local target = if type(targetId) == "number" then Players:GetPlayerByUserId(targetId) else nil
		runCommand(player, name, text, target)
	end)
	remote.Parent = remotes
end

-- Marks admins so their client shows the panel (the server checks again on every command).
local function markAdmins()
	local function mark(player: Player)
		if Admins.isAdmin(player) then
			player:SetAttribute("Admin", true)
		end
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
end

-- New chat: a TextChatCommand per command (the message doesn't show up in the chat).
local function useTextChatCommands()
	local folder = Instance.new("Folder")
	folder.Name = "DevCommands"
	for name in commands do
		local command = Instance.new("TextChatCommand")
		command.Name = name:sub(2)
		command.PrimaryAlias = name
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				run(player, text)
			end
		end)
		command.Parent = folder
	end
	folder.Parent = TextChatService
end

-- Old chat: listen to every player's messages.
local function useLegacyChat()
	local function watch(player: Player)
		player.Chatted:Connect(function(message)
			run(player, message)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

function DevService.start()
	markAdmins()
	useAdminRemote()
	-- Only one of the two, so a command never runs twice.
	if TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService then
		useLegacyChat()
	else
		useTextChatCommands()
	end
	if not RunService:IsStudio() then
		return
	end
	print(
		`DevService (admins, F2 opens the panel): /money <amount>, /wings <1-{MaxWings}>, /clearmonsters, /tutorial skip|restart, /reset confirm, /give <item> [count], /summon, /event <name> [set], /stopevent, /skip <hours>, /haunt, /charges, /chamber, /missions done|new|streak <days>, /calm, /attack`
	)
end

return DevService
