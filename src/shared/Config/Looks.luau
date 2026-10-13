--!strict
-- What each monster looks like: a little stud-style model built from blocks (see
-- server/MonsterModel.luau, which builds it, and client/Controllers/RoamController.luau,
-- which swings the limbs). A monster without a look here is still drawn as a glowing orb.
--
-- Every number is in studs for a Normal-size monster; other sizes are scaled. The monster
-- faces -Z (forward), +Y is up and its centre is 0,0,0. Walkers ("walk") have their feet at
-- y = -2 so they stand on the floor; floaters ("float") bob in the air.
--
-- A part with a `joint` swings back and forth around its `pivot` (a point given relative to
-- the part's own centre, e.g. the top of a leg is 0, half its height, 0):
--   axis   "X" swings forward/back (legs, arms), "Y" turns sideways (tails), "Z" flaps (wings)
--   amp    how far it swings, in degrees (use a negative amp to mirror the other side)
--   speed  swings per second while it walks; standing still it swings slower and smaller
--   phase  0..1, where in the swing it starts (0.5 = opposite of 0, for left/right legs)
--   spin   true to turn round and round instead (speed = turns per second; amp is ignored)
--   slide  true to move back and forth along the axis instead (amp = how far, in studs)

export type Joint = {
	axis: "X" | "Y" | "Z",
	amp: number,
	speed: number,
	phase: number?,
	pivot: { number }?,
	spin: boolean?, -- turns round and round (speed = turns per second) instead of swinging
	slide: boolean?, -- moves up and down its axis (amp in studs) instead of swinging
}

export type Piece = {
	name: string,
	size: { number },
	at: { number },
	color: { number },
	shape: ("Block" | "Ball" | "Cylinder")?,
	glow: boolean?, -- neon, for eyes and other bits that shine in the dark
	rot: { number }?, -- tilts the part, in degrees around X, Y, Z (a horse's neck, an arm held out)
	joint: Joint?,
}

export type Look = {
	gait: "walk" | "float",
	top: number, -- highest point, the name label floats above it
	grow: number?, -- drawn this many times bigger than other monsters of its size (event monsters)
	seeThrough: number?, -- 0..1: how see-through its non-glowing parts are (ghosts)
	wet: boolean?, -- smooth and shiny, like wet mud or slime
	pieces: { Piece },
}

-- Shared colours.
local Black = { 27, 27, 32 }
local Bone = { 235, 228, 205 }
local Moss = { 92, 140, 60 }
local White = { 245, 245, 255 }

local Looks: { [string]: Look } = {}

-- Shorthands for the bigger looks below: a fixed block, and a block that swings.
local function block(name: string, size: { number }, at: { number }, color: { number }, glow: boolean?): Piece
	return { name = name, size = size, at = at, color = color, glow = glow }
end

local function limb(
	name: string,
	size: { number },
	at: { number },
	color: { number },
	axis: "X" | "Y" | "Z",
	amp: number,
	speed: number,
	phase: number,
	pivot: { number },
	glow: boolean?
): Piece
	return {
		name = name,
		size = size,
		at = at,
		color = color,
		glow = glow,
		joint = { axis = axis, amp = amp, speed = speed, phase = phase, pivot = pivot },
	}
end

-- Makes a limb turn round and round its pivot instead of swinging (a carousel, orbiting bits).
local function spin(piece: Piece): Piece
	local joint = piece.joint :: Joint
	joint.spin = true
	return piece
end

-- Makes a limb slide up and down (or along its axis) instead of swinging; amp is in studs.
local function slide(piece: Piece): Piece
	local joint = piece.joint :: Joint
	joint.slide = true
	return piece
end

-- Tilts a part (degrees around X, Y, Z). Around X, a negative angle leans its top forward.
local function tilt(piece: Piece, x: number, y: number, z: number): Piece
	piece.rot = { x, y, z }
	return piece
end

-- Zone 1, Common: a shy little ghost blob that waves its stubby arms.
Looks.Gloomlet = {
	gait = "float",
	top = 2.2,
	pieces = {
		{ name = "Torso", size = { 2.4, 2.2, 2 }, at = { 0, 0.1, 0 }, color = { 120, 110, 160 } },
		{ name = "Cap", size = { 1.8, 0.6, 1.6 }, at = { 0, 1.5, 0 }, color = { 140, 130, 185 } },
		{ name = "LeftEye", size = { 0.5, 0.6, 0.2 }, at = { -0.5, 0.5, -1.05 }, color = White, glow = true },
		{ name = "RightEye", size = { 0.5, 0.6, 0.2 }, at = { 0.5, 0.5, -1.05 }, color = White, glow = true },
		{ name = "Mouth", size = { 0.8, 0.2, 0.1 }, at = { 0, -0.25, -1.03 }, color = Black },
		{
			name = "LeftArm",
			size = { 0.5, 1, 0.5 },
			at = { -1.45, 0, 0 },
			color = { 120, 110, 160 },
			joint = { axis = "Z", amp = -35, speed = 1.5, pivot = { 0.25, 0.4, 0 } },
		},
		{
			name = "RightArm",
			size = { 0.5, 1, 0.5 },
			at = { 1.45, 0, 0 },
			color = { 120, 110, 160 },
			joint = { axis = "Z", amp = 35, speed = 1.5, phase = 0.5, pivot = { -0.25, 0.4, 0 } },
		},
		{
			name = "LeftWisp",
			size = { 0.6, 0.8, 0.6 },
			at = { -0.6, -1.35, 0 },
			color = { 100, 92, 140 },
			joint = { axis = "X", amp = 20, speed = 1.2, pivot = { 0, 0.4, 0 } },
		},
		{
			name = "MiddleWisp",
			size = { 0.6, 0.9, 0.6 },
			at = { 0, -1.4, 0 },
			color = { 100, 92, 140 },
			joint = { axis = "X", amp = 20, speed = 1.2, phase = 0.33, pivot = { 0, 0.45, 0 } },
		},
		{
			name = "RightWisp",
			size = { 0.6, 0.8, 0.6 },
			at = { 0.6, -1.35, 0 },
			color = { 100, 92, 140 },
			joint = { axis = "X", amp = 20, speed = 1.2, phase = 0.66, pivot = { 0, 0.4, 0 } },
		},
	},
}

-- Zone 1, Common: a scruffy crow that hops along flapping its wings.
Looks.Skittercrow = {
	gait = "walk",
	top = 1.5,
	pieces = {
		{ name = "Torso", size = { 1.6, 1.4, 2.2 }, at = { 0, -0.2, 0 }, color = { 40, 40, 52 } },
		{ name = "Head", size = { 1.1, 1.1, 1.1 }, at = { 0, 0.9, -0.9 }, color = { 40, 40, 52 } },
		{ name = "Beak", size = { 0.4, 0.3, 0.7 }, at = { 0, 0.8, -1.7 }, color = { 245, 180, 40 } },
		{
			name = "LeftEye",
			size = { 0.25, 0.25, 0.1 },
			at = { -0.3, 1.1, -1.47 },
			color = { 255, 60, 60 },
			glow = true,
		},
		{
			name = "RightEye",
			size = { 0.25, 0.25, 0.1 },
			at = { 0.3, 1.1, -1.47 },
			color = { 255, 60, 60 },
			glow = true,
		},
		{
			name = "LeftWing",
			size = { 0.2, 1, 1.8 },
			at = { -0.9, 0, 0.1 },
			color = { 25, 25, 35 },
			joint = { axis = "Z", amp = -40, speed = 3, pivot = { 0.1, 0.5, 0 } },
		},
		{
			name = "RightWing",
			size = { 0.2, 1, 1.8 },
			at = { 0.9, 0, 0.1 },
			color = { 25, 25, 35 },
			joint = { axis = "Z", amp = 40, speed = 3, pivot = { -0.1, 0.5, 0 } },
		},
		{
			name = "LeftLeg",
			size = { 0.25, 1.1, 0.25 },
			at = { -0.4, -1.45, 0 },
			color = { 245, 180, 40 },
			joint = { axis = "X", amp = 30, speed = 2.5, pivot = { 0, 0.55, 0 } },
		},
		{
			name = "RightLeg",
			size = { 0.25, 1.1, 0.25 },
			at = { 0.4, -1.45, 0 },
			color = { 245, 180, 40 },
			joint = { axis = "X", amp = 30, speed = 2.5, phase = 0.5, pivot = { 0, 0.55, 0 } },
		},
		{
			name = "Tail",
			size = { 0.8, 0.2, 0.9 },
			at = { 0, 0, 1.5 },
			color = { 25, 25, 35 },
			joint = { axis = "X", amp = 15, speed = 2, pivot = { 0, 0, -0.45 } },
		},
	},
}

-- Zone 1, Uncommon: a bony skeleton with moss growing on it, swinging its arms as it shambles
-- and chattering its jaw. Thin bones with gaps between the ribs so it reads as a skeleton.
local Hole = { 20, 18, 16 }
Looks.Mossbones = {
	gait = "walk",
	top = 2.1,
	pieces = {
		{ name = "Skull", size = { 1.2, 1, 1.1 }, at = { 0, 1.55, 0 }, color = Bone },
		{ name = "LeftSocket", size = { 0.38, 0.38, 0.1 }, at = { -0.27, 1.6, -0.56 }, color = Hole },
		{ name = "RightSocket", size = { 0.38, 0.38, 0.1 }, at = { 0.27, 1.6, -0.56 }, color = Hole },
		{
			name = "LeftEye",
			size = { 0.14, 0.14, 0.1 },
			at = { -0.27, 1.6, -0.6 },
			color = { 120, 255, 120 },
			glow = true,
		},
		{
			name = "RightEye",
			size = { 0.14, 0.14, 0.1 },
			at = { 0.27, 1.6, -0.6 },
			color = { 120, 255, 120 },
			glow = true,
		},
		{ name = "NoseHole", size = { 0.16, 0.2, 0.1 }, at = { 0, 1.27, -0.56 }, color = Hole },
		{ name = "Teeth", size = { 0.7, 0.12, 0.1 }, at = { 0, 1.1, -0.56 }, color = { 250, 248, 235 } },
		{ name = "SkullMoss", size = { 0.7, 0.15, 0.6 }, at = { 0.2, 2.12, 0.1 }, color = Moss },
		{
			name = "Jaw",
			size = { 0.9, 0.25, 0.9 },
			at = { 0, 0.92, -0.05 },
			color = Bone,
			joint = { axis = "X", amp = 12, speed = 1.5, pivot = { 0, 0, 0.45 } },
		},
		{ name = "Neck", size = { 0.3, 0.3, 0.3 }, at = { 0, 0.65, 0.1 }, color = Bone },
		{ name = "Collarbone", size = { 1.7, 0.25, 0.3 }, at = { 0, 0.4, 0 }, color = Bone },
		{ name = "ShoulderMoss", size = { 0.6, 0.18, 0.4 }, at = { -0.55, 0.6, 0 }, color = Moss },
		{ name = "Spine", size = { 0.3, 1.5, 0.3 }, at = { 0, -0.4, 0.25 }, color = Bone },
		{ name = "Sternum", size = { 0.2, 0.8, 0.1 }, at = { 0, -0.1, -0.37 }, color = Bone },
		{ name = "TopRib", size = { 1.3, 0.15, 0.65 }, at = { 0, 0.12, -0.02 }, color = Bone },
		{ name = "MiddleRib", size = { 1.2, 0.15, 0.6 }, at = { 0, -0.18, -0.02 }, color = Bone },
		{ name = "BottomRib", size = { 1, 0.15, 0.55 }, at = { 0, -0.48, -0.02 }, color = Bone },
		{ name = "RibMoss", size = { 0.45, 0.17, 0.66 }, at = { 0.35, -0.18, -0.02 }, color = Moss },
		{ name = "Pelvis", size = { 1.1, 0.35, 0.5 }, at = { 0, -1.05, 0.05 }, color = Bone },
		{
			name = "LeftArm",
			size = { 0.25, 1.5, 0.25 },
			at = { -0.95, -0.35, 0 },
			color = Bone,
			joint = { axis = "X", amp = 35, speed = 1.6, phase = 0.5, pivot = { 0, 0.7, 0 } },
		},
		{
			name = "RightArm",
			size = { 0.25, 1.5, 0.25 },
			at = { 0.95, -0.35, 0 },
			color = Bone,
			joint = { axis = "X", amp = 35, speed = 1.6, pivot = { 0, 0.7, 0 } },
		},
		{
			name = "LeftLeg",
			size = { 0.3, 0.85, 0.3 },
			at = { -0.3, -1.575, 0.05 },
			color = Bone,
			joint = { axis = "X", amp = 30, speed = 1.6, pivot = { 0, 0.425, 0 } },
		},
		{
			name = "RightLeg",
			size = { 0.3, 0.85, 0.3 },
			at = { 0.3, -1.575, 0.05 },
			color = Bone,
			joint = { axis = "X", amp = 30, speed = 1.6, phase = 0.5, pivot = { 0, 0.425, 0 } },
		},
	},
}

-- Zone 1, Rare: a ghostly graveyard puppy that trots along wagging its tail.
local Pup = { 190, 215, 230 }
Looks.Gravepup = {
	gait = "walk",
	top = 1.4,
	pieces = {
		{ name = "Torso", size = { 1.4, 1.2, 2.4 }, at = { 0, -0.4, 0.1 }, color = Pup },
		{ name = "Head", size = { 1.2, 1.1, 1.1 }, at = { 0, 0.45, -1.3 }, color = Pup },
		{ name = "Snout", size = { 0.7, 0.5, 0.6 }, at = { 0, 0.2, -2.1 }, color = { 215, 230, 240 } },
		{ name = "Nose", size = { 0.3, 0.2, 0.15 }, at = { 0, 0.4, -2.45 }, color = Black },
		{ name = "Collar", size = { 1.3, 0.25, 1.2 }, at = { 0, -0.15, -1.3 }, color = { 200, 40, 50 } },
		{
			name = "LeftEye",
			size = { 0.25, 0.25, 0.1 },
			at = { -0.3, 0.7, -1.87 },
			color = { 80, 230, 255 },
			glow = true,
		},
		{
			name = "RightEye",
			size = { 0.25, 0.25, 0.1 },
			at = { 0.3, 0.7, -1.87 },
			color = { 80, 230, 255 },
			glow = true,
		},
		{
			name = "LeftEar",
			size = { 0.3, 0.5, 0.3 },
			at = { -0.4, 1.2, -1.2 },
			color = { 150, 175, 195 },
			joint = { axis = "Z", amp = -15, speed = 2, pivot = { 0, -0.25, 0 } },
		},
		{
			name = "RightEar",
			size = { 0.3, 0.5, 0.3 },
			at = { 0.4, 1.2, -1.2 },
			color = { 150, 175, 195 },
			joint = { axis = "Z", amp = 15, speed = 2, phase = 0.5, pivot = { 0, -0.25, 0 } },
		},
		-- Diagonal pairs step together, like a real trot.
		{
			name = "FrontLeftLeg",
			size = { 0.4, 1, 0.4 },
			at = { -0.45, -1.5, -0.75 },
			color = Pup,
			joint = { axis = "X", amp = 30, speed = 2.5, pivot = { 0, 0.5, 0 } },
		},
		{
			name = "FrontRightLeg",
			size = { 0.4, 1, 0.4 },
			at = { 0.45, -1.5, -0.75 },
			color = Pup,
			joint = { axis = "X", amp = 30, speed = 2.5, phase = 0.5, pivot = { 0, 0.5, 0 } },
		},
		{
			name = "BackLeftLeg",
			size = { 0.4, 1, 0.4 },
			at = { -0.45, -1.5, 0.95 },
			color = Pup,
			joint = { axis = "X", amp = 30, speed = 2.5, phase = 0.5, pivot = { 0, 0.5, 0 } },
		},
		{
			name = "BackRightLeg",
			size = { 0.4, 1, 0.4 },
			at = { 0.45, -1.5, 0.95 },
			color = Pup,
			joint = { axis = "X", amp = 30, speed = 2.5, pivot = { 0, 0.5, 0 } },
		},
		{
			name = "Tail",
			size = { 0.25, 0.25, 1 },
			at = { 0, 0, 1.75 },
			color = Pup,
			joint = { axis = "Y", amp = 35, speed = 4, pivot = { 0, 0, -0.5 } },
		},
	},
}

-- Zone 1, Uncommon: a jack-o'-lantern with a ghostly flame on top and two leaf arms.
local Pumpkin = { 235, 120, 30 }
local PumpkinDark = { 200, 95, 20 }
local Leaf = { 70, 130, 50 }
local Candle = { 255, 220, 90 }
Looks.WispJack = {
	gait = "float",
	top = 2,
	pieces = {
		block("Pumpkin", { 2, 1.7, 2 }, { 0, 0, 0 }, Pumpkin),
		block("LeftRib", { 0.3, 1.75, 2.05 }, { -0.55, 0, 0 }, PumpkinDark),
		block("RightRib", { 0.3, 1.75, 2.05 }, { 0.55, 0, 0 }, PumpkinDark),
		block("Stem", { 0.3, 0.5, 0.3 }, { 0, 1.1, 0 }, Leaf),
		block("LeftEye", { 0.4, 0.35, 0.1 }, { -0.45, 0.25, -1.05 }, Candle, true),
		block("RightEye", { 0.4, 0.35, 0.1 }, { 0.45, 0.25, -1.05 }, Candle, true),
		block("Grin", { 1.1, 0.25, 0.1 }, { 0, -0.35, -1.05 }, Candle, true),
		limb(
			"Flame",
			{ 0.5, 0.7, 0.5 },
			{ 0, 1.6, 0 },
			{ 120, 255, 200 },
			"Z",
			20,
			3,
			0,
			{ 0, -0.35, 0 },
			true
		),
		limb("LeftLeaf", { 0.8, 0.15, 0.4 }, { -1.4, -0.2, 0 }, Leaf, "Z", 30, 2, 0, { 0.4, 0, 0 }),
		limb("RightLeaf", { 0.8, 0.15, 0.4 }, { 1.4, -0.2, 0 }, Leaf, "Z", -30, 2, 0, { -0.4, 0, 0 }),
	},
}

-- Zone 1, Epic: a headstone that got up and walks, grinning. Arched top with a cross, an
-- engraved plate, cracks, moss and ivy, and an epitaph on the back too.
local Stone = { 130, 128, 140 }
local StoneDark = { 95, 92, 105 }
local Engraving = { 60, 58, 68 }
local Ivy = { 60, 120, 50 }
local Purple = { 200, 110, 255 }
Looks.Tombgrin = {
	gait = "walk",
	top = 2.6,
	pieces = {
		block("Slab", { 2, 2.2, 0.7 }, { 0, 0, 0 }, Stone),
		block("ArchLow", { 1.6, 0.3, 0.7 }, { 0, 1.25, 0 }, Stone),
		block("ArchHigh", { 1, 0.3, 0.7 }, { 0, 1.55, 0 }, Stone),
		block("CrossPost", { 0.25, 0.9, 0.25 }, { 0, 2.15, 0 }, StoneDark),
		block("CrossBar", { 0.75, 0.2, 0.25 }, { 0, 2.3, 0 }, StoneDark),
		block("Plinth", { 2.4, 0.4, 1.1 }, { 0, -1.3, 0 }, StoneDark),
		block("FrontGrass", { 0.6, 0.15, 0.2 }, { -0.7, -1.05, -0.45 }, Moss),
		block("BackGrass", { 0.7, 0.15, 0.2 }, { 0.6, -1.05, 0.45 }, Moss),
		-- Front: face, plate with an epitaph, a crack and a patch of moss.
		block("LeftEye", { 0.3, 0.3, 0.1 }, { -0.4, 0.6, -0.38 }, Purple, true),
		block("RightEye", { 0.3, 0.3, 0.1 }, { 0.4, 0.6, -0.38 }, Purple, true),
		block("Grin", { 1.1, 0.2, 0.1 }, { 0, 0.1, -0.38 }, Purple, true),
		block("Plate", { 1.3, 0.6, 0.08 }, { 0, -0.55, -0.38 }, Engraving),
		block("PlateLineTop", { 0.9, 0.07, 0.05 }, { 0, -0.45, -0.43 }, Stone),
		block("PlateLineBottom", { 0.7, 0.07, 0.05 }, { 0, -0.65, -0.43 }, Stone),
		block("FrontCrack", { 0.1, 0.7, 0.05 }, { 0.7, 0.75, -0.37 }, Engraving),
		block("FrontMoss", { 0.7, 0.2, 0.75 }, { -0.55, 1.1, 0 }, Moss),
		-- Back: epitaph lines, a long crack and ivy growing up the side.
		block("BackLine1", { 1.1, 0.07, 0.05 }, { 0, 0.5, 0.37 }, Engraving),
		block("BackLine2", { 1.1, 0.07, 0.05 }, { 0, 0.3, 0.37 }, Engraving),
		block("BackLine3", { 0.8, 0.07, 0.05 }, { 0, 0.1, 0.37 }, Engraving),
		block("BackCrack", { 0.1, 1.1, 0.05 }, { -0.5, -0.35, 0.37 }, Engraving),
		block("BackMoss", { 1, 0.35, 0.08 }, { 0.3, 0.95, 0.37 }, Moss),
		block("IvyStem", { 0.1, 1.7, 0.1 }, { 0.8, 0.05, 0.4 }, Ivy),
		block("IvyLeafTop", { 0.3, 0.15, 0.1 }, { 0.7, 0.55, 0.42 }, Ivy),
		block("IvyLeafBottom", { 0.3, 0.15, 0.1 }, { 0.9, -0.3, 0.42 }, Ivy),
		block("SideIvy", { 0.1, 1, 0.3 }, { 1.03, -0.3, 0.1 }, Ivy),
		limb("LeftArm", { 0.4, 1, 0.4 }, { -1.2, -0.1, 0 }, StoneDark, "X", 30, 1.4, 0.5, { 0, 0.4, 0 }),
		limb("RightArm", { 0.4, 1, 0.4 }, { 1.2, -0.1, 0 }, StoneDark, "X", 30, 1.4, 0, { 0, 0.4, 0 }),
		limb("LeftLeg", { 0.5, 0.5, 0.5 }, { -0.5, -1.75, 0 }, StoneDark, "X", 25, 1.4, 0, { 0, 0.25, 0 }),
		limb("RightLeg", { 0.5, 0.5, 0.5 }, { 0.5, -1.75, 0 }, StoneDark, "X", 25, 1.4, 0.5, { 0, 0.25, 0 }),
	},
}

-- Zone 1, Legendary: the old graveyard keeper. A gaunt grey face with sunken red eyes, a
-- stitched grin and a scar; a lantern in one hand and a shovel in the other. Hands, lantern,
-- shovel and boots share their arm's or leg's pivot, so they swing along with it.
local Coat = { 50, 60, 50 }
local Trousers = { 55, 45, 40 }
local Corpse = { 165, 175, 160 }
local Wood = { 120, 80, 45 }
local Iron = { 45, 45, 50 }
local Blood = { 140, 15, 20 }
local RedEye = { 255, 40, 40 }
Looks.TheGroundskeeper = {
	gait = "walk",
	top = 2,
	pieces = {
		block("Torso", { 1.4, 1.4, 0.8 }, { 0, -0.3, 0 }, Coat),
		block("CoatTail", { 1.5, 0.4, 0.9 }, { 0, -0.9, 0 }, Coat),
		block("Shirt", { 0.4, 0.7, 0.05 }, { 0, 0.05, -0.42 }, { 150, 140, 120 }),
		block("TopButton", { 0.12, 0.12, 0.05 }, { 0, 0.15, -0.46 }, Iron),
		block("LowButton", { 0.12, 0.12, 0.05 }, { 0, -0.15, -0.46 }, Iron),
		block("Belt", { 1.45, 0.15, 0.85 }, { 0, -0.6, 0 }, Iron),
		block("Buckle", { 0.25, 0.2, 0.05 }, { 0, -0.6, -0.45 }, { 180, 160, 90 }),
		block("Patch", { 0.35, 0.35, 0.05 }, { 0.45, -0.2, -0.42 }, { 90, 70, 50 }),
		block("Head", { 0.9, 0.9, 0.9 }, { 0, 0.85, -0.1 }, Corpse),
		block("Nose", { 0.15, 0.25, 0.15 }, { 0, 0.85, -0.62 }, Corpse),
		block("LeftSocket", { 0.25, 0.22, 0.05 }, { -0.2, 1, -0.57 }, Black),
		block("RightSocket", { 0.25, 0.22, 0.05 }, { 0.2, 1, -0.57 }, Black),
		block("LeftEye", { 0.1, 0.1, 0.05 }, { -0.2, 1, -0.6 }, RedEye, true),
		block("RightEye", { 0.1, 0.1, 0.05 }, { 0.2, 1, -0.6 }, RedEye, true),
		block("Mouth", { 0.55, 0.15, 0.05 }, { 0, 0.62, -0.57 }, Black),
		block("ToothLeft", { 0.08, 0.1, 0.05 }, { -0.15, 0.66, -0.6 }, Bone),
		block("ToothMiddle", { 0.08, 0.1, 0.05 }, { 0.02, 0.66, -0.6 }, Bone),
		block("ToothRight", { 0.08, 0.1, 0.05 }, { 0.18, 0.66, -0.6 }, Bone),
		block("Scar", { 0.06, 0.4, 0.05 }, { 0.32, 0.85, -0.57 }, Blood),
		block("LeftHair", { 0.15, 0.3, 0.5 }, { -0.5, 1.05, 0 }, { 170, 170, 170 }),
		block("RightHair", { 0.15, 0.3, 0.5 }, { 0.5, 1.05, 0 }, { 170, 170, 170 }),
		block("HatBrim", { 1.5, 0.12, 1.5 }, { 0, 1.35, -0.1 }, Trousers),
		block("HatTop", { 0.9, 0.55, 0.9 }, { 0, 1.68, -0.1 }, Trousers),
		block("HatBand", { 0.95, 0.15, 0.95 }, { 0, 1.48, -0.1 }, Blood),
		-- Right side: arm, hand and lantern.
		limb("RightArm", { 0.35, 1.1, 0.35 }, { 0.9, -0.3, 0 }, Coat, "X", 30, 1.4, 0, { 0, 0.5, 0 }),
		limb("RightHand", { 0.35, 0.3, 0.35 }, { 0.9, -1, 0 }, Corpse, "X", 30, 1.4, 0, { 0, 1.2, 0 }),
		limb("LanternTop", { 0.5, 0.1, 0.5 }, { 0.9, -1.2, -0.05 }, Iron, "X", 30, 1.4, 0, { 0, 1.4, 0.05 }),
		limb(
			"Lantern",
			{ 0.4, 0.45, 0.4 },
			{ 0.9, -1.475, -0.05 },
			Candle,
			"X",
			30,
			1.4,
			0,
			{ 0, 1.675, 0.05 },
			true
		),
		limb(
			"LanternBase",
			{ 0.5, 0.1, 0.5 },
			{ 0.9, -1.75, -0.05 },
			Iron,
			"X",
			30,
			1.4,
			0,
			{ 0, 1.95, 0.05 }
		),
		-- Left side: arm, hand and shovel.
		limb("LeftArm", { 0.35, 1.1, 0.35 }, { -0.9, -0.3, 0 }, Coat, "X", 30, 1.4, 0.5, { 0, 0.5, 0 }),
		limb("LeftHand", { 0.35, 0.3, 0.35 }, { -0.9, -1, 0 }, Corpse, "X", 30, 1.4, 0.5, { 0, 1.2, 0 }),
		limb("Shovel", { 0.15, 2, 0.15 }, { -0.9, -0.6, -0.25 }, Wood, "X", 30, 1.4, 0.5, { 0, 0.8, 0.25 }),
		limb(
			"ShovelBlade",
			{ 0.5, 0.5, 0.1 },
			{ -0.9, -1.7, -0.25 },
			Stone,
			"X",
			30,
			1.4,
			0.5,
			{ 0, 1.9, 0.25 }
		),
		-- Legs with boots.
		limb("LeftLeg", { 0.45, 0.8, 0.45 }, { -0.3, -1.45, 0 }, Trousers, "X", 28, 1.4, 0, { 0, 0.4, 0 }),
		limb(
			"LeftBoot",
			{ 0.5, 0.25, 0.6 },
			{ -0.3, -1.875, -0.05 },
			Iron,
			"X",
			28,
			1.4,
			0,
			{ 0, 0.825, 0.05 }
		),
		limb("RightLeg", { 0.45, 0.8, 0.45 }, { 0.3, -1.45, 0 }, Trousers, "X", 28, 1.4, 0.5, { 0, 0.4, 0 }),
		limb(
			"RightBoot",
			{ 0.5, 0.25, 0.6 },
			{ 0.3, -1.875, -0.05 },
			Iron,
			"X",
			28,
			1.4,
			0.5,
			{ 0, 0.825, 0.05 }
		),
	},
}

-- Zone 1, Mythic: a headless rider on a black horse, holding his own carved pumpkin head out in
-- front of him. The horse has a sloped neck, a long head, ears, a dark mane, a saddle and hooves.
local Horse = { 52, 46, 56 }
local HorseDark = { 28, 25, 32 }
local Hoof = { 70, 65, 60 }
local Leather = { 90, 55, 30 }
local Cloak = { 40, 30, 50 }
local Gold = { 255, 210, 80 }
Looks.TheHeadlessRider = {
	gait = "walk",
	top = 2.2,
	pieces = {
		-- The horse.
		block("HorseBody", { 1.4, 1.2, 2.8 }, { 0, -0.2, 0.2 }, Horse),
		block("HorseChest", { 1.3, 1, 0.4 }, { 0, -0.1, -1.3 }, Horse),
		tilt(block("HorseNeck", { 0.7, 1.4, 0.8 }, { 0, 0.65, -1.45 }, Horse), -30, 0, 0),
		tilt(block("Mane", { 0.25, 1.4, 0.3 }, { 0, 0.85, -1.1 }, HorseDark), -30, 0, 0),
		tilt(block("HorseHead", { 0.6, 0.6, 1.1 }, { 0, 1.25, -2.15 }, Horse), -25, 0, 0),
		tilt(block("Muzzle", { 0.55, 0.45, 0.35 }, { 0, 1.0, -2.6 }, HorseDark), -25, 0, 0),
		block("LeftEar", { 0.15, 0.35, 0.15 }, { -0.2, 1.65, -1.9 }, Horse),
		block("RightEar", { 0.15, 0.35, 0.15 }, { 0.2, 1.65, -1.9 }, Horse),
		block("HorseLeftEye", { 0.06, 0.12, 0.15 }, { -0.31, 1.35, -2.15 }, { 255, 60, 60 }, true),
		block("HorseRightEye", { 0.06, 0.12, 0.15 }, { 0.31, 1.35, -2.15 }, { 255, 60, 60 }, true),
		block("Blanket", { 1.5, 0.1, 1.2 }, { 0, 0.42, 0.1 }, { 120, 25, 35 }),
		block("Saddle", { 1.2, 0.2, 0.9 }, { 0, 0.55, 0.1 }, Leather),
		limb("HorseTail", { 0.3, 1.1, 0.3 }, { 0, -0.2, 1.7 }, HorseDark, "X", 20, 2, 0, { 0, 0.55, 0 }),
		limb("FrontLeftLeg", { 0.35, 1, 0.35 }, { -0.45, -1.3, -0.9 }, Horse, "X", 32, 2.2, 0, { 0, 0.5, 0 }),
		limb(
			"FrontLeftHoof",
			{ 0.42, 0.2, 0.42 },
			{ -0.45, -1.9, -0.9 },
			Hoof,
			"X",
			32,
			2.2,
			0,
			{ 0, 1.1, 0 }
		),
		limb(
			"FrontRightLeg",
			{ 0.35, 1, 0.35 },
			{ 0.45, -1.3, -0.9 },
			Horse,
			"X",
			32,
			2.2,
			0.5,
			{ 0, 0.5, 0 }
		),
		limb(
			"FrontRightHoof",
			{ 0.42, 0.2, 0.42 },
			{ 0.45, -1.9, -0.9 },
			Hoof,
			"X",
			32,
			2.2,
			0.5,
			{ 0, 1.1, 0 }
		),
		limb("BackLeftLeg", { 0.35, 1, 0.35 }, { -0.45, -1.3, 1.2 }, Horse, "X", 32, 2.2, 0.5, { 0, 0.5, 0 }),
		limb(
			"BackLeftHoof",
			{ 0.42, 0.2, 0.42 },
			{ -0.45, -1.9, 1.2 },
			Hoof,
			"X",
			32,
			2.2,
			0.5,
			{ 0, 1.1, 0 }
		),
		limb("BackRightLeg", { 0.35, 1, 0.35 }, { 0.45, -1.3, 1.2 }, Horse, "X", 32, 2.2, 0, { 0, 0.5, 0 }),
		limb("BackRightHoof", { 0.42, 0.2, 0.42 }, { 0.45, -1.9, 1.2 }, Hoof, "X", 32, 2.2, 0, { 0, 1.1, 0 }),
		-- The rider: no head, just a bloody stump above a tall torn collar.
		block("LeftThigh", { 0.35, 0.35, 0.8 }, { -0.75, 0.6, -0.1 }, Cloak),
		block("LeftShin", { 0.3, 0.8, 0.3 }, { -0.85, 0.15, -0.35 }, Black),
		block("RightThigh", { 0.35, 0.35, 0.8 }, { 0.75, 0.6, -0.1 }, Cloak),
		block("RightShin", { 0.3, 0.8, 0.3 }, { 0.85, 0.15, -0.35 }, Black),
		block("RiderBody", { 1, 1.1, 0.6 }, { 0, 1.15, 0.1 }, Cloak),
		block("Shoulders", { 1.3, 0.3, 0.65 }, { 0, 1.6, 0.1 }, Cloak),
		block("Collar", { 0.8, 0.3, 0.6 }, { 0, 1.85, 0.1 }, { 90, 20, 30 }),
		block("NeckStump", { 0.35, 0.15, 0.35 }, { 0, 2.05, 0.1 }, Blood),
		block("Buttons", { 0.1, 0.6, 0.05 }, { 0, 1.15, -0.22 }, Gold),
		limb("Cape", { 1.2, 1.5, 0.12 }, { 0, 1, 0.5 }, Cloak, "X", 15, 2, 0, { 0, 0.75, 0 }),
		tilt(block("ReinArm", { 0.3, 0.9, 0.3 }, { -0.7, 1.15, -0.35 }, Cloak), -45, 0, 0),
		block("HeadArm", { 0.3, 0.3, 1 }, { 0.75, 1.5, -0.4 }, Cloak),
		block("Pumpkin", { 0.7, 0.6, 0.7 }, { 0.75, 1.55, -1.1 }, Pumpkin),
		block("PumpkinStem", { 0.12, 0.2, 0.12 }, { 0.75, 1.95, -1.1 }, Ivy),
		block("PumpkinLeftEye", { 0.15, 0.12, 0.05 }, { 0.6, 1.65, -1.47 }, Candle, true),
		block("PumpkinRightEye", { 0.15, 0.12, 0.05 }, { 0.9, 1.65, -1.47 }, Candle, true),
		block("PumpkinGrin", { 0.45, 0.1, 0.05 }, { 0.75, 1.4, -1.47 }, Candle, true),
	},
}

-- Zone 1, Divine: a pale, bloodstained ghost lady in a torn white dress. Long black hair falls
-- over her face, her eyes are empty and weep blood, and she holds a lantern out in front of her.
local Dress = { 220, 220, 215 }
local GhostSkin = { 220, 228, 232 }
local Hair = { 20, 18, 24 }
Looks.LadyOfLanterns = {
	gait = "float",
	top = 2.2,
	pieces = {
		block("Bodice", { 1, 0.8, 0.7 }, { 0, 0.7, 0 }, Dress),
		block("Waist", { 1.3, 1.4, 0.9 }, { 0, -0.2, 0 }, Dress),
		block("Skirt", { 1.7, 1, 1.3 }, { 0, -1.3, 0 }, Dress),
		limb(
			"FrontLeftRag",
			{ 0.35, 0.45, 0.15 },
			{ -0.55, -1.95, -0.55 },
			Dress,
			"X",
			15,
			1,
			0,
			{ 0, 0.22, 0 }
		),
		limb(
			"FrontRightRag",
			{ 0.4, 0.35, 0.15 },
			{ 0.5, -1.9, -0.55 },
			Dress,
			"X",
			15,
			1,
			0.3,
			{ 0, 0.17, 0 }
		),
		limb("BackLeftRag", { 0.4, 0.4, 0.15 }, { -0.4, -1.92, 0.55 }, Dress, "X", 15, 1, 0.6, { 0, 0.2, 0 }),
		limb(
			"BackRightRag",
			{ 0.35, 0.5, 0.15 },
			{ 0.55, -1.97, 0.55 },
			Dress,
			"X",
			15,
			1,
			0.8,
			{ 0, 0.25, 0 }
		),
		block("ChestBlood", { 0.5, 0.4, 0.05 }, { 0.2, 0.75, -0.37 }, Blood),
		block("WaistBlood", { 0.4, 0.6, 0.05 }, { -0.3, -0.35, -0.47 }, Blood),
		block("SkirtBlood", { 0.6, 0.3, 0.05 }, { 0.3, -1.1, -0.67 }, Blood),
		block("Head", { 0.8, 0.9, 0.8 }, { 0, 1.55, 0 }, GhostSkin),
		block("LeftEye", { 0.2, 0.15, 0.05 }, { -0.18, 1.62, -0.42 }, Black),
		block("RightEye", { 0.2, 0.15, 0.05 }, { 0.18, 1.62, -0.42 }, Black),
		block("LeftPupil", { 0.06, 0.06, 0.05 }, { -0.18, 1.62, -0.45 }, White, true),
		block("RightPupil", { 0.06, 0.06, 0.05 }, { 0.18, 1.62, -0.45 }, White, true),
		block("LeftTear", { 0.06, 0.35, 0.05 }, { -0.18, 1.38, -0.43 }, Blood),
		block("RightTear", { 0.06, 0.3, 0.05 }, { 0.2, 1.4, -0.43 }, Blood),
		block("Mouth", { 0.25, 0.3, 0.05 }, { 0, 1.25, -0.42 }, Black),
		block("ChinBlood", { 0.08, 0.35, 0.05 }, { 0.05, 1.0, -0.37 }, Blood),
		block("HairTop", { 0.95, 0.25, 0.9 }, { 0, 2.05, 0 }, Hair),
		block("HairBack", { 0.95, 1.7, 0.3 }, { 0, 1.15, 0.42 }, Hair),
		block("HairLeft", { 0.15, 1.3, 0.5 }, { -0.47, 1.25, -0.05 }, Hair),
		block("HairRight", { 0.15, 1.5, 0.5 }, { 0.47, 1.15, -0.05 }, Hair),
		block("HairFront", { 0.2, 0.85, 0.06 }, { -0.28, 1.5, -0.44 }, Hair),
		-- Right arm held out with the lantern hanging from the hand (it sways).
		block("LanternArm", { 0.25, 0.25, 1 }, { 0.65, 0.85, -0.55 }, Dress),
		block("LanternHand", { 0.3, 0.3, 0.3 }, { 0.65, 0.85, -1.15 }, Blood),
		limb("Handle", { 0.06, 0.25, 0.06 }, { 0.65, 0.6, -1.15 }, Iron, "X", 12, 0.8, 0, { 0, 0.25, 0 }),
		limb("LanternTop", { 0.5, 0.1, 0.5 }, { 0.65, 0.45, -1.15 }, Iron, "X", 12, 0.8, 0, { 0, 0.4, 0 }),
		limb(
			"Lantern",
			{ 0.4, 0.5, 0.4 },
			{ 0.65, 0.15, -1.15 },
			Candle,
			"X",
			12,
			0.8,
			0,
			{ 0, 0.7, 0 },
			true
		),
		limb("LanternBase", { 0.5, 0.1, 0.5 }, { 0.65, -0.15, -1.15 }, Iron, "X", 12, 0.8, 0, { 0, 1, 0 }),
		-- Left arm hangs limp, ending in long bloody fingers.
		limb("LimpArm", { 0.25, 1.2, 0.25 }, { -0.65, 0.25, 0 }, Dress, "Z", -8, 0.6, 0, { 0, 0.6, 0 }),
		limb("Fingers", { 0.25, 0.4, 0.25 }, { -0.65, -0.55, 0 }, Blood, "Z", -8, 0.6, 0, { 0, 1.4, 0 }),
	},
}

-- Zone 2, Common: a wet, dark lump of bayou mud that oozes along, bubbles rising out of it and two
-- little eyes glinting from its sockets.
local Mud = { 62, 52, 33 }
local MudDark = { 42, 35, 22 }
local MudLight = { 92, 78, 50 }
Looks.Bogbub = {
	gait = "walk",
	top = 0.2,
	wet = true,
	pieces = {
		block("Puddle", { 2.3, 0.3, 2.1 }, { 0, -1.85, 0 }, MudDark),
		block("Blob", { 1.9, 1, 1.7 }, { 0, -1.2, 0 }, Mud),
		block("BlobTop", { 1.4, 0.55, 1.3 }, { 0, -0.45, 0.05 }, Mud),
		block("TopLump", { 0.7, 0.3, 0.6 }, { 0.25, -0.05, 0.15 }, Mud),
		block("SmallLump", { 0.35, 0.2, 0.35 }, { -0.35, -0.1, -0.1 }, MudLight),
		block("SideLumpLeft", { 0.5, 0.6, 0.7 }, { -1, -1.3, 0.2 }, Mud),
		block("SideLumpRight", { 0.45, 0.5, 0.6 }, { 1, -1.45, -0.3 }, Mud),
		block("BackLump", { 0.8, 0.6, 0.4 }, { 0.2, -1, 0.9 }, MudDark),
		block("DripLeft", { 0.16, 0.5, 0.06 }, { -0.6, -1.05, -0.86 }, MudDark),
		block("DripLeftEnd", { 0.2, 0.12, 0.08 }, { -0.6, -1.32, -0.86 }, MudDark),
		block("DripRight", { 0.14, 0.35, 0.06 }, { 0.65, -0.95, -0.86 }, MudDark),
		block("DripTop", { 0.14, 0.3, 0.06 }, { 0.45, -0.55, -0.66 }, MudDark),
		block("WetShine1", { 0.3, 0.08, 0.05 }, { -0.45, -0.85, -0.86 }, MudLight),
		block("WetShine2", { 0.2, 0.08, 0.05 }, { 0.2, -0.3, -0.66 }, MudLight),
		block("LeftSocket", { 0.38, 0.3, 0.05 }, { -0.35, -0.5, -0.66 }, Black),
		block("RightSocket", { 0.38, 0.3, 0.05 }, { 0.35, -0.45, -0.66 }, Black),
		block("LeftEye", { 0.14, 0.14, 0.05 }, { -0.33, -0.52, -0.69 }, { 255, 215, 90 }, true),
		block("RightEye", { 0.14, 0.14, 0.05 }, { 0.37, -0.47, -0.69 }, { 255, 215, 90 }, true),
		block("Mouth", { 0.95, 0.22, 0.05 }, { 0, -1.25, -0.86 }, Black),
		block("MouthDrip", { 0.12, 0.3, 0.06 }, { 0.25, -1.45, -0.86 }, MudDark),
		slide(
			limb("Bubble1", { 0.3, 0.3, 0.3 }, { 0.6, -0.15, 0.35 }, MudLight, "Y", 0.15, 0.7, 0, { 0, 0, 0 })
		),
		slide(
			limb(
				"Bubble2",
				{ 0.22, 0.22, 0.22 },
				{ -0.55, -0.12, 0.3 },
				MudLight,
				"Y",
				0.12,
				0.7,
				0.5,
				{ 0, 0, 0 }
			)
		),
		limb(
			"LeftFoot",
			{ 0.55, 0.25, 0.55 },
			{ -0.6, -1.87, -0.9 },
			MudDark,
			"X",
			25,
			2.5,
			0,
			{ 0, 0.12, 0 }
		),
		limb(
			"RightFoot",
			{ 0.55, 0.25, 0.55 },
			{ 0.6, -1.87, -0.9 },
			MudDark,
			"X",
			25,
			2.5,
			0.5,
			{ 0, 0.12, 0 }
		),
	},
}

-- Zone 2, Common: a zombie frog sewn back together from patches of skin. Stitches run over its
-- back and head, a button is sewn on for one eye, its mouth is stitched shut and its ribs show.
local Frog = { 95, 125, 75 }
local Belly = { 170, 190, 110 }
Looks.Croakling = {
	gait = "walk",
	top = 0.3,
	pieces = {
		block("Body", { 1.6, 1, 1.8 }, { 0, -1.2, 0.1 }, Frog),
		block("Belly", { 1.2, 0.6, 0.1 }, { 0, -1.3, -0.82 }, Belly),
		block("Head", { 1.4, 0.8, 1 }, { 0, -0.5, -0.6 }, Frog),
		block("PatchBack", { 0.7, 0.08, 0.7 }, { -0.3, -0.68, 0.4 }, { 125, 135, 120 }),
		block("PatchSide", { 0.06, 0.5, 0.6 }, { 0.81, -1.2, 0.3 }, { 175, 115, 115 }),
		block("PatchHead", { 0.5, 0.06, 0.4 }, { 0.35, -0.08, -0.6 }, { 125, 135, 120 }),
		block("ExposedRib1", { 0.07, 0.4, 0.07 }, { -0.82, -1.2, 0 }, Bone),
		block("ExposedRib2", { 0.07, 0.4, 0.07 }, { -0.82, -1.2, 0.25 }, Bone),
		block("RibHole", { 0.05, 0.45, 0.45 }, { -0.81, -1.2, 0.12 }, { 60, 20, 25 }),
		block("StitchBack", { 1.1, 0.05, 0.06 }, { 0.05, -0.69, 0.4 }, { 30, 25, 30 }),
		block("StitchBackTick1", { 0.05, 0.06, 0.2 }, { -0.39, -0.69, 0.4 }, { 30, 25, 30 }),
		block("StitchBackTick2", { 0.05, 0.06, 0.2 }, { -0.17, -0.69, 0.4 }, { 30, 25, 30 }),
		block("StitchBackTick3", { 0.05, 0.06, 0.2 }, { 0.05, -0.69, 0.4 }, { 30, 25, 30 }),
		block("StitchBackTick4", { 0.05, 0.06, 0.2 }, { 0.27, -0.69, 0.4 }, { 30, 25, 30 }),
		block("StitchBackTick5", { 0.05, 0.06, 0.2 }, { 0.49, -0.69, 0.4 }, { 30, 25, 30 }),
		block("StitchHead", { 0.06, 0.05, 0.5 }, { 0.35, -0.09, -0.6 }, { 30, 25, 30 }),
		block("StitchHeadTick1", { 0.2, 0.06, 0.05 }, { 0.35, -0.09, -0.767 }, { 30, 25, 30 }),
		block("StitchHeadTick2", { 0.2, 0.06, 0.05 }, { 0.35, -0.09, -0.6 }, { 30, 25, 30 }),
		block("StitchHeadTick3", { 0.2, 0.06, 0.05 }, { 0.35, -0.09, -0.433 }, { 30, 25, 30 }),
		block("StitchSide", { 0.05, 0.05, 0.7 }, { 0.82, -1, 0.3 }, { 30, 25, 30 }),
		block("StitchSideTick1", { 0.06, 0.18, 0.05 }, { 0.82, -1, 0.067 }, { 30, 25, 30 }),
		block("StitchSideTick2", { 0.06, 0.18, 0.05 }, { 0.82, -1, 0.3 }, { 30, 25, 30 }),
		block("StitchSideTick3", { 0.06, 0.18, 0.05 }, { 0.82, -1, 0.533 }, { 30, 25, 30 }),
		block("Mouth", { 1.2, 0.08, 0.06 }, { 0, -0.75, -1.12 }, Black),
		block("MouthStitch1", { 0.05, 0.2, 0.05 }, { -0.4, -0.75, -1.14 }, { 30, 25, 30 }),
		block("MouthStitch2", { 0.05, 0.2, 0.05 }, { -0.2, -0.75, -1.14 }, { 30, 25, 30 }),
		block("MouthStitch3", { 0.05, 0.2, 0.05 }, { 0, -0.75, -1.14 }, { 30, 25, 30 }),
		block("MouthStitch4", { 0.05, 0.2, 0.05 }, { 0.2, -0.75, -1.14 }, { 30, 25, 30 }),
		block("MouthStitch5", { 0.05, 0.2, 0.05 }, { 0.4, -0.75, -1.14 }, { 30, 25, 30 }),
		block("TongueOut", { 0.15, 0.35, 0.06 }, { 0.45, -0.93, -1.12 }, { 200, 90, 110 }),
		block("LeftEye", { 0.45, 0.45, 0.45 }, { -0.45, 0, -0.7 }, { 255, 230, 70 }, true),
		block("LeftPupil", { 0.1, 0.3, 0.1 }, { -0.45, 0, -0.95 }, Black),
		block("RightEyeSocket", { 0.45, 0.45, 0.45 }, { 0.45, 0, -0.7 }, Frog),
		block("ButtonEye", { 0.4, 0.4, 0.08 }, { 0.45, 0, -0.96 }, { 110, 70, 45 }),
		tilt(block("ButtonStitchA", { 0.05, 0.32, 0.04 }, { 0.45, 0, -1.01 }, { 30, 25, 30 }), 0, 0, 45),
		tilt(block("ButtonStitchB", { 0.05, 0.32, 0.04 }, { 0.45, 0, -1.01 }, { 30, 25, 30 }), 0, 0, -45),
		limb("FrontLeftLeg", { 0.3, 0.6, 0.3 }, { -0.55, -1.7, -0.6 }, Frog, "X", 25, 2, 0, { 0, 0.3, 0 }),
		limb(
			"FrontRightLeg",
			{ 0.3, 0.6, 0.3 },
			{ 0.55, -1.7, -0.6 },
			{ 125, 135, 120 },
			"X",
			25,
			2,
			0,
			{ 0, 0.3, 0 }
		),
		limb("BackLeftLeg", { 0.5, 0.3, 1 }, { -0.75, -1.85, 0.6 }, Frog, "X", 30, 2, 0.5, { 0, 0, -0.5 }),
		limb(
			"BackLeftBone",
			{ 0.12, 0.12, 0.5 },
			{ -0.75, -1.68, 0.75 },
			Bone,
			"X",
			30,
			2,
			0.5,
			{ 0, -0.17, -0.65 }
		),
		limb("BackRightLeg", { 0.5, 0.3, 1 }, { 0.75, -1.85, 0.6 }, Frog, "X", 30, 2, 0.5, { 0, 0, -0.5 }),
		limb(
			"BackRightStitch",
			{ 0.52, 0.05, 0.06 },
			{ 0.75, -1.69, 0.6 },
			{ 30, 25, 30 },
			"X",
			30,
			2,
			0.5,
			{ 0, -0.16, -0.5 }
		),
	},
}

-- Zone 2, Uncommon: a little glowing spirit living under a tiny willow tree. Strands of long thin
-- willow leaves hang all round it and sway.
local Willow = { 110, 160, 80 }
local Glow = { 200, 255, 180 }
Looks.WillowWisp = {
	gait = "float",
	top = 2,
	pieces = {
		block("Core", { 0.9, 0.9, 0.9 }, { 0, 0.25, 0 }, Glow, true),
		block("LeftEye", { 0.16, 0.2, 0.1 }, { -0.18, 0.35, -0.48 }, Black),
		block("RightEye", { 0.16, 0.2, 0.1 }, { 0.18, 0.35, -0.48 }, Black),
		block("Mouth", { 0.2, 0.08, 0.1 }, { 0, 0.12, -0.48 }, Black),
		block("Crown", { 1.7, 0.3, 1.7 }, { 0, 0.95, 0 }, { 120, 170, 85 }),
		block("CrownMiddle", { 1.2, 0.3, 1.2 }, { 0, 1.22, 0 }, { 85, 135, 65 }),
		block("CrownTop", { 0.7, 0.25, 0.7 }, { 0, 1.45, 0 }, { 120, 170, 85 }),
		block("Trunk", { 0.25, 0.5, 0.25 }, { 0, 1.55, 0 }, { 95, 80, 50 }),
		block("TrunkKnot", { 0.35, 0.12, 0.12 }, { 0.1, 1.7, 0 }, { 95, 80, 50 }),
		tilt(block("TwigLeft", { 0.06, 0.35, 0.06 }, { -0.12, 1.85, 0 }, { 95, 80, 50 }), 0, 0, 30),
		tilt(block("TwigRight", { 0.06, 0.3, 0.06 }, { 0.15, 1.82, 0 }, { 95, 80, 50 }), 0, 0, -35),
		tilt(block("TipLeaf1", { 0.08, 0.25, 0.04 }, { -0.22, 1.98, 0 }, { 120, 170, 85 }), 0, 0, 45),
		tilt(block("TipLeaf2", { 0.08, 0.22, 0.04 }, { 0.26, 1.94, 0 }, { 120, 170, 85 }), 0, 0, -50),
		limb(
			"Strand1",
			{ 0.05, 1.3, 0.05 },
			{ 0.693, 0.2, 0.287 },
			{ 95, 80, 50 },
			"X",
			12,
			1,
			0,
			{ 0, 0.65, 0 }
		),
		tilt(
			limb(
				"Strand1Leaf1",
				{ 0.09, 0.34, 0.04 },
				{ 0.763, 0.55, 0.287 },
				{ 120, 170, 85 },
				"X",
				12,
				1,
				0,
				{ -0.159, 0.264, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand1Leaf2",
				{ 0.09, 0.34, 0.04 },
				{ 0.623, 0.15, 0.287 },
				{ 85, 135, 65 },
				"X",
				12,
				1,
				0,
				{ 0.283, 0.644, 0 }
			),
			0,
			0,
			18
		),
		tilt(
			limb(
				"Strand1Leaf3",
				{ 0.09, 0.34, 0.04 },
				{ 0.763, -0.25, 0.287 },
				{ 120, 170, 85 },
				"X",
				12,
				1,
				0,
				{ -0.406, 1.025, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand1Leaf4",
				{ 0.09, 0.34, 0.04 },
				{ 0.623, -0.55, 0.287 },
				{ 85, 135, 65 },
				"X",
				12,
				1,
				0,
				{ 0.499, 1.31, 0 }
			),
			0,
			0,
			18
		),
		limb(
			"Strand2",
			{ 0.05, 1.3, 0.05 },
			{ 0.287, 0.2, 0.693 },
			{ 95, 80, 50 },
			"Z",
			12,
			1,
			0.125,
			{ 0, 0.65, 0 }
		),
		tilt(
			limb(
				"Strand2Leaf1",
				{ 0.09, 0.34, 0.04 },
				{ 0.357, 0.55, 0.693 },
				{ 120, 170, 85 },
				"Z",
				12,
				1,
				0.125,
				{ -0.159, 0.264, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand2Leaf2",
				{ 0.09, 0.34, 0.04 },
				{ 0.217, 0.15, 0.693 },
				{ 85, 135, 65 },
				"Z",
				12,
				1,
				0.125,
				{ 0.283, 0.644, 0 }
			),
			0,
			0,
			18
		),
		tilt(
			limb(
				"Strand2Leaf3",
				{ 0.09, 0.34, 0.04 },
				{ 0.357, -0.25, 0.693 },
				{ 120, 170, 85 },
				"Z",
				12,
				1,
				0.125,
				{ -0.406, 1.025, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand2Leaf4",
				{ 0.09, 0.34, 0.04 },
				{ 0.217, -0.55, 0.693 },
				{ 85, 135, 65 },
				"Z",
				12,
				1,
				0.125,
				{ 0.499, 1.31, 0 }
			),
			0,
			0,
			18
		),
		limb(
			"Strand3",
			{ 0.05, 1.3, 0.05 },
			{ -0.287, 0.2, 0.693 },
			{ 95, 80, 50 },
			"X",
			12,
			1,
			0.25,
			{ 0, 0.65, 0 }
		),
		tilt(
			limb(
				"Strand3Leaf1",
				{ 0.09, 0.34, 0.04 },
				{ -0.217, 0.55, 0.693 },
				{ 120, 170, 85 },
				"X",
				12,
				1,
				0.25,
				{ -0.159, 0.264, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand3Leaf2",
				{ 0.09, 0.34, 0.04 },
				{ -0.357, 0.15, 0.693 },
				{ 85, 135, 65 },
				"X",
				12,
				1,
				0.25,
				{ 0.283, 0.644, 0 }
			),
			0,
			0,
			18
		),
		tilt(
			limb(
				"Strand3Leaf3",
				{ 0.09, 0.34, 0.04 },
				{ -0.217, -0.25, 0.693 },
				{ 120, 170, 85 },
				"X",
				12,
				1,
				0.25,
				{ -0.406, 1.025, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand3Leaf4",
				{ 0.09, 0.34, 0.04 },
				{ -0.357, -0.55, 0.693 },
				{ 85, 135, 65 },
				"X",
				12,
				1,
				0.25,
				{ 0.499, 1.31, 0 }
			),
			0,
			0,
			18
		),
		limb(
			"Strand4",
			{ 0.05, 1.3, 0.05 },
			{ -0.693, 0.2, 0.287 },
			{ 95, 80, 50 },
			"Z",
			12,
			1,
			0.375,
			{ 0, 0.65, 0 }
		),
		tilt(
			limb(
				"Strand4Leaf1",
				{ 0.09, 0.34, 0.04 },
				{ -0.623, 0.55, 0.287 },
				{ 120, 170, 85 },
				"Z",
				12,
				1,
				0.375,
				{ -0.159, 0.264, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand4Leaf2",
				{ 0.09, 0.34, 0.04 },
				{ -0.763, 0.15, 0.287 },
				{ 85, 135, 65 },
				"Z",
				12,
				1,
				0.375,
				{ 0.283, 0.644, 0 }
			),
			0,
			0,
			18
		),
		tilt(
			limb(
				"Strand4Leaf3",
				{ 0.09, 0.34, 0.04 },
				{ -0.623, -0.25, 0.287 },
				{ 120, 170, 85 },
				"Z",
				12,
				1,
				0.375,
				{ -0.406, 1.025, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand4Leaf4",
				{ 0.09, 0.34, 0.04 },
				{ -0.763, -0.55, 0.287 },
				{ 85, 135, 65 },
				"Z",
				12,
				1,
				0.375,
				{ 0.499, 1.31, 0 }
			),
			0,
			0,
			18
		),
		limb(
			"Strand5",
			{ 0.05, 1.3, 0.05 },
			{ -0.693, 0.2, -0.287 },
			{ 95, 80, 50 },
			"X",
			12,
			1,
			0.5,
			{ 0, 0.65, 0 }
		),
		tilt(
			limb(
				"Strand5Leaf1",
				{ 0.09, 0.34, 0.04 },
				{ -0.623, 0.55, -0.287 },
				{ 120, 170, 85 },
				"X",
				12,
				1,
				0.5,
				{ -0.159, 0.264, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand5Leaf2",
				{ 0.09, 0.34, 0.04 },
				{ -0.763, 0.15, -0.287 },
				{ 85, 135, 65 },
				"X",
				12,
				1,
				0.5,
				{ 0.283, 0.644, 0 }
			),
			0,
			0,
			18
		),
		tilt(
			limb(
				"Strand5Leaf3",
				{ 0.09, 0.34, 0.04 },
				{ -0.623, -0.25, -0.287 },
				{ 120, 170, 85 },
				"X",
				12,
				1,
				0.5,
				{ -0.406, 1.025, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand5Leaf4",
				{ 0.09, 0.34, 0.04 },
				{ -0.763, -0.55, -0.287 },
				{ 85, 135, 65 },
				"X",
				12,
				1,
				0.5,
				{ 0.499, 1.31, 0 }
			),
			0,
			0,
			18
		),
		limb(
			"Strand6",
			{ 0.05, 1.3, 0.05 },
			{ -0.287, 0.2, -0.693 },
			{ 95, 80, 50 },
			"Z",
			12,
			1,
			0.625,
			{ 0, 0.65, 0 }
		),
		tilt(
			limb(
				"Strand6Leaf1",
				{ 0.09, 0.34, 0.04 },
				{ -0.217, 0.55, -0.693 },
				{ 120, 170, 85 },
				"Z",
				12,
				1,
				0.625,
				{ -0.159, 0.264, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand6Leaf2",
				{ 0.09, 0.34, 0.04 },
				{ -0.357, 0.15, -0.693 },
				{ 85, 135, 65 },
				"Z",
				12,
				1,
				0.625,
				{ 0.283, 0.644, 0 }
			),
			0,
			0,
			18
		),
		tilt(
			limb(
				"Strand6Leaf3",
				{ 0.09, 0.34, 0.04 },
				{ -0.217, -0.25, -0.693 },
				{ 120, 170, 85 },
				"Z",
				12,
				1,
				0.625,
				{ -0.406, 1.025, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand6Leaf4",
				{ 0.09, 0.34, 0.04 },
				{ -0.357, -0.55, -0.693 },
				{ 85, 135, 65 },
				"Z",
				12,
				1,
				0.625,
				{ 0.499, 1.31, 0 }
			),
			0,
			0,
			18
		),
		limb(
			"Strand7",
			{ 0.05, 1.3, 0.05 },
			{ 0.287, 0.2, -0.693 },
			{ 95, 80, 50 },
			"X",
			12,
			1,
			0.75,
			{ 0, 0.65, 0 }
		),
		tilt(
			limb(
				"Strand7Leaf1",
				{ 0.09, 0.34, 0.04 },
				{ 0.357, 0.55, -0.693 },
				{ 120, 170, 85 },
				"X",
				12,
				1,
				0.75,
				{ -0.159, 0.264, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand7Leaf2",
				{ 0.09, 0.34, 0.04 },
				{ 0.217, 0.15, -0.693 },
				{ 85, 135, 65 },
				"X",
				12,
				1,
				0.75,
				{ 0.283, 0.644, 0 }
			),
			0,
			0,
			18
		),
		tilt(
			limb(
				"Strand7Leaf3",
				{ 0.09, 0.34, 0.04 },
				{ 0.357, -0.25, -0.693 },
				{ 120, 170, 85 },
				"X",
				12,
				1,
				0.75,
				{ -0.406, 1.025, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand7Leaf4",
				{ 0.09, 0.34, 0.04 },
				{ 0.217, -0.55, -0.693 },
				{ 85, 135, 65 },
				"X",
				12,
				1,
				0.75,
				{ 0.499, 1.31, 0 }
			),
			0,
			0,
			18
		),
		limb(
			"Strand8",
			{ 0.05, 1.3, 0.05 },
			{ 0.693, 0.2, -0.287 },
			{ 95, 80, 50 },
			"Z",
			12,
			1,
			0.875,
			{ 0, 0.65, 0 }
		),
		tilt(
			limb(
				"Strand8Leaf1",
				{ 0.09, 0.34, 0.04 },
				{ 0.763, 0.55, -0.287 },
				{ 120, 170, 85 },
				"Z",
				12,
				1,
				0.875,
				{ -0.159, 0.264, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand8Leaf2",
				{ 0.09, 0.34, 0.04 },
				{ 0.623, 0.15, -0.287 },
				{ 85, 135, 65 },
				"Z",
				12,
				1,
				0.875,
				{ 0.283, 0.644, 0 }
			),
			0,
			0,
			18
		),
		tilt(
			limb(
				"Strand8Leaf3",
				{ 0.09, 0.34, 0.04 },
				{ 0.763, -0.25, -0.287 },
				{ 120, 170, 85 },
				"Z",
				12,
				1,
				0.875,
				{ -0.406, 1.025, 0 }
			),
			0,
			0,
			-18
		),
		tilt(
			limb(
				"Strand8Leaf4",
				{ 0.09, 0.34, 0.04 },
				{ 0.623, -0.55, -0.287 },
				{ 85, 135, 65 },
				"Z",
				12,
				1,
				0.875,
				{ 0.499, 1.31, 0 }
			),
			0,
			0,
			18
		),
	},
}

-- Zone 2, Uncommon: a swamp witch with a wicked grin (one gold tooth), a warty nose and grey hair
-- under a patched, crooked hat. A shawl, belt, potion and pouch over her tattered robe, clawed
-- hands, curled shoes, and a reed broom.
local Robe = { 45, 75, 55 }
local WitchSkin = { 150, 175, 120 }
local Reed = { 200, 180, 90 }
Looks.Reedwitch = {
	gait = "walk",
	top = 2.45,
	pieces = {
		block("Robe", { 1.4, 1.6, 1 }, { 0, -0.6, 0 }, Robe),
		block("Shawl", { 1.5, 0.4, 1.1 }, { 0, 0.05, 0 }, { 60, 40, 70 }),
		block("ShawlPoint", { 0.5, 0.3, 0.05 }, { 0, -0.2, -0.54 }, { 60, 40, 70 }),
		block("Belt", { 1.42, 0.15, 1.02 }, { 0, -0.55, 0 }, Leather),
		block("Buckle", { 0.25, 0.2, 0.05 }, { 0, -0.55, -0.53 }, Gold),
		block("RobePatch", { 0.3, 0.3, 0.05 }, { 0.35, -1, -0.51 }, { 70, 95, 70 }),
		block("PatchStitch", { 0.32, 0.04, 0.06 }, { 0.35, -0.86, -0.52 }, Black),
		block("Potion", { 0.2, 0.25, 0.2 }, { -0.45, -0.82, -0.56 }, { 120, 255, 120 }, true),
		block("Cork", { 0.1, 0.08, 0.1 }, { -0.45, -0.66, -0.56 }, Wood),
		block("Pouch", { 0.25, 0.25, 0.15 }, { 0.5, -0.75, -0.55 }, Leather),
		block("Tatter1", { 0.3, 0.25, 0.05 }, { -0.5, -1.5, -0.51 }, Robe),
		block("Tatter2", { 0.25, 0.15, 0.05 }, { 0.05, -1.46, -0.51 }, Robe),
		block("Tatter3", { 0.3, 0.22, 0.05 }, { 0.5, -1.49, -0.51 }, Robe),
		block("Tatter4", { 0.05, 0.2, 0.4 }, { -0.71, -1.47, 0.2 }, Robe),
		block("Tatter5", { 0.05, 0.25, 0.3 }, { 0.71, -1.5, -0.1 }, Robe),
		block("Head", { 0.9, 0.9, 0.9 }, { 0, 0.65, 0 }, WitchSkin),
		block("Chin", { 0.3, 0.2, 0.25 }, { 0, 0.15, -0.32 }, WitchSkin),
		block("Nose", { 0.2, 0.2, 0.5 }, { 0, 0.58, -0.65 }, WitchSkin),
		block("Wart", { 0.08, 0.08, 0.08 }, { 0.08, 0.7, -0.8 }, { 110, 140, 80 }),
		block("LeftEye", { 0.15, 0.12, 0.1 }, { -0.2, 0.8, -0.47 }, Candle, true),
		block("RightEye", { 0.15, 0.12, 0.1 }, { 0.2, 0.8, -0.47 }, Candle, true),
		tilt(block("LeftBrow", { 0.28, 0.07, 0.05 }, { -0.2, 0.92, -0.47 }, Black), 0, 0, -22),
		tilt(block("RightBrow", { 0.28, 0.07, 0.05 }, { 0.2, 0.92, -0.47 }, Black), 0, 0, 22),
		block("Grin", { 0.5, 0.09, 0.05 }, { 0, 0.35, -0.47 }, Black),
		tilt(block("GrinLeft", { 0.2, 0.08, 0.05 }, { -0.3, 0.4, -0.47 }, Black), 0, 0, -30),
		tilt(block("GrinRight", { 0.2, 0.08, 0.05 }, { 0.3, 0.4, -0.47 }, Black), 0, 0, 30),
		block("Tooth1", { 0.07, 0.08, 0.04 }, { -0.14, 0.37, -0.49 }, Bone),
		block("Tooth2", { 0.07, 0.08, 0.04 }, { 0.02, 0.37, -0.49 }, Gold),
		block("Tooth3", { 0.07, 0.08, 0.04 }, { 0.16, 0.37, -0.49 }, Bone),
		block("HairLeft", { 0.15, 0.7, 0.35 }, { -0.5, 0.55, 0.05 }, { 90, 95, 100 }),
		block("HairRight", { 0.15, 0.7, 0.35 }, { 0.5, 0.55, 0.05 }, { 90, 95, 100 }),
		block("HairBack", { 0.9, 0.75, 0.15 }, { 0, 0.55, 0.48 }, { 90, 95, 100 }),
		block("HatBrim", { 1.5, 0.15, 1.5 }, { 0, 1.15, 0 }, Black),
		block("HatMiddle", { 0.8, 0.6, 0.8 }, { 0, 1.5, 0 }, Black),
		tilt(block("HatTip", { 0.4, 0.5, 0.4 }, { 0.12, 1.95, 0.1 }, Black), 0, 0, -15),
		tilt(block("HatPoint", { 0.2, 0.3, 0.2 }, { 0.28, 2.25, 0.15 }, Black), 0, 0, -35),
		block("HatBand", { 0.85, 0.15, 0.85 }, { 0, 1.3, 0 }, Purple),
		block("HatBuckle", { 0.2, 0.18, 0.05 }, { 0, 1.3, -0.44 }, Gold),
		block("HatPatch", { 0.25, 0.25, 0.05 }, { -0.2, 1.55, -0.41 }, { 55, 45, 60 }),
		limb("LeftArm", { 0.3, 1, 0.3 }, { -0.85, -0.4, 0 }, Robe, "X", 25, 1.5, 0.5, { 0, 0.5, 0 }),
		limb(
			"LeftCuff",
			{ 0.34, 0.12, 0.34 },
			{ -0.85, -0.85, 0 },
			{ 60, 40, 70 },
			"X",
			25,
			1.5,
			0.5,
			{ 0, 0.95, 0 }
		),
		limb("LeftHand", { 0.24, 0.2, 0.24 }, { -0.85, -1, 0 }, WitchSkin, "X", 25, 1.5, 0.5, { 0, 1.1, 0 }),
		limb(
			"LeftNail1",
			{ 0.05, 0.15, 0.05 },
			{ -0.92, -1.15, -0.08 },
			Black,
			"X",
			25,
			1.5,
			0.5,
			{ 0.07, 1.25, 0.08 }
		),
		limb(
			"LeftNail2",
			{ 0.05, 0.15, 0.05 },
			{ -0.78, -1.15, -0.08 },
			Black,
			"X",
			25,
			1.5,
			0.5,
			{ -0.07, 1.25, 0.08 }
		),
		limb("RightArm", { 0.3, 1, 0.3 }, { 0.85, -0.4, 0 }, Robe, "X", 25, 1.5, 0, { 0, 0.5, 0 }),
		limb(
			"RightCuff",
			{ 0.34, 0.12, 0.34 },
			{ 0.85, -0.85, 0 },
			{ 60, 40, 70 },
			"X",
			25,
			1.5,
			0,
			{ 0, 0.95, 0 }
		),
		limb("RightHand", { 0.24, 0.2, 0.24 }, { 0.85, -1, 0 }, WitchSkin, "X", 25, 1.5, 0, { 0, 1.1, 0 }),
		limb(
			"RightNail1",
			{ 0.05, 0.15, 0.05 },
			{ 0.78, -1.15, -0.08 },
			Black,
			"X",
			25,
			1.5,
			0,
			{ 0.07, 1.25, 0.08 }
		),
		limb(
			"RightNail2",
			{ 0.05, 0.15, 0.05 },
			{ 0.92, -1.15, -0.08 },
			Black,
			"X",
			25,
			1.5,
			0,
			{ -0.07, 1.25, 0.08 }
		),
		limb("Broom", { 0.15, 2, 0.15 }, { 0.85, -0.6, -0.35 }, Wood, "X", 25, 1.5, 0, { 0, 0.7, 0.35 }),
		limb(
			"BroomTie",
			{ 0.3, 0.12, 0.3 },
			{ 0.85, -1.5, -0.35 },
			Purple,
			"X",
			25,
			1.5,
			0,
			{ 0, 1.6, 0.35 }
		),
		limb("Bristles", { 0.5, 0.5, 0.5 }, { 0.85, -1.7, -0.35 }, Reed, "X", 25, 1.5, 0, { 0, 1.8, 0.35 }),
		limb("LeftLeg", { 0.35, 0.6, 0.35 }, { -0.3, -1.7, 0 }, Black, "X", 25, 1.5, 0, { 0, 0.3, 0 }),
		limb(
			"LeftShoe",
			{ 0.3, 0.15, 0.55 },
			{ -0.3, -1.925, -0.15 },
			Black,
			"X",
			25,
			1.5,
			0,
			{ 0, 0.53, 0.15 }
		),
		limb(
			"LeftShoeTip",
			{ 0.12, 0.15, 0.12 },
			{ -0.3, -1.85, -0.45 },
			Black,
			"X",
			25,
			1.5,
			0,
			{ 0, 0.45, 0.45 }
		),
		limb("RightLeg", { 0.35, 0.6, 0.35 }, { 0.3, -1.7, 0 }, Black, "X", 25, 1.5, 0.5, { 0, 0.3, 0 }),
		limb(
			"RightShoe",
			{ 0.3, 0.15, 0.55 },
			{ 0.3, -1.925, -0.15 },
			Black,
			"X",
			25,
			1.5,
			0.5,
			{ 0, 0.53, 0.15 }
		),
		limb(
			"RightShoeTip",
			{ 0.12, 0.15, 0.12 },
			{ 0.3, -1.85, -0.45 },
			Black,
			"X",
			25,
			1.5,
			0.5,
			{ 0, 0.45, 0.45 }
		),
	},
}

-- Zone 2, Rare: a ghostly, see-through alligator, low to the ground, swishing its tail.
local Gator = { 120, 170, 140 }
local GatorDark = { 80, 120, 100 }
Looks.Gatorghast = {
	gait = "walk",
	top = -0.3,
	seeThrough = 0.45,
	pieces = {
		block("Body", { 1.4, 0.9, 3 }, { 0, -1.1, 0.2 }, Gator),
		block("Head", { 1.2, 0.7, 1.6 }, { 0, -0.9, -1.9 }, Gator),
		block("Teeth", { 1, 0.15, 1.2 }, { 0, -1.3, -2.1 }, White),
		block("LeftBrow", { 0.35, 0.3, 0.35 }, { -0.4, -0.45, -1.5 }, GatorDark),
		block("RightBrow", { 0.35, 0.3, 0.35 }, { 0.4, -0.45, -1.5 }, GatorDark),
		block("LeftEye", { 0.2, 0.15, 0.1 }, { -0.4, -0.45, -1.7 }, { 255, 240, 80 }, true),
		block("RightEye", { 0.2, 0.15, 0.1 }, { 0.4, -0.45, -1.7 }, { 255, 240, 80 }, true),
		block("FrontSpike", { 0.3, 0.3, 0.3 }, { 0, -0.5, -0.6 }, GatorDark),
		block("MiddleSpike", { 0.3, 0.3, 0.3 }, { 0, -0.5, 0.2 }, GatorDark),
		block("BackSpike", { 0.3, 0.3, 0.3 }, { 0, -0.5, 1 }, GatorDark),
		limb("Tail", { 0.8, 0.6, 2 }, { 0, -1.2, 2.7 }, Gator, "Y", 25, 1.5, 0, { 0, 0, -1 }),
		limb(
			"FrontLeftLeg",
			{ 0.4, 0.5, 0.4 },
			{ -0.75, -1.75, -0.8 },
			GatorDark,
			"X",
			30,
			2,
			0,
			{ 0, 0.25, 0 }
		),
		limb(
			"FrontRightLeg",
			{ 0.4, 0.5, 0.4 },
			{ 0.75, -1.75, -0.8 },
			GatorDark,
			"X",
			30,
			2,
			0.5,
			{ 0, 0.25, 0 }
		),
		limb(
			"BackLeftLeg",
			{ 0.4, 0.5, 0.4 },
			{ -0.75, -1.75, 0.9 },
			GatorDark,
			"X",
			30,
			2,
			0.5,
			{ 0, 0.25, 0 }
		),
		limb(
			"BackRightLeg",
			{ 0.4, 0.5, 0.4 },
			{ 0.75, -1.75, 0.9 },
			GatorDark,
			"X",
			30,
			2,
			0,
			{ 0, 0.25, 0 }
		),
	},
}

-- Zone 2, Epic: a drowned church bell, properly bell-shaped with bands and a wooden yoke, its
-- glowing clapper swinging inside. Seaweed is draped all over it and hangs from its rim, with
-- barnacles and green patina.
local Bronze = { 160, 110, 60 }
local Verdigris = { 90, 160, 140 }
local Seaweed = { 50, 110, 60 }
local BronzeDark = { 120, 80, 45 }
Looks.SunkenBell = {
	gait = "float",
	top = 2.2,
	pieces = {
		block("Bell1", { 1, 0.2, 1 }, { 0, 1.15, 0 }, Bronze),
		block("Bell2", { 1.3, 0.2, 1.3 }, { 0, 0.95, 0 }, Bronze),
		block("Bell3", { 1.42, 0.45, 1.42 }, { 0, 0.625, 0 }, Bronze),
		block("Bell4", { 1.5, 0.4, 1.5 }, { 0, 0.2, 0 }, Bronze),
		block("Bell5", { 1.6, 0.3, 1.6 }, { 0, -0.15, 0 }, Bronze),
		block("Bell6", { 1.75, 0.2, 1.75 }, { 0, -0.4, 0 }, Bronze),
		block("Bell7", { 1.95, 0.15, 1.95 }, { 0, -0.575, 0 }, Bronze),
		block("Bell8", { 2.2, 0.12, 2.2 }, { 0, -0.71, 0 }, Bronze),
		block("Bell9", { 2.4, 0.12, 2.4 }, { 0, -0.83, 0 }, BronzeDark),
		block("Hollow", { 2.1, 0.04, 2.1 }, { 0, -0.9, 0 }, Black),
		block("BandHigh", { 1.44, 0.06, 1.44 }, { 0, 0.745, 0 }, Verdigris),
		block("BandLow", { 1.77, 0.06, 1.77 }, { 0, -0.4, 0 }, Verdigris),
		block("Crown", { 0.7, 0.25, 0.7 }, { 0, 1.37, 0 }, Verdigris),
		block("Yoke", { 1.6, 0.3, 0.4 }, { 0, 1.65, 0 }, { 70, 50, 35 }),
		block("YokeStrapLeft", { 0.12, 0.4, 0.42 }, { -0.3, 1.42, 0 }, Iron),
		block("YokeStrapRight", { 0.12, 0.4, 0.42 }, { 0.3, 1.42, 0 }, Iron),
		block("Chain1", { 0.12, 0.25, 0.12 }, { 0, 1.93, 0 }, Iron),
		block("Chain2", { 0.25, 0.12, 0.12 }, { 0, 2.1, 0 }, Iron),
		tilt(block("Crack", { 0.05, 0.6, 0.04 }, { 0.5, 0.4, -0.73 }, Black), 0, 0, 25),
		block("LeftEye", { 0.26, 0.2, 0.06 }, { -0.33, 0.6, -0.73 }, { 90, 255, 220 }, true),
		block("RightEye", { 0.26, 0.2, 0.06 }, { 0.33, 0.6, -0.73 }, { 90, 255, 220 }, true),
		block("Mouth", { 0.7, 0.13, 0.06 }, { 0, 0.12, -0.78 }, Black),
		block("Patina1", { 0.5, 0.25, 0.05 }, { -0.45, -0.05, -0.8 }, Verdigris),
		block("Patina2", { 0.05, 0.35, 0.5 }, { 0.8, 0, 0.3 }, Verdigris),
		block("Barnacle1", { 0.15, 0.12, 0.08 }, { 0.55, -0.1, -0.82 }, { 220, 215, 200 }),
		block("Barnacle2", { 0.12, 0.1, 0.08 }, { 0.7, -0.35, -0.9 }, { 220, 215, 200 }),
		block("Barnacle3", { 0.15, 0.12, 0.08 }, { -0.6, 0.4, 0.74 }, { 220, 215, 200 }),
		block("Barnacle4", { 0.1, 0.15, 0.15 }, { 0.86, -0.25, -0.4 }, { 220, 215, 200 }),
		block("WeedFront2", { 0.16, 0.49, 0.05 }, { -0.26, 0.625, -0.735 }, { 35, 85, 45 }),
		block("WeedFront3", { 0.16, 0.44, 0.05 }, { -0.34, 0.2, -0.775 }, Seaweed),
		block("WeedFront5", { 0.16, 0.24, 0.05 }, { -0.34, -0.4, -0.9 }, Seaweed),
		block("WeedFront6", { 0.16, 0.19, 0.05 }, { -0.26, -0.575, -1 }, { 35, 85, 45 }),
		block("WeedFront8", { 0.16, 0.16, 0.05 }, { -0.26, -0.83, -1.225 }, { 35, 85, 45 }),
		block("WeedFrontTop", { 0.16, 0.06, 0.45 }, { -0.3, 1.27, -0.3 }, Seaweed),
		block("WeedBack1", { 0.16, 0.24, 0.05 }, { 0.36, 0.95, 0.675 }, Seaweed),
		block("WeedBack3", { 0.16, 0.44, 0.05 }, { 0.36, 0.2, 0.775 }, Seaweed),
		block("WeedBack4", { 0.16, 0.34, 0.05 }, { 0.44, -0.15, 0.825 }, { 35, 85, 45 }),
		block("WeedBack6", { 0.16, 0.19, 0.05 }, { 0.44, -0.575, 1 }, { 35, 85, 45 }),
		block("WeedBack7", { 0.16, 0.16, 0.05 }, { 0.36, -0.71, 1.125 }, Seaweed),
		block("WeedBackTop", { 0.16, 0.06, 0.45 }, { 0.4, 1.27, 0.3 }, Seaweed),
		block("WeedLeft1", { 0.05, 0.24, 0.16 }, { -0.675, 0.95, 0.06 }, Seaweed),
		block("WeedLeft3", { 0.05, 0.44, 0.16 }, { -0.775, 0.2, 0.06 }, Seaweed),
		block("WeedLeft4", { 0.05, 0.34, 0.16 }, { -0.825, -0.15, 0.14 }, { 35, 85, 45 }),
		block("WeedLeft6", { 0.05, 0.19, 0.16 }, { -1, -0.575, 0.14 }, { 35, 85, 45 }),
		block("WeedLeft7", { 0.05, 0.16, 0.16 }, { -1.125, -0.71, 0.06 }, Seaweed),
		block("WeedLeftTop", { 0.45, 0.06, 0.16 }, { -0.3, 1.27, 0.1 }, Seaweed),
		block("WeedRight2", { 0.05, 0.49, 0.16 }, { 0.735, 0.625, -0.16 }, { 35, 85, 45 }),
		block("WeedRight3", { 0.05, 0.44, 0.16 }, { 0.775, 0.2, -0.24 }, Seaweed),
		block("WeedRight5", { 0.05, 0.24, 0.16 }, { 0.9, -0.4, -0.24 }, Seaweed),
		block("WeedRight6", { 0.05, 0.19, 0.16 }, { 1, -0.575, -0.16 }, { 35, 85, 45 }),
		block("WeedRight8", { 0.05, 0.16, 0.16 }, { 1.225, -0.83, -0.16 }, { 35, 85, 45 }),
		block("WeedRightTop", { 0.45, 0.06, 0.16 }, { 0.3, 1.27, -0.2 }, Seaweed),
		block("WeedFrontRight1", { 0.16, 0.24, 0.05 }, { 0.46, 0.95, -0.675 }, Seaweed),
		block("WeedFrontRight3", { 0.16, 0.44, 0.05 }, { 0.46, 0.2, -0.775 }, Seaweed),
		block("WeedFrontRight4", { 0.16, 0.34, 0.05 }, { 0.54, -0.15, -0.825 }, { 35, 85, 45 }),
		block("WeedFrontRight6", { 0.16, 0.19, 0.05 }, { 0.54, -0.575, -1 }, { 35, 85, 45 }),
		block("WeedFrontRight7", { 0.16, 0.16, 0.05 }, { 0.46, -0.71, -1.125 }, Seaweed),
		block("WeedFrontRightTop", { 0.16, 0.06, 0.45 }, { 0.5, 1.27, -0.3 }, Seaweed),
		block("WeedBackLeft2", { 0.16, 0.49, 0.05 }, { -0.41, 0.625, 0.735 }, { 35, 85, 45 }),
		block("WeedBackLeft3", { 0.16, 0.44, 0.05 }, { -0.49, 0.2, 0.775 }, Seaweed),
		block("WeedBackLeft5", { 0.16, 0.24, 0.05 }, { -0.49, -0.4, 0.9 }, Seaweed),
		block("WeedBackLeft6", { 0.16, 0.19, 0.05 }, { -0.41, -0.575, 1 }, { 35, 85, 45 }),
		block("WeedBackLeft8", { 0.16, 0.16, 0.05 }, { -0.41, -0.83, 1.225 }, { 35, 85, 45 }),
		block("WeedBackLeftTop", { 0.16, 0.06, 0.45 }, { -0.45, 1.27, 0.3 }, Seaweed),
		block("WeedLeftBack2", { 0.05, 0.49, 0.16 }, { -0.735, 0.625, 0.59 }, { 35, 85, 45 }),
		block("WeedLeftBack3", { 0.05, 0.44, 0.16 }, { -0.775, 0.2, 0.51 }, Seaweed),
		block("WeedLeftBack5", { 0.05, 0.24, 0.16 }, { -0.9, -0.4, 0.51 }, Seaweed),
		block("WeedLeftBack6", { 0.05, 0.19, 0.16 }, { -1, -0.575, 0.59 }, { 35, 85, 45 }),
		block("WeedLeftBack8", { 0.05, 0.16, 0.16 }, { -1.225, -0.83, 0.59 }, { 35, 85, 45 }),
		block("WeedLeftBackTop", { 0.45, 0.06, 0.16 }, { -0.3, 1.27, 0.55 }, Seaweed),
		block("WeedRightFront1", { 0.05, 0.24, 0.16 }, { 0.675, 0.95, -0.64 }, Seaweed),
		block("WeedRightFront3", { 0.05, 0.44, 0.16 }, { 0.775, 0.2, -0.64 }, Seaweed),
		block("WeedRightFront4", { 0.05, 0.34, 0.16 }, { 0.825, -0.15, -0.56 }, { 35, 85, 45 }),
		block("WeedRightFront6", { 0.05, 0.19, 0.16 }, { 1, -0.575, -0.56 }, { 35, 85, 45 }),
		block("WeedRightFront7", { 0.05, 0.16, 0.16 }, { 1.125, -0.71, -0.64 }, Seaweed),
		block("WeedRightFrontTop", { 0.45, 0.06, 0.16 }, { 0.3, 1.27, -0.6 }, Seaweed),
		limb(
			"Hanging1",
			{ 0.15, 0.8, 0.15 },
			{ 1.003, -1.29, 0.31 },
			{ 35, 85, 45 },
			"Z",
			20,
			1.2,
			0,
			{ 0, 0.4, 0 }
		),
		limb(
			"Hanging2",
			{ 0.15, 1.2, 0.15 },
			{ 0.49, -1.49, 0.929 },
			Seaweed,
			"X",
			20,
			1.2,
			0.125,
			{ 0, 0.6, 0 }
		),
		limb(
			"Hanging3",
			{ 0.15, 1.6, 0.15 },
			{ -0.31, -1.69, 1.003 },
			{ 35, 85, 45 },
			"Z",
			20,
			1.2,
			0.25,
			{ 0, 0.8, 0 }
		),
		limb(
			"Hanging4",
			{ 0.15, 0.8, 0.15 },
			{ -0.929, -1.29, 0.49 },
			Seaweed,
			"X",
			20,
			1.2,
			0.375,
			{ 0, 0.4, 0 }
		),
		limb(
			"Hanging5",
			{ 0.15, 1.2, 0.15 },
			{ -1.003, -1.49, -0.31 },
			{ 35, 85, 45 },
			"Z",
			20,
			1.2,
			0.5,
			{ 0, 0.6, 0 }
		),
		limb(
			"Hanging6",
			{ 0.15, 1.6, 0.15 },
			{ -0.49, -1.69, -0.929 },
			Seaweed,
			"X",
			20,
			1.2,
			0.625,
			{ 0, 0.8, 0 }
		),
		limb(
			"Hanging7",
			{ 0.15, 0.8, 0.15 },
			{ 0.31, -1.29, -1.003 },
			{ 35, 85, 45 },
			"Z",
			20,
			1.2,
			0.75,
			{ 0, 0.4, 0 }
		),
		limb(
			"Hanging8",
			{ 0.15, 1.2, 0.15 },
			{ 0.929, -1.49, -0.49 },
			Seaweed,
			"X",
			20,
			1.2,
			0.875,
			{ 0, 0.6, 0 }
		),
		limb("ClapperRod", { 0.12, 1.2, 0.12 }, { 0, -0.3, 0 }, Iron, "X", 25, 2, 0, { 0, 0.8, 0 }),
		limb(
			"Clapper",
			{ 0.5, 0.5, 0.5 },
			{ 0, -1.1, 0 },
			{ 90, 255, 220 },
			"X",
			25,
			2,
			0,
			{ 0, 1.6, 0 },
			true
		),
	},
}

-- Zone 2, Legendary: the mud king of the bayou. A huge, wet, lumpy heap of dark mud with moss,
-- roots and bubbles in it, mud dripping from his mouth and his rusty crown, and a tattered cape
-- of moss strips swaying behind him.
Looks.TheBogKing = {
	gait = "walk",
	top = 2.6,
	wet = true,
	pieces = {
		block("Body", { 2.2, 1.9, 1.5 }, { 0, -0.25, 0 }, Mud),
		block("Belly", { 1.5, 1.1, 0.08 }, { 0, -0.4, -0.78 }, MudLight),
		block("BellyLump", { 0.6, 0.4, 0.15 }, { -0.3, -0.65, -0.8 }, Mud),
		block("LumpLeft", { 0.6, 0.7, 0.8 }, { -1.1, -0.6, 0.1 }, Mud),
		block("LumpRight", { 0.5, 0.6, 0.7 }, { 1.1, -0.2, -0.2 }, MudDark),
		block("LumpBack", { 1.2, 0.8, 0.4 }, { 0.2, -0.6, 0.8 }, MudDark),
		block("Hips", { 2, 0.4, 1.4 }, { 0, -1.25, 0 }, MudDark),
		block("Drip1", { 0.18, 0.6, 0.06 }, { -0.75, -0.1, -0.78 }, MudDark),
		block("Drip1End", { 0.24, 0.12, 0.08 }, { -0.75, -0.42, -0.78 }, MudDark),
		block("Drip2", { 0.15, 0.45, 0.06 }, { 0.8, -0.3, -0.78 }, MudDark),
		block("Drip3", { 0.15, 0.7, 0.06 }, { 0.35, -0.85, -0.79 }, MudDark),
		block("MossPatch1", { 0.6, 0.35, 0.06 }, { 0.55, 0.3, -0.78 }, { 60, 95, 45 }),
		block("MossPatch2", { 0.06, 0.5, 0.6 }, { -1.11, -0.1, -0.2 }, { 40, 70, 35 }),
		tilt(block("Root1", { 0.08, 0.5, 0.08 }, { 0.95, 0.5, -0.4 }, { 70, 50, 30 }), 0, 0, -35),
		tilt(block("Root2", { 0.07, 0.4, 0.07 }, { -0.9, 0.55, 0.3 }, { 70, 50, 30 }), 20, 0, 30),
		block("Bubble1", { 0.2, 0.2, 0.2 }, { -0.35, -0.15, -0.82 }, MudLight),
		block("Bubble2", { 0.14, 0.14, 0.14 }, { 0.15, -0.95, -0.82 }, MudLight),
		block("Head", { 1.4, 1.1, 1.2 }, { 0, 1.25, -0.1 }, Mud),
		block("HeadLump", { 0.6, 0.3, 0.6 }, { 0.3, 1.75, 0.1 }, MudDark),
		tilt(block("LeftBrow", { 0.5, 0.18, 0.2 }, { -0.35, 1.6, -0.65 }, MudDark), 0, 0, -15),
		tilt(block("RightBrow", { 0.5, 0.18, 0.2 }, { 0.35, 1.6, -0.65 }, MudDark), 0, 0, 15),
		block("LeftSocket", { 0.35, 0.3, 0.05 }, { -0.35, 1.4, -0.71 }, Black),
		block("RightSocket", { 0.35, 0.3, 0.05 }, { 0.35, 1.4, -0.71 }, Black),
		block("LeftEye", { 0.15, 0.15, 0.05 }, { -0.35, 1.4, -0.74 }, { 255, 150, 40 }, true),
		block("RightEye", { 0.15, 0.15, 0.05 }, { 0.35, 1.4, -0.74 }, { 255, 150, 40 }, true),
		block("Mouth", { 1, 0.3, 0.05 }, { 0, 0.95, -0.71 }, Black),
		block("Tooth1", { 0.1, 0.12, 0.04 }, { -0.35, 1.04, -0.74 }, Bone),
		block("Tooth2", { 0.1, 0.12, 0.04 }, { -0.12, 1.04, -0.74 }, Bone),
		block("Tooth3", { 0.1, 0.12, 0.04 }, { 0.12, 1.04, -0.74 }, Bone),
		block("Tooth4", { 0.1, 0.12, 0.04 }, { 0.35, 1.04, -0.74 }, Bone),
		block("MouthDrip1", { 0.12, 0.45, 0.06 }, { -0.25, 0.65, -0.71 }, MudDark),
		block("MouthDrip2", { 0.1, 0.3, 0.06 }, { 0.3, 0.72, -0.71 }, MudDark),
		block("Crown", { 1.5, 0.4, 1.3 }, { 0, 2, -0.1 }, { 190, 150, 60 }),
		block("CrownBand", { 1.52, 0.1, 1.32 }, { 0, 1.85, -0.1 }, Gold),
		block("LeftPoint", { 0.25, 0.4, 0.25 }, { -0.55, 2.38, -0.6 }, { 190, 150, 60 }),
		block("MiddleGem", { 0.3, 0.35, 0.25 }, { 0, 2.38, -0.6 }, { 80, 255, 120 }, true),
		block("RightPoint", { 0.25, 0.4, 0.25 }, { 0.55, 2.38, -0.6 }, { 190, 150, 60 }),
		block("BackPoint", { 0.25, 0.4, 0.25 }, { 0, 2.38, 0.4 }, { 190, 150, 60 }),
		block("CrownMoss", { 0.5, 0.12, 0.4 }, { 0.4, 2.22, 0.2 }, { 60, 95, 45 }),
		block("CrownDrip", { 0.12, 0.35, 0.06 }, { -0.4, 1.8, -0.77 }, MudDark),
		block("ShoulderMossLeft", { 0.7, 0.3, 0.9 }, { -0.85, 0.75, 0.2 }, { 40, 70, 35 }),
		block("ShoulderMossRight", { 0.7, 0.3, 0.9 }, { 0.85, 0.75, 0.2 }, { 60, 95, 45 }),
		limb(
			"Cape1",
			{ 0.42, 1.9, 0.12 },
			{ -0.8, -0.2, 0.82 },
			{ 40, 70, 35 },
			"X",
			12,
			1.2,
			0,
			{ 0, 0.95, 0 }
		),
		limb(
			"Cape1Tatter",
			{ 0.2, 0.2, 0.12 },
			{ -0.72, -1.25, 0.82 },
			{ 40, 70, 35 },
			"X",
			12,
			1.2,
			0,
			{ -0.08, 2, 0 }
		),
		limb(
			"Cape2",
			{ 0.42, 2.2, 0.12 },
			{ -0.4, -0.35, 0.82 },
			{ 60, 95, 45 },
			"X",
			12,
			1.2,
			0.08,
			{ 0, 1.1, 0 }
		),
		limb(
			"Cape2Tatter",
			{ 0.2, 0.2, 0.12 },
			{ -0.32, -1.55, 0.82 },
			{ 60, 95, 45 },
			"X",
			12,
			1.2,
			0.08,
			{ -0.08, 2.3, 0 }
		),
		limb("Cape3", { 0.42, 1.8, 0.12 }, { 0, -0.15, 0.82 }, Moss, "X", 12, 1.2, 0.16, { 0, 0.9, 0 }),
		limb(
			"Cape3Tatter",
			{ 0.2, 0.2, 0.12 },
			{ 0.08, -1.15, 0.82 },
			Moss,
			"X",
			12,
			1.2,
			0.16,
			{ -0.08, 1.9, 0 }
		),
		limb(
			"Cape4",
			{ 0.42, 2.1, 0.12 },
			{ 0.4, -0.3, 0.82 },
			{ 40, 70, 35 },
			"X",
			12,
			1.2,
			0.24,
			{ 0, 1.05, 0 }
		),
		limb(
			"Cape4Tatter",
			{ 0.2, 0.2, 0.12 },
			{ 0.48, -1.45, 0.82 },
			{ 40, 70, 35 },
			"X",
			12,
			1.2,
			0.24,
			{ -0.08, 2.2, 0 }
		),
		limb(
			"Cape5",
			{ 0.42, 1.7, 0.12 },
			{ 0.8, -0.1, 0.82 },
			{ 60, 95, 45 },
			"X",
			12,
			1.2,
			0.32,
			{ 0, 0.85, 0 }
		),
		limb(
			"Cape5Tatter",
			{ 0.2, 0.2, 0.12 },
			{ 0.88, -1.05, 0.82 },
			{ 60, 95, 45 },
			"X",
			12,
			1.2,
			0.32,
			{ -0.08, 1.8, 0 }
		),
		limb("Vine1", { 0.08, 1.4, 0.08 }, { -0.6, 0.05, 0.92 }, Moss, "X", 15, 1.2, 0.2, { 0, 0.7, 0 }),
		limb("Vine2", { 0.08, 1, 0.08 }, { 0.55, 0.25, 0.92 }, Moss, "X", 15, 1.2, 0.4, { 0, 0.5, 0 }),
		limb("LeftArm", { 0.6, 1.5, 0.6 }, { -1.4, -0.25, 0 }, Mud, "X", 25, 1.2, 0.5, { 0, 0.75, 0 }),
		limb(
			"LeftArmLump",
			{ 0.3, 0.4, 0.3 },
			{ -1.65, 0, -0.1 },
			MudDark,
			"X",
			25,
			1.2,
			0.5,
			{ 0.25, 0.5, 0.1 }
		),
		limb(
			"LeftArmDrip",
			{ 0.12, 0.4, 0.12 },
			{ -1.4, -1.15, 0.2 },
			MudDark,
			"X",
			25,
			1.2,
			0.5,
			{ 0, 1.65, -0.2 }
		),
		limb(
			"LeftFist",
			{ 0.7, 0.5, 0.7 },
			{ -1.4, -1.15, -0.05 },
			MudDark,
			"X",
			25,
			1.2,
			0.5,
			{ 0, 1.65, 0.05 }
		),
		limb(
			"LeftFinger1",
			{ 0.14, 0.25, 0.14 },
			{ -1.6, -1.47, -0.25 },
			MudDark,
			"X",
			25,
			1.2,
			0.5,
			{ 0.2, 1.97, 0.25 }
		),
		limb(
			"LeftFinger2",
			{ 0.14, 0.25, 0.14 },
			{ -1.4, -1.47, -0.25 },
			MudDark,
			"X",
			25,
			1.2,
			0.5,
			{ 0, 1.97, 0.25 }
		),
		limb(
			"LeftFinger3",
			{ 0.14, 0.25, 0.14 },
			{ -1.2, -1.47, -0.25 },
			MudDark,
			"X",
			25,
			1.2,
			0.5,
			{ -0.2, 1.97, 0.25 }
		),
		limb("RightArm", { 0.6, 1.5, 0.6 }, { 1.4, -0.25, 0 }, Mud, "X", 25, 1.2, 0, { 0, 0.75, 0 }),
		limb(
			"RightArmLump",
			{ 0.3, 0.4, 0.3 },
			{ 1.65, 0, -0.1 },
			MudDark,
			"X",
			25,
			1.2,
			0,
			{ -0.25, 0.5, 0.1 }
		),
		limb(
			"RightArmDrip",
			{ 0.12, 0.4, 0.12 },
			{ 1.4, -1.15, 0.2 },
			MudDark,
			"X",
			25,
			1.2,
			0,
			{ 0, 1.65, -0.2 }
		),
		limb(
			"RightFist",
			{ 0.7, 0.5, 0.7 },
			{ 1.4, -1.15, -0.05 },
			MudDark,
			"X",
			25,
			1.2,
			0,
			{ 0, 1.65, 0.05 }
		),
		limb(
			"RightFinger1",
			{ 0.14, 0.25, 0.14 },
			{ 1.2, -1.47, -0.25 },
			MudDark,
			"X",
			25,
			1.2,
			0,
			{ 0.2, 1.97, 0.25 }
		),
		limb(
			"RightFinger2",
			{ 0.14, 0.25, 0.14 },
			{ 1.4, -1.47, -0.25 },
			MudDark,
			"X",
			25,
			1.2,
			0,
			{ 0, 1.97, 0.25 }
		),
		limb(
			"RightFinger3",
			{ 0.14, 0.25, 0.14 },
			{ 1.6, -1.47, -0.25 },
			MudDark,
			"X",
			25,
			1.2,
			0,
			{ -0.2, 1.97, 0.25 }
		),
		limb("LeftLeg", { 0.65, 0.6, 0.65 }, { -0.5, -1.5, 0 }, MudDark, "X", 22, 1.2, 0, { 0, 0.3, 0 }),
		limb("LeftFoot", { 0.8, 0.2, 0.85 }, { -0.5, -1.9, -0.1 }, MudDark, "X", 22, 1.2, 0, { 0, 0.7, 0.1 }),
		limb("RightLeg", { 0.65, 0.6, 0.65 }, { 0.5, -1.5, 0 }, MudDark, "X", 22, 1.2, 0.5, { 0, 0.3, 0 }),
		limb(
			"RightFoot",
			{ 0.8, 0.2, 0.85 },
			{ 0.5, -1.9, -0.1 },
			MudDark,
			"X",
			22,
			1.2,
			0.5,
			{ 0, 0.7, 0.1 }
		),
	},
}

-- Zone 2, Mythic: a giant swamp snake slithering along the ground. Its head rears up with a glowing
-- hood and fangs, and every body segment slides side to side a bit later than the one before,
-- so a wave runs down its long body.
local Scale = { 40, 90, 85 }
local Stripe = { 160, 90, 255 }
local ScaleDark = { 25, 60, 55 }
Looks.MireSerpent = {
	gait = "walk",
	top = -0.2,
	pieces = {
		slide(limb("Body1", { 0.9, 0.7, 0.8 }, { 0, -1.65, -0.3 }, Scale, "X", -0.35, 0.8, 0, { 0, 0, 0 })),
		slide(
			limb(
				"Belly1",
				{ 0.63, 0.06, 0.7 },
				{ 0, -1.27, -0.3 },
				ScaleDark,
				"X",
				-0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"Body2",
				{ 0.9, 0.7, 0.8 },
				{ 0, -1.65, 0.42 },
				Stripe,
				"X",
				-0.35,
				0.8,
				0.1,
				{ 0, 0, 0 },
				true
			)
		),
		slide(
			limb(
				"Belly2",
				{ 0.63, 0.06, 0.7 },
				{ 0, -1.27, 0.42 },
				ScaleDark,
				"X",
				-0.35,
				0.8,
				0.1,
				{ 0, 0, 0 }
			)
		),
		slide(limb("Body3", { 0.9, 0.7, 0.8 }, { 0, -1.65, 1.14 }, Scale, "X", -0.35, 0.8, 0.2, { 0, 0, 0 })),
		slide(
			limb(
				"Belly3",
				{ 0.63, 0.06, 0.7 },
				{ 0, -1.27, 1.14 },
				ScaleDark,
				"X",
				-0.35,
				0.8,
				0.2,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"Body4",
				{ 0.9, 0.7, 0.8 },
				{ 0, -1.65, 1.86 },
				Stripe,
				"X",
				-0.35,
				0.8,
				0.3,
				{ 0, 0, 0 },
				true
			)
		),
		slide(
			limb(
				"Belly4",
				{ 0.63, 0.06, 0.7 },
				{ 0, -1.27, 1.86 },
				ScaleDark,
				"X",
				-0.35,
				0.8,
				0.3,
				{ 0, 0, 0 }
			)
		),
		slide(limb("Body5", { 0.9, 0.7, 0.8 }, { 0, -1.65, 2.58 }, Scale, "X", -0.35, 0.8, 0.4, { 0, 0, 0 })),
		slide(
			limb(
				"Belly5",
				{ 0.63, 0.06, 0.7 },
				{ 0, -1.27, 2.58 },
				ScaleDark,
				"X",
				-0.35,
				0.8,
				0.4,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"Body6",
				{ 0.9, 0.7, 0.8 },
				{ 0, -1.65, 3.3 },
				Stripe,
				"X",
				-0.35,
				0.8,
				0.5,
				{ 0, 0, 0 },
				true
			)
		),
		slide(
			limb(
				"Belly6",
				{ 0.63, 0.06, 0.7 },
				{ 0, -1.27, 3.3 },
				ScaleDark,
				"X",
				-0.35,
				0.8,
				0.5,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb("Body7", { 0.78, 0.62, 0.8 }, { 0, -1.69, 4.02 }, Scale, "X", -0.35, 0.8, 0.6, { 0, 0, 0 })
		),
		slide(
			limb(
				"Belly7",
				{ 0.546, 0.06, 0.7 },
				{ 0, -1.35, 4.02 },
				ScaleDark,
				"X",
				-0.35,
				0.8,
				0.6,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"Body8",
				{ 0.66, 0.54, 0.8 },
				{ 0, -1.73, 4.74 },
				Stripe,
				"X",
				-0.35,
				0.8,
				0.7,
				{ 0, 0, 0 },
				true
			)
		),
		slide(
			limb(
				"Belly8",
				{ 0.462, 0.06, 0.7 },
				{ 0, -1.43, 4.74 },
				ScaleDark,
				"X",
				-0.35,
				0.8,
				0.7,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb("Body9", { 0.54, 0.46, 0.8 }, { 0, -1.77, 5.46 }, Scale, "X", -0.35, 0.8, 0.8, { 0, 0, 0 })
		),
		slide(
			limb(
				"Belly9",
				{ 0.378, 0.06, 0.7 },
				{ 0, -1.51, 5.46 },
				ScaleDark,
				"X",
				-0.35,
				0.8,
				0.8,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"Body10",
				{ 0.42, 0.38, 0.8 },
				{ 0, -1.81, 6.18 },
				Stripe,
				"X",
				-0.35,
				0.8,
				0.9,
				{ 0, 0, 0 },
				true
			)
		),
		slide(
			limb(
				"Belly10",
				{ 0.294, 0.06, 0.7 },
				{ 0, -1.59, 6.18 },
				ScaleDark,
				"X",
				-0.35,
				0.8,
				0.9,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"TailTip",
				{ 0.3, 0.25, 0.7 },
				{ 0, -1.875, 6.9 },
				Stripe,
				"X",
				-0.35,
				0.8,
				1,
				{ 0, 0, 0 },
				true
			)
		),
		slide(limb("Neck", { 0.8, 0.8, 0.7 }, { 0, -1.2, -0.8 }, Scale, "X", -0.35, 0.8, 0, { 0, 0, 0 })),
		slide(limb("Head", { 1, 0.8, 1.3 }, { 0, -0.65, -1.35 }, Scale, "X", -0.35, 0.8, 0, { 0, 0, 0 })),
		slide(limb("Snout", { 0.8, 0.4, 0.4 }, { 0, -0.75, -2.15 }, Scale, "X", -0.35, 0.8, 0, { 0, 0, 0 })),
		slide(
			limb(
				"LeftEye",
				{ 0.2, 0.2, 0.1 },
				{ -0.3, -0.4, -2.02 },
				{ 255, 230, 60 },
				"X",
				-0.35,
				0.8,
				0,
				{ 0, 0, 0 },
				true
			)
		),
		slide(
			limb(
				"RightEye",
				{ 0.2, 0.2, 0.1 },
				{ 0.3, -0.4, -2.02 },
				{ 255, 230, 60 },
				"X",
				-0.35,
				0.8,
				0,
				{ 0, 0, 0 },
				true
			)
		),
		slide(
			limb(
				"LeftSlit",
				{ 0.05, 0.18, 0.05 },
				{ -0.3, -0.4, -2.08 },
				Black,
				"X",
				-0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"RightSlit",
				{ 0.05, 0.18, 0.05 },
				{ 0.3, -0.4, -2.08 },
				Black,
				"X",
				-0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(limb("Jaw", { 0.8, 0.2, 1.2 }, { 0, -1.2, -1.65 }, ScaleDark, "X", -0.35, 0.8, 0, { 0, 0, 0 })),
		slide(
			limb("LeftFang", { 0.1, 0.3, 0.1 }, { -0.25, -1, -2.15 }, White, "X", -0.35, 0.8, 0, { 0, 0, 0 })
		),
		slide(
			limb("RightFang", { 0.1, 0.3, 0.1 }, { 0.25, -1, -2.15 }, White, "X", -0.35, 0.8, 0, { 0, 0, 0 })
		),
		slide(
			limb("Tongue", { 0.08, 0.06, 0.5 }, { 0, -1.08, -2.45 }, Blood, "X", -0.35, 0.8, 0, { 0, 0, 0 })
		),
		slide(
			limb(
				"LeftHood",
				{ 0.1, 0.9, 0.8 },
				{ -0.55, -0.7, -1.1 },
				Stripe,
				"X",
				-0.35,
				0.8,
				0,
				{ 0, 0, 0 },
				true
			)
		),
		slide(
			limb(
				"RightHood",
				{ 0.1, 0.9, 0.8 },
				{ 0.55, -0.7, -1.1 },
				Stripe,
				"X",
				-0.35,
				0.8,
				0,
				{ 0, 0, 0 },
				true
			)
		),
	},
}

-- Zone 2, Divine: a ghoulish heron that stalks the moonlit marsh. Its ribs show through its sides,
-- its wings are torn, its eyes glow in hollow sockets, and its long serrated beak drips blood.
local Silver = { 225, 230, 245 }
local Moonglow = { 170, 210, 255 }
Looks.MoonlitHeron = {
	gait = "walk",
	top = 2.4,
	pieces = {
		block("Body", { 1, 1, 1.8 }, { 0, 0.1, 0.1 }, { 150, 155, 170 }),
		block("Back", { 0.9, 0.2, 1.4 }, { 0, 0.65, 0.2 }, { 75, 80, 95 }),
		block("LeftRib1", { 0.05, 0.6, 0.08 }, { -0.51, 0, -0.4 }, Bone),
		block("LeftRib2", { 0.05, 0.6, 0.08 }, { -0.51, 0, -0.15 }, Bone),
		block("LeftRib3", { 0.05, 0.6, 0.08 }, { -0.51, 0, 0.1 }, Bone),
		block("LeftRib4", { 0.05, 0.6, 0.08 }, { -0.51, 0, 0.35 }, Bone),
		block("RightRib1", { 0.05, 0.6, 0.08 }, { 0.51, 0, -0.4 }, Bone),
		block("RightRib2", { 0.05, 0.6, 0.08 }, { 0.51, 0, -0.15 }, Bone),
		block("RightRib3", { 0.05, 0.6, 0.08 }, { 0.51, 0, 0.1 }, Bone),
		block("RightRib4", { 0.05, 0.6, 0.08 }, { 0.51, 0, 0.35 }, Bone),
		block("LeftRibGap", { 0.04, 0.55, 0.9 }, { -0.505, 0, 0 }, Black),
		block("RightRibGap", { 0.04, 0.55, 0.9 }, { 0.505, 0, 0 }, Black),
		tilt(block("NeckLow", { 0.3, 0.75, 0.3 }, { 0, 0.85, -0.75 }, { 150, 155, 170 }), -35, 0, 0),
		tilt(block("NeckHigh", { 0.28, 0.65, 0.28 }, { 0, 1.4, -0.85 }, { 150, 155, 170 }), 25, 0, 0),
		block("Head", { 0.5, 0.45, 0.6 }, { 0, 1.8, -0.95 }, { 75, 80, 95 }),
		block("LeftSocket", { 0.05, 0.2, 0.22 }, { -0.26, 1.85, -1.05 }, Black),
		block("RightSocket", { 0.05, 0.2, 0.22 }, { 0.26, 1.85, -1.05 }, Black),
		block("LeftEye", { 0.05, 0.08, 0.08 }, { -0.28, 1.85, -1.07 }, Moonglow, true),
		block("RightEye", { 0.05, 0.08, 0.08 }, { 0.28, 1.85, -1.07 }, Moonglow, true),
		block("Beak", { 0.15, 0.15, 1.2 }, { 0, 1.72, -1.85 }, Iron),
		block("BeakLower", { 0.12, 0.08, 1 }, { 0, 1.6, -1.75 }, Iron),
		block("BeakTooth1", { 0.05, 0.08, 0.05 }, { 0, 1.53, -1.4 }, Bone),
		block("BeakTooth2", { 0.05, 0.08, 0.05 }, { 0, 1.53, -1.6 }, Bone),
		block("BeakTooth3", { 0.05, 0.08, 0.05 }, { 0, 1.53, -1.8 }, Bone),
		block("BeakTooth4", { 0.05, 0.08, 0.05 }, { 0, 1.53, -2 }, Bone),
		block("BeakBlood", { 0.17, 0.17, 0.25 }, { 0, 1.7, -2.35 }, Blood),
		block("BloodDrip", { 0.05, 0.25, 0.05 }, { 0, 1.5, -2.35 }, Blood),
		tilt(block("Crest1", { 0.06, 0.5, 0.12 }, { 0, 2.1, -0.8 }, { 75, 80, 95 }), 40, 0, 0),
		tilt(block("Crest2", { 0.06, 0.45, 0.12 }, { 0.1, 2.05, -0.7 }, { 75, 80, 95 }), 55, 0, 15),
		tilt(block("Crest3", { 0.06, 0.4, 0.12 }, { -0.1, 2, -0.65 }, { 75, 80, 95 }), 60, 0, -15),
		tilt(block("Tail1", { 0.15, 0.12, 0.7 }, { -0.2, 0.2, 1.3 }, { 75, 80, 95 }), -15, 0, 0),
		tilt(block("Tail2", { 0.15, 0.12, 0.8 }, { 0, 0.25, 1.35 }, { 75, 80, 95 }), -20, 0, 0),
		tilt(block("Tail3", { 0.15, 0.12, 0.65 }, { 0.2, 0.2, 1.28 }, { 75, 80, 95 }), -15, 0, 0),
		limb(
			"LeftWing",
			{ 0.12, 0.8, 1.6 },
			{ -0.6, 0.15, 0.2 },
			{ 150, 155, 170 },
			"Z",
			25,
			1,
			0,
			{ 0.02, 0.4, 0 }
		),
		limb(
			"LeftWingBone",
			{ 0.14, 0.1, 1.7 },
			{ -0.62, 0.52, 0.15 },
			Bone,
			"Z",
			25,
			1,
			0,
			{ 0.04, 0.03, 0.05 }
		),
		limb(
			"LeftTatter1",
			{ 0.1, 0.3, 0.25 },
			{ -0.6, -0.4, -0.3 },
			{ 75, 80, 95 },
			"Z",
			25,
			1,
			0,
			{ 0.02, 0.95, 0.5 }
		),
		limb(
			"LeftTatter2",
			{ 0.1, 0.45, 0.3 },
			{ -0.6, -0.45, 0.5 },
			{ 75, 80, 95 },
			"Z",
			25,
			1,
			0,
			{ 0.02, 1, -0.3 }
		),
		limb(
			"LeftTatter3",
			{ 0.1, 0.25, 0.2 },
			{ -0.6, -0.35, 0.9 },
			{ 75, 80, 95 },
			"Z",
			25,
			1,
			0,
			{ 0.02, 0.9, -0.7 }
		),
		limb(
			"RightWing",
			{ 0.12, 0.8, 1.6 },
			{ 0.6, 0.15, 0.2 },
			{ 150, 155, 170 },
			"Z",
			-25,
			1,
			0,
			{ -0.02, 0.4, 0 }
		),
		limb(
			"RightWingBone",
			{ 0.14, 0.1, 1.7 },
			{ 0.62, 0.52, 0.15 },
			Bone,
			"Z",
			-25,
			1,
			0,
			{ -0.04, 0.03, 0.05 }
		),
		limb(
			"RightTatter1",
			{ 0.1, 0.3, 0.25 },
			{ 0.6, -0.4, -0.3 },
			{ 75, 80, 95 },
			"Z",
			-25,
			1,
			0,
			{ -0.02, 0.95, 0.5 }
		),
		limb(
			"RightTatter2",
			{ 0.1, 0.45, 0.3 },
			{ 0.6, -0.45, 0.5 },
			{ 75, 80, 95 },
			"Z",
			-25,
			1,
			0,
			{ -0.02, 1, -0.3 }
		),
		limb(
			"RightTatter3",
			{ 0.1, 0.25, 0.2 },
			{ 0.6, -0.35, 0.9 },
			{ 75, 80, 95 },
			"Z",
			-25,
			1,
			0,
			{ -0.02, 0.9, -0.7 }
		),
		limb(
			"LeftLeg",
			{ 0.13, 1.5, 0.13 },
			{ -0.25, -1.15, 0 },
			{ 75, 80, 95 },
			"X",
			25,
			1,
			0,
			{ 0, 0.75, 0 }
		),
		limb("LeftKnee", { 0.2, 0.18, 0.2 }, { -0.25, -1, 0 }, Bone, "X", 25, 1, 0, { 0, 0.6, 0 }),
		limb(
			"LeftFoot",
			{ 0.2, 0.08, 0.2 },
			{ -0.25, -1.96, 0 },
			{ 75, 80, 95 },
			"X",
			25,
			1,
			0,
			{ 0, 1.56, 0 }
		),
		limb(
			"LeftTalon1",
			{ 0.05, 0.07, 0.35 },
			{ -0.37, -1.965, -0.25 },
			Bone,
			"X",
			25,
			1,
			0,
			{ 0.12, 1.565, 0.25 }
		),
		limb(
			"LeftTalon2",
			{ 0.05, 0.07, 0.35 },
			{ -0.25, -1.965, -0.25 },
			Bone,
			"X",
			25,
			1,
			0,
			{ 0, 1.565, 0.25 }
		),
		limb(
			"LeftTalon3",
			{ 0.05, 0.07, 0.35 },
			{ -0.13, -1.965, -0.25 },
			Bone,
			"X",
			25,
			1,
			0,
			{ -0.12, 1.565, 0.25 }
		),
		limb(
			"RightLeg",
			{ 0.13, 1.5, 0.13 },
			{ 0.25, -1.15, 0 },
			{ 75, 80, 95 },
			"X",
			25,
			1,
			0.5,
			{ 0, 0.75, 0 }
		),
		limb("RightKnee", { 0.2, 0.18, 0.2 }, { 0.25, -1, 0 }, Bone, "X", 25, 1, 0.5, { 0, 0.6, 0 }),
		limb(
			"RightFoot",
			{ 0.2, 0.08, 0.2 },
			{ 0.25, -1.96, 0 },
			{ 75, 80, 95 },
			"X",
			25,
			1,
			0.5,
			{ 0, 1.56, 0 }
		),
		limb(
			"RightTalon1",
			{ 0.05, 0.07, 0.35 },
			{ 0.13, -1.965, -0.25 },
			Bone,
			"X",
			25,
			1,
			0.5,
			{ 0.12, 1.565, 0.25 }
		),
		limb(
			"RightTalon2",
			{ 0.05, 0.07, 0.35 },
			{ 0.25, -1.965, -0.25 },
			Bone,
			"X",
			25,
			1,
			0.5,
			{ 0, 1.565, 0.25 }
		),
		limb(
			"RightTalon3",
			{ 0.05, 0.07, 0.35 },
			{ 0.37, -1.965, -0.25 },
			Bone,
			"X",
			25,
			1,
			0.5,
			{ -0.12, 1.565, 0.25 }
		),
	},
}

-- Zone 3: Abandoned Carnival. Faded circus stripes, chipped paint and sinister grins.
local CircusRed = { 185, 40, 50 }
local CircusCream = { 238, 222, 185 }
local CircusTeal = { 40, 145, 145 }
local Popcorn = { 250, 235, 160 }
local Faded = { 110, 40, 60 }
local PopRed = { 205, 35, 40 }

-- Zone 3, Common: a striped popcorn bucket with a toothy grin, waddling on little legs. Its
-- popcorn is heaped high, half of it soaked red, and red drips run down the bucket.
Looks.Poplet = {
	gait = "walk",
	top = 1.3,
	pieces = {
		block("Bucket", { 1.4, 1.6, 1.4 }, { 0, -0.9, 0 }, CircusCream),
		block("LeftStripe", { 0.25, 1.62, 1.42 }, { -0.45, -0.9, 0 }, CircusRed),
		block("MiddleStripe", { 0.25, 1.62, 1.42 }, { 0, -0.9, 0 }, CircusRed),
		block("RightStripe", { 0.25, 1.62, 1.42 }, { 0.45, -0.9, 0 }, CircusRed),
		block("Rim", { 1.5, 0.15, 1.5 }, { 0, -0.15, 0 }, CircusRed),
		block("Kernel1", { 0.5, 0.45, 0.5 }, { -0.35, 0.25, -0.3 }, Popcorn),
		block("Kernel2", { 0.55, 0.5, 0.5 }, { 0.35, 0.3, 0.2 }, PopRed),
		block("Kernel3", { 0.55, 0.5, 0.55 }, { 0, 0.6, 0 }, Popcorn),
		block("Kernel4", { 0.45, 0.45, 0.45 }, { -0.35, 0.3, 0.35 }, PopRed),
		block("Kernel5", { 0.45, 0.4, 0.4 }, { 0.4, 0.2, -0.4 }, Popcorn),
		block("Kernel6", { 0.4, 0.4, 0.4 }, { -0.15, 0.85, -0.15 }, PopRed),
		block("Kernel7", { 0.4, 0.35, 0.4 }, { 0.25, 0.8, 0.25 }, Popcorn),
		block("Kernel8", { 0.35, 0.35, 0.35 }, { 0.05, 1.1, 0.05 }, Popcorn),
		block("Kernel9", { 0.4, 0.4, 0.4 }, { -0.55, 0.15, -0.05 }, Popcorn),
		block("Kernel10", { 0.4, 0.4, 0.4 }, { 0.55, 0.15, -0.05 }, PopRed),
		block("Kernel11", { 0.35, 0.3, 0.35 }, { 0.1, 0.3, -0.5 }, Popcorn),
		block("Kernel12", { 0.35, 0.35, 0.35 }, { -0.1, 0.45, 0.5 }, Popcorn),
		block("Kernel13", { 0.3, 0.3, 0.3 }, { 0.3, 0.6, -0.25 }, PopRed),
		block("Kernel14", { 0.3, 0.3, 0.3 }, { -0.4, 0.6, 0.05 }, Popcorn),
		tilt(block("SpillLeft", { 0.3, 0.3, 0.3 }, { -0.8, -0.2, 0.3 }, Popcorn), 0, 0, 30),
		tilt(block("SpillRight", { 0.3, 0.3, 0.3 }, { 0.8, -0.3, -0.2 }, PopRed), 0, 0, -20),
		block("DripLeft", { 0.12, 0.45, 0.05 }, { -0.55, -0.37, -0.73 }, PopRed),
		block("DripLeftEnd", { 0.08, 0.1, 0.05 }, { -0.55, -0.65, -0.73 }, PopRed),
		block("DripRight", { 0.12, 0.3, 0.05 }, { 0.55, -0.3, -0.73 }, PopRed),
		block("DripBack", { 0.12, 0.6, 0.05 }, { 0.2, -0.45, 0.73 }, PopRed),
		block("Mound", { 1.3, 0.3, 1.3 }, { 0, 0, 0 }, Popcorn),
		block("LeftEye", { 0.28, 0.28, 0.05 }, { -0.3, -0.55, -0.73 }, Black),
		block("RightEye", { 0.28, 0.28, 0.05 }, { 0.3, -0.55, -0.73 }, Black),
		block("LeftPupil", { 0.1, 0.1, 0.05 }, { -0.3, -0.55, -0.76 }, Candle, true),
		block("RightPupil", { 0.1, 0.1, 0.05 }, { 0.3, -0.55, -0.76 }, Candle, true),
		block("Mouth", { 0.7, 0.18, 0.05 }, { 0, -1.05, -0.73 }, Black),
		block("ToothLeft", { 0.12, 0.12, 0.05 }, { -0.2, -1, -0.76 }, White),
		block("ToothRight", { 0.12, 0.12, 0.05 }, { 0.15, -1, -0.76 }, White),
		limb("LeftArm", { 0.2, 0.6, 0.2 }, { -0.82, -0.9, 0 }, CircusCream, "X", 35, 2.5, 0.5, { 0, 0.3, 0 }),
		limb("RightArm", { 0.2, 0.6, 0.2 }, { 0.82, -0.9, 0 }, CircusCream, "X", 35, 2.5, 0, { 0, 0.3, 0 }),
		limb("LeftLeg", { 0.25, 0.3, 0.25 }, { -0.35, -1.85, 0 }, Black, "X", 30, 2.5, 0, { 0, 0.15, 0 }),
		limb("RightLeg", { 0.25, 0.3, 0.25 }, { 0.35, -1.85, 0 }, Black, "X", 30, 2.5, 0.5, { 0, 0.15, 0 }),
	},
}

-- Zone 3, Common: a sad red carnival balloon, crying glowing tears, its string swaying below.
Looks.BalloonBoo = {
	gait = "float",
	top = 1.4,
	pieces = {
		block("Balloon", { 1.4, 1.6, 1.4 }, { 0, 0.5, 0 }, CircusRed),
		block("BalloonTop", { 1, 0.25, 1 }, { 0, 1.4, 0 }, CircusRed),
		block("Shine", { 0.18, 0.3, 0.05 }, { 0.52, 1.1, -0.72 }, White, true),
		block("ShineDot", { 0.1, 0.1, 0.05 }, { 0.52, 0.88, -0.72 }, White, true),
		block("LeftEye", { 0.25, 0.3, 0.05 }, { -0.3, 0.65, -0.72 }, Black),
		block("RightEye", { 0.25, 0.3, 0.05 }, { 0.3, 0.65, -0.72 }, Black),
		block("LeftGlint", { 0.07, 0.07, 0.05 }, { -0.36, 0.73, -0.75 }, White),
		block("RightGlint", { 0.07, 0.07, 0.05 }, { 0.24, 0.73, -0.75 }, White),
		tilt(block("LeftBrow", { 0.36, 0.07, 0.05 }, { -0.3, 0.92, -0.72 }, Black), 0, 0, 22),
		tilt(block("RightBrow", { 0.36, 0.07, 0.05 }, { 0.3, 0.92, -0.72 }, Black), 0, 0, -22),
		block("Frown", { 0.5, 0.1, 0.05 }, { 0, 0.3, -0.72 }, Black),
		block("FrownLeft", { 0.12, 0.2, 0.05 }, { -0.29, 0.2, -0.72 }, Black),
		block("FrownRight", { 0.12, 0.2, 0.05 }, { 0.29, 0.2, -0.72 }, Black),
		block("LeftTear", { 0.1, 0.3, 0.05 }, { -0.36, 0.38, -0.74 }, { 140, 200, 255 }, true),
		block("LeftTearDrop", { 0.12, 0.12, 0.05 }, { -0.36, 0.13, -0.74 }, { 140, 200, 255 }, true),
		block("RightTear", { 0.1, 0.18, 0.05 }, { 0.36, 0.43, -0.74 }, { 140, 200, 255 }, true),
		block("Wrinkle", { 0.05, 0.4, 0.05 }, { -0.55, -0.05, -0.71 }, Faded),
		block("Knot", { 0.3, 0.25, 0.3 }, { 0, -0.42, 0 }, Faded),
		limb("String1", { 0.08, 0.6, 0.08 }, { 0, -0.85, 0 }, White, "X", 15, 1, 0, { 0, 0.3, 0 }),
		limb("String2", { 0.08, 0.6, 0.08 }, { 0, -1.45, 0 }, White, "X", 20, 1, 0.2, { 0, 0.9, 0 }),
	},
}

-- Zone 3, Uncommon: a green gremlin in a carnival usher's uniform (gold-trimmed jacket, bow tie,
-- pillbox cap), clutching a big roll of tickets that unspools as it waddles.
local Gremlin = { 100, 140, 70 }
local GremlinDark = { 70, 100, 50 }
Looks.TicketGremlin = {
	gait = "walk",
	top = 0.85,
	pieces = {
		block("Body", { 1, 1, 0.8 }, { 0, -1, 0 }, Gremlin),
		block("Jacket", { 1.05, 0.7, 0.85 }, { 0, -0.93, 0 }, CircusRed),
		block("Collar", { 1.08, 0.12, 0.88 }, { 0, -0.62, 0 }, Gold),
		block("JacketHem", { 1.07, 0.08, 0.87 }, { 0, -1.27, 0 }, Gold),
		block("Shorts", { 1.02, 0.22, 0.82 }, { 0, -1.4, 0 }, Black),
		block("BowTie", { 0.36, 0.14, 0.05 }, { 0, -0.7, -0.45 }, Black),
		block("BowKnot", { 0.1, 0.1, 0.06 }, { 0, -0.7, -0.47 }, CircusRed),
		block("Button1", { 0.08, 0.08, 0.05 }, { -0.15, -0.88, -0.45 }, Gold),
		block("Button2", { 0.08, 0.08, 0.05 }, { 0.15, -0.88, -0.45 }, Gold),
		block("Button3", { 0.08, 0.08, 0.05 }, { -0.15, -1.1, -0.45 }, Gold),
		block("Button4", { 0.08, 0.08, 0.05 }, { 0.15, -1.1, -0.45 }, Gold),
		block("Pocket", { 0.25, 0.18, 0.05 }, { -0.33, -0.95, -0.45 }, { 140, 25, 35 }),
		block("PocketTicket", { 0.14, 0.18, 0.05 }, { -0.33, -0.82, -0.46 }, { 245, 205, 130 }),
		block("LeftEpaulette", { 0.25, 0.1, 0.45 }, { -0.5, -0.6, 0 }, Gold),
		block("RightEpaulette", { 0.25, 0.1, 0.45 }, { 0.5, -0.6, 0 }, Gold),
		block("Head", { 1.1, 0.9, 0.9 }, { 0, -0.05, -0.05 }, Gremlin),
		block("Cap", { 0.6, 0.35, 0.6 }, { 0, 0.57, 0 }, CircusRed),
		block("CapBand", { 0.62, 0.08, 0.62 }, { 0, 0.45, 0 }, Gold),
		block("CapButton", { 0.15, 0.08, 0.15 }, { 0, 0.78, 0 }, Gold),
		block("CapBadge", { 0.15, 0.15, 0.05 }, { 0, 0.6, -0.32 }, Gold),
		block("ChinStrap", { 0.04, 0.5, 0.04 }, { 0.5, 0.2, -0.2 }, Black),
		block("LeftEye", { 0.25, 0.22, 0.05 }, { -0.25, 0.08, -0.52 }, { 255, 230, 60 }, true),
		block("RightEye", { 0.25, 0.22, 0.05 }, { 0.25, 0.08, -0.52 }, { 255, 230, 60 }, true),
		block("LeftPupil", { 0.07, 0.15, 0.05 }, { -0.25, 0.08, -0.55 }, Black),
		block("RightPupil", { 0.07, 0.15, 0.05 }, { 0.25, 0.08, -0.55 }, Black),
		tilt(block("LeftBrow", { 0.3, 0.06, 0.05 }, { -0.25, 0.25, -0.52 }, GremlinDark), 0, 0, -20),
		tilt(block("RightBrow", { 0.3, 0.06, 0.05 }, { 0.25, 0.25, -0.52 }, GremlinDark), 0, 0, 20),
		block("Nose", { 0.2, 0.2, 0.2 }, { 0, -0.12, -0.6 }, GremlinDark),
		block("Mouth", { 0.6, 0.12, 0.05 }, { 0, -0.32, -0.52 }, Black),
		block("ToothLeft", { 0.1, 0.12, 0.05 }, { -0.18, -0.28, -0.55 }, White),
		block("ToothRight", { 0.1, 0.12, 0.05 }, { 0.18, -0.28, -0.55 }, White),
		tilt(
			limb("LeftEar", { 0.6, 0.35, 0.12 }, { -0.8, 0.1, 0 }, GremlinDark, "Z", 10, 2, 0, { 0.3, 0, 0 }),
			0,
			0,
			-20
		),
		tilt(
			limb(
				"RightEar",
				{ 0.6, 0.35, 0.12 },
				{ 0.8, 0.1, 0 },
				GremlinDark,
				"Z",
				-10,
				2,
				0,
				{ -0.3, 0, 0 }
			),
			0,
			0,
			20
		),
		limb(
			"LeftArm",
			{ 0.25, 0.55, 0.25 },
			{ -0.62, -0.92, 0 },
			CircusRed,
			"X",
			30,
			2,
			0.5,
			{ 0, 0.27, 0 }
		),
		limb("LeftCuff", { 0.27, 0.08, 0.27 }, { -0.62, -1.2, 0 }, Gold, "X", 30, 2, 0.5, { 0, 0.55, 0 }),
		limb("LeftHand", { 0.22, 0.18, 0.22 }, { -0.62, -1.33, 0 }, Gremlin, "X", 30, 2, 0.5, { 0, 0.68, 0 }),
		limb("RightArm", { 0.25, 0.55, 0.25 }, { 0.62, -0.92, 0 }, CircusRed, "X", 30, 2, 0, { 0, 0.27, 0 }),
		limb("RightCuff", { 0.27, 0.08, 0.27 }, { 0.62, -1.2, 0 }, Gold, "X", 30, 2, 0, { 0, 0.55, 0 }),
		limb("RightHand", { 0.22, 0.18, 0.22 }, { 0.62, -1.33, 0 }, Gremlin, "X", 30, 2, 0, { 0, 0.68, 0 }),
		limb(
			"TicketRoll",
			{ 0.3, 0.5, 0.5 },
			{ 0.72, -1.4, -0.25 },
			{ 245, 205, 130 },
			"X",
			30,
			2,
			0,
			{ -0.1, 0.75, 0.25 }
		),
		limb(
			"RollEdgeLeft",
			{ 0.04, 0.52, 0.52 },
			{ 0.57, -1.4, -0.25 },
			{ 230, 120, 60 },
			"X",
			30,
			2,
			0,
			{ 0.05, 0.75, 0.25 }
		),
		limb(
			"RollEdgeRight",
			{ 0.04, 0.52, 0.52 },
			{ 0.87, -1.4, -0.25 },
			{ 230, 120, 60 },
			"X",
			30,
			2,
			0,
			{ -0.25, 0.75, 0.25 }
		),
		limb(
			"RollCore",
			{ 0.34, 0.16, 0.16 },
			{ 0.72, -1.4, -0.25 },
			Wood,
			"X",
			30,
			2,
			0,
			{ -0.1, 0.75, 0.25 }
		),
		limb(
			"TicketStrip",
			{ 0.24, 0.04, 0.5 },
			{ 0.72, -1.63, -0.7 },
			{ 245, 205, 130 },
			"X",
			30,
			2,
			0,
			{ -0.1, 0.98, 0.7 }
		),
		limb(
			"TicketEnd",
			{ 0.24, 0.25, 0.04 },
			{ 0.72, -1.76, -0.95 },
			{ 245, 205, 130 },
			"X",
			30,
			2,
			0,
			{ -0.1, 1.11, 0.95 }
		),
		limb(
			"Perforation1",
			{ 0.25, 0.05, 0.03 },
			{ 0.72, -1.6, -0.6 },
			{ 150, 110, 70 },
			"X",
			30,
			2,
			0,
			{ -0.1, 0.95, 0.6 }
		),
		limb(
			"Perforation2",
			{ 0.25, 0.05, 0.03 },
			{ 0.72, -1.6, -0.85 },
			{ 150, 110, 70 },
			"X",
			30,
			2,
			0,
			{ -0.1, 0.95, 0.85 }
		),
		limb(
			"TicketPrint",
			{ 0.14, 0.02, 0.12 },
			{ 0.72, -1.6, -0.72 },
			CircusRed,
			"X",
			30,
			2,
			0,
			{ -0.1, 0.95, 0.72 }
		),
		limb("LeftLeg", { 0.3, 0.5, 0.3 }, { -0.3, -1.75, 0 }, GremlinDark, "X", 30, 2, 0, { 0, 0.25, 0 }),
		limb("RightLeg", { 0.3, 0.5, 0.3 }, { 0.3, -1.75, 0 }, GremlinDark, "X", 30, 2, 0.5, { 0, 0.25, 0 }),
	},
}

-- Zone 3, Uncommon: a chipped carousel horse that broke loose, still skewered on its golden pole.
-- The pole runs right through it; the horse slides up and down it like on the ride, frozen
-- mid-gallop, bleeding where the pole goes in and comes out.
local CarouselWhite = { 235, 230, 220 }
Looks.CarouselColt = {
	gait = "walk",
	top = 3.2,
	pieces = {
		-- The pole stays put; everything else rides up and down it.
		block("PoleBase", { 0.7, 0.2, 0.7 }, { 0, -1.9, 0.1 }, Gold),
		block("Pole", { 0.2, 4.6, 0.2 }, { 0, 0.7, 0.1 }, Gold),
		block("PoleStripe1", { 0.22, 0.15, 0.22 }, { 0, -1.45, 0.1 }, CircusRed),
		block("PoleStripe2", { 0.22, 0.15, 0.22 }, { 0, 1.35, 0.1 }, CircusRed),
		block("PoleStripe3", { 0.22, 0.15, 0.22 }, { 0, 1.95, 0.1 }, CircusRed),
		block("PoleStripe4", { 0.22, 0.15, 0.22 }, { 0, 2.55, 0.1 }, CircusRed),
		block("PoleBloodHigh", { 0.22, 0.6, 0.22 }, { 0, 0.55, 0.1 }, Blood),
		block("PoleBloodLow", { 0.22, 0.6, 0.22 }, { 0, -1, 0.1 }, Blood),
		block("PoleCap", { 0.4, 0.25, 0.4 }, { 0, 3.05, 0.1 }, Gold),
		slide(
			limb("Body", { 1.1, 0.95, 2.1 }, { 0, -0.3, 0.1 }, CarouselWhite, "Y", 0.35, 0.8, 0, { 0, 0, 0 })
		),
		slide(
			limb(
				"Chip",
				{ 0.05, 0.4, 0.5 },
				{ 0.57, -0.2, 0.5 },
				{ 120, 110, 100 },
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"ChipLow",
				{ 0.05, 0.25, 0.3 },
				{ -0.57, -0.5, -0.4 },
				{ 120, 110, 100 },
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb("Saddle", { 1.15, 0.15, 0.8 }, { 0, 0.23, 0.1 }, CircusRed, "Y", 0.35, 0.8, 0, { 0, 0, 0 })
		),
		slide(
			limb("SaddleTrim", { 1.2, 0.06, 0.85 }, { 0, 0.14, 0.1 }, Gold, "Y", 0.35, 0.8, 0, { 0, 0, 0 })
		),
		slide(
			limb(
				"WoundTop",
				{ 0.42, 0.04, 0.42 },
				{ 0, 0.32, 0.1 },
				{ 110, 10, 15 },
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"BloodSaddleLeft",
				{ 0.06, 0.45, 0.06 },
				{ -0.6, 0.02, 0.2 },
				Blood,
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"BloodSaddleRight",
				{ 0.06, 0.3, 0.06 },
				{ 0.6, 0.08, 0 },
				Blood,
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"WoundBottom",
				{ 0.42, 0.04, 0.42 },
				{ 0, -0.79, 0.1 },
				{ 110, 10, 15 },
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"BloodDrip",
				{ 0.07, 0.3, 0.07 },
				{ 0.14, -0.95, 0.1 },
				Blood,
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb("BloodDrop", { 0.08, 0.1, 0.08 }, { 0.14, -1.2, 0.1 }, Blood, "Y", 0.35, 0.8, 0, { 0, 0, 0 })
		),
		tilt(
			slide(
				limb(
					"Neck",
					{ 0.5, 1.05, 0.55 },
					{ 0, 0.42, -0.9 },
					CarouselWhite,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			-30,
			0,
			0
		),
		tilt(
			slide(
				limb(
					"Mane",
					{ 0.2, 1.1, 0.25 },
					{ 0, 0.62, -0.68 },
					CircusTeal,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			-30,
			0,
			0
		),
		tilt(
			slide(
				limb(
					"Head",
					{ 0.5, 0.5, 0.9 },
					{ 0, 0.95, -1.4 },
					CarouselWhite,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			-25,
			0,
			0
		),
		tilt(
			slide(
				limb(
					"Muzzle",
					{ 0.45, 0.35, 0.3 },
					{ 0, 0.75, -1.8 },
					{ 200, 190, 180 },
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			-25,
			0,
			0
		),
		tilt(
			slide(
				limb("Bridle", { 0.54, 0.08, 0.4 }, { 0, 0.88, -1.55 }, Gold, "Y", 0.35, 0.8, 0, { 0, 0, 0 })
			),
			-25,
			0,
			0
		),
		slide(limb("Teeth", { 0.38, 0.08, 0.06 }, { 0, 0.6, -1.97 }, White, "Y", 0.35, 0.8, 0, { 0, 0, 0 })),
		slide(
			limb(
				"MouthBlood",
				{ 0.06, 0.25, 0.06 },
				{ 0.12, 0.45, -1.95 },
				Blood,
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"LeftEar",
				{ 0.12, 0.3, 0.12 },
				{ -0.15, 1.3, -1.2 },
				CarouselWhite,
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"RightEar",
				{ 0.12, 0.3, 0.12 },
				{ 0.15, 1.3, -1.2 },
				CarouselWhite,
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"LeftEye",
				{ 0.06, 0.12, 0.12 },
				{ -0.26, 1.05, -1.45 },
				{ 255, 50, 50 },
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 },
				true
			)
		),
		slide(
			limb(
				"RightEye",
				{ 0.06, 0.12, 0.12 },
				{ 0.26, 1.05, -1.45 },
				{ 255, 50, 50 },
				"Y",
				0.35,
				0.8,
				0,
				{ 0, 0, 0 },
				true
			)
		),
		tilt(
			slide(
				limb(
					"Tail",
					{ 0.25, 0.8, 0.25 },
					{ 0, -0.26, 1.41 },
					CircusTeal,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			-40,
			0,
			0
		),
		tilt(
			slide(
				limb(
					"FrontLeftLeg",
					{ 0.28, 0.75, 0.28 },
					{ -0.33, -0.891, -0.987 },
					CarouselWhite,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			50,
			0,
			0
		),
		tilt(
			slide(
				limb(
					"FrontLeftHoof",
					{ 0.32, 0.2, 0.32 },
					{ -0.33, -1.196, -1.351 },
					Gold,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			50,
			0,
			0
		),
		tilt(
			slide(
				limb(
					"FrontRightLeg",
					{ 0.28, 0.75, 0.28 },
					{ 0.33, -0.975, -0.887 },
					CarouselWhite,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			30,
			0,
			0
		),
		tilt(
			slide(
				limb(
					"FrontRightHoof",
					{ 0.32, 0.2, 0.32 },
					{ 0.33, -1.386, -1.125 },
					Gold,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			30,
			0,
			0
		),
		tilt(
			slide(
				limb(
					"BackLeftLeg",
					{ 0.28, 0.75, 0.28 },
					{ -0.33, -0.957, 1.065 },
					CarouselWhite,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			-35,
			0,
			0
		),
		tilt(
			slide(
				limb(
					"BackLeftHoof",
					{ 0.32, 0.2, 0.32 },
					{ -0.33, -1.346, 1.338 },
					Gold,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			-35,
			0,
			0
		),
		tilt(
			slide(
				limb(
					"BackRightLeg",
					{ 0.28, 0.75, 0.28 },
					{ 0.33, -1.012, 0.947 },
					CarouselWhite,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			-15,
			0,
			0
		),
		tilt(
			slide(
				limb(
					"BackRightHoof",
					{ 0.32, 0.2, 0.32 },
					{ 0.33, -1.471, 1.07 },
					Gold,
					"Y",
					0.35,
					0.8,
					0,
					{ 0, 0, 0 }
				)
			),
			-15,
			0,
			0
		),
	},
}

-- Zone 3, Rare: a pale-faced jester in a two-colour suit and a belled two-tipped hat.
local JesterPurple = { 90, 40, 130 }
local Clown = { 240, 238, 230 }
Looks.JesterJinx = {
	gait = "walk",
	top = 1.8,
	pieces = {
		block("LeftHalf", { 0.55, 1.1, 0.6 }, { -0.275, -0.55, 0 }, CircusRed),
		block("RightHalf", { 0.55, 1.1, 0.6 }, { 0.275, -0.55, 0 }, JesterPurple),
		tilt(block("Diamond", { 0.3, 0.3, 0.05 }, { 0, -0.5, -0.32 }, Gold), 0, 0, 45),
		block("Ruff", { 1.3, 0.25, 0.8 }, { 0, 0.07, 0 }, Clown),
		block("Head", { 0.8, 0.8, 0.8 }, { 0, 0.6, 0 }, Clown),
		tilt(block("LeftEye", { 0.18, 0.18, 0.05 }, { -0.18, 0.72, -0.42 }, Black), 0, 0, 45),
		tilt(block("RightEye", { 0.18, 0.18, 0.05 }, { 0.18, 0.72, -0.42 }, Black), 0, 0, 45),
		block("LeftPupil", { 0.06, 0.06, 0.05 }, { -0.18, 0.72, -0.45 }, RedEye, true),
		block("RightPupil", { 0.06, 0.06, 0.05 }, { 0.18, 0.72, -0.45 }, RedEye, true),
		block("Nose", { 0.15, 0.15, 0.15 }, { 0, 0.55, -0.47 }, CircusRed),
		block("Grin", { 0.5, 0.1, 0.05 }, { 0, 0.38, -0.42 }, CircusRed),
		block("GrinLeft", { 0.1, 0.18, 0.05 }, { -0.28, 0.45, -0.42 }, CircusRed),
		block("GrinRight", { 0.1, 0.18, 0.05 }, { 0.28, 0.45, -0.42 }, CircusRed),
		block("HatBase", { 0.85, 0.25, 0.85 }, { 0, 1.1, 0 }, JesterPurple),
		tilt(block("LeftTip", { 0.3, 0.8, 0.3 }, { -0.45, 1.4, 0 }, CircusRed), 0, 0, 40),
		tilt(block("RightTip", { 0.3, 0.8, 0.3 }, { 0.45, 1.4, 0 }, JesterPurple), 0, 0, -40),
		limb("LeftBell", { 0.2, 0.2, 0.2 }, { -0.75, 1.65, 0 }, Gold, "Z", 15, 2, 0, { 0.1, -0.1, 0 }),
		limb("RightBell", { 0.2, 0.2, 0.2 }, { 0.75, 1.65, 0 }, Gold, "Z", 15, 2, 0.5, { -0.1, -0.1, 0 }),
		limb(
			"LeftArm",
			{ 0.28, 1, 0.28 },
			{ -0.72, -0.5, 0 },
			JesterPurple,
			"X",
			35,
			1.8,
			0.5,
			{ 0, 0.45, 0 }
		),
		limb("RightArm", { 0.28, 1, 0.28 }, { 0.72, -0.5, 0 }, CircusRed, "X", 35, 1.8, 0, { 0, 0.45, 0 }),
		limb(
			"LeftLeg",
			{ 0.35, 0.9, 0.35 },
			{ -0.28, -1.55, 0 },
			JesterPurple,
			"X",
			30,
			1.8,
			0,
			{ 0, 0.45, 0 }
		),
		limb(
			"LeftShoe",
			{ 0.3, 0.2, 0.5 },
			{ -0.28, -1.9, -0.15 },
			CircusRed,
			"X",
			30,
			1.8,
			0,
			{ 0, 0.8, 0.15 }
		),
		limb(
			"RightLeg",
			{ 0.35, 0.9, 0.35 },
			{ 0.28, -1.55, 0 },
			CircusRed,
			"X",
			30,
			1.8,
			0.5,
			{ 0, 0.45, 0 }
		),
		limb(
			"RightShoe",
			{ 0.3, 0.2, 0.5 },
			{ 0.28, -1.9, -0.15 },
			JesterPurple,
			"X",
			30,
			1.8,
			0.5,
			{ 0, 0.8, 0.15 }
		),
	},
}

-- Zone 3, Epic: a cracked funhouse mirror in an ornate gold frame. The thing in the glass grins
-- back with hollow eyes and bloody teeth, its claws curl round the frame as it climbs out, and
-- jagged shards of glass circle it.
local MirrorGlass = { 185, 205, 225 }
local Magenta = { 255, 70, 200 }
local GoldDark = { 190, 145, 50 }
local Reflection = { 235, 245, 255 }
local Crack = { 50, 55, 65 }
local ClawGrey = { 160, 160, 175 }
Looks.MirrorGrin = {
	gait = "float",
	top = 2.1,
	pieces = {
		block("Frame", { 2, 2.8, 0.3 }, { 0, 0.2, 0 }, Gold),
		block("FrameInner", { 1.7, 2.5, 0.05 }, { 0, 0.2, -0.16 }, GoldDark),
		block("Glass", { 1.5, 2.3, 0.1 }, { 0, 0.2, -0.17 }, MirrorGlass),
		block("Backing", { 1.8, 2.6, 0.1 }, { 0, 0.2, 0.18 }, Wood),
		block("Crest", { 1, 0.45, 0.3 }, { 0, 1.75, 0 }, Gold),
		block("CrestTop", { 0.4, 0.25, 0.3 }, { 0, 2.05, 0 }, Gold),
		block("Gem", { 0.22, 0.22, 0.1 }, { 0, 1.75, -0.18 }, Magenta, true),
		block("TopLeftKnob", { 0.35, 0.35, 0.35 }, { -1, 1.6, 0 }, Gold),
		block("TopRightKnob", { 0.35, 0.35, 0.35 }, { 1, 1.6, 0 }, Gold),
		block("BottomLeftKnob", { 0.35, 0.35, 0.35 }, { -1, -1.2, 0 }, Gold),
		block("BottomRightKnob", { 0.35, 0.35, 0.35 }, { 1, -1.2, 0 }, Gold),
		block("LeftScroll", { 0.2, 0.7, 0.35 }, { -1.05, 0.2, 0 }, GoldDark),
		block("RightScroll", { 0.2, 0.7, 0.35 }, { 1.05, 0.2, 0 }, GoldDark),
		block("Bottom", { 0.8, 0.3, 0.3 }, { 0, -1.3, 0 }, Gold),
		block("BottomPoint", { 0.3, 0.25, 0.3 }, { 0, -1.55, 0 }, Gold),
		-- The glass: a silvery shine, and the face of the thing living in it.
		tilt(block("Shine1", { 0.12, 0.8, 0.03 }, { -0.45, 1.0, -0.23 }, Reflection), 0, 0, -35),
		tilt(block("Shine2", { 0.07, 0.5, 0.03 }, { -0.25, 1.1, -0.23 }, Reflection), 0, 0, -35),
		tilt(block("Shine3", { 0.07, 0.4, 0.03 }, { 0.5, -0.75, -0.23 }, Reflection), 0, 0, -35),
		block("LeftSocket", { 0.42, 0.32, 0.05 }, { -0.35, 0.65, -0.24 }, Black),
		block("RightSocket", { 0.42, 0.32, 0.05 }, { 0.35, 0.65, -0.24 }, Black),
		block("LeftEye", { 0.13, 0.13, 0.05 }, { -0.35, 0.65, -0.27 }, Magenta, true),
		block("RightEye", { 0.13, 0.13, 0.05 }, { 0.35, 0.65, -0.27 }, Magenta, true),
		tilt(block("LeftBrow", { 0.45, 0.08, 0.05 }, { -0.35, 0.88, -0.24 }, Black), 0, 0, -20),
		tilt(block("RightBrow", { 0.45, 0.08, 0.05 }, { 0.35, 0.88, -0.24 }, Black), 0, 0, 20),
		block("Grin", { 1.2, 0.45, 0.05 }, { 0, -0.15, -0.24 }, Black),
		block("GrinLeft", { 0.14, 0.35, 0.05 }, { -0.62, 0.1, -0.24 }, Black),
		block("GrinRight", { 0.14, 0.35, 0.05 }, { 0.62, 0.1, -0.24 }, Black),
		block("TopTooth1", { 0.15, 0.2, 0.05 }, { -0.48, -0.02, -0.27 }, White),
		block("TopTooth2", { 0.15, 0.2, 0.05 }, { -0.24, -0.02, -0.27 }, White),
		block("TopTooth3", { 0.15, 0.2, 0.05 }, { 0, -0.02, -0.27 }, White),
		block("TopTooth4", { 0.15, 0.2, 0.05 }, { 0.24, -0.02, -0.27 }, White),
		block("TopTooth5", { 0.15, 0.2, 0.05 }, { 0.48, -0.02, -0.27 }, White),
		block("BottomTooth1", { 0.15, 0.18, 0.05 }, { -0.36, -0.29, -0.27 }, White),
		block("BottomTooth2", { 0.15, 0.18, 0.05 }, { -0.12, -0.29, -0.27 }, White),
		block("BottomTooth3", { 0.15, 0.18, 0.05 }, { 0.12, -0.29, -0.27 }, White),
		block("BottomTooth4", { 0.15, 0.18, 0.05 }, { 0.36, -0.29, -0.27 }, White),
		block("BloodDrip1", { 0.08, 0.45, 0.05 }, { 0.2, -0.58, -0.26 }, Blood),
		block("BloodDrip2", { 0.08, 0.3, 0.05 }, { -0.3, -0.5, -0.26 }, Blood),
		block("BloodDrop", { 0.1, 0.1, 0.05 }, { 0.2, -0.88, -0.26 }, Blood),
		block("Impact", { 0.14, 0.14, 0.04 }, { 0.42, 1.0, -0.24 }, Crack),
		tilt(block("Crack1", { 0.05, 0.6, 0.03 }, { 0.25, 0.75, -0.24 }, Crack), 0, 0, 35),
		tilt(block("Crack2", { 0.05, 0.5, 0.03 }, { 0.6, 1.2, -0.24 }, Crack), 0, 0, -55),
		tilt(block("Crack3", { 0.05, 0.45, 0.03 }, { 0.2, 1.12, -0.24 }, Crack), 0, 0, 75),
		tilt(block("Crack4", { 0.05, 0.5, 0.03 }, { 0.6, 0.75, -0.24 }, Crack), 0, 0, -25),
		tilt(block("Crack5", { 0.05, 0.8, 0.03 }, { -0.45, -0.75, -0.24 }, Crack), 0, 0, -25),
		-- Claws gripping the frame from inside the glass.
		block("LeftClaw1", { 0.4, 0.07, 0.07 }, { -0.95, 0.5, -0.2 }, ClawGrey),
		block("LeftClaw2", { 0.45, 0.07, 0.07 }, { -0.95, 0.35, -0.2 }, ClawGrey),
		block("LeftClaw3", { 0.4, 0.07, 0.07 }, { -0.95, 0.2, -0.2 }, ClawGrey),
		block("RightClaw1", { 0.4, 0.07, 0.07 }, { 0.95, -0.4, -0.2 }, ClawGrey),
		block("RightClaw2", { 0.45, 0.07, 0.07 }, { 0.95, -0.55, -0.2 }, ClawGrey),
		block("RightClaw3", { 0.4, 0.07, 0.07 }, { 0.95, -0.7, -0.2 }, ClawGrey),
		-- Four jagged shards circling the mirror, one of them bloody.
		spin(
			limb("Shard1", { 0.3, 0.5, 0.06 }, { 1.6, 0.6, 0 }, MirrorGlass, "Y", 0, 0.25, 0, { -1.6, 0, 0 })
		),
		spin(
			limb(
				"Shard1Point",
				{ 0.15, 0.3, 0.06 },
				{ 1.67, 0.98, 0 },
				MirrorGlass,
				"Y",
				0,
				0.25,
				0,
				{ -1.67, 0, 0 }
			)
		),
		spin(
			limb(
				"Shard1Chip",
				{ 0.12, 0.15, 0.06 },
				{ 1.5, 0.28, 0 },
				MirrorGlass,
				"Y",
				0,
				0.25,
				0,
				{ -1.5, 0, 0 }
			)
		),
		spin(
			limb(
				"Shard1Edge",
				{ 0.05, 0.5, 0.07 },
				{ 1.44, 0.6, 0 },
				Reflection,
				"Y",
				0,
				0.25,
				0,
				{ -1.44, 0, 0 }
			)
		),
		spin(
			limb(
				"Shard2",
				{ 0.28, 0.45, 0.06 },
				{ -1.6, -0.2, 0 },
				MirrorGlass,
				"Y",
				0,
				0.25,
				0,
				{ 1.6, 0, 0 }
			)
		),
		spin(
			limb(
				"Shard2Point",
				{ 0.12, 0.25, 0.06 },
				{ -1.68, -0.55, 0 },
				MirrorGlass,
				"Y",
				0,
				0.25,
				0,
				{ 1.68, 0, 0 }
			)
		),
		spin(
			limb(
				"Shard2Chip",
				{ 0.12, 0.12, 0.06 },
				{ -1.5, 0.1, 0 },
				MirrorGlass,
				"Y",
				0,
				0.25,
				0,
				{ 1.5, 0, 0 }
			)
		),
		spin(
			limb(
				"Shard2Blood",
				{ 0.1, 0.12, 0.07 },
				{ -1.68, -0.72, 0 },
				Blood,
				"Y",
				0,
				0.25,
				0,
				{ 1.68, 0, 0 }
			)
		),
		spin(
			limb("Shard3", { 0.45, 0.3, 0.06 }, { 0, 1.1, 1.5 }, MirrorGlass, "Y", 0, 0.25, 0, { 0, 0, -1.5 })
		),
		spin(
			limb(
				"Shard3Point",
				{ 0.25, 0.14, 0.06 },
				{ 0.32, 1.17, 1.5 },
				MirrorGlass,
				"Y",
				0,
				0.25,
				0,
				{ -0.32, 0, -1.5 }
			)
		),
		spin(
			limb(
				"Shard3Chip",
				{ 0.14, 0.12, 0.06 },
				{ -0.28, 1, 1.5 },
				MirrorGlass,
				"Y",
				0,
				0.25,
				0,
				{ 0.28, 0, -1.5 }
			)
		),
		spin(
			limb(
				"Shard4",
				{ 0.25, 0.4, 0.06 },
				{ -1.1, 1.25, -1.1 },
				MirrorGlass,
				"Y",
				0,
				0.25,
				0,
				{ 1.1, 0, 1.1 }
			)
		),
		spin(
			limb(
				"Shard4Point",
				{ 0.12, 0.22, 0.06 },
				{ -1.04, 1.55, -1.1 },
				MirrorGlass,
				"Y",
				0,
				0.25,
				0,
				{ 1.04, 0, 1.1 }
			)
		),
		spin(
			limb(
				"Shard4Blood",
				{ 0.1, 0.1, 0.07 },
				{ -1.04, 1.7, -1.1 },
				Blood,
				"Y",
				0,
				0.25,
				0,
				{ 1.04, 0, 1.1 }
			)
		),
	},
}

-- Zone 3, Legendary: the sinister ringmaster in a red tailcoat and top hat, swinging a cane.
local Tailcoat = { 160, 25, 35 }
local Glove = { 240, 240, 235 }
Looks.TheRingmaster = {
	gait = "walk",
	top = 2.2,
	pieces = {
		block("Coat", { 1.3, 1.3, 0.75 }, { 0, -0.35, 0 }, Tailcoat),
		block("Shirt", { 0.45, 0.8, 0.05 }, { 0, -0.1, -0.4 }, Glove),
		block("BowTie", { 0.4, 0.15, 0.05 }, { 0, 0.22, -0.43 }, Black),
		block("Button1", { 0.1, 0.1, 0.05 }, { -0.33, 0, -0.4 }, Gold),
		block("Button2", { 0.1, 0.1, 0.05 }, { 0.33, 0, -0.4 }, Gold),
		block("Button3", { 0.1, 0.1, 0.05 }, { -0.33, -0.35, -0.4 }, Gold),
		block("Button4", { 0.1, 0.1, 0.05 }, { 0.33, -0.35, -0.4 }, Gold),
		block("LeftEpaulette", { 0.4, 0.15, 0.6 }, { -0.6, 0.35, 0 }, Gold),
		block("RightEpaulette", { 0.4, 0.15, 0.6 }, { 0.6, 0.35, 0 }, Gold),
		block("Head", { 0.85, 0.85, 0.85 }, { 0, 0.75, 0 }, { 225, 218, 205 }),
		block("LeftSocket", { 0.22, 0.18, 0.05 }, { -0.2, 0.85, -0.44 }, Black),
		block("RightSocket", { 0.22, 0.18, 0.05 }, { 0.2, 0.85, -0.44 }, Black),
		block("LeftEye", { 0.08, 0.08, 0.05 }, { -0.2, 0.85, -0.47 }, RedEye, true),
		block("RightEye", { 0.08, 0.08, 0.05 }, { 0.2, 0.85, -0.47 }, RedEye, true),
		block("Mustache", { 0.7, 0.12, 0.08 }, { 0, 0.6, -0.46 }, Black),
		block("MustacheLeft", { 0.12, 0.2, 0.08 }, { -0.38, 0.68, -0.46 }, Black),
		block("MustacheRight", { 0.12, 0.2, 0.08 }, { 0.38, 0.68, -0.46 }, Black),
		block("Grin", { 0.4, 0.08, 0.05 }, { 0, 0.45, -0.44 }, Black),
		block("HatBrim", { 1.2, 0.1, 1.2 }, { 0, 1.22, 0 }, Black),
		block("HatCrown", { 0.8, 0.9, 0.8 }, { 0, 1.72, 0 }, Black),
		block("HatBand", { 0.85, 0.15, 0.85 }, { 0, 1.36, 0 }, Tailcoat),
		limb("LeftTail", { 0.5, 0.8, 0.1 }, { -0.3, -1.35, 0.35 }, Tailcoat, "X", 15, 1.5, 0, { 0, 0.4, 0 }),
		limb(
			"RightTail",
			{ 0.5, 0.8, 0.1 },
			{ 0.3, -1.35, 0.35 },
			Tailcoat,
			"X",
			15,
			1.5,
			0.5,
			{ 0, 0.4, 0 }
		),
		limb("LeftArm", { 0.32, 1.1, 0.32 }, { -0.82, -0.35, 0 }, Tailcoat, "X", 28, 1.5, 0.5, { 0, 0.5, 0 }),
		limb("LeftGlove", { 0.35, 0.3, 0.35 }, { -0.82, -1.05, 0 }, Glove, "X", 28, 1.5, 0.5, { 0, 1.2, 0 }),
		limb("RightArm", { 0.32, 1.1, 0.32 }, { 0.82, -0.35, 0 }, Tailcoat, "X", 28, 1.5, 0, { 0, 0.5, 0 }),
		limb("RightGlove", { 0.35, 0.3, 0.35 }, { 0.82, -1.05, 0 }, Glove, "X", 28, 1.5, 0, { 0, 1.2, 0 }),
		limb("LeftLeg", { 0.4, 0.9, 0.4 }, { -0.28, -1.45, 0 }, Black, "X", 26, 1.5, 0, { 0, 0.45, 0 }),
		limb(
			"LeftBoot",
			{ 0.45, 0.25, 0.6 },
			{ -0.28, -1.875, -0.05 },
			Iron,
			"X",
			26,
			1.5,
			0,
			{ 0, 0.875, 0.05 }
		),
		limb("RightLeg", { 0.4, 0.9, 0.4 }, { 0.28, -1.45, 0 }, Black, "X", 26, 1.5, 0.5, { 0, 0.45, 0 }),
		limb(
			"RightBoot",
			{ 0.45, 0.25, 0.6 },
			{ 0.28, -1.875, -0.05 },
			Iron,
			"X",
			26,
			1.5,
			0.5,
			{ 0, 0.875, 0.05 }
		),

		limb("Cane", { 0.1, 0.95, 0.1 }, { 0.82, -1.5, -0.24 }, Black, "X", 28, 1.5, 0, { 0, 1.65, 0.24 }),
		limb(
			"CaneTip",
			{ 0.13, 0.1, 0.13 },
			{ 0.82, -1.93, -0.24 },
			Silver,
			"X",
			28,
			1.5,
			0,
			{ 0, 2.08, 0.24 }
		),
		limb(
			"CaneKnob",
			{ 0.22, 0.22, 0.22 },
			{ 0.82, -0.86, -0.24 },
			Gold,
			"X",
			28,
			1.5,
			0,
			{ 0, 1.01, 0.24 }
		),
	},
}

-- Zone 3, Mythic: the big top come alive: a striped circus tent with a pointed roof and a
-- scalloped trim. Its entrance is a mouth full of teeth, two lit windows glare like eyes, and
-- the tent flaps beside its mouth open and shut as it scuttles along on its tent pegs.
Looks.BigTopTerror = {
	gait = "walk",
	top = 2.1,
	pieces = {
		block("Walls", { 2.4, 1.4, 2.4 }, { 0, -1.1, 0 }, CircusCream),
		block("Stripe1", { 0.3, 1.42, 2.42 }, { -0.95, -1.1, 0 }, CircusRed),
		block("Stripe2", { 0.3, 1.42, 2.42 }, { 0.95, -1.1, 0 }, CircusRed),
		block("Stripe3", { 2.42, 1.42, 0.3 }, { 0, -1.1, 0.95 }, CircusRed),
		block("Stripe4", { 2.42, 1.42, 0.3 }, { 0, -1.1, -0.6 }, CircusRed),
		block("Stripe5", { 0.3, 1.42, 2.42 }, { 0, -1.1, 0.3 }, CircusRed),
		block("RoofEdge", { 2.9, 0.1, 2.9 }, { 0, -0.38, 0 }, Gold),
		tilt(block("RoofFront1", { 2.4, 0.12, 0.601 }, { 0, -0.188, -1.225 }, CircusRed), -50.5, 0, 0),
		tilt(block("RoofBack1", { 2.4, 0.12, 0.601 }, { 0, -0.188, 1.225 }, CircusRed), 50.5, 0, 0),
		tilt(block("RoofLeft1", { 0.601, 0.12, 2.4 }, { -1.225, -0.188, 0 }, CircusCream), 0, 0, 50.5),
		tilt(block("RoofRight1", { 0.601, 0.12, 2.4 }, { 1.225, -0.188, 0 }, CircusCream), 0, 0, -50.5),
		tilt(block("RoofFront2", { 1.7, 0.12, 0.601 }, { 0, 0.238, -0.875 }, CircusRed), -50.5, 0, 0),
		tilt(block("RoofBack2", { 1.7, 0.12, 0.601 }, { 0, 0.238, 0.875 }, CircusRed), 50.5, 0, 0),
		tilt(block("RoofLeft2", { 0.601, 0.12, 1.7 }, { -0.875, 0.238, 0 }, CircusCream), 0, 0, 50.5),
		tilt(block("RoofRight2", { 0.601, 0.12, 1.7 }, { 0.875, 0.238, 0 }, CircusCream), 0, 0, -50.5),
		tilt(block("RoofFront3", { 1, 0.12, 0.601 }, { 0, 0.662, -0.525 }, CircusRed), -50.5, 0, 0),
		tilt(block("RoofBack3", { 1, 0.12, 0.601 }, { 0, 0.662, 0.525 }, CircusRed), 50.5, 0, 0),
		tilt(block("RoofLeft3", { 0.601, 0.12, 1 }, { -0.525, 0.662, 0 }, CircusCream), 0, 0, 50.5),
		tilt(block("RoofRight3", { 0.601, 0.12, 1 }, { 0.525, 0.662, 0 }, CircusCream), 0, 0, -50.5),
		tilt(block("RoofFront4", { 0.3, 0.12, 0.601 }, { 0, 1.088, -0.175 }, CircusRed), -50.5, 0, 0),
		tilt(block("RoofBack4", { 0.3, 0.12, 0.601 }, { 0, 1.088, 0.175 }, CircusRed), 50.5, 0, 0),
		tilt(block("RoofLeft4", { 0.601, 0.12, 0.3 }, { -0.175, 1.088, 0 }, CircusCream), 0, 0, 50.5),
		tilt(block("RoofRight4", { 0.601, 0.12, 0.3 }, { 0.175, 1.088, 0 }, CircusCream), 0, 0, -50.5),
		tilt(block("TrimFront1", { 0.32, 0.32, 0.08 }, { -1.05, -0.48, -1.42 }, CircusCream), 0, 0, 45),
		tilt(block("TrimBack1", { 0.32, 0.32, 0.08 }, { -1.05, -0.48, 1.42 }, CircusCream), 0, 0, 45),
		tilt(block("TrimLeft1", { 0.08, 0.32, 0.32 }, { -1.42, -0.48, -1.05 }, CircusRed), 45, 0, 0),
		tilt(block("TrimRight1", { 0.08, 0.32, 0.32 }, { 1.42, -0.48, -1.05 }, CircusRed), 45, 0, 0),
		tilt(block("TrimFront2", { 0.32, 0.32, 0.08 }, { -0.35, -0.48, -1.42 }, Gold), 0, 0, 45),
		tilt(block("TrimBack2", { 0.32, 0.32, 0.08 }, { -0.35, -0.48, 1.42 }, Gold), 0, 0, 45),
		tilt(block("TrimLeft2", { 0.08, 0.32, 0.32 }, { -1.42, -0.48, -0.35 }, Gold), 45, 0, 0),
		tilt(block("TrimRight2", { 0.08, 0.32, 0.32 }, { 1.42, -0.48, -0.35 }, Gold), 45, 0, 0),
		tilt(block("TrimFront3", { 0.32, 0.32, 0.08 }, { 0.35, -0.48, -1.42 }, CircusCream), 0, 0, 45),
		tilt(block("TrimBack3", { 0.32, 0.32, 0.08 }, { 0.35, -0.48, 1.42 }, CircusCream), 0, 0, 45),
		tilt(block("TrimLeft3", { 0.08, 0.32, 0.32 }, { -1.42, -0.48, 0.35 }, CircusRed), 45, 0, 0),
		tilt(block("TrimRight3", { 0.08, 0.32, 0.32 }, { 1.42, -0.48, 0.35 }, CircusRed), 45, 0, 0),
		tilt(block("TrimFront4", { 0.32, 0.32, 0.08 }, { 1.05, -0.48, -1.42 }, Gold), 0, 0, 45),
		tilt(block("TrimBack4", { 0.32, 0.32, 0.08 }, { 1.05, -0.48, 1.42 }, Gold), 0, 0, 45),
		tilt(block("TrimLeft4", { 0.08, 0.32, 0.32 }, { -1.42, -0.48, 1.05 }, Gold), 45, 0, 0),
		tilt(block("TrimRight4", { 0.08, 0.32, 0.32 }, { 1.42, -0.48, 1.05 }, Gold), 45, 0, 0),
		block("Peak", { 0.3, 0.25, 0.3 }, { 0, 1.35, 0 }, Gold),
		block("TopPole", { 0.12, 0.7, 0.12 }, { 0, 1.75, 0 }, Gold),
		block("TopKnob", { 0.2, 0.2, 0.2 }, { 0, 2.1, 0 }, Gold),
		limb("Flag", { 0.55, 0.3, 0.05 }, { 0.33, 1.9, 0 }, CircusTeal, "Y", 30, 2, 0, { -0.27, 0, 0 }),
		block("LeftWindow", { 0.4, 0.3, 0.05 }, { -0.5, -0.82, -1.22 }, Candle, true),
		block("RightWindow", { 0.4, 0.3, 0.05 }, { 0.5, -0.82, -1.22 }, Candle, true),
		tilt(block("LeftBrow", { 0.5, 0.08, 0.05 }, { -0.5, -0.62, -1.23 }, Black), 0, 0, -18),
		tilt(block("RightBrow", { 0.5, 0.08, 0.05 }, { 0.5, -0.62, -1.23 }, Black), 0, 0, 18),
		block("Mouth", { 1, 0.72, 0.05 }, { 0, -1.42, -1.22 }, Black),
		block("Tongue", { 0.6, 0.1, 0.5 }, { 0, -1.73, -1.05 }, Blood),
		block("TopTooth1", { 0.18, 0.22, 0.05 }, { -0.36, -1.15, -1.25 }, White),
		block("TopTooth2", { 0.18, 0.22, 0.05 }, { -0.12, -1.15, -1.25 }, White),
		block("TopTooth3", { 0.18, 0.22, 0.05 }, { 0.12, -1.15, -1.25 }, White),
		block("TopTooth4", { 0.18, 0.22, 0.05 }, { 0.36, -1.15, -1.25 }, White),
		block("BottomTooth1", { 0.18, 0.2, 0.05 }, { -0.24, -1.68, -1.25 }, White),
		block("BottomTooth2", { 0.18, 0.2, 0.05 }, { 0.24, -1.68, -1.25 }, White),
		block("Drool", { 0.07, 0.3, 0.05 }, { 0.3, -1.4, -1.26 }, Blood),
		limb(
			"LeftFlap",
			{ 0.4, 0.95, 0.08 },
			{ -0.72, -1.3, -1.26 },
			CircusRed,
			"Y",
			30,
			1.5,
			0,
			{ -0.2, 0, 0 }
		),
		limb(
			"RightFlap",
			{ 0.4, 0.95, 0.08 },
			{ 0.72, -1.3, -1.26 },
			CircusRed,
			"Y",
			-30,
			1.5,
			0,
			{ 0.2, 0, 0 }
		),
		limb("FrontLeftPeg", { 0.3, 0.2, 0.3 }, { -0.95, -1.9, -0.95 }, Wood, "X", 35, 2.5, 0, { 0, 0.1, 0 }),
		limb(
			"FrontRightPeg",
			{ 0.3, 0.2, 0.3 },
			{ 0.95, -1.9, -0.95 },
			Wood,
			"X",
			35,
			2.5,
			0.5,
			{ 0, 0.1, 0 }
		),
		limb("BackLeftPeg", { 0.3, 0.2, 0.3 }, { -0.95, -1.9, 0.95 }, Wood, "X", 35, 2.5, 0.5, { 0, 0.1, 0 }),
		limb("BackRightPeg", { 0.3, 0.2, 0.3 }, { 0.95, -1.9, 0.95 }, Wood, "X", 35, 2.5, 0, { 0, 0.1, 0 }),
	},
}

-- Zone 3, Divine: the carousel itself, alive. It stalks on six golden spider legs; its column is
-- a throat of flesh with one great eye, fangs hang from its canopy, and skeletal horses with
-- burning eyes still turn round it, skewered on their poles.
local CarouselFlesh = { 120, 25, 35 }
local GoldLeg = { 200, 150, 50 }
Looks.GoldenCarousel = {
	gait = "walk",
	top = 2.6,
	pieces = {
		block("Platform", { 2.6, 0.3, 2.6 }, { 0, -0.55, 0 }, Gold),
		block("PlatformTrim", { 2.7, 0.1, 2.7 }, { 0, -0.72, 0 }, CircusRed),
		block("Underbelly", { 2.2, 0.2, 2.2 }, { 0, -0.82, 0 }, CarouselFlesh),
		block("Throat", { 0.9, 1.7, 0.9 }, { 0, 0.45, 0 }, CarouselFlesh),
		block("ThroatRing1", { 0.95, 0.1, 0.95 }, { 0, 0, 0 }, Gold),
		block("ThroatRing2", { 0.95, 0.1, 0.95 }, { 0, 1.05, 0 }, Gold),
		block("Eye", { 0.75, 0.7, 0.1 }, { 0, 0.55, -0.48 }, Bone),
		block("Iris", { 0.42, 0.42, 0.05 }, { 0, 0.55, -0.55 }, Gold, true),
		block("Pupil", { 0.1, 0.36, 0.05 }, { 0, 0.55, -0.58 }, Black),
		tilt(block("Vein1", { 0.04, 0.25, 0.04 }, { 0.2, 0.72, -0.54 }, Blood), 0, 0, 40),
		tilt(block("Vein2", { 0.04, 0.22, 0.04 }, { -0.2, 0.38, -0.54 }, Blood), 0, 0, 40),
		block("Canopy", { 2.8, 0.3, 2.8 }, { 0, 1.45, 0 }, CircusRed),
		block("Maw", { 2.7, 0.05, 2.7 }, { 0, 1.2, 0 }, Black),
		block("CanopyTrim", { 2.9, 0.12, 2.9 }, { 0, 1.27, 0 }, Gold),
		block("Roof", { 1.8, 0.35, 1.8 }, { 0, 1.77, 0 }, CircusCream),
		block("RoofTop", { 1, 0.35, 1 }, { 0, 2.1, 0 }, Gold),
		block("Star", { 0.3, 0.3, 0.3 }, { 0, 2.42, 0 }, Candle, true),
		block("Bulb1", { 0.18, 0.18, 0.18 }, { 1.4, 1.45, 1.4 }, RedEye, true),
		block("Bulb2", { 0.18, 0.18, 0.18 }, { -1.4, 1.45, 1.4 }, RedEye, true),
		block("Bulb3", { 0.18, 0.18, 0.18 }, { 1.4, 1.45, -1.4 }, RedEye, true),
		block("Bulb4", { 0.18, 0.18, 0.18 }, { -1.4, 1.45, -1.4 }, RedEye, true),
		block("Fang1", { 0.2, 0.6, 0.2 }, { -0.9, 0.95, -1.35 }, Bone),
		block("Fang2", { 0.2, 0.6, 0.2 }, { -1.35, 0.95, -0.9 }, Bone),
		block("Fang3", { 0.2, 0.6, 0.2 }, { 0, 0.95, -1.35 }, Bone),
		block("Fang4", { 0.2, 0.6, 0.2 }, { -1.35, 0.95, 0 }, Bone),
		block("Fang5", { 0.2, 0.6, 0.2 }, { 0.9, 0.95, -1.35 }, Bone),
		block("Fang6", { 0.2, 0.6, 0.2 }, { -1.35, 0.95, 0.9 }, Bone),
		block("Fang7", { 0.2, 0.6, 0.2 }, { -0.9, 0.95, 1.35 }, Bone),
		block("Fang8", { 0.2, 0.6, 0.2 }, { 1.35, 0.95, -0.9 }, Bone),
		block("Fang9", { 0.2, 0.6, 0.2 }, { 0, 0.95, 1.35 }, Bone),
		block("Fang10", { 0.2, 0.6, 0.2 }, { 1.35, 0.95, 0 }, Bone),
		block("Fang11", { 0.2, 0.6, 0.2 }, { 0.9, 0.95, 1.35 }, Bone),
		block("Fang12", { 0.2, 0.6, 0.2 }, { 1.35, 0.95, 0.9 }, Bone),
		block("FangBlood1", { 0.21, 0.12, 0.21 }, { -0.9, 0.7, -1.35 }, Blood),
		block("FangBlood2", { 0.21, 0.12, 0.21 }, { 0.9, 0.7, -1.35 }, Blood),
		block("FangBlood3", { 0.21, 0.12, 0.21 }, { 1.35, 0.7, 0 }, Blood),
		block("FangBlood4", { 0.21, 0.12, 0.21 }, { -1.35, 0.7, 0.9 }, Blood),
		limb(
			"FrontLeftHip",
			{ 0.45, 0.22, 0.22 },
			{ -1.35, -0.65, -0.85 },
			Gold,
			"Y",
			18,
			1.6,
			0,
			{ 0.2, 0, 0 }
		),
		limb(
			"FrontLeftRiser",
			{ 0.22, 1.1, 0.22 },
			{ -1.55, -0.15, -0.85 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0,
			{ 0.4, -0.5, 0 }
		),
		limb(
			"FrontLeftKnee",
			{ 0.65, 0.22, 0.22 },
			{ -1.8, 0.4, -0.85 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0,
			{ 0.65, -1.05, 0 }
		),
		limb(
			"FrontLeftSpike",
			{ 0.14, 0.45, 0.14 },
			{ -2, 0.72, -0.85 },
			Bone,
			"Y",
			18,
			1.6,
			0,
			{ 0.85, -1.37, 0 }
		),
		limb(
			"FrontLeftShin",
			{ 0.22, 2.3, 0.22 },
			{ -2.12, -0.8, -0.85 },
			Black,
			"Y",
			18,
			1.6,
			0,
			{ 0.97, 0.15, 0 }
		),
		limb(
			"FrontLeftBand",
			{ 0.26, 0.12, 0.26 },
			{ -2.12, -0.2, -0.85 },
			Gold,
			"Y",
			18,
			1.6,
			0,
			{ 0.97, -0.45, 0 }
		),
		limb(
			"FrontLeftClaw",
			{ 0.14, 0.12, 0.3 },
			{ -2.12, -1.94, -0.85 },
			Bone,
			"Y",
			18,
			1.6,
			0,
			{ 0.97, 1.29, 0 }
		),
		limb(
			"MiddleLeftHip",
			{ 0.45, 0.22, 0.22 },
			{ -1.35, -0.65, 0 },
			Gold,
			"Y",
			18,
			1.6,
			0.5,
			{ 0.2, 0, 0 }
		),
		limb(
			"MiddleLeftRiser",
			{ 0.22, 1.1, 0.22 },
			{ -1.55, -0.15, 0 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0.5,
			{ 0.4, -0.5, 0 }
		),
		limb(
			"MiddleLeftKnee",
			{ 0.65, 0.22, 0.22 },
			{ -1.8, 0.4, 0 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0.5,
			{ 0.65, -1.05, 0 }
		),
		limb(
			"MiddleLeftSpike",
			{ 0.14, 0.45, 0.14 },
			{ -2, 0.72, 0 },
			Bone,
			"Y",
			18,
			1.6,
			0.5,
			{ 0.85, -1.37, 0 }
		),
		limb(
			"MiddleLeftShin",
			{ 0.22, 2.3, 0.22 },
			{ -2.12, -0.8, 0 },
			Black,
			"Y",
			18,
			1.6,
			0.5,
			{ 0.97, 0.15, 0 }
		),
		limb(
			"MiddleLeftBand",
			{ 0.26, 0.12, 0.26 },
			{ -2.12, -0.2, 0 },
			Gold,
			"Y",
			18,
			1.6,
			0.5,
			{ 0.97, -0.45, 0 }
		),
		limb(
			"MiddleLeftClaw",
			{ 0.14, 0.12, 0.3 },
			{ -2.12, -1.94, 0 },
			Bone,
			"Y",
			18,
			1.6,
			0.5,
			{ 0.97, 1.29, 0 }
		),
		limb(
			"BackLeftHip",
			{ 0.45, 0.22, 0.22 },
			{ -1.35, -0.65, 0.85 },
			Gold,
			"Y",
			18,
			1.6,
			0,
			{ 0.2, 0, 0 }
		),
		limb(
			"BackLeftRiser",
			{ 0.22, 1.1, 0.22 },
			{ -1.55, -0.15, 0.85 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0,
			{ 0.4, -0.5, 0 }
		),
		limb(
			"BackLeftKnee",
			{ 0.65, 0.22, 0.22 },
			{ -1.8, 0.4, 0.85 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0,
			{ 0.65, -1.05, 0 }
		),
		limb(
			"BackLeftSpike",
			{ 0.14, 0.45, 0.14 },
			{ -2, 0.72, 0.85 },
			Bone,
			"Y",
			18,
			1.6,
			0,
			{ 0.85, -1.37, 0 }
		),
		limb(
			"BackLeftShin",
			{ 0.22, 2.3, 0.22 },
			{ -2.12, -0.8, 0.85 },
			Black,
			"Y",
			18,
			1.6,
			0,
			{ 0.97, 0.15, 0 }
		),
		limb(
			"BackLeftBand",
			{ 0.26, 0.12, 0.26 },
			{ -2.12, -0.2, 0.85 },
			Gold,
			"Y",
			18,
			1.6,
			0,
			{ 0.97, -0.45, 0 }
		),
		limb(
			"BackLeftClaw",
			{ 0.14, 0.12, 0.3 },
			{ -2.12, -1.94, 0.85 },
			Bone,
			"Y",
			18,
			1.6,
			0,
			{ 0.97, 1.29, 0 }
		),
		limb(
			"FrontRightHip",
			{ 0.45, 0.22, 0.22 },
			{ 1.35, -0.65, -0.85 },
			Gold,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.2, 0, 0 }
		),
		limb(
			"FrontRightRiser",
			{ 0.22, 1.1, 0.22 },
			{ 1.55, -0.15, -0.85 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.4, -0.5, 0 }
		),
		limb(
			"FrontRightKnee",
			{ 0.65, 0.22, 0.22 },
			{ 1.8, 0.4, -0.85 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.65, -1.05, 0 }
		),
		limb(
			"FrontRightSpike",
			{ 0.14, 0.45, 0.14 },
			{ 2, 0.72, -0.85 },
			Bone,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.85, -1.37, 0 }
		),
		limb(
			"FrontRightShin",
			{ 0.22, 2.3, 0.22 },
			{ 2.12, -0.8, -0.85 },
			Black,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.97, 0.15, 0 }
		),
		limb(
			"FrontRightBand",
			{ 0.26, 0.12, 0.26 },
			{ 2.12, -0.2, -0.85 },
			Gold,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.97, -0.45, 0 }
		),
		limb(
			"FrontRightClaw",
			{ 0.14, 0.12, 0.3 },
			{ 2.12, -1.94, -0.85 },
			Bone,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.97, 1.29, 0 }
		),
		limb(
			"MiddleRightHip",
			{ 0.45, 0.22, 0.22 },
			{ 1.35, -0.65, 0 },
			Gold,
			"Y",
			18,
			1.6,
			0,
			{ -0.2, 0, 0 }
		),
		limb(
			"MiddleRightRiser",
			{ 0.22, 1.1, 0.22 },
			{ 1.55, -0.15, 0 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0,
			{ -0.4, -0.5, 0 }
		),
		limb(
			"MiddleRightKnee",
			{ 0.65, 0.22, 0.22 },
			{ 1.8, 0.4, 0 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0,
			{ -0.65, -1.05, 0 }
		),
		limb(
			"MiddleRightSpike",
			{ 0.14, 0.45, 0.14 },
			{ 2, 0.72, 0 },
			Bone,
			"Y",
			18,
			1.6,
			0,
			{ -0.85, -1.37, 0 }
		),
		limb(
			"MiddleRightShin",
			{ 0.22, 2.3, 0.22 },
			{ 2.12, -0.8, 0 },
			Black,
			"Y",
			18,
			1.6,
			0,
			{ -0.97, 0.15, 0 }
		),
		limb(
			"MiddleRightBand",
			{ 0.26, 0.12, 0.26 },
			{ 2.12, -0.2, 0 },
			Gold,
			"Y",
			18,
			1.6,
			0,
			{ -0.97, -0.45, 0 }
		),
		limb(
			"MiddleRightClaw",
			{ 0.14, 0.12, 0.3 },
			{ 2.12, -1.94, 0 },
			Bone,
			"Y",
			18,
			1.6,
			0,
			{ -0.97, 1.29, 0 }
		),
		limb(
			"BackRightHip",
			{ 0.45, 0.22, 0.22 },
			{ 1.35, -0.65, 0.85 },
			Gold,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.2, 0, 0 }
		),
		limb(
			"BackRightRiser",
			{ 0.22, 1.1, 0.22 },
			{ 1.55, -0.15, 0.85 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.4, -0.5, 0 }
		),
		limb(
			"BackRightKnee",
			{ 0.65, 0.22, 0.22 },
			{ 1.8, 0.4, 0.85 },
			GoldLeg,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.65, -1.05, 0 }
		),
		limb(
			"BackRightSpike",
			{ 0.14, 0.45, 0.14 },
			{ 2, 0.72, 0.85 },
			Bone,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.85, -1.37, 0 }
		),
		limb(
			"BackRightShin",
			{ 0.22, 2.3, 0.22 },
			{ 2.12, -0.8, 0.85 },
			Black,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.97, 0.15, 0 }
		),
		limb(
			"BackRightBand",
			{ 0.26, 0.12, 0.26 },
			{ 2.12, -0.2, 0.85 },
			Gold,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.97, -0.45, 0 }
		),
		limb(
			"BackRightClaw",
			{ 0.14, 0.12, 0.3 },
			{ 2.12, -1.94, 0.85 },
			Bone,
			"Y",
			18,
			1.6,
			0.5,
			{ -0.97, 1.29, 0 }
		),
		spin(limb("Horse1", { 0.3, 0.35, 0.75 }, { 1, 0.15, 0 }, Bone, "Y", 0, 0.2, 0, { -1, 0, -0 })),
		spin(
			limb("Horse1Head", { 0.24, 0.32, 0.36 }, { 1, 0.4, -0.45 }, Bone, "Y", 0, 0.2, 0, { -1, 0, 0.45 })
		),
		spin(
			limb(
				"Horse1LeftEye",
				{ 0.05, 0.08, 0.08 },
				{ 0.875, 0.45, -0.5 },
				RedEye,
				"Y",
				0,
				0.2,
				0,
				{ -0.875, 0, 0.5 },
				true
			)
		),
		spin(
			limb(
				"Horse1RightEye",
				{ 0.05, 0.08, 0.08 },
				{ 1.125, 0.45, -0.5 },
				RedEye,
				"Y",
				0,
				0.2,
				0,
				{ -1.125, 0, 0.5 },
				true
			)
		),
		spin(
			limb(
				"Horse1Ribs",
				{ 0.32, 0.2, 0.08 },
				{ 1, 0.12, 0.05 },
				Black,
				"Y",
				0,
				0.2,
				0,
				{ -1, 0, -0.05 }
			)
		),
		spin(
			limb(
				"Horse1FrontLeg",
				{ 0.08, 0.35, 0.08 },
				{ 1, -0.18, -0.25 },
				Bone,
				"Y",
				0,
				0.2,
				0,
				{ -1, 0, 0.25 }
			)
		),
		spin(
			limb(
				"Horse1BackLeg",
				{ 0.08, 0.35, 0.08 },
				{ 1, -0.18, 0.25 },
				Bone,
				"Y",
				0,
				0.2,
				0,
				{ -1, 0, -0.25 }
			)
		),
		spin(limb("Horse1Pole", { 0.08, 1.65, 0.08 }, { 1, 0.42, 0 }, Gold, "Y", 0, 0.2, 0, { -1, 0, -0 })),
		spin(limb("Horse1Blood", { 0.1, 0.2, 0.1 }, { 1, 0.4, 0 }, Blood, "Y", 0, 0.2, 0, { -1, 0, -0 })),
		spin(limb("Horse2", { 0.75, 0.35, 0.3 }, { 0, 0.15, -1 }, Bone, "Y", 0, 0.2, 0, { -0, 0, 1 })),
		spin(
			limb("Horse2Head", { 0.36, 0.32, 0.24 }, { -0.45, 0.4, -1 }, Bone, "Y", 0, 0.2, 0, { 0.45, 0, 1 })
		),
		spin(
			limb(
				"Horse2LeftEye",
				{ 0.08, 0.08, 0.05 },
				{ -0.5, 0.45, -0.875 },
				RedEye,
				"Y",
				0,
				0.2,
				0,
				{ 0.5, 0, 0.875 },
				true
			)
		),
		spin(
			limb(
				"Horse2RightEye",
				{ 0.08, 0.08, 0.05 },
				{ -0.5, 0.45, -1.125 },
				RedEye,
				"Y",
				0,
				0.2,
				0,
				{ 0.5, 0, 1.125 },
				true
			)
		),
		spin(
			limb(
				"Horse2Ribs",
				{ 0.08, 0.2, 0.32 },
				{ 0.05, 0.12, -1 },
				Black,
				"Y",
				0,
				0.2,
				0,
				{ -0.05, 0, 1 }
			)
		),
		spin(
			limb(
				"Horse2FrontLeg",
				{ 0.08, 0.35, 0.08 },
				{ -0.25, -0.18, -1 },
				Bone,
				"Y",
				0,
				0.2,
				0,
				{ 0.25, 0, 1 }
			)
		),
		spin(
			limb(
				"Horse2BackLeg",
				{ 0.08, 0.35, 0.08 },
				{ 0.25, -0.18, -1 },
				Bone,
				"Y",
				0,
				0.2,
				0,
				{ -0.25, 0, 1 }
			)
		),
		spin(limb("Horse2Pole", { 0.08, 1.65, 0.08 }, { 0, 0.42, -1 }, Gold, "Y", 0, 0.2, 0, { -0, 0, 1 })),
		spin(limb("Horse2Blood", { 0.1, 0.2, 0.1 }, { 0, 0.4, -1 }, Blood, "Y", 0, 0.2, 0, { -0, 0, 1 })),
		spin(limb("Horse3", { 0.3, 0.35, 0.75 }, { -1, 0.15, -0 }, Bone, "Y", 0, 0.2, 0, { 1, 0, 0 })),
		spin(
			limb("Horse3Head", { 0.24, 0.32, 0.36 }, { -1, 0.4, 0.45 }, Bone, "Y", 0, 0.2, 0, { 1, 0, -0.45 })
		),
		spin(
			limb(
				"Horse3LeftEye",
				{ 0.05, 0.08, 0.08 },
				{ -0.875, 0.45, 0.5 },
				RedEye,
				"Y",
				0,
				0.2,
				0,
				{ 0.875, 0, -0.5 },
				true
			)
		),
		spin(
			limb(
				"Horse3RightEye",
				{ 0.05, 0.08, 0.08 },
				{ -1.125, 0.45, 0.5 },
				RedEye,
				"Y",
				0,
				0.2,
				0,
				{ 1.125, 0, -0.5 },
				true
			)
		),
		spin(
			limb(
				"Horse3Ribs",
				{ 0.32, 0.2, 0.08 },
				{ -1, 0.12, -0.05 },
				Black,
				"Y",
				0,
				0.2,
				0,
				{ 1, 0, 0.05 }
			)
		),
		spin(
			limb(
				"Horse3FrontLeg",
				{ 0.08, 0.35, 0.08 },
				{ -1, -0.18, 0.25 },
				Bone,
				"Y",
				0,
				0.2,
				0,
				{ 1, 0, -0.25 }
			)
		),
		spin(
			limb(
				"Horse3BackLeg",
				{ 0.08, 0.35, 0.08 },
				{ -1, -0.18, -0.25 },
				Bone,
				"Y",
				0,
				0.2,
				0,
				{ 1, 0, 0.25 }
			)
		),
		spin(limb("Horse3Pole", { 0.08, 1.65, 0.08 }, { -1, 0.42, -0 }, Gold, "Y", 0, 0.2, 0, { 1, 0, 0 })),
		spin(limb("Horse3Blood", { 0.1, 0.2, 0.1 }, { -1, 0.4, -0 }, Blood, "Y", 0, 0.2, 0, { 1, 0, 0 })),
		spin(limb("Horse4", { 0.75, 0.35, 0.3 }, { -0, 0.15, 1 }, Bone, "Y", 0, 0.2, 0, { 0, 0, -1 })),
		spin(
			limb("Horse4Head", { 0.36, 0.32, 0.24 }, { 0.45, 0.4, 1 }, Bone, "Y", 0, 0.2, 0, { -0.45, 0, -1 })
		),
		spin(
			limb(
				"Horse4LeftEye",
				{ 0.08, 0.08, 0.05 },
				{ 0.5, 0.45, 0.875 },
				RedEye,
				"Y",
				0,
				0.2,
				0,
				{ -0.5, 0, -0.875 },
				true
			)
		),
		spin(
			limb(
				"Horse4RightEye",
				{ 0.08, 0.08, 0.05 },
				{ 0.5, 0.45, 1.125 },
				RedEye,
				"Y",
				0,
				0.2,
				0,
				{ -0.5, 0, -1.125 },
				true
			)
		),
		spin(
			limb(
				"Horse4Ribs",
				{ 0.08, 0.2, 0.32 },
				{ -0.05, 0.12, 1 },
				Black,
				"Y",
				0,
				0.2,
				0,
				{ 0.05, 0, -1 }
			)
		),
		spin(
			limb(
				"Horse4FrontLeg",
				{ 0.08, 0.35, 0.08 },
				{ 0.25, -0.18, 1 },
				Bone,
				"Y",
				0,
				0.2,
				0,
				{ -0.25, 0, -1 }
			)
		),
		spin(
			limb(
				"Horse4BackLeg",
				{ 0.08, 0.35, 0.08 },
				{ -0.25, -0.18, 1 },
				Bone,
				"Y",
				0,
				0.2,
				0,
				{ 0.25, 0, -1 }
			)
		),
		spin(limb("Horse4Pole", { 0.08, 1.65, 0.08 }, { -0, 0.42, 1 }, Gold, "Y", 0, 0.2, 0, { 0, 0, -1 })),
		spin(limb("Horse4Blood", { 0.1, 0.2, 0.1 }, { -0, 0.4, 1 }, Blood, "Y", 0, 0.2, 0, { 0, 0, -1 })),
	},
}

-- Watcher event monsters: they only appear in the main area during a Watcher event.
local Phantom = { 200, 215, 255 }
local PhantomDark = { 120, 135, 190 }
local Nightmare = { 230, 40, 150 }
local Eldritch = { 40, 255, 200 }
local Flesh = { 70, 35, 80 }

-- Flicker, Phantom: a melting candle with burning eyes and a fanged, dripping mouth, stuck in an
-- old bronze candle holder. Its flame flickers in layers, blue at the wick.
local FlameOrange = { 255, 120, 40 }
Looks.Flickerwick = {
	gait = "float",
	top = 1.65,
	grow = 2,
	pieces = {
		block("Wax", { 0.9, 1.5, 0.9 }, { 0, -0.25, 0 }, { 240, 235, 220 }),
		block("MeltedRim", { 1, 0.14, 1 }, { 0, 0.52, 0 }, { 240, 235, 220 }),
		block("RimLump1", { 0.3, 0.15, 0.3 }, { 0.3, 0.62, -0.25 }, { 240, 235, 220 }),
		block("RimLump2", { 0.25, 0.12, 0.3 }, { -0.3, 0.6, 0.25 }, { 240, 235, 220 }),
		block("DripFrontLeft", { 0.1, 0.45, 0.06 }, { -0.4, 0.25, -0.47 }, { 240, 235, 220 }),
		block("DripFrontLeftEnd", { 0.14, 0.1, 0.07 }, { -0.4, 0.02, -0.47 }, { 240, 235, 220 }),
		block("DripFrontRight", { 0.1, 0.3, 0.06 }, { 0.4, 0.32, -0.47 }, { 240, 235, 220 }),
		block("DripSide", { 0.06, 0.7, 0.12 }, { 0.47, 0.1, 0.2 }, { 240, 235, 220 }),
		block("DripBack", { 0.15, 0.55, 0.06 }, { -0.1, 0.15, 0.47 }, { 240, 235, 220 }),
		block("Wick", { 0.08, 0.2, 0.08 }, { 0, 0.67, 0 }, Black),
		limb(
			"FlameBase",
			{ 0.22, 0.18, 0.22 },
			{ 0, 0.84, 0 },
			{ 120, 170, 255 },
			"Z",
			10,
			4,
			0,
			{ 0, -0.09, 0 },
			true
		),
		limb("Flame", { 0.42, 0.5, 0.42 }, { 0, 1.1, 0 }, FlameOrange, "Z", 14, 4, 0, { 0, -0.35, 0 }, true),
		limb(
			"FlameCore",
			{ 0.24, 0.42, 0.24 },
			{ 0, 1.08, -0.1 },
			Candle,
			"Z",
			14,
			4,
			0,
			{ 0, -0.33, 0.1 },
			true
		),
		limb(
			"FlameTip",
			{ 0.2, 0.32, 0.2 },
			{ 0, 1.48, 0 },
			FlameOrange,
			"Z",
			22,
			4,
			0.15,
			{ 0, -0.73, 0 },
			true
		),
		block("LeftSocket", { 0.24, 0.28, 0.04 }, { -0.2, 0.12, -0.465 }, Black),
		block("RightSocket", { 0.24, 0.28, 0.04 }, { 0.2, 0.12, -0.465 }, Black),
		block("LeftEye", { 0.08, 0.08, 0.04 }, { -0.2, 0.1, -0.49 }, RedEye, true),
		block("RightEye", { 0.08, 0.08, 0.04 }, { 0.2, 0.1, -0.49 }, RedEye, true),
		tilt(block("LeftBrow", { 0.32, 0.08, 0.08 }, { -0.2, 0.32, -0.47 }, { 210, 200, 180 }), 0, 0, -20),
		tilt(block("RightBrow", { 0.32, 0.08, 0.08 }, { 0.2, 0.32, -0.47 }, { 210, 200, 180 }), 0, 0, 20),
		block("UpperLip", { 0.56, 0.07, 0.08 }, { 0, -0.13, -0.47 }, { 210, 200, 180 }),
		block("Mouth", { 0.46, 0.32, 0.04 }, { 0, -0.31, -0.465 }, Black),
		block("Tooth1", { 0.08, 0.12, 0.04 }, { -0.15, -0.21, -0.49 }, White),
		block("Tooth2", { 0.08, 0.15, 0.04 }, { 0, -0.22, -0.49 }, White),
		block("Tooth3", { 0.08, 0.12, 0.04 }, { 0.15, -0.21, -0.49 }, White),
		block("LowTooth1", { 0.08, 0.1, 0.04 }, { -0.08, -0.42, -0.49 }, White),
		block("LowTooth2", { 0.08, 0.1, 0.04 }, { 0.1, -0.42, -0.49 }, White),
		block("LipDrip1", { 0.08, 0.22, 0.07 }, { -0.13, -0.56, -0.47 }, { 240, 235, 220 }),
		block("LipDrip2", { 0.08, 0.14, 0.07 }, { 0.08, -0.52, -0.47 }, { 240, 235, 220 }),
		block("BloodDrip", { 0.07, 0.42, 0.06 }, { 0.2, -0.62, -0.47 }, Blood),
		block("BloodDrop", { 0.09, 0.09, 0.07 }, { 0.2, -0.88, -0.47 }, Blood),
		block("Dish", { 1.4, 0.16, 1.4 }, { 0, -1.08, 0 }, Bronze),
		block("DishLipFront", { 1.4, 0.1, 0.08 }, { 0, -0.96, -0.66 }, Bronze),
		block("DishLipBack", { 1.4, 0.1, 0.08 }, { 0, -0.96, 0.66 }, Bronze),
		block("DishLipLeft", { 0.08, 0.1, 1.4 }, { -0.66, -0.96, 0 }, Bronze),
		block("DishLipRight", { 0.08, 0.1, 1.4 }, { 0.66, -0.96, 0 }, Bronze),
		block("WaxPool", { 1.1, 0.06, 1.1 }, { 0, -0.98, 0 }, { 240, 235, 220 }),
		block("PoolBlood", { 0.35, 0.07, 0.3 }, { 0.3, -0.97, -0.35 }, Blood),
		block("Stem", { 0.3, 0.3, 0.3 }, { 0, -1.31, 0 }, Bronze),
		block("Foot", { 0.8, 0.12, 0.8 }, { 0, -1.52, 0 }, Bronze),
		block("HandleTop", { 0.35, 0.08, 0.12 }, { 0.86, -1, 0 }, Bronze),
		block("HandleOut", { 0.08, 0.3, 0.12 }, { 1, -1.13, 0 }, Bronze),
		block("HandleBottom", { 0.3, 0.08, 0.12 }, { 0.86, -1.26, 0 }, Bronze),
		limb(
			"LeftArm",
			{ 0.16, 0.6, 0.16 },
			{ -0.55, -0.45, -0.1 },
			{ 240, 235, 220 },
			"X",
			30,
			1.2,
			0.5,
			{ 0, 0.3, 0 }
		),
		limb(
			"LeftClaws",
			{ 0.22, 0.18, 0.22 },
			{ -0.55, -0.83, -0.1 },
			Bone,
			"X",
			30,
			1.2,
			0.5,
			{ 0, 0.68, 0 }
		),
		limb(
			"RightArm",
			{ 0.16, 0.6, 0.16 },
			{ 0.55, -0.45, -0.1 },
			{ 240, 235, 220 },
			"X",
			30,
			1.2,
			0,
			{ 0, 0.3, 0 }
		),
		limb(
			"RightClaws",
			{ 0.22, 0.18, 0.22 },
			{ 0.55, -0.83, -0.1 },
			Bone,
			"X",
			30,
			1.2,
			0,
			{ 0, 0.68, 0 }
		),
	},
}

-- Flicker, Phantom: an old television with a ghost inside, scuttling about on a spooky little table.
-- A pale arm pushes out of the screen and pulls back in.
Looks.StaticShade = {
	gait = "walk",
	top = 1.55,
	grow = 2,
	pieces = {
		block("Cabinet", { 1.8, 1.4, 1.2 }, { 0, 0, 0 }, Wood),
		block("Screen", { 1.1, 1, 0.1 }, { -0.2, 0.05, -0.61 }, { 200, 210, 220 }, true),
		block("StaticTop", { 1.05, 0.06, 0.05 }, { -0.2, 0.42, -0.67 }, { 120, 130, 140 }),
		block("StaticBottom", { 1.05, 0.06, 0.05 }, { -0.2, -0.35, -0.67 }, { 120, 130, 140 }),
		block("KnobTop", { 0.18, 0.18, 0.1 }, { 0.65, 0.3, -0.63 }, Iron),
		block("KnobBottom", { 0.18, 0.18, 0.1 }, { 0.65, -0.1, -0.63 }, Iron),
		tilt(
			limb("LeftAntenna", { 0.06, 0.9, 0.06 }, { -0.3, 1.1, 0 }, Iron, "Z", 10, 1.5, 0, { 0, -0.45, 0 }),
			0,
			0,
			25
		),
		tilt(
			limb(
				"RightAntenna",
				{ 0.06, 0.9, 0.06 },
				{ 0.3, 1.1, 0 },
				Iron,
				"Z",
				10,
				1.5,
				0.5,
				{ 0, -0.45, 0 }
			),
			0,
			0,
			-25
		),
		block("LeftEye", { 0.22, 0.26, 0.05 }, { -0.45, 0.18, -0.67 }, Black),
		block("RightEye", { 0.22, 0.26, 0.05 }, { 0.05, 0.18, -0.67 }, Black),
		block("LeftPupil", { 0.06, 0.06, 0.05 }, { -0.45, 0.18, -0.7 }, White, true),
		block("RightPupil", { 0.06, 0.06, 0.05 }, { 0.05, 0.18, -0.7 }, White, true),
		block("HairLeft", { 0.15, 0.9, 0.04 }, { -0.68, 0.05, -0.69 }, Black),
		block("HairRight", { 0.15, 0.7, 0.04 }, { 0.28, 0.12, -0.69 }, Black),
		block("HairTop", { 1.05, 0.12, 0.04 }, { -0.2, 0.5, -0.69 }, Black),
		block("BloodSmear", { 0.12, 0.6, 0.05 }, { 0.6, -0.4, -0.62 }, Blood),
		slide(
			limb(
				"ReachArm",
				{ 0.16, 0.16, 0.8 },
				{ -0.2, -0.2, -0.95 },
				{ 205, 210, 215 },
				"Z",
				-0.5,
				0.5,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"ReachHand",
				{ 0.26, 0.08, 0.24 },
				{ -0.2, -0.2, -1.45 },
				{ 205, 210, 215 },
				"Z",
				-0.5,
				0.5,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"Finger1",
				{ 0.05, 0.05, 0.22 },
				{ -0.29, -0.2, -1.67 },
				{ 205, 210, 215 },
				"Z",
				-0.5,
				0.5,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"Finger2",
				{ 0.05, 0.05, 0.26 },
				{ -0.2, -0.2, -1.69 },
				{ 205, 210, 215 },
				"Z",
				-0.5,
				0.5,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"Finger3",
				{ 0.05, 0.05, 0.22 },
				{ -0.11, -0.2, -1.67 },
				{ 205, 210, 215 },
				"Z",
				-0.5,
				0.5,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb("Nails", { 0.24, 0.05, 0.05 }, { -0.2, -0.2, -1.8 }, Blood, "Z", -0.5, 0.5, 0, { 0, 0, 0 })
		),
		block("TableTop", { 2.1, 0.15, 1.5 }, { 0, -0.775, 0 }, { 60, 40, 35 }),
		block("TableApron", { 1.9, 0.2, 1.3 }, { 0, -0.95, 0 }, { 60, 40, 35 }),
		block("Cloth", { 1.7, 0.12, 1.3 }, { 0, -0.68, 0 }, { 80, 50, 90 }),
		block("ClothFront", { 1.7, 0.45, 0.04 }, { 0, -0.95, -0.67 }, { 80, 50, 90 }),
		block("ClothRag1", { 0.25, 0.2, 0.04 }, { -0.55, -1.25, -0.67 }, { 80, 50, 90 }),
		block("ClothRag2", { 0.3, 0.15, 0.04 }, { 0.3, -1.22, -0.67 }, { 80, 50, 90 }),
		block("Candle", { 0.15, 0.3, 0.15 }, { 0.75, -0.55, 0.4 }, { 240, 235, 220 }),
		block("CandleFlame", { 0.1, 0.15, 0.1 }, { 0.75, -0.32, 0.4 }, Candle, true),
		limb(
			"FrontLeftLeg",
			{ 0.14, 1, 0.14 },
			{ -0.85, -1.45, -0.6 },
			{ 60, 40, 35 },
			"X",
			30,
			1.5,
			0,
			{ 0, 0.5, 0 }
		),
		limb(
			"FrontLeftKnob",
			{ 0.22, 0.14, 0.22 },
			{ -0.85, -1.25, -0.6 },
			{ 60, 40, 35 },
			"X",
			30,
			1.5,
			0,
			{ 0, 0.3, 0 }
		),
		limb(
			"FrontLeftClaw",
			{ 0.22, 0.1, 0.28 },
			{ -0.85, -1.95, -0.64 },
			Iron,
			"X",
			30,
			1.5,
			0,
			{ 0, 1, 0.04 }
		),
		limb(
			"FrontRightLeg",
			{ 0.14, 1, 0.14 },
			{ 0.85, -1.45, -0.6 },
			{ 60, 40, 35 },
			"X",
			30,
			1.5,
			0.5,
			{ 0, 0.5, 0 }
		),
		limb(
			"FrontRightKnob",
			{ 0.22, 0.14, 0.22 },
			{ 0.85, -1.25, -0.6 },
			{ 60, 40, 35 },
			"X",
			30,
			1.5,
			0.5,
			{ 0, 0.3, 0 }
		),
		limb(
			"FrontRightClaw",
			{ 0.22, 0.1, 0.28 },
			{ 0.85, -1.95, -0.64 },
			Iron,
			"X",
			30,
			1.5,
			0.5,
			{ 0, 1, 0.04 }
		),
		limb(
			"BackLeftLeg",
			{ 0.14, 1, 0.14 },
			{ -0.85, -1.45, 0.6 },
			{ 60, 40, 35 },
			"X",
			30,
			1.5,
			0.5,
			{ 0, 0.5, 0 }
		),
		limb(
			"BackLeftKnob",
			{ 0.22, 0.14, 0.22 },
			{ -0.85, -1.25, 0.6 },
			{ 60, 40, 35 },
			"X",
			30,
			1.5,
			0.5,
			{ 0, 0.3, 0 }
		),
		limb(
			"BackLeftClaw",
			{ 0.22, 0.1, 0.28 },
			{ -0.85, -1.95, 0.56 },
			Iron,
			"X",
			30,
			1.5,
			0.5,
			{ 0, 1, 0.04 }
		),
		limb(
			"BackRightLeg",
			{ 0.14, 1, 0.14 },
			{ 0.85, -1.45, 0.6 },
			{ 60, 40, 35 },
			"X",
			30,
			1.5,
			0,
			{ 0, 0.5, 0 }
		),
		limb(
			"BackRightKnob",
			{ 0.22, 0.14, 0.22 },
			{ 0.85, -1.25, 0.6 },
			{ 60, 40, 35 },
			"X",
			30,
			1.5,
			0,
			{ 0, 0.3, 0 }
		),
		limb(
			"BackRightClaw",
			{ 0.22, 0.1, 0.28 },
			{ 0.85, -1.95, 0.56 },
			Iron,
			"X",
			30,
			1.5,
			0,
			{ 0, 1, 0.04 }
		),
	},
}

-- Blood Moon, Phantom: a big, angry bonfire spirit. Layers of red, orange and white-hot flame lick
-- upward, its glaring face is burned into the fire, and embers circle it.
local DeepRed = { 150, 20, 30 }
local FireRed = { 235, 50, 30 }
local FireOrange = { 255, 135, 35 }
Looks.CrimsonWisp = {
	gait = "float",
	top = 2.35,
	grow = 2,
	pieces = {
		block("Embers", { 1.6, 0.6, 1.6 }, { 0, -0.95, 0 }, DeepRed),
		block("Body", { 1.5, 1.3, 1.5 }, { 0, -0.1, 0 }, FireRed, true),
		block("Upper", { 1.1, 0.8, 1.1 }, { 0, 0.85, 0.05 }, FireOrange, true),
		limb("Top", { 0.75, 0.7, 0.75 }, { 0, 1.5, 0.1 }, Candle, "Z", 8, 2.5, 0, { 0, -0.35, 0 }, true),
		limb(
			"Tip",
			{ 0.35, 0.6, 0.35 },
			{ 0, 2.05, 0.15 },
			{ 255, 245, 200 },
			"Z",
			15,
			2.5,
			0.1,
			{ 0, -0.9, -0.05 },
			true
		),
		limb(
			"TongueLeft",
			{ 0.4, 1, 0.4 },
			{ -0.75, 0.6, 0.1 },
			FireOrange,
			"Z",
			18,
			3,
			0,
			{ 0, -0.5, 0 },
			true
		),
		limb(
			"TongueLeftTip",
			{ 0.22, 0.45, 0.22 },
			{ -0.85, 1.3, 0.1 },
			Candle,
			"Z",
			18,
			3,
			0,
			{ 0.1, -1.2, 0 },
			true
		),
		limb(
			"TongueRight",
			{ 0.4, 0.9, 0.4 },
			{ 0.75, 0.55, 0.2 },
			FireOrange,
			"Z",
			18,
			3,
			0.4,
			{ 0, -0.45, 0 },
			true
		),
		limb(
			"TongueRightTip",
			{ 0.22, 0.4, 0.22 },
			{ 0.82, 1.2, 0.2 },
			Candle,
			"Z",
			18,
			3,
			0.4,
			{ -0.07, -1.1, 0 },
			true
		),
		limb(
			"TongueBack",
			{ 0.5, 1.1, 0.4 },
			{ 0, 1.2, 0.6 },
			FireRed,
			"X",
			12,
			3,
			0.7,
			{ 0, -0.6, 0 },
			true
		),
		limb(
			"TongueFront",
			{ 0.3, 0.6, 0.3 },
			{ 0.4, 1.25, -0.35 },
			FireOrange,
			"X",
			15,
			3,
			0.3,
			{ 0, -0.3, 0 },
			true
		),
		tilt(block("LeftBrow", { 0.5, 0.12, 0.05 }, { -0.3, 0.4, -0.77 }, Black), 0, 0, -25),
		tilt(block("RightBrow", { 0.5, 0.12, 0.05 }, { 0.3, 0.4, -0.77 }, Black), 0, 0, 25),
		tilt(
			block("LeftEye", { 0.38, 0.14, 0.05 }, { -0.3, 0.2, -0.77 }, { 255, 250, 210 }, true),
			0,
			0,
			-18
		),
		tilt(block("RightEye", { 0.38, 0.14, 0.05 }, { 0.3, 0.2, -0.77 }, { 255, 250, 210 }, true), 0, 0, 18),
		block("Mouth", { 0.85, 0.34, 0.05 }, { 0, -0.3, -0.77 }, Black),
		block("Fang1", { 0.11, 0.18, 0.05 }, { -0.3, -0.2, -0.8 }, White),
		block("Fang2", { 0.11, 0.18, 0.05 }, { -0.1, -0.2, -0.8 }, White),
		block("Fang3", { 0.11, 0.18, 0.05 }, { 0.1, -0.2, -0.8 }, White),
		block("Fang4", { 0.11, 0.18, 0.05 }, { 0.3, -0.2, -0.8 }, White),
		block("LowFang1", { 0.11, 0.15, 0.05 }, { -0.2, -0.4, -0.8 }, White),
		block("LowFang2", { 0.11, 0.15, 0.05 }, { 0, -0.4, -0.8 }, White),
		block("LowFang3", { 0.11, 0.15, 0.05 }, { 0.2, -0.4, -0.8 }, White),
		limb("Tail", { 0.9, 0.5, 0.9 }, { 0, -1.45, 0 }, FireRed, "X", 15, 1.5, 0, { 0, 0.25, 0 }, true),
		limb(
			"TailTip",
			{ 0.4, 0.45, 0.4 },
			{ 0, -1.85, 0.1 },
			FireOrange,
			"X",
			20,
			1.5,
			0.1,
			{ 0, 0.65, -0.1 },
			true
		),
		limb(
			"LeftArm",
			{ 0.3, 0.8, 0.3 },
			{ -0.95, -0.2, -0.1 },
			FireRed,
			"Z",
			20,
			1.5,
			0,
			{ 0, 0.4, 0 },
			true
		),
		limb(
			"LeftClaw",
			{ 0.34, 0.28, 0.34 },
			{ -0.95, -0.72, -0.1 },
			Candle,
			"Z",
			20,
			1.5,
			0,
			{ 0, 0.92, 0 },
			true
		),
		limb(
			"RightArm",
			{ 0.3, 0.8, 0.3 },
			{ 0.95, -0.2, -0.1 },
			FireRed,
			"Z",
			-20,
			1.5,
			0,
			{ 0, 0.4, 0 },
			true
		),
		limb(
			"RightClaw",
			{ 0.34, 0.28, 0.34 },
			{ 0.95, -0.72, -0.1 },
			Candle,
			"Z",
			-20,
			1.5,
			0,
			{ 0, 0.92, 0 },
			true
		),
		spin(
			limb(
				"Ember1",
				{ 0.2, 0.2, 0.2 },
				{ 1.5, 0.3, 0 },
				FireOrange,
				"Y",
				0,
				0.5,
				0,
				{ -1.5, 0, 0 },
				true
			)
		),
		spin(
			limb(
				"Ember2",
				{ 0.15, 0.15, 0.15 },
				{ -1.4, 0.9, 0 },
				Candle,
				"Y",
				0,
				0.5,
				0,
				{ 1.4, 0, 0 },
				true
			)
		),
		spin(
			limb(
				"Ember3",
				{ 0.15, 0.15, 0.15 },
				{ 0, 1.3, 1.4 },
				FireRed,
				"Y",
				0,
				0.5,
				0,
				{ 0, 0, -1.4 },
				true
			)
		),
	},
}

-- Blood Moon, Phantom: the ghost of a white werewolf, hunched on two legs, with a snapping bloody
-- jaw and hooked claws on its hands and feet.
local WolfWhite = { 228, 230, 238 }
local WolfLight = { 245, 246, 250 }
local WolfShade = { 175, 180, 195 }
Looks.Moonhowler = {
	gait = "walk",
	top = 1.9,
	grow = 2,
	pieces = {
		block("Head", { 0.9, 0.8, 0.9 }, { 0, 1.05, -0.2 }, WolfWhite),
		block("Snout", { 0.5, 0.4, 0.6 }, { 0, 0.9, -0.9 }, WolfShade),
		block("Nose", { 0.2, 0.15, 0.1 }, { 0, 1.08, -1.22 }, Black),
		block("LeftFang", { 0.08, 0.18, 0.08 }, { -0.15, 0.64, -1.1 }, White),
		block("RightFang", { 0.08, 0.18, 0.08 }, { 0.15, 0.64, -1.1 }, White),
		block("LeftEye", { 0.15, 0.12, 0.05 }, { -0.25, 1.2, -0.67 }, RedEye, true),
		block("RightEye", { 0.15, 0.12, 0.05 }, { 0.25, 1.2, -0.67 }, RedEye, true),
		block("LeftEar", { 0.2, 0.45, 0.2 }, { -0.3, 1.65, -0.1 }, WolfShade),
		block("RightEar", { 0.2, 0.45, 0.2 }, { 0.3, 1.65, -0.1 }, WolfShade),
		block("Mane", { 1.1, 0.4, 0.6 }, { 0, 0.7, 0.25 }, WolfShade),
		tilt(block("LeftBrow", { 0.3, 0.08, 0.05 }, { -0.25, 1.32, -0.67 }, Black), 0, 0, -25),
		tilt(block("RightBrow", { 0.3, 0.08, 0.05 }, { 0.25, 1.32, -0.67 }, Black), 0, 0, 25),
		block("UpperTooth1", { 0.07, 0.12, 0.05 }, { -0.15, 0.68, -1.21 }, White),
		block("UpperTooth2", { 0.07, 0.12, 0.05 }, { -0.05, 0.68, -1.21 }, White),
		block("UpperTooth3", { 0.07, 0.12, 0.05 }, { 0.05, 0.68, -1.21 }, White),
		block("UpperTooth4", { 0.07, 0.12, 0.05 }, { 0.15, 0.68, -1.21 }, White),
		limb("Jaw", { 0.45, 0.15, 0.55 }, { 0, 0.58, -0.85 }, WolfShade, "X", 15, 1.5, 0, { 0, 0, 0.27 }),
		limb("JawTeeth", { 0.38, 0.1, 0.05 }, { 0, 0.68, -1.1 }, White, "X", 15, 1.5, 0, { 0, -0.1, 0.52 }),
		limb(
			"JawBlood",
			{ 0.08, 0.3, 0.06 },
			{ 0.12, 0.42, -1.1 },
			Blood,
			"X",
			15,
			1.5,
			0,
			{ 0, 0.16, 0.52 }
		),
		block("SnoutBlood", { 0.52, 0.1, 0.3 }, { 0, 0.73, -1.02 }, Blood),
		tilt(block("Bristle1", { 0.25, 0.5, 0.2 }, { 0, 0.95, 0.5 }, WolfShade), 40, 0, 0),
		block("Torso", { 1.3, 1.7, 0.9 }, { 0, -0.2, 0 }, WolfWhite),
		block("Chest", { 0.9, 1.2, 0.1 }, { 0, -0.1, -0.48 }, WolfLight),
		block("Belly", { 1, 0.3, 0.8 }, { 0, -1.05, 0 }, WolfShade),
		tilt(block("Bristle2", { 0.25, 0.5, 0.2 }, { 0, 0.55, 0.55 }, WolfShade), 40, 0, 0),
		tilt(block("Bristle3", { 0.25, 0.45, 0.2 }, { 0, 0.15, 0.55 }, WolfShade), 40, 0, 0),
		tilt(block("Bristle4", { 0.25, 0.45, 0.2 }, { 0, -0.25, 0.55 }, WolfShade), 40, 0, 0),
		tilt(
			limb("Tail", { 0.4, 0.4, 1 }, { 0, -0.85, 0.85 }, WolfShade, "Y", 30, 2, 0, { 0, 0, -0.5 }),
			30,
			0,
			0
		),
		limb(
			"LeftArm",
			{ 0.35, 1.5, 0.35 },
			{ -0.85, -0.3, 0 },
			WolfWhite,
			"X",
			35,
			1.5,
			0.5,
			{ 0, 0.75, 0 }
		),
		limb(
			"LeftPaw",
			{ 0.42, 0.28, 0.42 },
			{ -0.85, -1.17, -0.03 },
			WolfShade,
			"X",
			35,
			1.5,
			0.5,
			{ 0, 1.62, 0.03 }
		),
		limb(
			"LeftTalon1",
			{ 0.07, 0.12, 0.24 },
			{ -0.99, -1.27, -0.32 },
			Bone,
			"X",
			35,
			1.5,
			0.5,
			{ 0.14, 1.72, 0.32 }
		),
		limb(
			"LeftTalonTip1",
			{ 0.05, 0.12, 0.06 },
			{ -0.99, -1.37, -0.42 },
			Bone,
			"X",
			35,
			1.5,
			0.5,
			{ 0.14, 1.82, 0.42 }
		),
		limb(
			"LeftTalon2",
			{ 0.07, 0.12, 0.24 },
			{ -0.85, -1.27, -0.32 },
			Bone,
			"X",
			35,
			1.5,
			0.5,
			{ 0, 1.72, 0.32 }
		),
		limb(
			"LeftTalonTip2",
			{ 0.05, 0.12, 0.06 },
			{ -0.85, -1.37, -0.42 },
			Bone,
			"X",
			35,
			1.5,
			0.5,
			{ 0, 1.82, 0.42 }
		),
		limb(
			"LeftTalon3",
			{ 0.07, 0.12, 0.24 },
			{ -0.71, -1.27, -0.32 },
			Bone,
			"X",
			35,
			1.5,
			0.5,
			{ -0.14, 1.72, 0.32 }
		),
		limb(
			"LeftTalonTip3",
			{ 0.05, 0.12, 0.06 },
			{ -0.71, -1.37, -0.42 },
			Bone,
			"X",
			35,
			1.5,
			0.5,
			{ -0.14, 1.82, 0.42 }
		),
		limb("RightArm", { 0.35, 1.5, 0.35 }, { 0.85, -0.3, 0 }, WolfWhite, "X", 35, 1.5, 0, { 0, 0.75, 0 }),
		limb(
			"RightPaw",
			{ 0.42, 0.28, 0.42 },
			{ 0.85, -1.17, -0.03 },
			WolfShade,
			"X",
			35,
			1.5,
			0,
			{ 0, 1.62, 0.03 }
		),
		limb(
			"RightTalon1",
			{ 0.07, 0.12, 0.24 },
			{ 0.71, -1.27, -0.32 },
			Bone,
			"X",
			35,
			1.5,
			0,
			{ 0.14, 1.72, 0.32 }
		),
		limb(
			"RightTalonTip1",
			{ 0.05, 0.12, 0.06 },
			{ 0.71, -1.37, -0.42 },
			Bone,
			"X",
			35,
			1.5,
			0,
			{ 0.14, 1.82, 0.42 }
		),
		limb(
			"RightTalon2",
			{ 0.07, 0.12, 0.24 },
			{ 0.85, -1.27, -0.32 },
			Bone,
			"X",
			35,
			1.5,
			0,
			{ 0, 1.72, 0.32 }
		),
		limb(
			"RightTalonTip2",
			{ 0.05, 0.12, 0.06 },
			{ 0.85, -1.37, -0.42 },
			Bone,
			"X",
			35,
			1.5,
			0,
			{ 0, 1.82, 0.42 }
		),
		limb(
			"RightTalon3",
			{ 0.07, 0.12, 0.24 },
			{ 0.99, -1.27, -0.32 },
			Bone,
			"X",
			35,
			1.5,
			0,
			{ -0.14, 1.72, 0.32 }
		),
		limb(
			"RightTalonTip3",
			{ 0.05, 0.12, 0.06 },
			{ 0.99, -1.37, -0.42 },
			Bone,
			"X",
			35,
			1.5,
			0,
			{ -0.14, 1.82, 0.42 }
		),
		limb(
			"LeftLeg",
			{ 0.4, 0.65, 0.4 },
			{ -0.35, -1.37, 0.05 },
			WolfWhite,
			"X",
			30,
			1.5,
			0,
			{ 0, 0.32, 0 }
		),
		limb(
			"LeftFoot",
			{ 0.42, 0.22, 0.6 },
			{ -0.35, -1.89, -0.12 },
			WolfShade,
			"X",
			30,
			1.5,
			0,
			{ 0, 0.84, 0.17 }
		),
		limb(
			"LeftToeClaw1",
			{ 0.07, 0.08, 0.2 },
			{ -0.48, -1.94, -0.5 },
			Bone,
			"X",
			30,
			1.5,
			0,
			{ 0.13, 0.89, 0.55 }
		),
		limb(
			"LeftToeClaw2",
			{ 0.07, 0.08, 0.2 },
			{ -0.35, -1.94, -0.5 },
			Bone,
			"X",
			30,
			1.5,
			0,
			{ 0, 0.89, 0.55 }
		),
		limb(
			"LeftToeClaw3",
			{ 0.07, 0.08, 0.2 },
			{ -0.22, -1.94, -0.5 },
			Bone,
			"X",
			30,
			1.5,
			0,
			{ -0.13, 0.89, 0.55 }
		),
		limb(
			"RightLeg",
			{ 0.4, 0.65, 0.4 },
			{ 0.35, -1.37, 0.05 },
			WolfWhite,
			"X",
			30,
			1.5,
			0.5,
			{ 0, 0.32, 0 }
		),
		limb(
			"RightFoot",
			{ 0.42, 0.22, 0.6 },
			{ 0.35, -1.89, -0.12 },
			WolfShade,
			"X",
			30,
			1.5,
			0.5,
			{ 0, 0.84, 0.17 }
		),
		limb(
			"RightToeClaw1",
			{ 0.07, 0.08, 0.2 },
			{ 0.22, -1.94, -0.5 },
			Bone,
			"X",
			30,
			1.5,
			0.5,
			{ 0.13, 0.89, 0.55 }
		),
		limb(
			"RightToeClaw2",
			{ 0.07, 0.08, 0.2 },
			{ 0.35, -1.94, -0.5 },
			Bone,
			"X",
			30,
			1.5,
			0.5,
			{ 0, 0.89, 0.55 }
		),
		limb(
			"RightToeClaw3",
			{ 0.07, 0.08, 0.2 },
			{ 0.48, -1.94, -0.5 },
			Bone,
			"X",
			30,
			1.5,
			0.5,
			{ -0.13, 0.89, 0.55 }
		),
	},
}

-- Mimic Night, Nightmare: a rusty mailbox on two post legs. Its lid gapes open on rows of sharp
-- teeth, four eyes glowing above.
local Mailbox = { 70, 90, 130 }
Looks.MailboxMimic = {
	gait = "walk",
	top = 1.05,
	grow = 2,
	pieces = {
		block("Box", { 1.2, 1, 1.8 }, { 0, 0.2, 0 }, Mailbox),
		block("Roof", { 1, 0.25, 1.8 }, { 0, 0.82, 0 }, Mailbox),
		block("Rust", { 0.05, 0.4, 0.5 }, { 0.62, 0, 0.4 }, { 140, 80, 40 }),
		block("FlagPost", { 0.1, 0.6, 0.12 }, { 0.65, 0.5, 0.35 }, CircusRed),
		limb("Flag", { 0.1, 0.25, 0.45 }, { 0.65, 0.7, 0.1 }, CircusRed, "X", 25, 2, 0, { 0, 0, 0.22 }),
		limb("LeftPost", { 0.3, 1.7, 0.3 }, { -0.25, -1.15, 0 }, Wood, "X", 25, 1.8, 0, { 0, 0.85, 0 }),
		limb("RightPost", { 0.3, 1.7, 0.3 }, { 0.25, -1.15, 0 }, Wood, "X", 25, 1.8, 0.5, { 0, 0.85, 0 }),
		block("Inside", { 1, 0.9, 0.05 }, { 0, 0.2, -0.88 }, Black),
		block("Gum", { 1, 0.1, 0.06 }, { 0, 0.62, -0.89 }, DeepRed),
		block("LeftEye", { 0.2, 0.2, 0.05 }, { -0.22, 0.82, -0.91 }, Nightmare, true),
		block("RightEye", { 0.2, 0.2, 0.05 }, { 0.22, 0.82, -0.91 }, Nightmare, true),
		block("SmallLeftEye", { 0.1, 0.1, 0.05 }, { -0.42, 0.85, -0.91 }, Nightmare, true),
		block("SmallRightEye", { 0.1, 0.1, 0.05 }, { 0.42, 0.85, -0.91 }, Nightmare, true),
		block("Drool1", { 0.05, 0.3, 0.05 }, { -0.12, 0.3, -0.9 }, Blood),
		block("Drool2", { 0.05, 0.2, 0.05 }, { 0.3, 0.35, -0.9 }, Blood),
		block("Tooth1", { 0.14, 0.1, 0.06 }, { -0.38, 0.53, -0.9 }, White),
		block("ToothTip1", { 0.06, 0.14, 0.06 }, { -0.38, 0.41, -0.9 }, White),
		block("Tooth2", { 0.14, 0.1, 0.06 }, { -0.19, 0.53, -0.9 }, White),
		block("ToothTip2", { 0.06, 0.14, 0.06 }, { -0.19, 0.41, -0.9 }, White),
		block("Tooth3", { 0.14, 0.1, 0.06 }, { 0, 0.53, -0.9 }, White),
		block("ToothTip3", { 0.06, 0.14, 0.06 }, { 0, 0.41, -0.9 }, White),
		block("Tooth4", { 0.14, 0.1, 0.06 }, { 0.19, 0.53, -0.9 }, White),
		block("ToothTip4", { 0.06, 0.14, 0.06 }, { 0.19, 0.41, -0.9 }, White),
		block("Tooth5", { 0.14, 0.1, 0.06 }, { 0.38, 0.53, -0.9 }, White),
		block("ToothTip5", { 0.06, 0.14, 0.06 }, { 0.38, 0.41, -0.9 }, White),
		tilt(
			limb("Lid", { 1.2, 1, 0.08 }, { 0, -0.035, -1.364 }, Mailbox, "X", -15, 2, 0, { 0, -0.5, 0 }),
			-58,
			0,
			0
		),
		tilt(
			limb(
				"LidHandle",
				{ 0.3, 0.1, 0.1 },
				{ 0, 0.083, -1.703 },
				Iron,
				"X",
				-15,
				2,
				0,
				{ 0, -0.85, 0.08 }
			),
			-58,
			0,
			0
		),
		tilt(
			limb(
				"LidTooth1",
				{ 0.14, 0.1, 0.06 },
				{ -0.36, 0.277, -1.806 },
				White,
				"X",
				-15,
				2,
				0,
				{ 0.36, -1.04, -0.03 }
			),
			-58,
			0,
			0
		),
		tilt(
			limb(
				"LidToothTip1",
				{ 0.06, 0.14, 0.06 },
				{ -0.36, 0.34, -1.908 },
				White,
				"X",
				-15,
				2,
				0,
				{ 0.36, -1.16, -0.03 }
			),
			-58,
			0,
			0
		),
		tilt(
			limb(
				"LidTooth2",
				{ 0.14, 0.1, 0.06 },
				{ -0.12, 0.277, -1.806 },
				White,
				"X",
				-15,
				2,
				0,
				{ 0.12, -1.04, -0.03 }
			),
			-58,
			0,
			0
		),
		tilt(
			limb(
				"LidToothTip2",
				{ 0.06, 0.14, 0.06 },
				{ -0.12, 0.34, -1.908 },
				White,
				"X",
				-15,
				2,
				0,
				{ 0.12, -1.16, -0.03 }
			),
			-58,
			0,
			0
		),
		tilt(
			limb(
				"LidTooth3",
				{ 0.14, 0.1, 0.06 },
				{ 0.12, 0.277, -1.806 },
				White,
				"X",
				-15,
				2,
				0,
				{ -0.12, -1.04, -0.03 }
			),
			-58,
			0,
			0
		),
		tilt(
			limb(
				"LidToothTip3",
				{ 0.06, 0.14, 0.06 },
				{ 0.12, 0.34, -1.908 },
				White,
				"X",
				-15,
				2,
				0,
				{ -0.12, -1.16, -0.03 }
			),
			-58,
			0,
			0
		),
		tilt(
			limb(
				"LidTooth4",
				{ 0.14, 0.1, 0.06 },
				{ 0.36, 0.277, -1.806 },
				White,
				"X",
				-15,
				2,
				0,
				{ -0.36, -1.04, -0.03 }
			),
			-58,
			0,
			0
		),
		tilt(
			limb(
				"LidToothTip4",
				{ 0.06, 0.14, 0.06 },
				{ 0.36, 0.34, -1.908 },
				White,
				"X",
				-15,
				2,
				0,
				{ -0.36, -1.16, -0.03 }
			),
			-58,
			0,
			0
		),
	},
}

-- Mimic Night, Nightmare: an old street lamp come alive. A fanged face glares out of its lantern,
-- long iron arms with finger claws hang from its ladder bar, and its cast-iron base splits
-- into two heavy feet.
local SickLight = { 210, 255, 140 }
local LampDark = { 30, 30, 34 }
local SignGreen = { 40, 80, 50 }
Looks.LamppostLurker = {
	gait = "walk",
	top = 3.2,
	grow = 2,
	pieces = {
		block("Lamp", { 0.7, 0.8, 0.7 }, { 0, 2, 0 }, SickLight, true),
		block("LampBottom", { 0.85, 0.12, 0.85 }, { 0, 1.56, 0 }, Iron),
		block("LampNeck", { 0.4, 0.15, 0.4 }, { 0, 1.43, 0 }, Iron),
		block("LampPost1", { 0.08, 0.85, 0.08 }, { -0.36, 2, -0.36 }, Iron),
		block("LampPost2", { 0.08, 0.85, 0.08 }, { 0.36, 2, -0.36 }, Iron),
		block("LampPost3", { 0.08, 0.85, 0.08 }, { -0.36, 2, 0.36 }, Iron),
		block("LampPost4", { 0.08, 0.85, 0.08 }, { 0.36, 2, 0.36 }, Iron),
		block("LampTop", { 0.85, 0.12, 0.85 }, { 0, 2.46, 0 }, Iron),
		block("Cap", { 0.95, 0.15, 0.95 }, { 0, 2.58, 0 }, Iron),
		block("CapMiddle", { 0.6, 0.15, 0.6 }, { 0, 2.72, 0 }, Iron),
		block("CapTop", { 0.3, 0.15, 0.3 }, { 0, 2.86, 0 }, Iron),
		block("Finial", { 0.1, 0.3, 0.1 }, { 0, 3.08, 0 }, Iron),
		block("FinialBall", { 0.16, 0.16, 0.16 }, { 0, 3, 0 }, Iron),
		block("LeftEye", { 0.17, 0.22, 0.05 }, { -0.15, 2.12, -0.37 }, Black),
		block("RightEye", { 0.17, 0.22, 0.05 }, { 0.15, 2.12, -0.37 }, Black),
		block("LeftPupil", { 0.06, 0.06, 0.05 }, { -0.15, 2.1, -0.4 }, RedEye, true),
		block("RightPupil", { 0.06, 0.06, 0.05 }, { 0.15, 2.1, -0.4 }, RedEye, true),
		block("Mouth", { 0.5, 0.2, 0.05 }, { 0, 1.83, -0.37 }, Black),
		block("Tooth1", { 0.08, 0.1, 0.05 }, { -0.16, 1.88, -0.4 }, White),
		block("Tooth2", { 0.08, 0.1, 0.05 }, { 0, 1.88, -0.4 }, White),
		block("Tooth3", { 0.08, 0.1, 0.05 }, { 0.16, 1.88, -0.4 }, White),
		block("Pole", { 0.25, 2, 0.25 }, { 0, 0.4, 0 }, Iron),
		block("RingHigh", { 0.35, 0.1, 0.35 }, { 0, 1.2, 0 }, Iron),
		block("RingMiddle", { 0.35, 0.1, 0.35 }, { 0, 0.4, 0 }, Iron),
		block("Flute1", { 0.05, 1.4, 0.27 }, { -0.1, 0.4, 0 }, LampDark),
		block("Flute2", { 0.05, 1.4, 0.27 }, { 0.1, 0.4, 0 }, LampDark),
		block("LadderBar", { 1.1, 0.1, 0.1 }, { 0, 1.3, 0 }, Iron),
		block("BarEndLeft", { 0.12, 0.12, 0.12 }, { -0.55, 1.3, 0 }, Iron),
		block("BarEndRight", { 0.12, 0.12, 0.12 }, { 0.55, 1.3, 0 }, Iron),
		tilt(block("ScrollLeft", { 0.06, 0.4, 0.06 }, { -0.22, 1.48, 0 }, Iron), 0, 0, -30),
		tilt(block("ScrollRight", { 0.06, 0.4, 0.06 }, { 0.22, 1.48, 0 }, Iron), 0, 0, 30),
		block("SignPost", { 0.06, 0.3, 0.06 }, { 0, 0.85, 0 }, Iron),
		block("SignA", { 0.75, 0.18, 0.04 }, { 0.45, 0.85, 0 }, SignGreen),
		block("SignB", { 0.04, 0.18, 0.75 }, { 0, 0.62, 0.45 }, SignGreen),
		block("SignTextA", { 0.5, 0.05, 0.045 }, { 0.45, 0.85, 0 }, White),
		block("SignTextB", { 0.045, 0.05, 0.5 }, { 0, 0.62, 0.45 }, White),
		block("PoleBlood", { 0.27, 0.4, 0.27 }, { 0, 1, 0 }, Blood),
		block("PoleBloodDrip", { 0.07, 0.35, 0.07 }, { 0.09, 0.65, -0.12 }, Blood),
		block("Base", { 0.6, 0.35, 0.6 }, { 0, -0.75, 0 }, Iron),
		block("BaseRing", { 0.7, 0.1, 0.7 }, { 0, -0.55, 0 }, Iron),
		block("BaseSkirt", { 0.75, 0.15, 0.6 }, { 0, -0.98, 0 }, LampDark),
		limb("LeftLeg", { 0.25, 0.45, 0.25 }, { -0.2, -1.25, 0 }, Iron, "X", 25, 1.2, 0, { 0, 0.25, 0 }),
		limb(
			"LeftLegRing",
			{ 0.33, 0.08, 0.33 },
			{ -0.2, -1.45, 0 },
			LampDark,
			"X",
			25,
			1.2,
			0,
			{ 0, 0.45, 0 }
		),
		limb("LeftPlinth", { 0.38, 0.35, 0.38 }, { -0.2, -1.66, 0 }, Iron, "X", 25, 1.2, 0, { 0, 0.66, 0 }),
		limb(
			"LeftFootPlate",
			{ 0.48, 0.12, 0.5 },
			{ -0.2, -1.94, -0.04 },
			LampDark,
			"X",
			25,
			1.2,
			0,
			{ 0, 0.94, 0.04 }
		),
		limb("RightLeg", { 0.25, 0.45, 0.25 }, { 0.2, -1.25, 0 }, Iron, "X", 25, 1.2, 0.5, { 0, 0.25, 0 }),
		limb(
			"RightLegRing",
			{ 0.33, 0.08, 0.33 },
			{ 0.2, -1.45, 0 },
			LampDark,
			"X",
			25,
			1.2,
			0.5,
			{ 0, 0.45, 0 }
		),
		limb("RightPlinth", { 0.38, 0.35, 0.38 }, { 0.2, -1.66, 0 }, Iron, "X", 25, 1.2, 0.5, { 0, 0.66, 0 }),
		limb(
			"RightFootPlate",
			{ 0.48, 0.12, 0.5 },
			{ 0.2, -1.94, -0.04 },
			LampDark,
			"X",
			25,
			1.2,
			0.5,
			{ 0, 0.94, 0.04 }
		),
		limb("LeftArm", { 0.12, 1.6, 0.12 }, { -0.55, 0.45, -0.05 }, Iron, "X", 30, 1.2, 0.5, { 0, 0.8, 0 }),
		limb(
			"LeftHand",
			{ 0.25, 0.14, 0.2 },
			{ -0.55, -0.42, -0.05 },
			Iron,
			"X",
			30,
			1.2,
			0.5,
			{ 0, 1.67, 0 }
		),
		limb(
			"LeftFinger1",
			{ 0.05, 0.45, 0.05 },
			{ -0.64, -0.71, -0.05 },
			Iron,
			"X",
			30,
			1.2,
			0.5,
			{ 0.09, 1.96, 0 }
		),
		limb(
			"LeftFinger2",
			{ 0.05, 0.45, 0.05 },
			{ -0.55, -0.71, -0.05 },
			Iron,
			"X",
			30,
			1.2,
			0.5,
			{ 0, 1.96, 0 }
		),
		limb(
			"LeftFinger3",
			{ 0.05, 0.45, 0.05 },
			{ -0.46, -0.71, -0.05 },
			Iron,
			"X",
			30,
			1.2,
			0.5,
			{ -0.09, 1.96, 0 }
		),
		limb("RightArm", { 0.12, 1.6, 0.12 }, { 0.55, 0.45, -0.05 }, Iron, "X", 30, 1.2, 0, { 0, 0.8, 0 }),
		limb("RightHand", { 0.25, 0.14, 0.2 }, { 0.55, -0.42, -0.05 }, Iron, "X", 30, 1.2, 0, { 0, 1.67, 0 }),
		limb(
			"RightFinger1",
			{ 0.05, 0.45, 0.05 },
			{ 0.46, -0.71, -0.05 },
			Iron,
			"X",
			30,
			1.2,
			0,
			{ 0.09, 1.96, 0 }
		),
		limb(
			"RightFinger2",
			{ 0.05, 0.45, 0.05 },
			{ 0.55, -0.71, -0.05 },
			Iron,
			"X",
			30,
			1.2,
			0,
			{ 0, 1.96, 0 }
		),
		limb(
			"RightFinger3",
			{ 0.05, 0.45, 0.05 },
			{ 0.64, -0.71, -0.05 },
			Iron,
			"X",
			30,
			1.2,
			0,
			{ -0.09, 1.96, 0 }
		),
	},
}

-- Breach Storm, Nightmare: a scowling storm gremlin with a mouth full of fangs. A big thundercloud
-- hangs high over its head, spitting jagged lightning.
local StormSkin = { 60, 70, 100 }
local Spark = { 120, 230, 255 }
local Lightning = { 255, 240, 120 }
local StormDark = { 30, 35, 55 }
local CloudGrey = { 70, 72, 85 }
local CloudLight = { 95, 98, 112 }
local CloudDark = { 45, 46, 56 }
Looks.StormGremlin = {
	gait = "walk",
	top = 2.35,
	grow = 2,
	pieces = {
		block("Body", { 1, 1, 0.8 }, { 0, -1, 0 }, StormSkin),
		block("Head", { 1, 0.8, 0.8 }, { 0, -0.1, -0.05 }, StormSkin),
		block("LeftEye", { 0.22, 0.22, 0.05 }, { -0.22, 0, -0.47 }, Spark, true),
		block("RightEye", { 0.22, 0.22, 0.05 }, { 0.22, 0, -0.47 }, Spark, true),
		tilt(block("LeftEar", { 0.55, 0.3, 0.1 }, { -0.7, 0.05, 0 }, StormSkin), 0, 0, -25),
		tilt(block("RightEar", { 0.55, 0.3, 0.1 }, { 0.7, 0.05, 0 }, StormSkin), 0, 0, 25),
		limb("Tail", { 0.15, 0.15, 0.8 }, { 0, -1.1, 0.75 }, StormSkin, "Y", 30, 2.5, 0, { 0, 0, -0.4 }),
		limb(
			"TailBolt",
			{ 0.1, 0.4, 0.25 },
			{ 0, -1, 1.2 },
			Lightning,
			"Y",
			30,
			2.5,
			0,
			{ 0, -0.1, -0.85 },
			true
		),
		limb("LeftArm", { 0.25, 0.7, 0.25 }, { -0.62, -1, 0 }, StormSkin, "X", 30, 2.2, 0.5, { 0, 0.35, 0 }),
		limb(
			"LeftSpark",
			{ 0.2, 0.2, 0.2 },
			{ -0.62, -1.45, 0 },
			Spark,
			"X",
			30,
			2.2,
			0.5,
			{ 0, 0.8, 0 },
			true
		),
		limb("RightArm", { 0.25, 0.7, 0.25 }, { 0.62, -1, 0 }, StormSkin, "X", 30, 2.2, 0, { 0, 0.35, 0 }),
		limb(
			"RightSpark",
			{ 0.2, 0.2, 0.2 },
			{ 0.62, -1.45, 0 },
			Spark,
			"X",
			30,
			2.2,
			0,
			{ 0, 0.8, 0 },
			true
		),
		limb("LeftLeg", { 0.3, 0.5, 0.3 }, { -0.3, -1.75, 0 }, StormSkin, "X", 30, 2.2, 0, { 0, 0.25, 0 }),
		limb("RightLeg", { 0.3, 0.5, 0.3 }, { 0.3, -1.75, 0 }, StormSkin, "X", 30, 2.2, 0.5, { 0, 0.25, 0 }),
		block("LeftPupil", { 0.06, 0.18, 0.05 }, { -0.22, 0, -0.5 }, Black),
		block("RightPupil", { 0.06, 0.18, 0.05 }, { 0.22, 0, -0.5 }, Black),
		block("Mouth", { 0.7, 0.22, 0.05 }, { 0, -0.3, -0.47 }, Black),
		block("Fang1", { 0.08, 0.12, 0.05 }, { -0.25, -0.24, -0.5 }, White),
		block("Fang2", { 0.08, 0.12, 0.05 }, { -0.08, -0.24, -0.5 }, White),
		block("Fang3", { 0.08, 0.12, 0.05 }, { 0.08, -0.24, -0.5 }, White),
		block("Fang4", { 0.08, 0.12, 0.05 }, { 0.25, -0.24, -0.5 }, White),
		tilt(block("LeftHorn", { 0.14, 0.45, 0.14 }, { -0.42, 0.42, 0.15 }, Black), 0, 0, 30),
		tilt(block("RightHorn", { 0.14, 0.45, 0.14 }, { 0.42, 0.42, 0.15 }, Black), 0, 0, -30),
		tilt(block("Vein1", { 0.05, 0.6, 0.05 }, { -0.2, -1, -0.41 }, Spark, true), 0, 0, 25),
		tilt(block("Vein2", { 0.05, 0.5, 0.05 }, { 0.2, -1.05, -0.41 }, Spark, true), 0, 0, -30),
		tilt(block("LeftBrow", { 0.32, 0.08, 0.05 }, { -0.22, 0.17, -0.47 }, Black), 0, 0, -25),
		tilt(block("RightBrow", { 0.32, 0.08, 0.05 }, { 0.22, 0.17, -0.47 }, Black), 0, 0, 25),
		tilt(block("HairSpike1", { 0.14, 0.4, 0.14 }, { -0.2, 0.38, 0.05 }, StormDark), 0, 0, 25),
		block("HairSpike2", { 0.14, 0.45, 0.14 }, { 0, 0.42, 0.1 }, StormDark),
		tilt(block("HairSpike3", { 0.14, 0.4, 0.14 }, { 0.2, 0.38, 0.05 }, StormDark), 0, 0, -25),
		slide(limb("Cloud", { 1.9, 0.5, 1.3 }, { 0, 1.75, 0 }, CloudGrey, "Y", 0.12, 0.6, 0, { 0, 0, 0 })),
		slide(
			limb(
				"CloudPuffLeft",
				{ 0.9, 0.5, 0.9 },
				{ -0.55, 2.05, 0.05 },
				CloudLight,
				"Y",
				0.12,
				0.6,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"CloudPuffRight",
				{ 1, 0.45, 0.9 },
				{ 0.5, 2, -0.05 },
				CloudLight,
				"Y",
				0.12,
				0.6,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb(
				"CloudPuffTop",
				{ 0.7, 0.35, 0.7 },
				{ 0, 2.25, 0.1 },
				CloudGrey,
				"Y",
				0.12,
				0.6,
				0,
				{ 0, 0, 0 }
			)
		),
		slide(
			limb("CloudBottom", { 1.5, 0.12, 1 }, { 0, 1.46, 0 }, CloudDark, "Y", 0.12, 0.6, 0, { 0, 0, 0 })
		),
		tilt(
			slide(
				limb(
					"BoltLeft1",
					{ 0.07, 0.4, 0.07 },
					{ -0.8, 1.247, -0.2 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0, 0 },
					true
				)
			),
			0,
			0,
			-30
		),
		tilt(
			slide(
				limb(
					"BoltLeft2",
					{ 0.07, 0.35, 0.07 },
					{ -0.8, 0.93, -0.2 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0, 0 },
					true
				)
			),
			0,
			0,
			35
		),
		tilt(
			slide(
				limb(
					"BoltLeft3",
					{ 0.07, 0.45, 0.07 },
					{ -0.794, 0.583, -0.2 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0, 0 },
					true
				)
			),
			0,
			0,
			-25
		),
		tilt(
			slide(
				limb(
					"BoltLeft4",
					{ 0.07, 0.3, 0.07 },
					{ -0.814, 0.249, -0.2 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0, 0 },
					true
				)
			),
			0,
			0,
			30
		),
		tilt(
			slide(
				limb(
					"BoltRight1",
					{ 0.07, 0.35, 0.07 },
					{ 0.838, 1.268, 0.1 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0.001, 0 },
					true
				)
			),
			0,
			0,
			30
		),
		tilt(
			slide(
				limb(
					"BoltRight2",
					{ 0.07, 0.4, 0.07 },
					{ 0.81, 0.953, 0.1 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0, 0 },
					true
				)
			),
			0,
			0,
			-35
		),
		tilt(
			slide(
				limb(
					"BoltRight3",
					{ 0.07, 0.4, 0.07 },
					{ 0.78, 0.608, 0.1 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0, 0 },
					true
				)
			),
			0,
			0,
			25
		),
		tilt(
			slide(
				limb(
					"BoltMiddle1",
					{ 0.07, 0.3, 0.07 },
					{ -0.013, 1.284, -0.35 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0, 0 },
					true
				)
			),
			0,
			0,
			-25
		),
		tilt(
			slide(
				limb(
					"BoltMiddle2",
					{ 0.07, 0.3, 0.07 },
					{ -0.002, 1.018, -0.35 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0, 0 },
					true
				)
			),
			0,
			0,
			30
		),
		tilt(
			slide(
				limb(
					"BoltBack1",
					{ 0.07, 0.35, 0.07 },
					{ -0.14, 1.256, 0.45 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0, 0 },
					true
				)
			),
			0,
			0,
			20
		),
		tilt(
			slide(
				limb(
					"BoltBack2",
					{ 0.07, 0.3, 0.07 },
					{ -0.155, 0.961, 0.45 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0, 0 },
					true
				)
			),
			0,
			0,
			-30
		),
		tilt(
			slide(
				limb(
					"BoltBack3",
					{ 0.07, 0.35, 0.07 },
					{ -0.156, 0.673, 0.45 },
					Lightning,
					"Y",
					0.12,
					0.6,
					0,
					{ 0, 0, 0 },
					true
				)
			),
			0,
			0,
			25
		),
	},
}

-- Breach Storm, Nightmare: a front door that walks. Peepholes for eyes, a brass knocker for a
-- mouth that swings as it goes.
local DoorWood = { 110, 35, 30 }
local DoorPanel = { 85, 25, 22 }
Looks.Doorknocker = {
	gait = "walk",
	top = 1.5,
	grow = 2,
	pieces = {
		block("Door", { 1.6, 2.8, 0.3 }, { 0, -0.2, 0 }, DoorWood),
		block("Arch", { 1.2, 0.25, 0.3 }, { 0, 1.32, 0 }, DoorWood),
		block("PanelTopLeft", { 0.5, 0.8, 0.05 }, { -0.38, 0.6, -0.17 }, DoorPanel),
		block("PanelTopRight", { 0.5, 0.8, 0.05 }, { 0.38, 0.6, -0.17 }, DoorPanel),
		block("PanelLowLeft", { 0.5, 0.8, 0.05 }, { -0.38, -1, -0.17 }, DoorPanel),
		block("PanelLowRight", { 0.5, 0.8, 0.05 }, { 0.38, -1, -0.17 }, DoorPanel),
		block("LeftEye", { 0.15, 0.15, 0.05 }, { -0.38, 0.75, -0.2 }, RedEye, true),
		block("RightEye", { 0.15, 0.15, 0.05 }, { 0.38, 0.75, -0.2 }, RedEye, true),
		block("LionFace", { 0.4, 0.35, 0.06 }, { 0, 0.1, -0.19 }, Bronze),
		limb("Knocker", { 0.5, 0.5, 0.08 }, { 0, -0.3, -0.22 }, Bronze, "X", 25, 2, 0, { 0, 0.25, 0 }),
		block("Handle", { 0.12, 0.3, 0.15 }, { 0.6, -0.25, -0.22 }, Bronze),
		limb("LeftArm", { 0.25, 1, 0.25 }, { -0.93, -0.4, 0 }, DoorPanel, "X", 30, 1.5, 0.5, { 0, 0.45, 0 }),
		limb("LeftHand", { 0.3, 0.25, 0.3 }, { -0.93, -1, 0 }, Bronze, "X", 30, 1.5, 0.5, { 0, 1.05, 0 }),
		limb("RightArm", { 0.25, 1, 0.25 }, { 0.93, -0.4, 0 }, DoorPanel, "X", 30, 1.5, 0, { 0, 0.45, 0 }),
		limb("RightHand", { 0.3, 0.25, 0.3 }, { 0.93, -1, 0 }, Bronze, "X", 30, 1.5, 0, { 0, 1.05, 0 }),
		limb("LeftLeg", { 0.35, 0.4, 0.3 }, { -0.45, -1.8, 0 }, DoorPanel, "X", 30, 1.5, 0, { 0, 0.2, 0 }),
		limb("RightLeg", { 0.35, 0.4, 0.3 }, { 0.45, -1.8, 0 }, DoorPanel, "X", 30, 1.5, 0.5, { 0, 0.2, 0 }),
		block("Mouth", { 0.9, 0.3, 0.05 }, { 0, -0.78, -0.18 }, Black),
		block("TopTooth1", { 0.12, 0.12, 0.05 }, { -0.33, -0.68, -0.21 }, White),
		block("TopTooth2", { 0.12, 0.12, 0.05 }, { -0.11, -0.68, -0.21 }, White),
		block("TopTooth3", { 0.12, 0.12, 0.05 }, { 0.11, -0.68, -0.21 }, White),
		block("TopTooth4", { 0.12, 0.12, 0.05 }, { 0.33, -0.68, -0.21 }, White),
		block("BottomTooth1", { 0.12, 0.12, 0.05 }, { -0.22, -0.88, -0.21 }, White),
		block("BottomTooth2", { 0.12, 0.12, 0.05 }, { 0, -0.88, -0.21 }, White),
		block("BottomTooth3", { 0.12, 0.12, 0.05 }, { 0.22, -0.88, -0.21 }, White),
		block("BloodDrip1", { 0.08, 0.45, 0.05 }, { -0.25, -1.1, -0.19 }, Blood),
		block("BloodDrip2", { 0.08, 0.3, 0.05 }, { 0.3, -1.05, -0.19 }, Blood),
		tilt(block("Scratch1", { 0.04, 0.7, 0.04 }, { -0.45, 0.6, -0.2 }, Black), 0, 0, 20),
		tilt(block("Scratch2", { 0.04, 0.7, 0.04 }, { -0.33, 0.6, -0.2 }, Black), 0, 0, 20),
		tilt(block("Scratch3", { 0.04, 0.7, 0.04 }, { -0.21, 0.6, -0.2 }, Black), 0, 0, 20),
		limb(
			"LeftFinger1",
			{ 0.06, 0.3, 0.06 },
			{ -1.03, -1.25, 0 },
			Bone,
			"X",
			30,
			1.5,
			0.5,
			{ 0.1, 1.3, 0 }
		),
		limb("LeftFinger2", { 0.06, 0.3, 0.06 }, { -0.93, -1.25, 0 }, Bone, "X", 30, 1.5, 0.5, { 0, 1.3, 0 }),
		limb(
			"LeftFinger3",
			{ 0.06, 0.3, 0.06 },
			{ -0.83, -1.25, 0 },
			Bone,
			"X",
			30,
			1.5,
			0.5,
			{ -0.1, 1.3, 0 }
		),
		limb("RightFinger1", { 0.06, 0.3, 0.06 }, { 0.83, -1.25, 0 }, Bone, "X", 30, 1.5, 0, { 0.1, 1.3, 0 }),
		limb("RightFinger2", { 0.06, 0.3, 0.06 }, { 0.93, -1.25, 0 }, Bone, "X", 30, 1.5, 0, { 0, 1.3, 0 }),
		limb(
			"RightFinger3",
			{ 0.06, 0.3, 0.06 },
			{ 1.03, -1.25, 0 },
			Bone,
			"X",
			30,
			1.5,
			0,
			{ -0.1, 1.3, 0 }
		),
	},
}

-- Watcher Awakens, Eldritch: a floating eyeball under a fleshy lid, bloodshot all the way round,
-- with a fanged maw beneath its eye and dangling tentacles.
local Eyeball = { 230, 225, 215 }
local SpikeTip = { 90, 15, 25 }
local Vein = { 180, 30, 40 }
local FleshDark = { 45, 20, 55 }
Looks.Watcherling = {
	gait = "float",
	top = 1.3,
	grow = 2,
	pieces = {
		block("Eyeball", { 1.4, 1.4, 1.4 }, { 0, 0.3, 0 }, Eyeball),
		block("Iris", { 0.7, 0.7, 0.1 }, { 0, 0.3, -0.72 }, Eldritch, true),
		block("Pupil", { 0.15, 0.5, 0.05 }, { 0, 0.3, -0.78 }, Black),
		limb(
			"FrontLeftTentacle",
			{ 0.25, 1.2, 0.25 },
			{ -0.45, -0.85, -0.4 },
			Flesh,
			"X",
			20,
			1.2,
			0,
			{ 0, 0.6, 0 }
		),
		limb(
			"FrontLeftTip",
			{ 0.2, 0.2, 0.2 },
			{ -0.45, -1.55, -0.4 },
			Eldritch,
			"X",
			20,
			1.2,
			0,
			{ 0, 1.3, 0 },
			true
		),
		limb(
			"FrontRightTentacle",
			{ 0.25, 1.2, 0.25 },
			{ 0.45, -0.85, -0.4 },
			Flesh,
			"Z",
			20,
			1.2,
			0.25,
			{ 0, 0.6, 0 }
		),
		limb(
			"FrontRightTip",
			{ 0.2, 0.2, 0.2 },
			{ 0.45, -1.55, -0.4 },
			Eldritch,
			"Z",
			20,
			1.2,
			0.25,
			{ 0, 1.3, 0 },
			true
		),
		limb(
			"BackLeftTentacle",
			{ 0.25, 1.2, 0.25 },
			{ -0.45, -0.85, 0.4 },
			Flesh,
			"Z",
			20,
			1.2,
			0.5,
			{ 0, 0.6, 0 }
		),
		limb(
			"BackLeftTip",
			{ 0.2, 0.2, 0.2 },
			{ -0.45, -1.55, 0.4 },
			Eldritch,
			"Z",
			20,
			1.2,
			0.5,
			{ 0, 1.3, 0 },
			true
		),
		limb(
			"BackRightTentacle",
			{ 0.25, 1.2, 0.25 },
			{ 0.45, -0.85, 0.4 },
			Flesh,
			"X",
			20,
			1.2,
			0.75,
			{ 0, 0.6, 0 }
		),
		limb(
			"BackRightTip",
			{ 0.2, 0.2, 0.2 },
			{ 0.45, -1.55, 0.4 },
			Eldritch,
			"X",
			20,
			1.2,
			0.75,
			{ 0, 1.3, 0 },
			true
		),
		block("Maw", { 0.9, 0.25, 0.05 }, { 0, -0.25, -0.71 }, Black),
		block("Tooth1", { 0.1, 0.12, 0.05 }, { -0.3, -0.18, -0.74 }, White),
		block("Tooth2", { 0.1, 0.12, 0.05 }, { -0.1, -0.18, -0.74 }, White),
		block("Tooth3", { 0.1, 0.12, 0.05 }, { 0.1, -0.18, -0.74 }, White),
		block("Tooth4", { 0.1, 0.12, 0.05 }, { 0.3, -0.18, -0.74 }, White),
		block("LowTooth1", { 0.1, 0.1, 0.05 }, { -0.2, -0.33, -0.74 }, White),
		block("LowTooth2", { 0.1, 0.1, 0.05 }, { 0, -0.33, -0.74 }, White),
		block("LowTooth3", { 0.1, 0.1, 0.05 }, { 0.2, -0.33, -0.74 }, White),
		block("Lid", { 1.6, 0.3, 1.6 }, { 0, 1.15, 0 }, Flesh),
		block("LidRim", { 1.62, 0.08, 1.62 }, { 0, 1, 0 }, FleshDark),
		block("LidEye1", { 0.2, 0.15, 0.05 }, { -0.45, 1.15, -0.82 }, Eldritch, true),
		block("LidEye2", { 0.2, 0.15, 0.05 }, { 0.45, 1.15, -0.82 }, Eldritch, true),
		tilt(block("Vein1", { 0.045, 0.176, 0.03 }, { 0.458, 0.3, -0.71 }, Vein), 0, 0, -90),
		tilt(block("Vein1Branch", { 0.035, 0.2, 0.03 }, { 0.576, 0.352, -0.71 }, Vein), 0, 0, -55),
		tilt(block("Vein2", { 0.045, 0.2376, 0.03 }, { 0.346, 0.646, -0.71 }, Vein), 0, 0, -45),
		tilt(block("Vein3", { 0.045, 0.2112, 0.03 }, { 0, 0.776, -0.71 }, Vein), 0, 0, 0),
		tilt(block("Vein3Branch", { 0.035, 0.2, 0.03 }, { -0.052, 0.902, -0.71 }, Vein), 0, 0, 35),
		tilt(block("Vein4", { 0.045, 0.1848, 0.03 }, { -0.327, 0.627, -0.71 }, Vein), 0, 0, 45),
		tilt(block("Vein5", { 0.045, 0.2464, 0.03 }, { -0.493, 0.3, -0.71 }, Vein), 0, 0, 90),
		tilt(block("Vein5Branch", { 0.035, 0.2, 0.03 }, { -0.629, 0.248, -0.71 }, Vein), 0, 0, 125),
		tilt(block("Vein6", { 0.045, 0.22, 0.03 }, { -0.339, -0.039, -0.71 }, Vein), 0, 0, 135),
		tilt(block("Vein7", { 0.045, 0.1936, 0.03 }, { 0, -0.167, -0.71 }, Vein), 0, 0, 180),
		tilt(block("Vein7Branch", { 0.035, 0.2, 0.03 }, { 0.052, -0.289, -0.71 }, Vein), 0, 0, 215),
		tilt(block("Vein8", { 0.045, 0.2552, 0.03 }, { 0.352, -0.052, -0.71 }, Vein), 0, 0, 225),
		tilt(block("LeftVein1", { 0.03, 0.45, 0.05 }, { -0.71, 0.55, -0.3 }, Vein), 30, 0, 0),
		tilt(block("LeftVein2", { 0.03, 0.45, 0.05 }, { -0.71, 0.1, 0.1 }, Vein), -40, 0, 0),
		tilt(block("LeftVein3", { 0.03, 0.45, 0.05 }, { -0.71, -0.2, -0.4 }, Vein), 60, 0, 0),
		tilt(block("LeftVein4", { 0.03, 0.45, 0.05 }, { -0.71, 0.6, 0.35 }, Vein), -20, 0, 0),
		tilt(block("RightVein1", { 0.03, 0.45, 0.05 }, { 0.71, 0.55, -0.3 }, Vein), 30, 0, 0),
		tilt(block("RightVein2", { 0.03, 0.45, 0.05 }, { 0.71, 0.1, 0.1 }, Vein), -40, 0, 0),
		tilt(block("RightVein3", { 0.03, 0.45, 0.05 }, { 0.71, -0.2, -0.4 }, Vein), 60, 0, 0),
		tilt(block("RightVein4", { 0.03, 0.45, 0.05 }, { 0.71, 0.6, 0.35 }, Vein), -20, 0, 0),
		tilt(block("BackVein1", { 0.045, 0.45, 0.03 }, { -0.3, 0.5, 0.71 }, Vein), 0, 0, 25),
		tilt(block("BackVein2", { 0.045, 0.45, 0.03 }, { 0.35, 0.2, 0.71 }, Vein), 0, 0, -35),
		tilt(block("BackVein3", { 0.045, 0.45, 0.03 }, { 0, -0.1, 0.71 }, Vein), 0, 0, 70),
		tilt(block("BackVein4", { 0.045, 0.45, 0.03 }, { -0.4, -0.2, 0.71 }, Vein), 0, 0, -20),
		tilt(block("UnderVein1", { 0.045, 0.03, 0.45 }, { -0.3, -0.41, 0.2 }, Vein), 0, 30, 0),
		tilt(block("UnderVein2", { 0.045, 0.03, 0.45 }, { 0.3, -0.41, -0.1 }, Vein), 0, -40, 0),
	},
}

-- Watcher Awakens, Eldritch: a piece of the Watcher itself, five times the size of other monsters.
-- A great bloodshot eye in a socket of dark flesh, crowned with spikes, over a jaw that drops open
-- on rows of fangs. Four smaller eyes orbit it and tentacles of every length hang beneath.
Looks.EyeOfTheWatcher = {
	gait = "float",
	top = 2.8,
	grow = 5,
	pieces = {
		block("Socket", { 2, 2, 2 }, { 0, 0.4, 0 }, Flesh),
		block("SocketRim", { 2.05, 2.05, 0.12 }, { 0, 0.4, -0.97 }, FleshDark),
		block("Eyeball", { 1.6, 1.6, 0.3 }, { 0, 0.45, -1.05 }, Eyeball),
		block("Iris", { 0.9, 0.9, 0.1 }, { 0, 0.45, -1.22 }, Eldritch, true),
		block("IrisRing", { 0.7, 0.7, 0.1 }, { 0, 0.45, -1.23 }, { 20, 190, 150 }, true),
		block("Pupil", { 0.18, 0.55, 0.05 }, { 0, 0.45, -1.29 }, Black),
		block("Glint", { 0.12, 0.12, 0.05 }, { 0.2, 0.65, -1.29 }, White, true),
		block("LeftTear", { 0.1, 0.55, 0.05 }, { -0.48, -0.15, -1.22 }, Blood),
		block("RightTear", { 0.1, 0.4, 0.05 }, { 0.52, -0.08, -1.22 }, Blood),
		tilt(block("Vein1", { 0.045, 0.224, 0.03 }, { 0.573, 0.551, -1.215 }, Vein), 0, 0, -80),
		tilt(block("Vein1Branch", { 0.035, 0.2, 0.03 }, { 0.692, 0.624, -1.215 }, Vein), 0, 0, -45),
		tilt(block("Vein2", { 0.045, 0.3024, 0.03 }, { 0.476, 0.849, -1.215 }, Vein), 0, 0, -50),
		tilt(block("Vein3", { 0.045, 0.2688, 0.03 }, { 0.207, 1.018, -1.215 }, Vein), 0, 0, -20),
		tilt(block("Vein3Branch", { 0.035, 0.2, 0.03 }, { 0.206, 1.168, -1.215 }, Vein), 0, 0, 15),
		tilt(block("Vein4", { 0.045, 0.2352, 0.03 }, { -0.102, 1.029, -1.215 }, Vein), 0, 0, 10),
		tilt(block("Vein5", { 0.045, 0.3136, 0.03 }, { -0.403, 0.93, -1.215 }, Vein), 0, 0, 40),
		tilt(block("Vein5Branch", { 0.035, 0.2, 0.03 }, { -0.54, 1.014, -1.215 }, Vein), 0, 0, 75),
		tilt(block("Vein6", { 0.045, 0.28, 0.03 }, { -0.573, 0.659, -1.215 }, Vein), 0, 0, 70),
		tilt(block("Vein7", { 0.045, 0.2464, 0.03 }, { -0.584, 0.347, -1.215 }, Vein), 0, 0, 100),
		tilt(block("Vein7Branch", { 0.035, 0.2, 0.03 }, { -0.708, 0.273, -1.215 }, Vein), 0, 0, 135),
		tilt(block("Vein8", { 0.045, 0.3248, 0.03 }, { -0.484, 0.044, -1.215 }, Vein), 0, 0, 130),
		tilt(block("Vein9", { 0.045, 0.2912, 0.03 }, { -0.211, -0.128, -1.215 }, Vein), 0, 0, 160),
		tilt(block("Vein9Branch", { 0.035, 0.2, 0.03 }, { -0.212, -0.284, -1.215 }, Vein), 0, 0, 195),
		tilt(block("Vein10", { 0.045, 0.2576, 0.03 }, { 0.104, -0.14, -1.215 }, Vein), 0, 0, 190),
		tilt(block("Vein11", { 0.045, 0.224, 0.03 }, { 0.374, 0.004, -1.215 }, Vein), 0, 0, 220),
		tilt(block("Vein11Branch", { 0.035, 0.2, 0.03 }, { 0.497, -0.062, -1.215 }, Vein), 0, 0, 255),
		tilt(block("Vein12", { 0.045, 0.3024, 0.03 }, { 0.584, 0.238, -1.215 }, Vein), 0, 0, 250),
		tilt(block("Spike1A", { 0.3, 0.42, 0.3 }, { -0.86, 1.564, -0.499 }, Black), -15, 0, 30),
		tilt(block("Spike1B", { 0.2, 0.42, 0.2 }, { -1.025, 1.84, -0.573 }, Black), -15, 0, 30),
		tilt(block("Spike1C", { 0.1, 0.42, 0.1 }, { -1.175, 2.091, -0.641 }, SpikeTip), -15, 0, 30),
		tilt(block("Spike2A", { 0.3, 0.504, 0.3 }, { -0.448, 1.623, -0.579 }, Black), -18, 0, 15),
		tilt(block("Spike2B", { 0.2, 0.504, 0.2 }, { -0.551, 1.986, -0.697 }, Black), -18, 0, 15),
		tilt(block("Spike2C", { 0.1, 0.504, 0.1 }, { -0.644, 2.317, -0.804 }, SpikeTip), -18, 0, 15),
		tilt(block("Spike3A", { 0.3, 0.588, 0.3 }, { 0, 1.669, -0.655 }, Black), -20, 0, 0),
		tilt(block("Spike3B", { 0.2, 0.588, 0.2 }, { 0, 2.104, -0.813 }, Black), -20, 0, 0),
		tilt(block("Spike3C", { 0.1, 0.588, 0.1 }, { 0, 2.498, -0.957 }, SpikeTip), -20, 0, 0),
		tilt(block("Spike4A", { 0.3, 0.504, 0.3 }, { 0.448, 1.623, -0.579 }, Black), -18, 0, -15),
		tilt(block("Spike4B", { 0.2, 0.504, 0.2 }, { 0.551, 1.986, -0.697 }, Black), -18, 0, -15),
		tilt(block("Spike4C", { 0.1, 0.504, 0.1 }, { 0.644, 2.317, -0.804 }, SpikeTip), -18, 0, -15),
		tilt(block("Spike5A", { 0.3, 0.42, 0.3 }, { 0.86, 1.564, -0.499 }, Black), -15, 0, -30),
		tilt(block("Spike5B", { 0.2, 0.42, 0.2 }, { 1.025, 1.84, -0.573 }, Black), -15, 0, -30),
		tilt(block("Spike5C", { 0.1, 0.42, 0.1 }, { 1.175, 2.091, -0.641 }, SpikeTip), -15, 0, -30),
		tilt(block("Spike6A", { 0.3, 0.462, 0.3 }, { -0.652, 1.579, 0.443 }, Black), 25, 0, 25),
		tilt(block("Spike6B", { 0.2, 0.462, 0.2 }, { -0.806, 1.877, 0.582 }, Black), 25, 0, 25),
		tilt(block("Spike6C", { 0.1, 0.462, 0.1 }, { -0.945, 2.148, 0.708 }, SpikeTip), 25, 0, 25),
		tilt(block("Spike7A", { 0.3, 0.546, 0.3 }, { 0, 1.633, 0.634 }, Black), 28, 0, 0),
		tilt(block("Spike7B", { 0.2, 0.546, 0.2 }, { 0, 2.011, 0.836 }, Black), 28, 0, 0),
		tilt(block("Spike7C", { 0.1, 0.546, 0.1 }, { 0, 2.356, 1.019 }, SpikeTip), 28, 0, 0),
		tilt(block("Spike8A", { 0.3, 0.462, 0.3 }, { 0.652, 1.579, 0.443 }, Black), 25, 0, -25),
		tilt(block("Spike8B", { 0.2, 0.462, 0.2 }, { 0.806, 1.877, 0.582 }, Black), 25, 0, -25),
		tilt(block("Spike8C", { 0.1, 0.462, 0.1 }, { 0.945, 2.148, 0.708 }, SpikeTip), 25, 0, -25),
		tilt(block("Spike9A", { 0.3, 0.336, 0.3 }, { -0.963, 1.49, 0.927 }, Black), 35, 0, 40),
		tilt(block("Spike9B", { 0.2, 0.336, 0.2 }, { -1.133, 1.656, 1.043 }, Black), 35, 0, 40),
		tilt(block("Spike9C", { 0.1, 0.336, 0.1 }, { -1.287, 1.807, 1.149 }, SpikeTip), 35, 0, 40),
		tilt(block("Spike10A", { 0.3, 0.336, 0.3 }, { 0.963, 1.49, 0.927 }, Black), 35, 0, -40),
		tilt(block("Spike10B", { 0.2, 0.336, 0.2 }, { 1.133, 1.656, 1.043 }, Black), 35, 0, -40),
		tilt(block("Spike10C", { 0.1, 0.336, 0.1 }, { 1.287, 1.807, 1.149 }, SpikeTip), 35, 0, -40),
		block("Palate", { 1.8, 0.05, 1.7 }, { 0, -0.62, -0.05 }, Black),
		block("UpperGum", { 1.8, 0.12, 0.3 }, { 0, -0.66, -0.78 }, DeepRed),
		block("UpperFang1", { 0.16, 0.2, 0.16 }, { -0.6, -0.8, -0.8 }, White),
		block("UpperFangTip1", { 0.08, 0.16, 0.08 }, { -0.6, -0.97, -0.8 }, White),
		block("UpperFang2", { 0.16, 0.2, 0.16 }, { -0.3, -0.8, -0.8 }, White),
		block("UpperFangTip2", { 0.08, 0.16, 0.08 }, { -0.3, -0.97, -0.8 }, White),
		block("UpperFang3", { 0.16, 0.2, 0.16 }, { 0, -0.8, -0.8 }, White),
		block("UpperFangTip3", { 0.08, 0.16, 0.08 }, { 0, -0.97, -0.8 }, White),
		block("UpperFang4", { 0.16, 0.2, 0.16 }, { 0.3, -0.8, -0.8 }, White),
		block("UpperFangTip4", { 0.08, 0.16, 0.08 }, { 0.3, -0.97, -0.8 }, White),
		block("UpperFang5", { 0.16, 0.2, 0.16 }, { 0.6, -0.8, -0.8 }, White),
		block("UpperFangTip5", { 0.08, 0.16, 0.08 }, { 0.6, -0.97, -0.8 }, White),
		tilt(
			limb("Jaw", { 1.8, 0.3, 1.75 }, { 0, -1.238, 0.192 }, Flesh, "X", 14, 0.8, 0, { 0, 0.15, 0.87 }),
			-32,
			0,
			0
		),
		tilt(
			limb(
				"Tongue",
				{ 1.1, 0.1, 1.1 },
				{ 0, -1.067, 0.108 },
				DeepRed,
				"X",
				14,
				0.8,
				0,
				{ 0, -0.04, 0.85 }
			),
			-32,
			0,
			0
		),
		tilt(
			limb(
				"JawFang1",
				{ 0.16, 0.2, 0.16 },
				{ -0.66, -1.413, -0.56 },
				White,
				"X",
				14,
				0.8,
				0,
				{ 0.66, -0.1, 1.6 }
			),
			-32,
			0,
			0
		),
		tilt(
			limb(
				"JawFangTip1",
				{ 0.08, 0.16, 0.08 },
				{ -0.66, -1.26, -0.655 },
				White,
				"X",
				14,
				0.8,
				0,
				{ 0.66, -0.28, 1.6 }
			),
			-32,
			0,
			0
		),
		tilt(
			limb(
				"JawFang2",
				{ 0.16, 0.2, 0.16 },
				{ -0.33, -1.413, -0.56 },
				White,
				"X",
				14,
				0.8,
				0,
				{ 0.33, -0.1, 1.6 }
			),
			-32,
			0,
			0
		),
		tilt(
			limb(
				"JawFangTip2",
				{ 0.08, 0.16, 0.08 },
				{ -0.33, -1.26, -0.655 },
				White,
				"X",
				14,
				0.8,
				0,
				{ 0.33, -0.28, 1.6 }
			),
			-32,
			0,
			0
		),
		tilt(
			limb(
				"JawFang3",
				{ 0.16, 0.2, 0.16 },
				{ 0, -1.413, -0.56 },
				White,
				"X",
				14,
				0.8,
				0,
				{ 0, -0.1, 1.6 }
			),
			-32,
			0,
			0
		),
		tilt(
			limb(
				"JawFangTip3",
				{ 0.08, 0.16, 0.08 },
				{ 0, -1.26, -0.655 },
				White,
				"X",
				14,
				0.8,
				0,
				{ 0, -0.28, 1.6 }
			),
			-32,
			0,
			0
		),
		tilt(
			limb(
				"JawFang4",
				{ 0.16, 0.2, 0.16 },
				{ 0.33, -1.413, -0.56 },
				White,
				"X",
				14,
				0.8,
				0,
				{ -0.33, -0.1, 1.6 }
			),
			-32,
			0,
			0
		),
		tilt(
			limb(
				"JawFangTip4",
				{ 0.08, 0.16, 0.08 },
				{ 0.33, -1.26, -0.655 },
				White,
				"X",
				14,
				0.8,
				0,
				{ -0.33, -0.28, 1.6 }
			),
			-32,
			0,
			0
		),
		tilt(
			limb(
				"JawFang5",
				{ 0.16, 0.2, 0.16 },
				{ 0.66, -1.413, -0.56 },
				White,
				"X",
				14,
				0.8,
				0,
				{ -0.66, -0.1, 1.6 }
			),
			-32,
			0,
			0
		),
		tilt(
			limb(
				"JawFangTip5",
				{ 0.08, 0.16, 0.08 },
				{ 0.66, -1.26, -0.655 },
				White,
				"X",
				14,
				0.8,
				0,
				{ -0.66, -0.28, 1.6 }
			),
			-32,
			0,
			0
		),
		spin(
			limb("Orbiter1", { 0.55, 0.55, 0.55 }, { 2.6, 0.9, 0 }, Eyeball, "Y", 0, 0.15, 0, { -2.6, 0, 0 })
		),
		spin(
			limb(
				"Orbiter1Iris",
				{ 0.05, 0.3, 0.3 },
				{ 2.89, 0.9, 0 },
				Eldritch,
				"Y",
				0,
				0.15,
				0,
				{ -2.89, 0, 0 },
				true
			)
		),
		spin(
			limb(
				"Orbiter1Pupil",
				{ 0.05, 0.18, 0.08 },
				{ 2.91, 0.9, 0 },
				Black,
				"Y",
				0,
				0.15,
				0,
				{ -2.91, 0, 0 }
			)
		),
		spin(
			limb(
				"Orbiter1Vein",
				{ 0.04, 0.04, 0.25 },
				{ 2.885, 1.1, 0 },
				Vein,
				"Y",
				0,
				0.15,
				0,
				{ -2.885, 0, 0 }
			)
		),
		spin(
			limb(
				"Orbiter1Nerve",
				{ 0.5, 0.12, 0.12 },
				{ 2.1, 0.9, 0 },
				FleshDark,
				"Y",
				0,
				0.15,
				0,
				{ -2.1, 0, 0 }
			)
		),
		spin(
			limb("Orbiter2", { 0.55, 0.55, 0.55 }, { 0, 0.1, 2.6 }, Eyeball, "Y", 0, 0.15, 0, { 0, 0, -2.6 })
		),
		spin(
			limb(
				"Orbiter2Iris",
				{ 0.3, 0.3, 0.05 },
				{ 0, 0.1, 2.89 },
				Eldritch,
				"Y",
				0,
				0.15,
				0,
				{ 0, 0, -2.89 },
				true
			)
		),
		spin(
			limb(
				"Orbiter2Pupil",
				{ 0.08, 0.18, 0.05 },
				{ 0, 0.1, 2.91 },
				Black,
				"Y",
				0,
				0.15,
				0,
				{ 0, 0, -2.91 }
			)
		),
		spin(
			limb(
				"Orbiter2Vein",
				{ 0.25, 0.04, 0.04 },
				{ 0, 0.3, 2.885 },
				Vein,
				"Y",
				0,
				0.15,
				0,
				{ 0, 0, -2.885 }
			)
		),
		spin(
			limb(
				"Orbiter2Nerve",
				{ 0.12, 0.12, 0.5 },
				{ 0, 0.1, 2.1 },
				FleshDark,
				"Y",
				0,
				0.15,
				0,
				{ 0, 0, -2.1 }
			)
		),
		spin(
			limb("Orbiter3", { 0.55, 0.55, 0.55 }, { -2.6, 0.6, 0 }, Eyeball, "Y", 0, 0.15, 0, { 2.6, 0, 0 })
		),
		spin(
			limb(
				"Orbiter3Iris",
				{ 0.05, 0.3, 0.3 },
				{ -2.89, 0.6, 0 },
				Eldritch,
				"Y",
				0,
				0.15,
				0,
				{ 2.89, 0, 0 },
				true
			)
		),
		spin(
			limb(
				"Orbiter3Pupil",
				{ 0.05, 0.18, 0.08 },
				{ -2.91, 0.6, 0 },
				Black,
				"Y",
				0,
				0.15,
				0,
				{ 2.91, 0, 0 }
			)
		),
		spin(
			limb(
				"Orbiter3Vein",
				{ 0.04, 0.04, 0.25 },
				{ -2.885, 0.8, 0 },
				Vein,
				"Y",
				0,
				0.15,
				0,
				{ 2.885, 0, 0 }
			)
		),
		spin(
			limb(
				"Orbiter3Nerve",
				{ 0.5, 0.12, 0.12 },
				{ -2.1, 0.6, 0 },
				FleshDark,
				"Y",
				0,
				0.15,
				0,
				{ 2.1, 0, 0 }
			)
		),
		spin(
			limb("Orbiter4", { 0.55, 0.55, 0.55 }, { 0, 0.2, -2.6 }, Eyeball, "Y", 0, 0.15, 0, { 0, 0, 2.6 })
		),
		spin(
			limb(
				"Orbiter4Iris",
				{ 0.3, 0.3, 0.05 },
				{ 0, 0.2, -2.89 },
				Eldritch,
				"Y",
				0,
				0.15,
				0,
				{ 0, 0, 2.89 },
				true
			)
		),
		spin(
			limb(
				"Orbiter4Pupil",
				{ 0.08, 0.18, 0.05 },
				{ 0, 0.2, -2.91 },
				Black,
				"Y",
				0,
				0.15,
				0,
				{ 0, 0, 2.91 }
			)
		),
		spin(
			limb(
				"Orbiter4Vein",
				{ 0.25, 0.04, 0.04 },
				{ 0, 0.4, -2.885 },
				Vein,
				"Y",
				0,
				0.15,
				0,
				{ 0, 0, 2.885 }
			)
		),
		spin(
			limb(
				"Orbiter4Nerve",
				{ 0.12, 0.12, 0.5 },
				{ 0, 0.2, -2.1 },
				FleshDark,
				"Y",
				0,
				0.15,
				0,
				{ 0, 0, 2.1 }
			)
		),
		limb("Tentacle1", { 0.3, 1.6, 0.3 }, { -0.85, -1.4, 0.2 }, Flesh, "Z", 22, 1, 0, { 0, 0.8, 0 }),
		limb(
			"Tentacle1Hook",
			{ 0.24, 0.2, 0.24 },
			{ -0.85, -2.3, 0.2 },
			Eldritch,
			"Z",
			22,
			1,
			0,
			{ 0, 1.7, 0 },
			true
		),
		limb("Tentacle2", { 0.3, 1.6, 0.3 }, { 0.85, -1.4, 0.2 }, Flesh, "Z", 22, 1, 0.5, { 0, 0.8, 0 }),
		limb(
			"Tentacle2Hook",
			{ 0.24, 0.2, 0.24 },
			{ 0.85, -2.3, 0.2 },
			Eldritch,
			"Z",
			22,
			1,
			0.5,
			{ 0, 1.7, 0 },
			true
		),
		limb("Tentacle3", { 0.25, 1.2, 0.25 }, { -0.6, -1.2, 0.75 }, Flesh, "X", 22, 1, 0.2, { 0, 0.6, 0 }),
		limb(
			"Tentacle3Hook",
			{ 0.2, 0.2, 0.2 },
			{ -0.6, -1.9, 0.75 },
			Eldritch,
			"X",
			22,
			1,
			0.2,
			{ 0, 1.3, 0 },
			true
		),
		limb("Tentacle4", { 0.25, 1.2, 0.25 }, { 0.6, -1.2, 0.75 }, Flesh, "X", 22, 1, 0.7, { 0, 0.6, 0 }),
		limb(
			"Tentacle4Hook",
			{ 0.2, 0.2, 0.2 },
			{ 0.6, -1.9, 0.75 },
			Eldritch,
			"X",
			22,
			1,
			0.7,
			{ 0, 1.3, 0 },
			true
		),
		limb("Tentacle5", { 0.35, 2, 0.35 }, { 0, -1.6, 0.8 }, Flesh, "X", 22, 1, 0.4, { 0, 1, 0 }),
		limb(
			"Tentacle5Hook",
			{ 0.28, 0.2, 0.28 },
			{ 0, -2.7, 0.8 },
			Eldritch,
			"X",
			22,
			1,
			0.4,
			{ 0, 2.1, 0 },
			true
		),
		limb("Tentacle6", { 0.2, 0.9, 0.2 }, { -0.85, -1.05, -0.45 }, Flesh, "Z", 22, 1, 0.3, { 0, 0.45, 0 }),
		limb(
			"Tentacle6Hook",
			{ 0.16, 0.2, 0.16 },
			{ -0.85, -1.6, -0.45 },
			Eldritch,
			"Z",
			22,
			1,
			0.3,
			{ 0, 1, 0 },
			true
		),
		limb("Tentacle7", { 0.2, 0.9, 0.2 }, { 0.85, -1.05, -0.45 }, Flesh, "Z", 22, 1, 0.8, { 0, 0.45, 0 }),
		limb(
			"Tentacle7Hook",
			{ 0.16, 0.2, 0.16 },
			{ 0.85, -1.6, -0.45 },
			Eldritch,
			"Z",
			22,
			1,
			0.8,
			{ 0, 1, 0 },
			true
		),
		limb("Tentacle8", { 0.18, 0.7, 0.18 }, { -0.3, -0.95, 0.4 }, Flesh, "X", 22, 1, 0.6, { 0, 0.35, 0 }),
		limb(
			"Tentacle8Hook",
			{ 0.144, 0.2, 0.144 },
			{ -0.3, -1.4, 0.4 },
			Eldritch,
			"X",
			22,
			1,
			0.6,
			{ 0, 0.8, 0 },
			true
		),
		limb("Tentacle9", { 0.18, 0.7, 0.18 }, { 0.3, -0.95, 0.4 }, Flesh, "X", 22, 1, 0.1, { 0, 0.35, 0 }),
		limb(
			"Tentacle9Hook",
			{ 0.144, 0.2, 0.144 },
			{ 0.3, -1.4, 0.4 },
			Eldritch,
			"X",
			22,
			1,
			0.1,
			{ 0, 0.8, 0 },
			true
		),
	},
}

return Looks
