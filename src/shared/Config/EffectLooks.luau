--!strict
-- How effects, combos and catch variants change the way a monster looks. `EffectLooks.dress`
-- takes a monster's look (Config/Looks) and returns a new look with every change applied, so
-- MonsterModel builds it like any other look. Pure data, so the tests and the preview page see
-- exactly what the game builds.
--
-- A style can:
--   tint       mix the monster's colours toward a colour (mix 0..1); glowing bits keep theirs
--   glow       recolour the glowing bits (eyes, flames)
--   seeThrough make the non-glowing parts see-through (0..1)
--   shell      cover each part in a slightly bigger skin (slime, cobwebs)
--   wrap       wind bandages round each part (they swing with the limb they sit on)
--   patchwork  make every other part a sickly green or a dark brown patch (stitched together)
--   hueShift   turn the colours round the colour wheel (0..1), like a shiny monster
--   rainbow    colour the parts by height in rainbow bands
--   material   a Roblox material name for the non-glowing parts, with reflectance
--   extras     added blocks, placed on an anchor:
--                head   on top of the monster; extras on the head stack, they never overlap
--                back   behind it (front is -Z); back extras stack outward too
--                feet   at the bottom middle
--                orbit  circling round its middle (each orbit group a bit further out)
--              `at` and `size` are for a medium head and get scaled to the monster
--   auras      particles coming off the monster (kind Sparkle, Mist or Drip)
--   includes   the styles of other effects first (a combo builds on its two effects)
--
-- Variants (Silver, Gold, Shiny, Rainbow) are applied last, so a gold monster stays gold
-- whatever effects it has; their extras and auras still add up.

local Looks = require("./Looks")

export type Extra = {
	name: string,
	size: { number },
	at: { number },
	color: { number },
	shape: ("Block" | "Ball" | "Cylinder")?,
	glow: boolean?,
	rot: { number }?,
	material: string?,
	transparency: number?,
}

export type Group = {
	anchor: "head" | "back" | "feet" | "orbit",
	speed: number?, -- orbit: turns per second
	parts: { Extra },
}

export type Aura = {
	kind: "Sparkle" | "Mist" | "Drip",
	color: { number },
}

export type Style = {
	includes: { string }?,
	tint: { color: { number }, mix: number }?,
	glow: { number }?,
	seeThrough: number?,
	shell: { color: { number }, transparency: number, material: string? }?,
	wrap: { color: { number } }?,
	patchwork: number?,
	hueShift: number?,
	rainbow: boolean?,
	material: { name: string, reflectance: number? }?,
	extras: { Group }?,
	auras: { Aura }?,
}

-- Pieces get three optional fields on top of Looks.Piece; MonsterModel reads them.
export type Piece = Looks.Piece & {
	material: string?,
	reflectance: number?,
	transparency: number?,
}

export type DressedLook = Looks.Look & {
	auras: { Aura }?,
}

local EffectLooks = {}

-- Colours.
local Black = { 24, 22, 28 }
local Bone = { 232, 224, 200 }
local Gold = { 255, 205, 70 }
local Blood = { 200, 20, 30 }
local Orange = { 245, 130, 30 }
local Leaf = { 70, 140, 50 }
local Flame = { 255, 220, 90 }
local Bandage = { 226, 212, 172 }
local Fur = { 110, 78, 52 }
local Wood = { 120, 78, 40 }
local Purple = { 150, 60, 220 }

local function bat(name: string, x: number, z: number, color: { number }): { Extra }
	return {
		{ name = name, size = { 0.5, 0.4, 0.5 }, at = { x, 0, z }, color = color },
		{
			name = name .. "WingL",
			size = { 0.6, 0.1, 0.4 },
			at = { x - 0.55, 0.1, z },
			color = color,
			rot = { 0, 0, 20 },
		},
		{
			name = name .. "WingR",
			size = { 0.6, 0.1, 0.4 },
			at = { x + 0.55, 0.1, z },
			color = color,
			rot = { 0, 0, -20 },
		},
		{
			name = name .. "EyeL",
			size = { 0.1, 0.1, 0.05 },
			at = { x - 0.12, 0.05, z - 0.27 },
			color = Blood,
			glow = true,
		},
		{
			name = name .. "EyeR",
			size = { 0.1, 0.1, 0.05 },
			at = { x + 0.12, 0.05, z - 0.27 },
			color = Blood,
			glow = true,
		},
	}
