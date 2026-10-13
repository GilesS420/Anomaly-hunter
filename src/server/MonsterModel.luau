--!strict
-- Builds how a monster looks, with its name floating above it. Used for wild monsters in
-- zones and for the ones roaming a mansion (those get a third line saying if they're fed,
-- and glow dimmer while they're hungry).
-- Monsters with a look in Config/Looks are stud-style block models whose limbs are joined
-- to Body with Motor6Ds (the client swings them, see RoamController); the rest are still a
-- glowing orb coloured by rarity. Body is always the PrimaryPart and the part players press
-- on to catch: for a block model it's an invisible ball around it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Looks = require(ReplicatedStorage.Shared.Config.Looks)
local Spawning = require(ReplicatedStorage.Shared.Util.Spawning)

local MonsterModel = {}

export type Info = {
	monsterId: string,
	rarity: string,
	size: string,
	effects: { string }?,
	owner: string?,
	status: string?, -- mansion monsters: "Fed · 45% familiar" (see Util/Care.status)
	hungry: boolean?, -- mansion monsters: dims the glow and puts the effects to sleep
}

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

-- Orb radius in studs for a size (Normal = 1.5). Monsters whose look grows them (the Watcher
-- event monsters) get a bigger orb, so they keep their distance and stand on the floor.
function MonsterModel.radius(sizeId: string, monsterId: string?): number
	local look = monsterId and Looks[monsterId]
	return Spawning.radius(sizeId) * (if look and look.grow then look.grow else 1)
end

local FedColor = Color3.fromRGB(255, 190, 230)
local HungryColor = Color3.fromRGB(255, 120, 70)

-- One line of text in the name label.
local function line(
	parent: Instance,
	name: string,
	text: string,
	color: Color3,
	y: number,
	height: number,
	bold: boolean
)
	local label = Instance.new("TextLabel")
	label.Name = name
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

-- "Big Rare · Ghost, Werewolf" (effects fall asleep while the monster is hungry).
local function detailsText(info: Info): string
	local details = `{info.size} {info.rarity}`
	local effects = info.effects
	if effects and #effects > 0 then
		local names = {}
		for _, effectId in effects do
			table.insert(names, Format.name(effectId))
		end
		local asleep = if info.hungry then " (asleep)" else ""
		details ..= ` · {table.concat(names, ", ")}{asleep}`
	end
	return details
end

-- Updates the label and glow after a mansion monster was fed, got hungry or got an effect.
function MonsterModel.refresh(model: Model, info: Info)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local billboard = body:FindFirstChild("Label")
	local details = billboard and billboard:FindFirstChild("Details")
	if details and details:IsA("TextLabel") then
		details.Text = detailsText(info)
	end
	local status = billboard and billboard:FindFirstChild("Status")
	if status and status:IsA("TextLabel") then
		status.Text = info.status or ""
		status.TextColor3 = if info.hungry then HungryColor else FedColor
	end
	body.Material = if info.hungry then Enum.Material.SmoothPlastic else Enum.Material.Neon
	local light = body:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = if info.hungry then 0.3 else 1.2
	end
end

local axes = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

local function vector(numbers: { number }, scale: number): Vector3
	return Vector3.new(numbers[1], numbers[2], numbers[3]) * scale
end

-- Builds the blocks of a look around Body. Each part is welded (or, if it swings, joined with
-- a Motor6D) to Body, so moving Body moves the whole monster.
local function buildLook(model: Model, body: BasePart, look: Looks.Look, scale: number, radius: number)
	-- Walkers are drawn with their feet at y = -2 (Normal size) but stand radius + 0.5 below
	-- Body's centre (Roam places them that way), so shift them to keep their feet on the floor.
	-- Grown floaters (event monsters) would dangle into the floor the same way, so they're lifted
	-- to hover a little above it.
	local lift = if look.gait == "walk"
		then 2 * scale - (radius + 0.5)
		elseif look.grow then 2.4 * scale - (radius + 0.5)
		else 0
	for _, piece in look.pieces do
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Shape = if piece.shape == "Ball"
			then Enum.PartType.Ball
			elseif piece.shape == "Cylinder" then Enum.PartType.Cylinder
			else Enum.PartType.Block
		part.Size = vector(piece.size, scale)
		part.Color = Color3.fromRGB(piece.color[1], piece.color[2], piece.color[3])
		part.Material = if piece.glow then Enum.Material.Neon else Enum.Material.Plastic
		part.TopSurface = Enum.SurfaceType.Studs -- the classic brick look
		part.BottomSurface = Enum.SurfaceType.Inlet
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false -- presses go to Body
		part.Massless = true
		part.CastShadow = not piece.glow

		local centre = vector(piece.at, scale) + Vector3.new(0, lift, 0)
		local rot = piece.rot
		local place = CFrame.new(centre)
		if rot then
			place *= CFrame.fromOrientation(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		end
		part.CFrame = body.CFrame * place
		local joint = piece.joint
		if joint then
			local pivot = if joint.pivot then vector(joint.pivot, scale) else Vector3.zero
			local motor = Instance.new("Motor6D")
			motor.Name = piece.name
			motor.Part0 = body
			motor.Part1 = part
			motor.C0 = place * CFrame.new(pivot)
			motor.C1 = CFrame.new(pivot)
			-- Read by the client every frame to swing the part (RoamController).
			motor:SetAttribute("SwingAxis", axes[joint.axis])
			motor:SetAttribute("SwingAmp", if joint.slide then joint.amp * scale else math.rad(joint.amp))
			motor:SetAttribute("SwingSpeed", joint.speed)
			motor:SetAttribute("SwingPhase", joint.phase or 0)
			motor:SetAttribute("SwingSpin", joint.spin == true)
			motor:SetAttribute("SwingSlide", joint.slide == true)
			motor.Parent = part
		else
			local weld = Instance.new("Weld")
			weld.Part0 = body
			weld.Part1 = part
			weld.C0 = place
			weld.Parent = part
		end
		part.Parent = model
	end
	model:SetAttribute("Gait", look.gait)
end

function MonsterModel.build(info: Info): Model
	local radius = MonsterModel.radius(info.size, info.monsterId)
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

	local look = Looks[info.monsterId]
	local scale = radius / Spawning.BaseRadius
	local labelHeight = radius + 1.6
	if look then
		body.Transparency = 1 -- just the press target; the blocks are what players see
		buildLook(model, body, look, scale, radius)
		labelHeight = look.top * scale + 1.2
	end

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 6 + radius * 2
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = body

	-- "Wisp Jack" / "Big Rare · Ghost, Werewolf" / mansion monsters: "Fed · 45% familiar"
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Adornee = body
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.LightInfluence = 0
	billboard.StudsOffset = Vector3.new(0, labelHeight, 0)
	local name = Format.name(info.monsterId)
	if info.status then
		billboard.Size = UDim2.fromOffset(220, 66)
		line(billboard, "Name", name, Color3.new(1, 1, 1), 0, 0.4, true)
		line(billboard, "Details", "", color, 0.4, 0.3, false)
		line(billboard, "Status", "", FedColor, 0.7, 0.3, false)
	else
		billboard.Size = UDim2.fromOffset(220, 46)
		line(billboard, "Name", name, Color3.new(1, 1, 1), 0, 0.55, true)
		line(billboard, "Details", "", color, 0.55, 0.45, false)
	end
	billboard.Parent = body

	model:SetAttribute("MonsterId", info.monsterId)
	model:SetAttribute("Rarity", info.rarity)
	model:SetAttribute("Size", info.size)
	if info.owner then
		model:SetAttribute("Owner", info.owner)
	end
	MonsterModel.refresh(model, info)
	return model
end

return MonsterModel
