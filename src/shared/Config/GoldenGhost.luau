--!strict
-- The Golden Ghost (quick time event B): once in the calm between two Watcher events, a golden
-- ghost zips through the main area for Seconds. The first player to click or tap it Taps
-- times wins a prize: cash that grows with their mansion, or now and then a rare cake. The
-- whole server races for it; missing it never costs anything. server/Services/GoldenGhostService
-- runs it, Util/GoldenGhost has the prize rules. Placeholders, tune in playtesting.

local GoldenGhost = {}

GoldenGhost.Seconds = 20 -- how long it stays before it gets away
GoldenGhost.Taps = 3 -- taps one player needs to catch it
GoldenGhost.TapReach = 90 -- studs from you it can still be tapped
GoldenGhost.TapCooldown = 0.25 -- seconds between one player's taps that count
GoldenGhost.Speed = 28 -- studs per second
GoldenGhost.Height = { 5, 11 } -- studs above the ground it flies, lowest to highest

-- When it comes: this many seconds into the calm after an event (the calm lasts at least
-- Events.GapMinSeconds, so it's always gone before the next warning).
GoldenGhost.EarliestSeconds = 45
GoldenGhost.LatestSeconds = 240

-- The prize: CashShare of what your mansion's monsters would sell for, at least MinCash.
-- CakeChance percent of the time it's a cake instead: a Bakery cake (not an event treat)
-- costing up to CakeTimesCash times the cash prize (the cheapest one if none is that cheap).
GoldenGhost.CashShare = 0.03
GoldenGhost.MinCash = 5_000
GoldenGhost.CakeChance = 20
GoldenGhost.CakeTimesCash = 5

return GoldenGhost
