--!strict
-- Rebirth rules (numbers in Config/Rebirth). Pure, so tests/run.luau checks them.

local Config = require("../Config/Rebirth")
local Wings = require("../Config/Wings")

local Rebirth = {}

export type Check = "Ok" | "NotComplete" | "TooPoor"

-- How many rebirths a save has done (older saves have no field yet).
function Rebirth.count(value: unknown): number
	local n = tonumber(value)
	if not n or n ~= n or n < 0 then
		return 0
	end
	return math.floor(n)
end

-- Money needed for the next rebirth after `done` of them.
function Rebirth.cost(done: number): number
	return Config.FirstCost * Config.CostGrowth ^ math.max(0, done)
end

-- The Collector bonus from `done` rebirths, in whole percent (+50, +100...).
function Rebirth.bonusPercent(done: number): number
	return math.floor(math.max(0, done) * Config.SellBonusPerRebirth * 100 + 0.5)
end

-- Whether a player with these wings and money can rebirth now.
function Rebirth.check(wingsOwned: number, money: number, done: number): Check
	if wingsOwned < #Wings.List then
		return "NotComplete"
	end
	if money < Rebirth.cost(done) then
		return "TooPoor"
	end
	return "Ok"
end

return Rebirth
