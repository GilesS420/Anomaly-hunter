--!strict
-- Builds a cake from its look (Config/Cakes.Looks): a plate, 1 to 3 tiers of sponge with
-- icing, and a topping that says what it is (fangs on Fang Fudge, bones on the Bone Marrow
-- Mousse, a moon on the Eclipse Éclair). The same model sits on the mansion floor and in your
-- hand (CakeModel.tool).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CakeConfig = require(ReplicatedStorage.Shared.Config.Cakes)

local CakeModel = {}

local Radius = 1.6 -- studs, bottom tier of a floor cake
local TierHeight = 1.1
local IcingHeight = 0.25

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local fallback: CakeConfig.Look = {
	tiers = 1,
	sponge = { 150, 70, 110 },
	icing = { 240, 200, 230 },
	topping = "Candy",
	toppingColor = { 255, 255, 255 },
}

-- Builds the cake at the origin (its plate's bottom at y = 0), scaled by `scale`, anchored.
-- Its PrimaryPart is the plate.
function CakeModel.build(itemId: string, scale: number): Model
	local look = CakeConfig.Looks[itemId] or fallback
	local model = Instance.new("Model")
	model.Name = itemId

	local function part(
		name: string,
		shape: Enum.PartType,
		size: Vector3,
		cframe: CFrame,
		color: Color3,
		material: Enum.Material?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size * scale
		p.CFrame = CFrame.new(cframe.Position * scale) * cframe.Rotation
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Parent = model
		return p
	end
	-- A cylinder standing up (Roblox cylinders lie along X).
	local function disc(
		name: string,
		height: number,
		radius: number,
		y: number,
		color: Color3,
		material: Enum.Material?
	)
		return part(
			name,
			Enum.PartType.Cylinder,
			Vector3.new(height, radius * 2, radius * 2),
			CFrame.new(0, y + height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			color,
			material
		)
	end

	local plate = disc("Plate", 0.2, Radius + 0.4, 0, Color3.fromRGB(235, 235, 235))
	model.PrimaryPart = plate

	local sponge, icing, topping = rgb(look.sponge), rgb(look.icing), rgb(look.toppingColor)
	local y, radius = 0.2, Radius
	for tier = 1, math.clamp(look.tiers, 1, 3) do
		disc(`Tier{tier}`, TierHeight, radius, y, sponge)
		disc(`Icing{tier}`, IcingHeight, radius + 0.05, y + TierHeight - 0.05, icing)
		y += TierHeight + IcingHeight - 0.05
		if tier < look.tiers then
			radius *= 0.7
		end
	end
	local top = y -- top of the icing
	local glowing = Enum.Material.Neon

	-- Points round the top, `count` of them, `inset` studs in from the edge.
	local function ring(
		count: number,
		inset: number,
		fn: (i: number, x: number, z: number, angle: number) -> ()
	)
		for i = 1, count do
			local angle = (i - 1) / count * math.pi * 2
			fn(i, math.cos(angle) * (radius - inset), math.sin(angle) * (radius - inset), angle)
		end
	end

	if look.topping == "Candy" then
		ring(6, 0.35, function(i, x, z)
			local color = if i % 2 == 0 then topping else icing
			part("Candy", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), CFrame.new(x, top + 0.15, z), color)
		end)
	elseif look.topping == "Fangs" then
		-- Teeth hanging over the edge, all the way round.
		ring(8, -0.05, function(_, x, z, angle)
			part(
				"Fang",
				Enum.PartType.Block,
				Vector3.new(0.18, 0.55, 0.18),
				CFrame.new(x, top - 0.3, z) * CFrame.Angles(0, -angle, 0),
				topping
			)
		end)
	elseif look.topping == "Drips" then
		ring(7, -0.05, function(i, x, z)
			local length = 0.35 + (i % 3) * 0.2
			part(
				"Drip",
				Enum.PartType.Block,
				Vector3.new(0.2, length, 0.2),
				CFrame.new(x, top - length / 2, z),
				topping,
				glowing
			)
		end)
	elseif look.topping == "Stitches" then
		for i = -1, 1 do
			part(
				"Stitch",
				Enum.PartType.Block,
				Vector3.new(0.12, 0.08, radius * 1.5),
				CFrame.new(i * 0.45, top + 0.04, 0),
				topping
			)
			part(
				"Stitch",
				Enum.PartType.Block,
				Vector3.new(0.5, 0.08, 0.12),
				CFrame.new(i * 0.45, top + 0.06, (i % 2 - 0.5) * 0.6),
				topping
			)
		end
	elseif look.topping == "Runes" then
		ring(5, 0.4, function(_, x, z, angle)
			part(
				"Rune",
				Enum.PartType.Block,
				Vector3.new(0.3, 0.06, 0.3),
				CFrame.new(x, top + 0.03, z) * CFrame.Angles(0, angle + math.rad(45), 0),
				topping,
				glowing
			)
		end)
		part(
			"Candle",
			Enum.PartType.Block,
			Vector3.new(0.2, 0.7, 0.2),
			CFrame.new(0, top + 0.35, 0),
			Color3.fromRGB(30, 20, 30)
		)
		part(
			"Flame",
			Enum.PartType.Ball,
			Vector3.new(0.22, 0.3, 0.22),
			CFrame.new(0, top + 0.85, 0),
			topping,
			glowing
		)
	elseif look.topping == "Bones" then
		for _, turn in { 45, -45 } do
			local frame = CFrame.new(0, top + 0.15, 0) * CFrame.Angles(0, math.rad(turn), 0)
			part("Bone", Enum.PartType.Block, Vector3.new(1.3, 0.18, 0.18), frame, topping)
			for _, side in { -0.65, 0.65 } do
				part(
					"Knuckle",
					Enum.PartType.Ball,
					Vector3.new(0.3, 0.3, 0.3),
					frame * CFrame.new(side, 0, 0),
					topping
				)
			end
		end
	elseif look.topping == "Bubbles" then
		local spots = {
			{ 0, 0, 0.45 },
			{ 0.4, 0.2, 0.3 },
			{ -0.35, -0.3, 0.35 },
			{ -0.2, 0.45, 0.22 },
			{ 0.3, -0.4, 0.2 },
		}
		for _, spot in spots do
			local size = spot[3]
			part(
				"Bubble",
				Enum.PartType.Ball,
				Vector3.new(size, size, size),
				CFrame.new(spot[1], top + size / 2, spot[2]),
				topping,
				glowing
			)
		end
	elseif look.topping == "Moon" then
		-- A crescent: a glowing ball with a dark one biting into it.
		part(
			"Moon",
			Enum.PartType.Ball,
			Vector3.new(0.9, 0.9, 0.3),
			CFrame.new(0, top + 0.6, 0),
			topping,
			glowing
		)
		part(
			"Shadow",
			Enum.PartType.Ball,
			Vector3.new(0.8, 0.8, 0.34),
			CFrame.new(0.25, top + 0.68, 0),
			sponge
		)
	end

	if look.glow then
		local light = Instance.new("PointLight")
		light.Color = rgb(look.glow)
		light.Range = 10 * scale
		light.Brightness = 1
		light.Shadows = false
		light.Parent = plate
	end
	return model
end

-- A Roblox Tool holding a small copy of the cake, for the hotbar. The plate is the Handle and
-- everything else is welded to it.
function CakeModel.tool(itemId: string, name: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Click in your mansion to set it out"
	tool:SetAttribute("CakeId", itemId)
	local model = CakeModel.build(itemId, 0.45)
	local handle = model.PrimaryPart :: BasePart
	handle.Name = "Handle"
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			if child ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = child
				weld.Parent = child
			end
		end
		child.Parent = tool
	end
	model:Destroy()
	-- Held flat in front of the hand.
	tool.Grip = CFrame.new(0, 0, -0.6)
	return tool
end

return CakeModel
