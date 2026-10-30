--!strict
-- Monster stealing (Sprint E, Giles 2026-10-30: "more like GAG"). Walk into another player's
-- mansion, hold E on one of their monsters and pay Robux: it's yours straight away. The price
-- goes by what the monster is worth, and a hearted monster costs one step more. Monsters
-- are never sold for Robux any other way. Rules in Util/Heists, the stealing itself in
-- server/Services/HeistService, the prompts in client/Controllers/StealController.

local Heists = {}

-- Which Steal product a monster needs: the first step its sell value fits under. A hearted
-- monster uses the step after (Config/Robux has the products and their prices).
Heists.Steps = {
	{ product = "Steal1", maxValue = 1_000_000 },
	{ product = "Steal2", maxValue = 50_000_000 },
	{ product = "Steal3", maxValue = 1_000_000_000 },
	{ product = "Steal4", maxValue = 20_000_000_000 },
	{ product = "Steal5", maxValue = math.huge },
	{ product = "Steal6", maxValue = math.huge }, -- only for hearted monsters from step 5
}

Heists.HoldSeconds = 1.5 -- how long E is held before the Robux prompt opens
Heists.Reach = 12 -- studs from the monster

-- Protections (owners are always online and in the same server: offline mansions aren't there).
Heists.NewPlayerSeconds = 2 * 60 * 60 -- nobody can be robbed in their first 2 hours of play
Heists.MaxLossesPerDay = 2 -- most monsters one player can lose to stealing in a day
Heists.SameThiefPerDay = 1 -- how often the same thief may rob the same player in a day
-- In Studio play tests the 2-hour shield is off, so stealing can be tried straight away with
-- Test > Clients and Servers.
Heists.ShieldInStudio = false

return Heists
