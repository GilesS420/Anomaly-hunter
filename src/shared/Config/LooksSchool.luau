--!strict
-- Zone 4: Spooky School. Chalk dust, lockers, lunch trays and a bell tower full of bats.
-- Same format as Config/Looks (which merges these in); kept in its own file so Looks stays
-- under Luau's limit of local names per file.

type Joint = {
	axis: "X" | "Y" | "Z",
	amp: number,
	speed: number,
	phase: number?,
	pivot: { number }?,
	spin: boolean?,
	slide: boolean?,
	around: { number }?,
}

type Piece = {
	name: string,
	size: { number },
	at: { number },
	color: { number },
	shape: ("Block" | "Ball" | "Cylinder")?,
	glow: boolean?,
	rot: { number }?,
	joint: Joint?,
}

type Look = {
	gait: "walk" | "float",
	top: number,
	grow: number?,
	seeThrough: number?,
	wet: boolean?,
	pieces: { Piece },
}

local Black = { 27, 27, 32 }
local White = { 245, 245, 255 }
local Chalk = { 240, 238, 228 }
local ChalkWorn = { 222, 218, 205 }
local ChalkPink = { 235, 120, 160 }
local Paper = { 245, 242, 228 }
local PaperShade = { 220, 216, 200 }
local InkBlue = { 90, 130, 210 }
local MarginRed = { 220, 70, 80 }
local RedEye = { 255, 50, 50 }
local Jello = { 110, 215, 95 }
local JelloDark = { 70, 165, 60 }
local Tray = { 170, 175, 182 }
local Locker = { 60, 95, 150 }
local LockerDark = { 40, 62, 100 }
local Steel = { 150, 155, 165 }
local Yellow = { 255, 220, 90 }
local GhostKid = { 210, 225, 235 }
local Sash = { 255, 140, 40 }
local Clipboard = { 140, 95, 55 }
local Shadow = { 35, 30, 50 }
local Violet = { 190, 110, 255 }
local Suit = { 70, 72, 82 }
local SuitDark = { 50, 52, 60 }
local Skin = { 190, 200, 185 }
local Tie = { 150, 30, 40 }
local Ruler = { 205, 165, 90 }
local Brass = { 205, 155, 60 }
local BrassDark = { 150, 105, 40 }
local BatFur = { 45, 38, 52 }
local Membrane = { 70, 55, 80 }
local Night = { 30, 35, 95 }
local NightDark = { 18, 20, 55 }
local Star = { 255, 245, 190 }
local Cyan = { 140, 230, 255 }
local Gold = { 255, 210, 80 }

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

local function tilt(piece: Piece, x: number, y: number, z: number): Piece
	piece.rot = { x, y, z }
	return piece
end

local function spin(piece: Piece): Piece
	local joint = piece.joint :: Joint
	joint.spin = true
	return piece
end

local function slide(piece: Piece): Piece
	local joint = piece.joint :: Joint
	joint.slide = true
	return piece
end

-- Circles the monster's middle (round its straight-up axis), like a moon.
local function orbit(piece: Piece, speed: number, phase: number): Piece
	piece.joint = { axis = "Y", amp = 0, speed = speed, phase = phase, spin = true, around = { 0, 0, 0 } }
	return piece
end

local Looks: { [string]: Look } = {}

