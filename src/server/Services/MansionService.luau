--!strict
-- Every player's mansion, built on their plot from placeholder blocks once their save has
-- loaded and they have a plot:
--   Workspace.Mansions.<PlotName>     a Model made here (removed when the owner leaves)
--     Wings       a room per owned wing (walls, doors, lanterns, see Config/Rooms), or a
--                 floor, four corner pillars and a name label for wings without a recipe yet
--     NextWing    a see-through floor plus a sign on that wing's boarded door: hold its
--                 prompt to buy the wing
--     OwnerSign   "<name>'s Mansion" and "3/8 monsters", floating above the Foyer
--     WorthSign   a wooden sign left of the front gate: what all the monsters inside are worth
--     Trophy      a stone stand right of the front gate with the owner's best monster on top
--     Monsters    the owner's caught monsters, roaming around the owned wings (each label
--                 says how familiar it is, see CareService)
-- Wings are bought in order (the Foyer is free). Each one makes room for more monsters and
-- opens a new zone. Nothing here needs building in Studio.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(ReplicatedStorage.Shared.Util.Care)
local CareConfig = require(ReplicatedStorage.Shared.Config.Care)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Hunt = require(ReplicatedStorage.Shared.Util.Hunt)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Mansion = require(ReplicatedStorage.Shared.Util.Mansion)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Roam = require(ReplicatedStorage.Shared.Util.Roam)
local Rooms = require(ReplicatedStorage.Shared.Config.Rooms)
local Storage = require(ReplicatedStorage.Shared.Util.Storage)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Weight = require(ReplicatedStorage.Shared.Util.Weight)
local WeightConfig = require(ReplicatedStorage.Shared.Config.Weight)
local Wings = require(ReplicatedStorage.Shared.Config.Wings)
local DataService = require(script.Parent.DataService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)
local PlotService = require(script.Parent.PlotService)
local Recipe = require(script.Parent.Parent.Recipe)
local RoamService = require(script.Parent.RoamService)
local World = require(script.Parent.Parent.World)

local MansionService = {}

type State = {
	player: Player,
	plot: PlotService.Plot,
	model: Model,
	wings: Folder, -- owned wing parts plus the NextWing sign; only what changed is rebuilt
	built: { [string]: { [string]: Built } }, -- recipe parts per wing, by part name
	monsters: Folder,
	countLabel: TextLabel, -- "3/8 monsters" on the owner sign
	worthLabels: { TextLabel }, -- the amount on both faces of the worth sign
	trophy: BasePart, -- the stand's top; the best monster stands on it
	trophyKey: string?, -- what the monster on the stand was built from (uid and look)
	group: string, -- RoamService group shared by this mansion's monsters
	rects: { Roam.Rect }, -- floor areas the monsters may roam (one per owned wing)
	generation: number, -- goes up whenever the monsters are cleared, cancelling waiting spawns
}

-- A room part as it stands in the world, with the recipe key (Rooms.key) it was built from.
type Built = { key: string, part: BasePart }

local MonsterSpeed = 4 -- studs per second; mansion monsters stroll, zone monsters hurry
local PillarHeight = 12
local EdgeInset = 1.5 -- keeps roaming orbs off the floor edges and away from the pillars
local MaxWings = #Wings.List
local SpawnRetrySeconds = 1 -- no free spot right now: try again after the others moved on
-- Where the worth sign and the trophy stand go: either side of the path to the Foyer gate,
-- plot-local (see Layout.Wings.Foyer and Layout.PlotSpawn).
local WorthSignSpot = { x = -13, z = -37 }
local TrophySpot = { x = 13, z = -37 }

local wingColors: { [string]: Color3 } = {
	Foyer = Color3.fromRGB(150, 110, 80),
	Library = Color3.fromRGB(70, 95, 160),
	Ballroom = Color3.fromRGB(160, 65, 90),
	Attic = Color3.fromRGB(125, 105, 90),
	Crypt = Color3.fromRGB(95, 115, 105),
	Garden = Color3.fromRGB(80, 155, 85),
}

local mansions: { [Player]: State } = {}
local buying: { [Player]: boolean } = {} -- one purchase at a time per player
local random = Random.new()