end

local function bats(prefix: string, count: number, color: { number }): { Extra }
	local parts = {}
	for i = 1, count do
		local angle = (i - 1) / count * math.pi * 2
		for _, part in bat(`{prefix}{i}`, math.cos(angle), math.sin(angle), color) do
			table.insert(parts, part)
		end
	end
	return parts
end

-- Looks by effect id, combo id and variant id.
EffectLooks.Styles = {
	-- Roam effects.
	Cobwebbed = {
		tint = { color = { 150, 150, 155 }, mix = 0.3 },
		extras = {
			{
				anchor = "head",
				parts = {
					{
						name = "Web",
						size = { 2.2, 0.06, 2.2 },
						at = { 0, 0.05, 0 },
						color = { 240, 240, 245 },
						transparency = 0.4,
						rot = { 0, 45, 0 },
					},
					{
						name = "Thread",
						size = { 0.04, 0.9, 0.04 },
						at = { 0.6, 0.5, 0 },
						color = { 240, 240, 245 },
					},
					{
						name = "Spider",
						size = { 0.35, 0.3, 0.35 },
						at = { 0.6, 1.1, 0 },
						color = Black,
						shape = "Ball",
					},
				},
			},
		},
		auras = { { kind = "Mist", color = { 170, 170, 170 } } },
	},
	Possessed = {
		tint = { color = { 80, 40, 120 }, mix = 0.25 },
		glow = { 210, 120, 255 },
		extras = {
			{
				anchor = "orbit",
				speed = 0.5,
				parts = {
					{
						name = "Wisp1",
						size = { 0.4, 0.4, 0.4 },
						at = { 1, 0.4, 0 },
						color = { 210, 120, 255 },
						glow = true,
						shape = "Ball",
					},
					{
						name = "Wisp2",
						size = { 0.3, 0.3, 0.3 },
						at = { -1, -0.2, 0 },
						color = { 210, 120, 255 },
						glow = true,
						shape = "Ball",
					},
				},
			},
		},
		auras = { { kind = "Mist", color = { 170, 90, 255 } } },
	},
	Vampire = {
		tint = { color = { 205, 200, 220 }, mix = 0.35 },
		glow = { 255, 40, 50 },
		extras = {
			{
				anchor = "back",
				parts = {
					{ name = "CapeLining", size = { 1.8, 2, 0.1 }, at = { 0, -1, 0.05 }, color = Blood },
					{ name = "Cape", size = { 2, 2.2, 0.12 }, at = { 0, -1, 0.16 }, color = Black },
					{
						name = "CollarL",
						size = { 0.12, 0.8, 0.6 },
						at = { -1, 0.3, 0.1 },
						color = Black,
						rot = { 0, -20, 0 },
					},
					{
						name = "CollarR",
						size = { 0.12, 0.8, 0.6 },
						at = { 1, 0.3, 0.1 },
						color = Black,
						rot = { 0, 20, 0 },
					},
				},
			},
		},
	},
	Batty = {
		tint = { color = { 60, 40, 70 }, mix = 0.2 },
		extras = { { anchor = "orbit", speed = 0.4, parts = bats("Bat", 3, { 40, 30, 45 }) } },
	},
	Mummy = {
		tint = { color = Bandage, mix = 0.55 },
		wrap = { color = Bandage },
		glow = { 140, 255, 110 },
		auras = { { kind = "Mist", color = { 200, 190, 150 } } },
	},

	-- Food effects.
	PumpkinHead = {
		glow = Flame,
		extras = {
			{
				anchor = "head",
				parts = {
					{ name = "Pumpkin", size = { 1.6, 1.2, 1.5 }, at = { 0, 0.6, 0 }, color = Orange },
					{
						name = "PumpkinRib",
						size = { 0.5, 1.25, 1.55 },
						at = { 0, 0.6, 0 },
						color = { 225, 105, 20 },
					},
					{ name = "Stem", size = { 0.25, 0.4, 0.25 }, at = { 0, 1.4, 0 }, color = Leaf },
					{
						name = "EyeL",
						size = { 0.3, 0.25, 0.05 },
						at = { -0.35, 0.8, -0.78 },
						color = Flame,
						glow = true,
					},
					{
						name = "EyeR",
						size = { 0.3, 0.25, 0.05 },
						at = { 0.35, 0.8, -0.78 },
						color = Flame,
						glow = true,
					},
					{
						name = "Grin",
						size = { 0.9, 0.15, 0.05 },
						at = { 0, 0.35, -0.78 },
						color = Flame,
						glow = true,
					},
				},
			},
		},
	},
	Slimed = {
		tint = { color = { 110, 200, 70 }, mix = 0.3 },
		shell = { color = { 120, 235, 80 }, transparency = 0.55, material = "SmoothPlastic" },
		extras = {
			{
				anchor = "feet",
				parts = {
					{
						name = "Puddle",
						size = { 2.2, 0.08, 2.2 },
						at = { 0, 0.04, 0 },
						color = { 120, 235, 80 },
						glow = true,
						transparency = 0.4,
						shape = "Cylinder",
						rot = { 0, 0, 90 },
					},
				},
			},
		},
		auras = { { kind = "Drip", color = { 120, 235, 80 } } },
	},
	Cursed = {
		tint = { color = { 70, 30, 90 }, mix = 0.45 },
		glow = { 255, 60, 200 },
		extras = {
			{
				anchor = "head",
				parts = {
					{
						name = "CurseRing",
						size = { 0.1, 1.8, 1.8 },
						at = { 0, 0.6, 0 },
						color = { 255, 60, 200 },
						glow = true,
						shape = "Cylinder",
						rot = { 0, 0, 90 },
						transparency = 0.3,
					},
					{
						name = "CurseHole",
						size = { 0.12, 1.4, 1.4 },
						at = { 0, 0.6, 0 },
						color = Black,
						shape = "Cylinder",
						rot = { 0, 0, 90 },
					},
				},
			},
		},
		auras = { { kind = "Mist", color = { 110, 30, 140 } } },
	},

	-- Catch effects.
	Ghost = {
		seeThrough = 0.55,
		tint = { color = { 220, 235, 255 }, mix = 0.5 },
		glow = { 150, 220, 255 },
		auras = { { kind = "Mist", color = { 210, 230, 255 } } },
	},
	Werewolf = {
		tint = { color = Fur, mix = 0.45 },
		glow = { 255, 210, 60 },
		extras = {
			{
				anchor = "head",
				parts = {
					{
						name = "EarL",
						size = { 0.45, 0.7, 0.3 },
						at = { -0.5, 0.35, 0 },
						color = Fur,
						rot = { 0, 0, 12 },
					},
					{
						name = "EarR",
						size = { 0.45, 0.7, 0.3 },
						at = { 0.5, 0.35, 0 },
						color = Fur,
						rot = { 0, 0, -12 },
					},
					{
						name = "EarInL",
						size = { 0.25, 0.45, 0.05 },
						at = { -0.5, 0.3, -0.17 },
						color = { 230, 150, 150 },
						rot = { 0, 0, 12 },
					},
					{
						name = "EarInR",
						size = { 0.25, 0.45, 0.05 },
						at = { 0.5, 0.3, -0.17 },
						color = { 230, 150, 150 },
						rot = { 0, 0, -12 },
					},
				},
			},
		},
	},

	-- Event effects: these are what an event leaves on a monster, so each wears its event.
	Poltergeist = {
		seeThrough = 0.25,
		tint = { color = { 190, 210, 255 }, mix = 0.2 },
		glow = { 170, 220, 255 },
		extras = {
			{
				anchor = "orbit",
				speed = 0.3,
				parts = {
					{
						name = "Book",
						size = { 0.5, 0.15, 0.7 },
						at = { 1, 0.5, 0 },
						color = { 120, 40, 40 },
						rot = { 20, 0, 15 },
					},
					{
						name = "Pages",
						size = { 0.45, 0.1, 0.65 },
						at = { 1, 0.6, 0 },
						color = Bone,
						rot = { 20, 0, 15 },
					},
					{
						name = "Plate",
						size = { 0.08, 0.7, 0.7 },
						at = { -0.5, 0, 0.87 },
						color = Bone,
						shape = "Cylinder",
						rot = { 0, 0, 70 },
					},
					{ name = "Candle", size = { 0.2, 0.5, 0.2 }, at = { -0.5, -0.3, -0.87 }, color = Bone },
					{
						name = "CandleFlame",
						size = { 0.12, 0.2, 0.12 },
						at = { -0.5, 0.05, -0.87 },
						color = Flame,
						glow = true,
					},
				},
			},
		},
		auras = { { kind = "Mist", color = { 170, 210, 255 } } },
	},
	Bloodmoon = {
		tint = { color = { 150, 20, 30 }, mix = 0.45 },
		glow = { 255, 40, 40 },
		extras = {
			{
				anchor = "head",
				parts = {
					{
						name = "Moon",
						size = { 0.9, 0.9, 0.9 },
						at = { 0, 0.9, 0 },
						color = { 230, 40, 40 },
						glow = true,
						shape = "Ball",
					},
				},
			},
		},
		auras = { { kind = "Mist", color = { 200, 20, 30 } } },
	},
	Mimic = {
		tint = { color = Wood, mix = 0.4 },
		glow = Gold,
		extras = {
			{
				anchor = "head",
				parts = {
					{
						name = "Lid",
						size = { 1.8, 0.5, 1.4 },
						at = { 0, 0.4, 0.1 },
						color = Wood,
						rot = { -15, 0, 0 },
					},
					{
						name = "LidBandL",
						size = { 0.2, 0.55, 1.45 },
						at = { -0.6, 0.4, 0.1 },
						color = Gold,
						rot = { -15, 0, 0 },
						material = "Metal",
					},
					{
						name = "LidBandR",
						size = { 0.2, 0.55, 1.45 },
						at = { 0.6, 0.4, 0.1 },
						color = Gold,
						rot = { -15, 0, 0 },
						material = "Metal",
					},
					{
						name = "Lock",
						size = { 0.3, 0.3, 0.1 },
						at = { 0, 0.3, -0.68 },
						color = Gold,
						material = "Metal",
					},
					{ name = "Tooth1", size = { 0.2, 0.25, 0.1 }, at = { -0.5, 0.05, -0.55 }, color = Bone },
					{ name = "Tooth2", size = { 0.2, 0.25, 0.1 }, at = { 0, 0.05, -0.55 }, color = Bone },
					{ name = "Tooth3", size = { 0.2, 0.25, 0.1 }, at = { 0.5, 0.05, -0.55 }, color = Bone },
				},
			},
		},
		auras = { { kind = "Sparkle", color = Gold } },
	},
	Watched = {
		tint = { color = { 60, 20, 30 }, mix = 0.2 },
		glow = { 255, 40, 40 },
		extras = {
			{
				anchor = "head",
				parts = {
					{
						name = "Eye",
						size = { 1.3, 1.3, 1.3 },
						at = { 0, 1.1, 0 },
						color = Bone,
						shape = "Ball",
					},
					{
						name = "Iris",
						size = { 0.1, 0.75, 0.75 },
						at = { 0, 1.1, -0.62 },
						color = { 230, 30, 30 },
						glow = true,
						shape = "Cylinder",
						rot = { 0, 90, 0 },
					},
					{
						name = "Pupil",
						size = { 0.1, 0.35, 0.35 },
						at = { 0, 1.1, -0.67 },
						color = Black,
						shape = "Cylinder",
						rot = { 0, 90, 0 },
					},
				},
			},
		},
		auras = { { kind = "Mist", color = { 180, 20, 30 } } },
	},

	-- Round 2 effects.
	Stitched = {
		patchwork = 0.45,
		glow = { 140, 255, 120 },
		extras = {
			{
				anchor = "head",
				parts = {
					{
						name = "BoltL",
						size = { 0.5, 0.25, 0.25 },
						at = { -0.55, 0.15, 0 },
						color = { 150, 150, 160 },
						shape = "Cylinder",
						material = "Metal",
					},
					{
						name = "BoltR",
						size = { 0.5, 0.25, 0.25 },
						at = { 0.55, 0.15, 0 },
						color = { 150, 150, 160 },
						shape = "Cylinder",
						material = "Metal",
					},
					{ name = "Stitch1", size = { 0.8, 0.06, 0.1 }, at = { 0, 0.04, -0.3 }, color = Black },
					{
						name = "Stitch2",
						size = { 0.06, 0.06, 0.3 },
						at = { -0.2, 0.04, -0.3 },
						color = Black,
					},
					{ name = "Stitch3", size = { 0.06, 0.06, 0.3 }, at = { 0.2, 0.04, -0.3 }, color = Black },
				},
			},
		},
	},
	Hexed = {
		tint = { color = { 50, 90, 50 }, mix = 0.2 },
		glow = { 120, 255, 90 },
		extras = {
			{
				anchor = "head",
				parts = {
					{ name = "HatBrim", size = { 1.8, 0.12, 1.8 }, at = { 0, 0.06, 0 }, color = Black },
					{ name = "HatBand", size = { 1.05, 0.2, 1.05 }, at = { 0, 0.22, 0 }, color = Purple },
					{ name = "HatLow", size = { 1, 0.6, 1 }, at = { 0, 0.42, 0 }, color = Black },
					{
						name = "HatMid",
						size = { 0.65, 0.6, 0.65 },
						at = { 0.05, 1, 0.05 },
						color = Black,
						rot = { 0, 0, -8 },
					},
					{
						name = "HatTip",
						size = { 0.35, 0.5, 0.35 },
						at = { 0.2, 1.5, 0.1 },
						color = Black,
						rot = { 0, 0, -20 },
					},
				},
			},
		},
		auras = { { kind = "Sparkle", color = { 120, 255, 90 } } },
	},
	Eclipsed = {
		tint = { color = { 25, 20, 35 }, mix = 0.6 },
		glow = { 255, 150, 40 },
		extras = {
			{
				anchor = "back",
				parts = {
					{
						name = "Corona",
						size = { 0.1, 2.6, 2.6 },
						at = { 0, 0, 0.3 },
						color = { 255, 150, 40 },
						glow = true,
						shape = "Cylinder",
						rot = { 0, 90, 0 },
					},
					{
						name = "Sun",
						size = { 0.12, 2.1, 2.1 },
						at = { 0, 0, 0.2 },
						color = { 15, 12, 20 },
						shape = "Cylinder",
						rot = { 0, 90, 0 },
					},
				},
			},
		},
	},

	-- Combos: both effects' looks plus a finishing touch.
	Count = {
		includes = { "Vampire", "Batty" },
		extras = {
			{
				anchor = "head",
				parts = {
					{
						name = "Medallion",
						size = { 0.45, 0.45, 0.1 },
						at = { 0, -0.6, -0.8 },
						color = Gold,
						material = "Metal",
					},
					{
						name = "MedallionGem",
						size = { 0.2, 0.2, 0.06 },
						at = { 0, -0.6, -0.86 },
						color = Blood,
						glow = true,
					},
				},
			},
		},
	},
	Banshee = {
		includes = { "Cursed", "Ghost" },
		glow = { 190, 240, 255 },
		auras = { { kind = "Mist", color = { 230, 240, 255 } } },
	},
	Pharaoh = {
		includes = { "Mummy" },
		glow = Gold,
		extras = {
			{
				anchor = "head",
				parts = {
					{
						name = "Nemes",
						size = { 1.7, 0.5, 1.5 },
						at = { 0, 0.25, 0.05 },
						color = Gold,
						material = "Metal",
					},
					{
						name = "NemesStripe",
						size = { 1.75, 0.15, 1.55 },
						at = { 0, 0.25, 0.05 },
						color = { 40, 70, 170 },
					},
					{
						name = "FlapL",
						size = { 0.35, 1.1, 0.5 },
						at = { -0.8, -0.3, -0.2 },
						color = Gold,
						material = "Metal",
					},
					{
						name = "FlapR",
						size = { 0.35, 1.1, 0.5 },
						at = { 0.8, -0.3, -0.2 },
						color = Gold,
						material = "Metal",
					},
					{
						name = "Cobra",
						size = { 0.2, 0.4, 0.2 },
						at = { 0, 0.65, -0.65 },
						color = Gold,
						material = "Metal",
					},
				},
			},
		},
		auras = { { kind = "Sparkle", color = Gold } },
	},
	Alpha = {
		includes = { "Werewolf", "Bloodmoon" },
		glow = { 255, 30, 30 },
		tint = { color = { 90, 20, 25 }, mix = 0.3 },
	},

	-- Catch variants.
	Silver = {
		tint = { color = { 200, 205, 215 }, mix = 0.75 },
		material = { name = "Metal", reflectance = 0.25 },
		auras = { { kind = "Sparkle", color = { 230, 235, 255 } } },
	},
	Gold = {
		tint = { color = Gold, mix = 0.9 },
		material = { name = "Metal", reflectance = 0.35 },
		auras = { { kind = "Sparkle", color = Gold } },
	},
	Shiny = {
		hueShift = 0.45,
		auras = { { kind = "Sparkle", color = { 255, 255, 255 } } },
	},
	Rainbow = {
		rainbow = true,
		material = { name = "SmoothPlastic", reflectance = 0.15 },
		auras = {
			{ kind = "Sparkle", color = { 255, 120, 220 } },
			{ kind = "Sparkle", color = { 120, 220, 255 } },
		},
	},
} :: { [string]: Style }

