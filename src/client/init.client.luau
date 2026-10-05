--!strict
-- Client entry point. UI and input controllers start here.

local CatchController = require(script.Controllers.CatchController)
local HuntController = require(script.Controllers.HuntController)

CatchController.start()
HuntController.start()
