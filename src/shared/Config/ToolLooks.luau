--!strict
-- What the hand-held tools look like: the six vacuums, the Bait Bells, the Return Charm and
-- the Name Tag (only a picture in the shop and Backpack: it is never held).
-- Part data in the same format as Config/Rooms, in Tool-local studs: the hand grips the
-- origin (the part named "Handle"), +Y is up and the business end points along -Z.
-- Pure data so the preview page can draw the same models.

local Rooms = require("./Rooms")

type Part = Rooms.Part
type Light = Rooms.Light

local ToolLooks = {}

local function part(
	parts: { Part },
	name: string,
	size: { number },
	at: { number },
	color: { number },
	material: string
): Part
	local p: Part = { name = name, size = size, at = at, color = color, material = material }
	table.insert(parts, p)
	return p
end

local function glow(color: { number }): Light
	return { color = color, range = 8, brightness = 1 }
end

-- A vacuum's colours. `wisp` glows inside the glass tank (nil for a cloth dust bag).
type Theme = {
	body: { number },
	bodyMaterial: string,
	trim: { number },
	trimMaterial: string,
	grip: { number },
	tank: { number },
	tankMaterial: string,
	wisp: { number }?,
	tip: { number }?, -- the glowing mouth (nil when the vacuum builds its own)
}

-- The shared shape: a pistol grip, a boxy body on top of it, a tank on the body, a neck and
-- a wide nozzle in front (unless the theme has no `tip`: that vacuum builds its own mouth), a
-- vent at the back and a stripe down each side.
local function vacuum(theme: Theme): { Part }
	local parts: { Part } = {}
	part(parts, "Handle", { 0.45, 1.3, 0.55 }, { 0, 0, 0 }, theme.grip, "Fabric")
	part(parts, "Trigger", { 0.2, 0.35, 0.25 }, { 0, 0.35, -0.4 }, theme.trim, theme.trimMaterial)
	part(parts, "Body", { 1.3, 1.2, 2.6 }, { 0, 1.25, -0.7 }, theme.body, theme.bodyMaterial)
	local tank = part(parts, "Tank", { 1, 0.7, 1.6 }, { 0, 2.2, -0.5 }, theme.tank, theme.tankMaterial)
	if theme.wisp then
		tank.transparency = 0.45
		local wisp = part(parts, "TankWisp", { 0.5, 0.4, 0.8 }, { 0, 2.2, -0.5 }, theme.wisp, "Neon")
		wisp.light = glow(theme.wisp)
	end
	for i, side in { -1, 1 } do
		part(
			parts,
			`Stripe{i}`,
			{ 0.1, 0.3, 2.6 },
			{ side * 0.7, 1.25, -0.7 },
			theme.trim,
			theme.trimMaterial
		)
	end
	part(parts, "Vent", { 1, 0.8, 0.2 }, { 0, 1.25, 0.7 }, theme.trim, theme.trimMaterial)
	part(parts, "Neck", { 0.6, 0.6, 1.4 }, { 0, 1.25, -2.7 }, theme.trim, theme.trimMaterial)
	if theme.tip then
		part(parts, "Nozzle", { 1.6, 0.9, 0.5 }, { 0, 1.25, -3.65 }, theme.body, theme.bodyMaterial)
		local tip = part(parts, "Tip", { 1.4, 0.7, 0.1 }, { 0, 1.25, -3.95 }, theme.tip, "Neon")
		tip.light = glow(theme.tip)
	end
	return parts
end

-- The starter vacuum: beige plastic with a cloth dust bag and a dim yellow mouth.
function ToolLooks.DustBuster(): { Part }
	return vacuum({
		body = { 176, 158, 122 },
		bodyMaterial = "SmoothPlastic",
		trim = { 84, 78, 70 },
		trimMaterial = "SmoothPlastic",
		grip = { 60, 56, 52 },
		tank = { 140, 120, 92 },
		tankMaterial = "Fabric",
		tip = { 255, 210, 120 },
	})
end

-- Ghostly white with silver, and a pale teal spirit swirling in its glass tank.
function ToolLooks.PhantomVac(): { Part }
	return vacuum({
		body = { 214, 226, 228 },
		bodyMaterial = "SmoothPlastic",
		trim = { 150, 156, 166 },
		trimMaterial = "Metal",
		grip = { 52, 60, 66 },
		tank = { 190, 240, 240 },
		tankMaterial = "Glass",
		wisp = { 110, 255, 230 },
		tip = { 140, 255, 235 },
	})
