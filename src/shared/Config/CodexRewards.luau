--!strict
-- Codex rewards: money paid once for finishing a goal on a Codex page (Util/Codex.newRewards,
-- server/Services/CodexService). On a monster page the goals are catching every monster on it
-- ("Found"), then catching every one of them in each variant. A page's goals pay its `Pages`
-- amount times the goal's `Goals` multiplier. The effects page pays for finding every effect
-- and for making every secret combo.
--
-- Harder goals pay much more (Giles 2026-11-05): every effect $1T, every combo $2T, the Watcher
-- event page $50B for Found. A zone page's Found pays 2x that zone's Divine monster, and each
-- zone pays 4x the last. Variant multipliers follow how rare the colour is to catch.
-- Table for Giles: https://claude.ai/artifact/XmyH81EdGfPur7JKkbu4KQ

return {
	Goals = {
		Found = 1,
		Silver = 3,
		Gold = 6,
		Shiny = 20,
		Rainbow = 100,
	} :: { [string]: number },
	Pages = {
		PumpkinGraveyard = 30_000_000,
		MurkyBayou = 120_000_000,
		AbandonedCarnival = 480_000_000,
		SpookySchool = 1_920_000_000,
		GhostShip = 7_680_000_000,
		Events = 50_000_000_000, -- the Watcher event monsters
	} :: { [string]: number },
	-- Zone pages also pay for catching every monster of one rarity there (Giles 2026-11-05),
	-- whatever its colour. Amounts are for Pumpkin Graveyard; RarityScale multiplies them per
	-- zone (4x each zone, like monster values). The Watcher event page has no rarity goals.
	Rarities = {
		Common = 20_000,
		Uncommon = 50_000,
		Rare = 150_000,
		Epic = 500_000,
		Legendary = 2_000_000,
		Mythic = 8_000_000,
		Divine = 25_000_000,
	} :: { [string]: number },
	RarityScale = {
		PumpkinGraveyard = 1,
		MurkyBayou = 4,
		AbandonedCarnival = 16,
		SpookySchool = 64,
		GhostShip = 256,
	} :: { [string]: number },
	Effects = 1_000_000_000_000, -- every effect found
	Combos = 2_000_000_000_000, -- every secret combo made

	-- Saves from before 2026-11-05 mark a paid goal `true` instead of the amount paid. With
	-- TopUpOldClaims on, such a goal counts as paid at these old amounts and the player gets the
	-- difference the next time the Codex is checked. Off: `true` counts as fully paid.
	TopUpOldClaims = true,
	Old = {
		Goals = { Found = 1, Silver = 2.5, Gold = 5, Shiny = 15, Rainbow = 50 } :: { [string]: number },
		Pages = {
			PumpkinGraveyard = 500_000,
			MurkyBayou = 4_000_000,
			AbandonedCarnival = 32_000_000,
			SpookySchool = 256_000_000,
			GhostShip = 2_048_000_000,
			Events = 10_000_000,
		} :: { [string]: number },
		Effects = 5_000_000,
		Combos = 25_000_000,
	},
}
