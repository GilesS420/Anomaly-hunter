--!strict
-- Weight and Titans. Every monster in a mansion has a weight in kg, and its price follows its
-- weight: it's worth baseValue x kg / KgPerValue (a Normal monster weighs about 20 kg, so
-- that's about x1). Its size follows its weight too: Normal, Big, Huge, Colossal, and past
-- Colossal a Titan that is too big for the mansion and clips through its walls and roof.
-- There is no top weight, so the biggest monsters are the rarest.
--
-- Growing is luck, not a timer. A monster grows in sudden spurts, and only rolls for one once
-- its Familiarity is at 100%. Every monster also gets a hidden growth gene when it's caught:
-- some never grow, some stop at a certain size, and a lucky few can keep growing for ever.
-- Watcher events with a growthMultiplier (Config/Events) give extra spurt rolls while live.
-- Rolls keep happening while the owner is offline; Storage pauses them.
-- Placeholders, tune in playtesting.

local Weight = {}

Weight.KgPerValue = 20 -- value multiplier = kg / KgPerValue

-- The weight (kg) where each size starts. A caught monster gets its size's value multiplier
-- x KgPerValue in kg, give or take CatchSpread (a Normal one 18-22 kg, a Colossal 90-110 kg).
Weight.StartKg = {
	Tiny = 0,
	Small = 13,
	Normal = 18,
	Big = 25,
	Huge = 40,
	Colossal = 75,
	Titan = 500, -- worth x25 when it turns Titan, and it keeps going up from there
}
Weight.CatchSpread = 0.1

-- Hidden growth genes, rolled once per monster when it's caught (weights add up to 100).
-- maxSize is the biggest size it can grow to; nil means no limit.
export type Gene = { id: string, weight: number, maxSize: string? }
Weight.Genes = {
	{ id = "Stunted", weight = 30, maxSize = "None" }, -- never grows
	{ id = "Sturdy", weight = 45, maxSize = "Huge" },
	{ id = "Mighty", weight = 20, maxSize = "Colossal" },
	{ id = "Titanic", weight = 5 }, -- can become a Titan and never stops
} :: { Gene }

-- A fully familiar monster rolls SpurtChance percent every CheckMinutes (0.25% every 5 min is
-- about 3% an hour, so a spurt every day and a half or so). While a Watcher event with a
-- growthMultiplier is live, every monster (familiar or not) also rolls
-- EventSpurtChance x growthMultiplier percent every minute.
Weight.CheckMinutes = 5
Weight.SpurtChance = 0.25
Weight.EventSpurtChance = 3
Weight.MaxOfflineDays = 30 -- rolls owed for longer than this away are dropped

-- How much a spurt adds: between SpurtMin and SpurtMax of its weight, mostly small
-- (+5% to +60%; SpurtSkew 3 makes big spurts rare).
Weight.SpurtMin = 0.05
Weight.SpurtMax = 0.6
Weight.SpurtSkew = 3

-- Titans are drawn TitanStartScale big (Normal = 1) at 500 kg and grow with the square root of
-- their weight from there (4x the kg = 2x as big): 533 kg about 5.2, 1 t about 7, 2 t 10,
-- 5 t about 16, 20 t about 32. Every growth spurt shows. No limit (Giles 2026-10-30):
-- EngineMaxScale only keeps every block under Roblox's 2048-stud part limit (about 18,000 t).
Weight.TitanStartScale = 5
Weight.TitanScaleStep = 0.05 -- drawn sizes are rounded to this, so tiny gains don't rebuild it
Weight.EngineMaxScale = 300

-- However big a monster is drawn, it walks the mansion floors as if it were this wide
-- (radius in studs, Colossal's), so a Titan still fits through the rooms and pokes through
-- the walls instead of getting stuck.
Weight.MaxRoamRadius = 3.75

Weight.GrowthTickSeconds = 60 -- how often the mansion catches up on growth while you play

return Weight
