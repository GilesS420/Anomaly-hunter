--!strict
-- Studio-only checks of the live game, run while play testing (Play, F5). In the Test tab
-- switch the view to Server, then paste this into the command bar (Window > Command Bar):
--
--   game.ServerScriptService.Server.Tests.RunChecks:Fire()
--
-- Before the client's ExploitChecks, give everyone test monsters and money (Studio saves
-- start empty unless the place has API access):
--
--   game.ServerScriptService.Server.Tests.Setup:Fire()
--
-- Results print in Window > Output: a PASS line per check, FAIL lines in orange, and a summary.
-- It checks the admin rules, that every remote is the one the tests know about, the money
-- guard, every player's save for broken or duplicated monsters and items, that the shared
-- rules turn away junk input, and lists every server error since the play test started (run
-- the client's ExploitChecks first, then this, to see if any bad request broke a remote).
--
-- The command bar has its own copy of every module, without the live saves, so it can't
-- run these itself: init.server.luau calls listen() in Studio, and RunChecks is the
-- BindableEvent it makes here. Nothing here runs in a live server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Cakes = require(ReplicatedStorage.Shared.Util.Cakes)
local Catching = require(ReplicatedStorage.Shared.Util.Catching)
local HotbarLayout = require(ReplicatedStorage.Shared.Util.HotbarLayout)
local RobuxConfig = require(ReplicatedStorage.Shared.Config.Robux)
local Mansion = require(ReplicatedStorage.Shared.Util.Mansion)
local Merge = require(ReplicatedStorage.Shared.Util.Merge)
local Missions = require(ReplicatedStorage.Shared.Util.Missions)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Nickname = require(ReplicatedStorage.Shared.Util.Nickname)
local Settings = require(ReplicatedStorage.Shared.Util.Settings)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Wings = require(ReplicatedStorage.Shared.Config.Wings)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local Admins = require(script.Parent.Parent.Admins)
local DataService = require(script.Parent.Parent.Services.DataService)
local Perks = require(script.Parent.Parent.Perks)
local MansionService = require(script.Parent.Parent.Services.MansionService)
local TutorialService = require(script.Parent.Parent.Services.TutorialService)

local ServerChecks = {}

-- Every remote the game makes, by "Folder.Name". The client's ExploitChecks fires all of the
-- client -> server ones with bad data. A remote that isn't listed here fails the check, so
-- a new one gets added to both lists (and gets tested) when it's made.
ServerChecks.KnownRemotes = {
	"Remotes.Toast",
	"Remotes.MutationLog",
	"Remotes.AdminCommand",
	"Remotes.AdminMonsters",
	"Remotes.Announcement",
	"Remotes.AwayBook",
	"StandRemotes.Talk",
	"StandRemotes.Enter",
	"CollectorRemotes.Open",
	"CollectorRemotes.GetList",
	"CollectorRemotes.Sell",
	"BakeryRemotes.Open",
	"BakeryRemotes.GetShop",
	"BakeryRemotes.Buy",
	"WorkshopRemotes.Open",
	"WorkshopRemotes.GetShop",
	"WorkshopRemotes.Buy",
	"WorkshopRemotes.Equip",
	"MergerRemotes.Open",
	"MergerRemotes.GetList",
	"MergerRemotes.Preview",
	"MergerRemotes.Merge",
	"MergerRemotes.OpenVariant",
	"MergerRemotes.Pull",
	"TradeRemotes.Open",
	"TradeRemotes.Nearby",
	"TradeRemotes.Request",
	"TradeRemotes.Invite",
	"TradeRemotes.Answer",
	"TradeRemotes.Offer",
	"TradeRemotes.Ready",
	"TradeRemotes.Cancel",
	"TradeRemotes.State",
	"TradeRemotes.Gift",
	"GrowthRemotes.Open",
	"GrowthRemotes.GetList",
	"GrowthRemotes.Grow",
	"GrowthRemotes.PickUp",
	"MissionRemotes.GetView",
	"MissionRemotes.Claim",
	"MissionRemotes.Reroll",
	"MissionRemotes.Changed",
	"InventoryRemotes.GetView",
	"InventoryRemotes.Move",
	"InventoryRemotes.Lock",
	"InventoryRemotes.Equip",
	"InventoryRemotes.Rename",
	"CatchRemotes.StartCatch",
	"CatchRemotes.StopCatch",
	"CatchRemotes.Strike",
	"CatchRemotes.State",
	"SlapRemotes.Slap",
	"SlapRemotes.Slapped",
	"HuntRemotes.UseReturnCharm",
	"HuntRemotes.UseBaitBell",
	"TravelRemotes.FastTravel",
	"HotbarRemotes.Set",
	"SettingsRemotes.Set",
	"TutorialRemotes.Finish",
	"GoldenGhostRemotes.Tap",
	"GoldenGhostRemotes.Progress",
	"CodexRemotes.GetView",
	"AttackRemotes.Warn",
	"AttackRemotes.Hit",
	"RobuxRemotes.Buy",
	"RobuxRemotes.Granted",
}

local passed = 0
local failed: { string } = {}
local warned: { string } = {}

local function pass(text: string)
	passed += 1
	print(`  PASS  {text}`)
end

local function fail(text: string)
	table.insert(failed, text)
	warn(`  FAIL  {text}`)
end

local function note(text: string)
	table.insert(warned, text)
	print(`  NOTE  {text}`)
end

local function check(ok: boolean, text: string, why: string?)
	if ok then
		pass(text)
	else
		fail(if why then `{text}: {why}` else text)
	end
end

-- Server errors since listen() (a remote handler that broke on bad input shows up here).
local errors: { string } = {}

local function isFinite(n: unknown): boolean
	return typeof(n) == "number" and n == n and math.abs(n) ~= math.huge
end

------------------------------------------------------------------------------------------

local function checkAdmins()
	print("Admins")
	local players = Players:GetPlayers()
	local testing = Admins.testingAsPlayer()
	for _, player in players do
		local admin = Admins.isAdmin(player)
		check(
			admin == not testing,
			`{player.Name} is {if admin then "an admin" else "a normal player"}`,
			if testing
				then "TestAsPlayer is on, so nobody should be an admin"
				else "everyone is an admin in Studio"
		)
		check(
			(player:GetAttribute("Admin") == true) == admin,
			`{player.Name}'s Admin attribute matches the server`
		)
	end
	-- Flip the switch for a moment and put it back.
	workspace:SetAttribute("TestAsPlayer", not testing)
	for _, player in players do
		check(Admins.isAdmin(player) == testing, `TestAsPlayer switch works for {player.Name}`)
	end
	workspace:SetAttribute("TestAsPlayer", if testing then true else nil)
	if not testing then
		note(
			"To test as a normal player: Workspace > Properties > Attributes > + > TestAsPlayer (Boolean), tick it, then press Play"
		)
	end
	local remote = ReplicatedStorage:FindFirstChild("Remotes")
	remote = remote and remote:FindFirstChild("AdminCommand")
	check(remote ~= nil and remote:IsA("RemoteEvent"), "the admin panel's remote exists")
	local list = ReplicatedStorage:FindFirstChild("Remotes")
	list = list and list:FindFirstChild("AdminMonsters")
	check(list ~= nil and list:IsA("RemoteFunction"), "the admin panel's monster list exists")
end

local function checkRemotes()
	print("Remotes")
	local known: { [string]: boolean } = {}
	for _, path in ServerChecks.KnownRemotes do
		known[path] = true
	end
	local found: { [string]: boolean } = {}
	for _, instance in ReplicatedStorage:GetDescendants() do
		local remote = instance:IsA("RemoteEvent")
			or instance:IsA("RemoteFunction")
			or instance:IsA("UnreliableRemoteEvent")
		-- Roblox's old chat keeps its own remotes in ReplicatedStorage.
		if remote and not instance:FindFirstAncestor("DefaultChatSystemChatEvents") then
			local parent = instance.Parent :: Instance
			local path = `{parent.Name}.{instance.Name}`
			found[path] = true
			if not known[path] then
				fail(
					`new remote {path}: add it to ServerChecks.KnownRemotes and to the client's ExploitChecks`
				)
			end
		end
	end
	local missing = {}
	for path in known do
		if not found[path] then
			table.insert(missing, path)
		end
	end
	check(#missing == 0, "every known remote exists", `missing {table.concat(missing, ", ")}`)
end

local function checkMoneyGuard(player: Player)
	local data = DataService.get(player)
	if not data then
		note(`{player.Name}'s save isn't loaded yet; skipped the money guard`)
		return
	end
	print(`Money guard ({player.Name})`)
	local before = data.money
	check(not DataService.addMoney(player, 0 / 0), "adding NaN money is refused")
	check(not DataService.addMoney(player, math.huge), "adding infinite money is refused")
	check(not DataService.addMoney(player, -math.huge), "taking infinite money is refused")
	-- Twice the balance (plus one): before + 1 rounds back to before on a huge balance.
	check(not DataService.addMoney(player, -(before * 2 + 1)), "spending more than you have is refused")
	check(data.money == before, "money didn't change", `was {before}, now {data.money}`)
	local leaderstats = player:FindFirstChild("leaderstats")
	local shown = leaderstats and leaderstats:FindFirstChild("Money")
	check(
		shown ~= nil and shown:IsA("NumberValue") and shown.Value == data.money,
		"the Money shown in the player list matches the save"
	)
end

local function checkSave(player: Player)
	local data = DataService.get(player)
	if not data then
		note(`{player.Name}'s save isn't loaded yet; skipped`)
		return
	end
	print(`Save ({player.Name})`)
	check(
		isFinite(data.money) and data.money >= 0,
		"money is a real number, not below 0",
		tostring(data.money)
	)
	check(
		typeof(data.wingsOwned) == "number"
			and data.wingsOwned % 1 == 0
			and data.wingsOwned >= 1
			and data.wingsOwned <= #Wings.List,
		"wings owned is between 1 and the number of wings",
		tostring(data.wingsOwned)
	)

	-- Every monster: a known kind, a uid, and that uid in only one place (no duplicates).
	local seen: { [string]: string } = {}
	local broken, dupes = {}, {}
	local function look(where: string, caught: any)
		if typeof(caught) ~= "table" or not Monsters[caught.monsterId] then
			table.insert(broken, `{where}: {if typeof(caught) == "table" then caught.monsterId else caught}`)
			return
		end
		local uid = caught.uid
		if typeof(uid) ~= "string" or uid == "" then
			table.insert(broken, `{where}: {caught.monsterId} has no uid`)
		elseif seen[uid] then
			table.insert(dupes, `{caught.monsterId} {uid} in {seen[uid]} and {where}`)
		else
			seen[uid] = where
		end
		if caught.kg ~= nil and not (isFinite(caught.kg) and caught.kg >= 0) then
			table.insert(broken, `{where}: {caught.monsterId} weighs {caught.kg}`)
		end
	end
	for _, caught in data.monsters do
		look("mansion", caught)
	end
	for _, caught in data.storage do
		look("Backpack", caught)
	end
	for _, caught in data.vault do
		look("Vault", caught)
	end
	if data.chamber.monster then
		look("Growth Chamber", data.chamber.monster)
	end
	check(#dupes == 0, "no monster is in two places at once (no duplicates)", table.concat(dupes, "; "))
	check(
		#broken == 0,
		"every monster is a known kind with a uid and a real weight",
		table.concat(broken, "; ")
	)

	local capacity = Mansion.capacity(data.wingsOwned)
	if #data.monsters > capacity then
		note(
			`{#data.monsters} monsters in a mansion that holds {capacity} (fine after /wings, odd otherwise)`
		)
	else
		pass(`mansion holds {#data.monsters}/{capacity}`)
	end
	local slots = Perks.storageSlots(player) -- more with the Big Storage pass
	check(#data.storage <= slots, `Backpack holds {#data.storage}/{slots}`)
	check(#data.vault <= Wings.VaultSlots, `Vault holds {#data.vault}/{Wings.VaultSlots}`)
	local robux = data.robux
	check(
		typeof(robux) == "table"
			and typeof(robux.receipts) == "table"
			and #robux.receipts <= RobuxConfig.ReceiptsKept,
		`Robux record is sound ({if typeof(robux) == "table" then #robux.receipts else 0} receipts kept)`
	)
	local heist = data.heist
	check(
		typeof(heist) == "table" and heist.playSeconds >= 0 and heist.lost >= 0,
		`Steal record is sound ({if typeof(heist) == "table" then heist.lostTotal else "?"} lost in all)`
	)
	local cakeLimit = Cakes.limit(data.wingsOwned, Perks.cakesPerWing(player))
	if #data.cakes > cakeLimit then
		note(`{#data.cakes} cakes out with room for {cakeLimit} (fine after /wings, odd otherwise)`)
	else
		pass(`cakes out {#data.cakes}/{cakeLimit}`)
	end

	-- Items: whole numbers above 0, and only things the shops sell.
	local badCounts, unknown = {}, {}
	for id, count in data.inventory do
		if not (isFinite(count) and count > 0 and count % 1 == 0) then
			table.insert(badCounts, `{id} = {count}`)
		end
		if not Workshop.item(id) and not Cakes.item(id) and Shop.Retired[id] == nil then
			table.insert(unknown, id)
		end
	end
	check(#badCounts == 0, "every item count is a whole number above 0", table.concat(badCounts, ", "))
	check(#unknown == 0, "every item is one the shops sell", table.concat(unknown, ", "))
	local vacuum = Workshop.item(data.equipped.vacuum)
	check(
		vacuum ~= nil and Workshop.owns(data.inventory, vacuum),
		"the vacuum in use is one you own",
		tostring(data.equipped.vacuum)
	)
end

local function checkRules()
	print("Rules turn away junk")
	local now = 1000
	check(Catching.tapTime(0 / 0, now) == now, "a NaN tap time counts as 'now'")
	check(Catching.tapTime(math.huge, now) == now, "a tap time in the far future counts as 'now'")
	check(Catching.tapTime(now - 60, now) == now, "a tap time a minute ago counts as 'now'")
	check(Catching.tapTime("soon", now) == now, "a tap time that isn't a number counts as 'now'")
	check(Nickname.clean(string.rep("A", 500)) == nil, "a 500 letter name is refused")
	check(Nickname.clean("\255\254") == nil, "a name that isn't valid text is refused")
	local cleaned = Nickname.clean("Bob\n\tthe\0Great")
	check(cleaned ~= nil and not string.find(cleaned, "%c"), "control characters are stripped from names")
	local junkSlots = {}
	for i = 1, 500 do
		junkSlots[`key{i}`] = i
	end
	local layout = HotbarLayout.clean({ slots = junkSlots, benched = table.create(500, "x") })
	local count = 0
	for _ in layout.slots do
		count += 1
	end
	check(
		count <= HotbarLayout.Slots and #layout.benched <= HotbarLayout.MaxBenched,
		"a giant hotbar layout is cut down to size"
	)
	check(
		not Settings.valid("music", 0 / 0) and not Settings.valid("NoSuchSetting", true),
		"junk settings are refused"
	)
	local monsterId = next(Monsters) :: string
	local one = { uid = "a", monsterId = monsterId, size = "Normal", effects = {}, familiarity = 0 }
	check(Merge.problem(one, one) == "Same", "merging a monster with itself is refused")
	check(Merge.problem(one, table.clone(one)) == "Same", "merging two copies with the same uid is refused")
	check(
		Workshop.canBuy(nil, 0, math.huge, {}, 0) == "Unknown",
		"buying an item that doesn't exist is refused"
	)
	local priciest: Shop.Item? = nil
	for _, item in Shop.Workshop do
		if not priciest or item.price > priciest.price then
			priciest = item
		end
	end
	if priciest then
		local result = Workshop.canBuy(priciest, 0, priciest.price - 1, {}, 0)
		check(result ~= "Ok", `buying the {priciest.name} with $1 too little is refused`, result)
	end
	local state = { list = {}, rerolls = 0 } :: any
	check(Missions.claim(state, 1, now) == nil, "claiming a mission that doesn't exist pays nothing")
	check(Missions.claimChest(state) == nil, "the chest can't be opened with no missions")
end

local function checkErrors()
	print("Server errors since the play test started")
	if #errors == 0 then
		pass("no server errors")
		return
	end
	for _, text in errors do
		fail(text)
	end
end

function ServerChecks.run()
	passed = 0
	failed = {}
	warned = {}
	print("========== Anomaly Hunter server checks ==========")
	local steps: { { name: string, run: () -> () } } = {
		{ name = "admins", run = checkAdmins },
		{ name = "remotes", run = checkRemotes },
		{ name = "rules", run = checkRules },
	}
	for _, player in Players:GetPlayers() do
		table.insert(steps, {
			name = `money guard {player.Name}`,
			run = function()
				checkMoneyGuard(player)
			end,
		})
		table.insert(steps, {
			name = `save {player.Name}`,
			run = function()
				checkSave(player)
			end,
		})
	end
	table.insert(steps, { name = "errors", run = checkErrors })
	for _, step in steps do
		local ok, err = pcall(step.run)
		if not ok then
			fail(`the {step.name} check itself broke: {err}`)
		end
	end
	if #Players:GetPlayers() == 0 then
		note("nobody is in the game: press Play (F5), not Run, so there's a player to check")
	end
	print(
		`========== {passed} passed, {#failed} failed, {#warned} notes =========={if #failed == 0
			then " ALL GOOD"
			else ""}`
	)
	for _, text in failed do
		warn(`FAIL  {text}`)
	end
end

-- What the client's ExploitChecks needs: the tutorial done, $1M, two of the same cheap
-- monster and one other in the Backpack (to try merging, selling and growing them), and one
-- in the mansion (to try selling and growing one that isn't in the Backpack).
function ServerChecks.setup()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if not data then
			warn(`Setup: {player.Name}'s save isn't loaded yet, try again in a moment`)
			continue
		end
		TutorialService.skip(player)
		if data.money < 1_000_000 then
			DataService.addMoney(player, 1_000_000 - data.money)
		end
		local function give(monsterId: string, backpack: boolean)
			local caught = {
				monsterId = monsterId,
				size = "Normal",
				effects = {},
				familiarity = 0,
			}
			local where = MansionService.addMonster(player, caught)
			if where == "Mansion" and backpack and caught.uid then
				MansionService.move(player, caught.uid)
			elseif where == nil then
				warn(`Setup: no room for a {monsterId}. Sell a few first.`)
			end
		end
		give("Gloomlet", true)
		give("Gloomlet", true)
		give("Skittercrow", true)
		give("Gloomlet", false)
		print(
			`Setup: {player.Name} has the tutorial done, at least $1M and 4 test monsters (3 in the Backpack)`
		)
	end
end

function ServerChecks.listen()
	if not RunService:IsStudio() then
		return
	end
	ScriptContext.Error:Connect(function(message: string, trace: string, source: Instance?)
		if #errors < 50 then
			local where = if source then source:GetFullName() else "?"
			table.insert(errors, `{where}: {message}`)
		end
	end)
	local event = Instance.new("BindableEvent")
	event.Name = "RunChecks"
	event.Event:Connect(ServerChecks.run)
	event.Parent = script.Parent
	local setup = Instance.new("BindableEvent")
	setup.Name = "Setup"
	setup.Event:Connect(ServerChecks.setup)
	setup.Parent = script.Parent
end

return ServerChecks
