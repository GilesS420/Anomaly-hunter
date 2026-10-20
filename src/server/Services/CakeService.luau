--!strict
-- Cakes (rules in Util/Cakes, numbers and looks in Config/Cakes). Every cake you own sits in
-- the Roblox hotbar as a Tool, one slot per kind ("Fang Fudge x3"). Hold one and click while
-- standing in one of your wings to set it out on the floor in front of you. Every
-- Config/Cakes.CheckSeconds each cake rolls for a bite; on a hit a monster within the cake's
-- reach walks over, eats, and may get a mutation. A cake is gone after its bites or when it goes stale.
--
-- Cakes are saved (DataService.Data.cakes) and keep going while you're offline: when you come
-- back, Util/Cakes.catchUp plays back the missed checks with the same odds and you get a
-- summary of what happened.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CakeConfig = require(ReplicatedStorage.Shared.Config.Cakes)
local Cakes = require(ReplicatedStorage.Shared.Util.Cakes)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local CakeModel = require(script.Parent.Parent.CakeModel)
local CareService = require(script.Parent.CareService)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)
local PlotService = require(script.Parent.PlotService)
local RoamService = require(script.Parent.RoamService)
local Notify = require(script.Parent.Parent.Notify)

local CakeService = {}

-- A saved cake while its owner is in the game: the model on the floor and who's walking over.
type Live = {
	saved: Cakes.Placed,
	item: Shop.Item,
	model: Model,
	label: TextLabel,
	at: Vector3, -- floor point under the cake, in the world
	coming: string?, -- uid of the monster walking over right now
}

local CakeRadius = 1.6 -- studs, matches CakeModel
local EdgeMargin = 3 -- keeps a cake off the wing edges
local PlaceAhead = 3 -- studs in front of you
local MaxWalkSeconds = 12 -- a monster hurries if the cake is far away
local EatSeconds = 3 -- it stays at the cake this long
local SummaryDelay = 6 -- seconds after joining before the "while you were away" message

local live: { [Player]: { Live } } = {}
local restored: { [Player]: boolean } = {}
local placing: { [Player]: boolean } = {}
local random = Random.new()
local folder: Folder? = nil

local function cakesFolder(): Folder
	if not folder then
		local made = Instance.new("Folder")
		made.Name = "Cakes"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

