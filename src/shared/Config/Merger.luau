--!strict
-- The Merger, next to the Trading Booth (Giles 2026-10-24). Put two monsters of the same
-- kind from your Backpack in: a main and a donor. On success they fuse into the main, which
-- gets heavier and keeps every effect of both. On failure the donor is lost and the main
-- comes out unchanged. Either way the fee is paid. Rules in Util/Merge.
-- Placeholders, tune in playtesting.

local Merger = {}

Merger.FeeShare = 0.1 -- the fee: this share of the donor's sell value
Merger.DonorKgShare = 0.5 -- the main gains this share of the donor's weight

-- Success chance in percent, by the monsters' rarity (Config/Rarities).
Merger.Success = {
	Common = 90,
	Uncommon = 85,
	Rare = 75,
	Epic = 65,
	Legendary = 55,
	Mythic = 45,
	Divine = 35,
	Phantom = 45,
	Nightmare = 35,
	Eldritch = 25,
} :: { [string]: number }

Merger.RevealSeconds = 2 -- how long the window bubbles before it shows how it went

return Merger
