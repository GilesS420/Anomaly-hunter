--!strict
-- Little pictures drawn from plain frames, so they need no uploaded images: the HUD menu's
-- backpack, book, scroll, gear and notebook, the Daily Missions pictures (a cake, a vacuum, a
-- money bag, sparkles, a merge, a growth arrow, a map, a ghost, a chest, a die) and the Robux
-- Store's stand-ins for a pass with no picture on the dashboard yet (a crown, a clover, a
-- boot, a gift). Icons.draw(parent, kind) fills `parent` with one, kept square. Every piece
-- is sized and placed in scale, so the picture grows with its parent, and
-- none of them take clicks, so a button underneath still works.

local Icons = {}

export type Kind =
	"Backpack"
	| "Book"
	| "Scroll"
	| "Gear"
	| "Notebook"
	| "Coin"
	| "Cake"
	| "Vacuum"
	| "MoneyBag"
	| "Sparkle"
	| "Merge"
	| "Grow"
	| "Map"
	| "Ghost"
	| "Chest"
	| "Dice"
	| "Crown"
	| "Clover"
	| "Boot"
	| "Gift"
	| "Wheel"

local Ink = Color3.fromRGB(30, 20, 36) -- the dark outline round the mission and store pictures

-- One piece of a picture: centred on (x, y), w by h, all as a share of the parent.
local function piece(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	round: number?,
	rotation: number?
): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Rotation = rotation or 0
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = frame
	end
	frame.Parent = parent
	return frame
end

-- A dark outline round a piece, so the pictures read like stickers.
local function edge(frame: Frame, thickness: number?): Frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Ink
	stroke.Thickness = thickness or 2
	stroke.Parent = frame
	return frame
end

-- A bold letter or sign in a picture, sized with it.
local function glyph(parent: Instance, x: number, y: number, size: number, text: string, color: Color3)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(size, size)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = parent
end

-- A four-pointed twinkle: a turned square with a long and a wide bar through it.
local function twinkle(parent: Instance, x: number, y: number, size: number, color: Color3)
	piece(parent, x, y, size * 0.18, size, color, 0.5)
	piece(parent, x, y, size, size * 0.18, color, 0.5)
	piece(parent, x, y, size * 0.36, size * 0.36, color, 0.15, 45)
end

