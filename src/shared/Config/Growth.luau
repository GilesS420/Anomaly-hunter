--!strict
-- The Growth Chamber, next to the Collector (Giles 2026-10-24). Put one monster from your
-- Backpack in, pick how hard to push it and pay the fee. A win makes it heavier (so bigger
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
}

local Growth = {}

Growth.Charges = 5

-- Mildest first (the order of the buttons).
Growth.Modes = {
	{ id = "Gentle", name = "Gentle", chance = 80, win = 1.15, lose = 1, feeShare = 0.08 },
	{ id = "Strong", name = "Strong", chance = 55, win = 1.4, lose = 0.9, feeShare = 0.15 },
	{ id = "Reckless", name = "Reckless", chance = 30, win = 2, lose = 0.75, feeShare = 0.25 },
} :: { Mode }

Growth.RevealSeconds = 2 -- how long the chamber bubbles before it shows how it went

return Growth
