--!strict
-- The inventory: everything you own, anywhere in the game, in three sections (the client
-- draws them, InventoryController):
--   Monsters  every monster in your mansion and in Storage, most valuable first. Store one to
--             make room (it's paused there, see Util/Storage) and Lock the ones you never want
--             to sell by accident. Monsters in Storage are also Tools in the hotbar: hold one
--             and click in your mansion to place it there.
--   Cakes     how many of each cake you have. They are Tools in the hotbar too (CakeService).
--   Tools     your vacuums (equip them right here), Bait Bells and Return Charms.
-- Catches that don't fit in the mansion land in Storage by themselves (MansionService.addMonster).
--
-- The client draws each monster and cake on a card from a preview model: one per look, kept
-- in a hidden ScreenGui in the player's PlayerGui (InventoryPreviews), so only they get them.
-- Rows name their preview in `look`.
--
-- Hotbar Tools carry attributes the client sorts and groups them by: Section ("Cake" or
-- "Monster") and Order (cakes by price, monsters most valuable first). Monster Tools also
-- carry MonsterUid.
--
-- Remotes in ReplicatedStorage.InventoryRemotes:
--   GetView  client -> server () -> View?
--   Move     client -> server (uid) -> Result      mansion -> Storage, or Storage -> mansion
--   Lock     client -> server (uid) -> Result      locks or unlocks a monster
--   Equip    client -> server (itemId) -> Result   puts an owned tool into use
--   Rename   client -> server (uid, name) -> Result uses a Name Tag to name a monster ("" takes
--            the name off, free)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Cakes = require(ReplicatedStorage.Shared.Util.Cakes)
local Care = require(ReplicatedStorage.Shared.Util.Care)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.Inventory)
local Mansion = require(ReplicatedStorage.Shared.Util.Mansion)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Nickname = require(ReplicatedStorage.Shared.Util.Nickname)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Workshop = require(ReplicatedStorage.Shared.Util.Workshop)
local CakeModel = require(script.Parent.Parent.CakeModel)
local DataService = require(script.Parent.DataService)
local HuntService = require(script.Parent.HuntService)
local MansionService = require(script.Parent.MansionService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)
local RoamService = require(script.Parent.RoamService)
local ToolModel = require(script.Parent.Parent.ToolModel)
local WorkshopService = require(script.Parent.WorkshopService)

local InventoryService = {}

export type MonsterRow = {
	uid: string,
	name: string, -- "Gravepup", or "Bob the Gravepup" once named
	species: string, -- "Gravepup"
	nickname: string?, -- the name given with a Name Tag
	details: string, -- "Big Rare · Ghost · $1.2M"
	color: Color3, -- rarity colour
	value: string, -- "$1.2M"
	worth: number, -- the sell price as a number, for sorting
	rarityOrder: number, -- Config/Rarities order (Common 1, Divine 7), for sorting
	look: string, -- the preview model's name in InventoryPreviews
	stored: boolean,
	locked: boolean,
}
export type ItemRow = {
	id: string,
	name: string,
	details: string,
	tool: boolean,
	equipped: boolean,
	cake: boolean, -- a Bakery cake (the Cakes section), else the Tools section
	kind: string, -- Shop.Item kind: "Food", "Vacuum", "Lure" or "Charm"
	count: number,
	look: string?, -- cakes and Workshop items: the preview model's name in InventoryPreviews
}
export type View = {
	monsters: { MonsterRow },
	items: { ItemRow },
	mansionCount: number,
	mansionCapacity: number,
	storageCount: number,
	storageCapacity: number,
}
export type Result = { ok: boolean, message: string, view: View? }

local remotes = Instance.new("Folder")
remotes.Name = "InventoryRemotes"
local function remote(name: string): RemoteFunction
	local fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remotes
	return fn
end
local GetView = remote("GetView")
local Move = remote("Move")
local Lock = remote("Lock")
local Equip = remote("Equip")
local Rename = remote("Rename")

local kindOrder = { Vacuum = 1, Food = 2, Lure = 3, Charm = 4, Potion = 5, Tag = 6 }

local function price(caught: Value.CaughtMonster, wingsOwned: number): number
	local ok, value = pcall(Value.sellValue, caught, wingsOwned)
	return if ok then value else 0
end

-- One preview per look: the same monster with the same effects and variant looks the same.
-- The Collector's rows use it too.
function InventoryService.lookOf(caught: Value.CaughtMonster): string
	return `{caught.monsterId}|{table.concat(Value.resolveEffects(caught.effects), ",")}|{caught.variant or ""}`