-- Zone 4, Common: a stick of chalk that got up and walks, worn flat on top, a pink paper
-- wrapper round its middle and dusty little feet.
Looks.Chalkling = {
	gait = "walk",
	top = 1.0,
	pieces = {
		block("Body", { 0.9, 2.2, 0.9 }, { 0, -0.4, 0 }, Chalk),
		block("Tip", { 0.8, 0.3, 0.8 }, { 0, 0.85, 0 }, ChalkWorn),
		block("Wrapper", { 0.95, 0.55, 0.95 }, { 0, -0.75, 0 }, ChalkPink),
		block("WrapperLine", { 0.97, 0.08, 0.97 }, { 0, -0.55, 0 }, White),
		block("LeftEye", { 0.2, 0.28, 0.05 }, { -0.2, 0.3, -0.47 }, Black),
		block("RightEye", { 0.2, 0.28, 0.05 }, { 0.2, 0.3, -0.47 }, Black),
		block("LeftGlint", { 0.07, 0.07, 0.05 }, { -0.23, 0.38, -0.5 }, White, true),
		block("RightGlint", { 0.07, 0.07, 0.05 }, { 0.17, 0.38, -0.5 }, White, true),
		block("Mouth", { 0.3, 0.08, 0.05 }, { 0, 0.0, -0.47 }, Black),
		block("Smudge", { 0.3, 0.2, 0.05 }, { 0.25, -0.2, -0.47 }, ChalkWorn),
		block("DustLeft", { 0.4, 0.15, 0.4 }, { -0.45, -1.925, -0.2 }, ChalkWorn),
		block("DustRight", { 0.3, 0.12, 0.3 }, { 0.5, -1.94, 0.25 }, ChalkWorn),
		limb("LeftArm", { 0.2, 0.7, 0.2 }, { -0.55, -0.35, 0 }, Chalk, "X", 35, 2.5, 0.5, { 0, 0.35, 0 }),
		limb("RightArm", { 0.2, 0.7, 0.2 }, { 0.55, -0.35, 0 }, Chalk, "X", 35, 2.5, 0, { 0, 0.35, 0 }),
		limb("LeftLeg", { 0.3, 0.5, 0.3 }, { -0.22, -1.75, 0 }, ChalkWorn, "X", 30, 2.5, 0, { 0, 0.25, 0 }),
		limb("RightLeg", { 0.3, 0.5, 0.3 }, { 0.22, -1.75, 0 }, ChalkWorn, "X", 30, 2.5, 0.5, { 0, 0.25, 0 }),
	},
}

-- Zone 4, Common: a bat folded out of lined notebook paper, a red margin down its back, its
-- paper wings flapping.
Looks.Paperbat = {
	gait = "float",
	top = 1.15,
	pieces = {
		block("Body", { 0.8, 0.8, 1.0 }, { 0, 0, 0.1 }, Paper),
		block("Margin", { 0.06, 0.82, 1.02 }, { -0.25, 0, 0.1 }, MarginRed),
		block("Line1", { 0.82, 0.04, 1.02 }, { 0, 0.2, 0.1 }, InkBlue),
		block("Line2", { 0.82, 0.04, 1.02 }, { 0, -0.15, 0.1 }, InkBlue),
		block("Head", { 0.7, 0.6, 0.6 }, { 0, 0.55, -0.3 }, Paper),
		tilt(block("LeftEar", { 0.2, 0.35, 0.1 }, { -0.22, 0.95, -0.3 }, PaperShade), 0, 0, 15),
		tilt(block("RightEar", { 0.2, 0.35, 0.1 }, { 0.22, 0.95, -0.3 }, PaperShade), 0, 0, -15),
		block("LeftEye", { 0.15, 0.12, 0.05 }, { -0.15, 0.62, -0.62 }, RedEye, true),
		block("RightEye", { 0.15, 0.12, 0.05 }, { 0.15, 0.62, -0.62 }, RedEye, true),
		block("LeftFang", { 0.07, 0.12, 0.05 }, { -0.08, 0.36, -0.62 }, White),
		block("RightFang", { 0.07, 0.12, 0.05 }, { 0.08, 0.36, -0.62 }, White),
		limb("LeftWing", { 1.4, 0.08, 0.9 }, { -1.1, 0.15, 0.1 }, Paper, "Z", -40, 3, 0, { 0.7, 0, 0 }),
		limb(
			"LeftWingFold",
			{ 1.0, 0.1, 0.06 },
			{ -1.0, 0.15, 0.1 },
			PaperShade,
			"Z",
			-40,
			3,
			0,
			{ 0.6, 0, 0 }
		),
		limb("RightWing", { 1.4, 0.08, 0.9 }, { 1.1, 0.15, 0.1 }, Paper, "Z", 40, 3, 0, { -0.7, 0, 0 }),
		limb(
			"RightWingFold",
			{ 1.0, 0.1, 0.06 },
			{ 1.0, 0.15, 0.1 },
			PaperShade,
			"Z",
			40,
			3,
			0,
			{ -0.6, 0, 0 }
		),
		block("LeftFoot", { 0.12, 0.25, 0.12 }, { -0.2, -0.52, 0.2 }, PaperShade),
		block("RightFoot", { 0.12, 0.25, 0.12 }, { 0.2, -0.52, 0.2 }, PaperShade),
	},
}

