--!strict
-- What the zone portals and the zones themselves look like, as data in the same format as
-- Config/Rooms. WorldBuilder builds them (and the preview page draws them the same way).
--
-- Arch-local studs: the ground's top is y = 0, the portal's middle is x = z = 0 and -Z is
-- the side hunters walk in from. Zone-local studs: the zone floor's top is y = 0, its middle
-- is x = z = 0 and -Z is the arrival side (Layout.ZoneArrival, Layout.ZoneExit).

local Rooms = require("./Rooms")

type Part = Rooms.Part

local Kit = Rooms.Kit
local part, group, dice = Kit.part, Kit.group, Kit.dice

local Scenery = {}

local Iron = { 34, 34, 38 }
local Stone = { 96, 92, 104 }
local StoneDark = { 62, 60, 68 }
local MossStone = { 82, 90, 74 }
local Pumpkin = { 222, 110, 30 }
local PumpkinDark = { 186, 86, 22 }
local Stem = { 70, 90, 40 }
local Glow = { 255, 170, 60 }
local Bark = { 52, 42, 36 }
local Plank = { 96, 72, 50 }
local Dirt = { 62, 44, 30 }
local Black = { 12, 10, 12 }
local Bone = { 200, 190, 165 }

------------------------------------------------------------------------------------------
-- Portals
------------------------------------------------------------------------------------------

type ArchStyle = {
	pillar: { { number } }, -- pillar colours, stacked in bands when there's more than one
	material: string,
	trim: { number },
	glow: { number }, -- the portal's colour
	crown: (parts: { Part }, top: number) -> (), -- what sits on top of the arch
}

-- A carved jack-o'-lantern: three blocks wide, a glowing face on the front (-Z).
local function jackOLantern(
	parts: { Part },
	name: string,
	x: number,
	y: number,
	z: number,
	size: number,
	lit: boolean,
	noStem: boolean?
)
	local s = size
	part(parts, name, { s * 0.6, s * 0.8, s }, { x, y + s * 0.4, z }, Pumpkin, "SmoothPlastic", true)
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(
			parts,
			name .. "Side" .. tag,
			{ s * 0.24, s * 0.68, s * 0.88 },
			{ x + side * s * 0.42, y + s * 0.4, z },
			PumpkinDark,
			"SmoothPlastic",
			true
		)
		part(
			parts,
			name .. "Eye" .. tag,
			{ s * 0.16, s * 0.16, 0.1 },
			{ x + side * s * 0.15, y + s * 0.52, z - s / 2 - 0.05 },
			Glow,
			"Neon"
		)
	end
	local mouth = part(
		parts,
		name .. "Mouth",
		{ s * 0.4, s * 0.1, 0.1 },
		{ x, y + s * 0.24, z - s / 2 - 0.05 },
		Glow,
		"Neon"
	)
	if lit then
		mouth.light = { color = Glow, range = 12, brightness = 0.9 }
	end
	if not noStem then
		part(parts, name .. "Stem", { s * 0.12, s * 0.2, s * 0.12 }, { x, y + s * 0.9, z }, Stem, "Wood")
	end
end

local ArchStyles: { [string]: ArchStyle } = {
	PumpkinGraveyard = {
		pillar = { MossStone },
		material = "Slate",
		trim = StoneDark,
		glow = { 255, 140, 40 },
		crown = function(parts, top)
			jackOLantern(parts, "CrownPumpkin", 0, top, 0, 4.5, true)
			jackOLantern(parts, "CrownPumpkinLeft", -6, top, 0, 2.4, false)
			jackOLantern(parts, "CrownPumpkinRight", 6, top, 0, 2.4, false)
		end,
	},
	MurkyBayou = {
		pillar = { { 70, 58, 42 } },
		material = "Wood",
		trim = { 52, 70, 44 },
		glow = { 80, 220, 110 },
		crown = function(parts, top)
			-- A little lantern cage of fireflies between two crooked cypress knees.
			for _, side in { -1, 1 } do
				local tag = if side < 0 then "Left" else "Right"
				part(
					parts,
					"KneeRoot" .. tag,
					{ 1.8, 0.6, 1.8 },
					{ side * 6, top + 0.3, 0 },
					Bark,
					"Wood",
					true
				)
				Kit.stick(
					parts,
					"Knee" .. tag,
					{ side * 6, top + 0.6, 0 },
					if side < 0 then 0 else 180,
					70,
					3.5,
					1,
					Bark,
					"Wood"
				)
			end
			part(parts, "CageBase", { 2.4, 0.3, 2.4 }, { 0, top + 0.15, 0 }, Iron, "Metal", true)
			part(parts, "Cage", { 2, 2.6, 2 }, { 0, top + 1.6, 0 }, { 200, 220, 200 }, "Glass").transparency =
				0.6
			part(parts, "CageTop", { 2.4, 0.3, 2.4 }, { 0, top + 3.05, 0 }, Iron, "Metal", true)
			for i, at in { { -0.4, 1.0, 0.3 }, { 0.5, 1.7, -0.2 }, { -0.2, 2.3, -0.4 } } do
				local fly = part(
					parts,
					`Firefly{i}`,
					{ 0.3, 0.3, 0.3 },
					{ at[1], top + at[2], at[3] },
					{ 170, 255, 120 },
					"Neon"
				)
				if i == 1 then
					fly.light = { color = { 120, 255, 120 }, range = 12, brightness = 0.8 }
				end
			end
		end,
	},
	AbandonedCarnival = {
		pillar = { { 180, 40, 50 }, { 238, 222, 185 } },
		material = "WoodPlanks",
		trim = { 40, 145, 145 },
		glow = { 180, 90, 255 },
		crown = function(parts, top)
			-- A little striped tent roof with a flag.
			for i, w in { 9, 7, 5, 3 } do
				local color = if i % 2 == 1 then { 180, 40, 50 } else { 238, 222, 185 }
				part(parts, `Tent{i}`, { w, 1, w * 0.5 }, { 0, top + i - 0.5, 0 }, color, "Fabric", true)
			end
			part(parts, "FlagPole", { 0.3, 3, 0.3 }, { 0, top + 5.5, 0 }, Iron, "Metal")
			part(parts, "Flag", { 1.8, 1.1, 0.1 }, { 1.05, top + 6.4, 0 }, { 40, 145, 145 }, "Fabric")
		end,
	},
}

local LockedStyle: ArchStyle = {
	pillar = { StoneDark },
	material = "Slate",
	trim = Iron,
	glow = { 90, 90, 90 },
	crown = function() end,
}

Scenery.HubPortal = { width = 14, height = 16, thickness = 2 } -- matches Layout.GateSize
Scenery.ExitPortal = { width = 10, height = 12, thickness = 1 } -- the way home in each zone

-- The archway around a portal `width` x `height`. The portal itself is a separate part (it's
-- what hunters touch); this is only the stone around it and the swirl painted on its front.
-- A locked arch has no portal: boards, chains and a padlock fill it instead.
function Scenery.Arch(
	zoneId: string,
	width: number,
	height: number,
	thickness: number,
	locked: boolean
): { Part }
	local parts: { Part } = {}
	local style = if locked then LockedStyle else (ArchStyles[zoneId] or LockedStyle)
	local w, h = width, height
	local px = w / 2 + 1.5

	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(parts, `Plinth{tag}`, { 3, 1, 4.2 }, { side * px, 0.5, 0 }, style.trim, style.material, true)
		local bands = #style.pillar
		local band = (h - 1) / (bands == 1 and 1 or 6)
		for i = 1, (if bands == 1 then 1 else 6) do
			part(parts, `Pillar{tag}{i}`, { 3, band, 3 }, {
				side * px,
				1 + (i - 0.5) * band,
				0,
			}, style.pillar[(i - 1) % bands + 1], style.material, true)
		end
		Kit.lantern(parts, `Lantern{tag}`, side * px, h * 0.55, -1.65, { 0, -1 })
	end
	part(parts, "Lintel", { w + 6, 3, 3.4 }, { 0, h + 1.5, 0 }, style.pillar[1], style.material, true)
	part(parts, "LintelCap", { w + 7, 0.6, 4 }, { 0, h + 3.3, 0 }, style.trim, style.material, true)
	style.crown(parts, h + 3.6)

	local front = -thickness / 2 - 0.05
	if locked then
		for i, roll in { 12, -9, 6 } do
			local board = part(
				parts,
				`Board{i}`,
				{ w + 1, 1.2, 0.3 },
				{ 0, h * (0.25 + i * 0.17), -1.65 - (i - 1) * 0.3 },
				Plank,
				"WoodPlanks",
				true
			)
			board.rot = { 0, 0, roll }
		end
		for _, side in { -1, 1 } do
			local tag = if side < 0 then "Left" else "Right"
			local chain = part(
				parts,
				`Chain{tag}`,
				{ w * 0.75, 0.3, 0.3 },
				{ 0, h * 0.45, if side < 0 then -2.55 else -2.9 },
				Iron,
				"Metal"
			)
			chain.rot = { 0, 0, side * 35 }
		end
		part(parts, "Padlock", { 1.4, 1.6, 0.5 }, { 0, h * 0.45, -3.35 }, { 170, 130, 60 }, "Metal")
		local plaque = part(
			parts,
			"Plaque",
			{ 9, 1.6, 0.2 },
			{ 0, h + 1.5, -1.8 },
			{ 196, 170, 120 },
			"WoodPlanks"
		)
		plaque.text = "Coming soon"
		return parts
	end

	-- The swirl: two glowing frames and a bright eye in the middle of the portal's front.
	local swirl = { style.glow[1] * 0.6, style.glow[2] * 0.6, style.glow[3] * 0.6 }
	for i, inset in { 1.2, 3 } do
		local fw, fh = w - inset * 2, h - inset * 2
		local color = if i == 1 then swirl else style.glow
		part(parts, `Swirl{i}Top`, { fw, 0.4, 0.1 }, { 0, h - inset - 0.2, front }, color, "Neon")
		part(parts, `Swirl{i}Bottom`, { fw, 0.4, 0.1 }, { 0, inset + 0.2, front }, color, "Neon")
		part(parts, `Swirl{i}Left`, { 0.4, fh - 0.8, 0.1 }, { -fw / 2 + 0.2, h / 2, front }, color, "Neon")
		part(parts, `Swirl{i}Right`, { 0.4, fh - 0.8, 0.1 }, { fw / 2 - 0.2, h / 2, front }, color, "Neon")
	end
	part(parts, "SwirlEye", { 1.6, 1.6, 0.1 }, { 0, h / 2, front }, { 255, 255, 255 }, "Neon")
	return parts
end

------------------------------------------------------------------------------------------
-- Zones
------------------------------------------------------------------------------------------