-- An anchored placeholder block.
local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.WoodPlanks
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Turns a part into scenery only: no bumping, no touching, never in the way of a press.
local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- One line of text that scales with its box, with a dark outline so it reads on any background.
local function textLine(parent: Instance, text: string, color: Color3, y: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- A floating label sized in studs, so it shrinks with distance like a real sign.
local function billboard(
	adornee: Instance,
	widthStuds: number,
	heightStuds: number,
	maxDistance: number
): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(widthStuds, heightStuds)
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance
	gui.Parent = adornee
	return gui
end

-- An invisible point to hang a label on, at a world position inside part.
local function anchorAt(part: BasePart, worldPosition: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "LabelAnchor"
	attachment.Position = part.CFrame:PointToObjectSpace(worldPosition)
	attachment.Parent = part
	return attachment
end

-- Height of the top of every wing floor (half a stud above the plot).
local function floorTop(plot: PlotService.Plot): number
	return plot.frame.Position.Y + 0.5
end

-- World centre of a wing's floor at the given height. Plots only turn 0 or 180 degrees, so
-- the floor stays lined up with world X/Z (width along X, depth along Z).
local function wingCentre(plot: PlotService.Plot, wingId: string, y: number): Vector3
	local spot = Layout.Wings[wingId]
	local point = plot.frame:PointToWorldSpace(Vector3.new(spot.x, 0, spot.z))
	return Vector3.new(point.X, y, point.Z)
end

-- Middle of a wing's front edge (the side facing the plot's front door) at the given height.
local function wingFront(plot: PlotService.Plot, wingId: string, inset: number, y: number): Vector3
	local spot = Layout.Wings[wingId]
	local point = plot.frame:PointToWorldSpace(Vector3.new(spot.x, 0, spot.z - spot.depth / 2 + inset))
	return Vector3.new(point.X, y, point.Z)
end

-- Floor areas monsters can roam: every owned wing that has a spot in the layout.
local function roamRects(state: State, wingsOwned: number): { Roam.Rect }
	local rects = {}
	local top = floorTop(state.plot)
	for _, wing in Mansion.ownedWings(wingsOwned) do
		local spot = Layout.Wings[wing.id]
		if spot then
			local centre = wingCentre(state.plot, wing.id, top)
			table.insert(
				rects,
				Roam.rect(centre.X, centre.Z, spot.width - 2 * EdgeInset, spot.depth - 2 * EdgeInset, top)
			)
		end
	end
	return rects
end

-- A wing the player owns: a full room when it has a recipe in Config/Rooms, otherwise still a
-- placeholder (a floor, corner pillars and the wing's name).
local function buildOwnedWing(state: State, wing: Wings.Wing, owned: { [string]: boolean })
	local spot = Layout.Wings[wing.id]
	if not spot then
		warn(`MansionService: no layout spot for the {wing.id} wing (add it to Layout.Wings)`)
		return
	end
	local top = floorTop(state.plot)
	local existing = state.wings:FindFirstChild(wing.id)
	local recipe = Rooms.ByWing[wing.id]
	if recipe then
		-- Only parts that are new or look different get built, and only parts that are gone
		-- get removed (e.g. the boards on a door when the wing behind it is bought). Everything
		-- else stays put, so buying a wing never makes the rest of the mansion blink.
		local folder = existing or Instance.new("Folder")
		folder.Name = wing.id
		local base = CFrame.new(wingCentre(state.plot, wing.id, top)) * state.plot.frame.Rotation
		local old = state.built[wing.id] or {}
		local now: { [string]: Built } = {}
		for _, spec in recipe(spot.width, spot.depth, owned) do
			local key = Rooms.key(spec)
			local was = old[spec.name]
			if was and was.key == key and was.part.Parent == folder then
				now[spec.name] = was
				old[spec.name] = nil
			else
				now[spec.name] = { key = key, part = Recipe.buildPart(spec, base, folder) }
			end
		end
		for _, gone in old do
			gone.part:Destroy()
		end
		state.built[wing.id] = now
		folder.Parent = state.wings
		return
	end
	if existing then
		return -- a placeholder looks the same whichever wings are owned
	end
	local color = wingColors[wing.id] or Color3.fromRGB(140, 140, 140)
	local folder = Instance.new("Folder")
	folder.Name = wing.id

	local centre = wingCentre(state.plot, wing.id, top - 0.5)
	local floor = block("Floor", Vector3.new(spot.width, 1, spot.depth), CFrame.new(centre), color, folder)

	-- Thin pillars at the corners so the wing reads as a room.
	for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		local x = centre.X + corner[1] * (spot.width / 2 - 0.5)
		local z = centre.Z + corner[2] * (spot.depth / 2 - 0.5)
		block(
			"Pillar",
			Vector3.new(1, PillarHeight, 1),
			CFrame.new(x, top + PillarHeight / 2, z),
			color:Lerp(Color3.new(0, 0, 0), 0.3),
			folder
		)
	end

	local gui = billboard(anchorAt(floor, wingFront(state.plot, wing.id, 1, top + 8)), 14, 3, 150)
	textLine(gui, wing.id, Color3.new(1, 1, 1), 0, 1)
	folder.Parent = state.wings
end

-- Text on the front of a sign board.
local function signText(board: BasePart, title: string, subtitle: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	textLine(gui, title, Color3.new(1, 1, 1), 0.08, 0.45)
	textLine(gui, subtitle, Color3.fromRGB(255, 220, 120), 0.55, 0.35)
	gui.Parent = board
end

local buyNext: (state: State, who: Player) -> ()

-- The wing that can be bought next: a see-through floor and a sign with a buy prompt.
local function buildNextWing(state: State, wing: Wings.Wing)
	local spot = Layout.Wings[wing.id]
	if not spot then
		return
	end
	local top = floorTop(state.plot)
	local color = wingColors[wing.id] or Color3.fromRGB(140, 140, 140)
	local folder = Instance.new("Folder")
	folder.Name = "NextWing"
	folder:SetAttribute("WingId", wing.id)

	local floor = block(
		"Floor",
		Vector3.new(spot.width, 1, spot.depth),
		CFrame.new(wingCentre(state.plot, wing.id, top - 0.5)),
		color,
		folder
	)
	floor.Transparency = 0.7
	ghost(floor)

	-- The sign hangs on the wing's boarded-up door (in the room that leads to it), facing into
	-- that room, so it's where the owner walks to. Without a door it stands at the wing's front
	-- edge, facing the plot's front door.
	local plate = state.wings:FindFirstChild(`{wing.id}Plate`, true)
	local board: Part
	if plate and plate:IsA("BasePart") then
		board = block(
			"Sign",
			Vector3.new(6, 3.4, 0.3),
			plate.CFrame * CFrame.new(0, -6.3, -0.65),
			Color3.fromRGB(60, 45, 35),
			folder
		)
		board.CanCollide = false
	else
		local signPosition = wingFront(state.plot, wing.id, 1, top + 3.5)
		board = block(
			"Sign",
			Vector3.new(10, 6, 0.5),
			CFrame.lookAt(signPosition, signPosition + state.plot.frame.LookVector),
			Color3.fromRGB(60, 45, 35),
			folder
		)
	end
	board.Material = Enum.Material.Wood

	if wing.launch then
		local zone = if wing.unlocksZone then Hunt.zoneByIndex(wing.unlocksZone) else nil
		local opens = if zone and zone.launch then ` · opens {zone.name}` else ""
		signText(board, `{wing.id} wing`, `{Format.money(wing.price)}{opens}`)

		-- Hold E, click or tap the prompt to buy (works with mouse, keyboard, touch and gamepad).
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BuyPrompt"
		prompt.ActionText = `Buy {wing.id}`
		prompt.ObjectText = Format.money(wing.price)
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(who)
			buyNext(state, who)
		end)
		prompt.Parent = board
	else
		signText(board, `{wing.id} — coming soon`, "Opens in a future update")
	end
	folder.Parent = state.wings
end

-- Brings the wing parts and the next-wing sign in line with the wings owned, and updates
-- where monsters may roam. Rooms already standing are kept; only what changed is rebuilt.
local function buildWings(state: State, wingsOwned: number)
	-- The client shuts the zone gates this player can't enter yet (client/GateController).
	state.player:SetAttribute("WingsOwned", wingsOwned)
	local owned: { [string]: boolean } = {}
	for _, wing in Mansion.ownedWings(wingsOwned) do
		owned[wing.id] = true
	end
	local nextWing = Mansion.nextWing(wingsOwned)
	-- The old next-wing sign goes first: the room bought in its place is built right after,
	-- in the same frame, so nothing blinks.
	local sign = state.wings:FindFirstChild("NextWing")
	if sign and not (nextWing and sign:GetAttribute("WingId") == nextWing.id) then
		sign:Destroy()
		sign = nil
	end
	-- Wings no longer owned (only the Studio /wings command takes wings away).
	for _, child in state.wings:GetChildren() do
		if child ~= sign and not owned[child.Name] then
			child:Destroy()
			state.built[child.Name] = nil
		end
	end
	for _, wing in Mansion.ownedWings(wingsOwned) do
		buildOwnedWing(state, wing, owned)
	end
	if nextWing and not sign then
		buildNextWing(state, nextWing)
	end
	state.rects = roamRects(state, wingsOwned)
	RoamService.setRectsForGroup(state.group, state.rects)
end

local updateShowcase: (state: State) -> ()

local function updateSign(state: State)
	local data = DataService.get(state.player)
	if data then
		state.countLabel.Text = `{#data.monsters}/{Mansion.capacity(data.wingsOwned)} monsters`
	end
	updateShowcase(state)
end

-- How wide a mansion monster walks (a Titan is drawn bigger, see MonsterModel.roamRadius).
local function roamRadiusOf(caught: Value.CaughtMonster): number
	return MonsterModel.roamRadius(MonsterModel.radius(caught.size, caught.monsterId, caught.kg))
end

-- What the orb shows: name, size, weight, rarity, effects, catch variant, Familiarity and
-- what it sells for.
local function infoFor(player: Player, caught: Value.CaughtMonster, rarity: string): MonsterModel.Info
	local data = DataService.get(player)
	local ok, value = pcall(Value.sellValue, caught, if data then data.wingsOwned else 1)
	return {
		monsterId = caught.monsterId,
		rarity = rarity,
		size = caught.size,
		kg = caught.kg,
		roamRadius = roamRadiusOf(caught),
		variant = caught.variant,
		effects = Value.resolveEffects(caught.effects), -- combos show as one
		owner = player.DisplayName,
		status = Care.status(caught),
		value = if ok then value else 0,
	}
end

-- Puts one saved monster into the mansion as a roaming orb.
local function spawnMonster(state: State, caught: Value.CaughtMonster)
	if mansions[state.player] ~= state then
		return -- the owner left (or the mansion was rebuilt)
	end
	local monster = Monsters[caught.monsterId]
	if not monster then
		-- A monster removed from the game: it stays in the save, it just isn't shown.
		warn(`MansionService: unknown monster "{caught.monsterId}" in {state.player.Name}'s save, not shown`)
		return
	end
	if #state.rects == 0 then
		return -- no floors to stand on (layout missing; already warned)
	end
	local radius = roamRadiusOf(caught)
	local spot = Roam.findFreePoint(state.rects, radius, RoamService.bodies(state.group), random)
	if not spot then
		local data = DataService.get(state.player)
		local overfull = data ~= nil and #data.monsters > Mansion.capacity(data.wingsOwned)
		if not overfull then
			-- Crowded for a moment (the others' paths block every spot): wait for them to move
			-- on and try again, so it never appears inside another orb.
			local generation = state.generation
			task.delay(SpawnRetrySeconds, function()
				local now = DataService.get(state.player)
				if state.generation == generation and now and table.find(now.monsters, caught) then
					spawnMonster(state, caught)
				end
			end)
			return
		end
		-- Only when the mansion holds more than it should (e.g. after /wings lowered it in Studio):
		-- place it anyway rather than hide a monster the player owns.
		warn(
			`MansionService: {state.player.Name}'s mansion is overfull, {caught.monsterId} may overlap others`
		)
		local first = state.rects[1]
		spot = Roam.randomPoint(state.rects, radius, random)
			or { x = (first.minX + first.maxX) / 2, y = first.y, z = (first.minZ + first.maxZ) / 2 }
	end
	local at: Roam.Point = spot :: Roam.Point -- set on every path above

	local model = MonsterModel.build(infoFor(state.player, caught, monster.rarity))
	model:SetAttribute("OwnerId", state.player.UserId)
	model:SetAttribute("Uid", caught.uid)
	RoamService.add(model, {
		rects = state.rects,
		radius = radius,
		speed = MonsterSpeed,
		group = state.group,
		at = Vector3.new(at.x, at.y + radius + 0.5, at.z),
	})
	model.Parent = state.monsters
end

-- The worth sign and the trophy stand out front: the total value of the mansion's monsters,
-- and the most valuable one standing on the stand. Called whenever monsters come, go, grow
-- or get more familiar.
function updateShowcase(state: State)
	local data = DataService.get(state.player)
	if not data or mansions[state.player] ~= state then
		return
	end
	local values = {}
	for index, caught in data.monsters do
		local ok, value = pcall(Value.sellValue, caught, data.wingsOwned)
		values[index] = if ok then value else 0
	end
	local total, best = Mansion.worth(values)
	for _, label in state.worthLabels do
		label.Text = Format.money(total)
	end

	local caught = if best then data.monsters[best] else nil
	local monster = if caught then Monsters[caught.monsterId] else nil
	local key = if caught and monster
		then `{caught.uid}|{caught.size}|{caught.kg}|{caught.variant}|{table.concat(caught.effects, ",")}`
		else nil
	local old = state.trophy.Parent and state.trophy.Parent:FindFirstChild("BestMonster")
	if key == state.trophyKey and old then
		if old:IsA("Model") and caught and monster then
			MonsterModel.refresh(old, infoFor(state.player, caught, monster.rarity))
		end
		return
	end
	state.trophyKey = key
	if old then
		old:Destroy()
	end
	if not caught or not monster then
		return -- an empty mansion: the stand waits
	end
	local model = MonsterModel.build(infoFor(state.player, caught, monster.rarity))
	model.Name = "BestMonster"
	local body = model.PrimaryPart :: BasePart
	body.CanQuery = false -- just for show: no catching or picking up from the stand
	local radius = MonsterModel.radius(caught.size, caught.monsterId, caught.kg)
	local top = state.trophy.Position + Vector3.new(0, state.trophy.Size.Y / 2 + radius + 0.2, 0)
	model:PivotTo(CFrame.new(top) * state.trophy.CFrame.Rotation)
	model.Parent = state.trophy.Parent
end

-- Removes every monster orb (stopping their roaming right away, not when Destroying fires).
local function clearMonsters(state: State)
	state.generation += 1
	for _, child in state.monsters:GetChildren() do
		if child:IsA("Model") then
			RoamService.remove(child)
		end
		child:Destroy()
	end
end

local function spawnAll(state: State, data: DataService.Data)
	clearMonsters(state)
	for _, caught in data.monsters do
		spawnMonster(state, caught)
	end
end

-- Fixes up a save before the mansion uses it: wings in range, every monster has a uid
-- (saves from before uids existed) and a list of effects. Brings every monster's Familiarity up to date; when the player
-- just joined and Config/Care.GrowsOffline is off, the time they were away doesn't count.
local function repair(data: DataService.Data, joining: boolean)
	if typeof(data.wingsOwned) ~= "number" or data.wingsOwned ~= data.wingsOwned then
		data.wingsOwned = 1
	end
	data.wingsOwned = math.clamp(math.floor(data.wingsOwned), 1, MaxWings)
	for _, list in { data.monsters, data.storage, data.vault } do
		for _, caught in list do
			if typeof(caught.uid) ~= "string" or caught.uid == "" then
				caught.uid = HttpService:GenerateGUID(false)
			end
			if typeof(caught.effects) ~= "table" then
				caught.effects = {}
			end
		end
	end
	local now = os.time()
	for _, caught in data.monsters do
		if joining and not CareConfig.GrowsOffline and caught.grownAt then
			caught.grownAt = math.max(caught.grownAt, now)
		end
		Care.settle(caught, now)
		Weight.settle(caught, now, random) -- weight always grows offline (Storage pauses it)
	end
end

local function folderIn(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Workspace.Mansions, made if it isn't there.
local function mansionsFolder(): Instance
	local existing = World.find(workspace, "Mansions")
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Mansions"
	folder.Parent = workspace
	return folder
end

-- The owner's name and monster count, floating high above the Foyer.
local function buildOwnerSign(player: Player, plot: PlotService.Plot, model: Model): TextLabel
	local top = floorTop(plot)
	local anchor = Instance.new("Part")
	anchor.Name = "OwnerSign"
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(wingCentre(plot, "Foyer", top + Rooms.WallHeight + 8))
	anchor.Anchored = true
	anchor.Transparency = 1
	ghost(anchor)
	anchor.Parent = model

	local gui = billboard(anchor, 28, 7, 300)
	textLine(gui, `{player.DisplayName}'s Mansion`, Color3.new(1, 1, 1), 0, 0.6)
	return textLine(gui, "", Color3.fromRGB(255, 220, 120), 0.6, 0.4)
end

-- A part standing on the plot at a plot-local spot, its front facing out to the hub.
local function yardPart(
	plot: PlotService.Plot,
	name: string,
	size: Vector3,
	spot: { x: number, z: number },
	offset: Vector3,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local base = plot.frame * CFrame.new(spot.x, 0, spot.z) -- on the plot's top surface
	local part = block(name, size, base * CFrame.new(offset + Vector3.new(0, size.Y / 2, 0)), color, parent)
	part.Material = material
	return part
end

-- Big text on one face of a board: a small heading and the line under it.
local function boardText(board: BasePart, face: Enum.NormalId, heading: string, line: string): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	textLine(gui, heading, Color3.fromRGB(230, 215, 190), 0.1, 0.28)
	local label = textLine(gui, line, Color3.fromRGB(140, 255, 140), 0.4, 0.5)
	gui.Parent = board
	return label
end

-- The wooden sign left of the gate: "MANSION WORTH" and the total, readable from both sides.
local function buildWorthSign(plot: PlotService.Plot, model: Model): { TextLabel }
	local folder = folderIn(model, "WorthSign")
	local wood = Color3.fromRGB(62, 36, 30)
	for i, side in { -1, 1 } do
		yardPart(
			plot,
			`Post{i}`,
			Vector3.new(0.6, 8, 0.6),
			WorthSignSpot,
			Vector3.new(side * 4.2, 0, 0),
			wood,
			Enum.Material.Wood,
			folder
		)
	end
	local board = yardPart(
		plot,
		"Board",
		Vector3.new(10, 4.5, 0.4),
		WorthSignSpot,
		Vector3.new(0, 3.6, 0),
		Color3.fromRGB(48, 30, 26),
		Enum.Material.Wood,
		folder
	)
	yardPart(
		plot,
		"Cap",
		Vector3.new(10.8, 0.4, 0.8),
		WorthSignSpot,
		Vector3.new(0, 8.1, 0),
		wood,
		Enum.Material.Wood,
		folder
	)
	return {
		boardText(board, Enum.NormalId.Front, "MANSION WORTH", "$0"),
		boardText(board, Enum.NormalId.Back, "MANSION WORTH", "$0"),
	}
end

-- The stone stand right of the gate, with a brass plate. Returns its top.
local function buildTrophy(plot: PlotService.Plot, model: Model): BasePart
	local folder = folderIn(model, "Trophy")
	local stone = Color3.fromRGB(70, 68, 76)
	local dark = Color3.fromRGB(52, 50, 58)
	yardPart(plot, "Base", Vector3.new(5, 1, 5), TrophySpot, Vector3.zero, dark, Enum.Material.Slate, folder)
	local column = yardPart(
		plot,
		"Column",
		Vector3.new(3.4, 3, 3.4),
		TrophySpot,
		Vector3.new(0, 1, 0),
		stone,
		Enum.Material.Slate,
		folder
	)
	local top = yardPart(
		plot,
		"Top",
		Vector3.new(4.4, 0.6, 4.4),
		TrophySpot,
		Vector3.new(0, 4, 0),
		dark,
		Enum.Material.Slate,
		folder
	)
	-- The brass plate on the front of the column.
	local plate = block(
		"Plate",
		Vector3.new(2.8, 1, 0.1),
		column.CFrame * CFrame.new(0, 0.3, -column.Size.Z / 2 - 0.05),
		Color3.fromRGB(170, 130, 60),
		folder
	)
	plate.Material = Enum.Material.Metal
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	local label = textLine(gui, "BEST MONSTER", Color3.fromRGB(50, 30, 10), 0.15, 0.7)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke:Destroy() -- engraved, not outlined
	end
	gui.Parent = plate
	return top
end

-- Builds the mansion once the player has both a loaded save and a plot.
local function tryBuild(player: Player)
	if mansions[player] or player.Parent ~= Players then
		return
	end
	local data = DataService.get(player)
	local plot = PlotService.get(player)
	if not data or not plot then
		return -- the other one calls this again when it's ready
	end
	repair(data, true)

	local model = Instance.new("Model")
	model.Name = plot.name
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)

	local state: State = {
		player = player,
		plot = plot,
		model = model,
		wings = folderIn(model, "Wings"),
		built = {},
		monsters = folderIn(model, "Monsters"),
		countLabel = buildOwnerSign(player, plot, model),
		worthLabels = buildWorthSign(plot, model),
		trophy = buildTrophy(plot, model),
		trophyKey = nil,
		group = `Mansion:{player.UserId}`,
		rects = {},
		generation = 0,
	}
	mansions[player] = state

	buildWings(state, data.wingsOwned)
	model.Parent = mansionsFolder()
	spawnAll(state, data)
	updateSign(state)
end

-- Buying the next wing from its sign. Only the plot's owner can buy.
local function purchase(state: State, player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local result, wing = Mansion.canBuyNext(data.wingsOwned, data.money)
	if result == "AllOwned" or not wing then
		Notify.toast(player, "You own every wing already!")
	elseif result == "ComingSoon" then
		Notify.toast(player, `The {wing.id} opens in a future update.`)
	elseif result == "TooPoor" then
		Notify.toast(
			player,
			`You need {Format.money(wing.price)} to buy the {wing.id} (you have {Format.money(data.money)})`
		)
	elseif DataService.addMoney(player, -wing.price) then
		data.wingsOwned += 1
		buildWings(state, data.wingsOwned)
		updateSign(state)
		MansionService.refreshMonsters(player) -- the new wing's value boost shows on the price tags
		local zone = if wing.unlocksZone then Hunt.zoneByIndex(wing.unlocksZone) else nil
		if zone and zone.launch then
			Notify.toast(player, `You bought the {wing.id}! {zone.name} is now open.`)
		else
			Notify.toast(player, `You bought the {wing.id}! More room for monsters.`)
		end
	end
end

buyNext = function(state: State, who: Player)
	if who ~= state.player then
		Notify.toast(who, `This is {state.player.DisplayName}'s mansion. Buy wings at your own mansion!`)
		return
	end
	if buying[who] or mansions[who] ~= state then
		return
	end
	buying[who] = true
	local ok, err = pcall(purchase, state, who)
	buying[who] = nil
	if not ok then
		warn(`MansionService: buying a wing failed: {err}`)
	end
end

-- How many monsters the player's mansion holds in total (0 while their save is loading).
function MansionService.capacity(player: Player): number
	local data = DataService.get(player)
	return if data then Mansion.capacity(data.wingsOwned) else 0
end

-- True if one more monster fits, in the mansion or else in Storage (false while their
-- save is loading).
function MansionService.hasRoom(player: Player): boolean
	local data = DataService.get(player)
	return data ~= nil
		and (Mansion.hasRoom(data.wingsOwned, #data.monsters) or Storage.hasRoom(#data.storage))
end

-- Puts a monster in the mansion and lets it roam there. False if the mansion is full.
local function place(player: Player, data: DataService.Data, caught: Value.CaughtMonster): boolean
	if not Mansion.hasRoom(data.wingsOwned, #data.monsters) then
		return false
	end
	if typeof(caught.uid) ~= "string" or caught.uid == "" then
		caught.uid = HttpService:GenerateGUID(false)
	end
	Care.settle(caught, os.time())
	Weight.settle(caught, os.time(), random) -- just caught: gets its weight and starts growing
	table.insert(data.monsters, caught)
	local state = mansions[player]
	if state then
		spawnMonster(state, caught)
		updateSign(state)
	end
	return true
end

-- Saves a caught monster: into the mansion if there's room, else into Storage. Returns where
-- it went, or nil (and nothing saved) if both are full or the save isn't loaded.
function MansionService.addMonster(player: Player, caught: Value.CaughtMonster): ("Mansion" | "Storage")?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	if place(player, data, caught) then
		DataService.saveSoon(player)
		return "Mansion"
	end
	if not Storage.hasRoom(#data.storage) then
		return nil
	end
	if typeof(caught.uid) ~= "string" or caught.uid == "" then
		caught.uid = HttpService:GenerateGUID(false)
	end
	Storage.store(caught, os.time())
	table.insert(data.storage, caught)
	DataService.saveSoon(player)
	return "Storage"
end

local function indexOf(list: { Value.CaughtMonster }, uid: string): number?
	for i, caught in list do
		if caught.uid == uid then
			return i
		end
	end
	return nil
end

export type MoveResult = "Ok" | "NotFound" | "MansionFull" | "StorageFull"

-- Moves a monster from the mansion into Storage, or from Storage back into the mansion.
function MansionService.move(player: Player, uid: string): (MoveResult, Value.CaughtMonster?)
	local data = DataService.get(player)
	if not data then
		return "NotFound", nil
	end
	local stored = indexOf(data.storage, uid)
	if stored then
		if not Mansion.hasRoom(data.wingsOwned, #data.monsters) then
			return "MansionFull", data.storage[stored]
		end
		local caught = table.remove(data.storage, stored) :: Value.CaughtMonster
		Storage.unstore(caught, os.time())
		place(player, data, caught)
		DataService.saveSoon(player)
		return "Ok", caught
	end
	if not indexOf(data.monsters, uid) then
		return "NotFound", nil
	end
	if not Storage.hasRoom(#data.storage) then
		return "StorageFull", nil
	end
	local removed = MansionService.removeMonsters(player, { [uid] = true })
	local caught = removed[1]
	if not caught then
		return "NotFound", nil
	end
	Storage.store(caught, os.time())
	table.insert(data.storage, caught)
	DataService.saveSoon(player)
	return "Ok", caught
end

-- Takes sold monsters out of the save: off the mansion floor or out of Storage. uids is a
-- set of the monsters' uids. Returns the ones it removed (anything not found is skipped).
function MansionService.removeMonsters(player: Player, uids: { [string]: boolean }): { Value.CaughtMonster }
	local data = DataService.get(player)
	if not data then
		return {}
	end
	local removed = {}
	for _, list in { data.monsters, data.storage } do
		for i = #list, 1, -1 do
			local caught = list[i]
			if caught.uid and uids[caught.uid] then
				table.insert(removed, table.remove(list, i) :: Value.CaughtMonster)
			end
		end
	end
	local state = mansions[player]
	if state then
		for _, child in state.monsters:GetChildren() do
			local uid = child:GetAttribute("Uid")
			if typeof(uid) == "string" and uids[uid] then
				if child:IsA("Model") then
					RoamService.remove(child)
				end
				child:Destroy()
			end
		end
		updateSign(state)
	end
	return removed
end

-- Brings the whole mansion in line with the save (wings, sign and monsters). Used after the save
-- was changed directly, e.g. by the Studio test commands.
function MansionService.rebuild(player: Player)
	local state = mansions[player]
	local data = DataService.get(player)
	if not state or not data then
		tryBuild(player) -- not built yet: builds it if everything is ready
		return
	end
	repair(data, false)
	buildWings(state, data.wingsOwned)
	spawnAll(state, data)
	updateSign(state)
end

-- The spot on the player's mansion floor under `position`, or nil when it isn't inside one of
-- their wings (for setting a cake down where they stand). `margin` keeps it off the edges.
function MansionService.floorSpot(player: Player, position: Vector3, margin: number): Vector3?
	local state = mansions[player]
	if not state or not Roam.inside(state.rects, position.X, position.Z, 0) then
		return nil
	end
	local point = Roam.clamp(state.rects, position.X, position.Z, margin)
	if not point or math.abs(position.Y - point.y) > PillarHeight then
		return nil -- standing on the roof, not in the room
	end
	return Vector3.new(point.x, point.y, point.z)
end

-- The player's mansion monster orbs by uid (empty while their mansion isn't built).
function MansionService.monsterModels(player: Player): { [string]: Model }
	local out: { [string]: Model } = {}
	local state = mansions[player]
	if state then
		for _, child in state.monsters:GetChildren() do
			local uid = child:GetAttribute("Uid")
			if child:IsA("Model") and typeof(uid) == "string" then
				out[uid] = child
			end
		end
	end
	return out
end

-- Updates every monster's label from the save (after it got an effect, or as it gets more
-- familiar). Settle them first (Util/Care.settle) so the labels show how they are right now.
function MansionService.refreshMonsters(player: Player)
	local state = mansions[player]
	local data = DataService.get(player)
	if not state or not data then
		return
	end
	local byUid: { [string]: Value.CaughtMonster } = {}
	for _, caught in data.monsters do
		if caught.uid then
			byUid[caught.uid] = caught
		end
	end
	for _, child in state.monsters:GetChildren() do
		local uid = child:GetAttribute("Uid")
		local caught = if typeof(uid) == "string" then byUid[uid] else nil
		local monster = if caught then Monsters[caught.monsterId] else nil
		if child:IsA("Model") and caught and monster then
			MonsterModel.refresh(child, infoFor(player, caught, monster.rarity))
		end
	end
	updateShowcase(state)
end

-- The growthMultiplier of the Watcher event that's live right now, or nil.
local function eventGrowth(): number?
	local id = workspace:GetAttribute("WatcherEvent")
	for _, event in Events.List do
		if event.id == id then
			return event.growthMultiplier
		end
	end
	return nil
end

-- Brings every mansion monster's growth up to date (and, while a growing Watcher event is
-- live, gives each one an extra spurt roll; MansionService.start calls this once a minute).
-- `spurts` forces that many spurts on every monster, ignoring luck and genes (Studio /grow).
-- The ones that grew a size (or a Titan that grew a step) are rebuilt bigger, and the owner
-- hears about it.
function MansionService.grow(player: Player, spurts: number?)
	local state = mansions[player]
	local data = DataService.get(player)
	if not state or not data then
		return
	end
	local now = os.time()
	local growth = eventGrowth()
	local grown: { Value.CaughtMonster } = {}
	local news: { string } = {}
	for _, caught in data.monsters do
		local scale = Weight.drawScale(caught.size, caught.kg)
		local wasTitan = caught.size == "Titan"
		local newSize = Weight.settle(caught, now, random)
		if growth then
			local _, bigger = Weight.eventRoll(caught, growth, random)
			newSize = bigger or newSize
		end
		for _ = 1, spurts or 0 do
			newSize = Weight.spurt(caught, random, true) or newSize
		end
		if newSize or Weight.drawScale(caught.size, caught.kg) ~= scale then
			table.insert(grown, caught)
		end
		if newSize and caught.size == "Titan" and not wasTitan then
			table.insert(
				news,
				`Your {Format.name(caught.monsterId)} became a TITAN! It's too big for your mansion now.`
			)
		elseif newSize then
			table.insert(news, `Your {Format.name(caught.monsterId)} grew {caught.size}!`)
		end
	end
	if #news > 2 then
		Notify.toast(player, `{#news} of your monsters grew bigger!`)
	else
		for _, text in news do
			Notify.toast(player, text)
		end
	end
	for _, caught in grown do
		for _, child in state.monsters:GetChildren() do
			if child:GetAttribute("Uid") == caught.uid then
				if child:IsA("Model") then
					RoamService.remove(child)
				end
				child:Destroy()
			end
		end
		spawnMonster(state, caught)
	end
	MansionService.refreshMonsters(player) -- the weights and price tags of the others
end

function MansionService.start()
	task.spawn(function()
		while true do
			task.wait(WeightConfig.GrowthTickSeconds)
			for player in mansions do
				MansionService.grow(player)
			end
		end
	end)
	DataService.onLoaded(function(player)
		tryBuild(player)
	end)
	PlotService.onAssigned(function(player)
		tryBuild(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local state = mansions[player]
		mansions[player] = nil
		buying[player] = nil
		if state then
			clearMonsters(state)
			state.model:Destroy()
		end
	end)
end

return MansionService