-- Zone 4, Uncommon: a wobbly cube of green cafeteria jello on a lunch tray, a cherry on top,
-- a spoon stuck in its side and a grumpy grin.
Looks.LunchGhoul = {
	gait = "walk",
	top = 0.55,
	wet = true,
	pieces = {
		block("Jello", { 1.8, 1.5, 1.6 }, { 0, -0.85, 0 }, Jello),
		block("JelloTop", { 1.6, 0.15, 1.4 }, { 0, -0.03, 0 }, JelloDark),
		block("Pea1", { 0.2, 0.2, 0.05 }, { 0.6, -1.25, -0.82 }, JelloDark),
		block("Pea2", { 0.18, 0.18, 0.05 }, { -0.65, -1.35, -0.82 }, JelloDark),
		block("Tray", { 2.4, 0.2, 2.0 }, { 0, -1.7, 0 }, Tray),
		block("TrayLip", { 2.4, 0.15, 0.1 }, { 0, -1.55, -1.0 }, Steel),
		block("Cherry", { 0.5, 0.5, 0.5 }, { 0.15, 0.2, 0 }, { 200, 30, 45 }),
		block("Stem", { 0.06, 0.3, 0.06 }, { 0.2, 0.4, 0 }, { 70, 110, 40 }),
		tilt(block("Spoon", { 0.14, 1.0, 0.08 }, { 0.95, -0.35, 0.3 }, Steel), 0, 0, -25),
		block("SpoonBowl", { 0.3, 0.35, 0.08 }, { 0.98, -0.95, 0.3 }, Steel),
		block("LeftEye", { 0.3, 0.25, 0.05 }, { -0.4, -0.55, -0.82 }, Black),
		block("RightEye", { 0.3, 0.25, 0.05 }, { 0.4, -0.55, -0.82 }, Black),
		block("LeftPupil", { 0.1, 0.1, 0.05 }, { -0.4, -0.55, -0.85 }, Yellow, true),
		block("RightPupil", { 0.1, 0.1, 0.05 }, { 0.4, -0.55, -0.85 }, Yellow, true),
		tilt(block("LeftBrow", { 0.35, 0.07, 0.05 }, { -0.4, -0.35, -0.82 }, Black), 0, 0, -18),
		tilt(block("RightBrow", { 0.35, 0.07, 0.05 }, { 0.4, -0.35, -0.82 }, Black), 0, 0, 18),
		block("Grin", { 0.8, 0.12, 0.05 }, { 0, -1.0, -0.82 }, Black),
		block("GrinTooth", { 0.12, 0.1, 0.05 }, { 0.15, -0.96, -0.85 }, White),
		limb("LeftFrontLeg", { 0.25, 0.2, 0.25 }, { -0.8, -1.9, -0.6 }, Steel, "X", 30, 3, 0, { 0, 0.1, 0 }),
		limb(
			"RightFrontLeg",
			{ 0.25, 0.2, 0.25 },
			{ 0.8, -1.9, -0.6 },
			Steel,
			"X",
			30,
			3,
			0.5,
			{ 0, 0.1, 0 }
		),
		limb("LeftBackLeg", { 0.25, 0.2, 0.25 }, { -0.8, -1.9, 0.6 }, Steel, "X", 30, 3, 0.5, { 0, 0.1, 0 }),
		limb("RightBackLeg", { 0.25, 0.2, 0.25 }, { 0.8, -1.9, 0.6 }, Steel, "X", 30, 3, 0, { 0, 0.1, 0 }),
	},
}

-- Zone 4, Uncommon: a school locker on stubby legs. Its door hangs open, creaking to and fro,
-- and inside two eyes glow in the dark.
local Hinge = { -0.65, -0.4, -0.66 } -- the door's hinge: the locker's front left edge
local DoorOpen = 100 -- degrees the door stands open (out to the front left)

-- A part on the open door, `lx` along the door from its middle, `ly` up and `lz` out of its
-- front (negative is outside), turned with the door and creaking round the hinge with it.
local function onDoor(
	name: string,
	size: { number },
	lx: number,
	ly: number,
	lz: number,
	color: { number }
): Piece
	local a = math.rad(DoorOpen)
	local along = 0.65 + lx -- from the hinge
	return {
		name = name,
		size = size,
		at = {
			Hinge[1] + along * math.cos(a) + lz * math.sin(a),
			Hinge[2] + ly,
			Hinge[3] - along * math.sin(a) + lz * math.cos(a),
		},
		color = color,
		rot = { 0, DoorOpen, 0 },
		joint = { axis = "Y", amp = 12, speed = 1.2, phase = 0, pivot = { -along, 0, -lz } },
	}
end

