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
export type Zone = {
	parts: () -> { Part },
	roam: { { x: number, z: number, width: number, depth: number } },
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

-- Where monsters roam in the graveyard: the dirt paths between the blocks of graves.
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
-- groundskeeper's shed with an open grave. Monsters roam the paths.
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

-- Where monsters roam in the bayou: the mud banks round the edge and the boardwalks up the
-- middle and across, between four stretches of swamp water.
local BayouPaths = {
	{ x = 0, z = -51, width = 208, depth = 14 }, -- south bank, just past the dock gate
	{ x = 0, z = 96, width = 208, depth = 16 }, -- north bank
	{ x = -97, z = 22, width = 14, depth = 132 }, -- west bank
	{ x = 97, z = 22, width = 14, depth = 132 }, -- east bank
	{ x = 0, z = 22, width = 10, depth = 132 }, -- the boardwalk up the middle
	{ x = -47.5, z = 21, width = 85, depth = 10 }, -- boardwalk across, west half
	{ x = 47.5, z = 21, width = 85, depth = 10 }, -- boardwalk across, east half
}

local Mud = { 54, 46, 32 }
local Swamp = { 38, 58, 40 }
local Cypress = { 44, 64, 40 }
local CypressDark = { 34, 50, 32 }
local Moss = { 84, 96, 70 }
local Rotten = { 74, 60, 44 }
local Firefly = { 200, 255, 120 }

-- A bald cypress: a flared foot, a tall trunk, a flat crown with grey moss hanging from it,
-- and knees poking up round its foot. The crown and moss are overhead, so walk-through.
local function cypress(parts: { Part }, name: string, x: number, z: number, height: number)
	part(parts, name .. "Foot", { 3.2, 2, 3.2 }, { x, 1, z }, Bark, "Wood", true)
	part(parts, name .. "Flare", { 2.4, 2, 2.4 }, { x, 3, z }, Bark, "Wood", true)
	part(parts, name .. "Trunk", { 1.5, height - 4, 1.5 }, { x, 2 + height / 2, z }, Bark, "Wood", true)
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
		part(parts, `{name}Knee{i}`, { 0.6, 1.2, 0.6 }, { x + spot[1], 0.6, z + spot[2] }, Bark, "Wood")
	end
end

-- The Murky Bayou: a swamp under tall mossy cliffs. From the arrival pad you cross a muddy
-- landing to a dock gate; past it, mud banks run round the edge and boardwalks run up the
-- middle and across, over four stretches of murky water full of cypress trees, reeds and lily
-- pads. Out in the water: a shack on stilts, a sunken bell tower, a rowboat and fireflies.
-- Monsters roam the banks and boardwalks.
local function murkyBayou(): { Part }
	local parts: { Part } = {}
	local roll = dice(2069)
	cliffs(parts, 91, { 48, 58, 46 })

	-- Mud round the edge, water in the four stretches between, boardwalks over the water.
	part(parts, "MudSouth", { 220, 0.1, 66 }, { 0, 0.05, -77 }, Mud, "Ground")
	part(parts, "MudNorth", { 220, 0.1, 22 }, { 0, 0.05, 99 }, Mud, "Ground")
	part(parts, "MudWest", { 20, 0.1, 132 }, { -100, 0.05, 22 }, Mud, "Ground")
	part(parts, "MudEast", { 20, 0.1, 132 }, { 100, 0.05, 22 }, Mud, "Ground")
	local stretches = {
		{ -47.5, -14, 85, 60 },
		{ 47.5, -14, 85, 60 },
		{ -47.5, 57, 85, 62 },
		{ 47.5, 57, 85, 62 },
	}
	for i, w in stretches do
		local water = part(parts, `Water{i}`, { w[3], 0.2, w[4] }, { w[1], 0.1, w[2] }, Swamp, "Glass")
		water.transparency = 0.25
	end
	part(parts, "BoardwalkMiddle", { 10, 0.3, 132 }, { 0, 0.15, 22 }, Plank, "WoodPlanks")
	part(parts, "BoardwalkWest", { 85, 0.3, 10 }, { -47.5, 0.15, 21 }, Plank, "WoodPlanks")
	part(parts, "BoardwalkEast", { 85, 0.3, 10 }, { 47.5, 0.15, 21 }, Plank, "WoodPlanks")
	local post = 0
	for z = -38, 82, 12 do
		if z < 14 or z > 28 then
			for _, side in { -1, 1 } do
				post += 1
				part(
					parts,
					`BoardwalkPost{post}`,
					{ 0.6, 1.6, 0.6 },
					{ side * 5.4, 0.8, z },
					Rotten,
					"Wood",
					true
				)
			end
		end
	end
	for x = 12, 84, 12 do
		for _, side in { -1, 1 } do
			for _, z in { 15.6, 26.4 } do
				post += 1
				part(
					parts,
					`BoardwalkPost{post}`,
					{ 0.6, 1.6, 0.6 },
					{ side * x, 0.8, z },
					Rotten,
					"Wood",
					true
				)
			end
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
			{ 0.8, 5, 0.8 },
			{ hx + spot[1], 2.5, hz + spot[2] },
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
			{ 0.3, 5.6, 0.3 },
			{ hx + side, 2.8, hz - 6.4 },
			Rotten,
			"Wood",
			true
		)
	end
	for r = 1, 5 do
		part(parts, `ShackRung{r}`, { 1.7, 0.2, 0.2 }, { hx, r - 0.1, hz - 6.4 }, Rotten, "Wood")
	end

	-- A bell tower sinking into the north-west water, leaning, its bell still hanging.
	local tx, tz = -58, 58
	take(tx - 10, tx + 10, tz - 10, tz + 10, true)
	take(tx - 16, tx + 16, tz - 16, tz + 16, false)
	local tower = group(parts, { tx, 0, tz }, 20, 10)
	tower("Tower", { 7, 14, 7 }, { 0, 7, 0 }, MossStone, "Slate", true)
	tower("TowerSlit", { 1.2, 3, 0.1 }, { 0, 9, -3.55 }, Black, "SmoothPlastic")
	for i, spot in { { -2.8, -2.8 }, { 2.8, -2.8 }, { -2.8, 2.8 }, { 2.8, 2.8 } } do
		tower(`TowerPost{i}`, { 1.4, 6, 1.4 }, { spot[1], 17, spot[2] }, Stone, "Slate", true)
	end
	tower("TowerCap", { 8, 1, 8 }, { 0, 20.5, 0 }, StoneDark, "Slate", true)
	tower("TowerRoof", { 5, 1.5, 5 }, { 0, 21.75, 0 }, StoneDark, "Slate", true)
	tower("TowerSpire", { 3, 1.5, 3 }, { 0, 23.25, 0 }, StoneDark, "Slate", true)
	tower("Bell", { 2.6, 2.4, 2.6 }, { 0, 16.6, 0 }, { 150, 110, 50 }, "Metal")
	tower("BellLip", { 3.2, 0.5, 3.2 }, { 0, 15.15, 0 }, { 130, 94, 42 }, "Metal")
	tower("BellHanger", { 0.4, 2.2, 0.4 }, { 0, 18.9, 0 }, Iron, "Metal")
	part(parts, "TowerRubbleA", { 2, 1, 1.5 }, { tx + 6, 0.5, tz - 6 }, MossStone, "Slate", true)
	part(parts, "TowerRubbleB", { 1.4, 0.8, 1.2 }, { tx - 6.5, 0.4, tz + 5 }, Stone, "Slate", true)

	-- A rowboat half sunk in the south-west water.
	take(-58, -42, -28, -12, true)
	take(-64, -36, -34, -6, false)
	local boat = group(parts, { -50, 0, -20 }, 25, 0)
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
							{ d, 0.05, d },
							{ px, 0.225, pz },
							{ 60, 96, 50 },
							"Grass"
						)
						pad.rot = { 0, roll() * 90, 0 }
					elseif pick < 0.5 then
						reeds += 1
						local h = 3 + roll() * 2
						for i, o in { { -0.4, 0 }, { 0.3, 0.3 }, { 0.1, -0.45 } } do
							local stalk = h - (i - 1) * 0.6
							part(
								parts,
								`Reeds{reeds}Stalk{i}`,
								{ 0.2, stalk, 0.2 },
								{ px + o[1], stalk / 2, pz + o[2] },
								{ 96, 110, 60 },
								"Grass"
							)
						end
						part(
							parts,
							`Reeds{reeds}Head`,
							{ 0.35, 0.8, 0.35 },
							{ px - 0.4, h + 0.4, pz },
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
		local y = 6 + roll() * 2.5
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

Scenery.Zones = {
	PumpkinGraveyard = {
		parts = pumpkinGraveyard,
		roam = GraveyardPaths,
	},
	MurkyBayou = {
		parts = murkyBayou,
		roam = BayouPaths,
	},
} :: { [string]: Zone }

-- The portal colour per zone (hub gate, exit and swirl).
function Scenery.Glow(zoneId: string): { number }
	local style = ArchStyles[zoneId]
	return if style then style.glow else LockedStyle.glow
end

return Scenery
