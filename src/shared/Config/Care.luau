--!strict
-- Feeding and Familiarity. A caught monster starts fed. While it's fed its Familiarity grows
-- (and with it the sell value, up to Value.FamiliarityMaxMultiplier); once it's hungry its
-- Familiarity stops growing and its effects fall asleep, so it sells for base value x size
-- until it's fed again. "Feed all" is free and feeds every monster at once; Bakery treats
-- feed one monster and add Familiarity and an effect (see Shop.Bakery).
-- Placeholders, tune in playtesting.

local Care = {}

Care.FedHours = 24 -- one feeding keeps a monster fed this long
Care.FamiliarityHours = 24 -- hours of being fed to go from 0% to 100% Familiarity
Care.GrowsOffline = true -- Familiarity keeps growing while the owner is offline (only while fed)
Care.HungrySoonHours = 6 -- the Feed all button shows once a monster gets hungry within this

return Care
