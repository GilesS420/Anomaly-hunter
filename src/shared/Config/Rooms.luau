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

local function wallRun(parts: { Part }, side: string, length: number, openings: { Opening })
	-- Turns a distance along the wall and a thickness offset into room-local x, z.
	local function place(along: number, inward: number): (number, number)
		if side == "Left" then
			return -length / 2 + T / 2 + inward, -length / 2 + along
		elseif side == "Right" then
			return length / 2 - T / 2 - inward, -length / 2 + along
		end
		return -length / 2 + along, length / 2 - T / 2 - inward
	end
	local function sized(alongSize: number, height: number, depth: number): { number }
		if side == "Back" then
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
			Wall,
			"Plaster",
			true
		)
		-- Dark wainscot panelling on the lower part, facing into the room.
		if bottom < 3 then
			local px, pz = place((from + to) / 2, T / 2 + 0.1)
			part(parts, name .. "Panel", sized(to - from, math.min(top, 3) - bottom, 0.2), {
				px,
				(bottom + math.min(top, 3)) / 2,
				pz,
			}, Panel, "WoodPlanks")
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
	part(parts, side .. "Crown", sized(length, 0.6, T + 0.6), { tx, H + 0.3, tz }, Trim, "Wood")
	-- A chair rail where the panelling stops, broken at every doorway (and its frame).
	local railFrom = 0
	local function rail(i: number, to: number)
		if to - railFrom > 0.01 then
			local rx, rz = place((railFrom + to) / 2, T / 2 + 0.15)
			part(parts, `{side}Rail{i}`, sized(to - railFrom, 0.25, 0.3), { rx, 3, rz }, Trim, "Wood")
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
		local frameColor = if opening.kind == "Door" then Trim else WallDark
		part(parts, opening.name .. "JambA", sized(0.5, opening.top - opening.bottom, T + 0.4), {
			fx1,
			(opening.bottom + opening.top) / 2,
			fz1,
		}, frameColor, "Wood")
		part(parts, opening.name .. "JambB", sized(0.5, opening.top - opening.bottom, T + 0.4), {
			fx2,
			(opening.bottom + opening.top) / 2,
			fz2,
		}, frameColor, "Wood")
		part(
			parts,
			opening.name .. "Head",
			sized(width + 1, 0.6, T + 0.4),
			{ cx, opening.top + 0.3, cz },
			frameColor,
			"Wood"
		)
		if opening.kind == "Window" then
			part(parts, opening.name .. "Ledge", sized(width + 0.6, 0.3, T + 0.8), {
				cx,
				opening.bottom - 0.15,
				cz,
			}, frameColor, "Wood")
			-- One loose board nailed across, crooked: haunted, but you can still see in.
			local board = part(
				parts,
				opening.name .. "Board",
				sized(width + 0.4, 0.5, 0.2),
				{ cx, opening.bottom + (opening.top - opening.bottom) * 0.62, cz },
				Board,
				"WoodPlanks"
			)
			board.rot = if side == "Back" then { 0, 0, 14 } else { 14, 0, 0 }
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

	-- Stone corner pillars, taller than the walls, with caps.
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

	-- Front: open, behind a low wrought-iron fence with a gate between two stone posts.
	local gateHalf = 5
	for i, s in { -1, 1 } do
		local from, to = gateHalf + 1.5, hw - 2.2
		local cx = s * (from + to) / 2
		part(parts, `FenceRail{i}`, { to - from, 0.3, 0.3 }, { cx, 3.2, -hd + 0.5 }, Iron, "Metal", true)
		part(parts, `FenceRailLow{i}`, { to - from, 0.3, 0.3 }, { cx, 0.8, -hd + 0.5 }, Iron, "Metal", true)
		local count = math.floor((to - from) / 1.5)
		for j = 0, count do
			local x = s * (from + j * (to - from) / count)
			part(parts, `FenceBar{i}_{j}`, { 0.2, 3.6, 0.2 }, { x, 1.8, -hd + 0.5 }, Iron, "Metal", true)
			part(parts, `FenceTip{i}_{j}`, { 0.3, 0.5, 0.3 }, { x, 3.85, -hd + 0.5 }, Iron, "Metal")
		end
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
	part(parts, "BeamCross", { 17, 1, 1 }, { 0, H - 0.5, 0 }, Trim, "Wood")
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

return Rooms