Looks.LockerLurker = {
	gait = "walk",
	top = 0.95,
	pieces = {
		block("Locker", { 1.4, 2.6, 1.2 }, { 0, -0.4, 0 }, Locker),
		block("LockerTop", { 1.5, 0.1, 1.3 }, { 0, 0.9, 0 }, LockerDark),
		block("Inside", { 1.2, 2.3, 0.05 }, { 0, -0.4, -0.58 }, Black),
		block("LeftEye", { 0.25, 0.15, 0.05 }, { -0.25, 0.25, -0.61 }, Yellow, true),
		block("RightEye", { 0.25, 0.15, 0.05 }, { 0.25, 0.25, -0.61 }, Yellow, true),
		block("Teeth", { 0.6, 0.1, 0.05 }, { 0, -0.15, -0.61 }, White),
		onDoor("Door", { 1.3, 2.4, 0.08 }, 0, 0, 0, Locker),
		onDoor("Vent1", { 0.8, 0.07, 0.04 }, 0, 0.95, -0.06, LockerDark),
		onDoor("Vent2", { 0.8, 0.07, 0.04 }, 0, 0.8, -0.06, LockerDark),
		onDoor("Vent3", { 0.8, 0.07, 0.04 }, 0, 0.65, -0.06, LockerDark),
		onDoor("Handle", { 0.1, 0.35, 0.08 }, 0.45, 0, -0.08, Steel),
		onDoor("Lock", { 0.2, 0.2, 0.08 }, 0.45, -0.35, -0.08, Steel),
		limb("LeftArm", { 0.25, 0.9, 0.25 }, { -0.83, -0.5, 0 }, LockerDark, "X", 30, 2, 0.5, { 0, 0.45, 0 }),
		limb("RightArm", { 0.25, 0.9, 0.25 }, { 0.83, -0.5, 0 }, LockerDark, "X", 30, 2, 0, { 0, 0.45, 0 }),
		limb("LeftLeg", { 0.35, 0.3, 0.35 }, { -0.35, -1.85, 0 }, Black, "X", 30, 2, 0, { 0, 0.15, 0 }),
		limb("RightLeg", { 0.35, 0.3, 0.35 }, { 0.35, -1.85, 0 }, Black, "X", 30, 2, 0.5, { 0, 0.15, 0 }),
	},
}

-- Zone 4, Rare: the ghost of a hall monitor, see-through, with a bright orange sash, a silver
-- whistle and a clipboard full of names.
Looks.HallMonitor = {
	gait = "float",
	top = 1.6,
	seeThrough = 0.3,
	pieces = {
		block("Robe", { 1.2, 1.5, 1.0 }, { 0, -0.35, 0 }, GhostKid),
		block("Head", { 1.0, 1.0, 1.0 }, { 0, 0.9, 0 }, GhostKid),
		block("Cap", { 1.05, 0.25, 1.05 }, { 0, 1.475, 0 }, Sash, true),
		block("CapBrim", { 0.9, 0.08, 0.4 }, { 0, 1.4, -0.65 }, Sash, true),
		block("LeftEye", { 0.22, 0.32, 0.05 }, { -0.22, 0.95, -0.52 }, Black),
		block("RightEye", { 0.22, 0.32, 0.05 }, { 0.22, 0.95, -0.52 }, Black),
		block("Mouth", { 0.2, 0.2, 0.05 }, { 0, 0.6, -0.52 }, Black),
		tilt(block("Sash", { 0.3, 1.7, 1.04 }, { 0, -0.3, 0 }, Sash, true), 0, 0, 35),
		block("Cord", { 0.05, 0.4, 0.05 }, { 0.2, 0.2, -0.53 }, White),
		block("Whistle", { 0.25, 0.15, 0.2 }, { 0.2, -0.05, -0.6 }, Steel),
		limb("LeftArm", { 0.3, 0.9, 0.3 }, { -0.75, -0.3, 0 }, GhostKid, "X", 20, 1.2, 0.5, { 0, 0.45, 0 }),
		limb("RightArm", { 0.3, 0.9, 0.3 }, { 0.75, -0.3, 0 }, GhostKid, "X", -40, 1.2, 0, { 0, 0.45, 0 }),
		limb(
			"Clipboard",
			{ 0.7, 0.9, 0.08 },
			{ 0.75, -0.65, -0.35 },
			Clipboard,
			"X",
			-40,
			1.2,
			0,
			{ 0, 0.8, 0.35 }
		),
		limb(
			"ClipPaper",
			{ 0.55, 0.65, 0.04 },
			{ 0.75, -0.7, -0.4 },
			Paper,
			"X",
			-40,
			1.2,
			0,
			{ 0, 0.85, 0.4 }
		),
		limb("Clip", { 0.3, 0.12, 0.1 }, { 0.75, -0.25, -0.4 }, Steel, "X", -40, 1.2, 0, { 0, 0.4, 0.4 }),
		limb("Tail", { 0.8, 0.6, 0.7 }, { 0, -1.4, 0.1 }, GhostKid, "X", 20, 1, 0, { 0, 0.3, 0 }),
		limb("TailTip", { 0.4, 0.4, 0.4 }, { 0, -1.85, 0.2 }, GhostKid, "X", 30, 1, 0.2, { 0, 0.75, -0.1 }),
	},
}