end
local lookOf = InventoryService.lookOf

-- Every cake has a preview, so the Bakery can show the ones you don't have yet.
function InventoryService.cakeLook(itemId: string): string
	return `Cake|{itemId}`
end
local cakeLook = InventoryService.cakeLook

-- The Codex shows each monster you've found plainly (no effects, no variant).
function InventoryService.codexLook(monsterId: string): string
	return `Codex|{monsterId}`
end

-- The monster built at Normal size with its effects and variant, without its name label.
local function monsterLook(caught: Value.CaughtMonster, rarity: string): Model
	local model = MonsterModel.build({
		monsterId = caught.monsterId,
		rarity = rarity,
		size = "Normal",
		effects = Value.resolveEffects(caught.effects),
		variant = caught.variant,
	})
	local body = model.PrimaryPart :: BasePart
	local label = body:FindFirstChild("Label")
	if label then
		label:Destroy()
	end
	return model
end

local function monsterRow(caught: Value.CaughtMonster, stored: boolean, value: number): MonsterRow?
	local monster = Monsters[caught.monsterId]
	if not monster or not caught.uid then
		return nil
	end
	local variant = if caught.variant then `{caught.variant} ` else ""
	local parts = { `{variant}{caught.size} {monster.rarity}` }
	local effects = Value.resolveEffects(caught.effects)
	if #effects > 0 then
		local names = {}
		for _, effectId in effects do
			table.insert(names, Format.name(effectId))
		end
		table.insert(parts, table.concat(names, ", "))
	end
	table.insert(parts, Format.money(value))
	return {
		uid = caught.uid,
		name = Format.monsterName(caught),
		species = Format.name(caught.monsterId),
		nickname = caught.nickname,
		details = table.concat(parts, " · "),
		color = MonsterModel.color(monster.rarity),
		value = Format.money(value),
		worth = value,
		rarityOrder = if Rarities[monster.rarity] then Rarities[monster.rarity].order else 0,
		look = lookOf(caught),
		stored = stored,
		locked = caught.locked == true,
	}
end

local function monsterRows(data: DataService.Data): { MonsterRow }
	local rows: { MonsterRow } = {}
	local values: { [string]: number } = {}
	local now = os.time()
	local function add(caught: Value.CaughtMonster, stored: boolean)
		local value = price(caught, data.wingsOwned)
		local row = monsterRow(caught, stored, value)
		if row then
			values[row.uid] = value
			table.insert(rows, row)
		end
	end
	for _, caught in data.monsters do
		Care.settle(caught, now)
		add(caught, false)
	end
	for _, caught in data.storage do
		add(caught, true) -- paused: keeps the state it was stored with
	end
	table.sort(rows, function(a, b)
		local va, vb = values[a.uid], values[b.uid]
		return if va == vb then a.uid < b.uid else va > vb
	end)
	return rows
end

local function itemRows(data: DataService.Data): { ItemRow }
	local equipped = data.equipped :: { [string]: string }
	local rows: { ItemRow } = {}
	local order: { [string]: number } = {}
	local function add(item: Shop.Item)
		local tool: boolean = Workshop.isTool(item)
		local count = data.inventory[item.id] or 0
		if tool and not Workshop.owns(data.inventory, item) or not tool and count <= 0 then
			return
		end
		local equipSlot = Workshop.equipSlot(item)
		local details
		if item.kind == "Food" then
			details = `x{count} · {Cakes.describe(item)}`
		elseif tool then
			details = Workshop.describe(item)
		else
			details = `x{count} · {Workshop.describe(item)}`
		end
		table.insert(rows, {
			id = item.id,
			name = item.name,
			details = details,
			tool = Workshop.isTool(item),
			equipped = equipSlot ~= nil and equipped[equipSlot] == item.id,
			cake = item.kind == "Food",
			kind = item.kind :: string,
			count = count,
			look = if item.kind == "Food" then cakeLook(item.id) else ToolModel.look(item.id),
		})
		order[item.id] = (kindOrder[item.kind] or 9) * 1e15 + item.price
	end
	for _, item in Shop.Workshop do
		add(item)
	end
	for _, item in Shop.Bakery do
		add(item)
	end
	table.sort(rows, function(a, b)
		return if order[a.id] == order[b.id] then a.id < b.id else order[a.id] < order[b.id]
	end)
	return rows
