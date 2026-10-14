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

-- Setting a treat out (Backpack > Set out, standing in your mansion) puts it down as a cake
-- that several monsters can nibble. Every CakeCheckSeconds the cake rolls CakeBiteChance; on a
-- hit a monster that hasn't had a bite yet walks over and eats. A bite feeds it, gives half
-- the treat's Familiarity and has SetOutEffectChance percent of the treat's normal effect odds
-- (so a sure treat gives its effect half the time). The cake is gone after CakeBites bites or
-- CakeMinutes, whichever comes first. With the defaults that is 3 bites in about 15 minutes.
-- Cakes aren't saved: they vanish when you leave, so set them out while you play.
Care.CakeMinutes = 15
Care.CakeBites = 3
Care.CakeBiteChance = 10 -- percent per check
Care.CakeCheckSeconds = 30
Care.CakesPerWing = 1 -- how many cakes can stand at once: one per owned wing (Foyer counts)
Care.SetOutEffectChance = 50
Care.BiteFamiliarityShare = 0.5

return Care
