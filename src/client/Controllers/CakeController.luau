--!strict
-- Shows how far a placed cake reaches: hover the mouse over a cake (or tap it on a phone)
-- and a glowing circle appears on the floor round it. Only monsters inside that circle come
-- for a bite (server/Services/CakeService, numbers in Config/Cakes.Reach). The server puts
-- the cakes in Workspace.Cakes with a "Reach" attribute (studs) and an invisible Hitbox.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CakeController = {}

local AreaColor = Color3.fromRGB(255, 150, 220)
local TapShowSeconds = 4 -- a tapped circle stays this long
local EdgeBeads = 40

-- The circle: a see-through disc with a ring of glowing beads round its edge.
local function buildArea(): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "CakeReach"
	local disc = Instance.new("Part")
	disc.Name = "Disc"
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.Neon
	disc.Color = AreaColor
	disc.Transparency = 0.82
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Parent = model
	for i = 1, EdgeBeads do
		local bead = Instance.new("Part")
		bead.Name = `Edge{i}`
		bead.Shape = Enum.PartType.Ball
		bead.Size = Vector3.one * 0.35
		bead.Material = Enum.Material.Neon
		bead.Color = AreaColor
		bead.Anchored = true
		bead.CanCollide = false
		bead.CanQuery = false
		bead.CanTouch = false
		bead.CastShadow = false
		bead.Parent = model
	end
	model.PrimaryPart = disc
	return model, disc
end

-- The cake model a part belongs to, if it's a placed cake.
local function cakeOf(part: Instance?): Model?
	local cakes = workspace:FindFirstChild("Cakes")
	local current = part
	while current and cakes and current ~= workspace do
		if current.Parent == cakes and current:IsA("Model") then
			return current
		end
		current = current.Parent
	end
	return nil
end

function CakeController.start()
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()
	local area, disc = buildArea()
	local shown: Model? = nil
	local tappedUntil = 0
	local tapped: Model? = nil

	local function show(cake: Model?)
		if cake == shown then
			return
		end
		shown = cake
		local reach = if cake then cake:GetAttribute("Reach") else nil
		local root = if cake then cake.PrimaryPart else nil
		if not cake or not root or typeof(reach) ~= "number" then
			area.Parent = nil
			shown = nil
			return
		end
		local floor = root.Position + Vector3.new(0, 0.06, 0)
		disc.Size = Vector3.new(0.1, reach * 2, reach * 2)
		disc.CFrame = CFrame.new(floor) * CFrame.Angles(0, 0, math.rad(90))
		for i = 1, EdgeBeads do
			local angle = (i - 1) / EdgeBeads * math.pi * 2
			local bead = area:FindFirstChild(`Edge{i}`) :: BasePart
			bead.CFrame =
				CFrame.new(floor + Vector3.new(math.cos(angle) * reach, 0.15, math.sin(angle) * reach))
		end
		area.Parent = workspace
	end

	-- Phones: tap a cake to see its circle for a few seconds.
	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if processed then
			return
		end
		local camera = workspace.CurrentCamera
		local ray = camera:ViewportPointToRay(position.X, position.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 300)
		tapped = cakeOf(if hit then hit.Instance else nil)
		tappedUntil = os.clock() + TapShowSeconds
	end)

	RunService.RenderStepped:Connect(function()
		local hovered = if UserInputService.MouseEnabled then cakeOf(mouse.Target) else nil
		local current = hovered or (if os.clock() < tappedUntil then tapped else nil)
		if current and not current.Parent then
			current = nil -- eaten up while we looked
		end
		show(current)
	end)
end

return CakeController