EffectLooks.Variants = { "Silver", "Gold", "Shiny", "Rainbow" }

local function mixColor(a: { number }, b: { number }, t: number): { number }
	return {
		math.floor(a[1] + (b[1] - a[1]) * t + 0.5),
		math.floor(a[2] + (b[2] - a[2]) * t + 0.5),
		math.floor(a[3] + (b[3] - a[3]) * t + 0.5),
	}
end

local function toHsv(c: { number }): (number, number, number)
	local r, g, b = c[1] / 255, c[2] / 255, c[3] / 255
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local d = max - min
	local h = 0
	if d > 0 then
		if max == r then
			h = ((g - b) / d) % 6
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, if max > 0 then d / max else 0, max
end

local function fromHsv(h: number, s: number, v: number): { number }
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local r, g, b
	i %= 6
	if i == 0 then
		r, g, b = v, t, p
	elseif i == 1 then
		r, g, b = q, v, p
	elseif i == 2 then
		r, g, b = p, v, t
	elseif i == 3 then
		r, g, b = p, q, v
	elseif i == 4 then
		r, g, b = t, p, v
	else
		r, g, b = v, p, q
	end
	return { math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5) }
end

-- The box round a look's pieces (rotations ignored) and the piece that reaches highest.
local function bounds(pieces: { Piece }): ({ number }, { number }, Piece)
	local min, max = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	local top = pieces[1]
	for _, piece in pieces do
		for axis = 1, 3 do
			min[axis] = math.min(min[axis], piece.at[axis] - piece.size[axis] / 2)
			max[axis] = math.max(max[axis], piece.at[axis] + piece.size[axis] / 2)
		end
		if piece.at[2] + piece.size[2] / 2 > top.at[2] + top.size[2] / 2 then
			top = piece
		end
	end
	return min, max, top
