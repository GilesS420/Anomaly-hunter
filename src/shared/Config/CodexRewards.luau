--!strict
-- Codex rewards: money paid once for finishing a goal on a Codex page (Util/Codex.newRewards,
-- server/Services/CodexService). On a monster page the goals are catching every monster on it
-- ("Found"), then catching every one of them in each variant. A page's goals pay its `Pages`
-- amount times the goal's `Goals` multiplier. The effects page pays for finding every effect
-- and for making every secret combo.
--
-- Wings cost 8x more each step (Config/Wings), so each zone's page pays about 8x the last.
-- Raised 5x on 2026-10-21 (Giles: "codex rewards need to be higher").

return {
	Goals = {
		Found = 1,
		Silver = 2.5,
		Gold = 5,
		Shiny = 15,
		Rainbow = 50,
	} :: { [string]: number },
	Pages = {
		PumpkinGraveyard = 500_000,
		MurkyBayou = 4_000_000,
		AbandonedCarnival = 32_000_000,
		SpookySchool = 256_000_000,
		GhostShip = 2_048_000_000,
		Events = 10_000_000, -- the Watcher event monsters
	} :: { [string]: number },
	Effects = 5_000_000, -- every effect found
	Combos = 25_000_000, -- every secret combo made
}
