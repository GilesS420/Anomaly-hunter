--!strict
-- Size rolled on catch. Multiplies sell value; big sizes need a better vacuum to catch.

export type Size = {
	id: string,
	weight: number,
	valueMultiplier: number,
	vacuumTier: number, -- minimum vacuum tier (see Shop.luau)
}

local Sizes: { Size } = {
	{ id = "Tiny", weight = 15, valueMultiplier = 0.5, vacuumTier = 1 },
	{ id = "Small", weight = 30, valueMultiplier = 0.8, vacuumTier = 1 },
	{ id = "Normal", weight = 35, valueMultiplier = 1, vacuumTier = 1 },
	{ id = "Big", weight = 15, valueMultiplier = 1.5, vacuumTier = 2 },
	{ id = "Huge", weight = 4, valueMultiplier = 2.5, vacuumTier = 2 },
	{ id = "Colossal", weight = 1, valueMultiplier = 5, vacuumTier = 3 },
}

return Sizes
