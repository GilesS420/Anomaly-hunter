--!strict
-- Builds a recipe (a list of parts as data, see Config/Rooms and Config/Landmarks) into real
-- parts. Used for the mansion rooms and the hub landmarks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rooms = require(ReplicatedStorage.Shared.Config.Rooms)

local Recipe = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Walk-through decor: no bumping, clicking or shadows.
local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- Text painted on the part's front face (name plates, shop signs).
local function paint(part: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, 0.1)
	label.Size = UDim2.fromScale(1, 0.8)
	label.Font = Enum.Font.LuckiestGuy
	label.Text = text
	label.TextColor3 = Color3.fromRGB(45, 30, 15)
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = part
end

-- Builds one part of a recipe into `parent`, placed relative to `base`.
function Recipe.buildPart(spec: Rooms.Part, base: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
	local rot = spec.rot or { 0, 0, 0 }
	part.CFrame = base
		* CFrame.new(spec.at[1], spec.at[2], spec.at[3])
		* CFrame.fromOrientation(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
	part.Color = rgb(spec.color)
	part.Material = (Enum.Material :: any)[spec.material]
	part.Shape = (Enum.PartType :: any)[spec.shape or "Block"]
	part.Transparency = spec.transparency or 0
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if not spec.solid then
		ghost(part)
	end
	if spec.light then
		local light = Instance.new("PointLight")
		light.Color = rgb(spec.light.color)
		light.Range = spec.light.range
		light.Brightness = spec.light.brightness
		light.Shadows = true
		light.Parent = part
	end
	if spec.text then
		paint(part, spec.text)
	end
	part.Parent = parent
	return part
end

-- Builds every part of the recipe into `parent`, placed relative to `base`.
function Recipe.build(parts: { Rooms.Part }, base: CFrame, parent: Instance)
	for _, spec in parts do
		Recipe.buildPart(spec, base, parent)
	end
end

return Recipe
