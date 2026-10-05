--!strict
-- Builds the placeholder look of a monster: a glowing orb coloured by rarity with its name
-- floating above it. Used for wild monsters in zones and for the ones roaming a mansion.
-- Real monster models can replace this later; everything else only needs a Model whose
-- PrimaryPart is called "Body".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Spawning = require(ReplicatedStorage.Shared.Util.Spawning)

local MonsterModel = {}

export type Info = { monsterId: string, rarity: string, size: string, effects: { string }?, owner: string? }

-- Orb and label colour per rarity.
local rarityColors: { [string]: Color3 } = {
	Common = Color3.fromRGB(170, 170, 170),
	Uncommon = Color3.fromRGB(80, 210, 90),
	Rare = Color3.fromRGB(60, 140, 255),
	Epic = Color3.fromRGB(170, 80, 255),
	Legendary = Color3.fromRGB(255, 150, 30),
	Mythic = Color3.fromRGB(255, 55, 55),
	Divine = Color3.fromRGB(255, 245, 170),
	Phantom = Color3.fromRGB(200, 215, 255),
	Nightmare = Color3.fromRGB(230, 40, 150),
	Eldritch = Color3.fromRGB(40, 255, 200),
}

function MonsterModel.color(rarityId: string): Color3
	return rarityColors[rarityId] or Color3.new(1, 1, 1)
end

-- Orb radius in studs for a size (Normal = 1.5).
function MonsterModel.radius(sizeId: string): number
	return Spawning.radius(sizeId)
end

-- One line of text in the name label.
local function line(parent: Instance, text: string, color: Color3, y: number, height: number, bold: boolean)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	local stroke = Instance.new("UIStroke") -- dark outline so it's readable on any background
	stroke.Thickness = 1.5
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
	label.Parent = parent
end

function MonsterModel.build(info: Info): Model
	local radius = MonsterModel.radius(info.size)
	local color = MonsterModel.color(info.rarity)

	local model = Instance.new("Model")
	model.Name = info.monsterId
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- streams in as one piece with its label

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * 2 * radius
	body.Material = Enum.Material.Neon
	body.Color = color
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = true -- the client raycasts the orb when a player presses on it
	body.CastShadow = false
	body.Parent = model
	model.PrimaryPart = body

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 6 + radius * 2
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = body

	-- "Wisp Jack" / "Big Rare · Ghost, Werewolf"
	local details = `{info.size} {info.rarity}`
	local effects = info.effects
	if effects and #effects > 0 then
		local names = {}
		for _, effectId in effects do
			table.insert(names, Format.name(effectId))
		end
		details ..= ` · {table.concat(names, ", ")}`
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Adornee = body
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(220, 46)
	billboard.StudsOffset = Vector3.new(0, radius + 1.6, 0)
	line(billboard, Format.name(info.monsterId), Color3.new(1, 1, 1), 0, 0.55, true)
	line(billboard, details, color, 0.55, 0.45, false)
	billboard.Parent = body

	model:SetAttribute("MonsterId", info.monsterId)
	model:SetAttribute("Rarity", info.rarity)
	model:SetAttribute("Size", info.size)
	if info.owner then
		model:SetAttribute("Owner", info.owner)
	end
	return model
end

return MonsterModel
