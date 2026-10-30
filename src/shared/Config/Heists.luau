--!strict
-- Monster Heists (Sprint E, Giles picked option B on 2026-10-28: heists cost Robux, everyone
-- can defend for free). Rules in Util/Heists, the heist itself in server/Services/HeistService.
-- Design page: https://claude.ai/artifact/HZhoKwMseDVgcnwDZvemGm
--
-- A Heist Charge (Robux, Config/Robux.Products) starts one heist at another player's mansion:
-- the owner hears an alarm and everyone sees THIEF over the thief's head. The thief has
-- InsideSeconds to vacuum one roaming monster that isn't hearted (the normal catch, with
-- struggles), then CarrySeconds to walk it to their own plot, slower than normal. One slap
-- and it flies back home. Reaching your own plot makes it yours, with its Familiarity back
-- at 0 and its name tag and heart taken off.

local Heists = {}

Heists.InsideSeconds = 60 -- to vacuum a monster once the heist starts
Heists.CarrySeconds = 120 -- to get it home once it's in the vacuum
Heists.CarrySpeed = 0.75 -- walking speed is multiplied by this while carrying a stolen monster
Heists.DoorReach = 12 -- studs: how close the heist prompt on the worth sign works from

-- Protections (from the design page).
Heists.MaxHearts = 5 -- hearted monsters can't be stolen; at most this many hearts (nil: no limit)
Heists.NewPlayerSeconds = 2 * 60 * 60 -- nobody can rob you in your first 2 hours of play
Heists.MinMansionWorth = 1_000_000 -- or while your mansion's monsters are worth less than this
Heists.MaxLossesPerDay = 2 -- most monsters one player can lose to heists in a day
Heists.SameThiefPerDay = 1 -- how often the same thief may rob the same player in a day
-- In Studio play tests the 2-hour shield is off, so heists can be tried straight away with
-- Test > Clients and Servers. The other protections still count.
Heists.ShieldInStudio = false

-- Moving faster than this (studs a second, walking speed with every boost is about 64) means a
-- teleport (fast travel, a Return Charm or a cheat): the stolen monster flies back home.
Heists.MaxCarrySpeed = 90

-- Charges each product gives (the products themselves are in Config/Robux).
Heists.ProductCharges = { HeistCharge = 1, HeistBundle = 5 } :: { [string]: number }

return Heists
