--!strict
-- STUB (sprint 2): replace with the real implementation per the spec.
local PlotService = {}
export type Plot = { index: number, name: string, part: BasePart, frame: CFrame }
function PlotService.get(_player: Player): Plot?
	return nil
end
function PlotService.spawnCFrame(_player: Player): CFrame?
	return nil
end
function PlotService.onAssigned(_callback: (Player, Plot) -> ()) end
function PlotService.ownerOf(_plotName: string): Player?
	return nil
end
function PlotService.teleport(_player: Player, _cframe: CFrame) end
function PlotService.start() end
return PlotService
