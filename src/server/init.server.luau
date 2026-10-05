--!strict
-- Server entry point. Starts each service in order.

local CatchService = require(script.Services.CatchService)
local DataService = require(script.Services.DataService)
local HuntService = require(script.Services.HuntService)
local SpawnService = require(script.Services.SpawnService)

DataService.start()
SpawnService.start()
HuntService.start()
CatchService.start()