-- Zone 4, Epic: a shadow in a hood that keeps you after school. A school clock is set in its
-- chest, its hands always spinning, and its eyes glow violet.
Looks.DetentionShade = {
	gait = "float",
	top = 1.75,
	seeThrough = 0.15,
	pieces = {
		block("Body", { 1.5, 1.9, 1.1 }, { 0, -0.2, 0 }, Shadow),
		block("Head", { 1.1, 1.0, 1.0 }, { 0, 1.1, 0 }, Shadow),
		block("Hood", { 1.2, 0.15, 1.1 }, { 0, 1.675, 0.05 }, NightDark),
		block("Face", { 0.8, 0.7, 0.05 }, { 0, 1.05, -0.52 }, Black),
		block("LeftEye", { 0.22, 0.12, 0.05 }, { -0.2, 1.12, -0.55 }, Violet, true),
		block("RightEye", { 0.22, 0.12, 0.05 }, { 0.2, 1.12, -0.55 }, Violet, true),
		block("ClockRim", { 1.0, 1.0, 0.08 }, { 0, -0.05, -0.58 }, Steel),
		block("ClockFace", { 0.85, 0.85, 0.05 }, { 0, -0.05, -0.63 }, White, true),
		block("Tick12", { 0.06, 0.12, 0.03 }, { 0, 0.3, -0.66 }, Black),
		block("Tick3", { 0.12, 0.06, 0.03 }, { 0.35, -0.05, -0.66 }, Black),
		block("Tick6", { 0.06, 0.12, 0.03 }, { 0, -0.4, -0.66 }, Black),
		block("Tick9", { 0.12, 0.06, 0.03 }, { -0.35, -0.05, -0.66 }, Black),
		spin(
			limb(
				"MinuteHand",
				{ 0.05, 0.36, 0.03 },
				{ 0, 0.13, -0.68 },
				Black,
				"Z",
				0,
				0.5,
				0,
				{ 0, -0.18, 0 }
			)
		),
		spin(
			limb(
				"HourHand",
				{ 0.07, 0.22, 0.03 },
				{ 0, 0.06, -0.69 },
				RedEye,
				"Z",
				0,
				0.08,
				0,
				{ 0, -0.11, 0 }
			)
		),
		block("ClockPin", { 0.08, 0.08, 0.04 }, { 0, -0.05, -0.71 }, Black),
		limb("LeftArm", { 0.35, 1.4, 0.35 }, { -0.95, -0.25, 0 }, Shadow, "Z", -15, 0.8, 0, { 0, 0.7, 0 }),
		limb("RightArm", { 0.35, 1.4, 0.35 }, { 0.95, -0.25, 0 }, Shadow, "Z", 15, 0.8, 0.5, { 0, 0.7, 0 }),
		limb("LeftClaw", { 0.4, 0.3, 0.4 }, { -0.95, -1.1, 0 }, NightDark, "Z", -15, 0.8, 0, { 0, 1.55, 0 }),
		limb("RightClaw", { 0.4, 0.3, 0.4 }, { 0.95, -1.1, 0 }, NightDark, "Z", 15, 0.8, 0.5, { 0, 1.55, 0 }),
		limb("Wisp1", { 1.0, 0.6, 0.8 }, { 0, -1.45, 0 }, Shadow, "X", 20, 0.9, 0, { 0, 0.3, 0 }),
		limb(
			"Wisp2",
			{ 0.6, 0.5, 0.5 },
			{ 0.15, -1.95, 0.1 },
			NightDark,
			"X",
			30,
			0.9,
			0.25,
			{ -0.15, 0.8, -0.1 }
		),
		slide(limb("Paper", { 0.6, 0.8, 0.04 }, { -1.3, 0.6, -0.3 }, Paper, "Y", 0.2, 0.7, 0, { 0, 0, 0 })),
		block("PaperLine1", { 0.45, 0.04, 0.02 }, { -1.3, 0.8, -0.33 }, InkBlue),
		block("PaperLine2", { 0.45, 0.04, 0.02 }, { -1.3, 0.6, -0.33 }, InkBlue),
	},
}

