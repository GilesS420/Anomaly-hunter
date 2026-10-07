--!strict
-- Every player's mansion, built on their plot from placeholder blocks once their save has
-- loaded and they have a plot:
--   Workspace.Mansions.<PlotName>     a Model made here (removed when the owner leaves)
--     Wings       a floor, four corner pillars and a name label for every owned wing
--     NextWing    a see-through floor plus a sign: hold its prompt to buy that wing
--     OwnerSign   "<name>'s Mansion" and "3/8 monsters", floating above the Foyer
--     Monsters    the owner's caught monsters, roaming around the owned wings (each label
--                 says if it's fed and how familiar it is, see CareService)
-- Wings are bought in order (the Foyer is free). Each one makes room for more monsters and
-- opens a new zone. Nothing here needs building in Studio.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Care = require(ReplicatedStorage.Shared.Util.Care)
local CareConfig = require(ReplicatedStorage.Shared.Config.Care)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Hunt = require(ReplicatedStorage.Shared.Util.Hunt)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Mansion = require(ReplicatedStorage.Shared.Util.Mansion)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Roam = require(ReplicatedStorage.Shared.Util.Roam)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local Wings = require(ReplicatedStorage.Shared.Config.Wings)
local DataService = require(script.Parent.DataService)
local MonsterModel = require(script.Parent.Parent.MonsterModel)
local Notify = require(script.Parent.Parent.Notify)
local PlotService = require(script.Parent.PlotService)
local RoamService = require(script.Parent.RoamService)
local World = require(script.Parent.Parent.World)

local MansionService = {}

type State = {
	player: Player,
	plot: PlotService.Plot,
	model: Model,
	wings: Folder, -- owned wing parts plus the NextWing sign; rebuilt when a wing is bought
	monsters: Folder,
	countLabel: TextLabel, -- "3/8 monsters" on the owner sign
	group: string, -- RoamService group shared by this mansion's monsters
	rects: { Roam.Rect }, -- floor areas the monsters may roam (one per owned wing)
	generation: number, -- goes up whenever the monsters are cleared, cancelling waiting spawns
}

local MonsterSpeed = 4 -- studs per second; mansion monsters stroll, zone monsters hurry
local PillarHeight = 12
local EdgeInset = 1.5 -- keeps roaming orbs off the floor edges and away from the pillars
local MaxWings = #Wings.List
local SpawnRetrySeconds = 1 -- no free spot right now: try again after the others moved on

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

-- A wing the player owns: floor, corner pillars and its name.
local function buildOwnedWing(state: State, wing: Wings.Wing)
	local spot = Layout.Wings[wing.id]
	if not spot then
		warn(`MansionService: no layout spot for the {wing.id} wing (add it to Layout.Wings)`)
		return
	end
	local top = floorTop(state.plot)
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

	local floor = block(
		"Floor",
		Vector3.new(spot.width, 1, spot.depth),
		CFrame.new(wingCentre(state.plot, wing.id, top - 0.5)),
		color,
		folder
	)
	floor.Transparency = 0.7
	ghost(floor)

	-- The sign stands at the wing's front edge, its front facing the plot's front door.
	local signPosition = wingFront(state.plot, wing.id, 1, top + 3.5)
	local board = block(
		"Sign",
		Vector3.new(10, 6, 0.5),
		CFrame.lookAt(signPosition, signPosition + state.plot.frame.LookVector),
		Color3.fromRGB(60, 45, 35),
		folder
	)
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

-- (Re)builds every wing part and the next-wing sign, and updates where monsters may roam.
local function buildWings(state: State, wingsOwned: number)
	state.wings:ClearAllChildren()
	for _, wing in Mansion.ownedWings(wingsOwned) do
		buildOwnedWing(state, wing)
	end
	local nextWing = Mansion.nextWing(wingsOwned)
	if nextWing then
		buildNextWing(state, nextWing)
	end
	state.rects = roamRects(state, wingsOwned)
	RoamService.setRectsForGroup(state.group, state.rects)
end

local function updateSign(state: State)
	local data = DataService.get(state.player)
	if data then
		state.countLabel.Text = `{#data.monsters}/{Mansion.capacity(data.wingsOwned)} monsters`
	end
end

-- What the orb shows: name, size, rarity, effects and whether it's fed.
local function infoFor(player: Player, caught: Value.CaughtMonster, rarity: string): MonsterModel.Info
	return {
		monsterId = caught.monsterId,
		rarity = rarity,
		size = caught.size,
		effects = caught.effects,
		owner = player.DisplayName,
		status = Care.status(caught),
		hungry = not caught.fed,
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
	local radius = MonsterModel.radius(caught.size)
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
-- (saves from before uids existed), a list of effects and feeding times (saves from before
-- feeding start out fed). Brings every monster's Familiarity up to date; when the player
-- just joined and Config/Care.GrowsOffline is off, the time they were away doesn't count.
local function repair(data: DataService.Data, joining: boolean)
	if typeof(data.wingsOwned) ~= "number" or data.wingsOwned ~= data.wingsOwned then
		data.wingsOwned = 1
	end
	data.wingsOwned = math.clamp(math.floor(data.wingsOwned), 1, MaxWings)
	for _, list in { data.monsters, data.vault } do
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
	anchor.CFrame = CFrame.new(wingCentre(plot, "Foyer", top + PillarHeight + 6))
	anchor.Anchored = true
	anchor.Transparency = 1
	ghost(anchor)
	anchor.Parent = model

	local gui = billboard(anchor, 28, 7, 300)
	textLine(gui, `{player.DisplayName}'s Mansion`, Color3.new(1, 1, 1), 0, 0.6)
	return textLine(gui, "", Color3.fromRGB(255, 220, 120), 0.6, 0.4)
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
		monsters = folderIn(model, "Monsters"),
		countLabel = buildOwnerSign(player, plot, model),
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

-- True if there's room for one more monster (false while their save is loading).
function MansionService.hasRoom(player: Player): boolean
	local data = DataService.get(player)
	return data ~= nil and Mansion.hasRoom(data.wingsOwned, #data.monsters)
end

-- Saves a caught monster into the mansion and lets it roam there. False (and nothing saved)
-- if the mansion is full or the save isn't loaded.
function MansionService.addMonster(player: Player, caught: Value.CaughtMonster): boolean
	local data = DataService.get(player)
	if not data or not Mansion.hasRoom(data.wingsOwned, #data.monsters) then
		return false
	end
	if typeof(caught.uid) ~= "string" or caught.uid == "" then
		caught.uid = HttpService:GenerateGUID(false)
	end
	Care.settle(caught, os.time()) -- arrives fed
	table.insert(data.monsters, caught)
	local state = mansions[player]
	if state then
		spawnMonster(state, caught)
		updateSign(state)
	end
	return true
end

-- Takes sold monsters out of the save and off the mansion floor. uids is a set of the
-- monsters' uids. Returns the ones it removed (anything not found is skipped).
function MansionService.removeMonsters(player: Player, uids: { [string]: boolean }): { Value.CaughtMonster }
	local data = DataService.get(player)
	if not data then
		return {}
	end
	local removed = {}
	for i = #data.monsters, 1, -1 do
		local caught = data.monsters[i]
		if caught.uid and uids[caught.uid] then
			table.insert(removed, table.remove(data.monsters, i) :: Value.CaughtMonster)
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

-- Rebuilds the whole mansion from the save (wings, sign and monsters). Used after the save
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

-- Updates every monster's label and glow from the save (after feeding, or as they get
-- hungry). Settle them first (Util/Care.settle) so the labels show how they are right now.
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
end

function MansionService.start()
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
