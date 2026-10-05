--!strict
-- Mansion rules: how many monsters fit, and which wing can be bought next.
-- Pure functions so they can be tested outside Roblox.

local Wings = require("../Config/Wings")

local Mansion = {}

-- Wings in purchase order (Foyer first).
local ordered: { Wings.Wing } = table.clone(Wings.List)
table.sort(ordered, function(a, b)
	return a.order < b.order
end)

-- The wings a player owns, in order. wingsOwned counts them, the free Foyer included.
function Mansion.ownedWings(wingsOwned: number): { Wings.Wing }
	local owned = {}
	for _, wing in ordered do
		if wing.order <= wingsOwned then
			table.insert(owned, wing)
		end
	end
	return owned
end

-- How many monsters the mansion holds (all owned wings together).
function Mansion.capacity(wingsOwned: number): number
	local total = 0
	for _, wing in Mansion.ownedWings(wingsOwned) do
		total += wing.capacity
	end
	return total
end

function Mansion.hasRoom(wingsOwned: number, monsterCount: number): boolean
	return monsterCount < Mansion.capacity(wingsOwned)
end

-- The next wing to buy, or nil when every wing is owned.
function Mansion.nextWing(wingsOwned: number): Wings.Wing?
	for _, wing in ordered do
		if wing.order == wingsOwned + 1 then
			return wing
		end
	end
	return nil
end

export type BuyResult = "Ok" | "AllOwned" | "ComingSoon" | "TooPoor"

-- Whether the next wing can be bought now, and which wing that is.
function Mansion.canBuyNext(wingsOwned: number, money: number): (BuyResult, Wings.Wing?)
	local wing = Mansion.nextWing(wingsOwned)
	if not wing then
		return "AllOwned", nil
	end
	if not wing.launch then
		return "ComingSoon", wing
	end
	if money < wing.price then
		return "TooPoor", wing
	end
	return "Ok", wing
end

return Mansion