end

-- The styles to apply, in order: included effects first, every style once.
local function collect(ids: { string }, out: { Style }, seen: { [string]: boolean })
	for _, id in ids do
		local style = EffectLooks.Styles[id]
		if style and not seen[id] then
			seen[id] = true
			if style.includes then
				collect(style.includes, out, seen)
			end
			table.insert(out, style)
		end
	end
end

local function recolor(pieces: { Piece }, style: Style)
	local min, max = bounds(pieces)
	for i, piece in pieces do
		if piece.glow then
			if style.glow then
				piece.color = style.glow
			end
			continue
		end
		if style.tint then
			piece.color = mixColor(piece.color, style.tint.color, style.tint.mix)
		end
		if style.patchwork then
			local toward = if i % 2 == 0 then { 150, 190, 130 } else { 95, 70, 60 }
			piece.color = mixColor(piece.color, toward, style.patchwork)
		end
		if style.hueShift then
			local h, s, v = toHsv(piece.color)
			piece.color = fromHsv((h + style.hueShift) % 1, math.max(s, 0.35), math.max(v, 0.35))
		end
		if style.rainbow then
			local height = (piece.at[2] - min[2]) / math.max(max[2] - min[2], 0.01)
			piece.color = fromHsv(height * 0.85, 0.75, 1)
		end
		if style.seeThrough then
			piece.transparency = style.seeThrough
		end
		if style.material then
			piece.material = style.material.name
			piece.reflectance = style.material.reflectance
		end
	end
