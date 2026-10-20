--!strict
-- Builds a cake from its look (Config/Cakes.Looks): a plate, 1 to 3 tiers of sponge with
-- icing, and a topping that says what it is (fangs on Fang Fudge, bones on the Bone Marrow
-- Mousse, a moon on the Eclipse Éclair), with piped cream round every tier and sprinkles.
-- The same model sits on the mansion floor and in your hand (CakeModel.tool).
--
-- Every part is placed relative to an invisible, unrotated Root at the bottom middle, which
-- is the PrimaryPart (and the Tool's Handle). Roblox cylinders lie along X, so the discs are
-- turned upright; pivoting by Root keeps them upright.

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
-- Its PrimaryPart is Root.
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

	local root = part(
		"Root",
		Enum.PartType.Block,
		Vector3.new(0.4, 0.2, 0.4),
		CFrame.new(0, 0, 0),
		Color3.new(1, 1, 1)
	)
	root.Transparency = 1
	model.PrimaryPart = root

	local white = Color3.fromRGB(240, 240, 240)
	local plate = disc("Plate", 0.15, Radius + 0.45, 0, white)
	disc("PlateRim", 0.08, Radius + 0.55, 0.12, Color3.fromRGB(210, 200, 215))

	local sponge, icing, topping = rgb(look.sponge), rgb(look.icing), rgb(look.toppingColor)
	local cream = icing:Lerp(Color3.new(1, 1, 1), 0.45) -- piping, a lighter icing
	-- `count` beads round a circle of radius r at height y.
	local function beads(name: string, count: number, r: number, y: number, size: number, color: Color3)
		for i = 1, count do
			local angle = (i - 1) / count * math.pi * 2
			part(
				name,
				Enum.PartType.Ball,
				Vector3.one * size,
				CFrame.new(math.cos(angle) * r, y, math.sin(angle) * r),
				color
			)
		end
	end

	local y, radius = 0.2, Radius
	local tiers = math.clamp(look.tiers, 1, 3)
	for tier = 1, tiers do
		disc(`Tier{tier}`, TierHeight, radius, y, sponge)
		-- a band of filling round the middle, and icing that runs a little down the sides
		disc(`Filling{tier}`, 0.14, radius + 0.03, y + TierHeight * 0.45, icing:Lerp(sponge, 0.5))
		disc(`Icing{tier}`, IcingHeight, radius + 0.06, y + TierHeight - 0.05, icing)
		disc(`IcingRun{tier}`, 0.3, radius + 0.04, y + TierHeight - 0.3, icing)
		beads(
			`Piping{tier}`,
			math.floor(radius * 9),
			radius - 0.05,
			y + TierHeight + IcingHeight - 0.02,
			0.26,
			cream
		)
		beads(`Border{tier}`, math.floor(radius * 9), radius + 0.02, y + 0.06, 0.2, cream)
		y += TierHeight + IcingHeight - 0.05
		if tier < tiers then
			radius *= 0.7
		end
	end
	local top = y -- top of the icing
	local glowing = Enum.Material.Neon

	-- Sprinkles on the top tier (the same pattern every time, so every copy matches).
	local sprinkleColors = { cream, topping, sponge:Lerp(Color3.new(1, 1, 1), 0.3) }
	for i = 1, 10 do
		local angle = i * 2.4
		local r = (radius - 0.45) * math.sqrt((i % 5 + 0.5) / 5)
		part(
			"Sprinkle",
			Enum.PartType.Block,
			Vector3.new(0.22, 0.06, 0.07),
			CFrame.new(math.cos(angle) * r, top + 0.03, math.sin(angle) * r)
				* CFrame.Angles(0, angle * 1.7, 0),
			sprinkleColors[i % 3 + 1]
		)
	end

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
		-- A crescent standing up: a glowing disc with a dark one biting into it.
		part(
			"Moon",
			Enum.PartType.Cylinder,
			Vector3.new(0.12, 1, 1),
			CFrame.new(0, top + 0.6, 0) * CFrame.Angles(0, math.rad(90), 0),
			topping,
			glowing
		)
		part(
			"Shadow",
			Enum.PartType.Cylinder,
			Vector3.new(0.14, 0.85, 0.85),
			CFrame.new(0.25, top + 0.68, 0) * CFrame.Angles(0, math.rad(90), 0),
			sponge
		)
		beads("Star", 5, radius - 0.35, top + 0.1, 0.16, topping)
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

-- A Roblox Tool holding a small copy of the cake, for the hotbar. Root is the Handle and
-- everything else is welded to it.
function CakeModel.tool(itemId: string, name: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Click in your mansion to set it out"
	tool:SetAttribute("CakeId", itemId)
	local model = CakeModel.build(itemId, 0.38)
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
	-- Held upright on the palm, like a tray. A grip with no turn keeps the Handle upright (its
	-- -Z forward), so the grip only moves the cake a little down and out from the hand.
	tool.Grip = CFrame.new(0, 0.25, 0.7)
	return tool
end

return CakeModel
