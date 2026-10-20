--!strict
-- Builds how a monster looks, with its name floating above it. Used for wild monsters in
-- zones and for the ones roaming a mansion (those get a third line saying how familiar they
-- are). Every monster wears a price tag: what the Collector pays
-- for a mansion monster, and base value x size (what it's worth before effects, Familiarity
-- and wings) for a wild one.
-- Monsters with a look in Config/Looks are stud-style block models whose limbs are joined
-- to Body with Motor6Ds (the client swings them, see RoamController); the rest are still a
-- glowing orb coloured by rarity. Body is always the PrimaryPart and the part players press
-- on to catch: for a block model it's an invisible ball around it.
-- Effects and the catch variant change the look (Config/EffectLooks): a Gold monster is gold,
-- a Vampire wears a cape. When they change, refresh rebuilds the blocks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectLooks = require(ReplicatedStorage.Shared.Config.EffectLooks)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Looks = require(ReplicatedStorage.Shared.Config.Looks)
local Spawning = require(ReplicatedStorage.Shared.Util.Spawning)
local Value = require(ReplicatedStorage.Shared.Util.Value)

local MonsterModel = {}

export type Info = {
	monsterId: string,
	rarity: string,
	size: string,
	effects: { string }?, -- merged into combos already (Value.resolveEffects)
	variant: string?, -- catch variant: "Silver", "Gold", "Shiny" or "Rainbow"
	owner: string?,
	status: string?, -- mansion monsters: "45% familiar" (see Util/Care.status)
	value: number?, -- mansion monsters: what the Collector pays right now (Util/Value.sellValue);
	-- left out, the tag shows base value x size
}

-- What the tag shows: the given value, or base value x size (no effects, Familiarity or wings).
local function tagValue(info: Info): number
	if info.value then
		return info.value
	end
	local plain: Value.CaughtMonster =
		{ monsterId = info.monsterId, size = info.size, effects = {}, familiarity = 0 }
	local ok, value = pcall(Value.sellValue, plain, 1)
	return if ok then value else 0
end

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

local FamiliarColor = Color3.fromRGB(255, 190, 230)

-- Price tag colours, the same spooky style as the shop windows (client Ui.Colors).
local TagPanel = Color3.fromRGB(18, 14, 26)
local TagLamp = Color3.fromRGB(255, 176, 84) -- lantern orange
local TagHeight = 26 -- pixels, on top of the name label

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

-- "Big Rare · Ghost, Werewolf".
local function detailsText(info: Info): string
	local details = `{info.size} {info.rarity}`
	local effects = info.effects
	if effects and #effects > 0 then
		local names = {}
		for _, effectId in effects do
			table.insert(names, Format.name(effectId))
		end
		details ..= ` · {table.concat(names, ", ")}`
	end
	return details
end

-- Builds (or rebuilds) the blocks for the monster's look with its effects; set further down.
local dressModel: (model: Model, info: Info) -> ()

-- Which effects and variant the blocks were built with.
local function lookKey(info: Info): string
	return `{table.concat(info.effects or {}, ",")}|{info.variant or ""}`
end

-- Updates the label after a mansion monster got more familiar or got an effect.
function MonsterModel.refresh(model: Model, info: Info)
	local body = model.PrimaryPart
	if not body then
		return
	end
	if model:GetAttribute("LookKey") ~= lookKey(info) then
		dressModel(model, info)
	end
	local billboard = body:FindFirstChild("Label")
	local details = billboard and billboard:FindFirstChild("Details")
	if details and details:IsA("TextLabel") then
		details.Text = detailsText(info)
	end
	local status = billboard and billboard:FindFirstChild("Status")
	if status and status:IsA("TextLabel") then
		status.Text = info.status or ""
		status.TextColor3 = FamiliarColor
	end
	local tag = billboard and billboard:FindFirstChild("Value")
	local price = tag and tag:FindFirstChild("Price")
	if tag and price and price:IsA("TextLabel") then
		price.Text = Format.money(tagValue(info))
		price.TextColor3 = TagLamp
	end