end

-- Old brass and copper with a pressure gauge on the side and a green spirit in the jar.
function ToolLooks.SpiritSiphon(): { Part }
	local parts = vacuum({
		body = { 176, 132, 58 },
		bodyMaterial = "Metal",
		trim = { 150, 82, 50 },
		trimMaterial = "Metal",
		grip = { 70, 44, 30 },
		tank = { 200, 240, 200 },
		tankMaterial = "Glass",
		wisp = { 120, 255, 120 },
		tip = { 150, 255, 140 },
	})
	-- The gauge sits on the right stripe: a cream dial with a red needle.
	part(parts, "Gauge", { 0.1, 0.6, 0.6 }, { 0.8, 1.25, -0.2 }, { 236, 228, 200 }, "SmoothPlastic")
	part(parts, "GaugeNeedle", { 0.05, 0.35, 0.08 }, { 0.875, 1.32, -0.2 }, { 200, 40, 40 }, "Neon")
	-- Copper pipes along the top of the body, either side of the jar.
	for i, side in { -1, 1 } do
		part(parts, `Pipe{i}`, { 0.15, 0.15, 2.2 }, { side * 0.575, 1.925, -0.7 }, { 150, 82, 50 }, "Metal")
	end
	return parts
end

-- Purple with a big flared horn for a mouth, rings glowing pink: it screams them in.
function ToolLooks.BansheeBlower(): { Part }
	local body, pink = { 92, 48, 130 }, { 255, 110, 200 }
	local parts = vacuum({
		body = body,
		bodyMaterial = "SmoothPlastic",
		trim = { 50, 30, 70 },
		trimMaterial = "Metal",
		grip = { 40, 26, 50 },
		tank = { 240, 200, 240 },
		tankMaterial = "Glass",
		wisp = pink,
	})
	part(parts, "Horn1", { 1.2, 1, 0.3 }, { 0, 1.25, -3.55 }, body, "SmoothPlastic")
	part(parts, "Horn2", { 1.8, 1.5, 0.3 }, { 0, 1.25, -3.85 }, body, "SmoothPlastic")
	part(parts, "Horn3", { 2.4, 2, 0.3 }, { 0, 1.25, -4.15 }, body, "SmoothPlastic")
	local tip = part(parts, "Tip", { 2.2, 1.8, 0.1 }, { 0, 1.25, -4.35 }, pink, "Neon")
	tip.light = glow(pink)
	return parts
end

-- Midnight blue and silver, a glowing moon in the tank and a crescent fin on top.
function ToolLooks.MoonVac(): { Part }
	local moon = { 255, 240, 170 }
	local parts = vacuum({
		body = { 34, 40, 86 },
		bodyMaterial = "SmoothPlastic",
		trim = { 196, 200, 214 },
		trimMaterial = "Metal",
		grip = { 24, 26, 44 },
		tank = { 220, 220, 255 },
		tankMaterial = "Glass",
		wisp = moon,
		tip = { 200, 220, 255 },
	})
	-- The crescent: three steps rising off the back of the tank and curling forward.
	part(parts, "FinLow", { 0.2, 0.4, 0.4 }, { 0, 2.75, -1.1 }, moon, "Neon")
	part(parts, "FinHigh", { 0.2, 0.4, 1 }, { 0, 3.15, -0.6 }, moon, "Neon")
	part(parts, "FinBack", { 0.2, 0.4, 0.4 }, { 0, 2.75, -0.1 }, moon, "Neon")
	return parts
end

