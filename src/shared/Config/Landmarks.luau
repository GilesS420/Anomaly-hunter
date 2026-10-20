--!strict
-- What the hub landmarks look like: Watcher Square, the Haunted Bakery and the Hunter's
-- Workshop, as data in the same format as Config/Rooms. WorldBuilder builds them (and the
-- preview page draws them the same way).
--
-- Landmark-local studs: the ground's top is y = 0 and the landmark's spot in
-- Layout.Landmarks is x = z = 0. -Z is the front, the side facing the middle of the hub.

local Rooms = require("./Rooms")

type Part = Rooms.Part

local Kit = Rooms.Kit
local part, group = Kit.part, Kit.group

local Landmarks = {}

-- Colours.
local Cobble = { 74, 70, 82 }
local Stone = { 96, 92, 104 }
local StoneDark = { 52, 50, 58 }
local Bone = { 200, 190, 165 }
local IrisRed = { 110, 28, 52 }
local Iron = { 34, 34, 38 }
local BenchWood = { 60, 44, 36 }
local BoardWood = { 196, 170, 120 }
local WatcherPurple = { 170, 90, 255 }
local Ink = { 20, 16, 22 }
local Glow = { 255, 170, 80 }

local PurpleLight: Rooms.Light = { color = WatcherPurple, range = 14, brightness = 1 }

local function rad(deg: number): number
	return math.rad(deg)
end

-- A point `r` studs from the middle, `deg` degrees round from +X toward +Z.
local function polar(r: number, deg: number): (number, number)
	return r * math.cos(rad(deg)), r * math.sin(rad(deg))
end

-- The yaw that lays a part's X along the circle at `deg`, with its front (-Z) facing outward.
local function outward(deg: number): number
	return -(deg + 90)
end

-- Runs `build` and lifts every part it adds by `dy` (Kit helpers stand on y = 0).
local function lifted(parts: { Part }, dy: number, build: () -> ())
	local first = #parts + 1
	build()
	for i = first, #parts do
		local at = parts[i].at
		parts[i].at = { at[1], at[2] + dy, at[3] }
	end
end

------------------------------------------------------------------------------------------
-- Watcher Square
------------------------------------------------------------------------------------------

Landmarks.SquareRadius = 30
local PlazaTop = 1 -- the Watcher's meter (WatcherService) stands on this, 4 x 4 in the middle

