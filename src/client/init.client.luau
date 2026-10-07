--!strict
-- Client entry point. UI and input controllers start here.
-- Each controller starts in its own thread, so one that is still waiting for the server
-- (for example for a remote to appear) never holds up the others.

local ToastController = require(script.Controllers.ToastController)
local RoamController = require(script.Controllers.RoamController)
local CatchController = require(script.Controllers.CatchController)
local HuntController = require(script.Controllers.HuntController)
local CollectorController = require(script.Controllers.CollectorController)
local WorkshopController = require(script.Controllers.WorkshopController)
local BakeryController = require(script.Controllers.BakeryController)

local controllers: { { start: () -> () } } = {
	ToastController,
	RoamController,
	CatchController,
	HuntController,
	CollectorController,
	WorkshopController,
	BakeryController,
}

for _, controller in controllers do
	task.spawn(controller.start)
end
