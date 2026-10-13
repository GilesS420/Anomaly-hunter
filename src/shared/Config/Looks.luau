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

export type Joint = {
	axis: "X" | "Y" | "Z",
	amp: number,
	speed: number,
	phase: number?,
	pivot: { number }?,
	spin: boolean?, -- turns round and round (speed = turns per second) instead of swinging
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

-- Zone 2, Common: a round blob of bayou mud with big eyes, waddling on flat feet.
local Mud = { 95, 85, 50 }
local MudDark = { 70, 60, 35 }
Looks.Bogbub = {
	gait = "walk",
	top = 0.3,
	pieces = {
		block("Blob", { 2, 1.4, 1.8 }, { 0, -1, 0 }, Mud),
		block("Top", { 1.4, 0.4, 1.3 }, { 0, -0.1, 0 }, Mud),
		block("LeftEye", { 0.5, 0.5, 0.5 }, { -0.45, 0, -0.5 }, White),
		block("RightEye", { 0.5, 0.5, 0.5 }, { 0.45, 0, -0.5 }, White),
		block("LeftPupil", { 0.2, 0.2, 0.1 }, { -0.45, 0, -0.78 }, Black),
		block("RightPupil", { 0.2, 0.2, 0.1 }, { 0.45, 0, -0.78 }, Black),
		block("Mouth", { 1, 0.15, 0.1 }, { 0, -0.9, -0.93 }, MudDark),
		limb(
			"Bubble",
			{ 0.4, 0.4, 0.4 },
			{ 0.6, -0.15, 0.4 },
			{ 150, 140, 90 },
			"Y",
			40,
			1,
			0,
			{ -0.3, 0, 0 }
		),
		limb("LeftFoot", { 0.5, 0.3, 0.6 }, { -0.6, -1.85, -0.2 }, MudDark, "X", 25, 2.5, 0, { 0, 0.15, 0 }),
		limb(
			"RightFoot",
			{ 0.5, 0.3, 0.6 },
			{ 0.6, -1.85, -0.2 },
			MudDark,
			"X",
			25,
			2.5,
			0.5,
			{ 0, 0.15, 0 }
		),
	},
}

-- Zone 2, Common: a stitched-up zombie frog that hops along.
local Frog = { 90, 150, 70 }
local Belly = { 170, 190, 110 }
Looks.Croakling = {
	gait = "walk",
	top = 0.3,
	pieces = {
		block("Body", { 1.6, 1, 1.8 }, { 0, -1.2, 0.1 }, Frog),
		block("Belly", { 1.2, 0.6, 0.1 }, { 0, -1.3, -0.82 }, Belly),
		block("Head", { 1.4, 0.8, 1 }, { 0, -0.5, -0.6 }, Frog),
		block("Mouth", { 1.2, 0.1, 0.1 }, { 0, -0.75, -1.12 }, Black),
		block("Stitches", { 0.5, 0.1, 0.5 }, { 0.3, -0.65, 0.4 }, { 140, 60, 140 }),
		block("LeftEye", { 0.45, 0.45, 0.45 }, { -0.45, 0, -0.7 }, { 255, 230, 70 }, true),
		block("RightEye", { 0.45, 0.45, 0.45 }, { 0.45, 0, -0.7 }, { 255, 230, 70 }, true),
		block("LeftPupil", { 0.1, 0.3, 0.1 }, { -0.45, 0, -0.95 }, Black),
		block("RightPupil", { 0.1, 0.3, 0.1 }, { 0.45, 0, -0.95 }, Black),
		limb("FrontLeftLeg", { 0.3, 0.6, 0.3 }, { -0.55, -1.7, -0.6 }, Frog, "X", 25, 2, 0, { 0, 0.3, 0 }),
		limb("FrontRightLeg", { 0.3, 0.6, 0.3 }, { 0.55, -1.7, -0.6 }, Frog, "X", 25, 2, 0, { 0, 0.3, 0 }),
		limb("BackLeftLeg", { 0.5, 0.3, 1 }, { -0.75, -1.85, 0.6 }, Frog, "X", 30, 2, 0.5, { 0, 0, -0.5 }),
		limb("BackRightLeg", { 0.5, 0.3, 1 }, { 0.75, -1.85, 0.6 }, Frog, "X", 30, 2, 0.5, { 0, 0, -0.5 }),
	},
}

-- Zone 2, Uncommon: a little glowing spirit hiding under willow leaves, its strands swaying.
local Willow = { 110, 160, 80 }
local Glow = { 200, 255, 180 }
Looks.WillowWisp = {
	gait = "float",
	top = 1.3,
	pieces = {
		block("Core", { 1, 1, 1 }, { 0, 0.3, 0 }, Glow, true),
		block("LeftEye", { 0.18, 0.18, 0.1 }, { -0.2, 0.4, -0.53 }, Black),
		block("RightEye", { 0.18, 0.18, 0.1 }, { 0.2, 0.4, -0.53 }, Black),
		block("Cap", { 1.6, 0.4, 1.6 }, { 0, 1, 0 }, Willow),
		limb(
			"FrontLeftStrand",
			{ 0.25, 1.4, 0.25 },
			{ -0.6, 0.1, -0.6 },
			Willow,
			"X",
			15,
			1,
			0,
			{ 0, 0.7, 0 }
		),
		limb(
			"FrontRightStrand",
			{ 0.25, 1.4, 0.25 },
			{ 0.6, 0.1, -0.6 },
			Willow,
			"X",
			15,
			1,
			0.25,
			{ 0, 0.7, 0 }
		),
		limb(
			"BackLeftStrand",
			{ 0.25, 1.4, 0.25 },
			{ -0.6, 0.1, 0.6 },
			Willow,
			"Z",
			15,
			1,
			0.5,
			{ 0, 0.7, 0 }
		),
		limb(
			"BackRightStrand",
			{ 0.25, 1.4, 0.25 },
			{ 0.6, 0.1, 0.6 },
			Willow,
			"Z",
			15,
			1,
			0.75,
			{ 0, 0.7, 0 }
		),
	},
}

-- Zone 2, Uncommon: a swamp witch in a pointy hat, swinging a reed broom.
local Robe = { 45, 75, 55 }
local WitchSkin = { 150, 175, 120 }
local Reed = { 200, 180, 90 }
Looks.Reedwitch = {
	gait = "walk",
	top = 2.2,
	pieces = {
		block("Robe", { 1.4, 1.6, 1 }, { 0, -0.6, 0 }, Robe),
		block("Head", { 0.9, 0.9, 0.9 }, { 0, 0.65, 0 }, WitchSkin),
		block("Nose", { 0.2, 0.2, 0.5 }, { 0, 0.55, -0.65 }, WitchSkin),
		block("LeftEye", { 0.15, 0.15, 0.1 }, { -0.2, 0.8, -0.47 }, Candle, true),
		block("RightEye", { 0.15, 0.15, 0.1 }, { 0.2, 0.8, -0.47 }, Candle, true),
		block("HatBrim", { 1.5, 0.15, 1.5 }, { 0, 1.15, 0 }, Black),
		block("HatMiddle", { 0.8, 0.6, 0.8 }, { 0, 1.5, 0 }, Black),
		block("HatTip", { 0.4, 0.5, 0.4 }, { 0.1, 1.95, 0.1 }, Black),
		block("HatBand", { 0.85, 0.15, 0.85 }, { 0, 1.3, 0 }, Purple),
		limb("LeftArm", { 0.3, 1.1, 0.3 }, { -0.85, -0.4, 0 }, Robe, "X", 25, 1.5, 0.5, { 0, 0.5, 0 }),
		limb("RightArm", { 0.3, 1.1, 0.3 }, { 0.85, -0.4, 0 }, Robe, "X", 25, 1.5, 0, { 0, 0.5, 0 }),
		limb("Broom", { 0.15, 2, 0.15 }, { 0.85, -0.6, -0.35 }, Wood, "X", 25, 1.5, 0, { 0, 0.7, 0.35 }),
		limb("Bristles", { 0.5, 0.5, 0.5 }, { 0.85, -1.7, -0.35 }, Reed, "X", 25, 1.5, 0, { 0, 1.8, 0.35 }),
		limb("LeftLeg", { 0.35, 0.6, 0.35 }, { -0.3, -1.7, 0 }, Black, "X", 25, 1.5, 0, { 0, 0.3, 0 }),
		limb("RightLeg", { 0.35, 0.6, 0.35 }, { 0.3, -1.7, 0 }, Black, "X", 25, 1.5, 0.5, { 0, 0.3, 0 }),
	},
}

-- Zone 2, Rare: a ghostly alligator, low to the ground, swishing its tail.
local Gator = { 120, 170, 140 }
local GatorDark = { 80, 120, 100 }
Looks.Gatorghast = {
	gait = "walk",
	top = -0.3,
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

-- Zone 2, Epic: a drowned church bell, its glowing clapper swinging and seaweed dangling off it.
local Bronze = { 160, 110, 60 }
local Verdigris = { 90, 160, 140 }
local Seaweed = { 50, 110, 60 }
Looks.SunkenBell = {
	gait = "float",
	top = 1.85,
	pieces = {
		block("Bell", { 1.8, 1.6, 1.8 }, { 0, 0.2, 0 }, Bronze),
		block("Rim", { 2.3, 0.4, 2.3 }, { 0, -0.75, 0 }, Bronze),
		block("Crown", { 1, 0.4, 1 }, { 0, 1.2, 0 }, Verdigris),
		block("Loop", { 0.3, 0.5, 0.3 }, { 0, 1.6, 0 }, Verdigris),
		block("Barnacles", { 0.5, 0.3, 0.1 }, { 0.5, -0.2, -0.92 }, { 220, 215, 200 }),
		block("LeftEye", { 0.3, 0.3, 0.1 }, { -0.4, 0.4, -0.92 }, { 90, 255, 220 }, true),
		block("RightEye", { 0.3, 0.3, 0.1 }, { 0.4, 0.4, -0.92 }, { 90, 255, 220 }, true),
		limb(
			"Clapper",
			{ 0.6, 0.6, 0.6 },
			{ 0, -1.3, 0 },
			{ 90, 255, 220 },
			"X",
			25,
			2,
			0,
			{ 0, 1.2, 0 },
			true
		),
		limb("LeftWeed", { 0.2, 1, 0.2 }, { -0.9, -1.2, 0.5 }, Seaweed, "Z", 20, 1.2, 0, { 0, 0.5, 0 }),
		limb("RightWeed", { 0.2, 1.2, 0.2 }, { 0.9, -1.3, 0.3 }, Seaweed, "X", 20, 1.2, 0.4, { 0, 0.6, 0 }),
	},
}

-- Zone 2, Legendary: the mud king of the bayou, with a golden crown and a mossy cape.
Looks.TheBogKing = {
	gait = "walk",
	top = 2.6,
	pieces = {
		block("Body", { 2.2, 1.8, 1.4 }, { 0, -0.2, 0 }, Mud),
		block("Belly", { 1.6, 1.2, 0.1 }, { 0, -0.3, -0.75 }, { 130, 120, 75 }),
		block("Head", { 1.4, 1.1, 1.2 }, { 0, 1.25, -0.1 }, Mud),
		block("Mouth", { 0.9, 0.15, 0.1 }, { 0, 0.95, -0.72 }, MudDark),
		block("LeftEye", { 0.25, 0.25, 0.1 }, { -0.35, 1.4, -0.72 }, { 255, 150, 40 }, true),
		block("RightEye", { 0.25, 0.25, 0.1 }, { 0.35, 1.4, -0.72 }, { 255, 150, 40 }, true),
		block("Crown", { 1.5, 0.4, 1.3 }, { 0, 2, -0.1 }, Gold),
		block("LeftPoint", { 0.25, 0.35, 0.25 }, { -0.5, 2.38, -0.6 }, Gold),
		block("MiddleGem", { 0.3, 0.35, 0.25 }, { 0, 2.38, -0.6 }, { 80, 255, 120 }, true),
		block("RightPoint", { 0.25, 0.35, 0.25 }, { 0.5, 2.38, -0.6 }, Gold),
		limb("Cape", { 2, 1.8, 0.15 }, { 0, -0.1, 0.78 }, Moss, "X", 12, 1.2, 0, { 0, 0.9, 0 }),
		limb("LeftArm", { 0.6, 1.6, 0.6 }, { -1.4, -0.3, 0 }, Mud, "X", 25, 1.2, 0.5, { 0, 0.7, 0 }),
		limb("RightArm", { 0.6, 1.6, 0.6 }, { 1.4, -0.3, 0 }, Mud, "X", 25, 1.2, 0, { 0, 0.7, 0 }),
		limb("LeftLeg", { 0.6, 0.9, 0.6 }, { -0.5, -1.55, 0 }, MudDark, "X", 22, 1.2, 0, { 0, 0.45, 0 }),
		limb("RightLeg", { 0.6, 0.9, 0.6 }, { 0.5, -1.55, 0 }, MudDark, "X", 22, 1.2, 0.5, { 0, 0.45, 0 }),
	},
}

-- Zone 2, Mythic: a giant swamp snake rising out of the water. Every body segment sways a bit
-- later than the one before it, so it slithers.
local Scale = { 40, 90, 85 }
local Stripe = { 160, 90, 255 }
Looks.MireSerpent = {
	gait = "float",
	top = 1.8,
	pieces = {
		block("Head", { 1, 0.9, 1.4 }, { 0, 1.2, -0.8 }, Scale),
		block("LeftEye", { 0.2, 0.2, 0.1 }, { -0.3, 1.45, -1.52 }, { 255, 230, 60 }, true),
		block("RightEye", { 0.2, 0.2, 0.1 }, { 0.3, 1.45, -1.52 }, { 255, 230, 60 }, true),
		block("LeftFang", { 0.12, 0.3, 0.12 }, { -0.25, 0.65, -1.35 }, White),
		block("RightFang", { 0.12, 0.3, 0.12 }, { 0.25, 0.65, -1.35 }, White),
		block("LeftFin", { 0.1, 0.6, 0.6 }, { -0.55, 1.5, -0.5 }, Stripe, true),
		block("RightFin", { 0.1, 0.6, 0.6 }, { 0.55, 1.5, -0.5 }, Stripe, true),
		limb("Neck", { 0.8, 0.8, 0.8 }, { 0, 0.4, -0.3 }, Scale, "Y", 20, 1, 0.15, { 0, 0, 0 }),
		limb("Body1", { 0.9, 0.8, 0.9 }, { 0, -0.4, 0.3 }, Stripe, "Y", 20, 1, 0.3, { 0, 0, 0 }, true),
		limb("Body2", { 0.9, 0.8, 0.9 }, { 0, -1, 1.1 }, Scale, "Y", 20, 1, 0.45, { 0, 0, 0 }),
		limb("Body3", { 0.7, 0.7, 0.9 }, { 0, -1.2, 1.9 }, Stripe, "Y", 20, 1, 0.6, { 0, 0, 0 }, true),
		limb("TailTip", { 0.5, 0.5, 0.8 }, { 0, -1.3, 2.7 }, Scale, "Y", 30, 1, 0.75, { 0, 0, -0.4 }),
	},
}

-- Zone 2, Divine: a silver heron that glows in the moonlight, stepping slowly on long legs.
local Silver = { 225, 230, 245 }
local Moonglow = { 170, 210, 255 }
Looks.MoonlitHeron = {
	gait = "walk",
	top = 2.2,
	pieces = {
		block("Body", { 1, 1, 1.8 }, { 0, 0.1, 0.1 }, Silver),
		block("Neck", { 0.3, 1.2, 0.3 }, { 0, 1, -0.6 }, Silver),
		block("Head", { 0.5, 0.45, 0.6 }, { 0, 1.75, -0.75 }, Silver),
		block("Beak", { 0.15, 0.15, 0.9 }, { 0, 1.7, -1.45 }, Gold),
		block("Crest", { 0.1, 0.4, 0.4 }, { 0, 2.05, -0.55 }, Moonglow, true),
		block("LeftEye", { 0.1, 0.1, 0.1 }, { -0.26, 1.8, -0.9 }, Moonglow, true),
		block("RightEye", { 0.1, 0.1, 0.1 }, { 0.26, 1.8, -0.9 }, Moonglow, true),
		block("TailFeathers", { 0.6, 0.15, 0.6 }, { 0, 0.2, 1.25 }, Moonglow, true),
		limb("LeftWing", { 0.15, 0.8, 1.6 }, { -0.58, 0.15, 0.2 }, Silver, "Z", -25, 1, 0, { 0.07, 0.4, 0 }),
		limb("RightWing", { 0.15, 0.8, 1.6 }, { 0.58, 0.15, 0.2 }, Silver, "Z", 25, 1, 0, { -0.07, 0.4, 0 }),
		limb("LeftLeg", { 0.15, 1.6, 0.15 }, { -0.25, -1.2, 0 }, Gold, "X", 25, 1, 0, { 0, 0.8, 0 }),
		limb("RightLeg", { 0.15, 1.6, 0.15 }, { 0.25, -1.2, 0 }, Gold, "X", 25, 1, 0.5, { 0, 0.8, 0 }),
	},
}

-- Zone 3: Abandoned Carnival. Faded circus stripes, chipped paint and sinister grins.
local CircusRed = { 185, 40, 50 }
local CircusCream = { 238, 222, 185 }
local CircusTeal = { 40, 145, 145 }
local Popcorn = { 250, 235, 160 }
local Faded = { 110, 40, 60 }

-- Zone 3, Common: a striped popcorn bucket with a toothy grin, waddling on little legs.
Looks.Poplet = {
	gait = "walk",
	top = 0.7,
	pieces = {
		block("Bucket", { 1.4, 1.6, 1.4 }, { 0, -0.9, 0 }, CircusCream),
		block("LeftStripe", { 0.25, 1.62, 1.42 }, { -0.45, -0.9, 0 }, CircusRed),
		block("MiddleStripe", { 0.25, 1.62, 1.42 }, { 0, -0.9, 0 }, CircusRed),
		block("RightStripe", { 0.25, 1.62, 1.42 }, { 0.45, -0.9, 0 }, CircusRed),
		block("Rim", { 1.5, 0.15, 1.5 }, { 0, -0.15, 0 }, CircusRed),
		block("Kernel1", { 0.5, 0.45, 0.5 }, { -0.35, 0.1, -0.3 }, Popcorn),
		block("Kernel2", { 0.55, 0.5, 0.5 }, { 0.35, 0.15, 0.2 }, Popcorn),
		block("Kernel3", { 0.5, 0.5, 0.5 }, { 0, 0.4, 0 }, Popcorn),
		block("Kernel4", { 0.45, 0.45, 0.45 }, { -0.3, 0.2, 0.35 }, Popcorn),
		block("Kernel5", { 0.4, 0.4, 0.4 }, { 0.4, 0.05, -0.38 }, Popcorn),
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

-- Zone 3, Common: a red carnival balloon with a painted-on grin, its string swaying below.
Looks.BalloonBoo = {
	gait = "float",
	top = 1.4,
	pieces = {
		block("Balloon", { 1.4, 1.6, 1.4 }, { 0, 0.5, 0 }, CircusRed),
		block("BalloonTop", { 1, 0.25, 1 }, { 0, 1.4, 0 }, CircusRed),
		block("Shine", { 0.25, 0.4, 0.05 }, { -0.4, 0.95, -0.72 }, White, true),
		block("LeftEye", { 0.25, 0.32, 0.05 }, { -0.3, 0.7, -0.72 }, Black),
		block("RightEye", { 0.25, 0.32, 0.05 }, { 0.3, 0.7, -0.72 }, Black),
		block("Smile", { 0.8, 0.12, 0.05 }, { 0, 0.2, -0.72 }, Black),
		block("SmileLeft", { 0.12, 0.25, 0.05 }, { -0.4, 0.3, -0.72 }, Black),
		block("SmileRight", { 0.12, 0.25, 0.05 }, { 0.4, 0.3, -0.72 }, Black),
		block("Knot", { 0.3, 0.25, 0.3 }, { 0, -0.42, 0 }, Faded),
		limb("String1", { 0.08, 0.6, 0.08 }, { 0, -0.85, 0 }, White, "X", 15, 1, 0, { 0, 0.3, 0 }),
		limb("String2", { 0.08, 0.6, 0.08 }, { 0, -1.45, 0 }, White, "X", 20, 1, 0.2, { 0, 0.9, 0 }),
	},
}

-- Zone 3, Uncommon: a green gremlin in a bellhop cap, clutching a roll of tickets.
local Gremlin = { 100, 140, 70 }
local GremlinDark = { 70, 100, 50 }
Looks.TicketGremlin = {
	gait = "walk",
	top = 0.75,
	pieces = {
		block("Body", { 1, 1, 0.8 }, { 0, -1, 0 }, Gremlin),
		block("Vest", { 1.05, 0.55, 0.85 }, { 0, -0.85, 0 }, CircusRed),
		block("VestButtons", { 0.1, 0.4, 0.05 }, { 0, -0.85, -0.45 }, Gold),
		block("Head", { 1.1, 0.9, 0.9 }, { 0, -0.05, -0.05 }, Gremlin),
		block("Cap", { 0.6, 0.3, 0.6 }, { 0, 0.55, 0 }, CircusRed),
		block("CapBand", { 0.62, 0.08, 0.62 }, { 0, 0.45, 0 }, Gold),
		block("LeftEye", { 0.25, 0.22, 0.05 }, { -0.25, 0.08, -0.52 }, { 255, 230, 60 }, true),
		block("RightEye", { 0.25, 0.22, 0.05 }, { 0.25, 0.08, -0.52 }, { 255, 230, 60 }, true),
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
		limb("LeftArm", { 0.25, 0.7, 0.25 }, { -0.62, -1, 0 }, Gremlin, "X", 30, 2, 0.5, { 0, 0.35, 0 }),
		limb("RightArm", { 0.25, 0.7, 0.25 }, { 0.62, -1, 0 }, Gremlin, "X", 30, 2, 0, { 0, 0.35, 0 }),
		limb(
			"TicketRoll",
			{ 0.35, 0.35, 0.35 },
			{ 0.62, -1.45, -0.1 },
			{ 230, 120, 60 },
			"X",
			30,
			2,
			0,
			{ 0, 0.8, 0.1 }
		),
		limb(
			"Tickets",
			{ 0.25, 0.05, 0.6 },
			{ 0.62, -1.55, -0.45 },
			{ 245, 200, 120 },
			"X",
			30,
			2,
			0,
			{ 0, 0.9, 0.45 }
		),
		limb("LeftLeg", { 0.3, 0.5, 0.3 }, { -0.3, -1.75, 0 }, GremlinDark, "X", 30, 2, 0, { 0, 0.25, 0 }),
		limb("RightLeg", { 0.3, 0.5, 0.3 }, { 0.3, -1.75, 0 }, GremlinDark, "X", 30, 2, 0.5, { 0, 0.25, 0 }),
	},
}

-- Zone 3, Uncommon: a chipped carousel horse that broke loose, still skewered on its golden pole.
local CarouselWhite = { 235, 230, 220 }
Looks.CarouselColt = {
	gait = "walk",
	top = 2.2,
	pieces = {
		block("Body", { 1.2, 1, 2.2 }, { 0, -0.5, 0.1 }, CarouselWhite),
		block("Chip", { 0.05, 0.4, 0.5 }, { 0.62, -0.4, 0.5 }, { 120, 110, 100 }),
		tilt(block("Neck", { 0.55, 1.1, 0.6 }, { 0, 0.25, -1.05 }, CarouselWhite), -30, 0, 0),
		tilt(block("Mane", { 0.2, 1.1, 0.25 }, { 0, 0.45, -0.8 }, CircusTeal), -30, 0, 0),
		tilt(block("Head", { 0.5, 0.5, 0.9 }, { 0, 0.75, -1.55 }, CarouselWhite), -25, 0, 0),
		tilt(block("Muzzle", { 0.45, 0.35, 0.3 }, { 0, 0.55, -1.95 }, { 200, 190, 180 }), -25, 0, 0),
		block("LeftEar", { 0.12, 0.3, 0.12 }, { -0.15, 1.1, -1.35 }, CarouselWhite),
		block("RightEar", { 0.12, 0.3, 0.12 }, { 0.15, 1.1, -1.35 }, CarouselWhite),
		block("LeftEye", { 0.06, 0.12, 0.12 }, { -0.26, 0.85, -1.6 }, { 255, 50, 50 }, true),
		block("RightEye", { 0.06, 0.12, 0.12 }, { 0.26, 0.85, -1.6 }, { 255, 50, 50 }, true),
		block("Saddle", { 1.25, 0.15, 0.8 }, { 0, 0.05, 0.1 }, CircusRed),
		block("SaddleTrim", { 1.3, 0.08, 0.85 }, { 0, -0.05, 0.1 }, Gold),
		block("Pole", { 0.2, 2.6, 0.2 }, { 0, 0.85, 0.1 }, Gold),
		block("PoleStripe1", { 0.22, 0.15, 0.22 }, { 0, 0.6, 0.1 }, CircusRed),
		block("PoleStripe2", { 0.22, 0.15, 0.22 }, { 0, 1.2, 0.1 }, CircusRed),
		block("PoleStripe3", { 0.22, 0.15, 0.22 }, { 0, 1.8, 0.1 }, CircusRed),
		block("PoleCap", { 0.35, 0.2, 0.35 }, { 0, 2.2, 0.1 }, Gold),
		limb("Tail", { 0.25, 0.8, 0.25 }, { 0, -0.5, 1.3 }, CircusTeal, "X", 20, 2, 0, { 0, 0.4, 0 }),
		limb(
			"FrontLeftLeg",
			{ 0.3, 0.8, 0.3 },
			{ -0.35, -1.4, -0.75 },
			CarouselWhite,
			"X",
			30,
			2,
			0,
			{ 0, 0.4, 0 }
		),
		limb(
			"FrontLeftHoof",
			{ 0.34, 0.2, 0.34 },
			{ -0.35, -1.9, -0.75 },
			Gold,
			"X",
			30,
			2,
			0,
			{ 0, 0.9, 0 }
		),
		limb(
			"FrontRightLeg",
			{ 0.3, 0.8, 0.3 },
			{ 0.35, -1.4, -0.75 },
			CarouselWhite,
			"X",
			30,
			2,
			0.5,
			{ 0, 0.4, 0 }
		),
		limb(
			"FrontRightHoof",
			{ 0.34, 0.2, 0.34 },
			{ 0.35, -1.9, -0.75 },
			Gold,
			"X",
			30,
			2,
			0.5,
			{ 0, 0.9, 0 }
		),
		limb(
			"BackLeftLeg",
			{ 0.3, 0.8, 0.3 },
			{ -0.35, -1.4, 0.9 },
			CarouselWhite,
			"X",
			30,
			2,
			0.5,
			{ 0, 0.4, 0 }
		),
		limb("BackLeftHoof", { 0.34, 0.2, 0.34 }, { -0.35, -1.9, 0.9 }, Gold, "X", 30, 2, 0.5, { 0, 0.9, 0 }),
		limb(
			"BackRightLeg",
			{ 0.3, 0.8, 0.3 },
			{ 0.35, -1.4, 0.9 },
			CarouselWhite,
			"X",
			30,
			2,
			0,
			{ 0, 0.4, 0 }
		),
		limb("BackRightHoof", { 0.34, 0.2, 0.34 }, { 0.35, -1.9, 0.9 }, Gold, "X", 30, 2, 0, { 0, 0.9, 0 }),
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

-- Zone 3, Epic: a cracked funhouse mirror whose reflection grins back, with shards circling it.
local MirrorGlass = { 175, 195, 215 }
local Magenta = { 255, 70, 200 }
Looks.MirrorGrin = {
	gait = "float",
	top = 1.9,
	pieces = {
		block("Frame", { 1.8, 2.6, 0.3 }, { 0, 0.2, 0 }, Gold),
		block("Glass", { 1.4, 2.2, 0.1 }, { 0, 0.2, -0.16 }, MirrorGlass),
		block("Crest", { 0.8, 0.4, 0.3 }, { 0, 1.65, 0 }, Gold),
		block("LeftFinial", { 0.3, 0.3, 0.3 }, { -0.9, 1.55, 0 }, Gold),
		block("RightFinial", { 0.3, 0.3, 0.3 }, { 0.9, 1.55, 0 }, Gold),
		block("Gem", { 0.2, 0.2, 0.1 }, { 0, 1.65, -0.18 }, Magenta, true),
		block("LeftEye", { 0.28, 0.2, 0.05 }, { -0.35, 0.65, -0.23 }, Magenta, true),
		block("RightEye", { 0.28, 0.2, 0.05 }, { 0.35, 0.65, -0.23 }, Magenta, true),
		block("Grin", { 1.1, 0.25, 0.05 }, { 0, -0.1, -0.22 }, Black),
		block("Teeth", { 1, 0.08, 0.05 }, { 0, -0.02, -0.25 }, White),
		block("GrinLeft", { 0.12, 0.3, 0.05 }, { -0.55, 0.05, -0.22 }, Black),
		block("GrinRight", { 0.12, 0.3, 0.05 }, { 0.55, 0.05, -0.22 }, Black),
		tilt(block("CrackTop", { 0.05, 0.9, 0.05 }, { 0.35, 0.9, -0.22 }, { 60, 60, 70 }), 0, 0, 30),
		tilt(block("CrackBottom", { 0.05, 0.7, 0.05 }, { -0.4, -0.6, -0.22 }, { 60, 60, 70 }), 0, 0, -25),
		spin(
			limb("Shard1", { 0.3, 0.45, 0.05 }, { 1.4, 0.4, 0 }, MirrorGlass, "Y", 0, 0.3, 0, { -1.4, 0, 0 })
		),
		spin(
			limb(
				"Shard2",
				{ 0.25, 0.35, 0.05 },
				{ -1.4, -0.2, 0 },
				MirrorGlass,
				"Y",
				0,
				0.3,
				0,
				{ 1.4, 0, 0 }
			)
		),
		spin(
			limb("Shard3", { 0.2, 0.3, 0.05 }, { 0, 0.9, 1.3 }, MirrorGlass, "Y", 0, 0.3, 0, { 0, 0, -1.3 })
		),
	},
}

-- Zone 3, Legendary: the sinister ringmaster in a red tailcoat and top hat, cracking his whip.
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
		limb(
			"WhipHandle",
			{ 0.15, 0.5, 0.15 },
			{ 0.82, -1.35, -0.15 },
			Wood,
			"X",
			28,
			1.5,
			0,
			{ 0, 1.5, 0.15 }
		),
		limb(
			"WhipLash",
			{ 0.08, 0.08, 1.3 },
			{ 0.82, -1.55, -0.85 },
			Leather,
			"X",
			28,
			1.5,
			0,
			{ 0, 1.7, 0.85 }
		),
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
	},
}

-- Zone 3, Mythic: the big top come alive. Its entrance is a mouth full of teeth, two windows
-- glow like eyes, and the flaps beside its mouth open and shut as it scuttles along.
Looks.BigTopTerror = {
	gait = "walk",
	top = 1.5,
	pieces = {
		block("Walls", { 2.4, 1.4, 2.4 }, { 0, -1.1, 0 }, CircusCream),
		block("Stripe1", { 0.35, 1.42, 2.42 }, { -0.9, -1.1, 0 }, CircusRed),
		block("Stripe2", { 0.35, 1.42, 2.42 }, { 0.9, -1.1, 0 }, CircusRed),
		block("Stripe3", { 2.42, 1.42, 0.35 }, { 0, -1.1, 0.9 }, CircusRed),
		block("RoofLow", { 2.6, 0.4, 2.6 }, { 0, -0.2, 0 }, CircusRed),
		block("RoofMiddle", { 1.8, 0.4, 1.8 }, { 0, 0.2, 0 }, CircusCream),
		block("RoofTop", { 1, 0.4, 1 }, { 0, 0.6, 0 }, CircusRed),
		block("Spire", { 0.2, 0.6, 0.2 }, { 0, 1.1, 0 }, Gold),
		limb("Flag", { 0.5, 0.3, 0.05 }, { 0.35, 1.25, 0 }, CircusTeal, "Y", 30, 2, 0, { -0.25, 0, 0 }),
		block("LeftWindow", { 0.4, 0.35, 0.05 }, { -0.5, -0.55, -1.22 }, Candle, true),
		block("RightWindow", { 0.4, 0.35, 0.05 }, { 0.5, -0.55, -1.22 }, Candle, true),
		block("Mouth", { 1.1, 0.8, 0.05 }, { 0, -1.25, -1.22 }, Black),
		block("Tongue", { 0.7, 0.1, 0.5 }, { 0, -1.6, -1.05 }, Blood),
		block("TopTooth1", { 0.2, 0.22, 0.05 }, { -0.4, -0.97, -1.25 }, White),
		block("TopTooth2", { 0.2, 0.22, 0.05 }, { -0.13, -0.97, -1.25 }, White),
		block("TopTooth3", { 0.2, 0.22, 0.05 }, { 0.13, -0.97, -1.25 }, White),
		block("TopTooth4", { 0.2, 0.22, 0.05 }, { 0.4, -0.97, -1.25 }, White),
		block("BottomTooth1", { 0.2, 0.2, 0.05 }, { -0.27, -1.55, -1.25 }, White),
		block("BottomTooth2", { 0.2, 0.2, 0.05 }, { 0.27, -1.55, -1.25 }, White),
		limb(
			"LeftFlap",
			{ 0.45, 1, 0.08 },
			{ -0.8, -1.2, -1.26 },
			CircusCream,
			"Y",
			30,
			1.5,
			0,
			{ -0.22, 0, 0 }
		),
		limb(
			"RightFlap",
			{ 0.45, 1, 0.08 },
			{ 0.8, -1.2, -1.26 },
			CircusCream,
			"Y",
			-30,
			1.5,
			0,
			{ 0.22, 0, 0 }
		),
		limb("FrontLeftPeg", { 0.35, 0.2, 0.35 }, { -0.8, -1.9, -0.8 }, Wood, "X", 35, 2.5, 0, { 0, 0.1, 0 }),
		limb(
			"FrontRightPeg",
			{ 0.35, 0.2, 0.35 },
			{ 0.8, -1.9, -0.8 },
			Wood,
			"X",
			35,
			2.5,
			0.5,
			{ 0, 0.1, 0 }
		),
		limb("BackLeftPeg", { 0.35, 0.2, 0.35 }, { -0.8, -1.9, 0.8 }, Wood, "X", 35, 2.5, 0.5, { 0, 0.1, 0 }),
		limb("BackRightPeg", { 0.35, 0.2, 0.35 }, { 0.8, -1.9, 0.8 }, Wood, "X", 35, 2.5, 0, { 0, 0.1, 0 }),
	},
}

-- Zone 3, Divine: a little golden carousel that floats and turns, horses and all.
local Pastel = { 255, 200, 230 }
Looks.GoldenCarousel = {
	gait = "float",
	top = 2.3,
	pieces = {
		block("Platform", { 2.4, 0.3, 2.4 }, { 0, -1.3, 0 }, Gold),
		block("PlatformTrim", { 2.5, 0.1, 2.5 }, { 0, -1.15, 0 }, CircusRed),
		block("Column", { 0.35, 2.4, 0.35 }, { 0, -0.1, 0 }, Gold),
		block("LeftEye", { 0.1, 0.1, 0.05 }, { -0.08, 0.3, -0.19 }, Candle, true),
		block("RightEye", { 0.1, 0.1, 0.05 }, { 0.08, 0.3, -0.19 }, Candle, true),
		block("Canopy", { 2.6, 0.3, 2.6 }, { 0, 1.1, 0 }, CircusCream),
		block("CanopyTrim", { 2.7, 0.12, 2.7 }, { 0, 0.92, 0 }, Gold),
		block("Roof", { 1.6, 0.4, 1.6 }, { 0, 1.45, 0 }, CircusRed),
		block("RoofTop", { 0.6, 0.4, 0.6 }, { 0, 1.8, 0 }, Gold),
		block("Star", { 0.3, 0.3, 0.3 }, { 0, 2.15, 0 }, Candle, true),
		block("Bulb1", { 0.15, 0.15, 0.15 }, { -1.25, 0.85, -1.25 }, Candle, true),
		block("Bulb2", { 0.15, 0.15, 0.15 }, { 1.25, 0.85, -1.25 }, Candle, true),
		block("Bulb3", { 0.15, 0.15, 0.15 }, { -1.25, 0.85, 1.25 }, Candle, true),
		block("Bulb4", { 0.15, 0.15, 0.15 }, { 1.25, 0.85, 1.25 }, Candle, true),
		-- Four horses on poles, turning round the column.
		spin(limb("Horse1", { 0.3, 0.4, 0.7 }, { 0.85, -0.4, 0 }, White, "Y", 0, 0.25, 0, { -0.85, 0, 0 })),
		spin(
			limb(
				"Horse1Head",
				{ 0.22, 0.3, 0.3 },
				{ 0.85, -0.15, -0.4 },
				White,
				"Y",
				0,
				0.25,
				0,
				{ -0.85, 0, 0.4 }
			)
		),
		spin(
			limb("Horse1Pole", { 0.08, 2, 0.08 }, { 0.85, -0.1, 0 }, Gold, "Y", 0, 0.25, 0, { -0.85, 0, 0 })
		),
		spin(limb("Horse2", { 0.3, 0.4, 0.7 }, { -0.85, -0.4, 0 }, Pastel, "Y", 0, 0.25, 0, { 0.85, 0, 0 })),
		spin(
			limb(
				"Horse2Head",
				{ 0.22, 0.3, 0.3 },
				{ -0.85, -0.15, 0.4 },
				Pastel,
				"Y",
				0,
				0.25,
				0,
				{ 0.85, 0, -0.4 }
			)
		),
		spin(
			limb("Horse2Pole", { 0.08, 2, 0.08 }, { -0.85, -0.1, 0 }, Gold, "Y", 0, 0.25, 0, { 0.85, 0, 0 })
		),
		spin(
			limb("Horse3", { 0.7, 0.4, 0.3 }, { 0, -0.4, 0.85 }, Moonglow, "Y", 0, 0.25, 0, { 0, 0, -0.85 })
		),
		spin(
			limb(
				"Horse3Head",
				{ 0.3, 0.3, 0.22 },
				{ 0.4, -0.15, 0.85 },
				Moonglow,
				"Y",
				0,
				0.25,
				0,
				{ -0.4, 0, -0.85 }
			)
		),
		spin(
			limb("Horse3Pole", { 0.08, 2, 0.08 }, { 0, -0.1, 0.85 }, Gold, "Y", 0, 0.25, 0, { 0, 0, -0.85 })
		),
		spin(
			limb("Horse4", { 0.7, 0.4, 0.3 }, { 0, -0.4, -0.85 }, CircusTeal, "Y", 0, 0.25, 0, { 0, 0, 0.85 })
		),
		spin(
			limb(
				"Horse4Head",
				{ 0.3, 0.3, 0.22 },
				{ -0.4, -0.15, -0.85 },
				CircusTeal,
				"Y",
				0,
				0.25,
				0,
				{ 0.4, 0, 0.85 }
			)
		),
		spin(
			limb("Horse4Pole", { 0.08, 2, 0.08 }, { 0, -0.1, -0.85 }, Gold, "Y", 0, 0.25, 0, { 0, 0, 0.85 })
		),
	},
}

-- Watcher event monsters: they only appear in the main area during a Watcher event.
local Phantom = { 200, 215, 255 }
local PhantomDark = { 120, 135, 190 }
local Nightmare = { 230, 40, 150 }
local Eldritch = { 40, 255, 200 }
local Flesh = { 70, 35, 80 }

-- Flicker, Phantom: a haunted candle with a carved face and a flickering flame.
Looks.Flickerwick = {
	gait = "float",
	top = 1.15,
	pieces = {
		block("Wax", { 0.9, 1.6, 0.9 }, { 0, -0.4, 0 }, { 240, 235, 220 }),
		block("Drip1", { 0.2, 0.5, 0.05 }, { 0.3, 0.15, -0.47 }, { 240, 235, 220 }),
		block("Drip2", { 0.2, 0.35, 0.05 }, { -0.3, 0.2, -0.47 }, { 240, 235, 220 }),
		block("Wick", { 0.1, 0.2, 0.1 }, { 0, 0.5, 0 }, Black),
		limb("Flame", { 0.4, 0.6, 0.4 }, { 0, 0.85, 0 }, Candle, "Z", 15, 4, 0, { 0, -0.3, 0 }, true),
		block("LeftEye", { 0.2, 0.25, 0.05 }, { -0.2, 0, -0.47 }, Black),
		block("RightEye", { 0.2, 0.25, 0.05 }, { 0.2, 0, -0.47 }, Black),
		block("Mouth", { 0.22, 0.28, 0.05 }, { 0, -0.45, -0.47 }, Black),
		block("Dish", { 1.4, 0.2, 1.4 }, { 0, -1.3, 0 }, Bronze),
		block("Handle", { 0.12, 0.4, 0.3 }, { 0.76, -1.2, 0 }, Bronze),
		limb("Wisp", { 0.5, 0.6, 0.5 }, { 0, -1.7, 0 }, Phantom, "X", 20, 1, 0, { 0, 0.3, 0 }, true),
	},
}

-- Flicker, Phantom: an old television haunted by a shadow; its static face stares out.
Looks.StaticShade = {
	gait = "float",
	top = 1.55,
	pieces = {
		block("Cabinet", { 1.8, 1.4, 1.2 }, { 0, 0, 0 }, Wood),
		block("Screen", { 1.1, 1, 0.1 }, { -0.2, 0.05, -0.61 }, { 200, 210, 220 }, true),
		block("StaticTop", { 1.05, 0.06, 0.05 }, { -0.2, 0.42, -0.67 }, { 120, 130, 140 }),
		block("StaticBottom", { 1.05, 0.06, 0.05 }, { -0.2, -0.35, -0.67 }, { 120, 130, 140 }),
		block("LeftEye", { 0.2, 0.2, 0.05 }, { -0.45, 0.2, -0.67 }, Black),
		block("RightEye", { 0.2, 0.2, 0.05 }, { 0.05, 0.2, -0.67 }, Black),
		block("Mouth", { 0.5, 0.1, 0.05 }, { -0.2, -0.15, -0.67 }, Black),
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
		limb("Shadow", { 1.2, 0.8, 1 }, { 0, -1.1, 0 }, { 50, 50, 80 }, "X", 10, 1, 0, { 0, 0.4, 0 }),
		limb("ShadowTail", { 0.6, 0.6, 0.6 }, { 0, -1.7, 0 }, { 40, 40, 65 }, "X", 20, 1, 0.3, { 0, 1, 0 }),
	},
}

-- Blood Moon, Phantom: a spirit of blood-red fire with flickering flame tongues and embers.
local DeepRed = { 150, 20, 30 }
local Flame = { 255, 90, 60 }
Looks.CrimsonWisp = {
	gait = "float",
	top = 1.55,
	pieces = {
		block("Flames", { 1.4, 1, 1.4 }, { 0, -0.1, 0 }, DeepRed),
		block("Core", { 1, 1, 1 }, { 0, 0.2, 0 }, { 255, 60, 60 }, true),
		block("LeftEye", { 0.2, 0.25, 0.05 }, { -0.25, 0.35, -0.52 }, Black),
		block("RightEye", { 0.2, 0.25, 0.05 }, { 0.25, 0.35, -0.52 }, Black),
		block("Mouth", { 0.45, 0.1, 0.05 }, { 0, 0, -0.52 }, Black),
		limb("TongueLeft", { 0.4, 0.8, 0.4 }, { -0.4, 0.9, 0 }, Flame, "Z", 15, 3, 0, { 0, -0.4, 0 }, true),
		limb(
			"TongueRight",
			{ 0.35, 0.7, 0.35 },
			{ 0.4, 0.8, 0.2 },
			Flame,
			"Z",
			15,
			3,
			0.4,
			{ 0, -0.35, 0 },
			true
		),
		limb(
			"TongueMiddle",
			{ 0.35, 0.9, 0.35 },
			{ 0, 1.1, -0.1 },
			Candle,
			"X",
			12,
			3,
			0.7,
			{ 0, -0.45, 0 },
			true
		),
		limb("Tail", { 0.5, 0.7, 0.5 }, { 0, -0.95, 0 }, DeepRed, "X", 20, 1.5, 0, { 0, 0.35, 0 }),
		limb(
			"TailTip",
			{ 0.3, 0.5, 0.3 },
			{ 0.1, -1.5, 0.1 },
			Flame,
			"X",
			20,
			1.5,
			0,
			{ -0.1, 0.9, -0.1 },
			true
		),
		spin(limb("Ember1", { 0.2, 0.2, 0.2 }, { 1.2, 0.3, 0 }, Flame, "Y", 0, 0.5, 0, { -1.2, 0, 0 }, true)),
		spin(
			limb(
				"Ember2",
				{ 0.15, 0.15, 0.15 },
				{ -1.1, 0.7, 0 },
				Candle,
				"Y",
				0,
				0.5,
				0,
				{ 1.1, 0, 0 },
				true
			)
		),
	},
}

-- Blood Moon, Phantom: the ghost of a werewolf, hunched on two legs with long clawed arms.
local GhostFur = { 150, 170, 200 }
local GhostFurDark = { 100, 115, 150 }
Looks.Moonhowler = {
	gait = "walk",
	top = 1.5,
	pieces = {
		block("Torso", { 1.3, 1.3, 0.9 }, { 0, -0.4, 0 }, GhostFur),
		block("Chest", { 0.9, 0.8, 0.1 }, { 0, -0.3, -0.48 }, { 200, 215, 235 }),
		block("Head", { 0.9, 0.8, 0.9 }, { 0, 0.65, -0.2 }, GhostFur),
		block("Snout", { 0.5, 0.4, 0.6 }, { 0, 0.5, -0.9 }, GhostFurDark),
		block("Nose", { 0.2, 0.15, 0.1 }, { 0, 0.68, -1.22 }, Black),
		block("LeftFang", { 0.08, 0.18, 0.08 }, { -0.15, 0.24, -1.1 }, White),
		block("RightFang", { 0.08, 0.18, 0.08 }, { 0.15, 0.24, -1.1 }, White),
		block("LeftEye", { 0.15, 0.12, 0.05 }, { -0.25, 0.8, -0.67 }, RedEye, true),
		block("RightEye", { 0.15, 0.12, 0.05 }, { 0.25, 0.8, -0.67 }, RedEye, true),
		block("LeftEar", { 0.2, 0.45, 0.2 }, { -0.3, 1.25, -0.1 }, GhostFurDark),
		block("RightEar", { 0.2, 0.45, 0.2 }, { 0.3, 1.25, -0.1 }, GhostFurDark),
		block("Mane", { 1.1, 0.4, 0.6 }, { 0, 0.3, 0.25 }, GhostFurDark),
		tilt(
			limb("Tail", { 0.4, 0.4, 1 }, { 0, -0.85, 0.85 }, GhostFurDark, "Y", 30, 2, 0, { 0, 0, -0.5 }),
			30,
			0,
			0
		),
		limb("LeftArm", { 0.35, 1.3, 0.35 }, { -0.85, -0.55, 0 }, GhostFur, "X", 35, 1.5, 0.5, { 0, 0.6, 0 }),
		limb(
			"LeftClaws",
			{ 0.4, 0.2, 0.4 },
			{ -0.85, -1.3, -0.05 },
			White,
			"X",
			35,
			1.5,
			0.5,
			{ 0, 1.35, 0.05 }
		),
		limb("RightArm", { 0.35, 1.3, 0.35 }, { 0.85, -0.55, 0 }, GhostFur, "X", 35, 1.5, 0, { 0, 0.6, 0 }),
		limb(
			"RightClaws",
			{ 0.4, 0.2, 0.4 },
			{ 0.85, -1.3, -0.05 },
			White,
			"X",
			35,
			1.5,
			0,
			{ 0, 1.35, 0.05 }
		),
		limb(
			"LeftLeg",
			{ 0.4, 0.6, 0.4 },
			{ -0.35, -1.4, 0.05 },
			GhostFurDark,
			"X",
			30,
			1.5,
			0,
			{ 0, 0.3, 0 }
		),
		limb(
			"LeftFoot",
			{ 0.4, 0.25, 0.7 },
			{ -0.35, -1.875, -0.15 },
			GhostFurDark,
			"X",
			30,
			1.5,
			0,
			{ 0, 0.775, 0.2 }
		),
		limb(
			"RightLeg",
			{ 0.4, 0.6, 0.4 },
			{ 0.35, -1.4, 0.05 },
			GhostFurDark,
			"X",
			30,
			1.5,
			0.5,
			{ 0, 0.3, 0 }
		),
		limb(
			"RightFoot",
			{ 0.4, 0.25, 0.7 },
			{ 0.35, -1.875, -0.15 },
			GhostFurDark,
			"X",
			30,
			1.5,
			0.5,
			{ 0, 0.775, 0.2 }
		),
	},
}

-- Mimic Night, Nightmare: a mailbox on two post legs. Its lid flaps open on a mouth of teeth
-- and a long tongue.
local Mailbox = { 70, 90, 130 }
Looks.MailboxMimic = {
	gait = "walk",
	top = 1.05,
	pieces = {
		block("Box", { 1.2, 1, 1.8 }, { 0, 0.2, 0 }, Mailbox),
		block("Roof", { 1, 0.25, 1.8 }, { 0, 0.82, 0 }, Mailbox),
		block("Rust", { 0.05, 0.4, 0.5 }, { 0.62, 0, 0.4 }, { 140, 80, 40 }),
		block("Inside", { 1, 0.8, 0.05 }, { 0, 0.2, -0.88 }, Black),
		block("Tooth1", { 0.15, 0.22, 0.05 }, { -0.35, 0.5, -0.9 }, White),
		block("Tooth2", { 0.15, 0.22, 0.05 }, { -0.12, 0.5, -0.9 }, White),
		block("Tooth3", { 0.15, 0.22, 0.05 }, { 0.12, 0.5, -0.9 }, White),
		block("Tooth4", { 0.15, 0.22, 0.05 }, { 0.35, 0.5, -0.9 }, White),
		block("LeftEye", { 0.2, 0.2, 0.05 }, { -0.3, 0.75, -0.91 }, Nightmare, true),
		block("RightEye", { 0.2, 0.2, 0.05 }, { 0.3, 0.75, -0.91 }, Nightmare, true),
		limb("Lid", { 1.2, 0.9, 0.08 }, { 0, -0.05, -0.95 }, Mailbox, "X", -25, 2, 0, { 0, -0.45, 0 }),
		limb(
			"Tongue",
			{ 0.4, 0.1, 0.9 },
			{ 0, -0.2, -1.35 },
			{ 200, 40, 70 },
			"Y",
			25,
			2,
			0.3,
			{ 0, 0, 0.45 }
		),
		block("FlagPost", { 0.1, 0.6, 0.12 }, { 0.65, 0.5, 0.35 }, CircusRed),
		limb("Flag", { 0.1, 0.25, 0.45 }, { 0.65, 0.7, 0.1 }, CircusRed, "X", 25, 2, 0, { 0, 0, 0.22 }),
		limb("LeftPost", { 0.3, 1.7, 0.3 }, { -0.25, -1.15, 0 }, Wood, "X", 25, 1.8, 0, { 0, 0.85, 0 }),
		limb("RightPost", { 0.3, 1.7, 0.3 }, { 0.25, -1.15, 0 }, Wood, "X", 25, 1.8, 0.5, { 0, 0.85, 0 }),
	},
}

-- Mimic Night, Nightmare: a street lamp that grew spindly arms and a face in its lamp.
local SickLight = { 210, 255, 140 }
Looks.LamppostLurker = {
	gait = "walk",
	top = 2.9,
	pieces = {
		block("Base", { 0.8, 0.25, 0.8 }, { 0, -0.9, 0 }, Iron),
		block("Pole", { 0.3, 2.4, 0.3 }, { 0, 0.35, 0 }, Iron),
		block("CrossBar", { 1, 0.12, 0.12 }, { 0, 1.3, 0 }, Iron),
		block("Lamp", { 0.7, 0.8, 0.7 }, { 0, 2, 0 }, SickLight, true),
		block("LampFrame", { 0.75, 0.1, 0.75 }, { 0, 1.62, 0 }, Iron),
		block("Cap", { 0.9, 0.2, 0.9 }, { 0, 2.5, 0 }, Iron),
		block("Spike", { 0.15, 0.3, 0.15 }, { 0, 2.75, 0 }, Iron),
		block("LeftEye", { 0.15, 0.15, 0.05 }, { -0.15, 2.1, -0.37 }, Black),
		block("RightEye", { 0.15, 0.15, 0.05 }, { 0.15, 2.1, -0.37 }, Black),
		block("Mouth", { 0.35, 0.08, 0.05 }, { 0, 1.85, -0.37 }, Black),
		limb("LeftArm", { 0.15, 1.8, 0.15 }, { -0.5, 0.4, -0.05 }, Iron, "X", 30, 1.2, 0.5, { 0, 0.9, 0 }),
		limb("LeftClaw", { 0.3, 0.25, 0.3 }, { -0.5, -0.6, -0.05 }, Iron, "X", 30, 1.2, 0.5, { 0, 1.9, 0 }),
		limb("RightArm", { 0.15, 1.8, 0.15 }, { 0.5, 0.4, -0.05 }, Iron, "X", 30, 1.2, 0, { 0, 0.9, 0 }),
		limb("RightClaw", { 0.3, 0.25, 0.3 }, { 0.5, -0.6, -0.05 }, Iron, "X", 30, 1.2, 0, { 0, 1.9, 0 }),
		limb("LeftLeg", { 0.25, 1, 0.25 }, { -0.2, -1.5, 0 }, Iron, "X", 30, 1.2, 0, { 0, 0.5, 0 }),
		limb("RightLeg", { 0.25, 1, 0.25 }, { 0.2, -1.5, 0 }, Iron, "X", 30, 1.2, 0.5, { 0, 0.5, 0 }),
	},
}

-- Breach Storm, Nightmare: a crackling storm gremlin with a tiny thundercloud over its head.
local StormSkin = { 60, 70, 100 }
local Spark = { 120, 230, 255 }
local Lightning = { 255, 240, 120 }
Looks.StormGremlin = {
	gait = "walk",
	top = 1.3,
	pieces = {
		block("Body", { 1, 1, 0.8 }, { 0, -1, 0 }, StormSkin),
		block("Head", { 1, 0.8, 0.8 }, { 0, -0.1, -0.05 }, StormSkin),
		block("LeftEye", { 0.22, 0.22, 0.05 }, { -0.22, 0, -0.47 }, Spark, true),
		block("RightEye", { 0.22, 0.22, 0.05 }, { 0.22, 0, -0.47 }, Spark, true),
		block("Mouth", { 0.55, 0.12, 0.05 }, { 0, -0.3, -0.47 }, Black),
		block("Fang", { 0.1, 0.12, 0.05 }, { 0.15, -0.26, -0.5 }, White),
		tilt(block("LeftEar", { 0.55, 0.3, 0.1 }, { -0.7, 0.05, 0 }, StormSkin), 0, 0, -25),
		tilt(block("RightEar", { 0.55, 0.3, 0.1 }, { 0.7, 0.05, 0 }, StormSkin), 0, 0, 25),
		tilt(block("Spike1", { 0.15, 0.5, 0.15 }, { -0.25, 0.45, 0 }, Lightning, true), 0, 0, 20),
		block("Spike2", { 0.15, 0.55, 0.15 }, { 0, 0.5, 0 }, Lightning, true),
		tilt(block("Spike3", { 0.15, 0.5, 0.15 }, { 0.25, 0.45, 0 }, Lightning, true), 0, 0, -20),
		limb("Cloud", { 0.9, 0.35, 0.6 }, { 0, 1, 0 }, { 80, 85, 100 }, "X", 10, 1, 0, { 0, -0.2, 0 }),
		limb(
			"CloudPuff",
			{ 0.5, 0.3, 0.5 },
			{ 0.25, 1.15, 0 },
			{ 95, 100, 115 },
			"X",
			10,
			1,
			0,
			{ -0.25, -0.35, 0 }
		),
		limb(
			"Bolt",
			{ 0.08, 0.35, 0.08 },
			{ -0.15, 0.68, 0 },
			Lightning,
			"X",
			10,
			1,
			0,
			{ 0.15, 0.12, 0 },
			true
		),
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
	},
}

-- Breach Storm, Nightmare: a front door that walks. Peepholes for eyes, a brass knocker for a
-- mouth that swings as it goes.
local DoorWood = { 110, 35, 30 }
local DoorPanel = { 85, 25, 22 }
Looks.Doorknocker = {
	gait = "walk",
	top = 1.5,
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
		block("MailSlot", { 0.5, 0.08, 0.05 }, { 0, -0.75, -0.18 }, Black),
		block("Handle", { 0.12, 0.3, 0.15 }, { 0.6, -0.25, -0.22 }, Bronze),
		limb("LeftArm", { 0.25, 1, 0.25 }, { -0.93, -0.4, 0 }, DoorPanel, "X", 30, 1.5, 0.5, { 0, 0.45, 0 }),
		limb("LeftHand", { 0.3, 0.25, 0.3 }, { -0.93, -1, 0 }, Bronze, "X", 30, 1.5, 0.5, { 0, 1.05, 0 }),
		limb("RightArm", { 0.25, 1, 0.25 }, { 0.93, -0.4, 0 }, DoorPanel, "X", 30, 1.5, 0, { 0, 0.45, 0 }),
		limb("RightHand", { 0.3, 0.25, 0.3 }, { 0.93, -1, 0 }, Bronze, "X", 30, 1.5, 0, { 0, 1.05, 0 }),
		limb("LeftLeg", { 0.35, 0.4, 0.3 }, { -0.45, -1.8, 0 }, DoorPanel, "X", 30, 1.5, 0, { 0, 0.2, 0 }),
		limb("RightLeg", { 0.35, 0.4, 0.3 }, { 0.45, -1.8, 0 }, DoorPanel, "X", 30, 1.5, 0.5, { 0, 0.2, 0 }),
	},
}

-- Watcher Awakens, Eldritch: a small floating eyeball with a slit pupil, dangling tentacles.
local Eyeball = { 230, 225, 215 }
local Vein = { 180, 30, 40 }
Looks.Watcherling = {
	gait = "float",
	top = 1.3,
	pieces = {
		block("Eyeball", { 1.4, 1.4, 1.4 }, { 0, 0.3, 0 }, Eyeball),
		block("Iris", { 0.7, 0.7, 0.1 }, { 0, 0.3, -0.72 }, Eldritch, true),
		block("Pupil", { 0.15, 0.5, 0.05 }, { 0, 0.3, -0.78 }, Black),
		tilt(block("Vein1", { 0.06, 0.5, 0.05 }, { 0.5, 0.65, -0.71 }, Vein), 0, 0, 30),
		tilt(block("Vein2", { 0.06, 0.45, 0.05 }, { -0.45, 0, -0.71 }, Vein), 0, 0, -40),
		block("Lid", { 1.5, 0.35, 1.5 }, { 0, 1.05, 0.05 }, Flesh),
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
	},
}

-- Watcher Awakens, Eldritch: a piece of the Watcher itself. A great eye in a socket of dark
-- flesh, crowned with spikes, with smaller eyes circling it.
Looks.EyeOfTheWatcher = {
	gait = "float",
	top = 2,
	pieces = {
		block("Socket", { 2, 2, 2 }, { 0, 0.4, 0 }, Flesh),
		block("Eyeball", { 1.6, 1.6, 0.3 }, { 0, 0.4, -1 }, Eyeball),
		block("Iris", { 0.9, 0.9, 0.1 }, { 0, 0.4, -1.17 }, Eldritch, true),
		block("Pupil", { 0.35, 0.35, 0.05 }, { 0, 0.4, -1.23 }, Black),
		tilt(block("Vein1", { 0.06, 0.6, 0.05 }, { 0.6, 0.85, -1.16 }, Vein), 0, 0, 35),
		tilt(block("Vein2", { 0.06, 0.5, 0.05 }, { -0.6, -0.05, -1.16 }, Vein), 0, 0, -35),
		tilt(block("SpikeLeft", { 0.25, 0.8, 0.25 }, { -0.7, 1.6, 0 }, Black), 0, 0, 25),
		block("SpikeMiddle", { 0.25, 1, 0.25 }, { 0, 1.8, 0 }, Black),
		tilt(block("SpikeRight", { 0.25, 0.8, 0.25 }, { 0.7, 1.6, 0 }, Black), 0, 0, -25),
		spin(limb("SmallEye1", { 0.4, 0.4, 0.4 }, { 1.6, 0.4, 0 }, Eyeball, "Y", 0, 0.2, 0, { -1.6, 0, 0 })),
		spin(
			limb(
				"SmallIris1",
				{ 0.18, 0.18, 0.05 },
				{ 1.6, 0.4, -0.22 },
				Eldritch,
				"Y",
				0,
				0.2,
				0,
				{ -1.6, 0, 0.22 },
				true
			)
		),
		spin(limb("SmallEye2", { 0.4, 0.4, 0.4 }, { -1.6, 0.4, 0 }, Eyeball, "Y", 0, 0.2, 0, { 1.6, 0, 0 })),
		spin(
			limb(
				"SmallIris2",
				{ 0.18, 0.18, 0.05 },
				{ -1.6, 0.4, -0.22 },
				Eldritch,
				"Y",
				0,
				0.2,
				0,
				{ 1.6, 0, 0.22 },
				true
			)
		),
		spin(limb("SmallEye3", { 0.4, 0.4, 0.4 }, { 0, 0.4, 1.6 }, Eyeball, "Y", 0, 0.2, 0, { 0, 0, -1.6 })),
		spin(
			limb(
				"SmallIris3",
				{ 0.18, 0.18, 0.05 },
				{ -0.22, 0.4, 1.6 },
				Eldritch,
				"Y",
				0,
				0.2,
				0,
				{ 0.22, 0, -1.6 },
				true
			)
		),
		limb("LeftTentacle", { 0.3, 1.2, 0.3 }, { -0.6, -1.15, 0 }, Flesh, "Z", 20, 1, 0, { 0, 0.6, 0 }),
		limb("MiddleTentacle", { 0.3, 1.4, 0.3 }, { 0, -1.25, 0 }, Flesh, "X", 20, 1, 0.33, { 0, 0.7, 0 }),
		limb("RightTentacle", { 0.3, 1.2, 0.3 }, { 0.6, -1.15, 0 }, Flesh, "Z", 20, 1, 0.66, { 0, 0.6, 0 }),
	},
}

return Looks
