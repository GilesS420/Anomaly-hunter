--!strict
-- Admin commands for play testing. Only admins can use them (see server/Admins.luau: anyone
-- in Studio, the game's owner and the UserIds listed there); for everyone else they do
-- nothing. Admins can press the buttons in the admin panel (client AdminController, F2) or
-- type them in the chat box:
--   /money 1000000    adds money (a negative number takes some away; 5k, 2.5m and 1b work too)
--   /wings 3          sets how many wings your mansion has (1 to 6) and rebuilds it
--   /clearmonsters    empties your mansion, Storage and Growth Chamber
--   /tutorial skip    ends your tutorial now (/tutorial restart starts it again from the gate)
--   /reset confirm    wipes the save back to a brand-new player's and kicks them; rejoin to
--                     start fresh (replay the tutorial and early game). Yours, or one picked
--                     player's (Giles 2026-10-30), never everyone's at once.
--   /respawn          a fresh body back home, like the Reset button in the Roblox menu
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
--                     3 days and deals a fresh set so the bonus shows; /missions reset starts
--                     today's missions over (no progress, claimable again); /missions set Merge2
--                     swaps in that mission (Config/Missions.Pool) for today's of its tier
--   /calm             zone monsters leave you alone (type it again to let them attack)
--   /attacks off      the same, but sets it (/attacks on lets them attack again)
--   /attack           the closest monster in your zone attacks you right now
--   /spawn Gravepup   brings that monster to you in the zone you're in (any monster, any zone;
--                     add a size: /spawn TheBogKing Huge). Only you can catch it and it never
--                     attacks. /spawn all brings every monster of the zone you're in.
--   /restock cakes 10 an admin restock in this server: every cake in stock, 10 per player, for
--                     5 minutes (/restock PumpkinCandy 10 BaitBell 5 picks items, "workshop"
--                     and "all" are groups too, add "time 15" for 15 minutes; Util/Restock).
--                     /restock end stops it and the normal stock is back.
--   /announce Hello!  a big banner with that text for everyone in this server (filtered by
--                     Roblox like chat)
--   /givemonster Gravepup Huge Gold 120kg Cobwebbed Count
--                     a brand-new monster (Giles 2026-10-30). After its name, in any order and
--                     all optional: a size, a variant, a weight (sets the size), effects and
--                     combos (a combo gives both its effects). Into the mansion, or Storage.
--   /addeffect <uid> Gilded   puts effects or combos on one of the player's monsters (the
--                     panel's Monsters tab picks it from a list); not with @all
-- Works with the new chat (TextChatService) and the old one (LegacyChatService).
-- Any command but /summon, /event, /stopevent, /ghost, /restock and /announce can be run on another
-- player in the server, and all of those but /reset and /addeffect on everyone in it: pick them
-- at the top of the panel, or end a chat command with @name
-- (/money 5m @Biggie) or @all.
-- The results come back to the admin, starting with that player's name.
-- The panel uses two remotes, made only on the server:
--   ReplicatedStorage.Remotes.AdminCommand   client -> server: (command: string, argument: string?,
--                                            targetUserId: number?; 0 = everyone)
--   ReplicatedStorage.Remotes.AdminMonsters  RemoteFunction (targetUserId?) -> { {uid, label,
--                                            effects} }: that player's monsters (their effect
--                                            ids, no combos), for /addeffect; {} for non-admins
-- The server checks the player is an admin and the command exists before running it, so a
-- player who fires it by hand gets nothing.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Effects = require(ReplicatedStorage.Shared.Config.Effects)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Sizes = require(ReplicatedStorage.Shared.Config.Sizes)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Mansion = require(ReplicatedStorage.Shared.Util.Mansion)
local Restock = require(ReplicatedStorage.Shared.Util.Restock)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local Weight = require(ReplicatedStorage.Shared.Util.Weight)
local Wings = require(ReplicatedStorage.Shared.Config.Wings)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local CakeService = require(script.Parent.CakeService)
local CareService = require(script.Parent.CareService)
local DataService = require(script.Parent.DataService)
local GoldenGhostService = require(script.Parent.GoldenGhostService)
local GrowthService = require(script.Parent.GrowthService)
local HauntService = require(script.Parent.HauntService)
local HuntService = require(script.Parent.HuntService)
local InventoryService = require(script.Parent.InventoryService)
local MonsterAiService = require(script.Parent.MonsterAiService)
local MansionService = require(script.Parent.MansionService)
local MissionService = require(script.Parent.MissionService)
local Notify = require(script.Parent.Parent.Notify)
local SpawnService = require(script.Parent.SpawnService)
local TutorialService = require(script.Parent.TutorialService)
local WatcherService = require(script.Parent.WatcherService)
local Admins = require(script.Parent.Parent.Admins)
local AdminRestock = require(script.Parent.Parent.AdminRestock)

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
-- `admin` is who ran it.
type Command = (player: Player, argument: string?, tell: (text: string) -> (), admin: Player) -> ...any

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

