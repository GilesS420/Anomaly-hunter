--!strict
-- Size rolled on catch. Multiplies sell value; big sizes need a better vacuum to catch.

export type Size = {
	id: string,
	weight: number,
	valueMultiplier: number,
	vacuumTier: number, -- minimum vacuum tier (see Shop.luau)
	scale: number, -- how big the model is drawn
}

local Sizes: { Size } = {
	{ id = "Tiny", weight = 15, valueMultiplier = 0.5, vacuumTier = 1, scale = 0.6 },
	{ id = "Small", weight = 30, valueMultiplier = 0.8, vacuumTier = 1, scale = 0.8 },
	{ id = "Normal", weight = 35, valueMultiplier = 1, vacuumTier = 1, scale = 1 },
	{ id = "Big", weight = 15, valueMultiplier = 1.5, vacuumTier = 2, scale = 1.3 },
	{ id = "Huge", weight = 4, valueMultiplier = 2.5, vacuumTier = 2, scale = 1.7 },
	{ id = "Colossal", weight = 1, valueMultiplier = 5, vacuumTier = 3, scale = 2.5 },
}

return Sizes