end

local function viewFor(data: DataService.Data): View
	return {
		monsters = monsterRows(data),
		items = itemRows(data),
		mansionCount = #data.monsters,
		mansionCapacity = Mansion.capacity(data.wingsOwned),
		storageCount = #data.storage,
		storageCapacity = InventoryConfig.StorageSlots,
	}
end

local function find(data: DataService.Data, uid: string): Value.CaughtMonster?
	for _, list in { data.monsters, data.storage } do
		for _, caught in list do
			if caught.uid == uid then
				return caught
			end
		end
	end
	return nil
end

local Loading: Result = { ok = false, message = "Your save is still loading. Try again in a moment!" }

GetView.OnServerInvoke = function(player: Player): View?
	local data = DataService.get(player)
	return if data then viewFor(data) else nil
end

Move.OnServerInvoke = function(player: Player, uid: unknown): Result
	local data = DataService.get(player)
	if not data then
		return Loading
	end
	if typeof(uid) ~= "string" then
		return { ok = false, message = "That monster is gone.", view = viewFor(data) }
	end
	local result, caught = MansionService.move(player, uid)
	local name = if caught then Format.monsterName(caught) else "That monster"
	local message
	if result == "Ok" then
		message = if caught and caught.storedAt
			then `Picked up {name}. It's paused in your inventory until you place it back.`
			else `{name} is back in your mansion!`
	elseif result == "MansionFull" then
		message = "Your mansion is full. Store or sell a monster first, or buy a new wing."
	elseif result == "StorageFull" then
		message = `Storage is full ({InventoryConfig.StorageSlots}). Sell some at the Collector first.`
	else
		message = "That monster is gone."
	end
	if result ~= "Ok" then
		Notify.toast(player, message) -- E in the mansion has no window to show it in
	end
	return { ok = result == "Ok", message = message, view = viewFor(data) }
end

Lock.OnServerInvoke = function(player: Player, uid: unknown): Result
	local data = DataService.get(player)
	if not data then
		return Loading
	end
	local caught = if typeof(uid) == "string" then find(data, uid) else nil
	if not caught then
		return { ok = false, message = "That monster is gone.", view = viewFor(data) }
	end
	caught.locked = if caught.locked then nil else true
	local name = Format.monsterName(caught)
	local message = if caught.locked
		then `Locked {name}. The Collector won't sell it.`
		else `Unlocked {name}.`
	return { ok = true, message = message, view = viewFor(data) }
end