-- Zone 4, Legendary: the Principal. Tall and stern in a grey suit and red tie, bald, with
-- round glasses that glow white and a long wooden ruler tapping in one hand.
Looks.ThePrincipal = {
	gait = "walk",
	top = 1.45,
	pieces = {
		block("Jacket", { 1.4, 1.5, 0.8 }, { 0, -0.25, 0 }, Suit),
		block("Shirt", { 0.45, 0.9, 0.05 }, { 0, 0.05, -0.42 }, White),
		block("Tie", { 0.18, 0.7, 0.05 }, { 0, -0.05, -0.45 }, Tie),
		block("TieKnot", { 0.22, 0.15, 0.06 }, { 0, 0.38, -0.45 }, Tie),
		block("LeftLapel", { 0.2, 0.7, 0.05 }, { -0.33, 0.1, -0.42 }, SuitDark),
		block("RightLapel", { 0.2, 0.7, 0.05 }, { 0.33, 0.1, -0.42 }, SuitDark),
		block("Badge", { 0.2, 0.12, 0.05 }, { -0.45, 0.3, -0.43 }, Gold, true),
		block("Button", { 0.08, 0.08, 0.05 }, { 0.2, -0.6, -0.42 }, Black),
		block("Head", { 0.9, 0.9, 0.85 }, { 0, 0.95, 0 }, Skin),
		block("LeftHair", { 0.12, 0.35, 0.6 }, { -0.5, 0.95, 0.05 }, Steel),
		block("RightHair", { 0.12, 0.35, 0.6 }, { 0.5, 0.95, 0.05 }, Steel),
		block("LeftLens", { 0.28, 0.24, 0.05 }, { -0.2, 1.0, -0.45 }, White, true),
		block("RightLens", { 0.28, 0.24, 0.05 }, { 0.2, 1.0, -0.45 }, White, true),
		block("Bridge", { 0.14, 0.05, 0.05 }, { 0, 1.02, -0.46 }, Black),
		tilt(block("LeftBrow", { 0.3, 0.07, 0.05 }, { -0.2, 1.2, -0.45 }, Black), 0, 0, -15),
		tilt(block("RightBrow", { 0.3, 0.07, 0.05 }, { 0.2, 1.2, -0.45 }, Black), 0, 0, 15),
		block("Mustache", { 0.5, 0.1, 0.07 }, { 0, 0.75, -0.45 }, Steel),
		block("Frown", { 0.3, 0.06, 0.05 }, { 0, 0.63, -0.44 }, Black),
		limb("LeftArm", { 0.32, 1.1, 0.32 }, { -0.86, -0.3, 0 }, Suit, "X", 25, 1.4, 0.5, { 0, 0.55, 0 }),
		limb("LeftHand", { 0.3, 0.28, 0.3 }, { -0.86, -0.99, 0 }, Skin, "X", 25, 1.4, 0.5, { 0, 1.24, 0 }),
		limb("RightArm", { 0.32, 1.1, 0.32 }, { 0.86, -0.3, 0 }, Suit, "X", 25, 1.4, 0, { 0, 0.55, 0 }),
		limb("RightHand", { 0.3, 0.28, 0.3 }, { 0.86, -0.99, 0 }, Skin, "X", 25, 1.4, 0, { 0, 1.24, 0 }),
		limb("Ruler", { 0.12, 0.05, 1.4 }, { 0.86, -1.0, -0.8 }, Ruler, "X", 25, 1.4, 0, { 0, 1.25, 0.8 }),
		limb(
			"RulerMarks",
			{ 0.13, 0.06, 1.0 },
			{ 0.86, -0.99, -0.85 },
			Black,
			"X",
			25,
			1.4,
			0,
			{ 0, 1.24, 0.85 }
		),
		limb(
			"LeftLeg",
			{ 0.42, 0.85, 0.42 },
			{ -0.3, -1.425, 0 },
			SuitDark,
			"X",
			25,
			1.4,
			0,
			{ 0, 0.425, 0 }
		),
		limb(
			"LeftShoe",
			{ 0.46, 0.2, 0.62 },
			{ -0.3, -1.9, -0.08 },
			Black,
			"X",
			25,
			1.4,
			0,
			{ 0, 0.9, 0.08 }
		),
		limb(
			"RightLeg",
			{ 0.42, 0.85, 0.42 },
			{ 0.3, -1.425, 0 },
			SuitDark,
			"X",
			25,
			1.4,
			0.5,
			{ 0, 0.425, 0 }
		),
		limb(
			"RightShoe",
			{ 0.46, 0.2, 0.62 },
			{ 0.3, -1.9, -0.08 },
			Black,
			"X",
			25,
			1.4,
			0.5,
			{ 0, 0.9, 0.08 }
		),
	},
}

