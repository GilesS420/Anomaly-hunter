--!strict
-- The "Next goal" bar under the money (Giles 2026-11-05): always one thing to save up for, so
-- every catch has a purpose. The goal is the cheapest vacuum better than your best one (one
-- that costs more: a cheaper one you skipped is no upgrade) or your next mansion wing,
-- whichever costs less. Pure so it can be tested outside Roblox; the server
-- (RookieService) sets the player attributes GoalName and GoalPrice, the client
-- (HuntController) draws the bar against your money.

local Names = require("../Config/Names")
local Shop = require("../Config/Shop")
local Wings = require("../Config/Wings")
local Zones = require("../Config/Zones")

local Goals = {}

export type Goal = { id: string, name: string, price: number }

local function zoneName(index: number?): string?
	for _, zone in Zones.List do
		if zone.index == index and zone.launch then
			return zone.name
		end
	end
	return nil
end

-- What to save up for next, or nil when everything is owned.
function Goals.next(inventory: { [string]: number }, wingsOwned: number): Goal?
	-- The dearest vacuum owned: only ones that cost more are an upgrade.
	local ownedPrice = 0
	for _, item in Shop.Workshop do
		if item.kind == "Vacuum" and (inventory[item.id] or 0) > 0 then
			ownedPrice = math.max(ownedPrice, item.price)
		end
	end
	local best: Goal? = nil
	for _, item in Shop.Workshop do
		if item.kind == "Vacuum" and item.price > ownedPrice and (inventory[item.id] or 0) <= 0 then
			if not best or item.price < best.price then
				best = { id = item.id, name = item.name, price = item.price }
			end
		end
	end
	local wing = Wings.List[math.floor(wingsOwned) + 1]
	if wing and (not best or wing.price < best.price) then
		local opens = zoneName(wing.unlocksZone)
		local wingName = Names[wing.id] or wing.id
		best = {
			id = wing.id,
			name = if opens then `{wingName} wing (opens {opens})` else `{wingName} wing`,
			price = wing.price,
		}
	end
	return best
end

-- How far along the bar is, 0 to 1.
function Goals.progress(money: number, price: number): number
	if price <= 0 then
		return 1
	end
	return math.clamp(money / price, 0, 1)
end

return Goals