-- Black with purple veins, spikes on the tank and a swirling void orb for a mouth (sunk a
-- little into the neck so it's held, not balanced on a point).
function ToolLooks.VoidVac(): { Part }
	local violet = { 170, 70, 255 }
	local parts = vacuum({
		body = { 22, 18, 30 },
		bodyMaterial = "SmoothPlastic",
		trim = violet,
		trimMaterial = "Neon",
		grip = { 14, 12, 20 },
		tank = { 60, 40, 90 },
		tankMaterial = "Glass",
		wisp = violet,
	})
	local orb = part(parts, "Orb", { 1.4, 1.4, 1.4 }, { 0, 1.25, -3.95 }, { 16, 10, 24 }, "Glass")
	orb.shape = "Ball"
	orb.transparency = 0.3
	local core = part(parts, "OrbCore", { 0.7, 0.7, 0.7 }, { 0, 1.25, -3.95 }, violet, "Neon")
	core.shape = "Ball"
	core.light = glow(violet)
	for i, z in { -1, -0.5, 0 } do
		part(parts, `Spike{i}`, { 0.2, 0.4, 0.2 }, { 0, 2.75, z }, { 30, 24, 40 }, "SmoothPlastic")
	end
	return parts
end

-- A hand bell in stepped rings, a wooden handle, a red bow and a glowing eye. Brass for the
-- Bait Bell; the Silver and Gold Bells are the same shape in their own metal.
local function bell(brass: { number }, rim: { number }, eyeColor: { number }): { Part }
	local parts: { Part } = {}
	part(parts, "Handle", { 0.4, 1.2, 0.4 }, { 0, 0, 0 }, { 92, 60, 40 }, "Wood")
	local knob = part(parts, "Knob", { 0.6, 0.6, 0.6 }, { 0, 0.9, 0 }, { 92, 60, 40 }, "Wood")
	knob.shape = "Ball"
	part(parts, "Collar", { 0.7, 0.25, 0.7 }, { 0, -0.725, 0 }, brass, "Metal")
	part(parts, "BellTop", { 1, 0.4, 1 }, { 0, -1.05, 0 }, brass, "Metal")
	part(parts, "BellMiddle", { 1.4, 0.5, 1.4 }, { 0, -1.5, 0 }, brass, "Metal")
	part(parts, "BellBottom", { 1.8, 0.4, 1.8 }, { 0, -1.95, 0 }, brass, "Metal")
	part(parts, "Rim", { 2, 0.15, 2 }, { 0, -2.225, 0 }, rim, "Metal")
	local clapper = part(parts, "Clapper", { 0.5, 0.5, 0.5 }, { 0, -2.55, 0 }, { 60, 56, 52 }, "Metal")
	clapper.shape = "Ball"
	for i, side in { -1, 1 } do
		part(parts, `Bow{i}`, { 0.3, 0.25, 0.1 }, { side * 0.2, -0.725, -0.4 }, { 180, 30, 40 }, "Fabric")
	end
	local eye = part(parts, "Eye", { 0.5, 0.25, 0.05 }, { 0, -1.5, -0.725 }, eyeColor, "Neon")
	eye.light = glow(eyeColor)
	return parts
end

function ToolLooks.BaitBell(): { Part }
	return bell({ 200, 160, 60 }, { 170, 130, 46 }, { 255, 90, 60 })
end

function ToolLooks.SilverBell(): { Part }
	return bell({ 205, 210, 225 }, { 160, 166, 182 }, { 120, 200, 255 })
end

function ToolLooks.GoldBell(): { Part }
	return bell({ 255, 200, 40 }, { 220, 160, 20 }, { 200, 90, 255 })
end

-- A teal crystal in a silver frame, hanging from a short chain held in the fist, with a dark
-- house rune on the crystal (it takes you home) and a tassel underneath.
function ToolLooks.ReturnCharm(): { Part }
	local parts: { Part } = {}
	local silver, teal = { 196, 200, 214 }, { 90, 240, 220 }
	part(parts, "Handle", { 0.15, 0.3, 0.15 }, { 0, 0, 0 }, silver, "Metal")
	part(parts, "Chain2", { 0.15, 0.3, 0.15 }, { 0, -0.3, 0 }, silver, "Metal")
	part(parts, "Chain3", { 0.15, 0.3, 0.15 }, { 0, -0.6, 0 }, silver, "Metal")
	part(parts, "FrameTop", { 0.6, 0.2, 0.2 }, { 0, -0.85, 0 }, silver, "Metal")
	for i, side in { -1, 1 } do
		part(parts, `FrameSide{i}`, { 0.2, 1, 0.2 }, { side * 0.4, -1.45, 0 }, silver, "Metal")
	end
	part(parts, "FrameBottom", { 0.6, 0.2, 0.2 }, { 0, -2.05, 0 }, silver, "Metal")
	local gem = part(parts, "Gem", { 0.6, 1, 0.3 }, { 0, -1.45, 0 }, teal, "Neon")
	gem.light = glow(teal)
	part(parts, "Rune", { 0.3, 0.3, 0.05 }, { 0, -1.45, -0.175 }, { 20, 50, 50 }, "SmoothPlastic")
	part(parts, "Tassel", { 0.15, 0.5, 0.15 }, { 0, -2.4, 0 }, teal, "Fabric")
	return parts
end

-- A cream paper luggage tag on a red string, held by the string, with a brass eyelet and two
-- ink lines where the name goes.
function ToolLooks.NameTag(): { Part }
	local parts: { Part } = {}
	local paper, ink = { 240, 226, 190 }, { 60, 40, 70 }
	part(parts, "Handle", { 0.15, 0.4, 0.15 }, { 0, 0, 0 }, { 200, 40, 50 }, "Fabric")
	part(parts, "String", { 0.1, 0.4, 0.1 }, { 0, -0.4, 0 }, { 200, 40, 50 }, "Fabric")
	part(parts, "Eyelet", { 0.3, 0.3, 0.12 }, { 0, -0.7, 0 }, { 220, 170, 60 }, "Metal")
	part(parts, "Card", { 1, 1.4, 0.06 }, { 0, -1.45, 0 }, paper, "SmoothPlastic")
	part(parts, "Line1", { 0.7, 0.08, 0.02 }, { 0, -1.35, -0.04 }, ink, "SmoothPlastic")
	part(parts, "Line2", { 0.5, 0.08, 0.02 }, { -0.1, -1.65, -0.04 }, ink, "SmoothPlastic")
	return parts
end

-- A round glass flask held by its neck: glowing liquid inside, a cork, a wax seal and a paper
-- label. `liquid` is the potion's colour, `seal` its wax.
local function potion(liquid: { number }, seal: { number }, sparkle: boolean): { Part }
	local parts: { Part } = {}
	part(parts, "Handle", { 0.4, 0.6, 0.4 }, { 0, 0, 0 }, { 200, 230, 240 }, "Glass").transparency = 0.4
	part(parts, "Cork", { 0.45, 0.35, 0.45 }, { 0, 0.45, 0 }, { 150, 110, 70 }, "Wood")
	part(parts, "Seal", { 0.55, 0.15, 0.55 }, { 0, 0.68, 0 }, seal, "SmoothPlastic")
	local flask = part(parts, "Flask", { 1.3, 1.3, 1.3 }, { 0, -0.9, 0 }, { 200, 230, 240 }, "Glass")
	flask.shape = "Ball"
	flask.transparency = 0.5
	local brew = part(parts, "Brew", { 1.05, 1.05, 1.05 }, { 0, -0.98, 0 }, liquid, "Neon")
	brew.shape = "Ball"
	brew.light = glow(liquid)
	part(parts, "Label", { 0.6, 0.4, 0.05 }, { 0, -0.85, -0.66 }, { 236, 222, 190 }, "SmoothPlastic")
	if sparkle then
		for i, at in { { 0.25, -0.7 }, { -0.2, -1.15 }, { 0.1, -1.3 } } do
			local fleck = part(
				parts,
				`Fleck{i}`,
				{ 0.12, 0.12, 0.12 },
				{ at[1], at[2], -0.3 },
				{ 255, 255, 255 },
				"Neon"
			)
			fleck.shape = "Ball"
		end
	end
	return parts
end

function ToolLooks.LuckyTonic(): { Part }
	return potion({ 90, 230, 120 }, { 40, 120, 60 }, false)
end

function ToolLooks.GildedElixir(): { Part }
	return potion({ 255, 200, 50 }, { 160, 110, 20 }, true)
end

function ToolLooks.PrismDraught(): { Part }
	return potion({ 200, 120, 255 }, { 90, 40, 140 }, true)
end

-- Recipes by Workshop item id.
ToolLooks.ById = {
	DustBuster = ToolLooks.DustBuster,
	PhantomVac = ToolLooks.PhantomVac,
	SpiritSiphon = ToolLooks.SpiritSiphon,
	BansheeBlower = ToolLooks.BansheeBlower,
	MoonVac = ToolLooks.MoonVac,
	VoidVac = ToolLooks.VoidVac,
	BaitBell = ToolLooks.BaitBell,
	SilverBell = ToolLooks.SilverBell,
	GoldBell = ToolLooks.GoldBell,
	ReturnCharm = ToolLooks.ReturnCharm,
	NameTag = ToolLooks.NameTag,
	LuckyTonic = ToolLooks.LuckyTonic,
	GildedElixir = ToolLooks.GildedElixir,
	PrismDraught = ToolLooks.PrismDraught,
} :: { [string]: () -> { Part } }

return ToolLooks