-- Roblox's filter for text other players see (names show over monsters in the mansion).
-- nil when the filter can't be reached; then nothing is saved.
local function filtered(player: Player, text: string): string?
	local ok, result = pcall(function()
		local filter = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filter:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and typeof(result) == "string" then result else nil
end

local renaming: { [Player]: boolean } = {}

Rename.OnServerInvoke = function(player: Player, uid: unknown, text: unknown): Result
	local data = DataService.get(player)
	if not data then
		return Loading
	end
	local caught = if typeof(uid) == "string" then find(data, uid) else nil
	if not caught then
		return { ok = false, message = "That monster is gone.", view = viewFor(data) }
	end
	local name = if typeof(text) == "string" then Nickname.clean(text) else nil
	if not name then
		return {
			ok = false,
			message = `A name can be up to {Nickname.MaxLength} letters.`,
			view = viewFor(data),
		}
	end
	if name == "" then
		local had = caught.nickname ~= nil
		caught.nickname = nil
		MansionService.refreshMonsters(player)
		local message = if had
			then `Took the name off your {Format.name(caught.monsterId)}.`
			else "It has no name."
		return { ok = had, message = message, view = viewFor(data) }
	end
	if (data.inventory.NameTag or 0) <= 0 then
		return { ok = false, message = "You need a Name Tag from the Workshop.", view = viewFor(data) }
	end
	if renaming[player] then
		return { ok = false, message = "One moment...", view = viewFor(data) }
	end
	renaming[player] = true
	local clean = filtered(player, name) -- yields
	renaming[player] = nil
	if not clean then
		return {
			ok = false,
			message = "Couldn't check that name. Try again in a moment.",
			view = viewFor(data),
		}
	end
	-- The filter yields: make sure the tag and the monster are still there.
	local count = data.inventory.NameTag or 0
	if count <= 0 or find(data, caught.uid or "") ~= caught then
		return { ok = false, message = "That monster is gone.", view = viewFor(data) }
	end
	local inventory: { [string]: number? } = data.inventory
	inventory.NameTag = if count <= 1 then nil else count - 1
	caught.nickname = clean
	MansionService.refreshMonsters(player) -- the monster's hotbar Tool follows within a second
	HuntService.refreshItems(player) -- the Name Tag count in the hotbar
	return { ok = true, message = `Say hi to {Format.monsterName(caught)}!`, view = viewFor(data) }
end

Equip.OnServerInvoke = function(player: Player, itemId: unknown): Result
	local data = DataService.get(player)
	if not data then
		return Loading
	end
	local ok, message = WorkshopService.equip(data, itemId)
	HuntService.refreshItems(player) -- the bag size follows the vacuum
	return { ok = ok, message = message, view = viewFor(data) }
end

-- Monsters in Storage as hotbar Tools ------------------------------------------------------

local PlaceAhead = 4 -- studs in front of you
local HeldSize = 3 -- studs, the longest side of a carried monster whatever its real size
local SyncSeconds = 1
local placing: { [Player]: boolean } = {}

-- A small copy of the monster, carried over your head (every client raises the carrier's
-- arms, CarryController). The Tool has no
-- Handle (so Roblox doesn't put it in one hand with its own hold pose): the copy is welded on
-- top of your head when you take it out, and unwelded when you put it away.
local function monsterTool(player: Player, caught: Value.CaughtMonster, rarity: string): Tool
	local tool = Instance.new("Tool")
	tool.CanBeDropped = false
	tool.RequiresHandle = false
	tool.ToolTip = "Click in your mansion to place it there"
	tool:SetAttribute("Section", "Monster")
	tool:SetAttribute("MonsterUid", caught.uid)
	local model = monsterLook(caught, rarity)
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * HeldSize / math.max(size.X, size.Y, size.Z))
	local box, boxSize = model:GetBoundingBox()
	local body = model.PrimaryPart :: BasePart
	-- where the body sits relative to the bottom middle of the copy
	local fromBottom = (box * CFrame.new(0, -boxSize.Y / 2, 0)):ToObjectSpace(body.CFrame)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			child.CanCollide = false
			child.CanQuery = false
			child.CanTouch = false
		end
		child.Parent = tool
	end
	model:Destroy()

	-- Carried while the Tool is on your character, whichever way it got there (hotbar, Backpack
	-- window, respawn). A Weld with its offset written out, not a WeldConstraint: that one
	-- keeps wherever the parts happen to be, which differs between server and client.
	local weld: Weld? = nil
	local carrier: Model? = nil
	local function drop()
		if weld then
			weld:Destroy()
			weld = nil
		end
		carrier = nil
	end
	local function carry()
		local character = tool.Parent
		local head = if character then character:FindFirstChild("Head") else nil
		if
			not character
			or not character:IsA("Model")
			or not character:FindFirstChildOfClass("Humanoid")
			or not head
			or not head:IsA("BasePart")
		then
			drop()
			return
		end
		if carrier == character then
			return
		end
		drop()
		carrier = character
		local joint = Instance.new("Weld")
		joint.Name = "CarryWeld"
		joint.Part0 = head
		joint.Part1 = body
		-- the copy's bottom just above the head, facing where you face
		joint.C0 = CFrame.new(0, head.Size.Y / 2 + 0.6, 0) * fromBottom
		joint.Parent = body
		weld = joint
	end
	tool.AncestryChanged:Connect(carry)
	tool.Destroying:Connect(drop)
	tool.Activated:Connect(function()
		InventoryService.place(player, caught.uid or "")
	end)
	return tool
end

-- Makes the hotbar's monster Tools match Storage: one per stored monster, named and ordered
-- by value. Called every second, so catches, sales and moves all show up by themselves.
function InventoryService.syncMonsterTools(player: Player)
	local data = DataService.get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	local stored: { [string]: Value.CaughtMonster } = {}
	for _, caught in data.storage do
		if caught.uid then
			stored[caught.uid] = caught
		end
	end
	local have: { [string]: Tool } = {}
	local containers: { Instance } = { backpack }
	if player.Character then
		table.insert(containers, player.Character)
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			local uid = child:GetAttribute("MonsterUid")
			if child:IsA("Tool") and typeof(uid) == "string" then
				if not stored[uid] or have[uid] then
					child:Destroy()
				else
					have[uid] = child
				end
			end
		end
	end
	for uid, caught in stored do
		local monster = Monsters[caught.monsterId]
		if monster then
			local tool = have[uid] or monsterTool(player, caught, monster.rarity)
			local variant = if caught.variant then `{caught.variant} ` else ""
			tool.Name = if caught.nickname
				then Format.monsterName(caught)
				else `{variant}{caught.size} {Format.name(caught.monsterId)}`
			tool:SetAttribute("Order", -price(caught, data.wingsOwned))
			if not tool.Parent then
				tool.Parent = backpack
			end
		end
	end
end

local function tryPlace(player: Player, uid: string): string
	local data = DataService.get(player)
	if not data then
		return Loading.message
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local spot = if root and root:IsA("BasePart")
		then MansionService.floorSpot(player, root.Position + root.CFrame.LookVector * PlaceAhead, 3)
		else nil
	if not spot then
		return "Stand inside your mansion to place it."
	end
	local result, caught = MansionService.move(player, uid)
	local name = if caught then Format.monsterName(caught) else "That monster"
	if result == "MansionFull" then
		return "Your mansion is full. Store or sell a monster first, or buy a new wing."
	elseif result ~= "Ok" then
		return "That monster is gone."
	end
	-- It appears at a free spot; walk it over to where you clicked.
	task.delay(0.5, function()
		local model = MansionService.monsterModels(player)[uid]
		if model then
			RoamService.teleport(model, spot.X, spot.Z, 2)
		end
	end)
	return `{name} is back in your mansion!`
end

-- Places a stored monster in the mansion, in front of the player (they clicked with it).
function InventoryService.place(player: Player, uid: string)
	if placing[player] then
		return
	end
	placing[player] = true
	local ok, message = pcall(tryPlace, player, uid)
	placing[player] = nil
	if ok then
		Notify.toast(player, message)
		InventoryService.syncMonsterTools(player)
	else
		warn(`InventoryService: placing a monster failed: {message}`)
	end
end

-- Keeps the player's hidden preview models in step with what they own: one per monster look,
-- one per Bakery cake, one per Workshop item and one per monster in their Codex. Built once each, removed when nothing uses them any more.
function InventoryService.syncPreviews(player: Player)
	local data = DataService.get(player)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not data or not playerGui then
		return
	end
	local holder = playerGui:FindFirstChild("InventoryPreviews") :: ScreenGui?
	if not holder then
		local gui = Instance.new("ScreenGui")
		gui.Name = "InventoryPreviews"
		gui.Enabled = false
		gui.ResetOnSpawn = false
		gui.Parent = playerGui
		holder = gui
	end
	local folder = holder :: ScreenGui
	local wanted: { [string]: () -> Model } = {}
	for _, list in { data.monsters, data.storage } do
		for _, caught in list do
			local monster = Monsters[caught.monsterId]
			local key = lookOf(caught)
			if monster and not wanted[key] then
				wanted[key] = function()
					return monsterLook(caught, monster.rarity)
				end
			end
		end
	end
	local found = data.codex.monsters
	if typeof(found) == "table" then
		for monsterId in found do
			local monster = Monsters[monsterId]
			if monster then
				local plain: Value.CaughtMonster =
					{ monsterId = monsterId, size = "Normal", effects = {}, familiarity = 0 }
				wanted[InventoryService.codexLook(monsterId)] = function()
					return monsterLook(plain, monster.rarity)
				end
			end
		end
	end
	for _, item in Shop.Bakery do
		wanted[cakeLook(item.id)] = function()
			return CakeModel.build(item.id, 1)
		end
	end
	for _, item in Shop.Workshop do
		local look = ToolModel.look(item.id)
		if look then
			wanted[look] = function()
				return ToolModel.preview(item.id) :: Model
			end
		end
	end
	for _, child in folder:GetChildren() do
		if not wanted[child.Name] then
			child:Destroy()
		end
	end
	for key, build in wanted do
		if not folder:FindFirstChild(key) then
			local model = build()
			model.Name = key
			model.Parent = folder
		end
	end
end

function InventoryService.start()
	remotes.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player)
		placing[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(SyncSeconds)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					InventoryService.syncMonsterTools(player)
					InventoryService.syncPreviews(player)
				end)
				if not ok then
					warn(`InventoryService: syncing {player.Name}'s monster tools failed: {err}`)
				end
			end
		end
	end)
end

return InventoryService