-- One player at a time: runForEveryone never sends it to everyone.
commands["/reset"] = function(player, argument, tell, admin)
	if string.lower(argument or "") ~= "confirm" then
		tell("This wipes the whole save. Type /reset confirm to do it.")
		return
	end
	if not DataService.reset(player) then
		tell("The save is still loading. Try again in a moment.")
	elseif player ~= admin then
		tell("Save wiped. They were sent out of the game and start fresh when they rejoin.")
	end
end

commands["/respawn"] = function(player, _, tell)
	player:LoadCharacter() -- HuntService ends a hunt the old body was on
	tell("Respawned at home.")
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
	local what, rest = string.match(argument or "", "^%s*(%a+)%s*(%S*)%s*$")
	what = if what then string.lower(what) else nil
	local count = tonumber(rest)
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
	elseif what == "reset" then
		tell(
			if MissionService.resetProgress(player)
				then "Today's missions start over (claimable again)."
				else "Your save is still loading."
		)
	elseif what == "set" and rest and rest ~= "" then
		local text = MissionService.setMission(player, rest)
		tell(
			if text then `Mission set: {text}` else `Couldn't set "{rest}" (zone missions need a zone open).`
		)
	elseif what == "streak" and count then
		tell(
			if MissionService.setStreak(player, count)
				then `Streak set to {count} days, with fresh missions.`
				else "Your save is still loading."
		)
	else
		tell(
			"Try: /missions done, /missions done 2, /missions new, /missions reset, /missions set Merge2 or /missions streak 3"
		)
	end
end

commands["/calm"] = function(player, _, tell)
	local calm = not player:GetAttribute("Calm")
	player:SetAttribute("Calm", if calm then true else nil)
	tell(if calm then "Monsters leave you alone now. /calm again to undo." else "Monsters attack you again.")
end

commands["/attacks"] = function(player, argument, tell)
	local wanted = string.lower(argument or "")
	if wanted ~= "on" and wanted ~= "off" then
		tell("Try: /attacks on or /attacks off")
		return
	end
	player:SetAttribute("Calm", if wanted == "off" then true else nil)
	tell(if wanted == "off" then "Monsters leave you alone now." else "Monsters attack you again.")
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

-- Every effect and combo id by its squashed name ("rat king" -> RatKing), for /givemonster
-- and /addeffect. A combo gives the two effects of its recipe (they merge by themselves).
local effectIds: { [string]: string } = {}
for id in Effects.List do
	effectIds[squash(id)] = id
end
for id in Effects.Combos do
	effectIds[squash(id)] = id
end

local function effectsOf(id: string): { string }
	local combo = Effects.Combos[id]
	return if combo then table.clone(combo.recipe) else { id }
end

-- Adds `wanted` (effect and combo ids) to `effects` by the game's rules: no doubles, Critter
-- effects only on cheap monsters. Returns the new list and the ones that didn't fit.
local function withEffects(
	effects: { string },
	wanted: { string },
	monsterId: string
): ({ string }, { string })
	local after = table.clone(effects)
	local skipped: { string } = {}
	for _, id in wanted do
		for _, effectId in effectsOf(id) do
			local fit = Value.fits(after, effectId, monsterId)
			if fit == "Ok" then
				table.insert(after, effectId)
			elseif fit == "TooPricey" then
				table.insert(
					skipped,
					`{Format.name(effectId)} (Critter effects only fit monsters worth up to {Format.money(
						Effects.CritterMaxValue
					)})`
				)
			end
		end
	end
	return after, skipped
end

-- Notes the combos a monster has for the Codex.
local function noteCombos(data: DataService.Data, effects: { string })
	for _, id in Value.resolveEffects(effects) do
		if Effects.Combos[id] then
			CareService.discoverCombo(data, id)
		end
	end