-- A round cobbled plaza with a giant eye laid in the stones, its pupil a stepped plinth around
-- the Watcher's meter. A low kerb runs round the edge with an iron arch over each of the four
-- ways in, and lamp posts, dead trees, benches and two little eye shrines stand in the ring.
function Landmarks.WatcherSquare(): { Part }
	local parts: { Part } = {}
	local R = Landmarks.SquareRadius
	local top = PlazaTop

	local plaza = part(parts, "Plaza", { top, R * 2, R * 2 }, { 0, top / 2, 0 }, Cobble, "Cobblestone", true)
	plaza.shape = "Cylinder"
	plaza.rot = { 0, 0, 90 }

	-- The eye: rows of flat tiles, a pale almond with a dark red iris round the plinth.
	local halfLength, halfDepth, irisRadius, plinth = 20, 9, 9, 6
	local function snap(n: number): number
		return math.floor(n * 2 + 0.5) / 2
	end
	for row = 1, halfDepth * 2 do
		local z = row - halfDepth - 0.5
		local reach = snap(halfLength * math.sqrt(1 - math.abs(z) / halfDepth))
		local iris = math.min(reach, snap(math.sqrt(irisRadius ^ 2 - z ^ 2)))
		local function tiles(name: string, from: number, to: number, color: { number })
			if to <= from then
				return
			end
			if from == 0 then
				part(parts, name, { to * 2, 0.1, 1 }, { 0, top + 0.05, z }, color, "Slate")
				return
			end
			for _, side in { -1, 1 } do
				local tag = if side < 0 then "Left" else "Right"
				part(
					parts,
					name .. tag,
					{ to - from, 0.1, 1 },
					{ side * (from + to) / 2, top + 0.05, z },
					color,
					"Slate"
				)
			end
		end
		if math.abs(z) < plinth then
			tiles(`Iris{row}`, plinth, iris, IrisRed)
			tiles(`Eye{row}`, math.max(iris, plinth), reach, Bone)
		else
			tiles(`Iris{row}`, 0, iris, IrisRed)
			tiles(`Eye{row}`, iris, reach, Bone)
		end
	end

	-- The pupil: two square steps round the meter, with purple braziers on the corners.
	local function squareRing(name: string, outer: number, inner: number, height: number, y: number)
		local w = (outer - inner) / 2
		local mid = inner / 2 + w / 2
		part(parts, name .. "Front", { outer, height, w }, { 0, y, -mid }, StoneDark, "Slate", true)
		part(parts, name .. "Back", { outer, height, w }, { 0, y, mid }, StoneDark, "Slate", true)
		part(parts, name .. "Left", { w, height, inner }, { -mid, y, 0 }, StoneDark, "Slate", true)
		part(parts, name .. "Right", { w, height, inner }, { mid, y, 0 }, StoneDark, "Slate", true)
	end
	squareRing("PlinthLow", 12, 4, 0.6, top + 0.3)
	squareRing("PlinthHigh", 8, 4, 0.6, top + 0.9)
	for i, corner in { { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } } do
		local x, z = corner[1], corner[2]
		part(parts, `Brazier{i}Stand`, { 1, 0.6, 1 }, { x, top + 0.9, z }, Iron, "Metal", true)
		part(parts, `Brazier{i}Bowl`, { 1.4, 0.4, 1.4 }, { x, top + 1.4, z }, Iron, "Metal", true)
		local flame = part(
			parts,
			`Brazier{i}`,
			{ 0.7, 0.7, 0.7 },
			{ x, top + 1.95, z },
			WatcherPurple,
			"Neon"
		)
		if i == 1 or i == 4 then
			flame.light = PurpleLight
		end
	end

	-- The kerb, with gaps for the four ways in.
	local kerbRadius, segments = R - 0.6, 32
	local length = 2 * (kerbRadius - 0.6) * math.sin(math.pi / segments)
	for i = 0, segments - 1 do
		local deg = (i + 0.5) * 360 / segments
		local fromWay = deg % 90
		if math.min(fromWay, 90 - fromWay) > 20 then
			local x, z = polar(kerbRadius, deg)
			local kerb = part(
				parts,
				`Kerb{i + 1}`,
				{ length, 1.2, 1.2 },
				{ x, top + 0.6, z },
				Stone,
				"Slate",
				true
			)
			kerb.rot = { 0, outward(deg), 0 }
		end
	end

	-- An iron arch over each way in: two stone pillars, a bar, a sign each side and a glowing eye.
	local gateHalf = 20.7 -- degrees either side of the way in
	for g, deg in { 0, 90, 180, 270 } do
		for _, side in { -1, 1 } do
			local d = deg + side * gateHalf
			local x, z = polar(kerbRadius, d)
			local tag = if side < 0 then "Left" else "Right"
			local pillar = part(
				parts,
				`Gate{g}Pillar{tag}`,
				{ 1.6, 7, 1.6 },
				{ x, top + 3.5, z },
				Stone,
				"Slate",
				true
			)
			pillar.rot = { 0, outward(d), 0 }
			local cap = part(
				parts,
				`Gate{g}Cap{tag}`,
				{ 2, 0.4, 2 },
				{ x, top + 7.2, z },
				StoneDark,
				"Slate",
				true
			)
			cap.rot = { 0, outward(d), 0 }
		end
		local chord = kerbRadius * math.cos(rad(gateHalf))
		local span = 2 * kerbRadius * math.sin(rad(gateHalf))
		local x, z = polar(chord, deg)
		local bar = part(
			parts,
			`Gate{g}Bar`,
			{ span + 2, 0.5, 0.6 },
			{ x, top + 7.65, z },
			Iron,
			"Metal",
			true
		)
		bar.rot = { 0, outward(deg), 0 }
		for _, face in { { "Out", 1, 0 }, { "In", -1, 180 } } do
			local ox, oz = polar(0.15 * face[2] :: number, deg)
			local board = part(
				parts,
				`Gate{g}Sign{face[1]}`,
				{ 9, 1.6, 0.3 },
				{ x + ox, top + 6.6, z + oz },
				BoardWood,
				"WoodPlanks"
			)
			board.rot = { 0, outward(deg) + face[3] :: number, 0 }
			board.text = "Watcher Square"
		end
		local eye = part(parts, `Gate{g}Eye`, { 1.4, 1.4, 1.4 }, { x, top + 8.6, z }, WatcherPurple, "Neon")
		eye.shape = "Ball"
		if g % 2 == 1 then
			eye.light = PurpleLight
		end
	end

	-- Lamp posts between the ways in.
	for i, deg in { 45, 135, 225, 315 } do
		local x, z = polar(25, deg)
		lifted(parts, top, function()
			Kit.lampPost(parts, `Lamp{i}`, x, z)
		end)
	end

	-- Two dead trees and two eye shrines across from each other, and benches facing the eye.
	for i, deg in { 67.5, 247.5 } do
		local x, z = polar(23, deg)
		lifted(parts, top, function()
			Kit.deadTree(parts, `Tree{i}`, x, z, outward(deg) + 180)
		end)
	end
	for i, deg in { 112.5, 292.5 } do
		local x, z = polar(23, deg)
		local add = group(parts, { x, top, z }, outward(deg), 0)
		add(`Shrine{i}Base`, { 4, 0.5, 1.6 }, { 0, 0.25, 0 }, StoneDark, "Slate", true)
		add(`Shrine{i}`, { 3, 4, 0.8 }, { 0, 2.5, 0 }, Stone, "Slate", true)
		add(`Shrine{i}Top`, { 3.4, 0.4, 1 }, { 0, 4.7, 0 }, StoneDark, "Slate", true)
		add(`Shrine{i}Eye`, { 1.8, 0.8, 0.1 }, { 0, 3, 0.45 }, Bone, "SmoothPlastic")
		add(`Shrine{i}Pupil`, { 0.6, 0.6, 0.1 }, { 0, 3, 0.55 }, WatcherPurple, "Neon")
		for _, side in { -1, 1 } do
			local cx, cz = polar(21.5, deg + side * 3)
			local tag = if side < 0 then "Left" else "Right"
			Kit.candles(parts, `Shrine{i}Candle{tag}`, cx, top, cz, side > 0)
		end
	end
	for i, deg in { 22.5, 157.5, 202.5, 337.5 } do
		local x, z = polar(22, deg)
		local add = group(parts, { x, top, z }, outward(deg), 0)
		add(`Bench{i}LegLeft`, { 0.4, 1.35, 1.1 }, { -1.7, 0.675, 0 }, Iron, "Metal", true)
		add(`Bench{i}LegRight`, { 0.4, 1.35, 1.1 }, { 1.7, 0.675, 0 }, Iron, "Metal", true)
		add(`Bench{i}Seat`, { 4.4, 0.3, 1.3 }, { 0, 1.5, 0 }, BenchWood, "WoodPlanks", true)
		add(`Bench{i}Back`, { 4.4, 1.4, 0.25 }, { 0, 2.35, -0.525 }, BenchWood, "WoodPlanks", true)
	end

	return parts
end

------------------------------------------------------------------------------------------
-- The shops
------------------------------------------------------------------------------------------

-- Where a shop's "hold E" prompt sits (see Counter): an invisible post in front of the
-- middle of the counter. WorldBuilder makes it the shop model's PrimaryPart.
Landmarks.CounterSpot = "CounterSpot"

type Theme = {
	title: string,
	wall: { number },
	trim: { number },
	roof: { number },
	deck: { number },
	sign: { number },
	awning: { { number } }, -- the stripes, in turn
}

local DeckTop = 0.6

