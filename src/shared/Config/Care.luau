--!strict
-- Familiarity. A monster in the mansion gets more familiar over time, which raises its sell
-- value (up to Value.FamiliarityMaxMultiplier) and its odds of picking up roaming effects.
-- Monsters never get hungry. Placeholders, tune in playtesting.

local Care = {}

Care.FamiliarityHours = 24 -- hours in the mansion to go from 0% to 100% Familiarity
Care.GrowsOffline = true -- Familiarity keeps growing while the owner is offline

return Care