end

-- The "$1.2M" pill at the top of a monster's label, so players can see what it's worth
-- without going to the Collector. The text is filled in by refresh.
local function priceTag(parent: Instance)
	local tag = Instance.new("Frame")
	tag.Name = "Value"
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.Position = UDim2.fromScale(0.5, 0)
	tag.Size = UDim2.new(0, 0, 0, TagHeight - 4)
	tag.AutomaticSize = Enum.AutomaticSize.X -- as wide as the price
	tag.BackgroundColor3 = TagPanel
	tag.BackgroundTransparency = 0.15
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = tag
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Thickness = 1.5
	rim.Color = TagLamp
	rim.Parent = tag
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = tag

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.BackgroundTransparency = 1
	price.Size = UDim2.fromScale(0, 1)
	price.AutomaticSize = Enum.AutomaticSize.X
	price.Font = Enum.Font.GothamBlack
	price.TextSize = 16
	price.Text = ""
	price.TextColor3 = TagLamp
	price.Parent = tag
	tag.Parent = parent
end

local axes = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

local function vector(numbers: { number }, scale: number): Vector3
	return Vector3.new(numbers[1], numbers[2], numbers[3]) * scale
end

-- Builds the blocks of a look around Body. Each part is welded (or, if it swings, joined with
-- a Motor6D) to Body, so moving Body moves the whole monster.
local function buildLook(
	model: Model,
	body: BasePart,
	look: EffectLooks.DressedLook,
	scale: number,
	radius: number
)
	-- Walkers are drawn with their feet at y = -2 (Normal size) but stand radius + 0.5 below
	-- Body's centre (Roam places them that way), so shift them to keep their feet on the floor.
	-- Grown floaters (event monsters) would dangle into the floor the same way, so they're lifted
	-- to hover a little above it.
	local lift = if look.gait == "walk"
		then 2 * scale - (radius + 0.5)
		elseif look.grow then 2.4 * scale - (radius + 0.5)
		else 0
	for _, piece: EffectLooks.Piece in look.pieces :: any do
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Shape = if piece.shape == "Ball"
			then Enum.PartType.Ball
			elseif piece.shape == "Cylinder" then Enum.PartType.Cylinder
			else Enum.PartType.Block
		part.Size = vector(piece.size, scale)
		part.Color = Color3.fromRGB(piece.color[1], piece.color[2], piece.color[3])
		part.Material = if piece.glow
			then Enum.Material.Neon
			elseif piece.material then (Enum.Material :: any)[piece.material]
			elseif look.wet then Enum.Material.SmoothPlastic
			else Enum.Material.Plastic
		if look.wet and not piece.glow then
			part.Reflectance = 0.2 -- a wet sheen
		end
		if piece.reflectance then
			part.Reflectance = piece.reflectance
		end
		if look.seeThrough and not piece.glow then
			part.Transparency = look.seeThrough
		end
		if piece.transparency then
			part.Transparency = piece.transparency
		end
		part.TopSurface = Enum.SurfaceType.Studs -- the classic brick look
		part.BottomSurface = Enum.SurfaceType.Inlet
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false -- presses go to Body
		part.Massless = true
		part.CastShadow = not piece.glow and not look.seeThrough and not piece.transparency
		part:SetAttribute("Look", true) -- rebuilt when the effects change
		if piece.rainbow then
			part:SetAttribute("Rainbow", piece.rainbow) -- the client keeps its colour cycling
		end

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
			if joint.around then
				-- Circles a point of the monster, upright whatever the part's own tilt.
				local hub = vector(joint.around, scale) + Vector3.new(0, lift, 0)
				motor.C0 = CFrame.new(hub)
				motor.C1 = (CFrame.new(-hub) * place):Inverse()
			end
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

