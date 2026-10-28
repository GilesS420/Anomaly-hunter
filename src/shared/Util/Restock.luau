--!strict
-- Admin restocks: an admin picks which shop items are in stock and how many of each a player
-- can buy, for a while (server/AdminRestock keeps it, DevService's /restock starts it). This
-- reads the command, so it can be tested outside Roblox.
--
--   /restock cakes 10                    every Bakery cake, 10 each
--   /restock PumpkinCandy 10 BaitBell 5  just those two
--   /restock all 3 VoidVelvet 0          everything 3 each, but no Void Velvet (0 = sold out)
--   /restock cakes 10 time 15            lasts 15 minutes instead of 5
--
-- Names are item ids in any capitals, or a group: "cakes" (the Bakery), "workshop" or "all".
-- Groups leave out event treats (name one to sell it outside its event). Vacuums and slappers
-- are bought once and always in stock, so they can't be restocked. A later name wins over an
-- earlier one.

local Shop = require("../Config/Shop")

local Restock = {}

Restock.MaxAmount = 999
Restock.DefaultMinutes = Shop.RestockSeconds / 60
Restock.MaxMinutes = 120

export type Plan = { items: { [string]: number }, minutes: number }

-- Vacuums and slappers are always in stock and bought once.
local function restockable(item: Shop.Item): boolean
	return item.kind ~= "Vacuum" and item.kind ~= "Slapper"
end

-- Every item an admin can restock, Bakery first, in shop order.
function Restock.items(): { Shop.Item }
	local list: { Shop.Item } = {}
	for _, shop in { Shop.Bakery, Shop.Workshop } do
		for _, item in shop do
			if restockable(item) then
				table.insert(list, item)
			end
		end
	end
	return list
end

-- True if the item is a Bakery cake (the rest are Workshop items).
function Restock.isCake(itemId: string): boolean
	for _, item in Shop.Bakery do
		if item.id == itemId then
			return true
		end
	end
	return false
end

local groups: { [string]: { Shop.Item } } = {}
for _, name in { "cakes", "bakery", "workshop", "all" } do
	groups[name] = {}
end
for _, item in Restock.items() do
	if not item.event then
		local cake = Restock.isCake(item.id)
		table.insert(groups.all, item)
		table.insert(groups[if cake then "cakes" else "workshop"], item)
	end
end
groups.bakery = groups.cakes

local byName: { [string]: Shop.Item } = {}
for _, shop in { Shop.Bakery, Shop.Workshop } do
	for _, item in shop do
		byName[string.lower(item.id)] = item
	end
end

local Usage = "Try: /restock cakes 10, /restock PumpkinCandy 10 BaitBell 5 or /restock all 3 time 15"

-- The plan for a /restock argument, or nil and what's wrong with it.
function Restock.parse(argument: string?): (Plan?, string?)
	local words = string.split(string.lower(argument or ""), " ")
	local tokens: { string } = {}
	for _, word in words do
		if word ~= "" then
			table.insert(tokens, word)
		end
	end
	if #tokens == 0 or #tokens % 2 ~= 0 then
		return nil, Usage
	end
	local plan: Plan = { items = {}, minutes = Restock.DefaultMinutes }
	local any = false
	for i = 1, #tokens, 2 do
		local name, amount = tokens[i], tonumber(tokens[i + 1])
		if not amount or amount ~= amount then
			return nil, `"{tokens[i + 1]}" isn't a number. {Usage}`
		end
		amount = math.floor(amount)
		if name == "time" then
			if amount < 1 or amount > Restock.MaxMinutes then
				return nil, `Time is in minutes, 1 to {Restock.MaxMinutes}.`
			end
			plan.minutes = amount
			continue
		end
		if amount < 0 or amount > Restock.MaxAmount then
			return nil, `Amounts go from 0 to {Restock.MaxAmount}.`
		end
		local group = groups[name]
		local item = byName[name]
		if group then
			for _, member in group do
				plan.items[member.id] = amount
			end
		elseif item and not restockable(item) then
			return nil, `The {item.name} is always in stock (it's bought once), so it can't be restocked.`
		elseif item then
			plan.items[item.id] = amount
		else
			return nil, `There's no shop item called "{tokens[i]}". {Usage}`
		end
		any = true
	end
	if not any then
		return nil, Usage
	end
	return plan, nil
end

-- The argument that gives this plan back (the admin panel builds one to send).
function Restock.argument(items: { [string]: number }, minutes: number?): string
	local ids: { string } = {}
	for id in items do
		table.insert(ids, id)
	end
	table.sort(ids)
	local parts: { string } = {}
	for _, id in ids do
		table.insert(parts, `{id} {items[id]}`)
	end
	if minutes and minutes ~= Restock.DefaultMinutes then
		table.insert(parts, `time {minutes}`)
	end
	return table.concat(parts, " ")
end

return Restock
