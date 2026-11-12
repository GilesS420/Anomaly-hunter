--!strict
-- Rebirth (thread "Add patterns from top Roblox games", 2026-11-11). The long-term loop of
-- Steal a Brainrot and most simulators: once every wing is owned, start over for a bonus that
-- stays forever. Rules in Util/Rebirth, done by server/Services/RebirthService.
--
-- Resets: money, wings (back to the Foyer), every monster in the mansion and Backpack, and
-- the cakes standing out (they go back in the hotbar).
-- Keeps: vacuums, slappers and every other item, the Codex, badges, Robux purchases and
-- passes, missions, settings.

local Rebirth = {}

-- Money needed on top of owning every wing, for the first rebirth; each one after costs
-- CostGrowth times more. The money is not paid: it all resets anyway.
Rebirth.FirstCost = 10_000_000_000 -- $10B (the Garden wing is $5B)
Rebirth.CostGrowth = 4

-- Collector bonus per rebirth, as a fraction. Added to the other sell bonuses (friends,
-- VIP, Guild, rookie hour), never multiplied (effect math rule, 2026-11-05).
Rebirth.SellBonusPerRebirth = 0.5

return Rebirth
