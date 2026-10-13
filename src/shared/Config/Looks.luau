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

export type Joint = {
	axis: "X" | "Y" | "Z",
	amp: number,
	speed: number,
	phase: number?,
	pivot: { number }?,
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

return Looks