-- What both shops share: a plank deck, a little shop with a tall stepped false front and its
-- name on a big sign, the front open behind a counter under a striped awning, and lanterns
-- on the corner posts. The shopkeeper stands behind the counter (z 0.6 .. 2.6).
local function shop(parts: { Part }, theme: Theme)
	local y = DeckTop
	part(parts, "Deck", { 34, y, 30 }, { 0, y / 2, 3 }, theme.deck, "WoodPlanks", true)

	-- The shop: back and side walls, a flat roof, and the false front over the open front.
	part(parts, "BackWall", { 32, 15, 1 }, { 0, y + 7.5, 17.5 }, theme.wall, "WoodPlanks", true)
	part(parts, "LeftWall", { 1, 15, 13 }, { -15.5, y + 7.5, 10.5 }, theme.wall, "WoodPlanks", true)
	part(parts, "RightWall", { 1, 15, 13 }, { 15.5, y + 7.5, 10.5 }, theme.wall, "WoodPlanks", true)
	part(parts, "Facade", { 32, 6, 1 }, { 0, y + 12, 3.5 }, theme.wall, "WoodPlanks", true)
	part(parts, "Roof", { 34, 0.6, 15 }, { 0, y + 15.3, 10.5 }, theme.roof, "Slate", true)
	part(parts, "StepLow", { 26, 1.5, 1 }, { 0, y + 16.35, 3.5 }, theme.wall, "WoodPlanks", true)
	part(parts, "StepHigh", { 14, 1.5, 1 }, { 0, y + 17.85, 3.5 }, theme.wall, "WoodPlanks", true)
	part(parts, "StepHighCap", { 14.4, 0.3, 1.4 }, { 0, y + 18.75, 3.5 }, theme.trim, "Wood", true)
	part(parts, "StepLowCapLeft", { 6.2, 0.3, 1.4 }, { -10.1, y + 17.25, 3.5 }, theme.trim, "Wood", true)
	part(parts, "StepLowCapRight", { 6.2, 0.3, 1.4 }, { 10.1, y + 17.25, 3.5 }, theme.trim, "Wood", true)
	part(parts, "PostLeft", { 1, 9, 1 }, { -15.5, y + 4.5, 3.5 }, theme.trim, "Wood", true)
	part(parts, "PostRight", { 1, 9, 1 }, { 15.5, y + 4.5, 3.5 }, theme.trim, "Wood", true)
	part(parts, "FacadeTrim", { 32, 0.4, 0.3 }, { 0, y + 9.2, 2.85 }, theme.trim, "Wood")
	local sign = part(parts, "Sign", { 22, 3.6, 0.3 }, { 0, y + 12, 2.85 }, theme.sign, "WoodPlanks")
	sign.text = theme.title
	Kit.lantern(parts, "LanternLeft", -15.5, y + 6.5, 2.85, { 0, -1 })
	Kit.lantern(parts, "LanternRight", 15.5, y + 6.5, 2.85, { 0, -1 })

	-- The counter, and the spot players walk up to.
	part(parts, "Counter", { 20, 3.2, 2.4 }, { 0, y + 1.6, -1 }, theme.wall, "WoodPlanks", true)
	part(parts, "CounterTop", { 21, 0.3, 3 }, { 0, y + 3.35, -1 }, theme.trim, "Wood", true)
	local spot = part(
		parts,
		Landmarks.CounterSpot,
		{ 0.2, 6, 0.2 },
		{ 0, 3, -2.8 },
		{ 255, 255, 255 },
		"SmoothPlastic"
	)
	spot.transparency = 1

	-- The awning: stripes sloping down from under the false front, scalloped flaps along the
	-- front edge and two iron poles holding it up.
	local backZ, backY, frontZ, frontY, thick = 2.8, y + 8.9, -6, y + 7.6, 0.3
	local dz, dy = backZ - frontZ, backY - frontY
	local slope = math.deg(math.atan(dy / dz))
	local ny, nz = math.cos(math.rad(slope)), -math.sin(math.rad(slope)) -- the stripes' up
	for i = 1, 12 do
		local x = -13 + i * 2
		local color = theme.awning[(i - 1) % #theme.awning + 1]
		local stripe = part(parts, `Awning{i}`, { 2, thick, math.sqrt(dz * dz + dy * dy) }, {
			x,
			(backY + frontY) / 2 - ny * thick / 2,
			(backZ + frontZ) / 2 - nz * thick / 2,
		}, color, "Fabric", true)
		stripe.rot = { -slope, 0, 0 }
		local flap = theme.awning[i % #theme.awning + 1]
		part(
			parts,
			`AwningFlap{i}`,
			{ 2, 0.8, 0.15 },
			{ x, frontY - thick - 0.45, frontZ - 0.1 },
			flap,
			"Fabric"
		)
	end
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(parts, `AwningPole{tag}`, { 0.3, 7.2, 0.3 }, { side * 11.6, y + 3.6, -5.6 }, Iron, "Metal", true)
	end
	return y
end

-- Shelves of three boards between two uprights, against the back wall.
local function shelves(parts: { Part }, name: string, x: number, color: { number }): { number }
	local y = DeckTop
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(
			parts,
			`{name}Side{tag}`,
			{ 0.3, 9.3, 2 },
			{ x + side * 4.15, y + 4.65, 16 },
			color,
			"Wood",
			true
		)
	end
	local tops = {}
	for i = 1, 3 do
		part(parts, `{name}Board{i}`, { 8, 0.3, 2 }, { x, y + i * 3, 16 }, color, "Wood", true)
		table.insert(tops, y + i * 3 + 0.15)
	end
	return tops
end

local Pink = { 200, 104, 140 }
local Cream = { 236, 222, 198 }
local Plum = { 98, 60, 78 }
local Bread = { 180, 120, 60 }
local Chocolate = { 90, 50, 40 }
local Wrapper = { 120, 70, 150 }
local Ghost = { 235, 235, 245 }

-- The Haunted Bakery: a plum and cream shop under a pink striped awning, a giant cupcake with
-- glowing eyes on the roof, two brick ovens glowing at the back, shelves of bread, and a
-- friendly ghost baker in a chef's hat behind a counter of cakes and cupcakes.
function Landmarks.Bakery(): { Part }
	local parts: { Part } = {}
	local y = shop(parts, {
		title = "Haunted Bakery",
		wall = Plum,
		trim = Cream,
		roof = { 60, 40, 52 },
		deck = { 70, 52, 44 },
		sign = { 236, 214, 170 },
		awning = { Pink, Cream },
	})

	-- Ovens and bread at the back.
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		local x = side * 9.5
		part(parts, `Oven{tag}`, { 6, 7, 3 }, { x, y + 3.5, 15.5 }, { 120, 60, 50 }, "Brick", true)
		local fire = part(parts, `Oven{tag}Fire`, { 3, 2, 0.1 }, { x, y + 2.5, 13.95 }, Glow, "Neon")
		fire.light = { color = Glow, range = 14, brightness = 1 }
		part(parts, `Oven{tag}Chimney`, { 2, 8, 2 }, { x, y + 11, 15.5 }, { 100, 50, 42 }, "Brick", true)
		part(parts, `Oven{tag}Stack`, { 2, 3, 2 }, { x, y + 17.1, 15.5 }, { 100, 50, 42 }, "Brick", true)
	end
	for i, top in shelves(parts, "BreadShelf", 0, { 70, 46, 34 }) do
		for j, x in { -2.5, 0, 2.5 } do
			part(parts, `Loaf{i}{j}`, { 1.6, 0.8, 1 }, { x, top + 0.4, 16 }, Bread, "SmoothPlastic")
		end
	end

	-- The ghost baker, floating behind the counter with a rolling pin.
	local gz = 1.6
	for i, x in { -1.1, 0, 1.1 } do
		part(parts, `BakerTail{i}`, { 0.8, 0.5, 1.6 }, { x, y + 1.65, gz }, Ghost, "SmoothPlastic")
	end
	part(parts, "Baker", { 3, 3.6, 2 }, { 0, y + 3.7, gz }, Ghost, "SmoothPlastic", true)
	part(parts, "BakerHead", { 2.4, 0.7, 1.6 }, { 0, y + 5.85, gz }, Ghost, "SmoothPlastic")
	part(parts, "BakerHatBand", { 2.6, 0.5, 1.8 }, { 0, y + 6.45, gz }, Cream, "Fabric")
	part(parts, "BakerHat", { 2.8, 0.8, 2 }, { 0, y + 7.1, gz }, { 250, 250, 250 }, "Fabric")
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(
			parts,
			`BakerEye{tag}`,
			{ 0.5, 0.8, 0.1 },
			{ side * 0.6, y + 4.7, gz - 1.05 },
			Ink,
			"SmoothPlastic"
		)
		part(
			parts,
			`BakerBlush{tag}`,
			{ 0.4, 0.2, 0.1 },
			{ side * 1.1, y + 4.15, gz - 1.05 },
			Pink,
			"SmoothPlastic"
		)
		part(parts, `BakerArm{tag}`, { 0.6, 0.6, 1.2 }, { side * 1.8, y + 3.8, 0.6 }, Ghost, "SmoothPlastic")
	end
	part(parts, "BakerMouth", { 0.8, 0.4, 0.1 }, { 0, y + 3.95, gz - 1.05 }, Ink, "SmoothPlastic")
	part(parts, "RollingPin", { 4.4, 0.5, 0.5 }, { 0, y + 3.75, -0.3 }, { 200, 160, 110 }, "Wood")

	-- Cakes on the counter.
	local top = y + 3.5
	part(parts, "CakeBottom", { 3, 1, 2.2 }, { -6.5, top + 0.5, -1 }, Cream, "SmoothPlastic")
	part(parts, "CakeMiddle", { 2.2, 0.8, 1.6 }, { -6.5, top + 1.4, -1 }, Pink, "SmoothPlastic")
	part(parts, "CakeTop", { 1.4, 0.6, 1 }, { -6.5, top + 2.1, -1 }, Chocolate, "SmoothPlastic")
	part(parts, "CakeCandle", { 0.25, 0.6, 0.25 }, { -6.5, top + 2.7, -1 }, Cream, "SmoothPlastic")
	part(parts, "CakeFlame", { 0.2, 0.3, 0.2 }, { -6.5, top + 3.15, -1 }, Glow, "Neon")
	for i, x in { 4.5, 6, 7.5 } do
		local frosting = ({ Pink, { 140, 220, 140 }, Cream })[i]
		part(parts, `Cupcake{i}`, { 0.9, 0.7, 0.9 }, { x, top + 0.35, -1.4 }, Wrapper, "SmoothPlastic")
		part(parts, `Cupcake{i}Frosting`, { 1, 0.5, 1 }, { x, top + 0.95, -1.4 }, frosting, "SmoothPlastic")
		part(
			parts,
			`Cupcake{i}Cherry`,
			{ 0.3, 0.3, 0.3 },
			{ x, top + 1.35, -1.4 },
			{ 200, 30, 40 },
			"SmoothPlastic"
		)
	end
	part(parts, "CookieJar", { 1.4, 1.8, 1.4 }, { 9, top + 0.9, -0.5 }, { 200, 220, 230 }, "Glass").transparency =
		0.4
	part(parts, "CookieJarLid", { 1.6, 0.3, 1.6 }, { 9, top + 1.95, -0.5 }, Pink, "SmoothPlastic")

	-- The giant cupcake on a cake stand on the roof, watching the hub over the false front.
	local roof = y + 15.6
	part(parts, "CakeStand", { 1.2, 3, 1.2 }, { 0, roof + 1.5, 9.5 }, Iron, "Metal", true)
	part(parts, "CakeStandPlate", { 7.4, 0.3, 7.4 }, { 0, roof + 3.15, 9.5 }, Cream, "SmoothPlastic", true)
	local base = roof + 3.3
	part(parts, "BigCupcake", { 6, 3.4, 6 }, { 0, base + 1.7, 9.5 }, Wrapper, "SmoothPlastic", true)
	for i, x in { -2, -1, 0, 1, 2 } do
		part(
			parts,
			`BigCupcakeRib{i}`,
			{ 0.4, 3.4, 0.1 },
			{ x, base + 1.7, 6.45 },
			{ 150, 95, 180 },
			"SmoothPlastic"
		)
	end
	part(parts, "BigFrostingLow", { 7, 1.6, 7 }, { 0, base + 4.2, 9.5 }, Pink, "SmoothPlastic", true)
	part(parts, "BigFrostingMid", { 5.4, 1.4, 5.4 }, { 0, base + 5.7, 9.5 }, Pink, "SmoothPlastic", true)
	part(parts, "BigFrostingTop", { 3.6, 1.2, 3.6 }, { 0, base + 7, 9.5 }, Pink, "SmoothPlastic", true)
	part(parts, "BigCherry", { 1.4, 1.4, 1.4 }, { 0, base + 8.3, 9.5 }, { 200, 30, 40 }, "SmoothPlastic")
	part(parts, "BigCherryStem", { 0.2, 1, 0.2 }, { 0, base + 9.5, 9.5 }, { 60, 90, 40 }, "Wood")
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(
			parts,
			`BigCupcakeEye{tag}`,
			{ 0.8, 0.6, 0.1 },
			{ side * 1.4, base + 4.3, 5.95 },
			{ 255, 220, 90 },
			"Neon"
		)
	end

	-- Flour sacks on the deck.
	part(parts, "FlourSack1", { 2, 2.4, 1.6 }, { -13.5, y + 1.2, -8 }, Cream, "Fabric", true)
	part(parts, "FlourSack2", { 2, 2.4, 1.6 }, { -13.5, y + 1.2, -6.2 }, Cream, "Fabric", true)
	part(parts, "FlourSack3", { 2, 2, 1.6 }, { -13.5, y + 3.4, -7.1 }, Cream, "Fabric")
	return parts
end

local Moss = { 52, 88, 62 }
local Canvas = { 196, 186, 150 }
local Teal = { 44, 62, 58 }
local Brass = { 170, 130, 60 }
local Ecto = { 120, 255, 150 }
local Robe = { 46, 40, 48 }

-- The Hunter's Workshop: a dark teal shop under a green striped awning, a big brass gear on
-- the roof, a wall of hunting gear (nets, lanterns, rope) behind a hooded hunter with
-- glowing eyes, a workbench, jars of glowing ecto, and an anvil and crates out on the deck.
function Landmarks.Workshop(): { Part }
	local parts: { Part } = {}
	local y = shop(parts, {
		title = "Hunter's Workshop",
		wall = Teal,
		trim = { 150, 118, 70 },
		roof = { 34, 40, 40 },
		deck = { 58, 48, 42 },
		sign = { 182, 146, 86 },
		awning = { Moss, Canvas },
	})

	-- The tool wall: a pegboard with a net, two lanterns and a coil of rope.
	part(parts, "Pegboard", { 17, 8, 0.2 }, { -4.5, y + 6, 16.9 }, { 110, 80, 55 }, "Wood")
	part(parts, "NetHandle", { 0.3, 4.4, 0.3 }, { -10, y + 4.6, 16.6 }, { 120, 90, 60 }, "Wood")
	part(parts, "NetHoop", { 2.4, 2.4, 0.3 }, { -10, y + 8, 16.6 }, Brass, "Metal")
	part(parts, "Net", { 2, 2, 0.1 }, { -10, y + 8, 16.4 }, Canvas, "Fabric").transparency = 0.3
	Kit.lantern(parts, "ToolLanternLeft", -6.5, y + 7, 16.65, { 0, -1 })
	Kit.lantern(parts, "ToolLanternRight", -3, y + 5, 16.65, { 0, -1 })
	part(parts, "Rope", { 1.8, 1.8, 0.6 }, { 1.5, y + 6.5, 16.5 }, { 150, 120, 80 }, "Fabric")

	-- A workbench with a vice and a hammer.
	local bx, bz = -9, 12
	part(parts, "Workbench", { 9, 0.5, 3.6 }, { bx, y + 3.25, bz }, { 90, 64, 44 }, "WoodPlanks", true)
	for i, leg in { { -4.1, -1.5 }, { 4.1, -1.5 }, { -4.1, 1.5 }, { 4.1, 1.5 } } do
		part(
			parts,
			`WorkbenchLeg{i}`,
			{ 0.5, 3, 0.5 },
			{ bx + leg[1], y + 1.5, bz + leg[2] },
			{ 70, 50, 36 },
			"Wood",
			true
		)
	end
	part(parts, "Vice", { 1, 1, 1.2 }, { bx + 3.5, y + 4, bz - 1 }, Iron, "Metal")
	part(parts, "HammerHandle", { 2, 0.25, 0.25 }, { bx - 1, y + 3.625, bz }, { 120, 90, 60 }, "Wood")
	part(parts, "HammerHead", { 0.4, 0.5, 0.9 }, { bx - 2.2, y + 3.75, bz }, Iron, "Metal")

	-- Shelves of glowing ecto jars.
	for i, top in shelves(parts, "JarShelf", 9.5, { 60, 44, 34 }) do
		for j, x in { 7.5, 9.5, 11.5 } do
			local jar = part(parts, `Jar{i}{j}`, { 0.8, 1.1, 0.8 }, { x, top + 0.55, 16 }, Ecto, "Neon")
			if i == 2 and j == 2 then
				jar.light = { color = Ecto, range = 12, brightness = 0.8 }
			end
			part(parts, `Jar{i}{j}Lid`, { 0.9, 0.2, 0.9 }, { x, top + 1.2, 16 }, Iron, "Metal")
		end
	end

	-- The hooded hunter behind the counter.
	local hz = 1.6
	part(parts, "Hunter", { 3, 4.6, 1.8 }, { 0, y + 2.3, hz }, Robe, "Fabric", true)
	part(parts, "HunterShoulders", { 3.4, 0.8, 2 }, { 0, y + 5, hz }, Robe, "Fabric")
	part(parts, "HunterHood", { 2.6, 2, 2.2 }, { 0, y + 6.4, hz }, { 56, 48, 58 }, "Fabric")
	part(parts, "HunterFace", { 1.8, 1.3, 0.1 }, { 0, y + 6.25, hz - 1.15 }, Ink, "SmoothPlastic")
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(parts, `HunterEye{tag}`, { 0.35, 0.25, 0.1 }, { side * 0.4, y + 6.4, hz - 1.25 }, Ecto, "Neon")
		part(parts, `HunterArm{tag}`, { 0.7, 0.7, 1.4 }, { side * 1.9, y + 3.85, 0 }, Robe, "Fabric")
	end

	-- For sale on the counter: a trap, charms on stands and a lantern.
	local top = y + 3.5
	part(parts, "TrapBase", { 2, 0.2, 2 }, { -6, top + 0.1, -1 }, Iron, "Metal")
	part(parts, "TrapJawFront", { 2, 0.6, 0.2 }, { -6, top + 0.5, -1.9 }, { 120, 120, 128 }, "Metal")
	part(parts, "TrapJawBack", { 2, 0.6, 0.2 }, { -6, top + 0.5, -0.1 }, { 120, 120, 128 }, "Metal")
	for i, x in { 4.5, 5.7, 6.9 } do
		part(parts, `CharmStand{i}`, { 0.2, 1.4, 0.2 }, { x, top + 0.7, -1.6 }, Brass, "Metal")
		part(parts, `Charm{i}`, { 0.6, 0.6, 0.15 }, { x, top + 1.7, -1.6 }, WatcherPurple, "Neon")
	end
	part(parts, "SaleLanternBase", { 0.9, 0.2, 0.9 }, { 9, top + 0.1, -1 }, Iron, "Metal")
	part(parts, "SaleLantern", { 0.8, 1.1, 0.8 }, { 9, top + 0.75, -1 }, Glow, "Neon")
	part(parts, "SaleLanternTop", { 1, 0.3, 1 }, { 9, top + 1.45, -1 }, Iron, "Metal")

	-- The big brass gear on the roof.
	local roof = y + 15.6
	local gy, gz = roof + 2.6 + 4.4, 9.5
	part(parts, "GearPost", { 1, 2, 1 }, { 0, roof + 1, gz }, Iron, "Metal", true)
	part(parts, "GearStand", { 3, 0.6, 1.2 }, { 0, roof + 2.3, gz }, Iron, "Metal", true)
	local gear = part(parts, "Gear", { 0.8, 6, 6 }, { 0, gy, gz }, Brass, "Metal", true)
	gear.shape = "Cylinder"
	gear.rot = { 0, 90, 0 }
	for i = 1, 8 do
		local deg = (i - 1) * 45 + 90
		local tooth = part(parts, `GearTooth{i}`, { 1.5, 1.2, 0.8 }, {
			3.65 * math.cos(math.rad(deg)),
			gy + 3.65 * math.sin(math.rad(deg)),
			gz,
		}, Brass, "Metal", true)
		tooth.rot = { 0, 0, deg }
	end
	part(parts, "GearHub", { 1.6, 1.6, 0.1 }, { 0, gy, gz - 0.45 }, Iron, "Metal")

	-- An anvil on a stump and a stack of crates out on the deck.
	part(parts, "Stump", { 2.4, 2, 2.4 }, { -13.5, y + 1, -7 }, { 80, 58, 42 }, "Wood", true)
	part(parts, "AnvilBase", { 1.4, 0.6, 1 }, { -13.5, y + 2.3, -7 }, Iron, "Metal", true)
	part(parts, "Anvil", { 2.8, 1, 1.4 }, { -13.5, y + 3.1, -7 }, Iron, "Metal", true)
	part(parts, "AnvilHorn", { 1, 0.6, 0.8 }, { -15.4, y + 3.2, -7 }, Iron, "Metal")
	part(parts, "Crate", { 3, 3, 3 }, { 13, y + 1.5, -8 }, { 110, 80, 50 }, "WoodPlanks", true)
	part(parts, "CrateSmall", { 2.4, 2.4, 2.4 }, { 13, y + 4.2, -8 }, { 96, 70, 44 }, "WoodPlanks", true).rot =
		{ 0, 15, 0 }
	return parts
end

local Oxblood = { 72, 34, 40 }
local Crimson = { 120, 30, 40 }
local Soot = { 30, 26, 30 }
local Coat = { 28, 24, 32 }
local Skull = { 226, 220, 200 }
local Gold = { 212, 170, 60 }
local GlassTint = { 180, 220, 230 }
local Wisps = { { 120, 255, 220 }, { 255, 120, 200 }, WatcherPurple, { 255, 200, 80 } }

-- An iron cage: a floor, a lid, a post at each corner and bars between them. `size` is its
-- width and depth, `height` its inside height; (x, y, z) is the middle of its floor.
local function cage(
	parts: { Part },
	name: string,
	x: number,
	y: number,
	z: number,
	size: number,
	height: number
)
	local half = size / 2
	part(parts, name .. "Floor", { size, 0.3, size }, { x, y + 0.15, z }, Iron, "Metal", true)
	part(parts, name .. "Lid", { size, 0.3, size }, { x, y + 0.45 + height, z }, Iron, "Metal", true)
	part(parts, name .. "Ring", { 0.8, 0.8, 0.2 }, { x, y + 1 + height, z }, Iron, "Metal")
	local n = 0
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			n += 1
			part(
				parts,
				`{name}Post{n}`,
				{ 0.25, height, 0.25 },
				{ x + cx * (half - 0.125), y + 0.3 + height / 2, z + cz * (half - 0.125) },
				Iron,
				"Metal",
				true
			)
		end
	end
	-- Thin bars on each face, between the posts (decor only; the posts hold the cage).
	for _, along in { -1 / 3, 1 / 3 } do
		for _, offset in { { along, -1 }, { along, 1 }, { -1, along }, { 1, along } } do
			n += 1
			part(
				parts,
				`{name}Bar{n}`,
				{ 0.12, height, 0.12 },
				{ x + offset[1] * (half - 0.125), y + 0.3 + height / 2, z + offset[2] * (half - 0.125) },
				Iron,
				"Metal"
			)
		end
	end
end

-- The Collector: an oxblood shop under a crimson and black awning, where a tall skeletal
-- dealer in a top hat buys your monsters. Brass scales and stacks of gold on the counter,
-- shelves of jars with trapped glowing wisps behind him, a caged monster out on the deck, and
-- a giant specimen jar with a wisp swirling inside on the roof.
function Landmarks.Collector(): { Part }
	local parts: { Part } = {}
	local y = shop(parts, {
		title = "The Collector",
		wall = Oxblood,
		trim = Bone,
		roof = { 40, 30, 34 },
		deck = { 54, 44, 40 },
		sign = Bone,
		awning = { Crimson, Soot },
	})

	-- Shelves of jars, each with a glowing wisp inside.
	for s, x in { -9.5, 9.5 } do
		for i, top in shelves(parts, `JarShelf{s}`, x, { 52, 36, 34 }) do
			for j, dx in { -2, 0, 2 } do
				local name = `Jar{s}{i}{j}`
				local glass = part(parts, name, { 1, 1.4, 1 }, { x + dx, top + 0.7, 16 }, GlassTint, "Glass")
				glass.transparency = 0.55
				local color = Wisps[(s + i + j) % #Wisps + 1]
				local wisp = part(
					parts,
					name .. "Wisp",
					{ 0.5, 0.5, 0.5 },
					{ x + dx, top + 0.6, 16 },
					color,
					"Neon"
				)
				wisp.shape = "Ball"
				if i == 2 and j == 2 then
					wisp.light = { color = color, range = 12, brightness = 0.8 }
				end
				part(parts, name .. "Lid", { 1.1, 0.2, 1.1 }, { x + dx, top + 1.5, 16 }, Iron, "Metal")
			end
		end
	end

	-- The Collector himself, low enough that his hat stays under the awning: a long coat, a grinning skull, a top hat and glowing eyes.
	local hz = 1.6
	part(parts, "CollectorCoat", { 2.6, 4.8, 1.6 }, { 0, y + 2.4, hz }, Coat, "Fabric", true)
	part(parts, "CollectorCollar", { 3, 0.6, 1.8 }, { 0, y + 4.6, hz }, Crimson, "Fabric")
	part(parts, "CollectorSkull", { 1.6, 1.8, 1.6 }, { 0, y + 5.8, hz }, Skull, "SmoothPlastic", true)
	part(parts, "CollectorJaw", { 1.2, 0.4, 0.1 }, { 0, y + 5.15, hz - 0.85 }, Ink, "SmoothPlastic")
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(
			parts,
			`CollectorEye{tag}`,
			{ 0.4, 0.4, 0.1 },
			{ side * 0.38, y + 6.0, hz - 0.85 },
			Wisps[1],
			"Neon"
		)
		part(parts, `CollectorArm{tag}`, { 0.6, 0.6, 1.4 }, { side * 1.6, y + 3.85, 0.1 }, Coat, "Fabric")
		part(
			parts,
			`CollectorHand{tag}`,
			{ 0.5, 0.3, 0.5 },
			{ side * 1.6, y + 3.65, -0.85 },
			Skull,
			"SmoothPlastic"
		)
	end
	part(parts, "HatBrim", { 2.4, 0.2, 2.4 }, { 0, y + 6.8, hz }, Soot, "Fabric")
	part(parts, "Hat", { 1.6, 1.3, 1.6 }, { 0, y + 7.55, hz }, Soot, "Fabric")
	part(parts, "HatBand", { 1.7, 0.3, 1.7 }, { 0, y + 7.1, hz }, Crimson, "Fabric")
	local eyeGlow = part(parts, "CollectorGlow", { 0.2, 0.2, 0.2 }, { 0, y + 6.0, hz }, Wisps[1], "Neon")
	eyeGlow.transparency = 1
	eyeGlow.light = { color = Wisps[1], range = 8, brightness = 0.7 }

	-- On the counter: brass scales and stacks of gold coins.
	local top = y + 3.5
	part(parts, "ScaleBase", { 1.6, 0.2, 1 }, { -5, top + 0.1, -1 }, Brass, "Metal")
	part(parts, "ScalePost", { 0.2, 2.4, 0.2 }, { -5, top + 1.4, -1 }, Brass, "Metal")
	part(parts, "ScaleBeam", { 3.4, 0.15, 0.15 }, { -5, top + 2.675, -1 }, Brass, "Metal")
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		local px = -5 + side * 1.6
		part(parts, `ScaleChain{tag}`, { 0.06, 1.2, 0.06 }, { px, top + 2.0, -1 }, Brass, "Metal")
		part(parts, `ScalePan{tag}`, { 1.2, 0.1, 1.2 }, { px, top + 1.35, -1 }, Brass, "Metal")
	end
	part(parts, "ScaleWisp", { 0.5, 0.5, 0.5 }, { -6.6, top + 1.65, -1.4 }, Wisps[2], "Neon").shape = "Ball"
	for i, stack in { { 4.5, 3 }, { 5.6, 5 }, { 6.7, 2 } } do
		for k = 1, stack[2] do
			local coin = part(
				parts,
				`Coins{i}_{k}`,
				{ 0.2, 0.9, 0.9 },
				{ stack[1], top + k * 0.2 - 0.1, -1.2 },
				Gold,
				"Metal"
			)
			coin.shape = "Cylinder"
			coin.rot = { 0, 0, 90 }
		end
	end

	-- A caged monster out on the deck, and empty cages waiting to be filled.
	cage(parts, "BigCage", 12.5, y, -8, 3.6, 3.6)
	local caught = part(parts, "CagedWisp", { 1.6, 1.6, 1.6 }, { 12.5, y + 2.1, -8 }, Wisps[3], "Neon")
	caught.shape = "Ball"
	caught.light = { color = Wisps[3], range = 12, brightness = 0.9 }
	cage(parts, "SmallCage", -13, y, -8, 2.4, 2)
	cage(parts, "TopCage", -13, y + 3.45, -8, 2.2, 1.6)

	-- The specimen jar on the roof: a glass drum on an iron stand with a wisp inside.
	local roof = y + 15.6
	local jz = 9.5
	part(parts, "JarStand", { 5, 0.8, 5 }, { 0, roof + 0.4, jz }, Iron, "Metal", true)
	local drum = part(parts, "SpecimenJar", { 6, 4.4, 4.4 }, { 0, roof + 3.8, jz }, GlassTint, "Glass")
	drum.shape = "Cylinder"
	drum.rot = { 0, 0, 90 }
	drum.transparency = 0.5
	local lid = part(parts, "SpecimenLid", { 0.6, 4.8, 4.8 }, { 0, roof + 7.1, jz }, Iron, "Metal", true)
	lid.shape = "Cylinder"
	lid.rot = { 0, 0, 90 }
	local spirit = part(parts, "SpecimenWisp", { 2.4, 2.4, 2.4 }, { 0, roof + 3.6, jz }, Wisps[1], "Neon")
	spirit.shape = "Ball"
	spirit.light = { color = Wisps[1], range = 22, brightness = 1 }
	return parts
end

-- The Trading Booth: a midnight-blue swap shop under a blue and white awning, run by a
-- hooded ghost broker with one teal and one pink eye (one for each side of a trade). A glass
-- bell jar at each end of the counter holds a wisp on offer, a ledger and quill sit between
-- them, shelves of wrapped parcels and crates line the back, two skeleton hands shake on the
-- roof, and a plank nailed across the counter says it opens soon.
local Midnight = { 40, 44, 72 }
local Ghostly = { 220, 222, 236 }
local SwapTeal = { 90, 240, 220 }
local SwapPink = { 255, 120, 200 }

function Landmarks.TradingBooth(): { Part }
	local parts: { Part } = {}
	local y = shop(parts, {
		title = "Trading Booth",
		wall = Midnight,
		trim = { 140, 140, 160 },
		roof = { 30, 32, 48 },
		deck = { 50, 48, 60 },
		sign = { 210, 205, 225 },
		awning = { { 50, 60, 120 }, Ghostly },
	})
	local top = y + 3.5 -- the counter top

	-- A bell jar at each end of the counter, each with a wisp up for trade.
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		local x = side * 7
		local base = part(parts, `JarBase{tag}`, { 0.3, 1.8, 1.8 }, { x, top + 0.15, -1 }, Brass, "Metal")
		base.shape = "Cylinder"
		base.rot = { 0, 0, 90 }
		local dome = part(parts, `JarDome{tag}`, { 1.4, 1.5, 1.5 }, { x, top + 1, -1 }, GlassTint, "Glass")
		dome.shape = "Cylinder"
		dome.rot = { 0, 0, 90 }
		dome.transparency = 0.55
		part(parts, `JarKnob{tag}`, { 0.4, 0.4, 0.4 }, { x, top + 1.9, -1 }, Brass, "Metal").shape = "Ball"
		local color = if side < 0 then SwapTeal else SwapPink
		local wisp = part(parts, `JarWisp{tag}`, { 0.7, 0.7, 0.7 }, { x, top + 1, -1 }, color, "Neon")
		wisp.shape = "Ball"
		wisp.light = { color = color, range = 10, brightness = 0.8 }
	end

	-- The ledger, an ink pot and a quill.
	part(parts, "Ledger", { 2.2, 0.25, 1.6 }, { 0, top + 0.125, -1.2 }, Crimson, "Fabric")
	part(parts, "LedgerPages", { 2, 0.12, 1.4 }, { 0, top + 0.31, -1.2 }, Cream, "SmoothPlastic")
	local pot = part(parts, "InkPot", { 0.45, 0.45, 0.45 }, { 1.8, top + 0.225, -0.6 }, Ink, "SmoothPlastic")
	pot.shape = "Cylinder"
	pot.rot = { 0, 0, 90 }
	part(parts, "Quill", { 0.1, 1.2, 0.25 }, { 1.95, top + 0.95, -0.6 }, Ghostly, "Fabric").rot =
		{ 0, 0, -20 }

	-- The broker: a hooded ghost behind the counter, low enough to stay under the awning.
	local hz = 1.6
	local robe = part(parts, "BrokerRobe", { 2.4, 4.8, 1.6 }, { 0, y + 2.4, hz }, Ghostly, "Fabric", true)
	robe.transparency = 0.25
	part(parts, "BrokerHood", { 2.2, 1.9, 1.9 }, { 0, y + 6.4, hz }, { 70, 50, 110 }, "Fabric", true)
	part(parts, "BrokerFace", { 1.5, 1.2, 0.1 }, { 0, y + 6.3, hz - 1 }, Ink, "SmoothPlastic")
	part(parts, "BrokerEyeLeft", { 0.35, 0.35, 0.05 }, { -0.35, y + 6.45, hz - 1.075 }, SwapTeal, "Neon")
	part(parts, "BrokerEyeRight", { 0.35, 0.35, 0.05 }, { 0.35, y + 6.45, hz - 1.075 }, SwapPink, "Neon")
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		local arm = part(
			parts,
			`BrokerArm{tag}`,
			{ 0.5, 0.5, 1.4 },
			{ side * 1.45, y + 4.6, 0.3 },
			Ghostly,
			"Fabric"
		)
		arm.transparency = 0.25
		part(
			parts,
			`BrokerHand{tag}`,
			{ 0.45, 0.3, 0.45 },
			{ side * 1.45, y + 4.5, -0.6 },
			Skull,
			"SmoothPlastic"
		)
	end
	local glow = part(parts, "BrokerGlow", { 0.2, 0.2, 0.2 }, { 0, y + 6.4, hz - 1.5 }, SwapTeal, "Neon")
	glow.transparency = 1
	glow.light = { color = { 200, 200, 255 }, range = 9, brightness = 0.6 }

	-- Shelves of wrapped parcels and crates behind him.
	for s, x in { -9.5, 9.5 } do
		for i, shelfTop in shelves(parts, `ParcelShelf{s}`, x, { 70, 60, 80 }) do
			local items = {
				{ -2.6, { 1.6, 1.2, 1.4 }, BoardWood, "Wood" },
				{ -0.4, { 1.8, 0.9, 1.2 }, Canvas, "Fabric" },
				{ 2.2, { 1.4, 1.6, 1.4 }, { 120, 90, 60 }, "Wood" },
			}
			for j, item in items do
				if (s + i + j) % 4 ~= 0 then -- a few gaps so the shelves don't look stamped
					local size = item[2]
					part(
						parts,
						`Parcel{s}{i}{j}`,
						size,
						{ x + item[1], shelfTop + size[2] / 2, 16 },
						item[3],
						item[4]
					)
					part(
						parts,
						`Parcel{s}{i}{j}String`,
						{ size[1] + 0.06, size[2] + 0.06, 0.12 },
						{ x + item[1], shelfTop + size[2] / 2 + 0.03, 16 },
						{ 150, 40, 50 },
						"Fabric"
					)
				end
			end
		end
	end

	-- Two skeleton hands shaking on the roof, over the sign.
	local roofTop = y + 18.9
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(parts, `ShakePost{tag}`, { 0.2, 0.5, 0.2 }, { side * 2, roofTop + 0.25, 3.5 }, Iron, "Metal")
		part(
			parts,
			`ShakeArm{tag}`,
			{ 2.6, 0.45, 0.45 },
			{ side * 1.8, roofTop + 0.725, 3.5 },
			Skull,
			"SmoothPlastic"
		)
		local cuff = if side < 0 then SwapTeal else SwapPink
		part(parts, `ShakeCuff{tag}`, { 0.8, 0.8, 0.8 }, { side * 3.5, roofTop + 0.725, 3.5 }, cuff, "Neon")
	end
	part(parts, "ShakeClasp", { 0.9, 0.75, 0.7 }, { 0, roofTop + 0.725, 3.5 }, Skull, "SmoothPlastic")

	-- Not open yet: a plank nailed across the counter.
	local plank = part(parts, "SoonPlank", { 14, 0.9, 0.2 }, { 0, y + 1.7, -2.35 }, BoardWood, "WoodPlanks")
	plank.rot = { 0, 0, -6 }
	plank.text = "Coming soon"
	return parts
end

-- Recipes by landmark name (Layout.Landmarks), and which of their parts is the model's
-- PrimaryPart: what Counter puts the prompt on.
Landmarks.ByName = {
	WatcherSquare = Landmarks.WatcherSquare,
	Bakery = Landmarks.Bakery,
	Workshop = Landmarks.Workshop,
	Collector = Landmarks.Collector,
	TradingBooth = Landmarks.TradingBooth,
} :: { [string]: () -> { Part } }

Landmarks.Anchor = {
	WatcherSquare = "Plaza",
	Bakery = Landmarks.CounterSpot,
	Workshop = Landmarks.CounterSpot,
	Collector = Landmarks.CounterSpot,
	TradingBooth = Landmarks.CounterSpot,
} :: { [string]: string }

return Landmarks
