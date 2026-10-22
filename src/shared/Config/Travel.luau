--!strict
-- Getting around the hub: a faster walk in the open middle of the hub, and the fast-travel
-- buttons at the top of the screen (see Util/Travel, TravelService and TravelController).

export type Destination = {
	id: string, -- what the button sends to the server
	label: string, -- button text
	color: { number }, -- button colour, RGB
	-- Hub.Landmarks to land at: one, in front of it; two, at a spot just as far from both
	-- (in front of the pair). None: the gate of the newest zone the player has opened.
	landmarks: { string }?,
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
		{ id = "Shops", label = "Shops", color = { 160, 95, 170 }, landmarks = { "Bakery", "Workshop" } },
		{ id = "Sell", label = "Sell", color = { 205, 135, 30 }, landmarks = { "Collector" } },
	} :: { Destination },
}
