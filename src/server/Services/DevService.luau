--!strict
-- Test commands for play testing in Studio (they do nothing in the real game). Type them
-- in the chat box:
--   /money 1000000    adds money (a negative number takes some away; 5k, 2.5m and 1b work too)
--   /wings 3          sets how many wings your mansion has (1 to 6) and rebuilds it
--   /clearmonsters    empties your mansion
--   /summon           starts the next Watcher event right away (Flicker, then Blood Moon)
--   /give VoidVac     gives a Workshop item or Bakery treat for free (tools are equipped;
--                     /give BaitBell 5 or /give PumpkinCandy 3 gives several)
--   /skip 12          your monsters live 12 hours ahead: they grow Familiarity, and get
--                     hungry after a day (/skip 25 makes them all hungry)
-- Works with the new chat (TextChatService) and the old one (LegacyChatService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Mansion = require(ReplicatedStorage.Shared.Util.Mansion)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Wings = require(ReplicatedStorage.Shared.Config.Wings)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local CareService = require(script.Parent.CareService)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local MansionService = require(script.Parent.MansionService)
local Notify = require(script.Parent.Parent.Notify)
local WatcherService = require(script.Parent.WatcherService)

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
	MansionService.rebuild(player)
	Notify.toast(player, "Your mansion is empty now.")
end

commands["/summon"] = function(player)
	if not WatcherService.summon() then
		Notify.toast(player, "An event is already playing. Wait for it to end first.")
	end
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
		Notify.toast(player, "Try: /give VoidVac, /give Moonbeam, /give BaitBell 5 or /give PumpkinCandy 3")
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
end

commands["/skip"] = function(player, argument)
	local hours = tonumber(argument)
	local data = DataService.get(player)
	if not hours or hours <= 0 or not data then
		Notify.toast(player, "Try: /skip 12 (hours; /skip 25 makes your monsters hungry)")
		return
	end
	-- Moving every timestamp back is the same as that much time passing.
	local seconds = math.floor(hours * 3600)
	for _, caught in data.monsters do
		caught.fedUntil = (caught.fedUntil or os.time()) - seconds
		caught.grownAt = (caught.grownAt or os.time()) - seconds
	end
	CareService.refresh(player)
	Notify.toast(player, `Your monsters skipped {hours} hours ahead.`)
end

-- Runs a chat message if it's one of the commands above.
local function run(player: Player, message: string)
	local name, rest = string.match(message, "^%s*(/%S+)%s*(.-)%s*$")
	local argument = rest
	local command = name and commands[string.lower(name)]
	if not command then
		return
	end
	local ok, err = pcall(command, player, if argument ~= "" then argument else nil)
	if not ok then
		warn(`DevService: {name} failed: {err}`)
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
	if not RunService:IsStudio() then
		return
	end
	-- Only one of the two, so a command never runs twice.
	if TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService then
		useLegacyChat()
	else
		useTextChatCommands()
	end
	print(
		`DevService (Studio only): /money <amount>, /wings <1-{MaxWings}>, /clearmonsters, /give <item> [count], /summon, /skip <hours>`
	)
end

return DevService
