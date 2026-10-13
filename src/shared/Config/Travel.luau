--!strict
-- Getting around the hub: a faster walk in the open middle of the hub, and the fast-travel
-- buttons at the top of the screen (see Util/Travel, TravelService and TravelController).

export type Destination = {
	id: string, -- what the button sends to the server
	label: string, -- button text
	color: { number }, -- button colour, RGB
}

return {
	-- WalkSpeed in the open hub. Mansion plots and zones keep the normal speed
	-- (StarterPlayer.CharacterWalkSpeed, 16 by default).
	HubWalkSpeed = 32,
	-- Seconds between two fast-travel trips: short enough to click through the buttons
	-- quickly, just enough to ignore an accidental double click.
	Cooldown = 0.25,
	-- Studs between where you land and the shop or the row of gates.
	StandOff = 10,
	Destinations = {
		{ id = "Portals", label = "Portals", color = { 60, 140, 110 } },
		{ id = "Bakery", label = "Bakery", color = { 200, 110, 140 } },
		{ id = "Workshop", label = "Workshop", color = { 110, 80, 200 } },
	} :: { Destination },
}
