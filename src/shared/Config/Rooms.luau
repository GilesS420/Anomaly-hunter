--!strict
-- What the mansion rooms look like: every part of a room as data, built by MansionService on
-- the owner's plot (and drawn the same way by the preview page). Rooms are left open-ish on
-- purpose: no roof, an open front behind a low fence and big glassless windows, so everyone
-- walking past can see the monsters roaming inside, while it still reads as a haunted house.
--
-- Room-local studs: the floor's top is y = 0 and its centre is x = z = 0. -Z is the front
-- (the side facing the plot's front door, toward the middle of the hub), +Z the back, +X the
-- plot's right. A part's `at` is its centre.

export type Light = { color: { number }, range: number, brightness: number }

export type Part = {
	name: string,
	size: { number },
	at: { number },
	color: { number },
	material: string, -- an Enum.Material name: "WoodPlanks", "Slate", "Neon", ...
	rot: { number }?, -- degrees around X, Y, Z
	shape: ("Block" | "Cylinder" | "Ball")?,
	solid: boolean?, -- players bump into it (walls, pillars, furniture); off for small decor
	transparency: number?,
	light: Light?, -- a warm PointLight inside (lanterns, the chandelier)
	text: string?, -- painted on the part's front (-Z) face: door name plates
}

local Rooms = {}

-- Colours.
local FloorWood = { 48, 38, 36 }
local FloorDark = { 36, 28, 27 }
local Wall = { 44, 36, 50 }
local WallDark = { 32, 26, 37 }
local Panel = { 52, 34, 30 } -- dark wainscot along the bottom of the walls
local Trim = { 70, 48, 38 }
local Stone = { 70, 68, 76 }
local StoneDark = { 52, 50, 58 }
local DoorWood = { 62, 36, 30 }
local Iron = { 34, 34, 38 }
local Brass = { 170, 130, 60 }
local LanternGlow = { 255, 186, 92 }
local Rug = { 95, 22, 30 }
local Gold = { 190, 150, 70 }
local Cobweb = { 200, 200, 210 }
local Board = { 92, 70, 52 }

local LampLight: Light = { color = { 255, 170, 80 }, range = 18, brightness = 1.1 }

Rooms.WallHeight = 14
local H = Rooms.WallHeight
local T = 1 -- wall thickness

local function part(
	parts: { Part },
	name: string,
	size: { number },
	at: { number },
	color: { number },
	material: string,
	solid: boolean?
): Part
	local p: Part = { name = name, size = size, at = at, color = color, material = material, solid = solid }
	table.insert(parts, p)
	return p
end

-- A run of wall along one side, with openings cut into it. `side` is "Left", "Right" or
-- "Back"; openings are { from, to, bottom, top, kind } along the wall, measured from its
-- start (the front end for side walls, the left end for the back wall).
type Opening = { from: number, to: number, bottom: number, top: number, kind: string, name: string }

-- Colours (and materials) for a room's walls; the Foyer's are the defaults.
export type Theme = {
	wall: { number }?,
	panel: { number }?,
	trim: { number }?,
	frame: { number }?,
	wallMaterial: string?, -- "Plaster" unless set
	panelMaterial: string?, -- "WoodPlanks" unless set
	trimMaterial: string?, -- "Wood" unless set
}

local function wallRun(parts: { Part }, side: string, length: number, openings: { Opening }, theme: Theme?)
	local wallColor = theme and theme.wall or Wall
	local panelColor = theme and theme.panel or Panel
	local trimColor = theme and theme.trim or Trim
	local windowFrame = theme and theme.frame or WallDark
	local wallMaterial = theme and theme.wallMaterial or "Plaster"
	local panelMaterial = theme and theme.panelMaterial or "WoodPlanks"
	local trimMaterial = theme and theme.trimMaterial or "Wood"
	local alongX = side == "Back" or side == "Front"
	-- Turns a distance along the wall and a thickness offset into room-local x, z.
	local function place(along: number, inward: number): (number, number)
		if side == "Left" then
			return -length / 2 + T / 2 + inward, -length / 2 + along
		elseif side == "Right" then
			return length / 2 - T / 2 - inward, -length / 2 + along
		elseif side == "Front" then
			return -length / 2 + along, -length / 2 + T / 2 + inward
		end
		return -length / 2 + along, length / 2 - T / 2 - inward
	end
	local function sized(alongSize: number, height: number, depth: number): { number }
		if alongX then
			return { alongSize, height, depth }
		end
		return { depth, height, alongSize }
	end
	local function piece(name: string, from: number, to: number, bottom: number, top: number)
		if to - from <= 0.01 or top - bottom <= 0.01 then
			return
		end
		local x, z = place((from + to) / 2, 0)
		part(
			parts,
			name,
			sized(to - from, top - bottom, T),
			{ x, (bottom + top) / 2, z },
			wallColor,
			wallMaterial,
			true
		)
		-- Dark wainscot panelling on the lower part, facing into the room.
		if bottom < 3 then
			local px, pz = place((from + to) / 2, T / 2 + 0.1)
			part(parts, name .. "Panel", sized(to - from, math.min(top, 3) - bottom, 0.2), {
				px,
				(bottom + math.min(top, 3)) / 2,
				pz,
			}, panelColor, panelMaterial)
		end
	end

	-- Solid wall between the openings, plus the wall under and over each opening.
	local cursor = 0
	for i, opening in openings do
		piece(`{side}Wall{i}`, cursor, opening.from, 0, H)
		piece(`{side}Sill{i}`, opening.from, opening.to, 0, opening.bottom)
		piece(`{side}Lintel{i}`, opening.from, opening.to, opening.top, H)
		cursor = opening.to
	end
	piece(`{side}WallEnd`, cursor, length, 0, H)

	-- Crown moulding along the top.
	local tx, tz = place(length / 2, 0)
	part(parts, side .. "Crown", sized(length, 0.6, T + 0.6), { tx, H + 0.3, tz }, trimColor, trimMaterial)
	-- A chair rail where the panelling stops, broken at every doorway (and its frame).
	local railFrom = 0
	local function rail(i: number, to: number)
		if to - railFrom > 0.01 then
			local rx, rz = place((railFrom + to) / 2, T / 2 + 0.15)
			part(
				parts,
				`{side}Rail{i}`,
				sized(to - railFrom, 0.25, 0.3),
				{ rx, 3, rz },
				trimColor,
				trimMaterial
			)
		end
	end
	for i, opening in openings do
		if opening.kind == "Door" then
			rail(i, opening.from - 0.25)
			railFrom = opening.to + 0.25
		end
	end
	rail(#openings + 1, length)

	for _, opening in openings do
		local mid = (opening.from + opening.to) / 2
		local width = opening.to - opening.from
		local fx1, fz1 = place(opening.from, 0)
		local fx2, fz2 = place(opening.to, 0)
		local cx, cz = place(mid, 0)
		-- Frame: two jambs and a head, sticking out a little on the inside.
		local frameColor = if opening.kind == "Door" then trimColor else windowFrame
		part(parts, opening.name .. "JambA", sized(0.5, opening.top - opening.bottom, T + 0.4), {
			fx1,
			(opening.bottom + opening.top) / 2,
			fz1,
		}, frameColor, trimMaterial)
		part(parts, opening.name .. "JambB", sized(0.5, opening.top - opening.bottom, T + 0.4), {
			fx2,
			(opening.bottom + opening.top) / 2,
			fz2,
		}, frameColor, trimMaterial)
		part(
			parts,
			opening.name .. "Head",
			sized(width + 1, 0.6, T + 0.4),
			{ cx, opening.top + 0.3, cz },
			frameColor,
			trimMaterial
		)
		if opening.kind == "Window" then
			part(parts, opening.name .. "Ledge", sized(width + 0.6, 0.3, T + 0.8), {
				cx,
				opening.bottom - 0.15,
				cz,
			}, frameColor, trimMaterial)
			-- One loose board nailed across, crooked: haunted, but you can still see in.
			local board = part(
				parts,
				opening.name .. "Board",
				sized(width + 0.4, 0.5, 0.2),
				{ cx, opening.bottom + (opening.top - opening.bottom) * 0.62, cz },
				Board,
				"WoodPlanks"
			)
			board.rot = if alongX then { 0, 0, 14 } else { 14, 0, 0 }
		end
	end
end

-- A wall lantern: an iron bracket and a glass box with a dim, yellowish glow.
local function lantern(parts: { Part }, name: string, x: number, y: number, z: number, out: { number })
	-- `out` is the direction pointing into the room (unit x or z).
	local ox, oz = out[1], out[2]
	part(parts, name .. "Bracket", { 0.3 + math.abs(ox) * 0.6, 0.3, 0.3 + math.abs(oz) * 0.6 }, {
		x + ox * 0.3,
		y + 0.9,
		z + oz * 0.3,
	}, Iron, "Metal")
	part(parts, name .. "Top", { 1, 0.3, 1 }, { x + ox * 0.75, y + 0.75, z + oz * 0.75 }, Iron, "Metal")
	local glass = part(
		parts,
		name,
		{ 0.8, 1.1, 0.8 },
		{ x + ox * 0.75, y, z + oz * 0.75 },
		LanternGlow,
		"Neon"
	)
	glass.light = LampLight
	part(
		parts,
		name .. "Bottom",
		{ 0.6, 0.25, 0.6 },
		{ x + ox * 0.75, y - 0.65, z + oz * 0.75 },
		Iron,
		"Metal"
	)
end

-- A doorway to another wing, with a brass name plate over it. Open (both leaves swung back
-- against the wall) when the owner has that wing, shut with boards nailed across when not.
local function door(parts: { Part }, wingId: string, x: number, z: number, along: string, open: boolean)
	-- `along` is the axis the wall runs along ("X" for the back wall, "Z" for side walls).
	local leafWidth, leafHeight = 3.5, 10 -- two leaves fill the 8-wide doorway
	local into = if along == "Z" then (if x < 0 then 1 else -1) else -1 -- room side of the wall
	for i, s in { -1, 1 } do
		local leaf: Part
		if open then
			-- Swung 90 degrees into the room, standing against the wall beside the frame.
			local hinge = s * leafWidth -- just inside the door frame, clear of the jambs
			if along == "Z" then
				leaf = part(parts, `{wingId}DoorLeaf{i}`, { leafWidth, leafHeight, 0.4 }, {
					x + into * (T / 2 + leafWidth / 2),
					leafHeight / 2,
					z + hinge,
				}, DoorWood, "Wood", true)
			else
				leaf = part(parts, `{wingId}DoorLeaf{i}`, { 0.4, leafHeight, leafWidth }, {
					x + hinge,
					leafHeight / 2,
					z + into * (T / 2 + leafWidth / 2),
				}, DoorWood, "Wood", true)
			end
		else
			local offset = s * leafWidth / 2
			if along == "Z" then
				leaf = part(parts, `{wingId}DoorLeaf{i}`, { 0.4, leafHeight, leafWidth }, {
					x,
					leafHeight / 2,
					z + offset,
				}, DoorWood, "Wood", true)
			else
				leaf = part(parts, `{wingId}DoorLeaf{i}`, { leafWidth, leafHeight, 0.4 }, {
					x + offset,
					leafHeight / 2,
					z,
				}, DoorWood, "Wood", true)
			end
			-- A brass knocker on each leaf, facing into the room.
			if along == "Z" then
				part(parts, `{wingId}Knocker{i}`, { 0.2, 0.6, 0.6 }, {
					x + into * 0.3,
					5,
					z + offset * 0.6,
				}, Brass, "Metal")
			else
				part(parts, `{wingId}Knocker{i}`, { 0.6, 0.6, 0.2 }, {
					x + offset * 0.6,
					5,
					z + into * 0.3,
				}, Brass, "Metal")
			end
		end
		leaf.solid = true
	end
	if not open then
		-- Two boards nailed across the shut doors: this wing isn't bought yet.
		for i, tiltDeg in { 18, -14 } do
			local board: Part
			if along == "Z" then
				board = part(parts, `{wingId}Boarded{i}`, { 0.3, 0.6, 7.6 }, {
					x + into * 0.45,
					3.5 + i * 1.8,
					z,
				}, Board, "WoodPlanks")
				board.rot = { tiltDeg, 0, 0 }
			else
				board = part(parts, `{wingId}Boarded{i}`, { 7.6, 0.6, 0.3 }, {
					x,
					3.5 + i * 1.8,
					z + into * 0.45,
				}, Board, "WoodPlanks")
				board.rot = { 0, 0, tiltDeg }
			end
		end
	end
	-- The name plate over the doorway, facing into the room.
	local plate: Part
	if along == "Z" then
		plate = part(parts, `{wingId}Plate`, { 0.2, 1, 4 }, { x + into * 0.7, 11.6, z }, Brass, "Metal")
		plate.rot = { 0, if into > 0 then -90 else 90, 0 }
		plate.size = { 4, 1, 0.2 }
	else
		plate = part(parts, `{wingId}Plate`, { 4, 1, 0.2 }, { x, 11.6, z + into * 0.7 }, Brass, "Metal")
	end
	plate.text = wingId
end

-- Stone corner pillars, taller than the walls, with caps and iron spikes.
local function cornerPillars(parts: { Part }, hw: number, hd: number)
	for _, corner in
		{ { -1, -1, "FrontLeft" }, { 1, -1, "FrontRight" }, { -1, 1, "BackLeft" }, { 1, 1, "BackRight" } }
	do
		local x, z = (corner[1] :: number) * (hw - 1), (corner[2] :: number) * (hd - 1)
		local name = corner[3] :: string
		part(parts, name .. "Pillar", { 2.4, H + 2, 2.4 }, { x, (H + 2) / 2, z }, Stone, "Slate", true)
		part(parts, name .. "PillarBase", { 3, 1, 3 }, { x, 0.5, z }, StoneDark, "Slate", true)
		part(parts, name .. "PillarCap", { 3, 0.8, 3 }, { x, H + 2.4, z }, StoneDark, "Slate")
		part(parts, name .. "PillarSpike", { 0.8, 1.4, 0.8 }, { x, H + 3.5, z }, Iron, "Metal")
	end
end

-- A run of low wrought-iron fence from x = a to x = b at depth z (the open front of a room).
local function fence(parts: { Part }, tag: string, a: number, b: number, z: number)
	local length = math.abs(b - a)
	part(parts, `FenceRail{tag}`, { length, 0.3, 0.3 }, { (a + b) / 2, 3.2, z }, Iron, "Metal", true)
	part(parts, `FenceRailLow{tag}`, { length, 0.3, 0.3 }, { (a + b) / 2, 0.8, z }, Iron, "Metal", true)
	local count = math.floor(length / 1.5)
	for j = 0, count do
		local x = a + j * (b - a) / count
		part(parts, `FenceBar{tag}_{j}`, { 0.2, 3.6, 0.2 }, { x, 1.8, z }, Iron, "Metal", true)
		part(parts, `FenceTip{tag}_{j}`, { 0.3, 0.5, 0.3 }, { x, 3.85, z }, Iron, "Metal")
	end
end

-- The Foyer: dark floorboards with a red runner, dark panelled walls with boarded-up
-- windows, wall lanterns, a broken chandelier on the cross beams, doors to the Library
-- (left), Ballroom (right) and Garden (back), and an open front behind a low iron fence
-- with a gate between two stone pillars. `owned` says which wings' doors stand open.
function Rooms.Foyer(width: number, depth: number, owned: { [string]: boolean }): { Part }
	local parts: { Part } = {}
	local hw, hd = width / 2, depth / 2

	-- Floor: dark boards with a darker border and a long red runner from the gate to the back.
	part(parts, "Floor", { width, 1, depth }, { 0, -0.5, 0 }, FloorWood, "WoodPlanks", true)
	part(parts, "FloorBorder", { width - 2, 0.04, depth - 2 }, { 0, 0.02, 0 }, FloorDark, "WoodPlanks")
	part(parts, "FloorInlay", { width - 4, 0.06, depth - 4 }, { 0, 0.03, 0 }, FloorWood, "WoodPlanks")
	-- The runner stops at the square rug's edges (front and back halves) so they don't overlap.
	local rugHalf = 6.3
	local runnerLength = hd - 2 - rugHalf
	for i, s in { -1, 1 } do
		local z = s * (rugHalf + runnerLength / 2)
		part(parts, `Runner{i}`, { 7, 0.1, runnerLength }, { 0, 0.08, z }, Rug, "Fabric")
		part(parts, `RunnerTrimLeft{i}`, { 0.4, 0.12, runnerLength }, { -3.3, 0.09, z }, Gold, "Fabric")
		part(parts, `RunnerTrimRight{i}`, { 0.4, 0.12, runnerLength }, { 3.3, 0.09, z }, Gold, "Fabric")
	end
	part(parts, "Rug", { 12, 0.1, 12 }, { 0, 0.1, 0 }, { 70, 18, 26 }, "Fabric")
	part(parts, "RugTrim", { 12.6, 0.08, 12.6 }, { 0, 0.09, 0 }, Gold, "Fabric")

	-- Walls: a window and a door on each side, two windows and a door on the back.
	local doorW, doorTop = 8, 10
	local winW, winBottom, winTop = 6, 4, 11
	local mid = depth / 2
	wallRun(parts, "Left", depth, {
		{
			from = 5,
			to = 5 + winW,
			bottom = winBottom,
			top = winTop,
			kind = "Window",
			name = "LeftWindowFront",
		},
		{
			from = mid - doorW / 2,
			to = mid + doorW / 2,
			bottom = 0,
			top = doorTop,
			kind = "Door",
			name = "LibraryDoorway",
		},
	})
	wallRun(parts, "Right", depth, {
		{
			from = 5,
			to = 5 + winW,
			bottom = winBottom,
			top = winTop,
			kind = "Window",
			name = "RightWindowFront",
		},
		{
			from = mid - doorW / 2,
			to = mid + doorW / 2,
			bottom = 0,
			top = doorTop,
			kind = "Door",
			name = "BallroomDoorway",
		},
	})
	wallRun(parts, "Back", width, {
		{
			from = 5,
			to = 5 + winW,
			bottom = winBottom,
			top = winTop,
			kind = "Window",
			name = "BackWindowLeft",
		},
		{
			from = width / 2 - doorW / 2,
			to = width / 2 + doorW / 2,
			bottom = 0,
			top = doorTop,
			kind = "Door",
			name = "GardenDoorway",
		},
		{
			from = width - 5 - winW,
			to = width - 5,
			bottom = winBottom,
			top = winTop,
			kind = "Window",
			name = "BackWindowRight",
		},
	})
	door(parts, "Library", -hw + T / 2, 0, "Z", owned.Library == true)
	door(parts, "Ballroom", hw - T / 2, 0, "Z", owned.Ballroom == true)
	door(parts, "Garden", 0, hd - T / 2, "X", owned.Garden == true)

	cornerPillars(parts, hw, hd)

	-- Front: open, behind a low wrought-iron fence with a gate between two stone posts.
	local gateHalf = 5
	for i, s in { -1, 1 } do
		local from, to = gateHalf + 1.5, hw - 2.2
		fence(parts, `{i}`, s * from, s * to, -hd + 0.5)
		local postX = s * (gateHalf + 0.75)
		part(parts, `GatePost{i}`, { 1.5, 7, 1.5 }, { postX, 3.5, -hd + 0.5 }, Stone, "Slate", true)
		part(parts, `GatePostCap{i}`, { 2, 0.6, 2 }, { postX, 7.3, -hd + 0.5 }, StoneDark, "Slate")
		lantern(parts, `GateLantern{i}`, postX, 8.4, -hd + 0.5, { 0, 0 })
	end
	part(parts, "GateArch", { gateHalf * 2 + 3, 0.6, 0.6 }, { 0, 9.8, -hd + 0.5 }, Iron, "Metal")
	part(parts, "GateArchTop", { gateHalf * 2 - 1, 0.4, 0.4 }, { 0, 10.6, -hd + 0.5 }, Iron, "Metal")
	part(parts, "GateArchSpike", { 0.5, 1.2, 0.5 }, { 0, 11.4, -hd + 0.5 }, Iron, "Metal")

	-- Wall lanterns: dim, yellowish, two on each side wall and two on the back.
	for i, z in { -6.5, 6.5 } do
		lantern(parts, `LeftLantern{i}`, -hw + T, 7.5, z, { 1, 0 })
		lantern(parts, `RightLantern{i}`, hw - T, 7.5, z, { -1, 0 })
	end
	for i, x in { -6.5, 6.5 } do
		lantern(parts, `BackLantern{i}`, x, 7.5, hd - T, { 0, -1 })
	end

	-- Two cross beams over the open top, and a crooked chandelier hanging between them.
	part(parts, "BeamLeft", { 1, 1, depth - 2 }, { -8, H - 0.5, 0 }, Trim, "Wood")
	part(parts, "BeamRight", { 1, 1, depth - 2 }, { 8, H - 0.5, 0 }, Trim, "Wood")
	part(parts, "BeamCross", { 15, 1, 1 }, { 0, H - 0.5, 0 }, Trim, "Wood")
	part(parts, "ChandelierChain", { 0.2, 3, 0.2 }, { 0, H - 2.5, 0 }, Iron, "Metal")
	-- An iron square frame hanging a little crooked (one side dropped).
	for i, bar in
		{
			{ 0, -2, 5, 0.3, H - 4.3 },
			{ 0, 2, 5, 0.3, H - 4.0 },
			{ -2, 0, 0.3, 4.4, H - 4.15 },
			{ 2, 0, 0.3, 4.4, H - 4.15 },
		}
	do
		local frame = part(
			parts,
			`ChandelierBar{i}`,
			{ bar[3], 0.3, bar[4] },
			{ bar[1], bar[5], bar[2] },
			Iron,
			"Metal"
		)
		if bar[3] < 1 then
			frame.rot = { -4, 0, 0 }
		end
	end
	for i, arm in { { 2.4, 0.2 }, { 0.2, 2.4 } } do
		part(parts, `ChandelierArm{i}`, { arm[1] * 2, 0.15, arm[2] * 2 }, { 0, H - 4.0, 0 }, Iron, "Metal")
	end
	part(parts, "ChandelierHub", { 1, 0.8, 1 }, { 0, H - 3.9, 0 }, Brass, "Metal")
	for i, spot in { { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } } do
		-- The frame hangs crooked, so the candles sit at slightly different heights.
		local y = H - 3.65 + spot[2] * 0.075
		part(
			parts,
			`ChandelierCandle{i}`,
			{ 0.3, 0.7, 0.3 },
			{ spot[1], y, spot[2] },
			{ 230, 225, 205 },
			"SmoothPlastic"
		)
		local flame = part(
			parts,
			`ChandelierFlame{i}`,
			{ 0.2, 0.3, 0.2 },
			{ spot[1], y + 0.5, spot[2] },
			LanternGlow,
			"Neon"
		)
		if i == 1 then
			flame.light = { color = { 255, 170, 80 }, range = 24, brightness = 0.9 }
		end
	end

	-- Furniture along the walls, out of the monsters' way.
	-- A grandfather clock in the back-left corner.
	part(parts, "ClockCase", { 2.2, 7, 1.6 }, { -hw + 4.5, 3.5, hd - 2.4 }, { 58, 34, 28 }, "Wood", true)
	part(parts, "ClockTop", { 2.6, 1, 1.9 }, { -hw + 4.5, 7.4, hd - 2.4 }, { 46, 28, 24 }, "Wood")
	part(
		parts,
		"ClockFace",
		{ 1.4, 1.4, 0.1 },
		{ -hw + 4.5, 6, hd - 3.25 },
		{ 225, 215, 180 },
		"SmoothPlastic"
	)
	local hand = part(parts, "ClockHand", { 0.1, 0.6, 0.05 }, { -hw + 4.5, 6.15, hd - 3.32 }, Iron, "Metal")
	hand.rot = { 0, 0, 40 }
	part(parts, "ClockPendulum", { 0.6, 0.6, 0.1 }, { -hw + 4.5, 3.2, hd - 3.25 }, Brass, "Metal")
	-- A side table with a candelabra in the back-right corner.
	part(parts, "TableTop", { 3.5, 0.3, 2 }, { hw - 5, 3, hd - 2.5 }, { 58, 34, 28 }, "Wood", true)
	for i, leg in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part(parts, `TableLeg{i}`, { 0.3, 2.85, 0.3 }, {
			hw - 5 + leg[1] * 1.5,
			1.43,
			hd - 2.5 + leg[2] * 0.75,
		}, { 46, 28, 24 }, "Wood")
	end
	part(parts, "CandelabraStem", { 0.25, 1.4, 0.25 }, { hw - 5, 3.85, hd - 2.5 }, Brass, "Metal")
	part(parts, "CandelabraArms", { 1.6, 0.2, 0.2 }, { hw - 5, 4.4, hd - 2.5 }, Brass, "Metal")
	for i, dx in { -0.75, 0, 0.75 } do
		part(
			parts,
			`CandelabraFlame{i}`,
			{ 0.18, 0.3, 0.18 },
			{ hw - 5 + dx, 4.75, hd - 2.5 },
			LanternGlow,
			"Neon"
		)
	end
	-- A portrait on each side wall, near the back, whose eyes glow in the dark.
	for i, sx in { -1, 1 } do
		local x, z = sx * (hw - T / 2 - 0.6), hd - 10
		local name = `Portrait{i}`
		part(parts, name .. "Frame", { 0.2, 5, 3.8 }, { x, 7.5, z }, Gold, "Metal")
		part(parts, name, { 0.25, 4.2, 3 }, { x - sx * 0.05, 7.5, z }, { 40, 30, 35 }, "SmoothPlastic")
		part(
			parts,
			name .. "Face",
			{ 0.27, 1.6, 1.3 },
			{ x - sx * 0.06, 8.1, z },
			{ 120, 110, 100 },
			"SmoothPlastic"
		)
		part(
			parts,
			name .. "Body",
			{ 0.27, 1.6, 2.2 },
			{ x - sx * 0.06, 6.4, z },
			{ 30, 22, 26 },
			"SmoothPlastic"
		)
		part(
			parts,
			name .. "EyeLeft",
			{ 0.3, 0.18, 0.18 },
			{ x - sx * 0.08, 8.35, z - 0.3 },
			{ 255, 60, 50 },
			"Neon"
		)
		part(
			parts,
			name .. "EyeRight",
			{ 0.3, 0.18, 0.18 },
			{ x - sx * 0.08, 8.35, z + 0.3 },
			{ 255, 60, 50 },
			"Neon"
		)
	end

	-- Cobwebs in the top corners.
	for i, corner in { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } } do
		local web = part(parts, `Cobweb{i}`, { 0.05, 3, 3 }, {
			corner[1] * (hw - 2.6),
			H - 1.6,
			corner[2] * (hd - 2.6),
		}, Cobweb, "SmoothPlastic")
		web.rot = { 0, corner[1] * corner[2] * 45, 0 }
		web.transparency = 0.6
	end

	return parts
end

-- Pieces of one object (a bookcase, a piano) placed together: `at` is the object's base,
-- `yaw` turns it to face a wall (its front is -Z, like a part) and `tilt` leans it sideways
-- around its own depth axis, so a bookcase can stand crooked with every book still on its shelf.
local function group(parts: { Part }, at: { number }, yaw: number, tilt: number)
	local cy, sy = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
	local function add(
		name: string,
		size: { number },
		pos: { number },
		color: { number },
		material: string,
		solid: boolean?,
		extraTilt: number?
	): Part
		local t = math.rad(tilt)
		local ct, st = math.cos(t), math.sin(t)
		local x1, y1, z1 = pos[1] * ct - pos[2] * st, pos[1] * st + pos[2] * ct, pos[3]
		local p = part(parts, name, size, {
			at[1] + x1 * cy + z1 * sy,
			at[2] + y1,
			at[3] - x1 * sy + z1 * cy,
		}, color, material, solid)
		local roll = tilt + (extraTilt or 0)
		if yaw ~= 0 or roll ~= 0 then
			p.rot = { 0, yaw, roll }
		end
		return p
	end
	return add
end

-- Small, repeatable dice so the same room always gets the same book colours.
local function dice(seed: number): () -> number
	return function()
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
end

local BookColors = {
	{ 90, 30, 30 },
	{ 40, 60, 45 },
	{ 45, 45, 75 },
	{ 110, 80, 40 },
	{ 70, 40, 60 },
	{ 30, 30, 32 },
	{ 120, 105, 80 },
}

-- A tall, dark bookcase full of books, `width` wide, facing out of the wall it stands on.
local function bookcase(
	parts: { Part },
	name: string,
	at: { number },
	yaw: number,
	tilt: number,
	width: number,
	seed: number
)
	local add = group(parts, at, yaw, tilt)
	local height, depth = 12, 1.6
	local wood, dark = { 50, 32, 24 }, { 32, 20, 16 }
	add(name .. "Back", { width, height, 0.2 }, { 0, height / 2, depth / 2 - 0.1 }, dark, "Wood", true)
	add(name .. "SideL", { 0.3, height, depth }, { -width / 2 + 0.15, height / 2, 0 }, wood, "Wood", true)
	add(name .. "SideR", { 0.3, height, depth }, { width / 2 - 0.15, height / 2, 0 }, wood, "Wood", true)
	add(name .. "Top", { width + 0.4, 0.5, depth + 0.3 }, { 0, height + 0.25, 0 }, wood, "Wood")
	add(name .. "Plinth", { width, 0.6, depth }, { 0, 0.3, 0 }, wood, "Wood", true)
	local roll = dice(seed)
	for shelf = 1, 5 do
		local y = 0.6 + (shelf - 1) * 2.3
		add(`{name}Shelf{shelf}`, { width - 0.6, 0.2, depth - 0.2 }, { 0, y + 0.1, 0 }, wood, "Wood")
		-- A row of book blocks (each a few books wide), sometimes with a gap or a leaning one.
		local x, n = -width / 2 + 0.35, 0
		while x < width / 2 - 0.9 do
			local w = math.min(0.6 + roll() * 1.1, width / 2 - 0.35 - x)
			local h = 1.3 + roll() * 0.6
			n += 1
			if roll() > 0.12 then
				local color = BookColors[1 + math.floor(roll() * #BookColors)]
				local lean = if roll() > 0.85 then 12 else 0
				add(
					`{name}Books{shelf}_{n}`,
					{ w - 0.05, h, depth - 0.5 },
					{ x + w / 2, y + 0.2 + h / 2, 0.1 },
					color,
					"SmoothPlastic",
					false,
					lean
				)
			end
			x += w
		end
	end
end

-- Wall lanterns at the usual spots: two per side wall and two on the back, beside the doors.
local function wallLanterns(parts: { Part }, hw: number, hd: number, sideZ: number)
	for i, z in { -sideZ, sideZ } do
		lantern(parts, `LeftLantern{i}`, -hw + T, 7.5, z, { 1, 0 })
		lantern(parts, `RightLantern{i}`, hw - T, 7.5, z, { -1, 0 })
	end
	for i, x in { -6.5, 6.5 } do
		lantern(parts, `BackLantern{i}`, x, 7.5, hd - T, { 0, -1 })
	end
end

-- Cobwebs in the four top corners.
local function cobwebs(parts: { Part }, hw: number, hd: number)
	for i, corner in { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } } do
		local web = part(parts, `Cobweb{i}`, { 0.05, 3, 3 }, {
			corner[1] * (hw - 2.6),
			H - 1.6,
			corner[2] * (hd - 2.6),
		}, Cobweb, "SmoothPlastic")
		web.rot = { 0, corner[1] * corner[2] * 45, 0 }
		web.transparency = 0.6
	end
end

-- The shell every wing shares: floor, three walls, corner pillars, an open front behind a
-- low fence (only the Foyer has a gate), lanterns, beams and cobwebs. `foyerSide` is the
-- side wall (-1 left, 1 right) with an open archway to the Foyer, plus a threshold over the
-- gap between the two floors; `backWing` is the wing behind, whose door sits in the back wall.
local function wingShell(
	parts: { Part },
	width: number,
	depth: number,
	theme: Theme,
	floorColor: { number },
	foyerSide: number,
	backWing: string,
	owned: { [string]: boolean },
	outerWindows: { Opening },
	lanternZ: number
)
	local hw, hd = width / 2, depth / 2
	part(parts, "Floor", { width, 1, depth }, { 0, -0.5, 0 }, floorColor, "WoodPlanks", true)
	part(parts, "Threshold", { 2, 1, 8 }, { foyerSide * (hw + 1), -0.5, 0 }, Stone, "Slate", true)

	local doorW, doorTop = 8, 10
	local archway: Opening = {
		from = depth / 2 - doorW / 2,
		to = depth / 2 + doorW / 2,
		bottom = 0,
		top = doorTop,
		kind = "Door",
		name = "FoyerArchway",
	}
	local foyerWall = if foyerSide < 0 then "Left" else "Right"
	local outerWall = if foyerSide < 0 then "Right" else "Left"
	wallRun(parts, foyerWall, depth, { archway }, theme)
	wallRun(parts, outerWall, depth, outerWindows, theme)
	wallRun(parts, "Back", width, {
		{
			from = width / 2 - doorW / 2,
			to = width / 2 + doorW / 2,
			bottom = 0,
			top = doorTop,
			kind = "Door",
			name = `{backWing}Doorway`,
		},
	}, theme)
	door(parts, backWing, 0, hd - T / 2, "X", owned[backWing] == true)
	cornerPillars(parts, hw, hd)
	fence(parts, "", -hw + 2.2, hw - 2.2, -hd + 0.5)
	wallLanterns(parts, hw, hd, lanternZ)
	part(parts, "BeamLeft", { 1, 1, depth - 2 }, { -8, H - 0.5, 0 }, theme.trim or Trim, "Wood")
	part(parts, "BeamRight", { 1, 1, depth - 2 }, { 8, H - 0.5, 0 }, theme.trim or Trim, "Wood")
	part(parts, "BeamCross", { 15, 1, 1 }, { 0, H - 0.5, 0 }, theme.trim or Trim, "Wood")
	cobwebs(parts, hw, hd)
end

-- The Library (left of the Foyer): crooked bookcases on every wall, a cold fireplace with a
-- reading chair, a rolling ladder and books floating over the middle around a glowing one.
function Rooms.Library(width: number, depth: number, owned: { [string]: boolean }): { Part }
	local parts: { Part } = {}
	local hw, hd = width / 2, depth / 2
	wingShell(
		parts,
		width,
		depth,
		{ wall = { 30, 38, 42 }, panel = { 42, 30, 24 }, trim = { 62, 44, 32 }, frame = { 24, 30, 34 } },
		{ 44, 34, 26 },
		1,
		"Attic",
		owned,
		{},
		6.5
	)

	-- Bookcases: two on each side wall, two on each side of the back door. A few lean.
	-- Bookcases stand just clear of the panelling and chair rail (0.3 out from the wall).
	local wallX = hw - T - 1.15
	for i, spot in { { -12, 0 }, { 12, -3 } } do
		bookcase(parts, `ShelfLeft{i}`, { -wallX, 0, spot[1] }, -90, spot[2], 6, 11 + i)
		bookcase(parts, `ShelfRight{i}`, { wallX, 0, spot[1] }, 90, -spot[2] * 0.5, 6, 21 + i)
	end
	local wallZ = hd - T - 1.15
	for i, spot in { { -11, 6, 0 }, { 11, 6, 2.5 }, { -15.9, 3, 0 }, { 15.9, 3, 0 } } do
		bookcase(parts, `ShelfBack{i}`, { spot[1], 0, wallZ }, 0, spot[3], spot[2], 31 + i)
	end

	-- A rolling ladder leaning on the back-right bookcase on the right wall.
	local ladderTilt = 15
	local footX = wallX - 0.8 - 11 * math.sin(math.rad(ladderTilt))
	for i, z in { 9.6, 11.2 } do
		local rail = part(parts, `LadderRail{i}`, { 0.25, 11, 0.25 }, {
			footX + 5.5 * math.sin(math.rad(ladderTilt)),
			5.5 * math.cos(math.rad(ladderTilt)),
			z,
		}, { 70, 48, 32 }, "Wood")
		rail.rot = { 0, 0, -ladderTilt }
	end
	for r = 1, 8 do
		local y = r * 1.2
		part(parts, `LadderRung{r}`, { 0.2, 0.2, 1.6 }, {
			footX + y * math.tan(math.rad(ladderTilt)),
			y,
			10.4,
		}, { 70, 48, 32 }, "Wood")
	end

	-- A cold fireplace in the middle of the outer (left) wall: stone surround, black firebox,
	-- grey ash and burnt logs, a chimney breast up to the top and two dead candles on the mantel.
	local fx = -hw + T
	local FireStone, Soot = { 78, 74, 80 }, { 14, 12, 14 }
	part(
		parts,
		"ChimneyBreast",
		{ 1.2, H - 6.4, 7 },
		{ fx + 0.6, 6.4 + (H - 6.4) / 2, 0 },
		FireStone,
		"Slate",
		true
	)
	part(parts, "FireplaceSideA", { 1.6, 6, 1.4 }, { fx + 0.8, 3, -3.3 }, FireStone, "Slate", true)
	part(parts, "FireplaceSideB", { 1.6, 6, 1.4 }, { fx + 0.8, 3, 3.3 }, FireStone, "Slate", true)
	part(parts, "FireplaceLintel", { 1.6, 1, 8 }, { fx + 0.8, 5.5, 0 }, FireStone, "Slate", true)
	part(parts, "Mantel", { 2.2, 0.4, 9 }, { fx + 1.1, 6.2, 0 }, { 50, 32, 24 }, "Wood")
	part(parts, "Firebox", { 0.3, 4.8, 5.2 }, { fx + 0.45, 2.6, 0 }, Soot, "Slate")
	part(parts, "Hearth", { 2.4, 0.2, 9 }, { fx + 1.8, 0.1, 0 }, { 60, 56, 62 }, "Slate")
	part(parts, "Ash", { 1.2, 0.25, 3.2 }, { fx + 1.2, 0.3, 0 }, { 105, 100, 98 }, "Slate")
	for i, z in { -0.6, 0.6 } do
		local log = part(
			parts,
			`BurntLog{i}`,
			{ 0.6, 0.6, 3 },
			{ fx + 1.2, 0.6, z * 0.4 },
			{ 26, 20, 18 },
			"Wood"
		)
		log.rot = { 0, z * 40, 0 }
	end
	for i, z in { -3.4, 3.4 } do
		part(
			parts,
			`MantelCandle{i}`,
			{ 0.35, 1, 0.35 },
			{ fx + 1.7, 6.9, z },
			{ 200, 195, 175 },
			"SmoothPlastic"
		)
	end
	part(parts, "MantelSkull", { 0.8, 0.8, 0.8 }, { fx + 1.7, 6.8, 0 }, { 215, 205, 180 }, "SmoothPlastic")
	part(parts, "MantelSkullEyes", { 0.1, 0.2, 0.55 }, { fx + 2.15, 6.85, 0 }, Soot, "SmoothPlastic")
	part(parts, "FireRug", { 6, 0.08, 8 }, { -hw + 7, 0.04, 0 }, { 32, 56, 44 }, "Fabric")

	-- The reading chair in front of the fireplace, and a little table with a lit candle.
	local chair = group(parts, { -hw + 8.5, 0, 2.6 }, 90 + 20, 0)
	local Velvet, VelvetDark = { 92, 26, 34 }, { 66, 18, 26 }
	chair("ChairSeat", { 3, 1, 2.8 }, { 0, 1.5, 0 }, Velvet, "Fabric", true)
	chair("ChairBack", { 3, 3.6, 0.6 }, { 0, 3.6, 1.1 }, Velvet, "Fabric", true)
	chair("ChairWingL", { 0.5, 1.4, 1.6 }, { -1.3, 4.6, 0.6 }, VelvetDark, "Fabric")
	chair("ChairWingR", { 0.5, 1.4, 1.6 }, { 1.3, 4.6, 0.6 }, VelvetDark, "Fabric")
	chair("ChairArmL", { 0.5, 0.9, 2.6 }, { -1.5, 2.3, 0 }, VelvetDark, "Fabric")
	chair("ChairArmR", { 0.5, 0.9, 2.6 }, { 1.5, 2.3, 0 }, VelvetDark, "Fabric")
	for i, leg in { { -1.2, -1.1 }, { 1.2, -1.1 }, { -1.2, 1.1 }, { 1.2, 1.1 } } do
		chair(`ChairLeg{i}`, { 0.3, 1, 0.3 }, { leg[1], 0.5, leg[2] }, { 40, 26, 20 }, "Wood")
	end
	part(parts, "ReadingTable", { 1.6, 0.2, 1.6 }, { -hw + 8.5, 2.4, -1.4 }, { 50, 32, 24 }, "Wood", true)
	part(parts, "ReadingTableLeg", { 0.3, 2.3, 0.3 }, { -hw + 8.5, 1.15, -1.4 }, { 40, 26, 20 }, "Wood")
	part(
		parts,
		"ReadingCandle",
		{ 0.3, 0.7, 0.3 },
		{ -hw + 8.3, 2.85, -1.2 },
		{ 220, 215, 195 },
		"SmoothPlastic"
	)
	local flame = part(
		parts,
		"ReadingFlame",
		{ 0.18, 0.3, 0.18 },
		{ -hw + 8.3, 3.35, -1.2 },
		LanternGlow,
		"Neon"
	)
	flame.light = { color = { 255, 170, 80 }, range = 10, brightness = 0.8 }
	local stack = part(
		parts,
		"ReadingBook",
		{ 0.9, 0.25, 1.2 },
		{ -hw + 8.8, 2.63, -1.6 },
		BookColors[1],
		"SmoothPlastic"
	)
	stack.rot = { 0, 25, 0 }

	-- Books floating over the middle of the room, around an open one that glows green.
	local Pages = { 150, 255, 170 }
	local open = group(parts, { 0, 7, 3 }, 30, 0)
	open("GhostBookLeft", { 1.4, 0.15, 1.9 }, { -0.68, 0, 0 }, { 60, 40, 30 }, "SmoothPlastic", false, -12)
	open("GhostBookRight", { 1.4, 0.15, 1.9 }, { 0.68, 0, 0 }, { 60, 40, 30 }, "SmoothPlastic", false, 12)
	open("GhostPagesLeft", { 1.25, 0.12, 1.75 }, { -0.66, 0.12, 0 }, Pages, "Neon", false, -12)
	local pages = open("GhostPagesRight", { 1.25, 0.12, 1.75 }, { 0.66, 0.12, 0 }, Pages, "Neon", false, 12)
	pages.light = { color = { 120, 255, 150 }, range = 14, brightness = 0.7 }
	local roll = dice(7)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		local book = part(parts, `FloatingBook{i}`, { 0.9, 1.3, 0.3 }, {
			math.cos(a) * 4.5,
			6 + roll() * 3.5,
			3 + math.sin(a) * 4.5,
		}, BookColors[1 + (i % #BookColors)], "SmoothPlastic")
		book.rot = { roll() * 60 - 30, math.deg(a), roll() * 50 - 25 }
	end
	-- A few loose pages drifting with them.
	for i = 1, 4 do
		local sheet = part(parts, `LoosePage{i}`, { 0.7, 0.04, 0.9 }, {
			roll() * 10 - 5,
			5 + roll() * 4,
			roll() * 10 - 2,
		}, { 220, 210, 180 }, "SmoothPlastic")
		sheet.rot = { roll() * 60 - 30, roll() * 360, roll() * 60 - 30 }
	end
	return parts
end

-- The Ballroom (right of the Foyer): a cracked black-and-cream dance floor, a huge chandelier
-- hanging crooked with pieces of it smashed on the floor, a dusty grand piano, tall cracked
-- mirrors between tattered curtains and gilded chairs (one knocked over).
function Rooms.Ballroom(width: number, depth: number, owned: { [string]: boolean }): { Part }
	local parts: { Part } = {}
	local hw, hd = width / 2, depth / 2
	local Gilt = { 150, 115, 55 }
	local windowAt = function(name: string, centre: number): Opening
		return {
			from = hd + centre - 3,
			to = hd + centre + 3,
			bottom = 3,
			top = 12,
			kind = "Window",
			name = name,
		}
	end
	wingShell(
		parts,
		width,
		depth,
		{ wall = { 52, 22, 32 }, panel = { 36, 18, 22 }, trim = { 104, 78, 44 }, frame = { 36, 16, 24 } },
		{ 38, 26, 24 },
		-1,
		"Crypt",
		owned,
		{ windowAt("WindowFront", -11), windowAt("WindowBack", 11) },
		5 -- between the mirror and the curtains
	)

	-- The dance floor: 8 x 8 tiles; some cracked loose (turned, raised), one missing.
	local Cream, Black, Grout = { 150, 140, 122 }, { 22, 20, 24 }, { 14, 12, 14 }
	part(parts, "DanceFloorGrout", { 32.4, 0.05, 32.4 }, { 0, 0.025, 0 }, Grout, "Slate")
	local roll = dice(3)
	for row = 0, 7 do
		for col = 0, 7 do
			local cracked = roll()
			if not (row == 2 and col == 5) then
				local tile = part(
					parts,
					`Tile{row}_{col}`,
					{ 3.9, 0.12, 3.9 },
					{ -14 + col * 4, 0.06 + (if cracked > 0.85 then 0.08 else 0), -14 + row * 4 },
					if (row + col) % 2 == 0 then Cream else Black,
					"Marble"
				)
				if cracked > 0.85 then
					tile.rot = { roll() * 4 - 2, roll() * 14 - 7, roll() * 4 - 2 }
				end
			end
		end
	end

	-- The chandelier: two tiers of gilded frame with crystals and candles, hanging crooked from
	-- one chain, and the third tier smashed on the floor below.
	part(parts, "ChandelierChain", { 0.25, 1, 0.25 }, { 0, H - 1.5, 0 }, Iron, "Metal")
	local add = group(parts, { 0, H - 2, 0 }, 20, 14)
	add("ChandelierStem", { 0.5, 3.5, 0.5 }, { 0, -1.75, 0 }, Gilt, "Metal")
	for tier, spec in { { 7, -2.8 }, { 4.5, -1.2 } } do
		local size, y = spec[1], spec[2]
		for i, bar in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
			local long = if bar[1] == 0 then { size, 0.3, 0.3 } else { 0.3, 0.3, size }
			add(`ChandelierTier{tier}_{i}`, long, { bar[1] * size / 2, y, bar[2] * size / 2 }, Gilt, "Metal")
			-- Crystals hang under the frame, candles stand on it.
			for c = -1, 1 do
				local along = c * size / 3
				local cx = if bar[1] == 0 then along else bar[1] * size / 2
				local cz = if bar[1] == 0 then bar[2] * size / 2 else along
				local crystal = add(
					`Crystal{tier}_{i}_{c}`,
					{ 0.25, 0.7, 0.25 },
					{ cx, y - 0.55, cz },
					{ 190, 215, 235 },
					"Glass"
				)
				crystal.transparency = 0.3
			end
			add(`ChandelierCandle{tier}_{i}`, { 0.3, 0.7, 0.3 }, {
				bar[1] * size / 2,
				y + 0.5,
				bar[2] * size / 2,
			}, { 225, 220, 200 }, "SmoothPlastic")
			if tier == 1 and i <= 2 then
				local glow = add(`ChandelierFlame{tier}_{i}`, { 0.2, 0.3, 0.2 }, {
					bar[1] * size / 2,
					y + 1,
					bar[2] * size / 2,
				}, LanternGlow, "Neon")
				if i == 1 then
					glow.light = { color = { 255, 170, 80 }, range = 26, brightness = 0.9 }
				end
			end
		end
	end
	-- The fallen tier: bent bars and crystals scattered on the dance floor.
	for i, bit in { { -3, 2, 30, 3.5 }, { -1.2, 3.6, -50, 2.5 }, { -4.2, 4, 80, 2 } } do
		local bar = part(parts, `FallenBar{i}`, { bit[4], 0.3, 0.3 }, { bit[1], 0.3, bit[2] }, Gilt, "Metal")
		bar.rot = { 0, bit[3], if i == 2 then 8 else 0 }
	end
	for i = 1, 9 do
		local shard = part(parts, `FallenCrystal{i}`, { 0.25, 0.25, 0.6 }, {
			-2.6 + roll() * 4 - 2,
			0.25,
			3 + roll() * 3 - 1.5,
		}, { 190, 215, 235 }, "Glass")
		shard.rot = { 0, roll() * 180, 90 }
		shard.transparency = 0.3
	end

	-- A grand piano in the back-right corner, lid propped open, covered in dust.
	local piano = group(parts, { hw - 7.5, 0, hd - 8 }, -150, 0)
	local Lacquer, Dust = { 24, 20, 24 }, { 150, 145, 140 }
	piano("PianoBody", { 4.6, 1.3, 3.6 }, { 0, 2.95, 0.6 }, Lacquer, "SmoothPlastic", true)
	piano("PianoTail", { 2.8, 1.3, 2.4 }, { 0.9, 2.95, 3.6 }, Lacquer, "SmoothPlastic", true)
	piano("PianoKeysBed", { 4.6, 0.4, 1 }, { 0, 2.6, -1.6 }, Lacquer, "SmoothPlastic")
	piano("PianoKeys", { 4.2, 0.12, 0.9 }, { 0, 2.86, -1.6 }, { 225, 220, 205 }, "SmoothPlastic")
	for k = 0, 6 do
		piano(
			`PianoBlackKeys{k}`,
			{ 0.35, 0.14, 0.55 },
			{ -1.8 + k * 0.6, 2.96, -1.4 },
			Lacquer,
			"SmoothPlastic"
		)
	end
	for i, leg in { { -2, -1 }, { 2, -1 }, { 1.2, 4.2 } } do
		piano(`PianoLeg{i}`, { 0.5, 2.3, 0.5 }, { leg[1], 1.15, leg[2] }, Lacquer, "SmoothPlastic", true)
	end
	-- The lid, hinged at the right side and tilted up 35 degrees, resting on a prop stick.
	local lidAngle = 35
	piano("PianoLid", { 4.4, 0.15, 5.6 }, {
		2.3 - 2.2 * math.cos(math.rad(lidAngle)),
		3.68 + 2.2 * math.sin(math.rad(lidAngle)),
		1.6,
	}, Lacquer, "SmoothPlastic", false, -lidAngle)
	piano("PianoProp", { 0.15, 2.4, 0.15 }, { -1.2, 4.6, 1.2 }, Lacquer, "SmoothPlastic")
	local dust = piano("PianoDust", { 2.6, 0.06, 2.2 }, { 0.9, 3.64, 3.6 }, Dust, "Fabric")
	dust.transparency = 0.35
	piano("PianoBench", { 2.6, 0.5, 1.1 }, { 0, 1.8, -3.4 }, Lacquer, "SmoothPlastic", true)
	piano("PianoBenchDust", { 2.4, 0.05, 1 }, { 0, 2.08, -3.4 }, Dust, "Fabric").transparency = 0.4
	for i, leg in { { -1.1, -3.8 }, { 1.1, -3.8 }, { -1.1, -3 }, { 1.1, -3 } } do
		piano(`PianoBenchLeg{i}`, { 0.25, 1.55, 0.25 }, { leg[1], 0.78, leg[2] }, Lacquer, "SmoothPlastic")
	end

	-- A tall mirror standing against the outer (right) wall, in front of the chair rail, its glass
	-- smashed into a spider web of cracks around one impact, a shard missing, a ghostly face.
	local mx = hw - T - 0.5
	local mirrorY = 4.85
	part(parts, "MirrorFrame", { 0.3, 9.5, 4.8 }, { mx, mirrorY, 0 }, Gilt, "Metal", true)
	part(parts, "MirrorFrameTop", { 0.4, 1, 3 }, { mx - 0.05, mirrorY + 5.2, 0 }, Gilt, "Metal")
	part(parts, "MirrorGlass", { 0.32, 8.6, 3.9 }, { mx - 0.02, mirrorY, 0 }, { 120, 130, 145 }, "Glass")
	local hitY, hitZ = mirrorY + 1.2, 0.5
	local halfY, halfZ = 4.2, 1.85 -- keep cracks on the glass
	for i, crack in
		{
			{ 10, 9 },
			{ 55, 6 },
			{ 100, 7 },
			{ 140, 5 },
			{ 190, 9 },
			{ 235, 6 },
			{ 280, 8 },
			{ 320, 4 },
			{ 165, 3 },
		}
	do
		local angle = math.rad(crack[1])
		local dy, dz = -math.sin(angle), math.cos(angle)
		-- Shorten the line where it would run off the glass.
		local length = crack[2]
		if math.abs(dy) > 0.01 then
			length = math.min(length, ((if dy > 0 then halfY else -halfY) + mirrorY - hitY) / dy)
		end
		if math.abs(dz) > 0.01 then
			length = math.min(length, ((if dz > 0 then halfZ else -halfZ) - hitZ) / dz)
		end
		local line = part(parts, `MirrorCrack{i}`, { 0.34, 0.1, length }, {
			mx - 0.03,
			hitY + dy * length / 2,
			hitZ + dz * length / 2,
		}, { 40, 40, 48 }, "SmoothPlastic")
		line.rot = { crack[1], 0, 0 }
	end
	-- A ring of short cracks around the impact.
	for i = 0, 5 do
		local angle = math.rad(i * 60 + 30)
		local ring = part(parts, `MirrorRing{i}`, { 0.34, 0.08, 0.7 }, {
			mx - 0.03,
			hitY - math.sin(angle) * 0.8,
			hitZ + math.cos(angle) * 0.8,
		}, { 40, 40, 48 }, "SmoothPlastic")
		ring.rot = { i * 60 + 120, 0, 0 }
	end
	part(
		parts,
		"MirrorShardGone",
		{ 0.33, 0.9, 0.6 },
		{ mx - 0.025, hitY - 0.5, hitZ + 0.45 },
		{ 20, 18, 22 },
		"SmoothPlastic"
	).rot =
		{ 25, 0, 0 }
	part(
		parts,
		"MirrorGhost",
		{ 0.33, 1.6, 1.2 },
		{ mx - 0.04, mirrorY + 1.6, -0.6 },
		{ 210, 225, 240 },
		"Neon"
	).transparency =
		0.75

	-- Tattered red curtains either side of both windows (the inner ones a bit shorter, torn).
	local Curtain = { 110, 22, 34 }
	for w, centre in { -11, 11 } do
		for c, s in { -1, 1 } do
			local long = if s * centre > 0 then 12 else 10.5
			part(parts, `Curtain{w}_{c}`, { 0.3, long, 1.3 }, {
				hw - T - 0.6,
				H - 1 - long / 2,
				centre + s * 3.5,
			}, Curtain, "Fabric")
		end
		part(parts, `CurtainRod{w}`, { 0.2, 0.2, 8.6 }, { hw - T - 0.6, H - 0.9, centre }, Gilt, "Metal")
	end

	-- Gilded chairs along the Foyer-side wall, facing the dance floor; one knocked over.
	local Seat = { 120, 30, 40 }
	local function gildedChair(name: string, at: { number }, yaw: number, tilt: number)
		local c = group(parts, at, yaw, tilt)
		c(name .. "Seat", { 1.8, 0.3, 1.8 }, { 0, 1.8, 0 }, Seat, "Fabric", true)
		c(name .. "Back", { 1.8, 2.4, 0.3 }, { 0, 3.2, 0.8 }, Gilt, "Metal", true)
		c(name .. "BackPad", { 1.3, 1.6, 0.1 }, { 0, 3.2, 0.62 }, Seat, "Fabric")
		for i, leg in { { -0.75, -0.75 }, { 0.75, -0.75 }, { -0.75, 0.75 }, { 0.75, 0.75 } } do
			c(`{name}Leg{i}`, { 0.2, 1.65, 0.2 }, { leg[1], 0.83, leg[2] }, Gilt, "Metal")
		end
	end
	local cx = -hw + T + 2
	gildedChair("ChairA", { cx, 0, -14 }, -90, 0)
	gildedChair("ChairB", { cx, 0, -10.5 }, -90, 0)
	gildedChair("ChairC", { cx, 0, 10.5 }, -90, 0)
	gildedChair("ChairFallen", { cx + 3, 0.9, 14 }, -120, 90)

	return parts
end

-- The shell of a back-row wing (Attic, Crypt): floor, an open archway in the front wall from
-- the wing in front of it (plus a threshold over the gap), the other three walls with their
-- openings, corner pillars, lanterns and cobwebs. Rooms add their own ceiling beams.
local function backShell(
	parts: { Part },
	width: number,
	depth: number,
	theme: Theme,
	floor: { number },
	floorMaterial: string,
	fromWing: string,
	walls: { Left: { Opening }, Right: { Opening }, Back: { Opening } }
)
	local hw, hd = width / 2, depth / 2
	part(parts, "Floor", { width, 1, depth }, { 0, -0.5, 0 }, floor, floorMaterial, true)
	part(parts, "Threshold", { 8, 1, 2 }, { 0, -0.5, -hd - 1 }, Stone, "Slate", true)
	wallRun(parts, "Front", width, {
		{
			from = width / 2 - 4,
			to = width / 2 + 4,
			bottom = 0,
			top = 10,
			kind = "Door",
			name = `{fromWing}Archway`,
		},
	}, theme)
	wallRun(parts, "Left", depth, walls.Left, theme)
	wallRun(parts, "Right", depth, walls.Right, theme)
	wallRun(parts, "Back", width, walls.Back, theme)
	cornerPillars(parts, hw, hd)
	wallLanterns(parts, hw, hd, 6.5)
	cobwebs(parts, hw, hd)
end

-- A window opening on a side or back wall, centred `centre` studs from the wall's middle.
local function window(
	name: string,
	length: number,
	centre: number,
	width: number,
	bottom: number,
	top: number
): Opening
	return {
		from = length / 2 + centre - width / 2,
		to = length / 2 + centre + width / 2,
		bottom = bottom,
		top = top,
		kind = "Window",
		name = name,
	}
end

-- A straight stick (rafter, branch) from point `from`, heading `yaw` degrees around Y and
-- climbing `up` degrees, `length` long. Its long axis is the part's X.
local function stick(
	parts: { Part },
	name: string,
	from: { number },
	yaw: number,
	up: number,
	length: number,
	thick: number,
	color: { number },
	material: string
): { number }
	local y, u = math.rad(yaw), math.rad(up)
	local dx, dy, dz = math.cos(u) * math.cos(y), math.sin(u), -math.cos(u) * math.sin(y)
	local p = part(parts, name, { length, thick, thick }, {
		from[1] + dx * length / 2,
		from[2] + dy * length / 2,
		from[3] + dz * length / 2,
	}, color, material)
	p.rot = { 0, yaw, up }
	return { from[1] + dx * length, from[2] + dy * length, from[3] + dz * length }
end

-- A shape draped in a dusty white sheet: the lump, a wider hem at the floor and a fold on top.
local function sheeted(parts: { Part }, name: string, at: { number }, size: { number }, yaw: number)
	local add = group(parts, at, yaw, 0)
	local Sheet, SheetShade = { 196, 192, 182 }, { 168, 164, 156 }
	add(name, { size[1], size[2] - 0.4, size[3] }, { 0, 0.4 + (size[2] - 0.4) / 2, 0 }, Sheet, "Fabric", true)
	add(name .. "Hem", { size[1] + 0.4, 0.4, size[3] + 0.4 }, { 0, 0.2, 0 }, SheetShade, "Fabric")
	add(
		name .. "Fold",
		{ size[1] * 0.7, 0.25, size[3] * 0.8 },
		{ 0.15, size[2] + 0.12, 0.1 },
		SheetShade,
		"Fabric",
		false,
		4
	)
end

-- The Attic (behind the Library): bare plank walls, a pitched frame of rafters over the open
-- top, furniture under dusty sheets, an old rocking horse with red eyes, trunks, a dress form
-- and stacked boxes.
function Rooms.Attic(width: number, depth: number, owned: { [string]: boolean }): { Part }
	local parts: { Part } = {}
	local hw = width / 2
	local Beam = { 66, 48, 34 }
	backShell(
		parts,
		width,
		depth,
		{
			wall = { 56, 44, 36 },
			panel = { 40, 30, 24 },
			trim = { 70, 52, 38 },
			frame = { 44, 34, 28 },
			wallMaterial = "WoodPlanks",
		},
		{ 62, 48, 36 },
		"WoodPlanks",
		"Library",
		{
			Left = { window("LeftWindow", depth, 0, 5, 5, 10) },
			Right = { window("RightWindow", depth, 0, 5, 5, 10) },
			Back = { window("BackWindow", width, 0, 6, 5, 11) },
		}
	)

	-- The pitched roof frame: pairs of rafters from the wall tops up to a ridge beam.
	local rise, run = 5, hw - T / 2
	local length = math.sqrt(rise * rise + run * run)
	local pitch = math.deg(math.atan(rise / run))
	for i, z in { -15, -7.5, 0, 7.5, 15 } do
		stick(parts, `RafterLeft{i}`, { -run, H + 1, z }, 0, pitch, length, 0.8, Beam, "Wood")
		stick(parts, `RafterRight{i}`, { run, H + 1, z }, 180, pitch, length, 0.8, Beam, "Wood")
	end
	part(parts, "RidgeBeam", { 1.2, 1.2, depth - 4 }, { 0, H + 1 + rise, 0 }, Beam, "Wood")

	-- Furniture under sheets along the walls.
	sheeted(parts, "SheetWardrobe", { -14, 0, 15.5 }, { 4, 8, 2.4 }, 0)
	sheeted(parts, "SheetArmchair", { -15, 0, 6 }, { 3, 3.6, 3 }, -70)
	sheeted(parts, "SheetTable", { 9, 0, 13 }, { 6, 3.2, 4 }, 8)
	sheeted(parts, "SheetMirror", { 15.5, 0, 14.5 }, { 3, 6.5, 1 }, 35)

	-- The rocking horse: faded cream body and red saddle on stepped rockers, glowing red eyes.
	local horse = group(parts, { -6, 0, -5 }, 35, 0)
	local Cream, Faded, Mane = { 205, 192, 170 }, { 150, 40, 40 }, { 50, 36, 30 }
	for i, sx in { -0.7, 0.7 } do
		horse(`RockerMid{i}`, { 0.25, 0.25, 2.4 }, { sx, 0.15, 0 }, Mane, "Wood")
		horse(`RockerFront{i}`, { 0.25, 0.25, 1.2 }, { sx, 0.35, -1.75 }, Mane, "Wood")
		horse(`RockerBack{i}`, { 0.25, 0.25, 1.2 }, { sx, 0.35, 1.75 }, Mane, "Wood")
		horse(`RockerTipFront{i}`, { 0.25, 0.25, 0.5 }, { sx, 0.6, -2.55 }, Mane, "Wood")
		horse(`RockerTipBack{i}`, { 0.25, 0.25, 0.5 }, { sx, 0.6, 2.55 }, Mane, "Wood")
		for j, sz in { -1.1, 1.1 } do
			horse(`HorseLeg{i}_{j}`, { 0.3, 1.6, 0.3 }, { sx * 0.6, 1.07, sz }, Cream, "Wood")
		end
	end
	horse("HorseBody", { 1.2, 1, 3 }, { 0, 2.35, 0 }, Cream, "Wood", true)
	horse("HorseSaddle", { 1.3, 0.2, 1 }, { 0, 2.95, 0.1 }, Faded, "Fabric")
	horse("HorseNeck", { 0.8, 1.4, 0.8 }, { 0, 3.3, -1.3 }, Cream, "Wood")
	horse("HorseHead", { 0.8, 0.9, 1.6 }, { 0, 4.1, -1.8 }, Cream, "Wood")
	horse("HorseMane", { 0.3, 1.5, 0.6 }, { 0, 3.6, -0.95 }, Mane, "Fabric")
	horse("HorseEyeL", { 0.1, 0.2, 0.2 }, { -0.45, 4.25, -2.1 }, { 255, 40, 40 }, "Neon")
	horse("HorseEyeR", { 0.1, 0.2, 0.2 }, { 0.45, 4.25, -2.1 }, { 255, 40, 40 }, "Neon")
	horse("HorseTail", { 0.3, 1.2, 0.3 }, { 0, 2.1, 1.65 }, Mane, "Fabric")
	horse("HorseHandle", { 1.4, 0.2, 0.2 }, { 0, 4, -1.5 }, Mane, "Wood")

	-- Two old trunks against the right wall, and a creepy dress form in the corner.
	local TrunkWood, Band = { 70, 44, 30 }, { 130, 100, 50 }
	for i, z in { -10, -5.5 } do
		local trunk = group(parts, { hw - T - 1.6, 0, z }, 90, 0)
		trunk(`Trunk{i}`, { 3.6, 1.8, 2.2 }, { 0, 0.9, 0 }, TrunkWood, "WoodPlanks", true)
		trunk(`TrunkLid{i}`, { 3.7, 0.5, 2.3 }, { 0, 2.05, 0 }, TrunkWood, "Wood")
		trunk(`TrunkBandA{i}`, { 0.25, 2.35, 2.35 }, { -1.2, 1.17, 0 }, Band, "Metal")
		trunk(`TrunkBandB{i}`, { 0.25, 2.35, 2.35 }, { 1.2, 1.17, 0 }, Band, "Metal")
		trunk(`TrunkLock{i}`, { 0.4, 0.5, 0.15 }, { 0, 1.75, -1.2 }, Band, "Metal")
	end
	local form = group(parts, { 13, 0, -14.5 }, -30, 0)
	form("DressFormFoot", { 1.6, 0.2, 1.6 }, { 0, 0.1, 0 }, Mane, "Wood")
	form("DressFormPole", { 0.25, 3, 0.25 }, { 0, 1.7, 0 }, Mane, "Wood")
	form("DressFormTorso", { 1.6, 2.4, 1 }, { 0, 4.3, 0 }, { 60, 50, 62 }, "Fabric")
	form("DressFormWaist", { 1.2, 0.5, 0.8 }, { 0, 3, 0 }, { 60, 50, 62 }, "Fabric")
	form("DressFormNeck", { 0.5, 0.6, 0.5 }, { 0, 5.8, 0 }, Mane, "Wood")

	-- A stack of boxes in the front-left corner.
	local Box = { 120, 92, 62 }
	part(parts, "BoxA", { 2.4, 2, 2.2 }, { -15.5, 1, -14.5 }, Box, "Wood", true)
	part(parts, "BoxB", { 2.2, 1.8, 2 }, { -12.9, 0.9, -15 }, { 108, 82, 56 }, "Wood", true)
	part(parts, "BoxC", { 1.8, 1.4, 1.8 }, { -15.3, 2.7, -14.4 }, { 132, 102, 70 }, "Wood").rot = { 0, 18, 0 }
	return parts
end

-- A cluster of candles of different heights with one light.
local function candles(parts: { Part }, name: string, x: number, y: number, z: number, light: boolean)
	for i, c in { { -0.35, 1.1, 0.1 }, { 0.3, 0.7, -0.2 }, { 0.05, 0.5, 0.4 }, { -0.1, 0.9, -0.45 } } do
		part(
			parts,
			`{name}{i}`,
			{ 0.3, c[2], 0.3 },
			{ x + c[1], y + c[2] / 2, z + c[3] },
			{ 225, 220, 200 },
			"SmoothPlastic"
		)
		local flame = part(
			parts,
			`{name}Flame{i}`,
			{ 0.18, 0.28, 0.18 },
			{ x + c[1], y + c[2] + 0.14, z + c[3] },
			LanternGlow,
			"Neon"
		)
		if i == 1 and light then
			flame.light = { color = { 255, 170, 80 }, range = 12, brightness = 0.8 }
		end
	end
end

-- The Crypt (behind the Ballroom): stone walls and floor, stone coffins with their heads to
-- the walls (one lid pushed open, green light and a bony hand inside), skulls in wall niches,
-- candles, chains hanging from stone ribs, and an iron gate in the back wall with a sickly
-- green glow behind it.
function Rooms.Crypt(width: number, depth: number, owned: { [string]: boolean }): { Part }
	local parts: { Part } = {}
	local hw, hd = width / 2, depth / 2
	local CoffinStone, CoffinDark, Bone, Green =
		{ 88, 86, 92 }, { 66, 64, 70 }, { 215, 205, 180 }, { 90, 255, 140 }
	local gateW, gateTop = 6, 9
	backShell(
		parts,
		width,
		depth,
		{
			wall = { 50, 52, 56 },
			panel = { 38, 40, 44 },
			trim = { 70, 72, 76 },
			frame = { 44, 46, 50 },
			wallMaterial = "Slate",
			panelMaterial = "Slate",
			trimMaterial = "Slate",
		},
		{ 40, 42, 46 },
		"Slate",
		"Ballroom",
		{
			Left = {},
			Right = {},
			Back = {
				{
					from = hw - gateW / 2,
					to = hw + gateW / 2,
					bottom = 0,
					top = gateTop,
					kind = "Door",
					name = "GreenGate",
				},
			},
		}
	)

	-- Stone ribs across the open top, with chains hanging down.
	for i, z in { -8, 8 } do
		part(parts, `Rib{i}`, { width - 2 * T, 1, 1 }, { 0, H - 0.5, z }, CoffinDark, "Slate")
		for j, x in { -9, -3, 4, 10 } do
			local long = 2 + ((i + j) % 3)
			part(parts, `Chain{i}_{j}`, { 0.2, long, 0.2 }, { x, H - 1 - long / 2, z }, Iron, "Metal")
		end
	end

	-- The gate: iron bars in the opening, a green glow behind, chains and a padlock.
	local gz = hd - T / 2
	local glow = part(parts, "GateGlow", { gateW, gateTop, 0.2 }, { 0, gateTop / 2, hd - 0.1 }, Green, "Neon")
	glow.transparency = 0.25
	glow.light = { color = { 90, 255, 140 }, range = 22, brightness = 1.2 }
	for i = 0, 7 do
		local x = -gateW / 2 + 0.4 + i * (gateW - 0.8) / 7
		part(parts, `GateBar{i}`, { 0.25, 7.6, 0.25 }, { x, 3.8, gz - 0.2 }, Iron, "Metal", true)
		part(parts, `GateSpike{i}`, { 0.35, 0.5, 0.35 }, { x, 7.85, gz - 0.2 }, Iron, "Metal")
	end
	for i, y in { 1.2, 4.6, 7.6 } do
		part(parts, `GateRail{i}`, { gateW - 0.5, 0.3, 0.3 }, { 0, y, gz - 0.2 }, Iron, "Metal")
	end
	for i, tilt in { 30, -30 } do
		local chain = part(
			parts,
			`GateChain{i}`,
			{ 3.4, 0.2, 0.15 },
			{ 0, 4.2, gz - 0.45 },
			{ 70, 70, 76 },
			"Metal"
		)
		chain.rot = { 0, 0, tilt }
	end
	part(parts, "GatePadlock", { 0.7, 0.8, 0.3 }, { 0, 3.9, gz - 0.6 }, Brass, "Metal")

	-- Stone coffins with their heads against the side walls.
	local function coffin(name: string, x: number, z: number, open: boolean)
		local s = if x < 0 then -1 else 1 -- which wall the head is against
		part(parts, name .. "Plinth", { 7.4, 0.4, 3.8 }, { x, 0.2, z }, CoffinDark, "Slate", true)
		part(parts, name, { 7, 2, 3.4 }, { x, 1.4, z }, CoffinStone, "Slate", true)
		if open then
			part(parts, name .. "Inside", { 6.4, 0.05, 2.8 }, { x, 2.42, z }, { 16, 16, 18 }, "Slate")
			local inside = part(parts, name .. "Glow", { 5.6, 0.05, 2.2 }, { x, 2.45, z }, Green, "Neon")
			inside.transparency = 0.35
			inside.light = { color = { 90, 255, 140 }, range = 10, brightness = 0.8 }
			-- The lid pushed half off, resting crooked on the far edge.
			local lid = part(
				parts,
				name .. "Lid",
				{ 7.2, 0.5, 3.6 },
				{ x - s * 0.6, 2.67, z + 1.6 },
				CoffinStone,
				"Slate"
			)
			lid.rot = { 0, 14, 0 }
			-- A bony hand reaching over the edge.
			part(
				parts,
				name .. "HandBone",
				{ 0.3, 0.3, 1.2 },
				{ x - s * 1.2, 2.6, z - 1.5 },
				Bone,
				"SmoothPlastic"
			)
			for f = 1, 3 do
				part(parts, `{name}Finger{f}`, { 0.12, 0.6, 0.12 }, {
					x - s * 1.2 + (f - 2) * 0.18,
					2.3,
					z - 2.05,
				}, Bone, "SmoothPlastic")
			end
		else
			part(parts, name .. "Lid", { 7.2, 0.5, 3.6 }, { x, 2.65, z }, CoffinStone, "Slate")
			part(parts, name .. "CrossLong", { 3, 0.12, 0.4 }, { x - s * 0.3, 2.96, z }, CoffinDark, "Slate")
			part(
				parts,
				name .. "CrossShort",
				{ 0.4, 0.12, 1.8 },
				{ x + s * 0.5, 2.96, z },
				CoffinDark,
				"Slate"
			)
		end
	end
	local cx = hw - T - 0.4 - 3.7
	coffin("CoffinRightA", cx, -10, false)
	coffin("CoffinRightB", cx, 0.5, true)
	coffin("CoffinRightC", cx, 11, false)
	coffin("CoffinLeftA", -cx, -10, false)
	coffin("CoffinLeftB", -cx, 11, false)

	-- Niches with skulls above the coffins, and candles between them.
	for i, spot in { { -1, -10 }, { -1, 11 }, { 1, -10 }, { 1, 0.5 }, { 1, 11 } } do
		local x = spot[1] * (hw - T - 0.08)
		part(parts, `Niche{i}`, { 0.15, 1.6, 2.2 }, { x, 9.5, spot[2] }, { 18, 18, 20 }, "Slate")
		part(
			parts,
			`NicheShelf{i}`,
			{ 0.8, 0.2, 2.4 },
			{ x - spot[1] * 0.4, 8.6, spot[2] },
			CoffinDark,
			"Slate"
		)
		part(
			parts,
			`Skull{i}`,
			{ 0.8, 0.75, 0.8 },
			{ x - spot[1] * 0.5, 9.08, spot[2] },
			Bone,
			"SmoothPlastic"
		)
		part(
			parts,
			`SkullEyes{i}`,
			{ 0.1, 0.2, 0.55 },
			{ x - spot[1] * 0.92, 9.15, spot[2] },
			{ 18, 18, 20 },
			"SmoothPlastic"
		)
	end
	candles(parts, "CandlesGateL", -4.5, 0, hd - T - 1, true)
	candles(parts, "CandlesGateR", 4.5, 0, hd - T - 1, false)
	candles(parts, "CandlesLeft", -cx + 1, 0, 3, true)
	candles(parts, "CandlesCoffin", cx + 1.5, 2.9, 11, false)
	return parts
end

-- A lamp post: an iron post with a lantern on top.
local function lampPost(parts: { Part }, name: string, x: number, z: number)
	part(parts, name .. "Base", { 1, 0.6, 1 }, { x, 0.3, z }, Iron, "Metal", true)
	part(parts, name .. "Post", { 0.4, 6.4, 0.4 }, { x, 3.5, z }, Iron, "Metal", true)
	lantern(parts, name, x, 7.4, z, { 0, 0 })
end

-- A dead tree: a leaning trunk and bare, crooked branches.
local function deadTree(parts: { Part }, name: string, x: number, z: number, turn: number)
	local Bark = { 52, 42, 36 }
	part(parts, name .. "Roots", { 2.4, 0.6, 2.4 }, { x, 0.3, z }, Bark, "Wood", true)
	local top = stick(parts, name .. "Trunk", { x, 0, z }, turn, 82, 8, 1.4, Bark, "Wood")
	local mid = { x + (top[1] - x) * 0.6, top[2] * 0.6, z + (top[3] - z) * 0.6 }
	stick(parts, name .. "BranchA", mid, turn + 70, 35, 4, 0.6, Bark, "Wood")
	local b = stick(parts, name .. "BranchB", top, turn - 50, 40, 4.5, 0.6, Bark, "Wood")
	stick(parts, name .. "BranchC", top, turn + 140, 25, 4, 0.5, Bark, "Wood")
	stick(parts, name .. "TwigA", b, turn - 10, 60, 2, 0.3, Bark, "Wood")
	stick(parts, name .. "TwigB", b, turn - 100, 10, 1.8, 0.3, Bark, "Wood")
	stick(parts, name .. "BranchD", mid, turn - 160, 20, 3, 0.5, Bark, "Wood")
end

-- The Garden (behind the Foyer): an outdoor room of dead grass inside tall hedges, a dry
-- fountain with a headless angel, cobbled paths, two dead trees, gravestones in rows and
-- iron lamp posts. The front hedge has a gap under an iron arch facing the Foyer's back door.
function Rooms.Garden(width: number, depth: number, owned: { [string]: boolean }): { Part }
	local parts: { Part } = {}
	local hw, hd = width / 2, depth / 2
	local Hedge, Cobble, Dirt = { 30, 44, 30 }, { 72, 70, 74 }, { 58, 44, 32 }
	local FountainStone = { 104, 102, 108 }
	part(parts, "Floor", { width, 1, depth }, { 0, -0.5, 0 }, { 50, 54, 36 }, "Grass", true)
	part(parts, "Threshold", { 8, 1, 2 }, { 0, -0.5, -hd - 1 }, Stone, "Slate", true)
	cornerPillars(parts, hw, hd)

	-- Hedges between the corner pillars, with a gap at the front under an iron arch.
	local inner = hw - 2.5 -- where the pillar bases stop
	part(parts, "HedgeLeft", { 2, 4.5, 2 * inner }, { -hw + 1.5, 2.25, 0 }, Hedge, "Grass", true)
	part(parts, "HedgeRight", { 2, 4.5, 2 * inner }, { hw - 1.5, 2.25, 0 }, Hedge, "Grass", true)
	part(parts, "HedgeBack", { 2 * inner, 4.5, 2 }, { 0, 2.25, hd - 1.5 }, Hedge, "Grass", true)
	local gap = 4.5
	for i, s in { -1, 1 } do
		part(
			parts,
			`HedgeFront{i}`,
			{ inner - gap, 4.5, 2 },
			{ s * (gap + inner) / 2, 2.25, -hd + 1.5 },
			Hedge,
			"Grass",
			true
		)
		part(
			parts,
			`ArchPost{i}`,
			{ 0.6, 7.5, 0.6 },
			{ s * (gap - 0.3), 3.75, -hd + 1.5 },
			Iron,
			"Metal",
			true
		)
	end
	part(parts, "ArchTop", { 2 * gap, 0.5, 0.5 }, { 0, 7.75, -hd + 1.5 }, Iron, "Metal")
	part(parts, "ArchCrest", { gap, 0.4, 0.4 }, { 0, 8.45, -hd + 1.5 }, Iron, "Metal")
	part(parts, "ArchSpike", { 0.4, 1, 0.4 }, { 0, 9.1, -hd + 1.5 }, Iron, "Metal")

	-- Cobbled path from the arch to the fountain, and a square path around it.
	local fz = 2 -- fountain centre
	part(
		parts,
		"PathFront",
		{ 3, 0.1, hd - 0.5 + fz - 8 },
		{ 0, 0.05, (-hd + 0.5 + fz - 8) / 2 },
		Cobble,
		"Cobblestone"
	)
	for i, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local size = if side[1] == 0 then { 16, 0.1, 2 } else { 2, 0.1, 12 }
		part(parts, `PathRing{i}`, size, { side[1] * 7, 0.05, fz + side[2] * 7 }, Cobble, "Cobblestone")
	end

	-- The dry fountain: a square basin with cracked dirt and dead leaves, a pedestal and bowl,
	-- and a weeping angel whose head has broken off (it lies in the basin).
	for i, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local size = if side[1] == 0 then { 11.6, 1.5, 0.8 } else { 0.8, 1.5, 10 }
		part(
			parts,
			`Basin{i}`,
			size,
			{ side[1] * 5.4, 0.75, fz + side[2] * 5.4 },
			FountainStone,
			"Slate",
			true
		)
	end
	part(parts, "BasinDirt", { 10, 0.2, 10 }, { 0, 0.1, fz }, Dirt, "Ground")
	for i, crack in { { -2, 1, 30 }, { 2.5, -1.5, -40 }, { 1, 3, 75 } } do
		local line = part(
			parts,
			`BasinCrack{i}`,
			{ 3, 0.04, 0.12 },
			{ crack[1], 0.21, fz + crack[2] },
			{ 30, 22, 16 },
			"Ground"
		)
		line.rot = { 0, crack[3], 0 }
	end
	local roll = dice(5)
	for i = 1, 8 do
		local leaf = part(parts, `DeadLeaf{i}`, { 0.5, 0.05, 0.35 }, {
			roll() * 8 - 4,
			0.23,
			fz + roll() * 8 - 4,
		}, if i % 2 == 0 then { 120, 70, 30 } else { 90, 54, 30 }, "Fabric")
		leaf.rot = { 0, roll() * 180, 0 }
	end
	part(parts, "Pedestal", { 1.4, 3, 1.4 }, { 0, 1.7, fz }, FountainStone, "Slate", true)
	part(parts, "Bowl", { 4, 0.6, 4 }, { 0, 3.5, fz }, FountainStone, "Slate")
	part(parts, "BowlRim", { 4.4, 0.3, 4.4 }, { 0, 3.95, fz }, { 92, 96, 84 }, "Slate")
	part(parts, "AngelBody", { 1, 2.4, 0.8 }, { 0, 5.3, fz }, FountainStone, "Slate")
	part(parts, "AngelNeck", { 0.4, 0.3, 0.4 }, { 0, 6.65, fz }, FountainStone, "Slate")
	for i, s in { -1, 1 } do
		local wing = part(
			parts,
			`AngelWing{i}`,
			{ 0.25, 2.2, 1.4 },
			{ s * 0.65, 5.7, fz + 0.6 },
			FountainStone,
			"Slate"
		)
		wing.rot = { -20, s * 25, 0 }
		local arm = part(
			parts,
			`AngelArm{i}`,
			{ 0.3, 1.4, 0.3 },
			{ s * 0.25, 5.9, fz - 0.55 },
			FountainStone,
			"Slate"
		)
		arm.rot = { 50, 0, s * -15 } -- hands over its face, weeping
	end
	part(parts, "AngelHead", { 0.8, 0.8, 0.8 }, { 2.4, 0.6, fz - 2.5 }, FountainStone, "Slate").rot =
		{ 20, 35, 70 }
	part(parts, "Moss", { 1.2, 0.08, 1.4 }, { -1.2, 4.14, fz + 0.8 }, { 60, 84, 46 }, "Grass")

	-- Two dead trees at the front corners.
	deadTree(parts, "TreeLeft", -13, -12, 20)
	deadTree(parts, "TreeRight", 13.5, -13, 160)

	-- Gravestones in rows at the back, some crooked, each with a mound of dirt in front.
	-- A gravestone leaning `lean` degrees forward (+) or back (-), pivoting at the ground.
	local function grave(name: string, x: number, z: number, kind: number, lean: number)
		part(parts, name .. "Mound", { 1.8, 0.3, 3 }, { x, 0.15, z - 1.9 }, Dirt, "Ground")
		local a = math.rad(-lean)
		local function piece(
			suffix: string,
			size: { number },
			height: number,
			color: { number },
			solid: boolean?
		)
			-- `height` is the piece's centre above the ground before leaning.
			local p = part(parts, name .. suffix, size, {
				x,
				height * math.cos(a),
				z + height * math.sin(a),
			}, color, "Slate", solid)
			if lean ~= 0 then
				p.rot = { -lean, 0, 0 }
			end
		end
		if kind == 1 then
			piece("", { 2, 2.6, 0.5 }, 1.3, Stone, true)
			piece("Top", { 1.4, 0.4, 0.5 }, 2.8, Stone)
		elseif kind == 2 then
			piece("", { 0.5, 3, 0.4 }, 1.5, StoneDark, true)
			piece("Arm", { 1.8, 0.5, 0.4 }, 2.2, StoneDark)
		else
			piece("", { 1.6, 1.8, 0.6 }, 0.9, { 82, 80, 88 }, true)
		end
	end
	grave("GraveA", -15, 14, 1, 0)
	grave("GraveB", -11, 14.5, 2, 6)
	grave("GraveC", -7, 14, 3, -4)
	grave("GraveD", 7, 14, 1, -3)
	grave("GraveE", 11, 14.5, 3, 0)
	grave("GraveF", 15, 14, 2, -8)
	grave("GraveG", -14, 8, 3, 5)
	grave("GraveH", -10, 8.5, 1, 0)
	grave("GraveI", 10, 8.5, 2, 0)
	grave("GraveJ", 14, 8, 1, 7)

	-- Lamp posts beside the path and behind the fountain.
	lampPost(parts, "LampLeft", -3.2, -13)
	lampPost(parts, "LampRight", 3.2, -13)
	lampPost(parts, "LampBack", 0, 15)
	return parts
end

-- Room recipes by wing id. A wing without one is built as a placeholder by MansionService.
Rooms.ByWing = {
	Foyer = Rooms.Foyer,
	Library = Rooms.Library,
	Ballroom = Rooms.Ballroom,
	Attic = Rooms.Attic,
	Crypt = Rooms.Crypt,
	Garden = Rooms.Garden,
} :: { [string]: (width: number, depth: number, owned: { [string]: boolean }) -> { Part } }

-- Everything about a part in one string: two parts with the same key look exactly the same.
-- MansionService compares keys to rebuild only the parts of a room that changed (a door that
-- opens when its wing is bought), so the rest of the mansion never blinks.
function Rooms.key(p: Part): string
	local function list(values: { number }?): string
		return if values then table.concat(values, ",") else "-"
	end
	local light = if p.light then `{list(p.light.color)}/{p.light.range}/{p.light.brightness}` else "-"
	return table.concat({
		p.name,
		list(p.size),
		list(p.at),
		list(p.rot),
		list(p.color),
		p.material,
		p.shape or "Block",
		tostring(p.solid == true),
		tostring(p.transparency or 0),
		light,
		p.text or "-",
	}, "|")
end

-- The building blocks, for other recipes in the same style (Config/Landmarks).
Rooms.Kit = {
	part = part,
	lantern = lantern,
	group = group,
	dice = dice,
	stick = stick,
	candles = candles,
	lampPost = lampPost,
	deadTree = deadTree,
}

return Rooms