-- Particles an effect or variant gives off (sparkles, mist, drips).
local auraTextures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Mist = "rbxasset://textures/particles/smoke_main.dds",
	Drip = "rbxasset://textures/particles/sparkles_main.dds",
}
local function addAura(body: BasePart, aura: EffectLooks.Aura, radius: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Aura"
	emitter.Texture = auraTextures[aura.kind]
	emitter.Color = ColorSequence.new(Color3.fromRGB(aura.color[1], aura.color[2], aura.color[3]))
	emitter.LightEmission = if aura.kind == "Mist" then 0.3 else 1
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Rate = if aura.kind == "Mist" then 4 else 6
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Speed = NumberRange.new(0.3, 1)
	if aura.kind == "Drip" then
		emitter.Acceleration = Vector3.new(0, -8, 0)
		emitter.Size = NumberSequence.new(0.25 * radius / 1.5)
	elseif aura.kind == "Mist" then
		emitter.Size = NumberSequence.new(radius * 0.8, radius * 1.4)
		emitter.Transparency = NumberSequence.new(0.75, 1)
	else
		emitter.Size = NumberSequence.new(0.35 * radius / 1.5, 0)
	end
	emitter.Parent = body
end

function dressModel(model: Model, info: Info)
	local body = model.PrimaryPart :: BasePart
	local base = Looks[info.monsterId]
	model:SetAttribute("LookKey", lookKey(info))
	if not base then
		return -- still a glowing orb
	end
	for _, child in model:GetChildren() do
		if child:GetAttribute("Look") then
			child:Destroy()
		end
	end
	for _, child in body:GetChildren() do
		if child:IsA("ParticleEmitter") and child.Name == "Aura" then
			child:Destroy()
		end
	end
	local radius = MonsterModel.radius(info.size, info.monsterId)
	local scale = radius / Spawning.BaseRadius
	local look = EffectLooks.dress(base, info.effects, info.variant)
	buildLook(model, body, look, scale, radius)
	for _, aura in look.auras or {} do
		addAura(body, aura, radius)
	end
	local billboard = body:FindFirstChild("Label")
	if billboard and billboard:IsA("BillboardGui") then
		billboard.StudsOffset = Vector3.new(0, look.top * scale + 1.6, 0)
	end
	-- Tells the client to pick up the new swinging joints (RoamController).
	model:SetAttribute("LookVersion", ((model:GetAttribute("LookVersion") :: number?) or 0) + 1)
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
	local labelHeight = radius + 1.6
	if look then
		body.Transparency = 1 -- just the press target; the blocks are what players see
	end

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 6 + radius * 2
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = body

	-- "$1.2M" price tag / "Wisp Jack" / "Big Rare · Ghost, Werewolf" / mansion monsters:
	-- "45% familiar"
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Adornee = body
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.LightInfluence = 0
	billboard.StudsOffset = Vector3.new(0, labelHeight, 0)
	-- The price tag sits above the text lines, which keep their 66 (or 46) pixels.
	billboard.StudsOffset += Vector3.new(0, 0.4, 0)
	local name = Format.name(info.monsterId)
	local top = TagHeight
	local height = top + if info.status then 66 else 46
	billboard.Size = UDim2.fromOffset(220, height)
	priceTag(billboard)
	local function row(px: number): number
		return px / height
	end
	if info.status then
		line(billboard, "Name", name, Color3.new(1, 1, 1), row(top), row(26.4), true)
		line(billboard, "Details", "", color, row(top + 26.4), row(19.8), false)
		line(billboard, "Status", "", FamiliarColor, row(top + 46.2), row(19.8), false)
	else
		line(billboard, "Name", name, Color3.new(1, 1, 1), row(top), row(25.3), true)
		line(billboard, "Details", "", color, row(top + 25.3), row(20.7), false)
	end
	billboard.Parent = body

	model:SetAttribute("MonsterId", info.monsterId)
	model:SetAttribute("Rarity", info.rarity)
	model:SetAttribute("Size", info.size)
	if info.owner then
		model:SetAttribute("Owner", info.owner)
	end
	MonsterModel.refresh(model, info) -- builds the look (with its effects) on the way
	return model
end

return MonsterModel
