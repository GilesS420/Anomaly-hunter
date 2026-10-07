--!strict
-- Where everything sits in the world. The server builds grey placeholder blocks here for
-- anything that isn't already in the place (see WorldBuilder), so the game is playable
-- before the real models exist. Studs; the ground is at Y = 0 (top of the default baseplate).
--
-- The hub is an oval: 4 mansion plots along the top, 4 along the bottom, Collector,
-- Watcher Square and Trading Booth in the middle, Bakery + Workshop at the west end and
-- the Zone Gates at the east end.

export type Vec = { x: number, y: number, z: number }

export type PlotSpot = {
	name: string, -- Plot1 .. Plot8
	x: number,
	z: number,
	facing: number, -- +1: the mansion's front faces +Z, -1: it faces -Z (always toward the middle)
}

-- Plot-local coordinates use the plot's CFrame: its LookVector (local -Z) points out of the
-- front door toward the middle of the hub, so +z is further back from the front door and
-- +x is the plot's RightVector.
export type WingSpot = {
	x: number, -- plot-local, along the plot's RightVector
	z: number, -- plot-local, +z is further back from the front door
	width: number, -- along x
	depth: number, -- along z
}

local Layout = {}

Layout.Hub = {
	Center = { x = 0, y = 0, z = 0 } :: Vec,
	GroundSize = { x = 900, z = 520 }, -- the oval floor
}

Layout.PlotSize = { x = 140, z = 110 }

Layout.Plots = {
	{ name = "Plot1", x = -225, z = -130, facing = 1 },
	{ name = "Plot2", x = -75, z = -130, facing = 1 },
	{ name = "Plot3", x = 75, z = -130, facing = 1 },
	{ name = "Plot4", x = 225, z = -130, facing = 1 },
	{ name = "Plot5", x = -225, z = 130, facing = -1 },
	{ name = "Plot6", x = -75, z = 130, facing = -1 },
	{ name = "Plot7", x = 75, z = 130, facing = -1 },
	{ name = "Plot8", x = 225, z = 130, facing = -1 },
} :: { PlotSpot }

-- Wing floors inside a plot: Foyer in the middle with Library and Ballroom either side,
-- and the later wings in a second row behind them. Plot-local, see WingSpot.
Layout.Wings = {
	Foyer = { x = 0, z = -10, width = 40, depth = 40 },
	Library = { x = -42, z = -10, width = 40, depth = 40 },
	Ballroom = { x = 42, z = -10, width = 40, depth = 40 },
	Attic = { x = -42, z = 32, width = 40, depth = 40 },
	Crypt = { x = 42, z = 32, width = 40, depth = 40 },
	Garden = { x = 0, z = 32, width = 40, depth = 40 },
} :: { [string]: WingSpot }

-- Where the owner appears on their plot, plot-local (in front of the Foyer).
Layout.PlotSpawn = { x = 0, z = -45 }

-- Hub landmarks (placeholders until the art pass, #31).
Layout.Landmarks = {
	{ name = "WatcherSquare", label = "Watcher Square", x = 0, z = 0, width = 60, depth = 60, height = 1 },
	{
		name = "Collector",
		label = "The Collector",
		x = -110,
		z = 0,
		width = 40,
		depth = 30,
		height = 16,
	},
	{
		name = "TradingBooth",
		label = "Trading Booth (coming soon)",
		x = 110,
		z = 0,
		width = 40,
		depth = 30,
		height = 16,
	},
	{
		name = "Bakery",
		label = "Haunted Bakery",
		x = -380,
		z = -45,
		width = 40,
		depth = 40,
		height = 20,
	},
	{
		name = "Workshop",
		label = "Hunter's Workshop",
		x = -380,
		z = 45,
		width = 40,
		depth = 40,
		height = 20,
	},
}

-- Where hunters land in the hub when they have no plot (fallback).
Layout.ReturnPoint = { x = 0, z = 40 }

-- Zone gates at the east end, one per launch zone, by zone index.
Layout.Gates = {
	[1] = { x = 380, z = -50 },
	[2] = { x = 380, z = 0 },
	[3] = { x = 380, z = 50 },
	[4] = { x = 380, z = -100 },
	[5] = { x = 380, z = 100 },
} :: { [number]: { x: number, z: number } }
Layout.GateSize = { width = 14, height = 16, thickness = 2 }

-- Zones are floating islands far from the hub; hunters only get there through a gate.
Layout.ZoneSize = { x = 220, z = 220 }
Layout.ZoneWallHeight = 16
Layout.Zones = {
	[1] = { x = 0, y = 100, z = 1500 },
	[2] = { x = 0, y = 100, z = 1850 },
	[3] = { x = 0, y = 100, z = 2200 },
	[4] = { x = 0, y = 100, z = 2550 },
	[5] = { x = 0, y = 100, z = 2900 },
} :: { [number]: Vec }

-- Inside a zone (zone-local, +z away from the arrival side).
Layout.ZoneArrival = { x = -20, z = -90 }
Layout.ZoneExit = { x = 20, z = -100 }
Layout.ZoneRoamArea = { x = 0, z = 20, width = 190, depth = 150 } -- keeps monsters away from the arrival

return Layout
