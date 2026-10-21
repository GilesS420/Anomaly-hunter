--!strict
-- Admin commands for play testing. Only admins can use them (see server/Admins.luau: anyone
-- in Studio, the game's owner and the UserIds listed there); for everyone else they do
-- nothing. Admins can press the buttons in the admin panel (client AdminController, F2 or
-- the Admin button) or type them in the chat box:
--   /money 1000000    adds money (a negative number takes some away; 5k, 2.5m and 1b work too)
--   /wings 3          sets how many wings your mansion has (1 to 6) and rebuilds it
--   /clearmonsters    empties your mansion and Storage
--   /tutorial skip    ends your tutorial now (/tutorial restart starts it again from the gate)
--   /reset confirm    wipes YOUR save back to a brand-new player's and kicks you; rejoin to
--                     start fresh (replay the tutorial and early game). Nobody else is touched.
--   /summon           starts the next Watcher event right away (skipping its warning)
--   /event BloodMoon  starts that Watcher event right away (/event alone lists them;
--                     any capitals: /event frostfog works too)
--   /give VoidVac     gives a Workshop item or Bakery cake for free (tools are equipped;
--                     /give BaitBell 5 or /give PumpkinCandy 3 gives several)
--   /haunt            every monster in your mansion picks up a roaming effect right now
--                     (during a Watcher event: the event's own effect instead)
--   /skip 12          your monsters live 12 hours ahead: they grow Familiarity
--   /grow 5           every monster in your mansion has 5 growth spurts right now, ignoring
--                     luck and growth genes (/grow 25 makes Titans)
--   /calm             zone monsters leave you alone (type it again to let them attack)
--   /attack           the closest monster in your zone attacks you right now
--   /spawn Gravepup   brings that monster to you in the zone you're in (any monster, any zone;
--                     add a size: /spawn TheBogKing Huge). Only you can catch it and it never
--                     attacks. /spawn all brings every monster of the zone you're in.
-- Works with the new chat (TextChatService) and the old one (LegacyChatService).
-- The panel uses one RemoteEvent, made only on the server:
--   ReplicatedStorage.Remotes.AdminCommand   client -> server: (command: string, argument: string?)
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
local HauntService = require(script.Parent.HauntService)
local HuntService = require(script.Parent.HuntService)
local MonsterAiService = require(script.Parent.MonsterAiService)
local MansionService = require(script.Parent.MansionService)
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

type Command = (player: Player, argument: string?) -> ...any

local commands: { [string]: Command } = {}

commands["/money"] = function(player, argument)
	local amount = parseAmount(argument)
	local data = DataService.get(player)
	if not amount or not data then
		Notify.toast(player, "Try: /money 1000000 (or /money 5m)")
		return
	end
	if DataService.addMoney(player, math.floor(amount)) then
		Notify.toast(player, `You now have {Format.money(data.money)}.`)
	else
		Notify.toast(player, `You can't go below $0 (you have {Format.money(data.money)}).`)
	end
end

commands["/wings"] = function(player, argument)
	local count = tonumber(argument)
	local data = DataService.get(player)
	if not count or not data then
		Notify.toast(player, `Try: /wings 3 (any number from 1 to {MaxWings})`)
		return
	end
	data.wingsOwned = math.clamp(math.floor(count), 1, MaxWings)
	MansionService.rebuild(player)
	Notify.toast(player, `Your mansion now has: {wingNames(data.wingsOwned)}.`)
end

commands["/clearmonsters"] = function(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	table.clear(data.monsters)
	table.clear(data.storage)
	MansionService.rebuild(player)
	Notify.toast(player, "Your mansion and Storage are empty now.")
end

commands["/tutorial"] = function(player, argument)
	local wanted = string.lower(argument or "")
	if wanted == "skip" then
		TutorialService.skip(player)
		Notify.toast(player, "Tutorial skipped. Everything is unlocked.")
	elseif wanted == "restart" then
		TutorialService.restart(player)
		Notify.toast(player, "Tutorial restarted from the first step.")
	else
		Notify.toast(player, "Try: /tutorial skip or /tutorial restart")
	end
end

-- Only ever the player who typed it: the command has no target argument.
commands["/reset"] = function(player, argument)
	if string.lower(argument or "") ~= "confirm" then
		Notify.toast(player, "This wipes your whole save. Type /reset confirm to do it.")
		return
	end
	if not DataService.reset(player) then
		Notify.toast(player, "Your save is still loading. Try again in a moment.")
	end
end

commands["/summon"] = function(player)
	if not WatcherService.summon() then
		Notify.toast(player, "An event is already playing. Wait for it to end first.")
	end
end

commands["/event"] = function(player, argument)
	local wanted = string.lower((string.gsub(argument or "", "%s", "")))
	local ids: { string } = {}
	for _, event in Events.List do
		if event.launch then
			table.insert(ids, event.id)
			if string.lower(event.id) == wanted then
				if not WatcherService.summon(event.id) then
					Notify.toast(player, "An event is already playing. Wait for it to end first.")
				end
				return
			end
		end
	end
	Notify.toast(player, `Try /event with one of: {table.concat(ids, ", ")}`)
end

commands["/give"] = function(player, argument)
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
		Notify.toast(player, "Try: /give VoidVac, /give MoonVac, /give BaitBell 5 or /give PumpkinCandy 3")
		return
	end
	local count = math.clamp(math.floor(tonumber(countText) or 1), 1, 99)
	local equipSlot = Workshop.equipSlot(item)
	if equipSlot then
		local equipped: { [string]: string } = data.equipped
		data.inventory[item.id] = 1
		equipped[equipSlot] = item.id
		Notify.toast(player, `You got the {item.name} and you're using it.`)
	else
		data.inventory[item.id] = (data.inventory[item.id] or 0) + count
		Notify.toast(player, `You now have {data.inventory[item.id]} x {item.name}.`)
	end
	HuntService.refreshItems(player)
	CakeService.syncTools(player)
end

commands["/haunt"] = function(player)
	local event = WatcherService.current()
	local gained = if event and event.effect
		then HauntService.eventRollFor(player, event, true)
		else HauntService.rollFor(player, true)
	if gained == 0 then
		Notify.toast(player, "No monster could take an effect (they already have them all).")
	end
end

commands["/skip"] = function(player, argument)
	local hours = tonumber(argument)
	local data = DataService.get(player)
	if not hours or hours <= 0 or not data then
		Notify.toast(player, "Try: /skip 12 (hours)")
		return
	end
	-- Moving every timestamp back is the same as that much time passing.
	local seconds = math.floor(hours * 3600)
	for _, caught in data.monsters do
		caught.grownAt = (caught.grownAt or os.time()) - seconds
	end
	CareService.refresh(player)
	Notify.toast(player, `Your monsters skipped {hours} hours ahead.`)
end

commands["/grow"] = function(player, argument)
	local spurts = tonumber(argument)
	if not spurts or spurts < 1 or spurts > 200 then
		Notify.toast(player, "Try: /grow 5 (growth spurts for every monster; /grow 25 makes Titans)")
		return
	end
	MansionService.grow(player, math.floor(spurts))
	Notify.toast(player, `Your monsters had {math.floor(spurts)} growth spurts.`)
end

commands["/calm"] = function(player)
	local calm = not player:GetAttribute("Calm")
	player:SetAttribute("Calm", if calm then true else nil)
	Notify.toast(
		player,
		if calm then "Monsters leave you alone now. /calm again to undo." else "Monsters attack you again."
	)
end

commands["/attack"] = function(player)
	if not MonsterAiService.provoke(player) then
		Notify.toast(player, "Go into a zone first, with a monster in it.")
	end
end

-- "the bog king", "TheBogKing" and "thebogking" all find TheBogKing.
local function squash(text: string): string
	return string.lower((string.gsub(text, "[%s_]", "")))
end

commands["/spawn"] = function(player, argument)
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
		Notify.toast(player, "Try: /spawn Gravepup, /spawn TheBogKing Huge or /spawn all")
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
			Notify.toast(player, "Go into a zone first, then try /spawn all again.")
			return
		end
		local count = 0
		for _, monster in Monsters do
			if monster.zone == zoneIndex and SpawnService.spawnFor(player, monster.id, sizeId) then
				count += 1
			end
		end
		Notify.toast(player, `{count} monsters came to you. Only you can catch them.`)
		return
	end

	for id in Monsters do
		if squash(id) == wanted then
			local _, message = SpawnService.spawnFor(player, id, sizeId)
			Notify.toast(player, message)
			return
		end
	end
	Notify.toast(player, `There's no monster called "{argument}". Try /spawn Gravepup`)
end

local MaxArgumentLength = 60

-- Runs one command for an admin. Anything else (not an admin, unknown command, odd
-- argument) is ignored.
local function runCommand(player: Player, name: string, argument: string?)
	local command = commands[string.lower(name)]
	if not command or not Admins.isAdmin(player) then
		return
	end
	if argument and (argument == "" or #argument > MaxArgumentLength) then
		argument = nil
	end
	local ok, err = pcall(command, player, argument)
	if not ok then
		warn(`DevService: {name} failed: {err}`)
	end
end

-- Runs a chat message if it's one of the commands above.
local function run(player: Player, message: string)
	local name, rest = string.match(message, "^%s*(/%S+)%s*(.-)%s*$")
	if name then
		runCommand(player, name, rest)
	end
end

-- The admin panel's buttons. Values from the client are checked: both must be strings.
local function useAdminRemote()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = Instance.new("RemoteEvent")
	remote.Name = "AdminCommand"
	remote.OnServerEvent:Connect(function(player: Player, name: unknown, argument: unknown)
		if type(name) ~= "string" or #name > 20 then
			return
		end
		runCommand(player, name, if type(argument) == "string" then argument else nil)
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
		`DevService (admins, F2 opens the panel): /money <amount>, /wings <1-{MaxWings}>, /clearmonsters, /tutorial skip|restart, /reset confirm, /give <item> [count], /summon, /event <name>, /skip <hours>, /haunt, /calm, /attack`
	)
end

return DevService
