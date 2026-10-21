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
local AttackController = require(script.Controllers.AttackController)
local TravelController = require(script.Controllers.TravelController)
local GateController = require(script.Controllers.GateController)
local InventoryController = require(script.Controllers.InventoryController)
local CakeController = require(script.Controllers.CakeController)
local HotbarController = require(script.Controllers.HotbarController)
local CarryController = require(script.Controllers.CarryController)
local PickupController = require(script.Controllers.PickupController)
local MonsterLabelController = require(script.Controllers.MonsterLabelController)
local SkyController = require(script.Controllers.SkyController)
local EventIconController = require(script.Controllers.EventIconController)
local AdminController = require(script.Controllers.AdminController)
local SoundController = require(script.Controllers.SoundController)
local TutorialController = require(script.Controllers.TutorialController)
local CodexController = require(script.Controllers.CodexController)
local SettingsController = require(script.Controllers.SettingsController)
local AwayBookController = require(script.Controllers.AwayBookController)

local controllers: { { start: () -> () } } = {
	ToastController,
	RoamController,
	CatchController,
	HuntController,
	CollectorController,
	WorkshopController,
	BakeryController,
	AttackController,
	TravelController,
	GateController,
	InventoryController,
	CakeController,
	HotbarController,
	CarryController,
	PickupController,
	MonsterLabelController,
	SkyController,
	EventIconController,
	AdminController,
	SoundController,
	TutorialController,
	CodexController,
	SettingsController,
	AwayBookController,
}

for _, controller in controllers do
	task.spawn(controller.start)
end
