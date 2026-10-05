--!strict
-- Keeps each zone stocked with monsters. A zone is built in Studio as
--   Workspace.Zones.<ZoneId>.SpawnPoints  (a folder of parts where monsters can appear)
-- Spawned monsters go in Workspace.Zones.<ZoneId>.Monsters. Zones without a folder are skipped.
-- The models are placeholders (a coloured ball with a name tag) until the art is in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spawning = require(ReplicatedStorage.Shared.Util.Spawning)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local SpawnService = {}

export type Spawned = {
	monsterId: string,
	rarity: string,
	size: string,
	zone: number,
}

local RarityColors: { [string]: Color3 } = {
	Common = Color3.fromRGB(190, 190, 190),
	Uncommon = Color3.fromRGB(90, 200, 90),
	Rare = Color3.fromRGB(70, 140, 255),
	Epic = Color3.fromRGB(170, 80, 255),
	Legendary = Color3.fromRGB(255, 170, 30),
	Mythic = Color3.fromRGB(255, 60, 90),
	Divine = Color3.fromRGB(255, 255, 160),
}

local random = Random.new()
local live: { [Model]: Spawned } = {}

local function buildModel(spawned: Spawned, scale: number, at: BasePart): Model
	local model = Instance.new("Model")
	model.Name = spawned.monsterId

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * 3 * scale
	body.Color = RarityColors[spawned.rarity] or Color3.new(1, 1, 1)
	body.Material = Enum.Material.Neon
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = at.CFrame + Vector3.new(0, body.Size.Y / 2 + 0.5, 0)
	body.Parent = model
	model.PrimaryPart = body

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(200, 50)
	tag.StudsOffset = Vector3.new(0, body.Size.Y / 2 + 1.5, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = body.Color
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = `{spawned.monsterId}\n{spawned.size} {spawned.rarity}`
	label.Parent = tag
	tag.Parent = body

	model:SetAttribute("MonsterId", spawned.monsterId)
	model:SetAttribute("Rarity", spawned.rarity)
	model:SetAttribute("Size", spawned.size)
	model:SetAttribute("Zone", spawned.zone)
	return model
end

local function pickSpawnPoint(points: { BasePart }, monstersFolder: Folder): BasePart
	local free = {}
	for _, point in points do
		local taken = false
		for _, model in monstersFolder:GetChildren() do
			if model:GetAttribute("SpawnPoint") == point.Name then
				taken = true
				break
			end
		end
		if not taken then
			table.insert(free, point)
		end
	end
	local pool = if #free > 0 then free else points
	return pool[random:NextInteger(1, #pool)]
end

local function spawnOne(zoneIndex: number, spawnPointsFolder: Instance, monstersFolder: Folder)
	local points = {}
	for _, child in spawnPointsFolder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end
	if #points == 0 then
		return
	end

	local monster = Spawning.rollMonster(zoneIndex, random)
	local size = Spawning.rollSize(random)
	local spawned: Spawned =
		{ monsterId = monster.id, rarity = monster.rarity, size = size.id, zone = zoneIndex }
	local point = pickSpawnPoint(points, monstersFolder)

	local model = buildModel(spawned, size.scale, point)
	model:SetAttribute("SpawnPoint", point.Name)
	live[model] = spawned

	-- However a monster leaves (caught, cleared by an event), replace it after a delay.
	model.Destroying:Connect(function()
		live[model] = nil
		task.delay(Zones.RespawnSeconds, function()
			if #monstersFolder:GetChildren() < Zones.MaxAlive then
				spawnOne(zoneIndex, spawnPointsFolder, monstersFolder)
			end
		end)
	end)
	model.Parent = monstersFolder
end

-- What a spawned model is, or nil if it isn't a live monster (already caught, or not one).
function SpawnService.get(model: Model): Spawned?
	return live[model]
end

-- Removes a caught monster from the zone and returns it as a save-ready entry, rolling any
-- catch effects from the hunter's equipped tools. Returns nil if someone caught it first.
function SpawnService.capture(model: Model, equippedItemIds: { string }): Value.CaughtMonster?
	local spawned = live[model]
	if not spawned then
		return nil
	end
	live[model] = nil
	model:Destroy()
	return {
		monsterId = spawned.monsterId,
		size = spawned.size,
		effects = Spawning.rollCatchEffects(equippedItemIds, random),
		familiarity = 0,
		fed = true,
	}
end

function SpawnService.start()
	local zonesFolder = workspace:FindFirstChild("Zones")
	if not zonesFolder then
		warn("SpawnService: no Workspace.Zones folder, nothing will spawn")
		return
	end
	for _, zone in Zones.List do
		local zoneFolder = zonesFolder:FindFirstChild(zone.id)
		local spawnPoints = zoneFolder and zoneFolder:FindFirstChild("SpawnPoints")
		if zoneFolder and spawnPoints then
			local monstersFolder = zoneFolder:FindFirstChild("Monsters")
			if not monstersFolder then
				monstersFolder = Instance.new("Folder")
				monstersFolder.Name = "Monsters"
				monstersFolder.Parent = zoneFolder
			end
			for _ = 1, Zones.MaxAlive do
				spawnOne(zone.index, spawnPoints, monstersFolder :: Folder)
			end
		end
	end
end

return SpawnService