local draw: { [Kind]: (Frame) -> () } = {
	Backpack = function(box)
		local body = Color3.fromRGB(110, 150, 80)
		local dark = Color3.fromRGB(70, 105, 50)
		-- The carry loop on top: a ring with nothing inside.
		local loop = piece(box, 0.5, 0.17, 0.3, 0.22, body, 0.5)
		loop.BackgroundTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = dark
		stroke.Thickness = 3
		stroke.Parent = loop
		piece(box, 0.5, 0.58, 0.68, 0.72, body, 0.25)
		piece(box, 0.5, 0.36, 0.68, 0.3, dark, 0.35) -- the flap
		piece(box, 0.5, 0.48, 0.12, 0.12, Color3.fromRGB(240, 200, 80), 0.3) -- buckle
		piece(box, 0.5, 0.76, 0.4, 0.22, dark, 0.3) -- front pocket
	end,

	Book = function(box)
		piece(box, 0.53, 0.86, 0.62, 0.1, Color3.fromRGB(240, 230, 205), 0.2) -- page edges
		piece(box, 0.5, 0.46, 0.68, 0.8, Color3.fromRGB(150, 80, 45), 0.12) -- cover
		piece(box, 0.2, 0.46, 0.1, 0.8, Color3.fromRGB(95, 50, 28), 0.2) -- spine
		piece(box, 0.56, 0.34, 0.36, 0.14, Color3.fromRGB(240, 190, 80), 0.2) -- title plate
		piece(box, 0.7, 0.82, 0.08, 0.2, Color3.fromRGB(200, 50, 60)) -- ribbon
	end,

	Scroll = function(box)
		local paper = Color3.fromRGB(240, 220, 170)
		local roll = Color3.fromRGB(200, 165, 105)
		local ink = Color3.fromRGB(120, 85, 45)
		piece(box, 0.5, 0.5, 0.6, 0.7, paper)
		piece(box, 0.5, 0.16, 0.78, 0.14, roll, 0.5)
		piece(box, 0.5, 0.84, 0.78, 0.14, roll, 0.5)
		-- Three lines of a to-do list, the first one ticked off.
		for i, y in { 0.36, 0.5, 0.64 } do
			piece(box, 0.31, y, 0.08, 0.08, if i == 1 then Color3.fromRGB(80, 170, 80) else ink, 0.2)
			piece(box, 0.56, y, 0.34, 0.05, ink, 0.5)
		end
	end,

	Gear = function(box)
		local metal = Color3.fromRGB(200, 200, 215)
		-- Four bars crossing in the middle make the eight teeth.
		for _, angle in { 0, 45, 90, 135 } do
			piece(box, 0.5, 0.5, 0.2, 0.9, metal, 0.15, angle)
		end
		piece(box, 0.5, 0.5, 0.66, 0.66, metal, 0.5)
		piece(box, 0.5, 0.5, 0.26, 0.26, Color3.fromRGB(40, 40, 52), 0.5) -- the hole
	end,

	Coin = function(box)
		local gold = Color3.fromRGB(250, 205, 80)
		local dark = Color3.fromRGB(190, 135, 30)
		piece(box, 0.5, 0.5, 0.86, 0.86, dark, 0.5) -- the rim
		piece(box, 0.5, 0.5, 0.7, 0.7, gold, 0.5)
		-- A hexagon in the middle, like the Robux sign: three bars turned 60 degrees apart.
		for _, angle in { 0, 60, 120 } do
			piece(box, 0.5, 0.5, 0.42, 0.24, dark, nil, angle)
		end
		piece(box, 0.5, 0.5, 0.16, 0.16, gold, 0.2, 45)
	end,

	-- A logbook: a lined page with spiral rings along the top.
	Notebook = function(box)
		piece(box, 0.5, 0.55, 0.7, 0.82, Color3.fromRGB(245, 238, 220), 0.1)
		piece(box, 0.27, 0.6, 0.03, 0.66, Color3.fromRGB(220, 80, 80)) -- margin
		for _, y in { 0.4, 0.52, 0.64, 0.76 } do
			piece(box, 0.55, y, 0.44, 0.045, Color3.fromRGB(90, 130, 200), 0.5)
		end
		for _, x in { 0.3, 0.43, 0.57, 0.7 } do
			piece(box, x, 0.15, 0.07, 0.2, Color3.fromRGB(70, 70, 85), 0.5)
		end
	end,
	-- Daily Missions: what each kind of mission asks for (MissionController).

	Cake = function(box)
		piece(box, 0.5, 0.9, 0.92, 0.08, Color3.fromRGB(232, 224, 244), 0.5) -- the plate
		edge(piece(box, 0.5, 0.7, 0.8, 0.3, Color3.fromRGB(140, 74, 44), 0.25)) -- sponge
		edge(piece(box, 0.5, 0.44, 0.66, 0.24, Color3.fromRGB(255, 143, 181), 0.3)) -- top layer
		for _, x in { 0.24, 0.4, 0.56, 0.72 } do -- icing dripping over the sponge
			piece(box, x, 0.58, 0.11, 0.11, Color3.fromRGB(255, 143, 181), 0.5)
		end
		piece(box, 0.5, 0.24, 0.07, 0.18, Color3.fromRGB(255, 244, 214), 0.4) -- candle
		piece(box, 0.5, 0.1, 0.1, 0.13, Color3.fromRGB(255, 176, 84), 0.5) -- flame
	end,

	Vacuum = function(box)
		edge(piece(box, 0.72, 0.56, 0.5, 0.12, Color3.fromRGB(207, 216, 234), 0.5, -28)) -- hose
		edge(piece(box, 0.9, 0.36, 0.16, 0.34, Color3.fromRGB(255, 211, 107), 0.25)) -- nozzle
		edge(piece(box, 0.36, 0.26, 0.24, 0.16, Color3.fromRGB(125, 138, 176), 0.3)) -- handle
		edge(piece(box, 0.36, 0.6, 0.56, 0.48, Color3.fromRGB(168, 196, 255), 0.35)) -- tank
		edge(piece(box, 0.36, 0.6, 0.24, 0.24, Color3.fromRGB(91, 140, 232), 0.5)) -- the swirl window
		piece(box, 0.31, 0.55, 0.07, 0.07, Color3.new(1, 1, 1), 0.5)
	end,

	MoneyBag = function(box)
		edge(piece(box, 0.5, 0.62, 0.78, 0.66, Color3.fromRGB(216, 176, 112), 0.5)) -- the bag
		edge(piece(box, 0.5, 0.25, 0.3, 0.14, Color3.fromRGB(201, 160, 96), 0.3)) -- the gathered top
		piece(box, 0.5, 0.33, 0.36, 0.06, Color3.fromRGB(110, 60, 30), 0.5) -- the string
		glyph(box, 0.5, 0.65, 0.42, "$", Color3.fromRGB(58, 120, 40))
	end,

	Sparkle = function(box)
		twinkle(box, 0.42, 0.56, 0.7, Color3.fromRGB(255, 226, 120))
		twinkle(box, 0.78, 0.22, 0.32, Color3.fromRGB(190, 160, 255))
		twinkle(box, 0.82, 0.8, 0.2, Color3.new(1, 1, 1))
	end,

	-- Two monsters becoming one: two blobs, a plus, and the bigger blob they make.
	Merge = function(box)
		edge(piece(box, 0.2, 0.3, 0.3, 0.3, Color3.fromRGB(111, 207, 142), 0.5))
		edge(piece(box, 0.2, 0.74, 0.3, 0.3, Color3.fromRGB(111, 168, 242), 0.5))
		piece(box, 0.44, 0.52, 0.16, 0.06, Color3.new(1, 1, 1), 0.5)
		piece(box, 0.5, 0.52, 0.06, 0.06, Color3.new(1, 1, 1), 0.5, 45)
		piece(box, 0.52, 0.44, 0.06, 0.16, Color3.new(1, 1, 1), 0.5, -45)
		piece(box, 0.52, 0.6, 0.06, 0.16, Color3.new(1, 1, 1), 0.5, 45)
		edge(piece(box, 0.76, 0.52, 0.42, 0.42, Color3.fromRGB(190, 140, 255), 0.5))
		piece(box, 0.7, 0.46, 0.07, 0.07, Ink, 0.5)
		piece(box, 0.83, 0.46, 0.07, 0.07, Ink, 0.5)
	end,

	-- The Growth Chamber: a small and a big monster with an arrow going up.
	Grow = function(box)
		edge(piece(box, 0.22, 0.78, 0.24, 0.24, Color3.fromRGB(111, 207, 142), 0.5))
		edge(piece(box, 0.7, 0.66, 0.48, 0.48, Color3.fromRGB(111, 207, 142), 0.5))
		piece(box, 0.63, 0.6, 0.07, 0.07, Ink, 0.5)
		piece(box, 0.78, 0.6, 0.07, 0.07, Ink, 0.5)
		local up = Color3.fromRGB(255, 211, 107)
		piece(box, 0.3, 0.38, 0.09, 0.4, up, 0.5)
		piece(box, 0.23, 0.24, 0.09, 0.24, up, 0.5, -45)
		piece(box, 0.37, 0.24, 0.09, 0.24, up, 0.5, 45)
	end,

	-- A zone map: a paper with a dotted trail to a red cross.
	Map = function(box)
		edge(piece(box, 0.5, 0.5, 0.84, 0.7, Color3.fromRGB(240, 220, 170), 0.12))
		for _, spot in { { 0.22, 0.68 }, { 0.32, 0.56 }, { 0.44, 0.62 }, { 0.54, 0.5 } } do
			piece(box, spot[1], spot[2], 0.06, 0.06, Color3.fromRGB(120, 85, 45), 0.5)
		end
		piece(box, 0.7, 0.38, 0.08, 0.28, Color3.fromRGB(210, 50, 60), 0.4, 45)
		piece(box, 0.7, 0.38, 0.08, 0.28, Color3.fromRGB(210, 50, 60), 0.4, -45)
	end,

	-- The Golden Ghost.
	Ghost = function(box)
		local gold = Color3.fromRGB(255, 211, 107)
		edge(piece(box, 0.5, 0.42, 0.62, 0.62, gold, 0.5))
		piece(box, 0.5, 0.62, 0.62, 0.36, gold)
		for _, x in { 0.29, 0.5, 0.71 } do -- the wavy hem
			piece(box, x, 0.8, 0.2, 0.2, gold, 0.5)
		end
		piece(box, 0.4, 0.4, 0.1, 0.15, Ink, 0.5)
		piece(box, 0.6, 0.4, 0.1, 0.15, Ink, 0.5)
		piece(box, 0.5, 0.56, 0.12, 0.08, Ink, 0.5)
	end,

	-- The bonus chest.
	Chest = function(box)
		local wood = Color3.fromRGB(150, 84, 36)
		local gold = Color3.fromRGB(255, 211, 107)
		edge(piece(box, 0.5, 0.36, 0.84, 0.34, Color3.fromRGB(168, 100, 44), 0.45)) -- the lid
		edge(piece(box, 0.5, 0.66, 0.84, 0.42, wood, 0.12)) -- the box
		edge(piece(box, 0.5, 0.46, 0.84, 0.08, gold), 1.5) -- the gold band
		edge(piece(box, 0.5, 0.56, 0.16, 0.2, gold, 0.2), 1.5) -- the lock
		piece(box, 0.5, 0.55, 0.05, 0.07, Ink, 0.5)
	end,

	Dice = function(box)
		edge(piece(box, 0.5, 0.5, 0.74, 0.74, Color3.fromRGB(245, 240, 255), 0.2))
		for _, spot in { { 0.32, 0.32 }, { 0.5, 0.5 }, { 0.68, 0.68 }, { 0.68, 0.32 }, { 0.32, 0.68 } } do
			piece(box, spot[1], spot[2], 0.13, 0.13, Color3.fromRGB(110, 80, 200), 0.5)
		end
	end,

	-- Robux Store stand-ins, for a pass whose dashboard picture hasn't loaded.

	Crown = function(box)
		local gold = Color3.fromRGB(255, 211, 107)
		for _, x in { 0.24, 0.5, 0.76 } do -- the three points
			edge(piece(box, x, 0.42, 0.24, 0.24, gold, 0.1, 45))
			edge(piece(box, x, 0.24, 0.12, 0.12, gold, 0.5))
		end
		edge(piece(box, 0.5, 0.58, 0.7, 0.24, gold, 0.1))
		edge(piece(box, 0.5, 0.74, 0.76, 0.12, Color3.fromRGB(230, 170, 60), 0.4))
		piece(box, 0.5, 0.58, 0.12, 0.12, Color3.fromRGB(176, 90, 255), 0.2, 45) -- the gem
	end,

	Clover = function(box)
		local green = Color3.fromRGB(80, 190, 100)
		piece(box, 0.62, 0.78, 0.07, 0.34, Color3.fromRGB(50, 130, 60), 0.5, -25) -- the stem
		for _, spot in { { 0.5, 0.28 }, { 0.5, 0.6 }, { 0.34, 0.44 }, { 0.66, 0.44 } } do
			edge(piece(box, spot[1], spot[2], 0.34, 0.34, green, 0.5))
		end
		piece(box, 0.5, 0.44, 0.16, 0.16, Color3.fromRGB(150, 230, 140), 0.5)
	end,

	-- A sneaker with speed lines behind it.
	Boot = function(box)
		local red = Color3.fromRGB(225, 80, 80)
		edge(piece(box, 0.52, 0.42, 0.3, 0.42, red, 0.25)) -- the ankle
		edge(piece(box, 0.62, 0.64, 0.62, 0.24, red, 0.4)) -- the foot
		piece(box, 0.62, 0.78, 0.66, 0.08, Color3.new(1, 1, 1), 0.5) -- the sole
		for i, y in { 0.36, 0.5, 0.64 } do
			piece(box, 0.16, y, 0.18 - i * 0.02, 0.05, Color3.fromRGB(190, 180, 210), 0.5)
		end
	end,

	Gift = function(box)
		local box1 = Color3.fromRGB(176, 110, 255)
		local ribbon = Color3.fromRGB(255, 211, 107)
		edge(piece(box, 0.5, 0.66, 0.7, 0.5, box1, 0.1))
		edge(piece(box, 0.5, 0.4, 0.8, 0.16, box1, 0.15))
		piece(box, 0.5, 0.6, 0.14, 0.62, ribbon)
		edge(piece(box, 0.38, 0.24, 0.2, 0.16, ribbon, 0.5, -20), 1.5) -- the bow
		edge(piece(box, 0.62, 0.24, 0.2, 0.16, ribbon, 0.5, 20), 1.5)
	end,

	-- The Lucky Spin: a prize wheel in four colours with a hub, and a red pointer on top.
	Wheel = function(box)
		local colors = {
			Color3.fromRGB(90, 170, 110),
			Color3.fromRGB(220, 120, 160),
			Color3.fromRGB(110, 150, 230),
			Color3.fromRGB(255, 211, 107),
		}
		edge(piece(box, 0.5, 0.55, 0.84, 0.84, Color3.fromRGB(60, 44, 80), 0.5))
		for i, spot in { { 0.36, 0.41 }, { 0.64, 0.41 }, { 0.64, 0.69 }, { 0.36, 0.69 } } do
			piece(box, spot[1], spot[2], 0.26, 0.26, colors[i], 0.5)
		end
		piece(box, 0.5, 0.55, 0.06, 0.76, Color3.fromRGB(60, 44, 80))
		piece(box, 0.5, 0.55, 0.76, 0.06, Color3.fromRGB(60, 44, 80))
		edge(piece(box, 0.5, 0.55, 0.18, 0.18, Color3.fromRGB(255, 240, 200), 0.5), 1.5)
		edge(piece(box, 0.5, 0.12, 0.16, 0.16, Color3.fromRGB(225, 70, 70), 0.15, 45), 1.5)
	end,
}

-- Draws a `kind` picture inside `parent`, `inset` (a share, default 0.15) away from its edges.
function Icons.draw(parent: GuiObject, kind: Kind, inset: number?): Frame
	local margin = inset or 0.15
	local box = Instance.new("Frame")
	box.Name = "Icon"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromScale(1 - margin * 2, 1 - margin * 2)
	box.BackgroundTransparency = 1
	box.ZIndex = parent.ZIndex
	local square = Instance.new("UIAspectRatioConstraint") -- stays square in a wide parent
	square.Parent = box
	draw[kind](box)
	box.Parent = parent
	return box
end

return Icons
