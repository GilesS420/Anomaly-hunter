--!strict
-- Hunter's Workshop rules: the restock timer, what's in stock and what a player may buy.
-- Stock is worked out from the 5-minute slot number alone, so every server shows the same
-- items at the same time and a restock can't be re-rolled by rejoining. Pure functions so
-- they can be tested outside Roblox.

local Effects = require("../Config/Effects")
local Shop = require("../Config/Shop")
local Sizes = require("../Config/Sizes")
local Tools = require("../Config/Tools")

local Workshop = {}

export type BuyResult = "Ok" | "Unknown" | "OutOfStock" | "Owned" | "SoldOut" | "TooPoor"
export type EquipSlot = "vacuum" | "flashlight" | "lens"

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

-- 32-bit FNV-1a hash. The multiply is split in two so it stays exact in a double.
local function hash(text: string): number
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296 -- h * 16777619, mod 2^32
	end
	return h
end

-- True if the item is for sale in this slot. Free starter tools always are.
function Workshop.inStock(item: Shop.Item, slot: number): boolean
	if item.price <= 0 then
		return true
	end
	local roll = (hash(`{slot}:{item.id}`) % 10000) / 100 -- 0 to 99.99
	return roll < item.restockChance
end

-- Tools are kept forever and equipped; everything else is used up.
function Workshop.isTool(item: Shop.Item): boolean
	return item.kind == "Vacuum" or item.kind == "Flashlight" or item.kind == "Lens"
end

function Workshop.equipSlot(item: Shop.Item): EquipSlot?
	if item.kind == "Vacuum" then
		return "vacuum"
	elseif item.kind == "Flashlight" then
		return "flashlight"
	elseif item.kind == "Lens" then
		return "lens"
	end
	return nil
end

-- True if the player has this tool (the free starter tools always count).
function Workshop.owns(inventory: { [string]: number }, item: Shop.Item): boolean
	return item.price <= 0 or (inventory[item.id] or 0) > 0
end

-- How many a player can buy in one restock.
function Workshop.limit(item: Shop.Item): number
	return if Workshop.isTool(item) then 1 else Shop.ConsumablesPerRestock
end

-- Whether a player can buy one now. boughtThisSlot is how many they bought since the restock.
function Workshop.canBuy(
	item: Shop.Item?,
	slot: number,
	money: number,
	inventory: { [string]: number },
	boughtThisSlot: number
): BuyResult
	if not item then
		return "Unknown"
	end
	if Workshop.isTool(item) and Workshop.owns(inventory, item) then
		return "Owned"
	end
	if not Workshop.inStock(item, slot) then
		return "OutOfStock"
	end
	if boughtThisSlot >= Workshop.limit(item) then
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

local function effectLine(effectId: string?): string
	return if effectId then `{Effects.CatchChance}% chance of {effectId} on catch` else ""
end

-- One short line saying what the item does, for the shop window.
function Workshop.describe(item: Shop.Item): string
	if item.kind == "Vacuum" then
		local vacuum = Tools.Vacuums[item.id]
		local tier = item.tier or 1
		local speed = if vacuum then ` · catches in {vacuum.catchSeconds}s` else ""
		local extra = if tier >= 3 then ", Mythic and Divine too" else ""
		return `Holds up to {biggestSize(tier)}{extra}{speed}`
	elseif item.kind == "Flashlight" then
		local light = Tools.Flashlights[item.id]
		local stats = if light then `Reach {light.reach} studs · stuns {light.stunSeconds}s` else ""
		local effect = effectLine(item.grantsEffect)
		return if effect ~= "" then `{stats} · {effect}` else stats
	elseif item.kind == "Lens" then
		return effectLine(item.grantsEffect)
	elseif item.kind == "Lure" then
		return "Ring it in a zone and a rarer monster comes to you"
	elseif item.kind == "Charm" then
		return "Takes you home from a zone, with your catch"
	end
	return ""
end

return Workshop
