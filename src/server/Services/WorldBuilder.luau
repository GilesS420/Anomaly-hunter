--!strict
-- Builds grey placeholder blocks for any part of the world that isn't in the place yet, so
-- the game is playable before the real models exist. Anything already built in Studio with
-- the same name wins: this never moves, changes or deletes what's there.
--   Workspace.Hub.Ground             the oval floor of the hub
--   Workspace.Hub.Plots.Plot1..8     mansion plots (each built one by one if missing)
--   Workspace.Hub.ZoneGates.<ZoneId> a glowing gate per zone
--   Workspace.Hub.ReturnPoint        where hunters land when they have no plot
--   Workspace.Hub.Landmarks.<Name>   Watcher Square, Collector, Trading Booth, Bakery, Workshop
--   Workspace.Zones.<ZoneId>         a floating island per zone (only if that zone folder is missing)
-- Positions and sizes come from Shared.Config.Layout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local World = require(script.Parent.Parent.World)

local WorldBuilder = {}

local GroundTop = 0.1 -- a little above a default baseplate (top at 0) so the two don't flicker
local GroundColor = Color3.fromRGB(56, 52, 62)
local PlotColor = Color3.fromRGB(86, 96, 82)
local LabelColor = Color3.fromRGB(235, 235, 235)

type Theme = { floor: Color3, floorMaterial: Enum.Material, wall: Color3, glow: Color3 }

-- Colours per zone id (gate, island floor, walls, exit).
local themes: { [string]: Theme } = {
	PumpkinGraveyard = {
		floor = Color3.fromRGB(84, 62, 44),
		floorMaterial = Enum.Material.Ground,
		wall = Color3.fromRGB(120, 72, 36),
		glow = Color3.fromRGB(255, 140, 40),
	},
	MurkyBayou = {
		floor = Color3.fromRGB(48, 70, 46),
		floorMaterial = Enum.Material.Mud,
		wall = Color3.fromRGB(40, 96, 60),
		glow = Color3.fromRGB(80, 220, 110),
	},
	AbandonedCarnival = {
		floor = Color3.fromRGB(62, 48, 80),
		floorMaterial = Enum.Material.Cobblestone,
		wall = Color3.fromRGB(96, 56, 130),
		glow = Color3.fromRGB(180, 90, 255),
	},
}
local defaultTheme: Theme = {
	floor = Color3.fromRGB(70, 70, 70),
	floorMaterial = Enum.Material.Slate,
	wall = Color3.fromRGB(100, 100, 100),
	glow = Color3.fromRGB(200, 200, 200),
}

local landmarkColors: { [string]: Color3 } = {
	WatcherSquare = Color3.fromRGB(90, 84, 100),
	Collector = Color3.fromRGB(110, 90, 70),
	TradingBooth = Color3.fromRGB(70, 100, 120),
	Bakery = Color3.fromRGB(150, 110, 90),
	Workshop = Color3.fromRGB(100, 100, 110),
}

local built: { string } = {} -- what was made this run, for the Output line

