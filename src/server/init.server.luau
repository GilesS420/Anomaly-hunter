--!strict
-- Server entry point. Starts each service in order.

local CatchService = require(script.Services.CatchService)
local DataService = require(script.Services.DataService)
local SpawnService = require(script.Services.SpawnService)

DataService.start()
SpawnService.start()
CatchService.start()
