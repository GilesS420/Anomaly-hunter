--!strict
-- The Variant Machine, inside the Merger (Giles 2026-10-29, like the machine in Grow a
-- Garden). Put a monster from your Backpack in: one of its effects, picked at random, is used
-- up to pay for one pull at a catch variant (Config/Variants). The monster always comes back.
-- Only an upgrade counts: landing on its own variant or a lower one gives nothing. The odds
-- are shown in the window and nothing (passes, potions) changes them. Rules in
-- Util/VariantMachine. Placeholders, tune in playtesting.

local VariantMachine = {}

-- Percent per pull for each variant; whatever is left over (74%) is a miss.
VariantMachine.Odds = {
	Rainbow = 1,
	Shiny = 3,
	Gold = 7,
	Silver = 15,
} :: { [string]: number }

-- Locked until the second wing expansion (Giles 2026-10-30): Foyer + Library + Ballroom.
VariantMachine.UnlockWings = 3

VariantMachine.FeeShare = 0.1 -- the fee: this share of the monster's sell value
VariantMachine.RevealSeconds = 2 -- how long the machine whirs before it shows the pull

return VariantMachine
