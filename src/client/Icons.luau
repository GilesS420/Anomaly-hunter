--!strict
-- Little pictures drawn from plain frames, so they need no uploaded images: a backpack, a
-- book, a scroll, a gear and a spiral notebook. Icons.draw(parent, kind) fills `parent` with
-- one, kept square. Every piece is sized and placed in scale, so the picture grows with its parent, and
-- none of them take clicks, so a button underneath still works.

local Icons = {}

export type Kind = "Backpack" | "Book" | "Scroll" | "Gear" | "Notebook" | "Coin"

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