local function folderAt(parent: Instance, name: string, path: string): Instance
	local existing = World.find(parent, name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	table.insert(built, path)
	return folder
end

-- An anchored placeholder block. Parent it after setting everything else.
local function block(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Turns a part into a ghost: you can walk through it, clicks and touches go past it.
local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- Floating text above a part (one or two lines).
local function label(part: BasePart, title: string, subtitle: string?, height: number, maxDistance: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Adornee = part
	billboard.LightInfluence = 0
	billboard.MaxDistance = maxDistance
	billboard.Size = UDim2.fromOffset(260, if subtitle then 60 else 36)
	billboard.StudsOffset = Vector3.new(0, height, 0)
	local lines: { string } = if subtitle then { title, subtitle } else { title }
	for i, text in lines do
		local textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.Position = UDim2.fromScale(0, (i - 1) / #lines)
		textLabel.Size = UDim2.fromScale(1, 1 / #lines)
		textLabel.Font = if i == 1 then Enum.Font.GothamBold else Enum.Font.GothamMedium
		textLabel.Text = text
		textLabel.TextColor3 = LabelColor
		textLabel.TextScaled = true
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Parent = textLabel
		textLabel.Parent = billboard
	end
	billboard.Parent = part
end

-- Text painted on the front face of a flat upright part (gates and exits).
local function sign(part: BasePart, title: string, subtitle: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	local lines: { string } = if subtitle then { title, subtitle } else { title }
	for i, text in lines do
		local textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.AnchorPoint = Vector2.new(0.5, 0)
		textLabel.Position = UDim2.fromScale(0.5, 0.15 + (i - 1) * 0.2)
		textLabel.Size = UDim2.fromScale(0.9, if i == 1 then 0.18 else 0.12)
		textLabel.Font = if i == 1 then Enum.Font.GothamBlack else Enum.Font.GothamBold
		textLabel.Text = text
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextScaled = true
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = textLabel
		textLabel.Parent = gui
	end
	gui.Parent = part
end

-- The hub floor: an oval made of a long middle slab and a round end on each side
-- (Roblox cylinders are always round, so one part can't be an oval).
local function buildGround(hub: Instance)
	local size = Layout.Hub.GroundSize
	local center = Layout.Hub.Center
	local long, short = math.max(size.x, size.z), math.min(size.x, size.z)
	local ground = Instance.new("Model")
	ground.Name = "Ground"
	local middle = block(
		"Middle",
		Vector3.new(long - short, 1, short),
		CFrame.new(center.x, GroundTop - 0.5, center.z),
		GroundColor,
		Enum.Material.Slate
	)
	middle.Parent = ground
	for _, side in { -1, 1 } do
		-- Cylinder height runs along its X axis; turning it 90 degrees about Z lays it flat.
		-- The round ends sit 0.01 lower than the middle so the overlapping tops don't flicker.
		local cap = block(
			if side < 0 then "WestEnd" else "EastEnd",
			Vector3.new(1, short, short),
			CFrame.new(center.x + side * (long - short) / 2, GroundTop - 0.51, center.z)
				* CFrame.Angles(0, 0, math.pi / 2),
			GroundColor,
			Enum.Material.Slate
		)
		cap.Shape = Enum.PartType.Cylinder
		cap.Parent = ground
	end
	ground.PrimaryPart = middle
	ground.Parent = hub
	table.insert(built, "Hub.Ground")
end

local function buildPlots(hub: Instance)
	local plots = folderAt(hub, "Plots", "Hub.Plots")
	local made = {}
	for _, spot in Layout.Plots do
		if not World.find(plots, spot.name) then
			-- Yaw 0 looks toward -Z, yaw pi toward +Z: the front always faces the middle.
			local yaw = if spot.facing == 1 then math.pi else 0
			local plot = block(
				spot.name,
				Vector3.new(Layout.PlotSize.x, 1, Layout.PlotSize.z),
				CFrame.new(spot.x, 0.2, spot.z) * CFrame.Angles(0, yaw, 0),
				PlotColor,
				Enum.Material.Grass
			)
			plot.Parent = plots
			table.insert(made, spot.name)
		end
	end
	if #made > 0 and not table.find(built, "Hub.Plots") then
		table.insert(built, `Hub.Plots ({table.concat(made, ", ")})`)
	end
end

local function buildGates(hub: Instance)
	local gates = folderAt(hub, "ZoneGates", "Hub.ZoneGates")
	local size = Layout.GateSize
	for _, zone in Zones.List do
		local spot = Layout.Gates[zone.index]
		if zone.launch and spot and not World.find(gates, zone.id) then
			local position = Vector3.new(spot.x, GroundTop + size.height / 2, spot.z)
			local theme = themes[zone.id] or defaultTheme
			-- lookAt west: the gate's front (and its sign) faces the hub.
			local gate = block(
				zone.id,
				Vector3.new(size.width, size.height, size.thickness),
				CFrame.lookAt(position, position - Vector3.xAxis),
				theme.glow,
				Enum.Material.Neon
			)
			gate.CanCollide = false
			gate.CanQuery = false
			gate.Transparency = 0.2
			sign(
				gate,
				zone.name,
				if zone.wing == "Foyer" then "Walk in to hunt!" else `Needs the {zone.wing}`
			)
			gate.Parent = gates
			table.insert(built, `Hub.ZoneGates.{zone.id}`)
		end
	end
end

local function buildReturnPoint(hub: Instance)
	local spot = Layout.ReturnPoint
	local point = block(
		"ReturnPoint",
		Vector3.new(4, 1, 4),
		CFrame.new(spot.x, GroundTop + 0.5, spot.z),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic
	)
	point.Transparency = 1
	ghost(point)
	point.Parent = hub
	table.insert(built, "Hub.ReturnPoint")
end

local function buildLandmarks(hub: Instance)
	local landmarks = folderAt(hub, "Landmarks", "Hub.Landmarks")
	for _, spot in Layout.Landmarks do
		if not World.find(landmarks, spot.name) then
			local color = landmarkColors[spot.name] or Color3.fromRGB(100, 100, 100)
			local position = Vector3.new(spot.x, GroundTop + spot.height / 2, spot.z)
			local part: Part
			if spot.name == "WatcherSquare" then
				-- A flat round plaza (cylinder lying down, height along X).
				part = block(
					spot.name,
					Vector3.new(spot.height, spot.depth, spot.width),
					CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
					color,
					Enum.Material.Cobblestone
				)
				part.Shape = Enum.PartType.Cylinder
				label(part, spot.label, nil, 8, 200)
			else
				part = block(
					spot.name,
					Vector3.new(spot.width, spot.height, spot.depth),
					CFrame.new(position),
					color,
					Enum.Material.WoodPlanks
				)
				label(part, spot.label, nil, spot.height / 2 + 4, 250)
			end
			part.Parent = landmarks
			table.insert(built, `Hub.Landmarks.{spot.name}`)
		end
	end
end

-- A floating island for a zone. Zone-local (x, z) is an offset from Layout.Zones[index];
-- +z runs away from the arrival side.
local function buildZone(zonesFolder: Instance, zone: Zones.Zone)
	local center = Layout.Zones[zone.index]
	if not center then
		return
	end
	local theme = themes[zone.id] or defaultTheme
	local top = center.y -- floor top
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(center.x + x, y, center.z + z)
	end

	local folder = Instance.new("Folder")
	folder.Name = zone.id

	local sizeX, sizeZ = Layout.ZoneSize.x, Layout.ZoneSize.z
	local floor =
		block("Floor", Vector3.new(sizeX, 2, sizeZ), at(0, top - 1, 0), theme.floor, theme.floorMaterial)
	floor.Parent = folder

	-- Four see-through walls so nobody falls off the island.
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	local height = Layout.ZoneWallHeight
	local wallY = top + height / 2
	local wallSpecs = {
		{ name = "Front", size = Vector3.new(sizeX + 4, height, 2), cframe = at(0, wallY, -(sizeZ / 2 + 1)) },
		{ name = "Back", size = Vector3.new(sizeX + 4, height, 2), cframe = at(0, wallY, sizeZ / 2 + 1) },
		{ name = "Left", size = Vector3.new(2, height, sizeZ), cframe = at(-(sizeX / 2 + 1), wallY, 0) },
		{ name = "Right", size = Vector3.new(2, height, sizeZ), cframe = at(sizeX / 2 + 1, wallY, 0) },
	}
	for _, spec in wallSpecs do
		local wall = block(spec.name, spec.size, spec.cframe, theme.wall, Enum.Material.Glass)
		wall.Transparency = 0.5
		wall.CastShadow = false
		wall.Parent = walls
	end
	walls.Parent = folder

	-- Where monsters wander: invisible, top flush with the floor.
	local roam = Layout.ZoneRoamArea
	local roamArea = block(
		"RoamArea",
		Vector3.new(roam.width, 1, roam.depth),
		at(roam.x, top - 0.5, roam.z),
		theme.glow,
		Enum.Material.SmoothPlastic
	)
	roamArea.Transparency = 1
	ghost(roamArea)
	roamArea.Parent = folder

	-- Where hunters appear: a flat glowing pad.
	local arrivalSpot = Layout.ZoneArrival
	local arrival = block(
		"Arrival",
		Vector3.new(10, 0.4, 10),
		at(arrivalSpot.x, top + 0.2, arrivalSpot.z),
		theme.glow,
		Enum.Material.Neon
	)
	arrival.Transparency = 0.5
	ghost(arrival)
	label(arrival, "Arrival", nil, 4, 60)
	arrival.Parent = folder

	-- The way home: an upright portal facing into the zone (+z). Touching it is wired by HuntService.
	local exitSpot = Layout.ZoneExit
	local exitPosition = at(exitSpot.x, top + 6, exitSpot.z).Position
	local exit = block(
		"Exit",
		Vector3.new(10, 12, 1),
		CFrame.lookAt(exitPosition, exitPosition + Vector3.zAxis),
		theme.glow,
		Enum.Material.Neon
	)
	exit.CanCollide = false
	exit.CanQuery = false -- never blocks a press on a monster behind it
	exit.Transparency = 0.2
	label(exit, "Exit — bring your catch home", nil, 8, 120)
	exit.Parent = folder

	folder.Parent = zonesFolder
	table.insert(built, `Zones.{zone.id}`)
end

function WorldBuilder.start()
	table.clear(built)
	local hub = folderAt(workspace, "Hub", "Hub")
	if not World.find(hub, "Ground") then
		buildGround(hub)
	end
	buildPlots(hub)
	buildGates(hub)
	if not World.find(hub, "ReturnPoint") then
		buildReturnPoint(hub)
	end
	buildLandmarks(hub)

	local zonesFolder = folderAt(workspace, "Zones", "Zones")
	for _, zone in Zones.List do
		if zone.launch and not World.find(zonesFolder, zone.id) then
			buildZone(zonesFolder, zone)
		end
	end

	if #built > 0 then
		print(`WorldBuilder: built {table.concat(built, ", ")}`)
	else
		print("WorldBuilder: everything was already in the place, nothing built")
	end
end

return WorldBuilder