end

local function lookName(caught: Value.CaughtMonster): string
	local variant = if caught.variant then `{caught.variant} ` else ""
	return `{variant}{caught.size} {Format.monsterName(caught)}`
end

local MaxGiveKg = 1e6

-- /givemonster Gravepup Huge Gold 120kg Cobwebbed Count: a brand-new monster, in any order
-- after its name. Leave out what you don't care about (a size alone gives it a weight for
-- that size; a weight sets its size). Goes into the mansion, or Storage when that's full.
commands["/givemonster"] = function(player, argument, tell, admin)
	local data = DataService.get(player)
	local words = string.split(string.match(argument or "", "^%s*(.-)%s*$") or "", " ")
	local monsterId: string? = nil
	for id in Monsters do
		if words[1] and squash(id) == squash(words[1]) then
			monsterId = id
		end
	end
	if not data or not monsterId then
		tell("Try: /givemonster Gravepup, or /givemonster Gravepup Huge Gold 120kg Cobwebbed Count")
		return
	end
	local sizeId, variantId, kg = "Normal", nil :: string?, nil :: number?
	local wanted: { string } = {}
	for i = 2, #words do
		local word = words[i]
		local key = squash(word)
		local number = tonumber(string.match(string.lower(word), "^([%d%.]+)kg$"))
		local found = false
		if key == "" or key == "none" then
			found = true
		elseif number then
			if number ~= number or number <= 0 or number > MaxGiveKg then
				tell(`A weight from 0.1 to {MaxGiveKg} kg, like 120kg.`)
				return
			end
			kg, found = math.floor(number * 10 + 0.5) / 10, true
		end
		for _, size in Sizes do
			if not found and squash(size.id) == key then
				sizeId, found = size.id, true
			end
		end
		for _, variant in Variants do
			if not found and squash(variant.id) == key then
				variantId, found = variant.id, true
			end
		end
		if not found and effectIds[key] then
			table.insert(wanted, effectIds[key])
			found = true
		end
		if not found then
			tell(`"{word}" isn't a size, variant, weight (120kg) or effect.`)
			return
		end
	end

	local effects, skipped = withEffects({}, wanted, monsterId)
	local caught: Value.CaughtMonster = {
		uid = HttpService:GenerateGUID(false),
		monsterId = monsterId,
		size = sizeId,
		effects = effects,
		variant = variantId,
		familiarity = 0,
	}
	if kg then
		-- Its size follows its weight; a fresh gene like any catch.
		caught.kg = math.max(kg, 0.1)
		caught.size = Weight.sizeFor(math.max(kg, 0.1))
		caught.gene = Weight.rollGene()
		caught.kgAt = os.time()
	else
		Weight.settle(caught, os.time()) -- a weight for its size now, so Storage shows it too
	end
	local where = MansionService.addMonster(player, caught)
	if not where then
		tell("Their mansion and Storage are full (or the save is still loading).")
		return
	end
	noteCombos(data, effects)
	InventoryService.syncMonsterTools(player)
	local name = lookName(caught)
	local place = if where == "Storage" then "Storage (the mansion is full)" else "the mansion"
	tell(`Gave a {name} ({Weight.text(caught.kg or 0)}), in {place}.`)
	if #skipped > 0 then
		tell(`Left off: {table.concat(skipped, ", ")}`)
	end
	if player ~= admin then
		Notify.toast(
			player,
			`An admin gave you a {name}! It's in your {if where == "Storage" then "Storage" else "mansion"}.`
		)
	end
end

-- A monster the player owns, in the mansion or Storage, by its uid.
local function ownedMonster(data: DataService.Data, uid: string): Value.CaughtMonster?
	for _, list in { data.monsters, data.storage } do
		for _, caught in list do
			if caught.uid == uid then
				return caught
			end
		end
	end
	return nil
end

