--!strict
-- Catch variants: a colour a monster can get the moment it's caught, rolled by the vacuum
-- (Config/Tools, Vacuum.variants). A monster has at most one. It multiplies the whole sell
-- value and is separate from the effect slots. Rarest first; placeholders.

export type Variant = { id: string, multiplier: number }

local Variants: { Variant } = {
	{ id = "Rainbow", multiplier = 25 },
	{ id = "Shiny", multiplier = 10 },
	{ id = "Gold", multiplier = 5 },
	{ id = "Silver", multiplier = 2 },
}

return Variants
