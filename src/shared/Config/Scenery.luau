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

-- The Pumpkin Graveyard: dead ground inside an iron fence. A stone archway welcomes hunters
-- off the arrival pad; crooked tombstones fill the west side, a pumpkin patch with a scarecrow
-- the east, a ruined chapel stands at the back left and the groundskeeper's shed with an open
-- grave at the back right. The middle stays open for the monsters.
local function pumpkinGraveyard(): { Part }
	local parts: { Part } = {}
	local roll = dice(1031)
	perimeterFence(parts)

	-- The way in: a cobbled path from the arrival pad and the exit to the archway.
	part(parts, "PathMain", { 8, 0.1, 40 }, { 0, 0.05, -70 }, StoneDark, "Cobblestone")
	part(parts, "PathCross", { 39, 0.1, 6 }, { 4.5, 0.05, -93 }, StoneDark, "Cobblestone")
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		local x = side * 7
		part(parts, `GatePillar{tag}`, { 2, 9, 2 }, { x, 4.5, -70 }, MossStone, "Slate", true)
		part(parts, `GateCap{tag}`, { 2.6, 0.5, 2.6 }, { x, 9.25, -70 }, StoneDark, "Slate", true)
		jackOLantern(parts, `GatePumpkin{tag}`, x, 9.5, -70, 2.2, side > 0)
		Kit.lampPost(parts, `PathLamp{tag}`, side * 6.5, -84)
	end
	part(parts, "GateBar", { 12, 0.6, 0.6 }, { 0, 8.7, -70 }, Iron, "Metal", true)
	local sign = part(
		parts,
		"GateSign",
		{ 10, 1.8, 0.3 },
		{ 0, 7.5, -70.15 },
		{ 196, 170, 120 },
		"WoodPlanks"
	)
	sign.text = "Pumpkin Graveyard"

	-- Tombstones in crooked rows on the west side.
	local n = 0
	for z = -24, 40, 8 do
		for x = -90, -62, 7 do
			n += 1
			local kind = math.floor(roll() * 3)
			local yaw = (roll() - 0.5) * 20
			local tilt = (roll() - 0.5) * 16
			local add = group(parts, { x + (roll() - 0.5) * 2, 0, z }, yaw, tilt)
			local color = if roll() < 0.3 then MossStone else Stone
			if kind == 0 then
				add(`Tomb{n}`, { 2.4, 3.2, 0.6 }, { 0, 1.6, 0 }, color, "Slate", true)
				add(`Tomb{n}Top`, { 1.6, 0.5, 0.6 }, { 0, 3.45, 0 }, color, "Slate")
			elseif kind == 1 then
				add(`Tomb{n}`, { 0.7, 4, 0.6 }, { 0, 2, 0 }, color, "Slate", true)
				add(`Tomb{n}ArmLeft`, { 0.95, 0.7, 0.6 }, { -0.825, 2.9, 0 }, color, "Slate")
				add(`Tomb{n}ArmRight`, { 0.95, 0.7, 0.6 }, { 0.825, 2.9, 0 }, color, "Slate")
			else
				add(`Tomb{n}`, { 2, 2.2, 0.8 }, { 0, 1.1, 0 }, color, "Slate", true)
			end
			add(`Tomb{n}Mound`, { 2.2, 0.3, 3.4 }, { 0, 0.15, 2.2 }, Dirt, "Ground")
		end
	end

	-- The pumpkin patch on the east side: dirt, rows of pumpkins and a scarecrow.
	part(parts, "PatchSoil", { 38, 0.2, 50 }, { 74, 0.1, 13 }, Dirt, "Ground")
	local p = 0
	for row = 0, 5 do
		local x = 58 + row * 6
		part(parts, `PatchRow{row + 1}`, { 1.2, 0.4, 46 }, { x, 0.4, 13 }, { 50, 36, 24 }, "Ground")
		for _, z in { 2, 10, 18, 26, 34 } do
			p += 1
			local size = 1.6 + roll() * 1.6
			local carved = p % 5 == 2
			if carved then
				jackOLantern(parts, `Pumpkin{p}`, x, 0.6, z, size, p % 10 == 2)
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
			part(
				parts,
				`Pumpkin{p}Leaf`,
				{ 1.2, 0.15, 1 },
				{ x + size * 0.55 + 0.6, 0.275, z + 1 },
				Stem,
				"Grass"
			)
		end
	end
	local sx, sz = 73, -6
	part(parts, "ScarecrowPole", { 0.5, 3.5, 0.5 }, { sx, 1.95, sz }, Bark, "Wood", true)
	part(parts, "Scarecrow", { 2.4, 3, 1.2 }, { sx, 5.2, sz }, { 120, 96, 60 }, "Fabric", true)
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		part(
			parts,
			`ScarecrowArm{tag}`,
			{ 2.2, 0.8, 0.8 },
			{ sx + side * 2.3, 6.1, sz },
			{ 90, 60, 80 },
			"Fabric"
		)
		part(
			parts,
			`ScarecrowStraw{tag}`,
			{ 0.6, 0.6, 0.6 },
			{ sx + side * 3.7, 6.1, sz },
			{ 210, 180, 90 },
			"Fabric"
		)
	end
	jackOLantern(parts, "ScarecrowHead", sx, 6.7, sz, 2.2, true, true)
	part(parts, "ScarecrowHatBrim", { 3, 0.2, 3 }, { sx, 8.56, sz }, Black, "Fabric")
	part(parts, "ScarecrowHat", { 1.6, 1.4, 1.6 }, { sx, 9.36, sz }, Black, "Fabric")

	-- The ruined chapel at the back left: broken stone walls, a stub of a bell tower, old
	-- pews knocked askew and an altar with candles.
	local cx, cz = -72, 76
	ruinedWall(parts, "ChapelFront", cx - 12, cx - 3, cz - 14, false, { 9, 7, 8 }, Stone)
	ruinedWall(parts, "ChapelFrontRight", cx + 3, cx + 12, cz - 14, false, { 6, 9, 4 }, Stone)
	ruinedWall(parts, "ChapelBack", cx - 12, cx + 12, cz + 14, false, { 6, 10, 12, 12, 9, 5 }, Stone)
	ruinedWall(parts, "ChapelLeft", cz - 13.2, cz + 13.2, cx - 12.8, true, { 8, 6, 0, 7, 9, 4 }, Stone)
	ruinedWall(parts, "ChapelRight", cz - 13.2, cz + 13.2, cx + 12.8, true, { 3, 7, 8, 0, 5, 8 }, StoneDark)
	part(parts, "ChapelFloor", { 24, 0.2, 26.4 }, { cx, 0.1, cz }, StoneDark, "Slate")
	part(parts, "BellTower", { 6, 18, 6 }, { cx + 12.8 + 3.8, 9, cz - 11.2 }, Stone, "Slate", true)
	part(
		parts,
		"BellTowerCap",
		{ 6.8, 0.6, 6.8 },
		{ cx + 12.8 + 3.8, 18.3, cz - 11.2 },
		StoneDark,
		"Slate",
		true
	)
	part(parts, "BellTowerWindow", { 2, 3, 0.1 }, { cx + 12.8 + 3.8, 14, cz - 14.25 }, Black, "SmoothPlastic")
	part(parts, "Altar", { 6, 3, 2.4 }, { cx, 1.7, cz + 11 }, StoneDark, "Slate", true)
	Kit.candles(parts, "AltarCandles", cx - 1.8, 3.2, cz + 11, true)
	Kit.candles(parts, "AltarCandlesRight", cx + 1.8, 3.2, cz + 11, false)
	for i, at in { { -4, 2, 0 }, { 4, 2, -8 }, { -4, -6, 15 }, { 4, -6, -10 } } do
		local add = group(parts, { cx + at[1], 0.2, cz + at[2] }, at[3], 0)
		add(`Pew{i}Seat`, { 7, 0.4, 1.6 }, { 0, 1.4, 0 }, Plank, "WoodPlanks", true)
		add(`Pew{i}Back`, { 7, 1.6, 0.3 }, { 0, 2.4, 0.65 }, Plank, "WoodPlanks", true)
		add(`Pew{i}LegLeft`, { 0.4, 1.2, 1.4 }, { -3, 0.6, 0 }, Plank, "Wood", true)
		add(`Pew{i}LegRight`, { 0.4, 1.2, 1.4 }, { 3, 0.6, 0 }, Plank, "Wood", true)
	end

	-- The groundskeeper's shed and an open grave, at the back right.
	local hx, hz = 80, 84
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
	local shovel = part(parts, "Shovel", { 0.25, 4.4, 0.25 }, { hx + 7, 2.15, hz - 3 }, Bark, "Wood")
	shovel.rot = { 0, 0, 12 }
	local gx, gz = 66, 74
	part(parts, "GravePit", { 3, 0.06, 6 }, { gx, 0.03, gz }, Black, "SmoothPlastic")
	part(parts, "GraveRimLeft", { 0.6, 0.4, 6 }, { gx - 1.8, 0.2, gz }, Dirt, "Ground")
	part(parts, "GraveRimRight", { 0.6, 0.4, 6 }, { gx + 1.8, 0.2, gz }, Dirt, "Ground")
	part(parts, "GraveDirt", { 3, 1.4, 4.4 }, { gx + 4, 0.7, gz }, Dirt, "Ground", true)
	part(parts, "GraveStone", { 2.6, 3.4, 0.6 }, { gx, 1.7, gz + 3.6 }, Stone, "Slate", true)
	local lid = part(parts, "CoffinLid", { 2.4, 0.3, 5.6 }, { gx - 4.4, 0.15, gz }, Plank, "WoodPlanks")
	lid.rot = { 0, 20, 0 }

	-- Dead trees along the fence, outside the monsters' ground.
	for i, spot in
		{
			{ -100, -45, 30 },
			{ 100, -42, 160 },
			{ -30, 101, 90 },
			{ 34, 100, 260 },
			{ -100, 46, 0 },
			{ 101, 50, 200 },
		}
	do
		Kit.deadTree(parts, `Tree{i}`, spot[1], spot[2], spot[3])
	end
	return parts
end

Scenery.Zones = {
	PumpkinGraveyard = {
		parts = pumpkinGraveyard,
		roam = {
			{ x = 0, z = 20, width = 100, depth = 150 }, -- the open middle
			{ x = 72.5, z = -35, width = 45, depth = 40 }, -- in front of the pumpkin patch
			{ x = 72.5, z = 50, width = 45, depth = 20 }, -- between the patch and the shed
			{ x = -72.5, z = -42.5, width = 45, depth = 25 }, -- in front of the tombstones
		},
	},
} :: { [string]: Zone }

-- The portal colour per zone (hub gate, exit and swirl).
function Scenery.Glow(zoneId: string): { number }
	local style = ArchStyles[zoneId]
	return if style then style.glow else LockedStyle.glow
end

return Scenery
