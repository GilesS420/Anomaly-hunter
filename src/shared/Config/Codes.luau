--!strict
-- Reward codes (thread "Add fresh content to match the market", 2026-11-11). Players type a
-- code in Settings > Codes; each works once per player. Post new codes on the game page, the
-- group wall and in update logs: "codes" are one of the first things new players look for.
-- Rules in Util/Codes, server/Services/CodesService pays them.
--
-- Codes are matched without caring about capitals or spaces ("spooky school" = SPOOKYSCHOOL).
-- Cash is a share of the same base as the playtime gifts (Util/Playtime.base), at least
-- `floor`. To retire a code, set `ended = true` (players who type it are told it ended).

export type Code = {
	code: string, -- capitals and digits only
	share: number?,
	floor: number?,
	items: { [string]: number }?, -- Workshop or Bakery item id -> how many
	pickCake: boolean?, -- also a Bakery cake picked for their progress (like the playtime gifts)
	ended: boolean?,
}

return {
	{ code = "WELCOME", share = 0.02, floor = 5_000, items = { ReturnCharm = 2, BaitBell = 1 } },
	{ code = "SPOOKYSCHOOL", share = 0.03, floor = 10_000, items = { SilverBell = 1 } },
	{ code = "LUCKY", items = { LuckyTonic = 1 }, pickCake = true },
	{ code = "HUNTERS", share = 0.05, floor = 20_000 },
} :: { Code }
