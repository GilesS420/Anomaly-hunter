--!strict
-- Luck potions (Config/Shop items of kind "Potion"): the one a player has going, how long it
-- has left, and what drinking another does. The time left only counts down while the player
-- is online (HuntService ticks it). Pure functions so they can be tested outside Roblox.

local Shop = require("../Config/Shop")

local Potions = {}

-- The save's record: the potion going ("" for none) and its seconds left.
export type State = { id: string, secondsLeft: number }
export type DrinkResult = "Ok" | "Refreshed" | "Weaker" | "Unknown"

local byId: { [string]: Shop.Item } = {}
for _, item in Shop.Workshop do
	if item.kind == "Potion" then
		byId[item.id] = item
	end
end

function Potions.item(id: string): Shop.Item?
	return byId[id]
end

-- The potion going right now, or nil.
function Potions.active(state: State): Shop.Item?
	return if state.secondsLeft > 0 then byId[state.id] else nil
end

-- What the vacuum's variant chances are multiplied by: 1 with no potion going.
function Potions.boost(state: State): number
	local item = Potions.active(state)
	return if item then item.potionBoost or 1 else 1
end

-- Drinks potion `id`: it starts (or, the same one again, starts over at full time), unless a
-- stronger one is still going. Changes state only on "Ok" and "Refreshed".
function Potions.drink(state: State, id: string): DrinkResult
	local item = byId[id]
	if not item then
		return "Unknown"
	end
	local going = Potions.active(state)
	if going and (going.potionBoost or 1) > (item.potionBoost or 1) then
		return "Weaker"
	end
	local same = going ~= nil and going.id == id
	state.id = id
	state.secondsLeft = item.potionSeconds or 0
	return if same then "Refreshed" else "Ok"
end

-- Counts the potion down by `seconds`; clears it when it runs out.
function Potions.tick(state: State, seconds: number)
	if state.secondsLeft <= 0 then
		return
	end
	state.secondsLeft = math.max(0, state.secondsLeft - seconds)
	if state.secondsLeft == 0 then
		state.id = ""
	end
end

return Potions
