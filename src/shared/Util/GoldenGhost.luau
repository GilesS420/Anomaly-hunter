--!strict
-- Golden Ghost prize rules (Config/GoldenGhost). Pure functions so they can be tested outside
-- Roblox.

local Config = require("../Config/GoldenGhost")
local Shop = require("../Config/Shop")

local GoldenGhost = {}

-- The cash prize for a mansion whose monsters would sell for `mansionValue`.
function GoldenGhost.cash(mansionValue: number): number
	return math.max(Config.MinCash, math.floor(mansionValue * Config.CashShare))
end

-- The cakes the prize may be, for this cash prize: every Bakery cake that isn't an event
-- treat and costs at most CakeTimesCash times the cash, or the cheapest one if none does.
function GoldenGhost.cakeChoices(cash: number): { Shop.Item }
	local choices: { Shop.Item } = {}
	local cheapest: Shop.Item? = nil
	for _, item in Shop.Bakery do
		if item.event then
			continue
		end
		if item.price <= cash * Config.CakeTimesCash then
			table.insert(choices, item)
		end
		if not cheapest or item.price < cheapest.price then
			cheapest = item
		end
	end
	if #choices == 0 and cheapest then
		table.insert(choices, cheapest)
	end
	return choices
end

return GoldenGhost
