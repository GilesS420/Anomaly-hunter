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

-- Zone 1, Epic: a gravestone that got up and walks, grinning.
local Stone = { 130, 128, 140 }
local StoneDark = { 95, 92, 105 }
local Purple = { 200, 110, 255 }
Looks.Tombgrin = {
	gait = "walk",
	top = 1.7,
	pieces = {
		block("Slab", { 2, 2.6, 0.8 }, { 0, 0, 0 }, Stone),
		block("Top", { 1.6, 0.4, 0.8 }, { 0, 1.5, 0 }, Stone),
		block("Plate", { 1, 0.35, 0.1 }, { 0, 0.9, -0.45 }, StoneDark),
		block("Crack", { 0.15, 0.8, 0.1 }, { 0.6, -0.8, -0.45 }, StoneDark),
		block("Moss", { 0.8, 0.2, 0.85 }, { -0.5, 1.3, 0 }, Moss),
		block("LeftEye", { 0.3, 0.3, 0.1 }, { -0.4, 0.35, -0.45 }, Purple, true),
		block("RightEye", { 0.3, 0.3, 0.1 }, { 0.4, 0.35, -0.45 }, Purple, true),
		block("Grin", { 1.1, 0.2, 0.1 }, { 0, -0.25, -0.45 }, Purple, true),
		limb("LeftArm", { 0.4, 1, 0.4 }, { -1.2, -0.1, 0 }, StoneDark, "X", 30, 1.4, 0.5, { 0, 0.4, 0 }),
		limb("RightArm", { 0.4, 1, 0.4 }, { 1.2, -0.1, 0 }, StoneDark, "X", 30, 1.4, 0, { 0, 0.4, 0 }),
		limb("LeftLeg", { 0.5, 0.7, 0.5 }, { -0.5, -1.65, 0 }, StoneDark, "X", 25, 1.4, 0, { 0, 0.35, 0 }),
		limb("RightLeg", { 0.5, 0.7, 0.5 }, { 0.5, -1.65, 0 }, StoneDark, "X", 25, 1.4, 0.5, { 0, 0.35, 0 }),
	},
}

-- Zone 1, Legendary: the old graveyard keeper, a lantern in one hand and a shovel in the
-- other (they swing along with his arms).
local Coat = { 60, 85, 60 }
local Trousers = { 70, 50, 40 }
local Skin = { 200, 205, 190 }
local Wood = { 120, 80, 45 }
Looks.TheGroundskeeper = {
	gait = "walk",
	top = 1.9,
	pieces = {
		block("Torso", { 1.4, 1.4, 0.8 }, { 0, -0.3, 0 }, Coat),
		block("Head", { 0.9, 0.9, 0.9 }, { 0, 0.85, 0 }, Skin),
		block("Beard", { 0.8, 0.4, 0.2 }, { 0, 0.55, -0.5 }, { 180, 180, 180 }),
		block("LeftEye", { 0.18, 0.18, 0.1 }, { -0.2, 0.95, -0.47 }, Candle, true),
		block("RightEye", { 0.18, 0.18, 0.1 }, { 0.2, 0.95, -0.47 }, Candle, true),
		block("HatBrim", { 1.4, 0.15, 1.4 }, { 0, 1.35, 0 }, Trousers),
		block("HatTop", { 0.9, 0.5, 0.9 }, { 0, 1.65, 0 }, Trousers),
		limb("LeftArm", { 0.35, 1.3, 0.35 }, { -0.9, -0.4, 0 }, Coat, "X", 30, 1.4, 0.5, { 0, 0.55, 0 }),
		limb("RightArm", { 0.35, 1.3, 0.35 }, { 0.9, -0.4, 0 }, Coat, "X", 30, 1.4, 0, { 0, 0.55, 0 }),
		limb(
			"Lantern",
			{ 0.4, 0.5, 0.4 },
			{ 0.9, -1.25, -0.1 },
			Candle,
			"X",
			30,
			1.4,
			0,
			{ 0, 1.4, 0.1 },
			true
		),
		limb("Shovel", { 0.15, 1.7, 0.15 }, { -0.9, -0.5, -0.3 }, Wood, "X", 30, 1.4, 0.5, { 0, 0.65, 0.3 }),
		limb(
			"ShovelBlade",
			{ 0.5, 0.5, 0.1 },
			{ -0.9, -1.6, -0.3 },
			Stone,
			"X",
			30,
			1.4,
			0.5,
			{ 0, 1.75, 0.3 }
		),
		limb("LeftLeg", { 0.45, 1, 0.45 }, { -0.3, -1.5, 0 }, Trousers, "X", 28, 1.4, 0, { 0, 0.5, 0 }),
		limb("RightLeg", { 0.45, 1, 0.45 }, { 0.3, -1.5, 0 }, Trousers, "X", 28, 1.4, 0.5, { 0, 0.5, 0 }),
	},
}

