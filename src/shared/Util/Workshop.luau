--!strict
-- Shop rules: the restock timer, what's in stock and what a player may buy. Used by the
-- Hunter's Workshop and, for the stock and timer, the Haunted Bakery.
-- Stock is worked out from the 5-minute slot number alone, so every server shows the same
-- items at the same time and a restock can't be re-rolled by rejoining. Pure functions so
-- they can be tested outside Roblox.

local Effects = require("../Config/Effects")
local Events = require("../Config/Events")
local Monsters = require("../Config/Monsters")
local Shop = require("../Config/Shop")
local Sizes = require("../Config/Sizes")
local Tools = require("../Config/Tools")
local Variants = require("../Config/Variants")
local Rng = require("./Rng")

local Workshop = {}

export type BuyResult = "Ok" | "Unknown" | "OutOfStock" | "Owned" | "SoldOut" | "TooPoor"
export type EquipSlot = "vacuum"

local byId: { [string]: Shop.Item } = {}
for _, item in Shop.Workshop do
	byId[item.id] = item
end

function Workshop.item(id: string): Shop.Item?
	return byId[id]
end

-- Which 5-minute restock a moment (os.time / server time, in seconds) falls in.
function Workshop.slotAt(time: number): number
	return math.floor(time / Shop.RestockSeconds)
end

-- When the slot after this one starts (seconds, same clock as slotAt).
function Workshop.restockAt(slot: number): number
	return (slot + 1) * Shop.RestockSeconds
end

-- What a player bought since the last restock (item id -> how many), from their save's shop
-- record. Clears it when a new restock has started. The Workshop and the Bakery share it.
function Workshop.boughtThisSlot(
	shop: { slot: number, bought: { [string]: number } },
	slot: number
): { [string]: number }
	if shop.slot ~= slot then
		shop.slot = slot
		shop.bought = {}
	end
	return shop.bought
end

local hash = Rng.hash

-- True if the item is for sale in this slot. Vacuums always are (they're expensive, so a
-- player who saved up never waits on luck: Giles 2026-10-22); an event treat
-- is exactly while its Watcher event (`liveEvent`, an id) is live. `chanceMultiplier` raises
-- the restock chances (Sugar Rush), and anything in stock without it stays in stock.
function Workshop.inStock(
	item: Shop.Item,
	slot: number,
	liveEvent: string?,
	chanceMultiplier: number?
): boolean
	if item.event then
		return item.event == liveEvent
	end
	if item.price <= 0 or item.kind == "Vacuum" then
		return true
	end
	local roll = (hash(`{slot}:{item.id}`) % 10000) / 100 -- 0 to 99.99
	return roll < item.restockChance * math.max(chanceMultiplier or 1, 1)
end

-- Tools (vacuums) are kept forever and equipped; everything else is used up.
function Workshop.isTool(item: Shop.Item): boolean
	return item.kind == "Vacuum"
end

function Workshop.equipSlot(item: Shop.Item): EquipSlot?
	return if item.kind == "Vacuum" then "vacuum" else nil
end

-- Takes retired tools (Shop.Retired: flashlights, the Spirit Lens) out of an inventory and
-- returns the cash they're worth back. 0 if there were none.
function Workshop.refundRetired(inventory: { [string]: number }): number
	local refund = 0
	local items: { [string]: number? } = inventory
	for id, price in Shop.Retired do
		if (items[id] or 0) > 0 then
			refund += price
			items[id] = nil
		end
	end
	return refund
end

-- True if the player has this tool (the free starter tools always count).
function Workshop.owns(inventory: { [string]: number }, item: Shop.Item): boolean
	return item.price <= 0 or (inventory[item.id] or 0) > 0
end

-- How many a player can buy in one restock: one tool, or a random number of a single-use item
-- (Shop.StockMin to StockMax), worked out from the slot like the stock itself.
function Workshop.limit(item: Shop.Item, slot: number): number
	if Workshop.isTool(item) then
		return 1
	end
	local spread = Shop.StockMax - Shop.StockMin + 1
	return Shop.StockMin + hash(`{slot}:{item.id}:count`) % spread