end

-- A copy of a piece that sits on it, so it swings along with it.
local function onPiece(piece: Piece, name: string, size: { number }, color: { number }): Piece
	return {
		name = name,
		size = size,
		at = piece.at,
		color = color,
		shape = piece.shape,
		rot = piece.rot,
		joint = piece.joint,
	}
end

local function coverings(pieces: { Piece }, style: Style): { Piece }
	local added = {}
	for _, piece in pieces do
		if piece.glow then
			continue
		end
		local s = piece.size
		if style.shell then
			local shell = onPiece(
				piece,
				piece.name .. "Shell",
				{ s[1] + 0.12, s[2] + 0.12, s[3] + 0.12 },
				style.shell.color
			)
			shell.transparency = style.shell.transparency
			shell.material = style.shell.material
			table.insert(added, shell)
		end
		if style.wrap and s[2] >= 0.4 then
			-- One band round the middle of each part (two on long parts), along its height.
			local bands = if s[2] >= 1.2 then 2 else 1
			for b = 1, bands do
				local offset = if bands == 1 then 0 else (b - 1.5) * s[2] * 0.45
				local band = onPiece(
					piece,
					`{piece.name}Wrap{b}`,
					{ s[1] + 0.1, math.min(0.3, s[2] * 0.3), s[3] + 0.1 },
					style.wrap.color
				)
				band.material = "Fabric"
				if offset ~= 0 then
					-- Moved along the part's own up axis; a jointed band keeps the part's pivot.
					local rot = piece.rot or { 0, 0, 0 }
					local rx, ry, rz = math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])
					-- Up vector of CFrame.fromOrientation(rx, ry, rz) (Y, then X, then Z).
					local ux = -math.sin(rz) * math.cos(ry) + math.cos(rz) * math.sin(rx) * math.sin(ry)
					local uy = math.cos(rz) * math.cos(rx)
					local uz = math.sin(rz) * math.sin(ry) + math.cos(rz) * math.sin(rx) * math.cos(ry)
					band.at =
						{ piece.at[1] + ux * offset, piece.at[2] + uy * offset, piece.at[3] + uz * offset }
					if piece.joint and piece.joint.pivot then
						local p = piece.joint.pivot
						local joint = table.clone(piece.joint)
						joint.pivot = { p[1], p[2] - offset, p[3] }
						band.joint = joint
					end
				end
				table.insert(added, band)
			end
		end
	end
	return added
