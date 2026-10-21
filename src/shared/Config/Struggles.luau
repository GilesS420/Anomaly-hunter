--!strict
-- The struggle: every catch has quick time moments where the monster fights the vacuum. The
-- meter stops, a needle sweeps back and forth over a bar, and you tap (or press Space or E)
-- while the needle is in the glowing zone. Hit it and the meter fills on; miss it, or wait
-- too long, and the monster breaks free (dazed, so you can try again).
-- Rarer monsters struggle more often, with a faster needle and a smaller zone; bigger ones
-- shrink the zone a little more. All numbers are placeholders to tune in playtesting.

export type Struggle = {
	count: number, -- struggles per catch, spread evenly over the meter
	speed: number, -- full sweeps of the needle (one side to the other) per second
	zone: number, -- width of the zone, as a share of the bar (0 to 1)
}

local Struggles = {}

Struggles.ByRarity = {
	Common = { count = 1, speed = 0.6, zone = 0.34 },
	Uncommon = { count = 1, speed = 0.75, zone = 0.3 },
	Rare = { count = 2, speed = 0.9, zone = 0.26 },
	Epic = { count = 2, speed = 1.05, zone = 0.22 },
	Legendary = { count = 3, speed = 1.2, zone = 0.18 },
	Mythic = { count = 3, speed = 1.4, zone = 0.15 },
	Divine = { count = 4, speed = 1.6, zone = 0.12 },
	Phantom = { count = 2, speed = 1, zone = 0.24 },
	Nightmare = { count = 3, speed = 1.3, zone = 0.17 },
	Eldritch = { count = 4, speed = 1.6, zone = 0.12 },
} :: { [string]: Struggle }

-- The zone's width is multiplied by this for the monster's size.
Struggles.ZoneBySize = {
	Tiny = 1.15,
	Small = 1.08,
	Normal = 1,
	Big = 0.92,
	Huge = 0.85,
	Colossal = 0.78,
	Titan = 0.7,
} :: { [string]: number }

-- Seconds you get to tap before the monster breaks free anyway.
Struggles.TimeoutSeconds = 4

-- How far a tap's time may be from the server's clock (lag) and still count, in seconds.
Struggles.LagAllowance = 0.35

return Struggles
