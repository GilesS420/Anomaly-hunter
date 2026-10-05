--!strict
-- STUB (sprint 2): replace with the real implementation per the spec.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roam = require(ReplicatedStorage.Shared.Util.Roam)
local RoamService = {}
export type Options = { rects: { Roam.Rect }, radius: number, speed: number, group: string, at: Vector3 }
function RoamService.add(_model: Model, _opts: Options) end
function RoamService.remove(_model: Model) end
function RoamService.setRects(_model: Model, _rects: { Roam.Rect }) end
function RoamService.setRectsForGroup(_group: string, _rects: { Roam.Rect }) end
function RoamService.position(_model: Model): Vector3?
	return nil
end
function RoamService.hold(_model: Model) end
function RoamService.release(_model: Model, _pauseSeconds: number) end
function RoamService.isHeld(_model: Model): boolean
	return false
end
function RoamService.bodies(_group: string, _except: Model?): { Roam.Body }
	return {}
end
function RoamService.start() end
return RoamService