-- A zone's look: its parts, and the open ground monsters roam over (zone-local rectangles,
-- clear of the props; SpawnService and the roam code use them as Workspace.Zones.<Id>.RoamArea).
-- `y` is the floor's height when it isn't the ground (the water's surface, say).
export type Rect = { x: number, z: number, width: number, depth: number, y: number? }
export type Zone = {
	parts: () -> { Part },
	roam: { Rect },
	-- With water: the island floor sits `bed` studs below the ground (the recipe builds the
	-- ground round the pools) and the `water` pools hold `waterDepth` studs of terrain water.
	bed: number?,
	water: { Rect }?,
	waterDepth: number?,
}

local Edge = 108 -- the fence line, just inside the zone's invisible walls

-- An iron fence all the way round: posts with spikes, and two rails along their inside.
local function perimeterFence(parts: { Part })
	local posts: { number } = {}
	for v = -Edge, Edge, 8 do
		table.insert(posts, v)
	end
	local i = 0
	local function post(x: number, z: number)
		i += 1
		part(parts, `FencePost{i}`, { 0.6, 7, 0.6 }, { x, 3.5, z }, Iron, "Metal", true)
		part(parts, `FenceSpike{i}`, { 0.3, 0.8, 0.3 }, { x, 7.4, z }, Iron, "Metal")
	end
	for _, v in posts do
		post(v, -Edge)
		post(v, Edge)
		if v ~= -Edge and v ~= Edge then
			post(-Edge, v)
			post(Edge, v)
		end
	end
	local inner = Edge - 0.45
	for r, y in { 2, 6 } do
		part(parts, `FenceRailFront{r}`, { (inner - 0.15) * 2, 0.3, 0.3 }, { 0, y, -inner }, Iron, "Metal")
		part(parts, `FenceRailBack{r}`, { (inner - 0.15) * 2, 0.3, 0.3 }, { 0, y, inner }, Iron, "Metal")
		part(parts, `FenceRailLeft{r}`, { 0.3, 0.3, (inner + 0.15) * 2 }, { -inner, y, 0 }, Iron, "Metal")
		part(parts, `FenceRailRight{r}`, { 0.3, 0.3, (inner + 0.15) * 2 }, { inner, y, 0 }, Iron, "Metal")
	end
end

-- A run of broken wall along x (or z when `alongZ`), as blocks of uneven height.
local function ruinedWall(
	parts: { Part },
	name: string,
	from: number,
	to: number,
	at: number,
	alongZ: boolean,
	heights: { number },
	color: { number }
)
	local step = (to - from) / #heights
	for i, height in heights do
		if height > 0 then
			local mid = from + (i - 0.5) * step
			local size = if alongZ then { 1.6, height, step } else { step, height, 1.6 }
			local pos = if alongZ then { at, height / 2, mid } else { mid, height / 2, at }
			part(parts, `{name}{i}`, size, pos, color, "Slate", true)
		end
	end
end

-- Tall, blocky cliffs all round the zone, just outside its invisible walls: they close the
-- zone in and hide the other floating zones from view. Stepped blocks that never overlap.
local Cliff = 110 -- where the cliffs start: the floor's edge, so no gap shows (the walls sit inside them)
local function cliffs(parts: { Part }, seed: number, rock: { number })
	local roll = dice(seed)
	local n = 0
	local function shade(): { number }
		local d = math.floor((roll() - 0.5) * 18)
		return { rock[1] + d, rock[2] + d, rock[3] + d }
	end
	-- One stretch of cliff: a base from far below the floor, a step on top, sometimes a peak.
	local function stretch(cx: number, cz: number, along: number, deep: number, alongX: boolean)
		n += 1
		local height = 32 + roll() * 22
		local function box(name: string, w: number, h: number, d: number, x: number, y: number, z: number)
			local size = if alongX then { w, h, d } else { d, h, w }
			local at = if alongX then { cx + x, y, cz + z } else { cx + z, y, cz + x }
			part(parts, name, size, at, shade(), "Slate", true)
		end
		box(`Cliff{n}`, along, height + 30, deep, 0, (height - 30) / 2, 0)
		local stepW, stepD = along * (0.5 + roll() * 0.3), deep * (0.4 + roll() * 0.3)
		local stepH = 8 + roll() * 16
		local sx = (roll() - 0.5) * (along - stepW)
		local sz = (roll() - 0.5) * (deep - stepD)
		box(`Cliff{n}Step`, stepW, stepH, stepD, sx, height + stepH / 2, sz)
		if roll() < 0.45 then
			local peakW, peakH = stepW * 0.45, 6 + roll() * 12
			box(`Cliff{n}Peak`, peakW, peakH, stepD * 0.5, sx, height + stepH + peakH / 2, sz)
		end
	end
	local deep, span, width = 26, 136, 16
	local mid = Cliff + deep / 2
	for x = -span + width / 2, span - width / 2, width do
		stretch(x, -mid, width, deep, true)
		stretch(x, mid, width, deep, true)
	end
	for z = -Cliff + width / 2, Cliff - width / 2, width do
		stretch(-mid, z, width, deep, false)
		stretch(mid, z, width, deep, false)
	end
end

-- A low iron fence along z from x = `from` to `to` (both posts), rails on its +z side.
local function fenceRun(parts: { Part }, name: string, from: number, to: number, z: number)
	local count = 0
	for x = from, to, (if to > from then 8 else -8) do
		count += 1
		part(parts, `{name}Post{count}`, { 0.6, 7, 0.6 }, { x, 3.5, z }, Iron, "Metal", true)
		part(parts, `{name}Spike{count}`, { 0.3, 0.8, 0.3 }, { x, 7.4, z }, Iron, "Metal")
	end
	local last = from + (count - 1) * (if to > from then 8 else -8)
	for r, y in { 2, 6 } do
		part(
			parts,
			`{name}Rail{r}`,
			{ math.abs(last - from) + 0.6, 0.3, 0.3 },
			{ (from + last) / 2, y, z + 0.45 },
			Iron,
			"Metal"
		)
	end
end

-- The dirt paths between the blocks of graves.
local GraveyardPaths = {
	{ x = 0, z = -51, width = 208, depth = 14 }, -- south path, just inside the gate
	{ x = 0, z = 96, width = 208, depth = 16 }, -- north path
	{ x = -97, z = 22, width = 14, depth = 132 }, -- west path
	{ x = 97, z = 22, width = 14, depth = 132 }, -- east path
	{ x = 0, z = 22, width = 16, depth = 132 }, -- the avenue up the middle
	{ x = -49, z = 21, width = 82, depth = 14 }, -- cross path, west half
	{ x = 49, z = 21, width = 82, depth = 14 }, -- cross path, east half
}

-- The Pumpkin Graveyard: a walled-in graveyard under tall cliffs. From the arrival pad a
-- cobbled path leads through an archway in an inner fence; inside, dirt paths run round the
-- edge, up the middle and across, between four blocks of crooked graves. Tucked among the
-- graves: a small ruined chapel, a mausoleum, a little pumpkin patch with a scarecrow, and the
-- groundskeeper's shed with an open grave. Monsters roam all the open ground,
-- between the graves too.
local function pumpkinGraveyard(): { Part }
	local parts: { Part } = {}
	local roll = dice(1031)
	perimeterFence(parts)
	cliffs(parts, 77, { 58, 54, 66 })

	-- The paths, in packed dirt.
	for i, r in GraveyardPaths do
		part(parts, `Path{i}`, { r.width, 0.1, r.depth }, { r.x, 0.05, r.z }, { 58, 46, 36 }, "Ground")
	end

	-- The way in: a cobbled path from the arrival pad and the exit to the archway in the
	-- inner fence.
	part(parts, "PathMain", { 8, 0.1, 30 }, { 0, 0.05, -73 }, StoneDark, "Cobblestone")
	part(parts, "PathCross", { 39, 0.1, 6 }, { 4.5, 0.05, -91 }, StoneDark, "Cobblestone")
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		local x = side * 8
		part(parts, `GatePillar{tag}`, { 2, 9, 2 }, { x, 4.5, -62 }, MossStone, "Slate", true)
		part(parts, `GateCap{tag}`, { 2.6, 0.5, 2.6 }, { x, 9.25, -62 }, StoneDark, "Slate", true)
		jackOLantern(parts, `GatePumpkin{tag}`, x, 9.5, -62, 2.2, side > 0)
		Kit.lampPost(parts, `PathLamp{tag}`, side * 6.5, -80)
		fenceRun(parts, `InnerFence{tag}`, side * 10, side * 106, -62)
	end
	part(parts, "GateBar", { 14, 0.6, 0.6 }, { 0, 8.7, -62 }, Iron, "Metal")
	local sign = part(
		parts,
		"GateSign",
		{ 10, 1.8, 0.3 },
		{ 0, 7.5, -62.15 },
		{ 196, 170, 120 },
		"WoodPlanks"
	)
	sign.text = "Pumpkin Graveyard"

	-- The small extras, each with the patch of ground it takes from the graves.
	local taken: { { number } } = {} -- minX, maxX, minZ, maxZ
	local function take(minX: number, maxX: number, minZ: number, maxZ: number)
		table.insert(taken, { minX, maxX, minZ, maxZ })
	end

	-- A small ruined chapel in the north-west corner.
	local cx = -76
	take(-87, -65, 63, 87)
	ruinedWall(parts, "ChapelFrontLeft", -84, -78.8, 66.8, false, { 7, 5 }, Stone)
	ruinedWall(parts, "ChapelFrontRight", -73.2, -68, 66.8, false, { 6, 8 }, Stone)
	ruinedWall(parts, "ChapelBack", -84, -68, 84, false, { 6, 10, 10, 7 }, Stone)
	ruinedWall(parts, "ChapelLeft", 67.6, 83.2, -83.2, true, { 7, 0, 6, 8 }, Stone)
	ruinedWall(parts, "ChapelRight", 67.6, 83.2, -68.8, true, { 5, 8, 0, 6 }, StoneDark)
	part(parts, "ChapelFloor", { 12.8, 0.2, 15.6 }, { cx, 0.1, 75.4 }, StoneDark, "Slate")
	part(parts, "ChapelCross", { 0.8, 3, 0.8 }, { cx - 2, 11.5, 84 }, Stone, "Slate")
	part(parts, "ChapelCrossArmLeft", { 0.7, 0.7, 0.8 }, { cx - 3.15, 12, 84 }, Stone, "Slate")
	part(parts, "ChapelCrossArmRight", { 0.7, 0.7, 0.8 }, { cx - 0.85, 12, 84 }, Stone, "Slate")
	part(parts, "Altar", { 4, 2.4, 1.6 }, { cx, 1.4, 81.6 }, StoneDark, "Slate", true)
	Kit.candles(parts, "AltarCandles", cx - 1, 2.6, 81.6, true)
	Kit.candles(parts, "AltarCandlesRight", cx + 1, 2.6, 81.6, false)
	local add = group(parts, { cx, 0.2, 74 }, 8, 0)
	add("PewSeat", { 6, 0.4, 1.6 }, { 0, 1.4, 0 }, Plank, "WoodPlanks", true)
	add("PewBack", { 6, 1.6, 0.3 }, { 0, 2.4, 0.65 }, Plank, "WoodPlanks", true)
	add("PewLegLeft", { 0.4, 1.2, 1.4 }, { -2.6, 0.6, 0 }, Plank, "Wood", true)
	add("PewLegRight", { 0.4, 1.2, 1.4 }, { 2.6, 0.6, 0 }, Plank, "Wood", true)

	-- A stone mausoleum in the south-west corner.
	local mx, mz = -78, -34
	take(-86, -70, -42, -27)
	part(parts, "Mausoleum", { 10, 7, 8 }, { mx, 3.5, mz }, Stone, "Slate", true)
	part(parts, "MausoleumRoof", { 11, 0.6, 9 }, { mx, 7.3, mz }, StoneDark, "Slate", true)
	part(parts, "MausoleumGable", { 8, 1, 6 }, { mx, 8.1, mz }, Stone, "Slate", true)
	part(parts, "MausoleumGableTop", { 5, 1, 4 }, { mx, 9.1, mz }, Stone, "Slate", true)
	part(parts, "MausoleumDoor", { 3, 4.2, 0.1 }, { mx, 2.5, mz - 4.05 }, Black, "SmoothPlastic")
	part(parts, "MausoleumStep", { 6, 0.4, 1.2 }, { mx, 0.2, mz - 4.6 }, StoneDark, "Slate", true)
	local plate = part(parts, "MausoleumPlate", { 4, 0.8, 0.1 }, { mx, 5.6, mz - 4.05 }, Bone, "Slate")
	plate.text = "R.I.P."
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(
			parts,
			`MausoleumColumn{tag}`,
			{ 0.8, 7, 0.8 },
			{ mx + side * 3.5, 3.5, mz - 4.4 },
			Bone,
			"Marble",
			true
		)
	end

	-- A little pumpkin patch with a scarecrow in the north-east corner.
	take(64, 88, 58, 86)
	part(parts, "PatchSoil", { 20, 0.2, 16 }, { 76, 0.1, 74 }, Dirt, "Ground")
	local p = 0
	for _, x in { 70, 76, 82 } do
		part(parts, `PatchRow{x}`, { 1.2, 0.4, 14 }, { x, 0.4, 74 }, { 50, 36, 24 }, "Ground")
		for _, z in { 70, 78 } do
			p += 1
			local size = 1.8 + roll() * 1.4
			if p % 3 == 1 then
				jackOLantern(parts, `Pumpkin{p}`, x, 0.6, z, size, p == 1)
			else
				part(
					parts,
					`Pumpkin{p}`,
					{ size, size * 0.75, size },
					{ x, 0.6 + size * 0.375, z },
					Pumpkin,
					"SmoothPlastic",
					true
				)
				part(parts, `Pumpkin{p}Stem`, { 0.3, 0.4, 0.3 }, { x, 0.8 + size * 0.75, z }, Stem, "Wood")
			end
		end
	end
	local sx, sz = 76, 63
	part(parts, "ScarecrowPole", { 0.5, 3.5, 0.5 }, { sx, 1.75, sz }, Bark, "Wood", true)
	part(parts, "Scarecrow", { 2.4, 3, 1.2 }, { sx, 5, sz }, { 120, 96, 60 }, "Fabric", true)
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(
			parts,
			`ScarecrowArm{tag}`,
			{ 2.2, 0.8, 0.8 },
			{ sx + side * 2.3, 5.9, sz },
			{ 90, 60, 80 },
			"Fabric"
		)
		part(
			parts,
			`ScarecrowStraw{tag}`,
			{ 0.6, 0.6, 0.6 },
			{ sx + side * 3.7, 5.9, sz },
			{ 210, 180, 90 },
			"Fabric"
		)
	end
	jackOLantern(parts, "ScarecrowHead", sx, 6.5, sz, 2.2, true, true)
	part(parts, "ScarecrowHatBrim", { 3, 0.2, 3 }, { sx, 8.36, sz }, Black, "Fabric")
	part(parts, "ScarecrowHat", { 1.6, 1.4, 1.6 }, { sx, 9.16, sz }, Black, "Fabric")

	-- The groundskeeper's shed and an open grave in the south-east corner.
	take(56, 88, -42, -22)
	local hx, hz = 78, -30
	part(parts, "ShedBack", { 12, 8, 0.6 }, { hx, 4, hz + 4.7 }, Plank, "WoodPlanks", true)
	part(parts, "ShedLeft", { 0.6, 8, 8.8 }, { hx - 5.7, 4, hz }, Plank, "WoodPlanks", true)
	part(parts, "ShedRight", { 0.6, 8, 8.8 }, { hx + 5.7, 4, hz }, Plank, "WoodPlanks", true)
	part(parts, "ShedFrontLeft", { 3.6, 8, 0.6 }, { hx - 4.2, 4, hz - 4.7 }, Plank, "WoodPlanks", true)
	part(parts, "ShedFrontRight", { 4.4, 8, 0.6 }, { hx + 3.8, 4, hz - 4.7 }, Plank, "WoodPlanks", true)
	part(parts, "ShedOverDoor", { 4, 1.6, 0.6 }, { hx - 0.4, 7.2, hz - 4.7 }, Plank, "WoodPlanks", true)
	local roof = part(parts, "ShedRoof", { 13.4, 0.5, 11.6 }, { hx, 8.95, hz }, Bark, "WoodPlanks", true)
	roof.rot = { -8, 0, 0 }
	local window = part(parts, "ShedWindow", { 1.8, 1.6, 0.1 }, { hx + 3.8, 5, hz - 5.05 }, Glow, "Neon")
	window.light = { color = Glow, range = 14, brightness = 0.8 }
	part(parts, "ShedDoorDark", { 4, 6.4, 0.1 }, { hx - 0.4, 3.2, hz - 4.45 }, Black, "SmoothPlastic")
	local shovel = part(parts, "Shovel", { 0.25, 4.4, 0.25 }, { hx + 7, 2.15, hz + 2 }, Bark, "Wood")
	shovel.rot = { 0, 0, 12 }
	local gx, gz = 64, -31
	part(parts, "GravePit", { 3, 0.06, 6 }, { gx, 0.03, gz }, Black, "SmoothPlastic")
	part(parts, "GraveRimLeft", { 0.6, 0.4, 6 }, { gx - 1.8, 0.2, gz }, Dirt, "Ground")
	part(parts, "GraveRimRight", { 0.6, 0.4, 6 }, { gx + 1.8, 0.2, gz }, Dirt, "Ground")
	part(parts, "GraveDirt", { 3, 1.4, 4.4 }, { gx + 4, 0.7, gz }, Dirt, "Ground", true)
	part(parts, "GraveStone", { 2.6, 3.4, 0.6 }, { gx, 1.7, gz + 3.6 }, Stone, "Slate", true)
	local lid = part(parts, "CoffinLid", { 2.4, 0.3, 5.6 }, { gx - 4.4, 0.15, gz }, Plank, "WoodPlanks")
	lid.rot = { 0, 20, 0 }

	-- Dead trees and lamp posts beside the avenue.
	for i, spot in { { -15, 5, 30 }, { 15, 37, 200 }, { -45, 80, 120 }, { 45, -36, 300 } } do
		take(spot[1] - 4, spot[1] + 4, spot[2] - 4, spot[2] + 4)
		Kit.deadTree(parts, `Tree{i}`, spot[1], spot[2], spot[3])
	end
	for i, spot in { { -10.5, -38 }, { 10.5, -38 }, { -10.5, 60 }, { 10.5, 60 } } do
		take(spot[1] - 2, spot[1] + 2, spot[2] - 2, spot[2] + 2)
		Kit.lampPost(parts, `Lamp{i}`, spot[1], spot[2])
	end

	-- Graves fill the rest of the four blocks, in crooked rows.
	local function free(x: number, z: number): boolean
		for _, t in taken do
			if x > t[1] - 1.5 and x < t[2] + 1.5 and z > t[3] - 1 and z < t[4] + 4 then
				return false
			end
		end
		return true
	end
	local n, pumpkins = 0, 0
	for _, rows in { { -38, 2 }, { 34, 74 } } do
		for z = rows[1], rows[2], 8 do
			for _, sideX in { -1, 1 } do
				for col = 0, 10 do
					local x = sideX * (14 + col * 7) + (roll() - 0.5) * 1.6
					if free(x, z) then
						n += 1
						local kind = math.floor(roll() * 3)
						local yaw = (roll() - 0.5) * 20
						local tilt = (roll() - 0.5) * 16
						local grave = group(parts, { x, 0, z }, yaw, tilt)
						local color = if roll() < 0.3 then MossStone else Stone
						if kind == 0 then
							grave(`Tomb{n}`, { 2.4, 3.2, 0.6 }, { 0, 1.6, 0 }, color, "Slate", true)
							grave(`Tomb{n}Top`, { 1.6, 0.5, 0.6 }, { 0, 3.45, 0 }, color, "Slate")
						elseif kind == 1 then
							grave(`Tomb{n}`, { 0.7, 4, 0.6 }, { 0, 2, 0 }, color, "Slate", true)
							grave(`Tomb{n}ArmLeft`, { 0.95, 0.7, 0.6 }, { -0.825, 2.9, 0 }, color, "Slate")
							grave(`Tomb{n}ArmRight`, { 0.95, 0.7, 0.6 }, { 0.825, 2.9, 0 }, color, "Slate")
						else
							grave(`Tomb{n}`, { 2, 2.2, 0.8 }, { 0, 1.1, 0 }, color, "Slate", true)
						end
						grave(`Tomb{n}Mound`, { 2.2, 0.3, 3.4 }, { 0, 0.15, 2.2 }, Dirt, "Ground")
					end
					-- Now and then a pumpkin in the gap behind the grave, a few of them lit.
					local px, pz = sideX * (17.5 + col * 7), z + 5.8
					if col < 10 and roll() < 0.22 and free(px, pz) then
						pumpkins += 1
						local size = 1.2 + roll() * 0.6
						jackOLantern(parts, `GravePumpkin{pumpkins}`, px, 0, pz, size, roll() < 0.3)
					end
				end
			end
		end
	end
	return parts
end

local Mud = { 54, 46, 32 }
local Cypress = { 44, 64, 40 }
local CypressDark = { 34, 50, 32 }
local Moss = { 84, 96, 70 }
local Rotten = { 74, 60, 44 }
local Firefly = { 200, 255, 120 }

-- The bayou's water: shallow, real (terrain) water in pits between the banks and boardwalks.
-- The pit floor is `BayouBed` studs below the ground and the water `BayouWater` deep.
local BayouBed, BayouWater = 4, 2
local Bed, Surface = -BayouBed, BayouWater - BayouBed
-- Monsters roam over the water too, gliding just above its surface.
local BayouPools: { Rect } = {
	{ x = -47.5, z = -14, width = 85, depth = 60, y = Surface },
	{ x = 47.5, z = -14, width = 85, depth = 60, y = Surface },
	{ x = -47.5, z = 57, width = 85, depth = 62, y = Surface },
	{ x = 47.5, z = 57, width = 85, depth = 62, y = Surface },
}

-- A bald cypress standing in the water: a flared foot, a tall trunk, a flat crown with grey
-- moss hanging from it, and knees poking up round its foot. The crown and moss are overhead,
-- so walk-through.
local function cypress(parts: { Part }, name: string, x: number, z: number, height: number)
	part(parts, name .. "Foot", { 3.2, 2, 3.2 }, { x, Bed + 1, z }, Bark, "Wood", true)
	part(parts, name .. "Flare", { 2.4, 2, 2.4 }, { x, Bed + 3, z }, Bark, "Wood", true)
	part(parts, name .. "Trunk", { 1.5, height, 1.5 }, { x, height / 2, z }, Bark, "Wood", true)
	part(parts, name .. "Crown", { 9, 1.4, 8 }, { x, height + 0.7, z }, Cypress, "Grass")
	part(parts, name .. "CrownTop", { 6, 1.2, 5 }, { x + 0.8, height + 2, z - 0.6 }, CypressDark, "Grass")
	for i, spot in { { -3.6, -2, 4 }, { 3.2, 2.4, 5 }, { 1, -3.3, 3 }, { -2.2, 3.1, 4.5 } } do
		local length = spot[3]
		part(
			parts,
			`{name}Moss{i}`,
			{ 0.4, length, 0.2 },
			{ x + spot[1], height - length / 2, z + spot[2] },
			Moss,
			"Fabric"
		)
	end
	for i, spot in { { 2.4, 0.8 }, { -1.2, 2.3 } } do
		part(parts, `{name}Knee{i}`, { 0.6, 3, 0.6 }, { x + spot[1], Bed + 1.5, z + spot[2] }, Bark, "Wood")
	end
end

-- The Murky Bayou: a swamp under tall mossy cliffs. From the arrival pad you cross a muddy
-- landing to a dock gate; past it, mud banks run round the edge and boardwalks run up the
-- middle and across, over four pools of shallow murky water full of cypress trees, reeds and
-- lily pads. Out in the water: a shack on stilts, a broken clock tower sinking into the
-- swamp with its fallen stones around it, a rowboat and fireflies. Monsters roam all the open
-- ground, banks, boardwalks and water alike.
local function murkyBayou(): { Part }
	local parts: { Part } = {}
	local roll = dice(2069)
	cliffs(parts, 91, { 48, 58, 46 })

	-- Mud round the edge down to the pit floor, boardwalks over the pools.
	part(parts, "MudSouth", { 220, BayouBed, 66 }, { 0, Bed / 2, -77 }, Mud, "Ground", true)
	part(parts, "MudNorth", { 220, BayouBed, 22 }, { 0, Bed / 2, 99 }, Mud, "Ground", true)
	part(parts, "MudWest", { 20, BayouBed, 132 }, { -100, Bed / 2, 22 }, Mud, "Ground", true)
	part(parts, "MudEast", { 20, BayouBed, 132 }, { 100, Bed / 2, 22 }, Mud, "Ground", true)
	part(parts, "BoardwalkMiddle", { 10, 0.3, 132 }, { 0, -0.15, 22 }, Plank, "WoodPlanks", true)
	part(parts, "BoardwalkWest", { 85, 0.3, 10 }, { -47.5, -0.15, 21 }, Plank, "WoodPlanks", true)
	part(parts, "BoardwalkEast", { 85, 0.3, 10 }, { 47.5, -0.15, 21 }, Plank, "WoodPlanks", true)
	local post = 0
	local function boardwalkPost(x: number, z: number)
		post += 1
		part(parts, `BoardwalkPost{post}`, { 0.6, 4.8, 0.6 }, { x, Bed + 2.4, z }, Rotten, "Wood", true)
	end
	for z = -38, 82, 12 do
		if z < 14 or z > 28 then
			boardwalkPost(-5.4, z)
			boardwalkPost(5.4, z)
		end
	end
	for x = 12, 84, 12 do
		for _, side in { -1, 1 } do
			boardwalkPost(side * x, 15.6)
			boardwalkPost(side * x, 26.4)
		end
	end

	-- The way in: a dock gate with glowing firefly jars, and a rotten fence either side.
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		local x = side * 7
		part(parts, `GatePost{tag}`, { 1.2, 9, 1.2 }, { x, 4.5, -62 }, Rotten, "Wood", true)
		local jar = part(parts, `GateJar{tag}`, { 0.8, 0.8, 0.8 }, { x, 9.4, -62 }, Firefly, "Neon")
		jar.light = { color = Firefly, range = 14, brightness = 1 }
		Kit.lampPost(parts, `PathLamp{tag}`, side * 6.5, -80)
		local count = 0
		for fx = side * 10, side * 106, side * 8 do
			count += 1
			part(parts, `Fence{tag}Post{count}`, { 0.6, 4, 0.6 }, { fx, 2, -62 }, Rotten, "Wood", true)
		end
		local last = side * (10 + (count - 1) * 8)
		for r, y in { 1.5, 3.2 } do
			part(
				parts,
				`Fence{tag}Rail{r}`,
				{ math.abs(last - side * 10) + 0.6, 0.3, 0.3 },
				{ (side * 10 + last) / 2, y, -61.55 },
				Rotten,
				"Wood"
			)
		end
	end
	part(parts, "GateBar", { 12.8, 0.8, 0.6 }, { 0, 8.4, -62 }, Rotten, "Wood")
	local sign = part(parts, "GateSign", { 9, 1.8, 0.3 }, { 0, 6.9, -62.75 }, { 150, 130, 90 }, "WoodPlanks")
	sign.text = "Murky Bayou"
	part(parts, "CrateA", { 2.4, 2.4, 2.4 }, { -52, 1.2, -84 }, Plank, "WoodPlanks", true)
	part(parts, "CrateB", { 2, 2, 2 }, { -52.3, 3.4, -84.2 }, Rotten, "WoodPlanks", true)
	part(parts, "Barrel", { 1.8, 2.6, 1.8 }, { -48.6, 1.3, -85 }, Rotten, "Wood", true)

	-- What's out in the water takes its patch from the trees and reeds; `solid` patches also
	-- keep the fireflies away.
	local taken: { { number } } = {} -- minX, maxX, minZ, maxZ
	local solids: { { number } } = {}
	local function take(minX: number, maxX: number, minZ: number, maxZ: number, solid: boolean)
		table.insert(taken, { minX, maxX, minZ, maxZ })
		if solid then
			table.insert(solids, { minX, maxX, minZ, maxZ })
		end
	end
	local function clear(list: { { number } }, x: number, z: number, margin: number): boolean
		for _, t in list do
			if x > t[1] - margin and x < t[2] + margin and z > t[3] - margin and z < t[4] + margin then
				return false
			end
		end
		return true
	end

	-- A fisherman's shack on stilts in the north-east water, a light still on.
	local hx, hz = 62, 58
	take(hx - 9, hx + 9, hz - 9, hz + 8, true)
	take(hx - 16, hx + 16, hz - 16, hz + 14, false)
	part(parts, "ShackDeck", { 14, 0.6, 12 }, { hx, 5.3, hz }, Plank, "WoodPlanks", true)
	for i, spot in { { -6.6, -5.6 }, { 6.6, -5.6 }, { -6.6, 5.6 }, { 6.6, 5.6 } } do
		part(
			parts,
			`ShackStilt{i}`,
			{ 0.8, 9, 0.8 },
			{ hx + spot[1], 0.5, hz + spot[2] },
			Rotten,
			"Wood",
			true
		)
	end
	part(parts, "ShackBack", { 10, 7, 0.5 }, { hx, 9.1, hz + 4.75 }, Rotten, "WoodPlanks", true)
	part(parts, "ShackLeft", { 0.5, 7, 7 }, { hx - 4.75, 9.1, hz + 1 }, Rotten, "WoodPlanks", true)
	part(parts, "ShackRight", { 0.5, 7, 7 }, { hx + 4.75, 9.1, hz + 1 }, Rotten, "WoodPlanks", true)
	part(parts, "ShackFrontLeft", { 3.5, 7, 0.5 }, { hx - 3.25, 9.1, hz - 2.75 }, Rotten, "WoodPlanks", true)
	part(parts, "ShackFrontRight", { 3.5, 7, 0.5 }, { hx + 3.25, 9.1, hz - 2.75 }, Rotten, "WoodPlanks", true)
	part(parts, "ShackOverDoor", { 3, 2, 0.5 }, { hx, 11.6, hz - 2.75 }, Rotten, "WoodPlanks", true)
	part(parts, "ShackDoorDark", { 3, 5, 0.1 }, { hx, 8.1, hz - 2.75 }, Black, "SmoothPlastic")
	part(parts, "ShackRoof", { 12, 0.5, 10 }, { hx, 12.85, hz + 1 }, { 110, 70, 50 }, "Metal", true)
	part(parts, "ShackRoofTop", { 9, 0.6, 7 }, { hx, 13.4, hz + 1 }, { 96, 60, 44 }, "Metal", true)
	local window = part(parts, "ShackWindow", { 1.6, 1.4, 0.1 }, { hx + 3.25, 9.6, hz - 3.05 }, Glow, "Neon")
	window.light = { color = Glow, range = 16, brightness = 0.9 }
	for _, side in { -1, 1 } do
		part(
			parts,
			`ShackLadder{side}`,
			{ 0.3, 7.4, 0.3 },
			{ hx + side, 1.3, hz - 6.4 },
			Rotten,
			"Wood",
			true
		)
	end
	for r = 0, 5 do
		part(parts, `ShackRung{r}`, { 1.7, 0.2, 0.2 }, { hx, r - 1.1, hz - 6.4 }, Rotten, "Wood")
	end

	-- A clock tower sinking into the north-west water: leaning, a hole broken in its front, the
	-- clock stopped, half its belfry roof gone, and the fallen stones lying in the water.
	local tx, tz = -58, 58
	take(tx - 10, tx + 10, tz - 18, tz + 10, true)
	take(tx - 16, tx + 16, tz - 22, tz + 16, false)
	local tower = group(parts, { tx, Bed, tz }, 20, 10)
	local Clock = { 196, 186, 150 }
	-- The shaft: four walls 18 studs tall, the front one broken open in the middle.
	tower("TowerBack", { 7, 18, 1 }, { 0, 9, 3 }, MossStone, "Slate", true)
	tower("TowerLeft", { 1, 18, 5 }, { -3, 9, 0 }, MossStone, "Slate", true)
	tower("TowerRight", { 1, 18, 5 }, { 3, 9, 0 }, MossStone, "Slate", true)
	tower("TowerFrontLow", { 7, 8, 1 }, { 0, 4, -3 }, MossStone, "Slate", true)
	tower("TowerJambLeft", { 2, 5, 1 }, { -2.5, 10.5, -3 }, MossStone, "Slate", true)
	tower("TowerJambRight", { 2, 5, 1 }, { 2.5, 10.5, -3 }, MossStone, "Slate", true)
	tower("TowerFrontHigh", { 7, 5, 1 }, { 0, 15.5, -3 }, MossStone, "Slate", true)
	tower("TowerChipA", { 1, 1.2, 1 }, { -1, 12.4, -3 }, Stone, "Slate", true)
	tower("TowerChipB", { 1.2, 1, 1 }, { 0.9, 8.5, -3 }, Stone, "Slate", true)
	tower("TowerDark", { 5, 6, 0.1 }, { 0, 10.5, 2.45 }, Black, "SmoothPlastic")
	tower("TowerLoft", { 5, 0.3, 5 }, { 0, 17.85, 0 }, StoneDark, "Slate", true)
	-- Stone bands round the shaft, moss and arrow slits.
	for b, y in { 7.7, 17.7 } do
		tower(`TowerBandFront{b}`, { 7, 0.6, 0.3 }, { 0, y, -3.65 }, Stone, "Slate")
		tower(`TowerBandBack{b}`, { 7, 0.6, 0.3 }, { 0, y, 3.65 }, Stone, "Slate")
		tower(`TowerBandLeft{b}`, { 0.3, 0.6, 7.6 }, { -3.65, y, 0 }, Stone, "Slate")
		tower(`TowerBandRight{b}`, { 0.3, 0.6, 7.6 }, { 3.65, y, 0 }, Stone, "Slate")
	end
	tower("TowerMossFront", { 2.2, 2.6, 0.1 }, { -2, 5, -3.55 }, Moss, "Grass")
	tower("TowerMossLeft", { 0.1, 3, 2 }, { -3.55, 12, 1 }, Moss, "Grass")
	tower("TowerSlitRight", { 0.1, 2.4, 1 }, { 3.55, 12, 0 }, Black, "SmoothPlastic")
	tower("TowerSlitLeft", { 0.1, 2.4, 1 }, { -3.55, 12, -1.6 }, Black, "SmoothPlastic")
	-- The clock, stopped at three, with a crack across it.
	tower("ClockFace", { 3.2, 3.2, 0.1 }, { 0, 15.5, -3.55 }, Clock, "SmoothPlastic")
	tower("ClockMinute", { 0.2, 1.4, 0.05 }, { 0, 16.2, -3.625 }, Black, "SmoothPlastic")
	tower("ClockHour", { 0.9, 0.2, 0.05 }, { 0.55, 15.5, -3.625 }, Black, "SmoothPlastic")
	tower("ClockCrack", { 0.1, 1.2, 0.05 }, { -0.8, 15, -3.625 }, Black, "SmoothPlastic")
	-- The belfry: one post snapped off, the front half of the roof fallen in the water, the
	-- bell still hanging from the back half.
	for i, spot in { { -2.8, -2.8 }, { -2.8, 2.8 }, { 2.8, 2.8 } } do
		tower(`TowerPost{i}`, { 1.4, 6, 1.4 }, { spot[1], 21, spot[2] }, Stone, "Slate", true)
	end
	tower("TowerPostBroken", { 1.4, 3, 1.4 }, { 2.8, 19.5, -2.8 }, Stone, "Slate", true)
	tower("TowerCap", { 8, 1, 4.4 }, { 0, 24.5, 1.8 }, StoneDark, "Slate", true)
	tower("TowerRoof", { 6, 1, 3 }, { 0, 25.5, 1.9 }, StoneDark, "Slate", true)
	tower("TowerRoofTop", { 3, 1.2, 2 }, { 0, 26.6, 2.2 }, StoneDark, "Slate", true)
	tower("BellHanger", { 0.4, 2.2, 0.4 }, { 0, 22.9, 0.5 }, Iron, "Metal")
	tower("Bell", { 2.6, 2.4, 2.6 }, { 0, 20.6, 0.5 }, { 150, 110, 50 }, "Metal")
	tower("BellLip", { 3.2, 0.5, 3.2 }, { 0, 19.15, 0.5 }, { 130, 94, 42 }, "Metal")
	-- What fell out: stones from the hole, sticking out of the water, and the roof half.
	for i, stone in
		{
			{ -60.5, 51, 2.6, 2.4, 2.2, 15 },
			{ -57, 49.5, 1.8, 2.2, 1.6, 40 },
			{ -63, 48.5, 2.2, 2.6, 2, 70 },
			{ -59.5, 46.2, 1.6, 2.3, 1.4, 25 },
			{ -55.5, 45.8, 1.2, 2.1, 1.2, 55 },
		}
	do
		local rock = part(
			parts,
			`FallenStone{i}`,
			{ stone[3], stone[4], stone[5] },
			{ stone[1], Bed + stone[4] / 2, stone[2] },
			if i % 2 == 0 then Stone else MossStone,
			"Slate",
			true
		)
		rock.rot = { 0, stone[6], 0 }
	end
	local fallen = part(parts, "FallenRoof", { 8, 1, 4.4 }, { -67, Bed + 1.2, 42 }, StoneDark, "Slate", true)
	fallen.rot = { 0, 35, 18 }

	-- A rowboat half sunk in the south-west water.
	take(-58, -42, -28, -12, true)
	take(-64, -36, -34, -6, false)
	local boat = group(parts, { -50, Surface - 0.6, -20 }, 25, 0)
	boat("BoatBottom", { 3, 0.3, 8 }, { 0, 0.25, 0 }, Rotten, "WoodPlanks", true)
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		boat(`BoatSide{tag}`, { 0.3, 1, 8 }, { side * 1.65, 0.75, 0 }, Plank, "WoodPlanks", true)
		boat(`BoatEnd{tag}`, { 3.6, 1, 0.3 }, { 0, 0.75, side * 4.15 }, Plank, "WoodPlanks", true)
	end
	boat("BoatSeat", { 3, 0.2, 0.8 }, { 0, 0.9, 0 }, Plank, "Wood")
	boat("BoatOar", { 0.25, 0.25, 6 }, { 0.5, 1.125, 0.5 }, Bark, "Wood")

	-- Cypress trees through the water, with reeds and lily pads between them.
	local blocks = { { -86, -9, -40, 12 }, { 9, 86, -40, 12 }, { -86, -9, 30, 84 }, { 9, 86, 30, 84 } }
	local trees = 0
	for _, b in blocks do
		for x = b[1] + 2, b[2] - 2, 13 do
			for z = b[3] + 2, b[4] - 2, 13 do
				local tx2, tz2 = x + (roll() - 0.5) * 4, z + (roll() - 0.5) * 4
				if roll() < 0.45 and clear(taken, tx2, tz2, 1) then
					trees += 1
					cypress(parts, `Cypress{trees}`, tx2, tz2, 14 + roll() * 6)
					take(tx2 - 4.5, tx2 + 4.5, tz2 - 4, tz2 + 4, false)
					table.insert(solids, { tx2 - 2.2, tx2 + 2.2, tz2 - 2.2, tz2 + 2.2 })
				end
			end
		end
	end
	local pads, reeds = 0, 0
	for _, b in blocks do
		for x = b[1], b[2], 6 do
			for z = b[3], b[4], 6 do
				local px, pz = x + (roll() - 0.5) * 2, z + (roll() - 0.5) * 2
				local pick = roll()
				if clear(taken, px, pz, 1.5) then
					if pick < 0.3 then
						pads += 1
						local d = 1.5 + roll() * 1
						local pad = part(
							parts,
							`LilyPad{pads}`,
							{ d, 0.1, d },
							{ px, Surface + 0.05, pz },
							{ 60, 96, 50 },
							"Grass"
						)
						pad.rot = { 0, roll() * 90, 0 }
					elseif pick < 0.5 then
						-- Reeds grow from the pit floor; `h` is how far they stand out of the water.
						reeds += 1
						local h = 3 + roll() * 2
						for i, o in { { -0.4, 0 }, { 0.3, 0.3 }, { 0.1, -0.45 } } do
							local stalk = h - (i - 1) * 0.6 + BayouWater
							part(
								parts,
								`Reeds{reeds}Stalk{i}`,
								{ 0.2, stalk, 0.2 },
								{ px + o[1], Bed + stalk / 2, pz + o[2] },
								{ 96, 110, 60 },
								"Grass"
							)
						end
						part(
							parts,
							`Reeds{reeds}Head`,
							{ 0.35, 0.8, 0.35 },
							{ px - 0.4, Surface + h + 0.4, pz },
							{ 80, 54, 34 },
							"Fabric"
						)
					end
				end
			end
		end
	end

	-- Fireflies drifting over the water, a few bright enough to light it.
	local flies = 0
	while flies < 40 do
		local b = blocks[1 + math.floor(roll() * 4)]
		local x, z = b[1] + roll() * (b[2] - b[1]), b[3] + roll() * (b[4] - b[3])
		local y = 4 + roll() * 3
		if clear(solids, x, z, 0.5) then
			flies += 1
			local fly = part(parts, `Firefly{flies}`, { 0.3, 0.3, 0.3 }, { x, y, z }, Firefly, "Neon")
			if flies % 6 == 0 then
				fly.light = { color = Firefly, range = 10, brightness = 0.8 }
			end
		end
	end
	return parts
end

local Red = { 140, 46, 46 }
local Cream = { 190, 176, 146 }
local Teal = { 52, 108, 102 }
local Purple = { 84, 58, 104 }
local Leaf = { 58, 92, 44 }
local LeafDark = { 40, 70, 34 }
local Grime = { 96, 78, 58 }
local Rust = { 120, 70, 50 }
local Gold = { 210, 170, 70 }
local BulbColors =
	{ { 255, 80, 80 }, { 255, 210, 90 }, { 90, 200, 255 }, { 180, 110, 255 }, { 120, 255, 140 } }

-- A round slab or post: a cylinder of diameter `d`, `h` tall, standing upright.
local function disc(
	parts: { Part },
	name: string,
	at: { number },
	d: number,
	h: number,
	color: { number },
	material: string,
	solid: boolean?
): Part
	local p = part(parts, name, { h, d, d }, at, color, material, solid)
	p.shape = "Cylinder"
	p.rot = { 0, 0, 90 }
	return p
end

-- A striped cone of stacked discs, from `bottom` up: a tent or carousel roof.
local function stripedCone(
	parts: { Part },
	name: string,
	x: number,
	z: number,
	bottom: number,
	sizes: { number },
	h: number,
	colors: { { number } }
)
	for i, d in sizes do
		disc(
			parts,
			`{name}{i}`,
			{ x, bottom + (i - 0.5) * h, z },
			d,
			h,
			colors[(i - 1) % #colors + 1],
			"Fabric",
			true
		)
	end
end

-- A carousel horse round a pole (the pole runs between its two halves), facing local -z.
local function horse(
	add: (string, { number }, { number }, { number }, string, boolean?, number?) -> Part,
	name: string,
	hy: number,
	coat: { number }
)
	add(name .. "Front", { 0.9, 1.2, 1.4 }, { 0, hy, -0.95 }, coat, "SmoothPlastic", true)
	add(name .. "Back", { 0.9, 1.2, 1.4 }, { 0, hy, 0.95 }, coat, "SmoothPlastic", true)
	add(name .. "Neck", { 0.6, 1.2, 0.6 }, { 0, hy + 1.2, -1.3 }, coat, "SmoothPlastic")
	add(name .. "Head", { 0.7, 0.6, 1.2 }, { 0, hy + 2.1, -1.7 }, coat, "SmoothPlastic")
	add(name .. "Saddle", { 0.95, 0.2, 0.8 }, { 0, hy + 0.7, 0.7 }, Red, "Fabric")
	add(name .. "Tail", { 0.2, 0.9, 0.2 }, { 0, hy + 0.1, 1.75 }, { 60, 40, 30 }, "Fabric")
	for i, leg in { { -0.3, -1.2 }, { 0.3, -1.2 }, { -0.3, 1.2 }, { 0.3, 1.2 } } do
		add(`{name}Leg{i}`, { 0.25, 1.2, 0.25 }, { leg[1], hy - 1.2, leg[2] }, coat, "SmoothPlastic")
	end
end

-- A game stall, its counter facing local -z: walls, a striped awning, a sign and prizes.
local function stall(
	parts: { Part },
	name: string,
	x: number,
	z: number,
	yaw: number,
	label: string,
	n: number
)
	local add = group(parts, { x, 0, z }, yaw, 0)
	local wall = if n % 2 == 0 then Teal else Purple
	add(name .. "Counter", { 6, 2.4, 1 }, { 0, 1.2, -2.5 }, Cream, "WoodPlanks", true)
	add(name .. "Back", { 6, 6, 0.4 }, { 0, 3, 2.5 }, wall, "WoodPlanks", true)
	add(name .. "Left", { 0.4, 6, 4.6 }, { -3.2, 3, 0 }, wall, "WoodPlanks", true)
	add(name .. "Right", { 0.4, 6, 4.6 }, { 3.2, 3, 0 }, wall, "WoodPlanks", true)
	add(name .. "Roof", { 7, 0.3, 6 }, { 0, 6.15, 0 }, Rust, "Metal", true)
	for i = 1, 7 do
		-- A torn awning on every third stall: two stripes gone.
		if not (n % 3 == 0 and (i == 3 or i == 4)) then
			add(
				`{name}Awning{i}`,
				{ 1, 0.2, 2 },
				{ i - 4, 6.4, -3 },
				if i % 2 == 0 then Cream else Red,
				"Fabric"
			)
		end
	end
	local sign = add(name .. "Sign", { 5, 1.2, 0.2 }, { 0, 7.1, -2.5 }, Cream, "WoodPlanks")
	sign.text = label
	add(name .. "Shelf", { 5.6, 0.2, 0.6 }, { 0, 3.8, 2 }, Rust, "Wood")
	for i, px in { -2, 0, 2 } do
		local fur = if i == 2 then { 120, 90, 60 } else { 150, 110, 150 }
		add(`{name}Teddy{i}`, { 0.8, 0.9, 0.6 }, { px, 4.35, 2 }, fur, "Fabric")
		add(`{name}TeddyHead{i}`, { 0.6, 0.6, 0.5 }, { px, 5.1, 2 }, fur, "Fabric")
	end
	for i, px in { -0.5, 0, 0.5 } do
		add(`{name}Bottle{i}`, { 0.3, 0.7, 0.3 }, { px, 2.75, -2.5 }, { 70, 110, 80 }, "Glass")
	end
	if n % 2 == 1 then
		add(name .. "Ivy", { 0.1, 4, 1.6 }, { -3.45, 2, 0.6 }, Leaf, "Grass")
		add(name .. "IvyLow", { 0.1, 2, 1.2 }, { -3.45, 1, -1 }, LeafDark, "Grass")
	end
	if n % 4 == 1 then
		local bulb = add(name .. "Bulb", { 0.4, 0.4, 0.4 }, { 0, 5.8, -2.4 }, { 255, 210, 90 }, "Neon")
		bulb.light = { color = { 255, 200, 120 }, range = 12, brightness = 0.8 }
	end
end

-- The Abandoned Carnival: a dead carnival under tall cliffs, slowly taken back by weeds.
-- From the arrival pad you pass the ticket booth to a striped entrance arch; a dirt path
-- under strings of dead bulbs leads straight to the huge big top in the middle. Around it: a
-- broken ferris wheel, a broken carousel, a small midway of game stalls (one collapsed), a
-- fortune teller's tent, a caravan, a strongman bell and a popcorn cart, with bushes, grass,
-- young trees, crates and old signs everywhere between. Monsters roam all the open ground.
local function abandonedCarnival(): { Part }
	local parts: { Part } = {}
	perimeterFence(parts)
	cliffs(parts, 113, { 62, 54, 72 })
	part(parts, "PathToTent", { 10, 0.1, 75 }, { 0, 0.05, -20.5 }, { 92, 76, 58 }, "Ground")

	-- The way in: past the ticket booth, under a striped arch with bulbs.
	part(parts, "PathMain", { 8, 0.1, 30 }, { 0, 0.05, -73 }, StoneDark, "Cobblestone")
	part(parts, "PathCross", { 39, 0.1, 6 }, { 4.5, 0.05, -91 }, StoneDark, "Cobblestone")
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		local x = side * 8
		for b = 1, 5 do
			part(
				parts,
				`Gate{tag}Band{b}`,
				{ 2, 2, 2 },
				{ x, b * 2 - 1, -62 },
				if b % 2 == 0 then Cream else Red,
				"WoodPlanks",
				true
			)
		end
		local ball = part(parts, `Gate{tag}Ball`, { 1.6, 1.6, 1.6 }, { x, 10.8, -62 }, Gold, "Metal", true)
		ball.shape = "Ball"
		Kit.lampPost(parts, `PathLamp{tag}`, side * 6.5, -80)
		fenceRun(parts, `InnerFence{tag}`, side * 10, side * 106, -62)
	end
	part(parts, "GateBar", { 14, 1.2, 1 }, { 0, 9.4, -62 }, Teal, "WoodPlanks")
	local sign = part(parts, "GateSign", { 12, 2.2, 0.3 }, { 0, 11.1, -62 }, Cream, "WoodPlanks")
	sign.text = "Abandoned Carnival"
	for i = 0, 5 do
		local lit = i == 1 or i == 4
		local bulb = part(
			parts,
			`GateBulb{i}`,
			{ 0.4, 0.4, 0.4 },
			{ -5 + i * 2, 12.4, -62 },
			if lit then BulbColors[i % #BulbColors + 1] else { 70, 66, 60 },
			if lit then "Neon" else "Glass"
		)
		if lit then
			bulb.light = { color = BulbColors[i % #BulbColors + 1], range = 14, brightness = 0.8 }
		end
	end
	local booth = group(parts, { 14, 0, -72 }, 0, 0)
	booth("Booth", { 4, 6, 4 }, { 0, 3, 0 }, Red, "WoodPlanks", true)
	booth("BoothWindow", { 2, 1.5, 0.1 }, { 0, 3.5, -2.05 }, Black, "SmoothPlastic")
	booth("BoothLedge", { 3, 0.2, 0.6 }, { 0, 2.6, -2.3 }, Cream, "Wood", true)
	local tickets = booth("BoothSign", { 3.6, 0.9, 0.1 }, { 0, 5.1, -2.05 }, Cream, "WoodPlanks")
	tickets.text = "TICKETS"
	local skull = booth("BoothSkull", { 0.9, 0.9, 0.9 }, { 0, 3.15, -2.56 }, Bone, "SmoothPlastic")
	skull.solid = true
	for i, ex in { -0.2, 0.2 } do
		booth(`BoothSkullEye{i}`, { 0.25, 0.25, 0.05 }, { ex, 3.3, -3.035 }, Black, "SmoothPlastic")
	end
	for i, roof in { { 5, 0.4 }, { 3.5, 0.6 }, { 2, 0.6 } } do
		local y = ({ 6.2, 6.7, 7.3 })[i]
		booth(
			`BoothRoof{i}`,
			{ roof[1], roof[2], roof[1] },
			{ 0, y, 0 },
			if i % 2 == 0 then Cream else Red,
			"Fabric",
			true
		)
	end

	-- The big top in the middle, the main attraction: sixteen striped wall panels 11 studs tall,
	-- a doorway under an awning, a stepped striped roof 27 studs high with flags. It's dirty:
	-- grime and ivy on the walls, a panel torn down, tears and moss on the roof. Inside: a
	-- sawdust ring, the king pole, toppled benches and one lamp still burning.
	local bx, bz = 0, 45
	for i = 0, 15 do
		local a = i * 22.5
		local r = math.rad(a)
		local function onWall(name: string, size: { number }, y: number, color: { number }, material: string)
			local plate = part(
				parts,
				name,
				size,
				{ bx + 24.65 * math.sin(r), y, bz + 24.65 * math.cos(r) },
				color,
				material
			)
			plate.rot = { 0, a, 0 }
		end
		if i ~= 8 then
			local height = if i == 5 then 6 else 11
			local panel = part(
				parts,
				`BigTopWall{i}`,
				{ 9.5, height, 0.6 },
				{ bx + 24.3 * math.sin(r), height / 2, bz + 24.3 * math.cos(r) },
				if i % 2 == 0 then Red else Cream,
				"Fabric",
				true
			)
			panel.rot = { 0, a, 0 }
			if i == 1 or i == 4 or i == 10 or i == 13 then
				onWall(`BigTopIvy{i}`, { 1.6, 4 + (i % 3) * 2, 0.1 }, (4 + (i % 3) * 2) / 2, Leaf, "Grass")
			elseif i == 3 or i == 7 or i == 12 then
				onWall(`BigTopGrime{i}`, { 4, 3, 0.1 }, 5.5, Grime, "Fabric")
			end
		end
	end
	local rings = { 51, 46, 41, 36, 31, 26, 21, 16, 11, 6 }
	stripedCone(parts, "BigTopRoof", bx, bz, 11, rings, 1.6, { Red, Cream })
	for i, mark in { { 1, 60, Black }, { 2, 200, Leaf }, { 4, 300, Black }, { 5, 120, Leaf } } do
		local ring = mark[1] :: number
		local a = mark[2] :: number
		local radius = (rings[ring] + rings[ring + 1]) / 4
		local patch = part(parts, `BigTopRoofPatch{i}`, { 3.5, 0.05, 1.8 }, {
			bx + radius * math.sin(math.rad(a)),
			11 + ring * 1.6 + 0.025,
			bz + radius * math.cos(math.rad(a)),
		}, mark[3] :: { number }, "Fabric")
		patch.rot = { 0, a, 0 }
	end
	part(parts, "BigTopFlagPole", { 0.4, 5, 0.4 }, { bx, 29.5, bz }, Iron, "Metal")
	part(parts, "BigTopFlag", { 3.4, 2, 0.1 }, { bx + 1.9, 31, bz }, Purple, "Fabric")
	for _, side in { -1, 1 } do
		part(
			parts,
			`BigTopDoorPost{side}`,
			{ 0.5, 11, 0.5 },
			{ bx + side * 5.75, 5.5, bz - 28 },
			Rust,
			"Metal",
			true
		)
	end
	for i = 0, 10 do
		if i ~= 7 then
			part(
				parts,
				`BigTopAwning{i}`,
				{ 1, 0.2, 3.2 },
				{ bx - 5 + i, 8.1, bz - 26.4 },
				if i % 2 == 0 then Red else Cream,
				"Fabric"
			)
		end
	end
	local bigSign = part(parts, "BigTopSign", { 11, 2.4, 0.3 }, { bx, 9.6, bz - 28 }, Cream, "WoodPlanks")
	bigSign.text = "The Big Top"
	disc(parts, "BigTopRing", { bx, 0.025, bz }, 22, 0.05, { 150, 120, 80 }, "Fabric")
	disc(parts, "BigTopKingPole", { bx, 5.525, bz }, 2, 10.95, Rust, "Metal", true)
	for i, bench in { { 45, 0 }, { 315, 0 }, { 110, 18 } } do
		local a = math.rad(bench[1])
		local seat = part(
			parts,
			`BigTopBench{i}`,
			{ 6, 1, 1.5 },
			{ bx + 18 * math.sin(a), 0.5, bz + 18 * math.cos(a) },
			Plank,
			"WoodPlanks",
			true
		)
		seat.rot = { 0, bench[1], bench[2] }
	end
	local lamp = part(parts, "BigTopLamp", { 0.8, 0.8, 0.8 }, { bx + 8, 9, bz }, Glow, "Neon")
	lamp.light = { color = Glow, range = 26, brightness = 0.9 }
	part(parts, "BigTopLampChain", { 0.1, 1.6, 0.1 }, { bx + 8, 10.2, bz }, Iron, "Metal")

	-- The broken carousel in the south-west: a round floor, a centre column, a striped roof,
	-- horses on poles. Two poles stand bare, one is snapped, its horse lies on the ground.
	local cx, cz = -64, 52
	disc(parts, "CarouselFloor", { cx, 0.5, cz }, 22, 1, { 110, 80, 60 }, "WoodPlanks", true)
	disc(parts, "CarouselColumn", { cx, 6, cz }, 3, 10, Gold, "Metal", true)
	stripedCone(parts, "CarouselRoof", cx, cz, 11, { 26, 21, 16, 11, 6 }, 0.8, { Red, Cream, Teal })
	for i = 1, 8 do
		local a = 22.5 + (i - 1) * 45
		local r = math.rad(a)
		local px, pz = cx + 8 * math.sin(r), cz + 8 * math.cos(r)
		if i == 8 then
			part(parts, `CarouselPole{i}Low`, { 0.4, 3, 0.4 }, { px, 2.5, pz }, Gold, "Metal", true)
			part(parts, `CarouselPole{i}High`, { 0.4, 3, 0.4 }, { px, 9.5, pz }, Gold, "Metal")
		else
			part(parts, `CarouselPole{i}`, { 0.4, 10, 0.4 }, { px, 6, pz }, Gold, "Metal", true)
			if i <= 5 then
				horse(
					group(parts, { px, 0, pz }, a - 90, 0),
					`Horse{i}`,
					4,
					if i % 2 == 0 then Cream else { 90, 70, 60 }
				)
			end
		end
	end
	local fallen = math.rad(22.5 + 7 * 45 + 8)
	horse(
		group(parts, { cx + 14 * math.sin(fallen), 0.45, cz + 14 * math.cos(fallen) }, 40, 90),
		"HorseFallen",
		0,
		Cream
	)
	for i, weed in { { 3, 4 }, { -5, 2 }, { 2, -6 }, { -4, -5 } } do
		part(parts, `CarouselWeed{i}`, { 1.2, 0.8, 1.2 }, { cx + weed[1], 1.4, cz + weed[2] }, Leaf, "Grass")
	end

	-- The ferris wheel in the north-east, rusted still: a rim, spokes, a hub on two A-frames,
	-- and gondolas hanging in front. One spoke and one gondola are gone; the gondola lies below.
	local fx, fz, hubY = 72, 62, 22
	for i = 0, 15 do
		local b = i * 22.5
		local r = math.rad(b)
		local seg = part(
			parts,
			`WheelRim{i}`,
			{ 7.16, 0.8, 0.8 },
			{ fx + 18.4 * math.sin(r), hubY + 18.4 * math.cos(r), fz },
			Rust,
			"Metal",
			true
		)
		seg.rot = { 0, 0, -b }
	end
	for i = 0, 7 do
		if i ~= 5 then
			local b = i * 45
			local r = math.rad(b)
			local spoke = part(
				parts,
				`WheelSpoke{i}`,
				{ 16.5, 0.4, 0.4 },
				{ fx + 9.75 * math.sin(r), hubY + 9.75 * math.cos(r), fz },
				Rust,
				"Metal"
			)
			spoke.rot = { 0, 0, 90 - b }
		end
	end
	local hub = part(parts, "WheelHub", { 5.4, 3, 3 }, { fx, hubY, fz }, Iron, "Metal", true)
	hub.shape = "Cylinder"
	hub.rot = { 0, 90, 0 }
	for _, zSide in { -1, 1 } do
		local tag = if zSide < 0 then "Front" else "Back"
		local lz = fz + zSide * 3.2
		part(parts, `WheelBearing{tag}`, { 3, 3, 1 }, { fx, hubY, lz }, Iron, "Metal", true)
		for _, xSide in { -1, 1 } do
			local leg = `WheelLeg{tag}{if xSide < 0 then "Left" else "Right"}`
			local from = { fx + xSide * 11, 0, lz }
			local dx, dy = -xSide * 9.5, hubY - 1.5
			local length = math.sqrt(dx * dx + dy * dy)
			local up = math.deg(math.atan2(dy, math.abs(dx)))
			Kit.stick(parts, leg, from, if xSide < 0 then 0 else 180, up, length, 1, Iron, "Metal")
		end
	end
	for i = 0, 7 do
		if i ~= 4 then
			local b = 22.5 + i * 45
			local r = math.rad(b)
			local ax, ay = fx + 18.4 * math.sin(r), hubY + 18.4 * math.cos(r)
			local car = if i % 2 == 0 then Teal else Red
			part(parts, `Gondola{i}Pin`, { 0.3, 0.3, 1.3 }, { ax, ay, fz - 1.05 }, Iron, "Metal")
			part(parts, `Gondola{i}Rod`, { 0.2, 0.8, 0.2 }, { ax, ay - 0.55, fz - 1.6 }, Iron, "Metal")
			part(parts, `Gondola{i}Canopy`, { 3.2, 0.25, 2.2 }, { ax, ay - 1.075, fz - 1.6 }, car, "Metal")
			for j, c in { { -1.4, -0.9 }, { 1.4, -0.9 }, { -1.4, 0.9 }, { 1.4, 0.9 } } do
				part(
					parts,
					`Gondola{i}Post{j}`,
					{ 0.15, 1, 0.15 },
					{ ax + c[1], ay - 1.7, fz - 1.6 + c[2] },
					Iron,
					"Metal"
				)
			end
			part(parts, `Gondola{i}Tub`, { 3, 1.4, 2 }, { ax, ay - 2.9, fz - 1.6 }, car, "Metal", true)
		end
	end
	local wreck = part(parts, "GondolaFallen", { 3, 1.4, 2 }, { fx + 15, 0.9, fz - 9 }, Red, "Metal", true)
	wreck.rot = { 0, 30, 12 }
	local roofWreck = part(
		parts,
		"GondolaFallenCanopy",
		{ 3.2, 0.25, 2.2 },
		{ fx + 19, 0.2, fz - 7 },
		Red,
		"Metal"
	)
	roofWreck.rot = { 0, -20, 0 }
	for i, b in { 0, 90, 180, 270 } do
		local r = math.rad(b)
		local lit = i == 2
		local bulb = part(
			parts,
			`WheelBulb{i}`,
			{ 0.4, 0.4, 0.4 },
			{ fx + 18.4 * math.sin(r), hubY + 18.4 * math.cos(r), fz - 0.6 },
			if lit then { 255, 80, 80 } else { 70, 66, 60 },
			if lit then "Neon" else "Glass"
		)
		if lit then
			bulb.light = { color = { 255, 80, 80 }, range = 16, brightness = 1 }
		end
	end

	-- A small midway of game stalls in the south-east: two rows facing each other across a
	-- lane, the last stall collapsed.
	local labels =
		{ "Ring Toss", "Duck Pond", "Whack-a-Ghoul", "Lucky Darts", "Bottle Smash", "Guess Your Fate" }
	for i, x in { 36, 44, 52 } do
		stall(parts, `StallSouth{i}`, x, -24, 180, labels[i], i)
		stall(parts, `StallNorth{i}`, x, -1, 0, labels[i + 3], i + 3)
	end
	local wreckRoof = part(parts, "StallWreckRoof", { 7, 0.3, 6 }, { 61, 0.15, -23 }, Rust, "Metal", true)
	wreckRoof.rot = { 0, 12, 0 }
	local wreckCounter = part(
		parts,
		"StallWreckCounter",
		{ 6, 1, 2.4 },
		{ 61, 0.5, -17.5 },
		Cream,
		"WoodPlanks",
		true
	)
	wreckCounter.rot = { 0, -8, 0 }
	for i, board in { { 57.5, -29, 30 }, { 68.5, -27, -50 }, { 65.5, -19.5, 80 } } do
		local plank = part(
			parts,
			`StallWreckBoard{i}`,
			{ 0.4, 0.2, 4.6 },
			{ board[1], 0.1, board[2] },
			Teal,
			"WoodPlanks"
		)
		plank.rot = { 0, board[3], 0 }
	end
	local fallenSign = part(parts, "StallWreckSign", { 5, 0.2, 1.2 }, { 60, 0.1, -12 }, Cream, "WoodPlanks")
	fallenSign.rot = { 0, -20, 0 }

	-- Small extras. A fortune teller's tent beside the path.
	local tx, tz = -36, -10
	disc(parts, "FortuneTent", { tx, 2, tz }, 8, 4, Purple, "Fabric", true)
	stripedCone(parts, "FortuneRoof", tx, tz, 4, { 9, 6.5, 4, 1.5 }, 1, { Purple, Gold })
	part(parts, "FortuneDoor", { 2, 3, 0.1 }, { tx, 1.5, tz - 4.05 }, Black, "SmoothPlastic")
	local orb = part(parts, "FortuneOrb", { 0.8, 0.8, 0.8 }, { tx, 8.4, tz }, { 160, 110, 255 }, "Neon")
	orb.shape = "Ball"
	orb.light = { color = { 160, 110, 255 }, range = 12, brightness = 1 }
	-- A caravan in the north-west corner.
	local vx, vz = -76, -30
	part(parts, "Caravan", { 8, 5, 4 }, { vx, 4, vz }, Purple, "WoodPlanks", true)
	part(parts, "CaravanRoof", { 8.4, 0.6, 4.6 }, { vx, 6.8, vz }, Cream, "WoodPlanks", true)
	part(parts, "CaravanRoofTop", { 7, 0.6, 3 }, { vx, 7.4, vz }, Cream, "WoodPlanks", true)
	for i, w in { { -2.5, -2.25 }, { 2.5, -2.25 }, { -2.5, 2.25 }, { 2.5, 2.25 } } do
		local wheel = part(
			parts,
			`CaravanWheel{i}`,
			{ 0.5, 2.4, 2.4 },
			{ vx + w[1], 1.2, vz + w[2] },
			Rust,
			"Wood",
			true
		)
		wheel.shape = "Cylinder"
		wheel.rot = { 0, 90, 0 }
	end
	local caravanWindow = part(
		parts,
		"CaravanWindow",
		{ 1.6, 1.2, 0.1 },
		{ vx + 2, 4.6, vz - 2.05 },
		Glow,
		"Neon"
	)
	caravanWindow.light = { color = Glow, range = 12, brightness = 0.7 }
	part(parts, "CaravanDoor", { 1.6, 3, 0.1 }, { vx, 3.5, vz - 2.05 }, Black, "SmoothPlastic")
	-- A strongman bell beside the ferris wheel.
	local sx, sz = 38, 30
	part(parts, "StrongmanBase", { 3, 0.6, 3 }, { sx, 0.3, sz }, Rust, "Wood", true)
	part(parts, "StrongmanBoard", { 1, 12, 0.4 }, { sx, 6.6, sz }, Cream, "WoodPlanks", true)
	part(parts, "StrongmanPuck", { 0.8, 0.4, 0.4 }, { sx, 3, sz - 0.4 }, Red, "Metal")
	local bell = part(parts, "StrongmanBell", { 1.4, 1.4, 1.4 }, { sx, 13.3, sz }, Gold, "Metal", true)
	bell.shape = "Ball"
	part(parts, "StrongmanHammer", { 0.3, 0.3, 3 }, { sx + 2, 0.15, sz - 1 }, Plank, "Wood")
	part(parts, "StrongmanHammerHead", { 1, 0.8, 0.8 }, { sx + 2, 0.4, sz - 2.9 }, Iron, "Metal")
	-- A popcorn cart and two stands of faded balloons.
	local px, pz = 14, -36
	part(parts, "PopcornCart", { 3, 2, 2 }, { px, 1.5, pz }, Red, "WoodPlanks", true)
	local glass = part(parts, "PopcornGlass", { 2.6, 2, 1.6 }, { px, 3.5, pz }, { 220, 220, 200 }, "Glass")
	glass.transparency = 0.5
	part(parts, "PopcornRoof", { 3.4, 0.3, 2.4 }, { px, 4.65, pz }, Cream, "Fabric", true)
	for i, side in { -1, 1 } do
		local wheel = part(
			parts,
			`PopcornWheel{i}`,
			{ 0.3, 1, 1 },
			{ px + side * 1, 0.5, pz - 1.15 },
			Iron,
			"Metal"
		)
		wheel.shape = "Cylinder"
		wheel.rot = { 0, 90, 0 }
	end
	for s, spot in { { -16, -42 }, { 86, -30 } } do
		part(parts, `Balloons{s}Weight`, { 2, 0.4, 0.4 }, { spot[1], 0.2, spot[2] }, Iron, "Metal")
		for i, bx2 in { -0.7, 0, 0.7 } do
			local top = if i == 2 then 6.8 else 5.4
			part(
				parts,
				`Balloons{s}String{i}`,
				{ 0.05, top - 0.4, 0.05 },
				{ spot[1] + bx2, 0.4 + (top - 0.4) / 2, spot[2] },
				Cream,
				"Fabric"
			)
			local d = if s == 2 and i == 3 then 0.7 else 1.2
			local balloon = part(
				parts,
				`Balloons{s}Balloon{i}`,
				{ d, d, d },
				{ spot[1] + bx2, top + d / 2, spot[2] },
				BulbColors[(i + s) % #BulbColors + 1],
				"SmoothPlastic"
			)
			balloon.shape = "Ball"
		end
	end

	-- Strings of bulbs over the path to the big top, most of them dead; one pole has fallen.
	local n = 0
	for _, z in { -48, -32, -16, 0 } do
		n += 1
		for _, side in { -1, 1 } do
			local tag = if side < 0 then "Left" else "Right"
			if n == 3 and side > 0 then
				local down = part(
					parts,
					`LightPole{n}{tag}`,
					{ 0.4, 9, 0.4 },
					{ 11.5, 0.2, z + 1 },
					Iron,
					"Metal",
					true
				)
				down.rot = { 0, 20, 90 }
			else
				part(parts, `LightPole{n}{tag}`, { 0.4, 9, 0.4 }, { side * 7.5, 4.5, z }, Iron, "Metal", true)
			end
		end
		if n ~= 3 then
			part(parts, `LightWire{n}`, { 14.6, 0.1, 0.1 }, { 0, 8.8, z }, Black, "Metal")
			for b, bx2 in { -6, -3.6, -1.2, 1.2, 3.6, 6 } do
				local lit = (n + b) % 4 == 0
				local color = BulbColors[(n + b) % #BulbColors + 1]
				local bulb = part(
					parts,
					`LightBulb{n}x{b}`,
					{ 0.3, 0.3, 0.3 },
					{ bx2, 8.6, z },
					if lit then color else { 70, 66, 60 },
					if lit then "Neon" else "Glass"
				)
				if lit then
					bulb.light = { color = color, range = 10, brightness = 0.6 }
				end
			end
		end
	end

	-- Weeds, bushes, young trees and junk over all the open ground in between.
	local roll = dice(4243)
	local busy = {
		{ -30, 30, 14, 75 }, -- big top
		{ -80, -48, 36, 68 }, -- carousel
		{ 56, 92, 46, 72 }, -- ferris wheel
		{ 28, 68, -32, 6 }, -- stalls
		{ -43, -29, -17, -3 }, -- fortune tent
		{ -84, -68, -36, -24 }, -- caravan
		{ 34, 44, 25, 35 }, -- strongman
		{ 10, 18, -40, -32 }, -- popcorn cart
		{ -19, -13, -45, -39 }, -- balloons
		{ 83, 89, -33, -27 }, -- balloons
		{ -10, 17, -60, 17 }, -- the path and its lights
	}
	local function free(x: number, z: number): boolean
		for _, b in busy do
			if x > b[1] - 2 and x < b[2] + 2 and z > b[3] - 2 and z < b[4] + 2 then
				return false
			end
		end
		return true
	end
	local SignWords = { "Closed", "This way!", "Keep Out", "Fun for all!", "No refunds", "Lost & Found" }
	local count = 0
	for x = -100, 100, 8 do
		for z = -54, 100, 8 do
			local ox, oz = x + (roll() - 0.5) * 4, z + (roll() - 0.5) * 4
			local pick = roll()
			if free(ox, oz) and pick < 0.7 then
				count += 1
				local name = `Overgrowth{count}`
				if pick < 0.25 then
					part(
						parts,
						name .. "Grass",
						{ 1.4, 0.8, 1.4 },
						{ ox, 0.4, oz },
						if pick < 0.12 then Leaf else LeafDark,
						"Grass"
					)
					part(
						parts,
						name .. "Blades",
						{ 0.8, 0.6, 0.8 },
						{ ox + 0.2, 1.1, oz - 0.1 },
						Leaf,
						"Grass"
					)
				elseif pick < 0.37 then
					part(parts, name .. "Bush", { 2.6, 1.6, 2.6 }, { ox, 0.8, oz }, LeafDark, "Grass")
					part(
						parts,
						name .. "BushTop",
						{ 1.6, 0.9, 1.6 },
						{ ox - 0.3, 2.05, oz + 0.2 },
						Leaf,
						"Grass"
					)
				elseif pick < 0.44 then
					part(parts, name .. "Moss", { 3, 0.05, 2 }, { ox, 0.025, oz }, LeafDark, "Grass").rot =
						{ 0, roll() * 90, 0 }
				elseif pick < 0.5 then
					part(parts, name .. "Trunk", { 0.8, 5, 0.8 }, { ox, 2.5, oz }, Bark, "Wood", true)
					part(parts, name .. "Leaves", { 3.2, 2.4, 3.2 }, { ox, 6.2, oz }, LeafDark, "Grass")
					part(
						parts,
						name .. "LeavesTop",
						{ 2, 1.4, 2 },
						{ ox + 0.3, 8.1, oz - 0.2 },
						Leaf,
						"Grass"
					)
				else
					local kind = math.floor(roll() * 5)
					if kind == 0 then
						part(
							parts,
							name .. "Crate",
							{ 2.2, 2.2, 2.2 },
							{ ox, 1.1, oz },
							Plank,
							"WoodPlanks",
							true
						)
					elseif kind == 1 then
						disc(parts, name .. "Barrel", { ox, 1.3, oz }, 1.8, 2.6, Rust, "Wood", true)
					elseif kind == 2 then
						local bale = part(
							parts,
							name .. "Hay",
							{ 3, 1.6, 2 },
							{ ox, 0.8, oz },
							{ 150, 130, 74 },
							"Fabric",
							true
						)
						bale.rot = { 0, roll() * 90, 0 }
					elseif kind == 3 then
						part(parts, name .. "SignPost", { 0.3, 3, 0.3 }, { ox, 1.5, oz }, Plank, "Wood", true)
						local board = part(
							parts,
							name .. "Sign",
							{ 3, 1.2, 0.2 },
							{ ox, 3.4, oz - 0.25 },
							Cream,
							"WoodPlanks"
						)
						board.text = SignWords[count % #SignWords + 1]
						board.rot = { 0, 0, (roll() - 0.5) * 16 }
					else
						local boards = part(
							parts,
							name .. "Boards",
							{ 3, 0.3, 1.2 },
							{ ox, 0.15, oz },
							Plank,
							"WoodPlanks"
						)
						boards.rot = { 0, roll() * 180, 0 }
					end
				end
			end
		end
	end
	return parts
end

-- How far a part reaches over the floor from its centre (half its width along x and z), and
-- how high its bottom is, for any rotation.
function Scenery.footprint(p: Part): (number, number, number)
	local rot = p.rot or { 0, 0, 0 }
	local rx, ry, rz = math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])
	-- CFrame.fromOrientation(rx, ry, rz) = rotate about Y, then X, then Z (outermost first).
	local cx, sx, cy, sy, cz, sz =
		math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local m = {
		{ cy * cz + sy * sx * sz, -cy * sz + sy * sx * cz, sy * cx },
		{ cx * sz, cx * cz, -sx },
		{ -sy * cz + cy * sx * sz, sy * sz + cy * sx * cz, cy * cx },
	}
	local half = { p.size[1] / 2, p.size[2] / 2, p.size[3] / 2 }
	local function reach(row: { number }): number
		return math.abs(row[1]) * half[1] + math.abs(row[2]) * half[2] + math.abs(row[3]) * half[3]
	end
	return reach(m[1]), reach(m[3]), p.at[2] - reach(m[2])
end

-- Monsters may walk under anything whose bottom is this high over their floor (roofs, wires,
-- the wheel's top).
Scenery.Overhead = 6
-- Walk-through parts lower than this (grass, mounds, puddles) are glided over.
Scenery.Low = 1.5

-- All the open ground of a zone as rectangles for monsters to roam: the floor in `cell`-stud
-- squares, minus every square within `pad` studs of a prop standing on it (solid, or a
-- walk-through one taller than `Low`), and minus the
-- arrival pad and the exit arch. Squares inside one of the `floors` (water, say) have their
-- floor at that height instead of the ground. The free squares are covered with big rectangles
-- (they may overlap).
export type GroundOptions = { cell: number?, pad: number?, floors: { Rect }? }
local Reach = 106
local KeepOut = {
	{ x = -20, z = -90, hx = 7, hz = 7 }, -- the arrival pad
	{ x = 20, z = -100, hx = 9, hz = 6 }, -- the exit and its arch
}
function Scenery.openGround(parts: { Part }, options: GroundOptions?): { Rect }
	local cell = options and options.cell or 1
	local pad = options and options.pad or 1
	local floors = options and options.floors or {}
	local n = math.floor(2 * Reach / cell)
	local function centre(i: number): number
		return -Reach + (i - 0.5) * cell
	end
	-- Which floor each square is on (0 = the ground), and whether something stands there.
	local floorOf: { { number } } = {}
	local blocked: { { boolean } } = {}
	for i = 1, n do
		floorOf[i], blocked[i] = {}, {}
		for j = 1, n do
			local x, z = centre(i), centre(j)
			floorOf[i][j] = 0
			for f, r in floors do
				if math.abs(x - r.x) < r.width / 2 and math.abs(z - r.z) < r.depth / 2 then
					floorOf[i][j] = f
				end
			end
		end
	end
	local function heightOf(f: number): number
		return if f == 0 then 0 else floors[f].y or 0
	end
	local function mark(
		minX: number,
		maxX: number,
		minZ: number,
		maxZ: number,
		top: number?,
		bottom: number?,
		rise: number?
	)
		local i0 = math.max(1, math.floor((minX + Reach) / cell) + 1)
		local i1 = math.min(n, math.ceil((maxX + Reach) / cell))
		local j0 = math.max(1, math.floor((minZ + Reach) / cell) + 1)
		local j1 = math.min(n, math.ceil((maxZ + Reach) / cell))
		for i = i0, i1 do
			for j = j0, j1 do
				local y = heightOf(floorOf[i][j])
				if
					top == nil
					or bottom == nil
					or (top > y + (rise or 0.05) and bottom < y + Scenery.Overhead)
				then
					blocked[i][j] = true
				end
			end
		end
	end
	for _, p in parts do
		local hx, hz, bottom = Scenery.footprint(p)
		local top = p.at[2] * 2 - bottom
		-- Walk-through parts only count when they stand taller than a monster can glide over.
		-- Slabs level with the ground (paths, banks, decks) are floor, even next to the water.
		local rise = if p.solid then 0.05 else Scenery.Low
		if math.abs(top) > 0.05 then
			mark(
				p.at[1] - hx - pad,
				p.at[1] + hx + pad,
				p.at[3] - hz - pad,
				p.at[3] + hz + pad,
				top,
				bottom,
				rise
			)
		end
	end
	for _, k in KeepOut do
		mark(k.x - k.hx, k.x + k.hx, k.z - k.hz, k.z + k.hz)
	end
	-- Cover the free squares with big rectangles: from each square not yet covered, grow the
	-- rectangle (on that square's floor) whose shorter side is longest, then the biggest. So a
	-- lane between graves becomes one long rectangle, and an open field one big block.
	-- Rectangles may overlap.
	local run: { { number } } = {} -- free squares on one floor from (i, j) along +x
	for i = n, 1, -1 do
		run[i] = {}
		for j = 1, n do
			local f = floorOf[i][j]
			run[i][j] = if blocked[i][j]
				then 0
				elseif i < n and floorOf[i + 1][j] == f then run[i + 1][j] + 1
				else 1
		end
	end
	-- The best rectangle with its corner at square (i, j).
	local function grow(i: number, j: number): (number, number, number, number)
		local f = floorOf[i][j]
		local i1, j1, bestSide, bestArea = i, j, 0, 0
		local width = math.huge
		local cj = j
		while cj <= n and run[i][cj] > 0 and floorOf[i][cj] == f do
			width = math.min(width, run[i][cj])
			local height = cj - j + 1
			local side, area = math.min(width, height), width * height
			if side > bestSide or (side == bestSide and area > bestArea) then
				i1, j1, bestSide, bestArea = i + width - 1, cj, side, area
			end
			cj += 1
		end
		return i1, j1, bestSide, bestArea
	end
	-- Every corner of the open ground (a free square with a blocked or other-floor square to its
	-- -x or -z side) offers its best rectangle; take the best first, while they add new ground.
	local function edge(i: number, j: number, di: number, dj: number): boolean
		local a, b = i + di, j + dj
		return a < 1 or b < 1 or blocked[a][b] or floorOf[a][b] ~= floorOf[i][j]
	end
	type Offer = { i: number, j: number, i1: number, j1: number, side: number, area: number }
	local offers: { Offer } = {}
	for i = 1, n do
		for j = 1, n do
			if not blocked[i][j] and (edge(i, j, -1, 0) or edge(i, j, 0, -1)) then
				local i1, j1, side, area = grow(i, j)
				table.insert(offers, { i = i, j = j, i1 = i1, j1 = j1, side = side, area = area })
			end
		end
	end
	table.sort(offers, function(a: Offer, b: Offer): boolean
		if a.side ~= b.side then
			return a.side > b.side
		end
		return a.area > b.area
	end)
	local covered: { { boolean } } = {}
	for i = 1, n do
		covered[i] = {}
	end
	local rects: { Rect } = {}
	local function take(i: number, j: number, i1: number, j1: number)
		local fresh = false
		for ci = i, i1 do
			for cj = j, j1 do
				if not covered[ci][cj] then
					covered[ci][cj], fresh = true, true
				end
			end
		end
		if not fresh then
			return
		end
		local x0, z0 = -Reach + (i - 1) * cell, -Reach + (j - 1) * cell
		local r: Rect = {
			x = x0 + (i1 - i + 1) * cell / 2,
			z = z0 + (j1 - j + 1) * cell / 2,
			width = (i1 - i + 1) * cell,
			depth = (j1 - j + 1) * cell,
		}
		local f = floorOf[i][j]
		if f ~= 0 then
			r.y = heightOf(f)
		end
		table.insert(rects, r)
	end
	for _, o in offers do
		take(o.i, o.j, o.i1, o.j1)
	end
	-- Anything still left over (inner corners the offers missed) gets its own.
	for j = 1, n do
		for i = 1, n do
			if not blocked[i][j] and not covered[i][j] then
				local i1, j1 = grow(i, j)
				take(i, j, i1, j1)
			end
		end
	end
	return rects
end

Scenery.Zones = {
	PumpkinGraveyard = {
		parts = pumpkinGraveyard,
		roam = Scenery.openGround(pumpkinGraveyard()),
	},
	MurkyBayou = {
		parts = murkyBayou,
		roam = Scenery.openGround(murkyBayou(), { floors = BayouPools }),
		bed = BayouBed,
		water = BayouPools,
		waterDepth = BayouWater,
	},
	AbandonedCarnival = {
		parts = abandonedCarnival,
		roam = Scenery.openGround(abandonedCarnival()),
	},
} :: { [string]: Zone }

-- The portal colour per zone (hub gate, exit and swirl).
function Scenery.Glow(zoneId: string): { number }
	local style = ArchStyles[zoneId]
	return if style then style.glow else LockedStyle.glow
end

return Scenery