-- "Fang Fudge / 2 bites left / 12:34 left"
local function labelText(cake: Live): string
	local left = cake.saved.bitesLeft
	local seconds = math.max(0, Cakes.expiresAt(cake.saved) - os.time())
	local timer = string.format("%d:%02d left", seconds // 60, seconds % 60)
	return `{cake.item.name}\n{if left == 1 then "1 bite left" else `{left} bites left`}\n{timer}`
end

-- Puts a saved cake on the floor. Nil if its plot or item is gone.
local function show(player: Player, saved: Cakes.Placed): Live?
	local plot = PlotService.get(player)
	local item = Cakes.item(saved.itemId)
	if not plot or not item then
		return nil
	end
	local at = plot.frame:PointToWorldSpace(Vector3.new(saved.x, saved.y, saved.z))
	local model = CakeModel.build(item.id, 1)
	model.Name = `Cake_{item.id}`
	model:PivotTo(CFrame.new(at))
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("Reach", Cakes.reach(item.id)) -- the client draws this circle on hover

	-- Invisible, so the mouse (or a tap) can find the cake: the cake parts ignore rays.
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Shape = Enum.PartType.Cylinder
	hitbox.Size = Vector3.new(4, CakeRadius * 2 + 1, CakeRadius * 2 + 1)
	hitbox.CFrame = CFrame.new(at + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	local plate = model.PrimaryPart :: BasePart
	billboard.Adornee = plate
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(180, 64)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 240)
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard
	billboard.Parent = plate

	local cake: Live = { saved = saved, item = item, model = model, label = label, at = at }
	label.Text = labelText(cake)
	model.Parent = cakesFolder()
	local list = live[player] or {}
	table.insert(list, cake)
	live[player] = list
	return cake
end

-- Takes a cake away, from the floor and from the save.
local function remove(player: Player, cake: Live)
	local list = live[player]
	local index = if list then table.find(list, cake) else nil
	if list and index then
		table.remove(list, index)
	end
	local data = DataService.get(player)
	local savedIndex = if data then table.find(data.cakes, cake.saved) else nil
	if data and savedIndex then
		table.remove(data.cakes, savedIndex)
	end
	cake.model:Destroy()
end

-- Makes the hotbar match the cakes the player owns: one Tool per kind, named with the count.
function CakeService.syncTools(player: Player)
	local data = DataService.get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	local have: { [string]: Tool } = {}
	local containers: { Instance } = { backpack }
	if player.Character then
		table.insert(containers, player.Character)
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			local id = child:GetAttribute("CakeId")
			if child:IsA("Tool") and typeof(id) == "string" then
				local count = data.inventory[id] or 0
				if count <= 0 or have[id] then
					child:Destroy()
				else
					have[id] = child
					local item = Cakes.item(id)
					child.Name = `{if item then item.name else id} x{count}`
				end
			end
		end
	end
	for _, item in Shop.Bakery do
		local count = data.inventory[item.id] or 0
		if count > 0 and not have[item.id] then
			local tool = CakeModel.tool(item.id, `{item.name} x{count}`)
			tool:SetAttribute("Section", "Cake")
			tool:SetAttribute("Order", item.price)
			tool.Activated:Connect(function()
				CakeService.place(player, item.id)
			end)
			tool.Parent = backpack
		end
	end
end

local function tryPlace(player: Player, itemId: string): (boolean, string)
	local data = DataService.get(player)
	local item = Cakes.item(itemId)
	local plot = PlotService.get(player)
	if not data or not item or not plot or not restored[player] then
		return false, "Your save is still loading. Try again in a moment!"
	end
	local inventory: { [string]: number? } = data.inventory
	if (inventory[item.id] or 0) <= 0 then
		return false, `You don't have a {item.name}. Buy one at the Bakery!`
	end
	if #data.cakes >= Cakes.limit(data.wingsOwned) then
		return false,
			`You already have {#data.cakes} out (one per wing). Wait until one is eaten up, or buy a new wing.`
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local spot = if root and root:IsA("BasePart")
		then MansionService.floorSpot(player, root.Position + root.CFrame.LookVector * PlaceAhead, EdgeMargin)
		else nil
	if not spot then
		return false, "Stand inside your mansion to set it out."
	end

	local left = (inventory[item.id] or 0) - 1
	inventory[item.id] = if left > 0 then left else nil
	local offset = plot.frame:PointToObjectSpace(spot)
	local saved = Cakes.new(item.id, offset.X, offset.Y, offset.Z, os.time())
	table.insert(data.cakes, saved)
	show(player, saved)
	return true,
		`You set out the {item.name}. Monsters will come for a bite, even while you're offline (it lasts {CakeConfig.Minutes} minutes).`
end

-- Sets one of the player's cakes out in front of them (they clicked with it in hand).
-- Returns whether it worked. The cake is only used up when it worked.
function CakeService.place(player: Player, itemId: string): boolean
	if placing[player] then
		return false
	end
	placing[player] = true
	local ok, worked, message = pcall(tryPlace, player, itemId)
	placing[player] = nil
	if not ok then
		warn(`CakeService: placing a cake failed: {worked}`)
		return false
	end
	Notify.toast(player, message)
	if worked then
		CakeService.syncTools(player)
	end
	return worked
end

local function find(data: DataService.Data, uid: string): Value.CaughtMonster?
	for _, caught in data.monsters do
		if caught.uid == uid then
			return caught
		end
	end
	return nil
end

-- " and got Vampire!", " and turned into a Count!" or ". No mutation this time." for one
-- bite. Notes a new combo for the Codex.
local function result(data: DataService.Data, b: Cakes.Bite): string
	if b.combo then
		CareService.discoverCombo(data, b.combo)
		local article = if string.match(b.combo, "^[AEIOU]") then "an" else "a"
		return ` and turned into {article} {b.combo}!`
	elseif b.effect then
		return ` and got {Format.name(b.effect)}!`
	end
	return ". No mutation this time."
end

-- One monster finishes its walk and takes a bite.
local function bite(player: Player, cake: Live, uid: string)
	cake.coming = nil
	local list = live[player]
	local data = DataService.get(player)
	if not list or not table.find(list, cake) or not data then
		return -- the owner left
	end
	local caught = find(data, uid)
	if not caught then
		return -- stored or sold on the way
	end
	local b = Cakes.bite(cake.saved, caught, random)
	MansionService.refreshMonsters(player)
	local name = Format.name(caught.monsterId)
	if cake.saved.bitesLeft <= 0 then
		Notify.toast(player, `{name} ate the last of your {cake.item.name}{result(data, b)}`)
		remove(player, cake)
	else
		Notify.toast(player, `{name} took a bite of your {cake.item.name}{result(data, b)}`)
		cake.label.Text = labelText(cake)
	end
end

-- One check for every cake the player has out (they're online).
local function check(player: Player)
	local list = live[player]
	local data = DataService.get(player)
	if not list or not data then
		return
	end
	local now = os.time()
	local models = MansionService.monsterModels(player)
	for _, cake in table.clone(list) do
		if cake.coming then
			continue
		end
		if Cakes.isDone(cake.saved, now) then
			Notify.toast(player, `Your {cake.item.name} went stale and the monsters lost interest.`)
			remove(player, cake)
			continue
		end
		cake.saved.checkedAt = now
		local event = Events.find(workspace:GetAttribute("WatcherEvent"))
		local biteChance = CakeConfig.BiteChance * (if event then event.cakeBiteMultiplier or 1 else 1)
		if not Rng.chance(biteChance, random) then
			continue
		end
		-- Only monsters within the cake's reach come over.
		local reach = Cakes.reach(cake.item.id)
		local eater = Cakes.pickEater(cake.saved, data.monsters, random, function(caught)
			local model = if caught.uid then models[caught.uid] else nil
			local at = if model and not RoamService.isHeld(model) then RoamService.position(model) else nil
			return at ~= nil and Vector2.new(at.X - cake.at.X, at.Z - cake.at.Z).Magnitude <= reach
		end)
		local uid = if eater then eater.uid else nil
		local model = if uid then models[uid] else nil
		local from = if model then RoamService.position(model) else nil
		if uid and model and from then
			-- Walk up to the plate's edge, from the side it's coming from.
			local _, radius = RoamService.area(model)
			local away = Vector3.new(from.X - cake.at.X, 0, from.Z - cake.at.Z)
			away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(1, 0, 0)
			local target = cake.at + away * (CakeRadius + radius + 0.5)
			local distance = (Vector3.new(target.X, 0, target.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
			local seconds = math.min(distance / (RoamService.speed(model) or 4), MaxWalkSeconds)
			if RoamService.moveTo(model, target.X, target.Z, seconds, EatSeconds) then
				cake.coming = uid
				task.delay(seconds, bite, player, cake, uid)
			end
		end
	end
end

-- When the player is back: plays back what their cakes did while they were away, then puts
-- the ones still going on the floor.
local function restore(player: Player)
	local data = DataService.get(player)
	if restored[player] or not data or not PlotService.get(player) then
		return
	end
	restored[player] = true
	local now = os.time()
	local lines: { string } = {}
	for _, saved in table.clone(data.cakes) do
		local item = Cakes.item(saved.itemId)
		for _, b in Cakes.catchUp(saved, data.monsters, now, data.wingsOwned, random) do
			local caught = find(data, b.uid)
			if b.combo then
				CareService.discoverCombo(data, b.combo)
			end
			if caught and b.effect then
				table.insert(lines, `{Format.name(caught.monsterId)} got {Format.name(b.combo or b.effect)}`)
			end
		end
		if not item or Cakes.isDone(saved, now) then
			local index = table.find(data.cakes, saved)
			if index then
				table.remove(data.cakes, index)
			end
		else
			show(player, saved)
		end
	end
	MansionService.refreshMonsters(player)
	CakeService.syncTools(player)
	if #lines > 0 then
		task.delay(SummaryDelay, function()
			if player.Parent then
				Notify.toast(
					player,
					`While you were away, your cakes did their thing: {table.concat(lines, ", ")}!`
				)
			end
		end)
	end
end

function CakeService.start()
	DataService.onLoaded(function(player)
		restore(player)
	end)
	PlotService.onAssigned(function(player)
		restore(player)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			-- the Backpack is new after every respawn
			task.defer(CakeService.syncTools, player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local list = live[player]
		live[player] = nil
		restored[player] = nil
		placing[player] = nil
		if list then
			for _, cake in list do
				cake.model:Destroy() -- still in the save: it keeps going offline
			end
		end
	end)
	-- The countdown on every label.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, list in live do
				for _, cake in list do
					cake.label.Text = labelText(cake)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(CakeConfig.CheckSeconds)
			for player in live do
				local ok, err = pcall(function()
					check(player)
				end)
				if not ok then
					warn(`CakeService: checking {player.Name}'s cakes failed: {err}`)
				end
			end
		end
	end)
end

return CakeService
