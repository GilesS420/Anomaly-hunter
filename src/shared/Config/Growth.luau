--!strict
-- The Growth Chamber, next to the Collector (Giles 2026-10-24). Put one monster from your
-- Backpack in, pick how hard to push it and pay the fee. It bubbles for its mode's seconds, then
-- the chamber shows how it went. A win makes it heavier (so bigger
-- and worth more); pushing harder wins more but fails more often, and a failed hard push
-- makes it shrink. Rules in Util/Growth.
--
-- Every monster can go in Charges times in its life, win or lose: weight has no top and price
-- follows weight, so without a limit the chamber would print money. The chamber ignores the
-- hidden growth gene (Config/Weight), so it can't give the gene away.
-- Placeholders, tune in playtesting.

export type Mode = {
	id: string,
	name: string,
	chance: number, -- percent to win
	win: number, -- its weight is multiplied by this on a win
	lose: number, -- and by this on a loss (1: nothing happens)
	feeShare: number, -- the fee: this share of its sell value
	seconds: number, -- how long it bubbles in the chamber (the clock keeps going offline)
}

local Growth = {}

Growth.Charges = 5

-- Mildest first (the order of the buttons). Giles 2026-10-28: bigger wins (Gentle +75%,
-- Strong +150%, Reckless +300%), and the bigger the growth the longer it bubbles, Reckless
-- the longest at 20 minutes. The monster stays in the chamber meanwhile.
Growth.Modes = {
	{ id = "Gentle", name = "Gentle", chance = 80, win = 1.75, lose = 1, feeShare = 0.08, seconds = 5 * 60 },
	{
		id = "Strong",
		name = "Strong",
		chance = 55,
		win = 2.5,
		lose = 0.9,
		feeShare = 0.15,
		seconds = 10 * 60,
	},
	{
		id = "Reckless",
		name = "Reckless",
		chance = 30,
		win = 4,
		lose = 0.75,
		feeShare = 0.25,
		seconds = 20 * 60,
	},
} :: { Mode }

return Growth
