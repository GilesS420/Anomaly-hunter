--!strict
-- The hub around the landmarks and plots: cobbled paths between them, lamp posts, an iron
-- fence round the edge of the oval with dead trees, graves and pumpkins inside it, and tall
-- cliffs outside it so the hub feels closed in. Data in the same format as Config/Rooms;
-- WorldBuilder builds it as Workspace.Hub.Map (and the preview page draws it the same way).
--
-- Hub-local studs: the ground's top is y = 0 and the middle of the hub is x = z = 0.

local Layout = require("./Layout")
local Rooms = require("./Rooms")

type Part = Rooms.Part

local Kit = Rooms.Kit
local part, group, dice = Kit.part, Kit.group, Kit.dice

local HubMap = {}

local Cobble = { 74, 70, 82 }
local CobbleDark = { 60, 57, 66 }
local Iron = { 34, 34, 38 }
local Stone = { 96, 92, 104 }
local MossStone = { 82, 90, 74 }
local Dirt = { 50, 42, 34 }
local DeadGrass = { 70, 72, 48 }
local Pumpkin = { 222, 110, 30 }
local PumpkinDark = { 186, 86, 22 }
local Stem = { 70, 90, 40 }
local Glow = { 255, 170, 60 }
local Rock = { 62, 60, 70 }

-- The oval: a long middle with a round end each side (as WorldBuilder builds the ground).
local Size = Layout.Hub.GroundSize
local Radius = math.min(Size.x, Size.z) / 2 -- of the round ends
local Straight = (math.max(Size.x, Size.z) - math.min(Size.x, Size.z)) / 2 -- x where the ends start

-- True if (x, z) is at least `inset` studs inside the oval's edge.
function HubMap.inside(x: number, z: number, inset: number): boolean
	local r = Radius - inset
	if math.abs(x) <= Straight then
		return math.abs(z) <= r
	end
	local dx = math.abs(x) - Straight
	return dx * dx + z * z <= r * r
end