end

local function extent(group: Group, axis: number, sign: number): number
	local reach = 0
	for _, part in group.parts do
		reach = math.max(reach, sign * part.at[axis] + part.size[axis] / 2)
	end
	return reach
end

-- Places a style's extras on the look. `stack` remembers how far each anchor has been used
-- so later groups sit above (or behind, or outside) earlier ones instead of inside them.
local function place(
	pieces: { Piece },
	base: { Piece },
	groups: { Group },
	stack: { [string]: number },
	prefix: string
)
	local min, max = bounds(base)
	local width, depth = max[1] - min[1], max[3] - min[3]
	-- The head: every part reaching near the very top (a head with its ears or hat), so extras
	-- sit centred between the ears rather than on one of them.
	local hx0, hx1, hz0, hz1 = math.huge, -math.huge, math.huge, -math.huge
	for _, piece in base do
		if piece.at[2] + piece.size[2] / 2 >= max[2] - 0.6 then
			hx0 = math.min(hx0, piece.at[1] - piece.size[1] / 2)
			hx1 = math.max(hx1, piece.at[1] + piece.size[1] / 2)
			hz0 = math.min(hz0, piece.at[3] - piece.size[3] / 2)
			hz1 = math.max(hz1, piece.at[3] + piece.size[3] / 2)
		end
	end
	-- Head extras are drawn for a 1.6-stud head; scale them to the real one (within reason).
	local head = math.clamp(math.max(hx1 - hx0, hz1 - hz0) / 1.6, 0.6, 2.5)
	-- Back extras (capes, the eclipse) match the monster's width and height, not its length.
	local back = math.clamp(math.min(width / 2, (max[2] - min[2]) / 2.4), 0.6, 3)
	local body = math.clamp(math.max(width, depth) / 3, 0.6, 3)
	for _, group in groups do
		local k = if group.anchor == "head" then head elseif group.anchor == "back" then back else body
		local origin: { number }
		if group.anchor == "head" then
			local y = stack.head or max[2]
			-- Things hanging below the head line (collars, medallions) don't push the stack up.
			stack.head = y + extent(group, 2, 1) * k
			origin = { (hx0 + hx1) / 2, y, (hz0 + hz1) / 2 }
		elseif group.anchor == "back" then
			local z = stack.back or max[3]
			stack.back = z + extent(group, 3, 1) * k
			origin = { 0, (min[2] + max[2]) / 2 + (max[2] - min[2]) * 0.15, z }
		elseif group.anchor == "feet" then
			origin = { (min[1] + max[1]) / 2, min[2], (min[3] + max[3]) / 2 }
		else
			local reach = stack.orbit or (math.max(width, depth) / 2 + 0.6)
			stack.orbit = reach + 1.2 * k
			origin = { (min[1] + max[1]) / 2, (min[2] + max[2]) / 2, (min[3] + max[3]) / 2 }
			-- Orbit parts are given on a ring of radius 1; push them out to `reach`.
			for _, part in group.parts do
				local x, z = part.at[1], part.at[3]
				local length = math.sqrt(x * x + z * z)
				local scale = if length > 0 then (reach + 0.4) / length else 1
				local at = { origin[1] + x * scale, origin[2] + part.at[2], origin[3] + z * scale }
				table.insert(pieces, {
					name = `{prefix}{part.name}`,
					size = part.size,
					at = at,
					color = part.color,
					shape = part.shape,
					glow = part.glow,
					rot = part.rot,
					material = part.material,
					transparency = part.transparency,
					joint = {
						axis = "Y" :: "Y",
						amp = 0,
						speed = group.speed or 0.3,
						spin = true,
						around = origin,
					},
				})
			end
			continue
		end
		for _, part in group.parts do
			table.insert(pieces, {
				name = `{prefix}{part.name}`,
				size = { part.size[1] * k, part.size[2] * k, part.size[3] * k },
				at = { origin[1] + part.at[1] * k, origin[2] + part.at[2] * k, origin[3] + part.at[3] * k },
				color = part.color,
				shape = part.shape,
				glow = part.glow,
				rot = part.rot,
				material = part.material,
				transparency = part.transparency,
			})
		end
	end
