--!strict
-- Weight and Titans. Every monster in a mansion has a weight in kg that keeps growing, also
-- while its owner is offline (Storage pauses it). Its size follows its weight: a Normal
-- monster that gets heavy enough turns Big, then Huge, then Colossal, and past Colossal it
-- becomes a Titan that is too big for the mansion and clips through its walls and roof.
-- Effects make it grow faster, so cakes speed it up through the effects they give.
-- Placeholders, tune in playtesting.

local Weight = {}

-- The weight (kg) a monster needs to be drawn at that size. A caught monster gets a random
-- weight between its size's start and the next one's.
Weight.StartKg = {
	Tiny = 5,
	Small = 10,
	Normal = 20,
	Big = 40,
	Huge = 80,
	Colossal = 160,
	Titan = 320,
}
Weight.MaxKg = 2560 -- a Titan stops growing here (8 times its starting weight)

-- How fast a monster grows: this share of its own weight per hour (0.01 = +1% an hour, so it
-- doubles, and goes up one size, in about 3 days). Each effect it has adds GrowthPerEffect
-- (3 effects: +4% an hour, a size every 17 hours or so).
Weight.GrowthPerHour = 0.01
Weight.GrowthPerEffect = 0.01

-- Titans: worth Sizes' Titan multiplier (x10) when they turn Titan, rising to TitanMaxValue at
-- MaxKg, and drawn from TitanStartScale up to TitanMaxScale (capped so phones keep up).
-- The drawn size goes up in steps of TitanScaleStep, so the model is only rebuilt now and then.
Weight.TitanMaxValue = 20
Weight.TitanStartScale = 3.5
Weight.TitanMaxScale = 6
Weight.TitanScaleStep = 0.5

-- However big a monster is drawn, it walks the mansion floors as if it were this wide
-- (radius in studs, Colossal's), so a Titan still fits through the rooms and pokes through
-- the walls instead of getting stuck.
Weight.MaxRoamRadius = 3.75

Weight.GrowthTickSeconds = 60 -- how often the mansion catches up on growth while you play

return Weight
