--!strict
-- How effects, combos and catch variants change the way a monster looks. `EffectLooks.dress`
-- takes a monster's look (Config/Looks) and returns a new look with every change applied, so
-- MonsterModel builds it like any other look. Pure data, so the tests and the preview page see
-- exactly what the game builds.
--
-- Effects change the monster itself (its colours, skin and glow), they don't hand it hats or
-- props. A style can:
--   tint       mix the monster's colours toward a colour (mix 0..1); glowing bits keep theirs
--   fade       like tint, but strongest at the feet and gone at the top (a vampire's dark hem)
--   glow       recolour the glowing bits (eyes, flames)
--   seeThrough make the non-glowing parts see-through (0..1)
--   shell      cover each part in a slightly bigger skin (slime, cobwebs, an eclipse's glow)
--   wrap       wind bands round each part (bandages, gold straps, stitches)
--   fur        tufts of fur sticking out of the biggest parts
--   pumpkin    turn the head into a carved pumpkin
--   patchwork  make every other part a sickly green or a dark brown patch (stitched together)
--   hueShift   turn the colours round the colour wheel (0..1), like a shiny monster
--   rainbow    colours that keep cycling through the rainbow (the client turns them)
--   material   a Roblox material name for the non-glowing parts, with reflectance
--   extras     a few things that float with the monster, placed on an anchor:
--                head   above the monster; extras on the head stack, they never overlap
--                feet   at the bottom middle
--                orbit  circling round its middle (each orbit group a bit further out); a
--                       part's `angle` is where on the ring it sits, `at` is its offset there
--   auras      particles coming off the monster (kind Sparkle, Mist or Drip)
--   includes   the styles of other effects first (a combo builds on its two effects)
--
-- Everything added to a part (shells, bands, fur, stitches) copies that part's joint, so it
-- swings along with the limb it sits on. Variants (Silver, Gold, Shiny, Rainbow) are applied
-- last, so a gold monster stays gold whatever effects it has; their auras still add up.

local Looks = require("./Looks")

export type Extra = {
	name: string,
	size: { number },
	at: { number },
	color: { number },
	angle: number?, -- orbit: degrees round the ring
	shape: ("Block" | "Ball" | "Cylinder")?,
	glow: boolean?,
	rot: { number }?,
	material: string?,
	transparency: number?,
}

export type Group = {
	anchor: "head" | "feet" | "orbit",
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
	fade: { color: { number }, mix: number }?,
	glow: { number }?,
	seeThrough: number?,
	shell: { color: { number }, transparency: number, material: string?, glow: boolean? }?,
	wrap: { colors: { { number } }, thickness: number?, material: string?, stitches: boolean? }?,
	fur: { { number } }?,
	pumpkin: boolean?,
	patchwork: number?,
	hueShift: number?,
	rainbow: boolean?,
	material: { name: string, reflectance: number? }?,
	extras: { Group }?,
	auras: { Aura }?,
}

-- Pieces get a few optional fields on top of Looks.Piece; MonsterModel reads them.
export type Piece = Looks.Piece & {
	material: string?,
	reflectance: number?,
	transparency: number?,
	rainbow: number?, -- 0..1: where in the rainbow cycle this part starts
}

export type DressedLook = Looks.Look & {
	auras: { Aura }?,
}

local EffectLooks = {}

-- Colours.
local Black = { 24, 22, 28 }
local Bone = { 232, 224, 200 }
local Gold = { 255, 205, 30 }
local Orange = { 245, 130, 30 }
local Flame = { 255, 220, 90 }
local Bandage = { 226, 212, 172 }
local Fur = { 110, 78, 52 }

-- A little bat: body, ears, eyes and wings all touching, so it flies as one.
local function bat(name: string, angle: number): { Extra }
	local color = { 40, 30, 45 }
	local eye = { 255, 40, 50 }
	return {
		{ name = name, size = { 0.6, 0.55, 0.6 }, at = { 0, 0, 0 }, color = color, angle = angle },
		{
			name = name .. "WingL",
			size = { 0.7, 0.1, 0.5 },
			at = { -0.65, 0.12, 0 },
			color = color,
			angle = angle,
		},
		{
			name = name .. "WingR",
			size = { 0.7, 0.1, 0.5 },
			at = { 0.65, 0.12, 0 },
			color = color,
			angle = angle,
		},
		{
			name = name .. "EarL",
			size = { 0.14, 0.2, 0.14 },
			at = { -0.16, 0.37, 0 },
			color = color,
			angle = angle,
		},
		{
			name = name .. "EarR",
			size = { 0.14, 0.2, 0.14 },
			at = { 0.16, 0.37, 0 },
			color = color,
			angle = angle,
		},
		{
			name = name .. "EyeL",
			size = { 0.12, 0.12, 0.05 },
			at = { -0.14, 0.06, -0.32 },
			color = eye,
			glow = true,
			angle = angle,
		},
		{
			name = name .. "EyeR",
			size = { 0.12, 0.12, 0.05 },
			at = { 0.14, 0.06, -0.32 },
			color = eye,
			glow = true,
			angle = angle,
		},
	}
end

local function bats(prefix: string, count: number): { Extra }
	local parts = {}
	for i = 1, count do
		for _, part in bat(`{prefix}{i}`, (i - 1) * 360 / count) do
			table.insert(parts, part)
		end
	end
	return parts
end

-- Looks by effect id, combo id and variant id.
EffectLooks.Styles = {
	-- Roam effects.
	Cobwebbed = {
		tint = { color = { 150, 150, 155 }, mix = 0.35 },
		shell = { color = { 240, 240, 245 }, transparency = 0.7 },
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
						at = { 0, 0.4, 0 },
						angle = 0,
						color = { 210, 120, 255 },
						glow = true,
						shape = "Ball",
					},
					{
						name = "Wisp2",
						size = { 0.3, 0.3, 0.3 },
						at = { 0, -0.2, 0 },
						angle = 180,
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
		tint = { color = { 210, 205, 225 }, mix = 0.45 },
		fade = { color = { 90, 10, 20 }, mix = 0.8 },
		glow = { 255, 40, 50 },
		auras = { { kind = "Mist", color = { 120, 10, 20 } } },
	},
	Batty = {
		tint = { color = { 60, 40, 70 }, mix = 0.2 },
		extras = { { anchor = "orbit", speed = 0.4, parts = bats("Bat", 3) } },
	},
	Mummy = {
		tint = { color = Bandage, mix = 0.55 },
		wrap = { colors = { Bandage } },
		glow = { 140, 255, 110 },
		auras = { { kind = "Mist", color = { 200, 190, 150 } } },
	},

	-- Food effects.
	PumpkinHead = {
		pumpkin = true,
		auras = { { kind = "Sparkle", color = Flame } },
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
						size = { 0.08, 2.2, 2.2 },
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
		auras = {
			{ kind = "Mist", color = { 110, 30, 140 } },
			{ kind = "Sparkle", color = { 255, 60, 200 } },
		},
	},

	-- Catch effects.
	Ghost = {
		seeThrough = 0.55,
		tint = { color = { 220, 235, 255 }, mix = 0.5 },
		glow = { 150, 220, 255 },
		auras = { { kind = "Mist", color = { 210, 230, 255 } } },
	},
	Werewolf = {
		tint = { color = Fur, mix = 0.6 },
		fur = { { 95, 66, 44 }, { 135, 100, 70 } },
		glow = { 255, 210, 60 },
	},

	-- Event effects: what an event leaves on a monster.
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
						at = { 0, 0.5, 0 },
						angle = 0,
						color = { 120, 40, 40 },
						rot = { 20, 0, 15 },
					},
					{
						name = "Pages",
						size = { 0.45, 0.1, 0.65 },
						at = { 0, 0.6, 0 },
						angle = 0,
						color = Bone,
						rot = { 20, 0, 15 },
					},
					{
						name = "Plate",
						size = { 0.08, 0.7, 0.7 },
						at = { 0, 0, 0 },
						angle = 120,
						color = Bone,
						shape = "Cylinder",
						rot = { 0, 0, 70 },
					},
					{
						name = "Candle",
						size = { 0.2, 0.5, 0.2 },
						at = { 0, -0.3, 0 },
						angle = 240,
						color = Bone,
					},
					{
						name = "CandleFlame",
						size = { 0.12, 0.2, 0.12 },
						at = { 0, 0.05, 0 },
						angle = 240,
						color = Flame,
						glow = true,
					},
				},
			},
		},
		auras = { { kind = "Mist", color = { 170, 210, 255 } } },
	},
	Frostbitten = {
		-- Pale icy skin under a thin frosted crust, with frost sparkling off it.
		tint = { color = { 190, 225, 255 }, mix = 0.55 },
		glow = { 150, 235, 255 },
		shell = { color = { 220, 245, 255 }, transparency = 0.6, material = "Ice" },
		auras = {
			{ kind = "Sparkle", color = { 215, 245, 255 } },
			{ kind = "Mist", color = { 200, 235, 255 } },
		},
	},
	Sugarcoated = {
		-- A glossy pink candy shell with sprinkles glinting on it.
		tint = { color = { 255, 170, 210 }, mix = 0.3 },
		shell = { color = { 255, 150, 200 }, transparency = 0.45, material = "Glass" },
		auras = {
			{ kind = "Sparkle", color = { 255, 120, 190 } },
			{ kind = "Sparkle", color = { 140, 230, 255 } },
			{ kind = "Sparkle", color = { 255, 240, 120 } },
		},
	},
	Gilded = {
		-- Thin gold veins cracking through a darkened skin (not the all-over foil of a Gold
		-- catch variant, nor the thick gold straps of a Mimic).
		tint = { color = { 70, 52, 30 }, mix = 0.35 },
		wrap = { colors = { Gold, { 230, 170, 20 } }, thickness = 0.05, material = "Foil" },
		glow = Gold,
		auras = { { kind = "Sparkle", color = Gold } },
	},
	Harvested = {
		-- Straw-coloured skin bound with bands of dry corn husk, leaves drifting off it.
		tint = { color = { 200, 160, 70 }, mix = 0.4 },
		wrap = { colors = { { 185, 145, 65 }, { 150, 110, 40 } }, thickness = 0.08, material = "Fabric" },
		auras = { { kind = "Sparkle", color = { 240, 150, 50 } } },
	},
	Skeletal = {
		-- Turned to old bone: pale and a little see-through, ribs showing, green grave-glow.
		tint = { color = { 235, 228, 205 }, mix = 0.7 },
		seeThrough = 0.15,
		wrap = { colors = { { 245, 240, 225 } }, thickness = 0.06 },
		glow = { 170, 255, 170 },
		auras = { { kind = "Mist", color = { 200, 230, 190 } } },
	},
	Bewitched = {
		-- A witch's curse: dusky purple skin, green eyes, a curl of green cauldron smoke.
		tint = { color = { 90, 40, 120 }, mix = 0.35 },
		glow = { 120, 255, 120 },
		auras = {
			{ kind = "Mist", color = { 120, 255, 140 } },
			{ kind = "Sparkle", color = { 190, 120, 255 } },
		},
	},
	Bloodmoon = {
		tint = { color = { 150, 20, 30 }, mix = 0.45 },
		glow = { 255, 40, 40 },
		auras = { { kind = "Mist", color = { 200, 20, 30 } }, { kind = "Sparkle", color = { 255, 40, 40 } } },
	},
	Rifted = {
		-- Torn by a rift: a darkened body with thin cracks of blue-white light running through it.
		tint = { color = { 35, 30, 70 }, mix = 0.4 },
		wrap = { colors = { { 150, 190, 255 }, { 230, 240, 255 } }, thickness = 0.04, material = "Glass" },
		glow = { 140, 180, 255 },
		auras = { { kind = "Sparkle", color = { 170, 200, 255 } } },
	},
	Mimic = {
		tint = { color = { 120, 78, 40 }, mix = 0.5 },
		wrap = { colors = { Gold }, thickness = 0.18, material = "Metal" },
		glow = Gold,
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
		wrap = { colors = { { 30, 24, 28 } }, thickness = 0.07, stitches = true },
		glow = { 140, 255, 120 },
	},
	Hexed = {
		tint = { color = { 60, 110, 60 }, mix = 0.35 },
		glow = { 120, 255, 90 },
		auras = {
			{ kind = "Sparkle", color = { 120, 255, 90 } },
			{ kind = "Mist", color = { 120, 50, 170 } },
		},
	},
	Eclipsed = {
		tint = { color = { 12, 10, 16 }, mix = 0.85 },
		shell = { color = { 255, 40, 30 }, transparency = 0.7, glow = true },
		glow = { 255, 120, 40 },
	},

	-- Critter effects (only on cheap monsters).
	Glowbug = {
		-- Fireflies circling it, and a warm green-yellow glow.
		glow = { 220, 255, 90 },
		extras = {
			{
				anchor = "orbit",
				speed = 0.6,
				parts = {
					{
						name = "Firefly1",
						size = { 0.2, 0.2, 0.2 },
						at = { 0, 0.5, 0 },
						angle = 0,
						color = { 220, 255, 90 },
						glow = true,
						shape = "Ball",
					},
					{
						name = "Firefly2",
						size = { 0.2, 0.2, 0.2 },
						at = { 0, -0.1, 0 },
						angle = 120,
						color = { 220, 255, 90 },
						glow = true,
						shape = "Ball",
					},
					{
						name = "Firefly3",
						size = { 0.2, 0.2, 0.2 },
						at = { 0, 0.2, 0 },
						angle = 240,
						color = { 220, 255, 90 },
						glow = true,
						shape = "Ball",
					},
				},
			},
		},
		auras = { { kind = "Sparkle", color = { 220, 255, 90 } } },
	},
	Moldy = {
		-- Grey-green and fuzzy, shedding spores.
		tint = { color = { 120, 140, 100 }, mix = 0.45 },
		shell = { color = { 150, 180, 120 }, transparency = 0.6, material = "Fabric" },
		auras = { { kind = "Mist", color = { 150, 180, 120 } } },
	},
	Rusty = {
		-- Orange-brown corroded metal.
		tint = { color = { 160, 80, 40 }, mix = 0.6 },
		material = { name = "CorrodedMetal" },
		auras = { { kind = "Drip", color = { 150, 70, 30 } } },
	},
	Fungal = {
		-- Red and white mushroom caps sprouting from its skin, puffing spores.
		tint = { color = { 90, 75, 60 }, mix = 0.3 },
		fur = { { 210, 50, 45 }, { 240, 232, 214 } },
		auras = { { kind = "Sparkle", color = { 200, 255, 150 } } },
	},
	RatKing = {
		-- A royal purple skin with golden eyes and a glint of gold.
		tint = { color = { 80, 50, 110 }, mix = 0.4 },
		glow = Gold,
		auras = { { kind = "Sparkle", color = Gold }, { kind = "Mist", color = { 120, 110, 110 } } },
	},

	-- Round 3 cake effects.
	Buried = {
		-- Grave-grey skin with soil caked on from the feet up and pale green eyes.
		tint = { color = { 150, 145, 130 }, mix = 0.35 },
		fade = { color = { 70, 52, 35 }, mix = 0.85 },
		glow = { 180, 255, 170 },
		auras = { { kind = "Mist", color = { 110, 85, 60 } } },
	},
	Spectral = {
		-- Half see-through, with a cold teal glow round every part.
		seeThrough = 0.4,
		tint = { color = { 170, 255, 230 }, mix = 0.5 },
		shell = { color = { 120, 255, 220 }, transparency = 0.75, glow = true },
		glow = { 120, 255, 220 },
		auras = {
			{ kind = "Mist", color = { 150, 255, 230 } },
			{ kind = "Sparkle", color = { 200, 255, 245 } },
		},
	},
	Voidtouched = {
		-- Pitch black under a purple void glow.
		tint = { color = { 12, 4, 22 }, mix = 0.9 },
		shell = { color = { 140, 50, 255 }, transparency = 0.6, glow = true },
		glow = { 210, 130, 255 },
		auras = {
			{ kind = "Mist", color = { 90, 20, 160 } },
			{ kind = "Sparkle", color = { 210, 130, 255 } },
		},
	},

	-- Combos: both effects' looks plus a finishing touch.
	Count = {
		includes = { "Vampire", "Batty" },
		auras = { { kind = "Sparkle", color = { 255, 40, 50 } } },
	},
	Banshee = {
		includes = { "Cursed", "Ghost" },
		glow = { 190, 240, 255 },
		auras = { { kind = "Mist", color = { 230, 240, 255 } } },
	},
	Pharaoh = {
		tint = { color = Bandage, mix = 0.55 },
		wrap = { colors = { Gold, { 40, 70, 170 } }, material = "Metal" },
		glow = Gold,
		auras = { { kind = "Sparkle", color = Gold }, { kind = "Mist", color = { 200, 190, 150 } } },
	},
	Alpha = {
		includes = { "Werewolf", "Bloodmoon" },
		glow = { 255, 30, 30 },
		tint = { color = { 90, 20, 25 }, mix = 0.3 },
	},

	-- Catch variants.
	Silver = {
		tint = { color = { 200, 205, 215 }, mix = 0.75 },
		material = { name = "Metal", reflectance = 0.1 },
		auras = { { kind = "Sparkle", color = { 230, 235, 255 } } },
	},
	Gold = {
		tint = { color = Gold, mix = 0.92 },
		material = { name = "Foil", reflectance = 0.1 },
		auras = { { kind = "Sparkle", color = { 255, 230, 120 } } },
	},
	Shiny = {
		hueShift = 0.45,
		material = { name = "Foil", reflectance = 0.12 },
		auras = { { kind = "Sparkle", color = { 255, 255, 255 } } },
	},
	Rainbow = {
		rainbow = true,
		material = { name = "SmoothPlastic", reflectance = 0.05 },
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

-- A colour from hue, saturation and value (all 0..1), as 0..255 numbers.
function EffectLooks.fromHsv(h: number, s: number, v: number): { number }
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
local fromHsv = EffectLooks.fromHsv

-- The box round a look's pieces (rotations ignored).
local function bounds(pieces: { Piece }): ({ number }, { number })
	local min, max = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, piece in pieces do
		for axis = 1, 3 do
			min[axis] = math.min(min[axis], piece.at[axis] - piece.size[axis] / 2)
			max[axis] = math.max(max[axis], piece.at[axis] + piece.size[axis] / 2)
		end
	end
	return min, max
end

local function volume(piece: Piece): number
	return piece.size[1] * piece.size[2] * piece.size[3]
end

-- The biggest non-glowing parts, biggest first.
local function biggest(pieces: { Piece }, count: number): { Piece }
	local list: { Piece } = {}
	for _, piece in pieces do
		if not piece.glow then
			table.insert(list, piece)
		end
	end
	table.sort(list, function(a, b)
		return volume(a) > volume(b)
	end)
	return { table.unpack(list, 1, math.min(count, #list)) }
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

-- Turns a vector by a part's rotation (degrees, applied like CFrame.fromOrientation).
local function rotate(rot: { number }?, v: { number }): { number }
	if not rot then
		return v
	end
	local rx, ry, rz = math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])
	local x, y, z = v[1], v[2], v[3]
	x, y = x * math.cos(rz) - y * math.sin(rz), x * math.sin(rz) + y * math.cos(rz)
	y, z = y * math.cos(rx) - z * math.sin(rx), y * math.sin(rx) + z * math.cos(rx)
	x, z = x * math.cos(ry) + z * math.sin(ry), -x * math.sin(ry) + z * math.cos(ry)
	return { x, y, z }
end

-- A part stuck onto `piece`, `offset` studs from its centre in the piece's own directions. It
-- shares the piece's tilt and joint (with the pivot moved to match), so it swings along.
local function attach(
	piece: Piece,
	name: string,
	size: { number },
	color: { number },
	offset: { number }
): Piece
	local turned = rotate(piece.rot, offset)
	local part: Piece = {
		name = name,
		size = size,
		at = { piece.at[1] + turned[1], piece.at[2] + turned[2], piece.at[3] + turned[3] },
		color = color,
		shape = piece.shape,
		rot = piece.rot,
	}
	if piece.joint then
		local joint = table.clone(piece.joint)
		local pivot = joint.pivot or { 0, 0, 0 }
		joint.pivot = { pivot[1] - offset[1], pivot[2] - offset[2], pivot[3] - offset[3] }
		part.joint = joint
	end
	return part
end

local function recolor(pieces: { Piece }, style: Style)
	local min, max = bounds(pieces)
	local height = math.max(max[2] - min[2], 0.01)
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
		if style.fade then
			local up = (piece.at[2] - min[2]) / height
			piece.color =
				mixColor(piece.color, style.fade.color, style.fade.mix * math.clamp(1 - up * 1.4, 0, 1))
		end
		if style.patchwork then
			local toward = if i % 2 == 0 then { 150, 190, 130 } else { 95, 70, 60 }
			piece.color = mixColor(piece.color, toward, style.patchwork)
		end
		if style.hueShift then
			local h, s, v = toHsv(piece.color)
			piece.color = fromHsv((h + style.hueShift) % 1, math.max(s, 0.45), math.max(v, 0.45))
		end
		if style.rainbow then
			piece.rainbow = (piece.at[2] - min[2]) / height * 0.85
			piece.color = fromHsv(piece.rainbow :: number, 0.75, 1)
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

-- The head: a part called Head or Skull, or else the biggest part near the top (a ghost or a
-- blob is all head).
local function findHead(pieces: { Piece }): Piece?
	for _, piece in pieces do
		if (piece.name == "Head" or piece.name == "Skull") and not piece.glow then
			return piece
		end
	end
	local min, max = bounds(pieces)
	local best: Piece? = nil
	for _, piece in pieces do
		local top = piece.at[2] + piece.size[2] / 2
		if not piece.glow and top >= min[2] + (max[2] - min[2]) * 0.6 then
			if not best or volume(piece) > volume(best) then
				best = piece
			end
		end
	end
	return best
end

-- Turns the head into a carved pumpkin: orange, ribbed, a stem on top, and everything on its
-- face (eyes, mouth, nose) glowing like candle light or carved dark.
local function pumpkin(pieces: { Piece }, prefix: string): { Piece }
	local head = findHead(pieces)
	if not head then
		return {}
	end
	local s = head.size
	for _, piece in pieces do
		if piece ~= head then
			local inside = true
			for axis = 1, 3 do
				if math.abs(piece.at[axis] - head.at[axis]) > s[axis] / 2 + 0.35 then
					inside = false
				end
			end
			if inside and volume(piece) < volume(head) * 0.3 then
				piece.color = if piece.glow then Flame else { 120, 45, 10 }
			end
		end
	end
	head.color = Orange
	head.material = nil
	head.reflectance = nil
	local k = math.clamp(math.min(s[1], s[3]) / 1.6, 0.4, 2.5)
	local rib = attach(
		head,
		prefix .. "Rib",
		{ s[1] * 0.34, s[2] + 0.04, s[3] + 0.04 },
		{ 220, 100, 20 },
		{ 0, 0, 0 }
	)
	local stem = attach(head, prefix .. "Stem", { 0.28 * k, 0.45 * k, 0.28 * k }, { 70, 140, 50 }, {
		0,
		s[2] / 2 + 0.2 * k,
		0,
	})
	return { rib, stem }
end

local function coverings(pieces: { Piece }, style: Style, prefix: string): { Piece }
	local added = {}
	for _, piece in pieces do
		if piece.glow then
			continue
		end
		local s = piece.size
		if style.shell then
			local shell = attach(
				piece,
				`{prefix}Shell{piece.name}`,
				{ s[1] + 0.12, s[2] + 0.12, s[3] + 0.12 },
				style.shell.color,
				{ 0, 0, 0 }
			)
			shell.transparency = style.shell.transparency
			shell.material = style.shell.material
			shell.glow = style.shell.glow
			table.insert(added, shell)
		end
	end
	if style.wrap then
		-- Bands round the middle of each part (two on long parts), along its height.
		local wrap = style.wrap
		local n = 0
		local list = if wrap.stitches then biggest(pieces, 8) else pieces
		for _, piece in list do
			local s = piece.size
			if piece.glow or s[2] < 0.4 then
				continue
			end
			local bands = if s[2] >= 1.2 and not wrap.stitches then 2 else 1
			for b = 1, bands do
				n += 1
				local offset = if bands == 1 then 0 else (b - 1.5) * s[2] * 0.45
				local thickness = wrap.thickness or math.min(0.3, s[2] * 0.3)
				local band = attach(
					piece,
					`{prefix}Band{piece.name}{b}`,
					{ s[1] + 0.1, thickness, s[3] + 0.1 },
					wrap.colors[(n - 1) % #wrap.colors + 1],
					{ 0, offset, 0 }
				)
				band.material = wrap.material or "Fabric"
				table.insert(added, band)
			end
			-- Stitches: short ticks across the seam on the front.
			if wrap.stitches and s[1] >= 0.8 then
				for t = -1, 1 do
					local tick = attach(
						piece,
						`{prefix}Tick{piece.name}{t + 2}`,
						{ 0.07, 0.32, 0.06 },
						wrap.colors[1],
						{ t * s[1] * 0.28, 0, -(s[3] / 2 + 0.04) }
					)
					table.insert(added, tick)
				end
			end
		end
	end
	if style.fur then
		-- Tufts on the top and the sides of the biggest parts, light and dark.
		local n = 0
		for _, piece in biggest(pieces, 10) do
			local s = piece.size
			if math.min(s[1], s[3]) < 0.5 or s[2] < 0.4 then
				continue
			end
			local spots = {
				{ -s[1] * 0.25, s[2] / 2 + 0.05, -s[3] * 0.2 },
				{ s[1] * 0.25, s[2] / 2 + 0.05, s[3] * 0.2 },
				{ -(s[1] / 2 + 0.05), s[2] * 0.15, 0 },
				{ s[1] / 2 + 0.05, -s[2] * 0.1, 0 },
			}
			for i, spot in spots do
				n += 1
				local tuft = attach(
					piece,
					`{prefix}Tuft{piece.name}{i}`,
					{ 0.4, 0.32, 0.4 },
					style.fur[n % #style.fur + 1],
					spot
				)
				table.insert(added, tuft)
			end
		end
	end
	return added
end

local function extent(group: Group, axis: number): number
	local reach = 0
	for _, part in group.parts do
		reach = math.max(reach, part.at[axis] + part.size[axis] / 2)
	end
	return reach
end

-- Places a style's extras on the look. `stack` remembers how far each anchor has been used
-- so later groups sit above (or outside) earlier ones instead of inside them.
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
	local body = math.clamp(math.max(width, depth) / 3, 0.6, 3)
	local middle = { (min[1] + max[1]) / 2, (min[2] + max[2]) / 2, (min[3] + max[3]) / 2 }
	for _, group in groups do
		if group.anchor == "orbit" then
			local reach = stack.orbit or (math.max(width, depth) / 2 + 1)
			stack.orbit = reach + 1.4
			for _, part in group.parts do
				-- On the ring at `angle`, turned so the part's X points out from the middle.
				local angle = math.rad(part.angle or 0)
				local offset = rotate({ 0, -(part.angle or 0), 0 }, part.at)
				local at = {
					middle[1] + math.cos(angle) * reach + offset[1],
					middle[2] + offset[2],
					middle[3] + math.sin(angle) * reach + offset[3],
				}
				local rot = part.rot or { 0, 0, 0 }
				table.insert(pieces, {
					name = `{prefix}{part.name}`,
					size = part.size,
					at = at,
					color = part.color,
					shape = part.shape,
					glow = part.glow,
					rot = { rot[1], rot[2] - (part.angle or 0), rot[3] },
					material = part.material,
					transparency = part.transparency,
					joint = {
						axis = "Y" :: "Y",
						amp = 0,
						speed = group.speed or 0.3,
						spin = true,
						around = middle,
					},
				})
			end
			continue
		end
		local k = if group.anchor == "head" then head else body
		local origin: { number }
		if group.anchor == "head" then
			local y = stack.head or max[2]
			stack.head = y + extent(group, 2) * k
			origin = { (hx0 + hx1) / 2, y, (hz0 + hz1) / 2 }
		else
			origin = { middle[1], min[2], middle[3] }
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

	-- Name what a style adds after the style, so names never clash.
	local names: { [Style]: string } = {}
	for id, style in EffectLooks.Styles do
		names[style] = id
	end

	local base: { Piece } = {}
	for _, piece in look.pieces do
		local copy = table.clone(piece) :: Piece
		if look.seeThrough and not piece.glow then
			copy.transparency = look.seeThrough -- per piece now; the look-wide one is dropped
		end
		table.insert(base, copy)
	end
	local effectStyles = table.clone(styles)
	if variantStyle then
		table.remove(effectStyles)
	end
	-- Effects change the monster first: its colours, then what sits on its parts.
	local pieces: { Piece } = table.clone(base)
	for _, style in effectStyles do
		recolor(base, style)
		if style.pumpkin then
			for _, piece in pumpkin(base, names[style]) do
				table.insert(pieces, piece)
			end
		end
	end
	for _, style in effectStyles do
		for _, piece in coverings(base, style, names[style]) do
			table.insert(pieces, piece)
		end
	end
	-- The variant last, over everything on the monster (see-through skins keep their colour).
	if variantStyle then
		local solid = {}
		for _, piece in pieces do
			if piece.transparency == nil or piece.transparency < 0.5 then
				table.insert(solid, piece)
			end
		end
		recolor(solid, variantStyle)
	end
	local stack: { [string]: number } = {}
	local auras: { Aura } = {}
	for _, style in styles do
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
	dressed.seeThrough = nil
	return dressed
end

return EffectLooks
