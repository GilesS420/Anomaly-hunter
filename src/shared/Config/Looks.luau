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

return Looks