-- Zone 1, Mythic: a headless rider on a black horse, holding up a burning pumpkin head.
local Horse = { 35, 30, 40 }
local Cloak = { 70, 40, 90 }
local Ember = { 130, 255, 120 }
Looks.TheHeadlessRider = {
	gait = "walk",
	top = 1.7,
	pieces = {
		block("HorseBody", { 1.4, 1.2, 2.8 }, { 0, -0.2, 0.1 }, Horse),
		block("HorseNeck", { 0.7, 1.2, 0.7 }, { 0, 0.6, -1.2 }, Horse),
		block("HorseHead", { 0.7, 0.6, 1 }, { 0, 1.1, -1.75 }, Horse),
		block("HorseLeftEye", { 0.1, 0.15, 0.15 }, { -0.36, 1.2, -1.95 }, { 255, 60, 60 }, true),
		block("HorseRightEye", { 0.1, 0.15, 0.15 }, { 0.36, 1.2, -1.95 }, { 255, 60, 60 }, true),
		block("Mane", { 0.2, 1.2, 0.5 }, { 0, 0.9, -1 }, Ember, true),
		block("Saddle", { 1.5, 0.2, 1 }, { 0, 0.45, 0.3 }, { 120, 30, 40 }),
		block("RiderBody", { 1, 1, 0.6 }, { 0, 1, 0.3 }, Cloak),
		block("NeckFlame", { 0.5, 0.3, 0.5 }, { 0, 1.6, 0.3 }, Ember, true),
		block("RiderArm", { 0.3, 0.3, 0.9 }, { 0.65, 1.2, -0.1 }, Cloak),
		block("PumpkinHead", { 0.65, 0.6, 0.65 }, { 0.65, 1.55, -0.55 }, Pumpkin),
		block("PumpkinEyes", { 0.4, 0.12, 0.1 }, { 0.65, 1.62, -0.9 }, Candle, true),
		limb("Cape", { 1.1, 1.3, 0.15 }, { 0, 0.85, 0.7 }, Cloak, "X", 15, 2, 0, { 0, 0.65, 0 }),
		limb("Tail", { 0.3, 1, 0.3 }, { 0, -0.3, 1.65 }, Ember, "X", 20, 2, 0, { 0, 0.5, 0 }, true),
		limb(
			"FrontLeftLeg",
			{ 0.35, 1.2, 0.35 },
			{ -0.45, -1.4, -0.9 },
			Horse,
			"X",
			32,
			2.2,
			0,
			{ 0, 0.6, 0 }
		),
		limb(
			"FrontRightLeg",
			{ 0.35, 1.2, 0.35 },
			{ 0.45, -1.4, -0.9 },
			Horse,
			"X",
			32,
			2.2,
			0.5,
			{ 0, 0.6, 0 }
		),
		limb(
			"BackLeftLeg",
			{ 0.35, 1.2, 0.35 },
			{ -0.45, -1.4, 1.1 },
			Horse,
			"X",
			32,
			2.2,
			0.5,
			{ 0, 0.6, 0 }
		),
		limb("BackRightLeg", { 0.35, 1.2, 0.35 }, { 0.45, -1.4, 1.1 }, Horse, "X", 32, 2.2, 0, { 0, 0.6, 0 }),
	},
}

-- Zone 1, Divine: a glowing ghost lady in a long dress with two lanterns floating at her sides.
local Dress = { 215, 230, 250 }
local Hair = { 60, 70, 120 }
local Gold = { 255, 210, 80 }
Looks.LadyOfLanterns = {
	gait = "float",
	top = 2.3,
	pieces = {
		block("Skirt", { 1.8, 1.6, 1.6 }, { 0, -0.6, 0 }, Dress),
		block("Hem", { 2.2, 0.4, 2 }, { 0, -1.5, 0 }, Dress),
		block("Bodice", { 1, 0.9, 0.7 }, { 0, 0.65, 0 }, { 190, 210, 245 }),
		block("Head", { 0.8, 0.8, 0.8 }, { 0, 1.5, 0 }, { 235, 240, 255 }),
		block("Hair", { 0.9, 1.2, 0.4 }, { 0, 1.3, 0.35 }, Hair),
		block("Crown", { 0.9, 0.2, 0.9 }, { 0, 2, 0 }, Gold, true),
		block("LeftEye", { 0.15, 0.15, 0.1 }, { -0.18, 1.55, -0.42 }, { 130, 220, 255 }, true),
		block("RightEye", { 0.15, 0.15, 0.1 }, { 0.18, 1.55, -0.42 }, { 130, 220, 255 }, true),
		limb("LeftArm", { 0.3, 1, 0.3 }, { -0.7, 0.55, 0 }, Dress, "Z", -20, 1, 0, { 0, 0.45, 0 }),
		limb("RightArm", { 0.3, 1, 0.3 }, { 0.7, 0.55, 0 }, Dress, "Z", 20, 1, 0.5, { 0, 0.45, 0 }),
		limb(
			"LeftLantern",
			{ 0.45, 0.55, 0.45 },
			{ -1.6, 0.6, -0.3 },
			Candle,
			"X",
			18,
			0.8,
			0,
			{ 0, 0.8, 0 },
			true
		),
		limb(
			"RightLantern",
			{ 0.45, 0.55, 0.45 },
			{ 1.6, 0.6, -0.3 },
			Candle,
			"X",
			18,
			0.8,
			0.5,
			{ 0, 0.8, 0 },
			true
		),
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