end

-- Whether a player can buy one now. boughtThisSlot is how many they bought since the restock.
function Workshop.canBuy(
	item: Shop.Item?,
	slot: number,
	money: number,
	inventory: { [string]: number },
	boughtThisSlot: number,
	liveEvent: string?,
	chanceMultiplier: number?
): BuyResult
	if not item then
		return "Unknown"
	end
	if Workshop.isTool(item) and Workshop.owns(inventory, item) then
		return "Owned"
	end
	if not Workshop.inStock(item, slot, liveEvent, chanceMultiplier) then
		return "OutOfStock"
	end
	if boughtThisSlot >= Workshop.limit(item, slot) then
		return "SoldOut"
	end
	if money < item.price then
		return "TooPoor"
	end
	return "Ok"
end

-- Biggest monster size a vacuum tier can hold ("Normal", "Huge", "Colossal").
local function biggestSize(tier: number): string
	local biggest = "nothing"
	for _, size in Sizes do
		if size.vacuumTier <= tier then
			biggest = size.id
		end
	end
	return biggest
end

-- "Gold 3% · Silver 5%", rarest first.
local function variantLine(chances: { [string]: number }?): string
	local parts = {}
	for _, variant in Variants do
		local chance = if chances then chances[variant.id] else nil
		if chance then
			table.insert(parts, `{variant.id} {chance}%`)
		end
	end
	return table.concat(parts, " · ")
end

-- The event monsters this vacuum is the first to catch, by event or Watcher set name
-- ("Blood Moon"), sorted.
function Workshop.unlocksEvents(vacuumId: string): { string }
	local names: { string } = {}
	local function add(name: string)
		if not table.find(names, name) then
			table.insert(names, name)
		end
	end
	for _, event in Events.List do
		local monsters: { [string]: number } = event.monsters or {}
		for id in monsters do
			if Monsters[id] and Monsters[id].vacuum == vacuumId then
				add(event.name)
			end
		end
		local sets: { Events.MonsterSet } = event.monsterSets or {}
		for _, set in sets do
			for id in set.monsters do
				if Monsters[id] and Monsters[id].vacuum == vacuumId then
					add(set.name)
				end
			end
		end
	end
	table.sort(names)
	return names
end

-- One short line saying what the item does, for the shop window.
function Workshop.describe(item: Shop.Item): string
	if item.kind == "Vacuum" then
		local vacuum = Tools.Vacuums[item.id]
		if not vacuum then
			return ""
		end
		local tier = item.tier or 1
		local extra = if tier >= 3 then ", Mythic and Divine too" else ""
		local parts = {
			`Carries {vacuum.bag} · up to {biggestSize(tier)}{extra}`,
			`catches in {vacuum.catchSeconds}s · reach {vacuum.reach}`,
		}
		local events = Workshop.unlocksEvents(item.id)
		if #events > 0 then
			table.insert(parts, `catches {table.concat(events, " and ")} monsters`)
		end
		local catchEffects: { string } = vacuum.catchEffects or {}
		for _, effectId in catchEffects do
			table.insert(parts, `{Effects.CatchChance}% {effectId}`)
		end
		local variants = variantLine(vacuum.variants)
		if variants ~= "" then
			table.insert(parts, variants)
		end
		return table.concat(parts, " · ")
	elseif item.kind == "Lure" then
		local odds = item.lureOdds
		if odds then
			local parts = {}
			for _, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine" } do
				if odds[rarity] then
					table.insert(parts, `{rarity} {odds[rarity]}%`)
				end
			end
			return `Ring it in a zone: {table.concat(parts, " · ")} comes to you`
		end
		local steps = item.lureSteps or 1
		local up = if steps == 1 then "one rarity" else `{steps} rarities`
		local cap = if item.maxRarity then `, up to {item.maxRarity}` else ""
		return `Ring it in a zone: a monster {up} rarer comes to you{cap}`
	elseif item.kind == "Charm" then
		return "Takes you home from a zone, with your catch"
	end
	return ""
end

return Workshop