-- Zone 4, Mythic: the old school bell, come alive as a bat. A brass bell for a body, a furry
-- bat head on its crown, big leathery wings and a clapper swinging underneath.
Looks.BellTowerBat = {
	gait = "float",
	top = 2.3,
	pieces = {
		block("BellLip", { 2.3, 0.3, 2.3 }, { 0, -1.2, 0 }, BrassDark),
		block("Bell", { 2.0, 1.1, 2.0 }, { 0, -0.5, 0 }, Brass),
		block("BellBand", { 2.05, 0.12, 2.05 }, { 0, -0.75, 0 }, BrassDark),
		block("BellUpper", { 1.6, 0.7, 1.6 }, { 0, 0.4, 0 }, Brass),
		block("BellCrown", { 1.1, 0.35, 1.1 }, { 0, 0.92, 0 }, BrassDark),
		block("Shine", { 0.15, 0.6, 0.05 }, { 0.6, -0.4, -1.01 }, Star, true),
		block("Head", { 1.0, 0.9, 0.9 }, { 0, 1.5, -0.1 }, BatFur),
		tilt(block("LeftEar", { 0.3, 0.6, 0.12 }, { -0.35, 2.0, -0.1 }, BatFur), 0, 0, 15),
		tilt(block("RightEar", { 0.3, 0.6, 0.12 }, { 0.35, 2.0, -0.1 }, BatFur), 0, 0, -15),
		block("LeftEye", { 0.2, 0.15, 0.05 }, { -0.22, 1.6, -0.57 }, RedEye, true),
		block("RightEye", { 0.2, 0.15, 0.05 }, { 0.22, 1.6, -0.57 }, RedEye, true),
		block("Snout", { 0.35, 0.25, 0.1 }, { 0, 1.35, -0.6 }, Membrane),
		block("LeftFang", { 0.08, 0.15, 0.05 }, { -0.1, 1.17, -0.6 }, White),
		block("RightFang", { 0.08, 0.15, 0.05 }, { 0.1, 1.17, -0.6 }, White),
		limb("LeftWing", { 2.4, 0.12, 1.5 }, { -2.0, 0.5, 0.2 }, Membrane, "Z", -45, 1.8, 0, { 1.2, 0, 0 }),
		limb(
			"LeftWingBone",
			{ 2.4, 0.2, 0.15 },
			{ -2.0, 0.55, -0.5 },
			BatFur,
			"Z",
			-45,
			1.8,
			0,
			{ 1.2, -0.05, 0 }
		),
		limb("RightWing", { 2.4, 0.12, 1.5 }, { 2.0, 0.5, 0.2 }, Membrane, "Z", 45, 1.8, 0, { -1.2, 0, 0 }),
		limb(
			"RightWingBone",
			{ 2.4, 0.2, 0.15 },
			{ 2.0, 0.55, -0.5 },
			BatFur,
			"Z",
			45,
			1.8,
			0,
			{ -1.2, -0.05, 0 }
		),
		limb("ClapperRod", { 0.15, 0.8, 0.15 }, { 0, -1.3, 0 }, BrassDark, "X", 25, 1.8, 0.25, { 0, 0.4, 0 }),
		limb("Clapper", { 0.5, 0.5, 0.5 }, { 0, -1.85, 0 }, BrassDark, "X", 25, 1.8, 0.25, { 0, 0.95, 0 }),
	},
}