end

-- The look with effects (already merged into combos, see Value.resolveEffects) and the
-- catch variant applied. With nothing to apply it returns the look itself.
function EffectLooks.dress(look: Looks.Look, effects: { string }?, variant: string?): DressedLook
	local styles: { Style } = {}
	collect(effects or {}, styles, {})
	local variantStyle = if variant then EffectLooks.Styles[variant] else nil
	if variantStyle then
		table.insert(styles, variantStyle)
	end
	if #styles == 0 then
		return look :: any
	end

	local base: { Piece } = {}
	for _, piece in look.pieces do
		table.insert(base, table.clone(piece) :: Piece)
	end
	-- Effects colour the monster first, the variant last.
	for _, style in styles do
		recolor(base, style)
	end
	local pieces: { Piece } = table.clone(base)
	local stack: { [string]: number } = {}
	local auras: { Aura } = {}
	-- Name extras after the style they came from so names never clash.
	local names: { [Style]: string } = {}
	for id, style in EffectLooks.Styles do
		names[style] = id
	end
	for _, style in styles do
		for _, piece in coverings(base, style) do
			table.insert(pieces, piece)
		end
		if style.extras then
			place(pieces, base, style.extras, stack, names[style])
		end
		for _, aura in style.auras or {} do
			table.insert(auras, aura)
		end
	end

	local _, max = bounds(pieces)
	local dressed: DressedLook = table.clone(look) :: any
	dressed.pieces = pieces :: any
	dressed.top = math.max(look.top, max[2])
	dressed.auras = if #auras > 0 then auras else nil
	-- See-through now comes per piece, so the look-wide setting would double it.
	if look.seeThrough then
		for _, piece in base do
			if not piece.glow and piece.transparency == nil then
				piece.transparency = look.seeThrough
			end
		end
		dressed.seeThrough = nil
	end
	return dressed
end

return EffectLooks
