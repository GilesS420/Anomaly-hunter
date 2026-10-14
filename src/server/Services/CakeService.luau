--!strict
-- Cakes set out in a mansion (Backpack > Set out on a treat, standing inside your mansion).
-- The treat stands on the floor where you stood and the monsters in that mansion come for
-- a bite: every Config/Care.CakeCheckSeconds each cake rolls CakeBiteChance, and on a hit one
-- monster that hasn't had a bite of it yet walks over and eats (CareService.eat with
-- bite = true: fed, half the Familiarity, lower effect odds, see Util/Care.pickEffect).
-- A cake is gone after CakeBites bites or CakeMinutes. You can have Config/Care.CakesPerWing
-- cakes out per owned wing. Cakes live only while you're in the game; they aren't saved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(ReplicatedStorage.Shared.Util.Care)
local CareConfig = require(ReplicatedStorage.Shared.Config.Care)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local CareService = require(script.Parent.CareService)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)
local RoamService = require(script.Parent.RoamService)
local Notify = require(script.Parent.Parent.Notify)

local CakeService = {}

type Cake = {
	item: Shop.Item,
	model: Model,
	label: TextLabel,
	at: Vector3, -- floor point under the cake
	bitesLeft: number,
	expiresAt: number,
	eaten: { [string]: boolean }, -- uids that had a bite
	coming: string?, -- uid of the monster walking over right now
}

local CakeRadius = 1.6 -- studs
local EdgeMargin = 3 -- keeps a cake off the wing edges
local MaxWalkSeconds = 12 -- a monster hurries if the cake is far away
local EatSeconds = 3 -- it stays at the cake this long

local cakes: { [Player]: { Cake } } = {}
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

local function labelText(cake: Cake): string
	local bites = if cake.bitesLeft == 1 then "1 bite left" else `{cake.bitesLeft} bites left`
	return `{cake.item.name}\n{bites}`
end

