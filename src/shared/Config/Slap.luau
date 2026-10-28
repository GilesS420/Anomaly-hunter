--!strict
-- Slapping (Giles 2026-10-28): walk up to another hunter in a zone or in the open hub and slap
-- them. They get knocked back, and if they were catching a monster it breaks loose (dazed for
-- a moment), so you can challenge them for it. Never in a mansion plot or the tutorial.
-- You need a slapper to slap: everyone starts without one, and the Hunter's Workshop sells
-- them (Shop.Workshop, kind "Slapper"; bought once, kept forever, always in stock). Your best
-- slapper is the one you use, no need to hold it. Better slappers reach further, push harder
-- and lock a thief out of stealing for longer (Giles 2026-10-28).
-- Rules in Util/Slap, server SlapService, button and Q key in client SlapController.
-- All numbers are placeholders to tune in playtesting.

export type Slapper = {
	id: string, -- the Shop.Workshop item id
	reach: number, -- studs between the two hunters for the button to show
	push: number, -- studs per second the slap throws the other hunter back
	stealLockSeconds: number, -- slapping someone who is stealing stops them stealing for this long
}

local Slap = {}

-- Weakest first: the last one you own is the one you use.
Slap.Slappers = {
	{ id = "CobwebMitt", reach = 5, push = 30, stealLockSeconds = 10 },
	{ id = "RubberGlove", reach = 6, push = 40, stealLockSeconds = 20 },
	{ id = "BoneHand", reach = 9, push = 60, stealLockSeconds = 60 },
	{ id = "GhoulClaw", reach = 12, push = 80, stealLockSeconds = 2 * 60 },
	{ id = "WitchPaddle", reach = 16, push = 105, stealLockSeconds = 5 * 60 },
	{ id = "TitanHand", reach = 20, push = 130, stealLockSeconds = 10 * 60 }, -- Giles 2026-10-28
} :: { Slapper }

Slap.RangeSlack = 3 -- extra studs the server allows, for lag
Slap.CooldownSeconds = 3 -- between two of your own slaps
Slap.GuardSeconds = 5 -- after being slapped, nobody can slap you again for this long
Slap.PushUp = 28 -- studs per second the slap throws you up

return Slap