-- /addeffect <monster uid> Gilded Count: puts effects (a combo: both its effects) on one of
-- the player's monsters. The admin panel picks the monster from a list (AdminMonsters below).
commands["/addeffect"] = function(player, argument, tell, admin)
	local data = DataService.get(player)
	local words = string.split(string.match(argument or "", "^%s*(.-)%s*$") or "", " ")
	local caught = if data and words[1] then ownedMonster(data, words[1]) else nil
	if not data or not caught then
		tell("Pick one of their monsters first (that one is gone, or the save is still loading).")
		return
	end
	local wanted: { string } = {}
	for i = 2, #words do
		local id = effectIds[squash(words[i])]
		if not id then
			tell(`"{words[i]}" isn't an effect or combo.`)
			return
		end
		table.insert(wanted, id)
	end
	if #wanted == 0 then
		tell("Pick an effect to add.")
		return
	end
	local before = #caught.effects
	local after, skipped = withEffects(caught.effects, wanted, caught.monsterId)
	if #after == before then
		tell(if #skipped > 0 then `Didn't fit: {table.concat(skipped, ", ")}` else "It already has that.")
		return
	end
	caught.effects = after
	noteCombos(data, after)
	DataService.saveSoon(player)
	MansionService.refreshMonsters(player)
	InventoryService.syncMonsterTools(player)
	local names: { string } = {}
	for _, id in Value.resolveEffects(after) do
		table.insert(names, Format.name(id))
	end
	local name = Format.monsterName(caught)
	tell(`{name} now has: {table.concat(names, ", ")}.`)
	if #skipped > 0 then
		tell(`Left off: {table.concat(skipped, ", ")}`)
	end
	if player ~= admin then
		Notify.toast(player, `An admin haunted your {name}: it now has {table.concat(names, ", ")}!`)
	end
end

commands["/restock"] = function(_, argument, tell)
	local wanted = string.lower(argument or "")
	if wanted == "end" or wanted == "stop" then
		if AdminRestock.stop() then
			Notify.toastAll("The admin restock is over: the shops have their normal stock again.")
		else
			tell("No admin restock is on.")
		end
		return
	end
	local plan, problem = Restock.parse(argument)
	if not plan then
		tell(problem or "Try: /restock cakes 10")
		return
	end
	local cakes, tools = 0, 0
	for id, amount in plan.items do
		if amount > 0 then
			if Restock.isCake(id) then
				cakes += 1
			else
				tools += 1
			end
		end
	end
	AdminRestock.start(plan.items, plan.minutes * 60)
	local shops = if cakes > 0 and tools > 0
		then "The Bakery and the Workshop have"
		elseif tools > 0 then "The Workshop has"
		else "The Bakery has"
	Notify.toastAll(`Admin restock! {shops} fresh stock for {plan.minutes} min.`)
	tell(`Restocked {cakes} cakes and {tools} Workshop items for {plan.minutes} min.`)
end

local MaxAnnouncementLength = 150

-- Roblox's rules: text one player writes for others must go through the filter first.
local function filterForEveryone(author: Player, text: string): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, author.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(result) == "string" then result else nil
end

-- Always the admin who ran it (it's untargeted), so the filter checks it as theirs.
commands["/announce"] = function(player, argument, tell)
	local text = string.match(argument or "", "^%s*(.-)%s*$") or ""
	if text == "" then
		tell("Try: /announce Double money weekend starts now!")
		return
	end
	if #text > MaxAnnouncementLength then
		tell(`Keep it under {MaxAnnouncementLength} letters.`)
		return
	end
	local filtered = filterForEveryone(player, text)
	if not filtered then
		tell("Roblox's text filter didn't answer. Try again in a moment.")
		return
	end
	Notify.announceAll(filtered)
end

local MaxArgumentLength = 60
-- These take a long argument: a restock lists every item it puts in, an announcement is a
-- sentence, a given monster can have many effects.
local longArguments: { [string]: number } = {
	["/restock"] = 1200,
	["/announce"] = MaxAnnouncementLength * 2,
	["/givemonster"] = 600,
	["/addeffect"] = 600,
}

-- Commands that act on the whole server or only ever on yourself: a picked player is ignored.
local untargeted: { [string]: boolean } = {
	["/summon"] = true,
	["/event"] = true,
	["/stopevent"] = true,
	["/ghost"] = true,
	["/restock"] = true,
	["/announce"] = true,
}

-- Runs one command for an admin, on `target` (another player in the server) or on the admin.
-- Anything else (not an admin, unknown command, odd argument) is ignored.
local function runCommand(admin: Player, name: string, argument: string?, target: Player?)
	local key = string.lower(name)
	local command = commands[key]
	if not command or not Admins.isAdmin(admin) then
		return
	end
	if argument and (argument == "" or #argument > (longArguments[key] or MaxArgumentLength)) then
		argument = nil
	end
	-- A picked player who left: nothing happens (never falls back to the admin, so a Reset save
	-- meant for them can't wipe the admin's own).
	if target and target.Parent ~= Players and not untargeted[key] then
		Notify.toast(admin, "That player left the server.")
		return
	end
	local who = if target and not untargeted[key] then target else admin
	local function tell(text: string)
		Notify.toast(admin, if who ~= admin then `{who.DisplayName}: {text}` else text)
	end
	local ok, err = pcall(command, who, argument, tell, admin)
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
	if string.lower(name) == "/addeffect" then
		if Admins.isAdmin(admin) then
			Notify.toast(admin, "Add effect works on one player's monster: pick that player.")
		end
		return
	end
	if string.lower(name) == "/reset" then
		if Admins.isAdmin(admin) then
			Notify.toast(admin, "Reset save works on one player at a time: pick them.")
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
		-- A whole number: GetPlayerByUserId errors on NaN, infinity and fractions. A broken
		-- one is ignored, not run on the admin themselves.
		if type(targetId) == "number" and not (targetId % 1 == 0 and math.abs(targetId) < 2 ^ 53) then
			return
		end
		local target = if type(targetId) == "number" then Players:GetPlayerByUserId(targetId) else nil
		if type(targetId) == "number" and not target then
			if Admins.isAdmin(player) then
				Notify.toast(player, "That player left the server.")
			end
			return
		end
		runCommand(player, name, text, target)
	end)
	remote.Parent = remotes

	-- The admin panel's "Add effect" list: one player's monsters (mansion, then Storage).
	-- Empty for anyone who isn't an admin, or for a player who isn't in the server.
	local monsterList = Instance.new("RemoteFunction")
	monsterList.Name = "AdminMonsters"
	monsterList.OnServerInvoke = function(
		player: Player,
		targetId: unknown
	): { { uid: string, label: string, effects: { string } } }
		if not Admins.isAdmin(player) then
			return {}
		end
		local target: Player? = player
		if
			type(targetId) == "number"
			and targetId % 1 == 0
			and math.abs(targetId) < 2 ^ 53
			and targetId > 0
		then
			target = Players:GetPlayerByUserId(targetId)
		end
		local data = if target then DataService.get(target) else nil
		local rows: { { uid: string, label: string, effects: { string } } } = {}
		if not data then
			return rows
		end
		for _, list in { data.monsters, data.storage } do
			local stored = list == data.storage
			for _, caught in list do
				if typeof(caught.uid) == "string" and Monsters[caught.monsterId] then
					local names: { string } = {}
					for _, id in Value.resolveEffects(caught.effects) do
						table.insert(names, Format.name(id))
					end
					local effects = if #names > 0 then ` · {table.concat(names, ", ")}` else ""
					local kg = if typeof(caught.kg) == "number" then ` {Weight.text(caught.kg)}` else ""
					local where = if stored then " (Storage)" else ""
					table.insert(rows, {
						uid = caught.uid,
						label = `{lookName(caught)}{kg}{effects}{where}`,
						effects = table.clone(caught.effects),
					})
				end
			end
		end
		return rows
	end
	monsterList.Parent = remotes
end

-- Marks admins so their client shows the panel (the server checks again on every command).
local function markAdmins()
	local function mark(player: Player)
		player:SetAttribute("Admin", if Admins.isAdmin(player) then true else nil)
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
	-- The Studio "test as a player" switch (Admins.luau) can be flipped during a play test.
	workspace:GetAttributeChangedSignal("TestAsPlayer"):Connect(function()
		for _, player in Players:GetPlayers() do
			mark(player)
		end
	end)
	if Admins.testingAsPlayer() then
		warn("Admins: TestAsPlayer is on, so nobody is an admin in this Studio test (untick it on Workspace)")
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
		`DevService (admins, F2 opens the panel): /money <amount>, /wings <1-{MaxWings}>, /clearmonsters, /tutorial skip|restart, /reset confirm, /give <item> [count], /summon, /event <name> [set], /stopevent, /skip <hours>, /haunt, /charges, /chamber, /missions done|new|reset|set <id>|streak <days>, /calm, /attacks on|off, /respawn, /attack, /restock <items amounts>|end, /announce <text>, /givemonster <monster> [size] [variant] [kg] [effects], /addeffect <uid> <effects>`
	)
end

return DevService
