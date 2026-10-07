--!strict
-- Server entry point. Requires every service and starts them in order: each one may only
-- use the ones started before it (WorldBuilder builds any missing world pieces before the
-- plots, zones and gates are read).

local DataService = require(script.Services.DataService)
local _Notify = require(script.Notify) -- no start(); made here so the Toast remote exists early
local _MonsterModel = require(script.MonsterModel) -- no start()
local _Counter = require(script.Counter) -- no start()
local WorldBuilder = require(script.Services.WorldBuilder)
local PlotService = require(script.Services.PlotService)
local RoamService = require(script.Services.RoamService)
local SpawnService = require(script.Services.SpawnService)
local MansionService = require(script.Services.MansionService)
local WatcherService = require(script.Services.WatcherService)
local HuntService = require(script.Services.HuntService)
local CatchService = require(script.Services.CatchService)
local CollectorService = require(script.Services.CollectorService)
local WorkshopService = require(script.Services.WorkshopService)
local CareService = require(script.Services.CareService)
local BakeryService = require(script.Services.BakeryService)
local DevService = require(script.Services.DevService)

local services: { { name: string, start: () -> ...any } } = {
	{ name = "DataService", start = DataService.start },
	{ name = "WorldBuilder", start = WorldBuilder.start },
	{ name = "PlotService", start = PlotService.start },
	{ name = "RoamService", start = RoamService.start },
	{ name = "SpawnService", start = SpawnService.start },
	{ name = "MansionService", start = MansionService.start },
	{ name = "WatcherService", start = WatcherService.start },
	{ name = "HuntService", start = HuntService.start },
	{ name = "CatchService", start = CatchService.start },
	{ name = "CollectorService", start = CollectorService.start },
	{ name = "WorkshopService", start = WorkshopService.start },
	{ name = "CareService", start = CareService.start },
	{ name = "BakeryService", start = BakeryService.start },
	{ name = "DevService", start = DevService.start },
}

-- One service failing to start shows its error in Output but doesn't stop the others.
for _, service in services do
	local ok, err = xpcall(service.start, debug.traceback)
	if not ok then
		warn(`{service.name} failed to start: {err}`)
	end
end