-- A plate with a round cake on it and a label: "Fang Fudge / 3 bites left".
local function build(item: Shop.Item, at: Vector3): (Model, TextLabel)
	local model = Instance.new("Model")
	model.Name = `Cake_{item.id}`
	local function cylinder(name: string, height: number, diameter: number, y: number, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(height, diameter, diameter)
		-- a cylinder's axis is X: tip it upright
		part.CFrame = CFrame.new(at + Vector3.new(0, y + height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Parent = model
		return part
	end
	cylinder("Plate", 0.2, CakeRadius * 2 + 0.8, 0, Color3.fromRGB(235, 235, 235))
	local cake = cylinder("Cake", 1.4, CakeRadius * 2, 0.2, Color3.fromRGB(150, 70, 110))
	cylinder("Icing", 0.25, CakeRadius * 2 + 0.1, 1.5, Color3.fromRGB(240, 200, 230))
	model.PrimaryPart = cake

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 220)
	light.Range = 8
	light.Brightness = 0.8
	light.Parent = cake

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Adornee = cake
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(180, 44)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 240)
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard
	billboard.Parent = cake
	return model, label
end

local function remove(player: Player, cake: Cake)
	local list = cakes[player]
	local index = if list then table.find(list, cake) else nil
	if list and index then
		table.remove(list, index)
	end
	cake.model:Destroy()
end

-- How many cakes the player may have out at once.
local function limit(data: DataService.Data): number
	return data.wingsOwned * CareConfig.CakesPerWing
end

-- Sets one of the player's treats out where they stand. Returns whether it worked and the
-- message for them. The treat is only used up when it worked.
function CakeService.setOut(player: Player, itemId: unknown): (boolean, string)
	local data = DataService.get(player)
	if not data then
		return false, "Your save is still loading. Try again in a moment!"
	end
	local item = if typeof(itemId) == "string" then Care.treat(itemId) else nil
	if not item then
		return false, "That isn't a treat."
	end
	local inventory: { [string]: number? } = data.inventory
	if (inventory[item.id] or 0) <= 0 then
		return false, `You don't have a {item.name}. Buy one at the Bakery!`
	end
	local list = cakes[player] or {}
	if #list >= limit(data) then
		return false,
			`You already have {#list} out (one per wing). Wait until the monsters finish one, or buy a new wing.`
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local spot = if root and root:IsA("BasePart")
		then MansionService.floorSpot(player, root.Position, EdgeMargin)
		else nil
	if not spot then
		return false, "Stand inside your mansion to set it out."
	end

	local left = (inventory[item.id] or 0) - 1
	inventory[item.id] = if left > 0 then left else nil
	local model, label = build(item, spot)
	local cake: Cake = {
		item = item,
		model = model,
		label = label,
		at = spot,
		bitesLeft = CareConfig.CakeBites,
		expiresAt = os.time() + CareConfig.CakeMinutes * 60,
		eaten = {},
	}
	label.Text = labelText(cake)
	model.Parent = cakesFolder()
	table.insert(list, cake)
	cakes[player] = list
	return true,
		`You set out the {item.name}. Your monsters will come for a bite (it stays {CareConfig.CakeMinutes} minutes, and disappears if you leave).`
end

-- One monster finishes its walk and eats a bite.
local function bite(player: Player, cake: Cake, uid: string)
	cake.coming = nil
	local list = cakes[player]
	local data = DataService.get(player)
	if not list or not table.find(list, cake) or not data then
		return -- eaten up, gone stale, or the owner left
	end
	local caught: Value.CaughtMonster? = nil
	for _, candidate in data.monsters do
		if candidate.uid == uid then
			caught = candidate
		end
	end
	if not caught then
		return -- stored or sold on the way
	end
	cake.eaten[uid] = true
	cake.bitesLeft -= 1
	local result = CareService.eat(player, data, caught, cake.item, true)
	local name = Format.name(caught.monsterId)
	if cake.bitesLeft <= 0 then
		Notify.toast(player, `{name} ate the last of your {cake.item.name}{result}!`)
		remove(player, cake)
	else
		Notify.toast(player, `{name} took a bite of your {cake.item.name}{result}!`)
		cake.label.Text = labelText(cake)
	end
end

-- Picks a monster for a bite: one that hasn't had one yet, preferring ones the treat's
-- effect can still land on. Nil when nobody can come.
local function pickEater(player: Player, cake: Cake): (string?, Model?)
	local data = DataService.get(player)
	if not data then
		return nil, nil
	end
	local models = MansionService.monsterModels(player)
	local best: { string } = {}
	local others: { string } = {}
	for _, caught in data.monsters do
		local uid = caught.uid
		local model = if uid then models[uid] else nil
		if uid and model and not cake.eaten[uid] and not RoamService.isHeld(model) then
			table.insert(if Care.canTreat(caught, cake.item) == "Ok" then best else others, uid)
		end
	end
	local pool = if #best > 0 then best else others
	if #pool == 0 then
		return nil, nil
	end
	local uid = pool[random:NextInteger(1, #pool)]
	return uid, models[uid]
end

local function check(player: Player)
	local list = cakes[player]
	if not list then
		return
	end
	local now = os.time()
	for _, cake in table.clone(list) do
		if now >= cake.expiresAt and not cake.coming then
			Notify.toast(player, `Your {cake.item.name} went stale and the monsters lost interest.`)
			remove(player, cake)
		elseif not cake.coming and Rng.chance(CareConfig.CakeBiteChance, random) then
			local uid, model = pickEater(player, cake)
			local from = if model then RoamService.position(model) else nil
			if uid and model and from then
				-- Walk up to the plate's edge, from the side it's coming from.
				local _, radius = RoamService.area(model)
				local away = Vector3.new(from.X - cake.at.X, 0, from.Z - cake.at.Z)
				away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(1, 0, 0)
				local target = cake.at + away * (CakeRadius + radius + 0.5)
				local distance = (Vector3.new(target.X, 0, target.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
				local speed = RoamService.speed(model) or 4
				local seconds = math.min(distance / speed, MaxWalkSeconds)
				if RoamService.moveTo(model, target.X, target.Z, seconds, EatSeconds) then
					cake.coming = uid
					task.delay(seconds, bite, player, cake, uid)
				end
			end
		end
	end
end

function CakeService.start()
	Players.PlayerRemoving:Connect(function(player)
		local list = cakes[player]
		cakes[player] = nil
		if list then
			for _, cake in list do
				cake.model:Destroy()
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(CareConfig.CakeCheckSeconds)
			for player in cakes do
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
