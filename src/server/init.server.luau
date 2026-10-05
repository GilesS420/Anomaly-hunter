--!strict
-- Server entry point. Starts each service in order.

local DataService = require(script.Services.DataService)
local SpawnService = require(script.Services.SpawnService)

DataService.start()
SpawnService.start()
