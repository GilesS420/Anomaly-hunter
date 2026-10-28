--!strict
-- Slapping (Giles 2026-10-28): walk up to another hunter in a zone or in the open hub and slap
-- them. They get knocked back, and if they were catching a monster it breaks loose (dazed for
-- a moment), so you can challenge them for it. Never in a mansion plot or the tutorial.
-- Rules in Util/Slap, server SlapService, button and Q key in client SlapController.
-- All numbers are placeholders to tune in playtesting.

local Slap = {}

Slap.Range = 7 -- studs between the two hunters for the button to show
Slap.RangeSlack = 3 -- extra studs the server allows, for lag
Slap.CooldownSeconds = 3 -- between two of your own slaps
Slap.GuardSeconds = 5 -- after being slapped, nobody can slap you again for this long
Slap.PushSpeed = 55 -- studs per second the slap throws you back
Slap.PushUp = 28 -- and up

return Slap
