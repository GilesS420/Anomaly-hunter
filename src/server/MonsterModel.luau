--!strict
-- STUB (sprint 2): replace with the real implementation per the spec.
local MonsterModel = {}
export type Info = { monsterId: string, rarity: string, size: string, effects: { string }?, owner: string? }
function MonsterModel.build(_info: Info): Model
	return Instance.new("Model")
end
function MonsterModel.radius(_sizeId: string): number
	return 1.5
end
return MonsterModel
