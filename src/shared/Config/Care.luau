--!strict
-- Familiarity. A monster in the mansion gets more familiar over time, which raises its sell
-- value (up to Value.FamiliarityMaxMultiplier) and its odds of picking up roaming effects.
-- Monsters never get hungry. Placeholders, tune in playtesting.

local Care = {}

-- Hours in the mansion to go from 0% to 100% Familiarity. Cheaper monsters get familiar
-- faster: a monster worth CheapValue (base price) or less takes CheapHours, one worth
-- PriceyValue or more takes PriceyHours, and in between every x10 in price takes about
-- three times as long (Util/Care.hours): $1K 10 min, $10K ~30 min, $100K ~1.6 h, $1M ~5 h,
-- $10M ~15 h.
Care.CheapValue = 1_000
Care.CheapHours = 10 / 60
Care.PriceyValue = 100_000_000
Care.PriceyHours = 48
Care.FamiliarityHours = 24 -- for a monster that isn't in Config/Monsters any more
Care.GrowsOffline = true -- Familiarity keeps growing while the owner is offline

return Care