-- Zone 4, Divine: the Starlight Scholar, a floating figure in a night-sky robe dotted with
-- stars. Under its graduation cap is only darkness and two star-bright eyes; an open book of
-- glowing pages hovers before it and little stars circle round it.
Looks.StarlightScholar = {
	gait = "float",
	top = 2.0,
	pieces = {
		block("Robe", { 1.4, 2.0, 1.0 }, { 0, -0.5, 0 }, Night),
		block("Hem", { 1.8, 0.4, 1.3 }, { 0, -1.55, 0 }, NightDark),
		block("Collar", { 1.5, 0.2, 1.1 }, { 0, 0.55, 0 }, Gold, true),
		block("Head", { 0.95, 0.95, 0.9 }, { 0, 1.1, 0 }, Night),
		block("Face", { 0.75, 0.7, 0.05 }, { 0, 1.05, -0.47 }, NightDark),
		block("LeftEye", { 0.18, 0.18, 0.05 }, { -0.18, 1.1, -0.5 }, Cyan, true),
		block("RightEye", { 0.18, 0.18, 0.05 }, { 0.18, 1.1, -0.5 }, Cyan, true),
		block("CapBase", { 0.9, 0.3, 0.9 }, { 0, 1.65, 0 }, Black),
		tilt(block("CapBoard", { 1.5, 0.1, 1.5 }, { 0, 1.85, 0 }, Black), 0, 45, 0),
		block("CapButton", { 0.15, 0.1, 0.15 }, { 0, 1.95, 0 }, Gold, true),
		limb("Tassel", { 0.08, 0.6, 0.08 }, { 0.6, 1.55, -0.3 }, Gold, "Z", 15, 0.8, 0, { 0, 0.3, 0 }, true),
		block("Star1", { 0.15, 0.15, 0.05 }, { -0.4, 0.1, -0.52 }, Star, true),
		block("Star2", { 0.12, 0.12, 0.05 }, { 0.35, -0.3, -0.52 }, Star, true),
		block("Star3", { 0.15, 0.15, 0.05 }, { -0.2, -0.9, -0.52 }, Star, true),
		block("Star4", { 0.12, 0.12, 0.05 }, { 0.45, -1.1, -0.52 }, Star, true),
		block("Star5", { 0.1, 0.1, 0.05 }, { 0.1, 0.3, -0.52 }, Star, true),
		block("Star6", { 0.12, 0.12, 0.05 }, { -0.5, -0.5, 0.52 }, Star, true),
		block("Star7", { 0.15, 0.15, 0.05 }, { 0.3, 0.2, 0.52 }, Star, true),
		limb(
			"LeftArm",
			{ 0.32, 1.1, 0.32 },
			{ -0.85, -0.1, -0.2 },
			Night,
			"X",
			-50,
			0.7,
			0,
			{ 0, 0.55, 0.2 }
		),
		limb(
			"LeftHand",
			{ 0.3, 0.3, 0.3 },
			{ -0.85, -0.8, -0.2 },
			Gold,
			"X",
			-50,
			0.7,
			0,
			{ 0, 1.25, 0.2 },
			true
		),
		limb(
			"RightArm",
			{ 0.32, 1.1, 0.32 },
			{ 0.85, -0.1, -0.2 },
			Night,
			"X",
			-50,
			0.7,
			0.1,
			{ 0, 0.55, 0.2 }
		),
		limb(
			"RightHand",
			{ 0.3, 0.3, 0.3 },
			{ 0.85, -0.8, -0.2 },
			Gold,
			"X",
			-50,
			0.7,
			0.1,
			{ 0, 1.25, 0.2 },
			true
		),
		slide(limb("BookCover", { 1.3, 0.1, 0.9 }, { 0, -0.3, -1.3 }, Tie, "Y", 0.15, 0.6, 0, { 0, 0, 0 })),
		slide(
			limb(
				"LeftPage",
				{ 0.6, 0.06, 0.8 },
				{ -0.32, -0.22, -1.3 },
				Paper,
				"Y",
				0.15,
				0.6,
				0,
				{ 0, 0, 0 },
				true
			)
		),
		slide(
			limb(
				"RightPage",
				{ 0.6, 0.06, 0.8 },
				{ 0.32, -0.22, -1.3 },
				Paper,
				"Y",
				0.15,
				0.6,
				0,
				{ 0, 0, 0 },
				true
			)
		),
		orbit(block("Orbit1", { 0.3, 0.3, 0.3 }, { 1.6, 0.4, 0 }, Star, true), 0.25, 0),
		orbit(block("Orbit2", { 0.22, 0.22, 0.22 }, { -1.6, -0.2, 0 }, Cyan, true), 0.25, 0),
		orbit(block("Orbit3", { 0.18, 0.18, 0.18 }, { 0, 0.9, 1.5 }, Star, true), 0.25, 0),
	},
}

return Looks