-- Points every `step` studs round the oval, `inset` studs inside its edge, each with the
-- direction it runs (degrees, as a part's yaw).
local function ring(inset: number, step: number): { { x: number, z: number, yaw: number } }
	local r = Radius - inset
	local arc = math.pi * r
	local length = 4 * Straight + 2 * arc
	local count = math.floor(length / step + 0.5)
	local points = {}
	for i = 0, count - 1 do
		local d = i * length / count
		local x, z, yaw
		if d < 2 * Straight then -- along the -z side, west to east
			x, z, yaw = -Straight + d, -r, 0
		elseif d < 2 * Straight + arc then -- round the east end
			local a = -math.pi / 2 + (d - 2 * Straight) / r
			x, z = Straight + r * math.cos(a), r * math.sin(a)
			yaw = -math.deg(a) - 90
		elseif d < 4 * Straight + arc then -- along the +z side, east to west
			x, z, yaw = Straight - (d - 2 * Straight - arc), r, 180
		else -- round the west end
			local a = math.pi / 2 + (d - 4 * Straight - arc) / r
			x, z = -Straight + r * math.cos(a), r * math.sin(a)
			yaw = -math.deg(a) - 90
		end
		table.insert(points, { x = x, z = z, yaw = yaw })
	end
	return points
end

-- Where things stand (minX, maxX, minZ, maxZ): kept clear of the scatter round the edge.
local taken: { { number } } = {}
local function take(minX: number, maxX: number, minZ: number, maxZ: number)
	table.insert(taken, { minX, maxX, minZ, maxZ })
end
local function free(x: number, z: number, r: number): boolean
	for _, t in taken do
		if x + r > t[1] and x - r < t[2] and z + r > t[3] and z - r < t[4] then
			return false
		end
	end
	return true
end

-- A flat cobbled path from (x0, z0) to (x1, z1) (along x or z), `width` wide. `y` keeps
-- crossing paths from sharing a top (they'd flicker).
local function path(
	parts: { Part },
	name: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	width: number,
	y: number
)
	local alongX = z0 == z1
	local length = if alongX then math.abs(x1 - x0) else math.abs(z1 - z0)
	local size = if alongX then { length, y, width } else { width, y, length }
	part(parts, name, size, { (x0 + x1) / 2, y / 2, (z0 + z1) / 2 }, Cobble, "Cobblestone", true)
	local hx, hz = size[1] / 2 + 3, size[3] / 2 + 3
	take((x0 + x1) / 2 - hx, (x0 + x1) / 2 + hx, (z0 + z1) / 2 - hz, (z0 + z1) / 2 + hz)
end

-- The paths: two long avenues, a plaza at each end, and short paths to every plot, the
-- Collector, the Trading Booth and Watcher Square.
local Avenue = 50 -- the avenues run along z = -50 and z = 50
local GatePlaza = { x0 = 330, x1 = 372 }
local ShopPlaza = { x0 = -360, x1 = -330 } -- the shops stand just west of it
local function paths(parts: { Part })
	for i, z in { -Avenue, Avenue } do
		path(parts, `Avenue{i}`, ShopPlaza.x1, z, GatePlaza.x0, z, 12, 0.12)
	end
	path(parts, "GatePlaza", GatePlaza.x0, 0, GatePlaza.x1, 0, 226, 0.1)
	path(parts, "ShopPlaza", ShopPlaza.x0, 0, ShopPlaza.x1, 0, 140, 0.1)
	-- Each plot's front path, from the avenue to its front edge.
	local front = Layout.PlotSize.z / 2
	for _, plot in Layout.Plots do
		local edge = plot.z + plot.facing * front
		local start = math.sign(plot.z) * (Avenue + 8)
		path(parts, `{plot.name}Path`, plot.x, start, plot.x, edge, 10, 0.08)
	end
	-- Up to Watcher Square, and from it to the Collector and the Trading Booth.
	local square = 30
	path(parts, "SquarePathNorth", 0, -Avenue + 8, 0, -square, 10, 0.08)
	path(parts, "SquarePathSouth", 0, square, 0, Avenue - 8, 10, 0.08)
	-- The Growth Chamber and the Merger stand one further out, past the Collector and the
	-- Trading Booth: their paths start at the back of those.
	local after = { GrowthChamber = "Collector", Merger = "TradingBooth" }
	local spots: { [string]: Layout.Landmark } = {}
	for _, spot in Layout.Landmarks do
		spots[spot.name] = spot
	end
	for _, spot in Layout.Landmarks do
		local inner = spots[after[spot.name] or ""]
		if spot.name == "Collector" or spot.name == "TradingBooth" or inner then
			local side = math.sign(spot.x)
			local near = math.abs(spot.x) - spot.depth / 2 - 2
			local from = if inner then math.abs(inner.x) + inner.depth / 2 + 2 else square
			path(parts, `{spot.name}Path`, side * from, 0, side * near, 0, 10, 0.08)
		end
	end
	-- Worn edges along the avenues: a darker cobble strip each side.
	for i, z in { -Avenue - 7, -Avenue + 7, Avenue - 7, Avenue + 7 } do
		part(
			parts,
			`AvenueEdge{i}`,
			{ GatePlaza.x0 - ShopPlaza.x1, 0.1, 2 },
			{ (GatePlaza.x0 + ShopPlaza.x1) / 2, 0.05, z },
			CobbleDark,
			"Slate",
			true
		)
	end
end

-- Lamp posts down both avenues, on the side away from the middle, and round the plazas.
local function lamps(parts: { Part })
	local n = 0
	for x = ShopPlaza.x1 + 20, GatePlaza.x0 - 10, 40 do
		for _, z in { -Avenue - 9.5, Avenue + 9.5 } do
			-- Not in front of a plot's path.
			local clear = true
			for _, plot in Layout.Plots do
				clear = clear and math.abs(plot.x - x) > 9
			end
			if clear then
				n += 1
				Kit.lampPost(parts, `Lamp{n}`, x, z)
				take(x - 2, x + 2, z - 2, z + 2)
			end
		end
	end
	for _, spot in
		{
			{ GatePlaza.x0 - 2, -116 },
			{ GatePlaza.x0 - 2, 116 },
			{ ShopPlaza.x1 + 2, -73 },
			{ ShopPlaza.x1 + 2, 73 },
		}
	do
		n += 1
		Kit.lampPost(parts, `Lamp{n}`, spot[1], spot[2])
		take(spot[1] - 2, spot[1] + 2, spot[2] - 2, spot[2] + 2)
	end
end

-- An iron fence all the way round, just inside the edge: posts with spikes and two rails.
local FenceInset = 6
local function fence(parts: { Part })
	local posts = ring(FenceInset, 8)
	for i, p in posts do
		part(parts, `FencePost{i}`, { 0.6, 7, 0.6 }, { p.x, 3.5, p.z }, Iron, "Metal", true)
		part(parts, `FenceSpike{i}`, { 0.3, 0.8, 0.3 }, { p.x, 7.4, p.z }, Iron, "Metal")
		local q = posts[i % #posts + 1]
		local dx, dz = q.x - p.x, q.z - p.z
		local length = math.sqrt(dx * dx + dz * dz) - 0.7
		local yaw = math.deg(math.atan2(-dz, dx))
		for r, y in { 2, 6 } do
			local rail = part(
				parts,
				`FenceRail{i}_{r}`,
				{ length, 0.3, 0.3 },
				{ (p.x + q.x) / 2, y, (p.z + q.z) / 2 },
				Iron,
				"Metal",
				true
			)
			rail.rot = { 0, yaw, 0 }
		end
	end
end

-- Tall cliffs round the outside, from far below the floor, with steps and the odd peak.
local function cliffs(parts: { Part })
	local roll = dice(4242)
	local deep = 30
	for i, p in ring(-deep / 2 - 1, 20) do
		local d = math.floor((roll() - 0.5) * 18)
		local shade = { Rock[1] + d, Rock[2] + d, Rock[3] + d }
		local height = 34 + roll() * 30
		-- Every other one a step further out, so neighbours never share a face.
		local add = group(parts, { p.x, 0, p.z }, p.yaw, 0)
		local out = if i % 2 == 0 then -1.5 else 0
		add(`Cliff{i}`, { 22, height + 40, deep }, { 0, (height - 40) / 2, out }, shade, "Slate", true)
		local stepW, stepD, stepH = 10 + roll() * 6, 10 + roll() * 8, 8 + roll() * 16
		local sz = out + (roll() - 0.3) * (deep - stepD) / 2
		add(`Cliff{i}Step`, { stepW, stepH, stepD }, { 0, height + stepH / 2, sz }, shade, "Slate", true)
		if roll() < 0.4 then
			local peakH = 6 + roll() * 14
			add(
				`Cliff{i}Peak`,
				{ stepW * 0.45, peakH, stepD * 0.5 },
				{ 0, height + stepH + peakH / 2, sz },
				shade,
				"Slate",
				true
			)
		end
	end
end

-- Little things for the empty ground near the edge.
local function grave(
	parts: { Part },
	name: string,
	x: number,
	z: number,
	yaw: number,
	kind: number,
	lean: number
)
	local add = group(parts, { x, 0, z }, yaw, lean)
	add(name .. "Mound", { 2.6, 0.4, 4.4 }, { 0, 0.2, 2.6 }, Dirt, "Ground")
	if kind < 0.45 then
		add(name, { 2.4, 3.2, 0.6 }, { 0, 1.6, 0 }, Stone, "Slate", true)
		add(name .. "Top", { 1.6, 0.6, 0.6 }, { 0, 3.5, 0 }, Stone, "Slate", true)
	elseif kind < 0.75 then
		add(name, { 0.6, 4, 0.6 }, { 0, 2, 0 }, MossStone, "Slate", true)
		add(name .. "ArmLeft", { 0.8, 0.6, 0.6 }, { -0.7, 2.9, 0 }, MossStone, "Slate", true)
		add(name .. "ArmRight", { 0.8, 0.6, 0.6 }, { 0.7, 2.9, 0 }, MossStone, "Slate", true)
	else
		add(name, { 2, 2.2, 0.8 }, { 0, 1.1, 0 }, MossStone, "Slate", true)
	end
end

local function pumpkin(
	parts: { Part },
	name: string,
	x: number,
	z: number,
	s: number,
	yaw: number,
	lit: boolean
)
	local add = group(parts, { x, 0, z }, yaw, 0)
	add(name, { s * 0.6, s * 0.8, s }, { 0, s * 0.4, 0 }, Pumpkin, "SmoothPlastic", true)
	add(
		name .. "Left",
		{ s * 0.24, s * 0.68, s * 0.88 },
		{ -s * 0.42, s * 0.4, 0 },
		PumpkinDark,
		"SmoothPlastic",
		true
	)
	add(
		name .. "Right",
		{ s * 0.24, s * 0.68, s * 0.88 },
		{ s * 0.42, s * 0.4, 0 },
		PumpkinDark,
		"SmoothPlastic",
		true
	)
	add(name .. "Stem", { s * 0.14, s * 0.3, s * 0.14 }, { 0, s * 0.95, 0 }, Stem, "Wood")
	if lit then
		local face = add(
			name .. "Face",
			{ s * 0.4, s * 0.25, 0.1 },
			{ 0, s * 0.45, -s / 2 - 0.05 },
			Glow,
			"Neon"
		)
		face.light = { color = Glow, range = 8, brightness = 1 }
	end
end

local function rock(parts: { Part }, name: string, x: number, z: number, s: number, yaw: number)
	local add = group(parts, { x, 0, z }, yaw, 0)
	add(name, { s * 1.4, s * 0.8, s }, { 0, s * 0.4, 0 }, Rock, "Slate", true)
	add(name .. "Top", { s * 0.8, s * 0.5, s * 0.6 }, { s * 0.15, s * 1.05, 0 }, Stone, "Slate", true)
end

-- The scatter: dead trees, graves, pumpkins and rocks on a jittered grid over the ground
-- that's left in a band round the edge (behind the plots, the shops and the gates), and
-- patches of dead grass anywhere free.
local Band = 64 -- how far in from the edge the scatter reaches
local function scatter(parts: { Part })
	local roll = dice(777)
	local n = 0
	local step = 12
	for x = -Radius - Straight + 10, Radius + Straight - 10, step do
		for z = -Radius + 10, Radius - 10, step do
			local px, pz = x + (roll() - 0.5) * 6, z + (roll() - 0.5) * 6
			local what, keep = roll(), roll()
			local yaw = math.floor(roll() * 360)
			if
				keep < 0.3
				and HubMap.inside(px, pz, FenceInset + 6)
				and not HubMap.inside(px, pz, Band)
				and free(px, pz, 4)
			then
				n += 1
				if what < 0.22 then
					Kit.deadTree(parts, `Tree{n}`, px, pz, yaw)
				elseif what < 0.6 then
					grave(parts, `Grave{n}`, px, pz, yaw, roll(), (roll() - 0.5) * 12)
				elseif what < 0.85 then
					pumpkin(parts, `Pumpkin{n}`, px, pz, 1.6 + roll() * 1.4, yaw, roll() < 0.3)
				else
					rock(parts, `Rock{n}`, px, pz, 1.5 + roll() * 2, yaw)
				end
				take(px - 4, px + 4, pz - 4, pz + 4)
			elseif keep > 0.93 and HubMap.inside(px, pz, FenceInset + 8) and free(px, pz, 6) then
				-- A patch of dead grass.
				n += 1
				local w, d = 4 + roll() * 6, 4 + roll() * 6
				local add = group(parts, { px, 0, pz }, yaw, 0)
				add(`Grass{n}`, { w, 0.06, d }, { 0, 0.03, 0 }, DeadGrass, "Grass")
				local r = math.max(w, d) / 2 + 1
				take(px - r, px + r, pz - r, pz + r)
			end
		end
	end
end

function HubMap.parts(): { Part }
	local parts: { Part } = {}
	table.clear(taken)
	-- Keep the scatter off the plots, landmarks, gates and landing spot.
	local hx, hz = Layout.PlotSize.x / 2 + 4, Layout.PlotSize.z / 2 + 4
	for _, plot in Layout.Plots do
		take(plot.x - hx, plot.x + hx, plot.z - hz, plot.z + hz)
	end
	for _, spot in Layout.Landmarks do
		local w = math.max(spot.width, spot.depth) / 2 + 10
		take(spot.x - w, spot.x + w, spot.z - w, spot.z + w)
	end
	for _, gate in Layout.Gates do
		take(gate.x - 14, gate.x + 14, gate.z - 16, gate.z + 16)
	end
	local back = Layout.ReturnPoint
	take(back.x - 8, back.x + 8, back.z - 8, back.z + 8)
	-- The shops stand behind their plaza.
	take(-410, ShopPlaza.x0, -75, 75)

	paths(parts)
	lamps(parts)
	fence(parts)
	cliffs(parts)
	scatter(parts)
	return parts
end

return HubMap
