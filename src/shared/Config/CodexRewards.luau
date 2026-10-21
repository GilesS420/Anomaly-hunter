--!strict
-- Codex rewards: money paid once for finishing a goal on a Codex page (Util/Codex.newRewards,
-- server/Services/CodexService). On a monster page the goals are catching every monster on it
-- ("Found"), then catching every one of them in each variant. A page's goals pay its `Pages`
-- amount times the goal's `Goals` multiplier. The effects page pays for finding every effect
-- and for making every secret combo.
--
-- Wings cost 8x more each step (Config/Wings), so each zone's page pays about 8x the last.

return {
	Goals = {
		Found = 1,
		Silver = 2.5,
		Gold = 5,
		Shiny = 15,
		Rainbow = 50,
	} :: { [string]: number },
	Pages = {
		PumpkinGraveyard = 100_000,
		MurkyBayou = 800_000,
		AbandonedCarnival = 6_400_000,
		SpookySchool = 51_200_000,
		GhostShip = 409_600_000,
		Events = 2_000_000, -- the Watcher event monsters
	} :: { [string]: number },
	Effects = 1_000_000, -- every effect found
	Combos = 5_000_000, -- every secret combo made
}
