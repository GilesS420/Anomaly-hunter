--!strict
-- STUB (sprint 2): replace with the real implementation per the spec.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Value = require(ReplicatedStorage.Shared.Util.Value)
local MansionService = {}
function MansionService.capacity(_player: Player): number
	return 0
end
function MansionService.hasRoom(_player: Player): boolean
	return false
end
function MansionService.addMonster(_player: Player, _caught: Value.CaughtMonster): boolean
	return false
end
function MansionService.rebuild(_player: Player) end
function MansionService.start() end
return MansionService
