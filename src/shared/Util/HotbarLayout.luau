--!strict
-- Where each player keeps things on their hotbar, so it comes back the same after a respawn
-- or rejoin instead of filling up in whatever order the Tools arrive (Giles 2026-10-24).
-- A Tool is known by a key: "T:<item id>" for tools, "C:<item id>" for cakes and
-- "M:<monster uid>" for monsters. `slots` maps a key to its slot (one key per slot), and
-- `benched` lists the keys dragged off the bar (Backpack only). Slots stay remembered while
-- the Tool is gone (a used-up cake), until something else is put in that slot.
-- Saved in data.hotbar (server/Services/HotbarService), used by client HotbarController.

local HotbarLayout = {}

export type Layout = { slots: { [string]: number }, benched: { string } }

HotbarLayout.Slots = 9
HotbarLayout.MaxBenched = 100 -- oldest go first (sold monsters leave theirs behind)
local MaxKeyLength = 64

function HotbarLayout.new(): Layout
	return { slots = {}, benched = {} }
end

-- The key for a Tool's attributes, or nil if it has none of them.
function HotbarLayout.key(toolId: unknown, cakeId: unknown, monsterUid: unknown): string?
	if typeof(toolId) == "string" and toolId ~= "" then
		return "T:" .. toolId
	elseif typeof(cakeId) == "string" and cakeId ~= "" then
		return "C:" .. cakeId
	elseif typeof(monsterUid) == "string" and monsterUid ~= "" then
		return "M:" .. monsterUid
	end
	return nil
end

local function goodKey(key: unknown): boolean
	return typeof(key) == "string" and #key > 0 and #key <= MaxKeyLength
end

-- A valid copy of anything (from a save or a client): bad entries are dropped.
function HotbarLayout.clean(raw: unknown): Layout
	local layout = HotbarLayout.new()
	if typeof(raw) ~= "table" then
		return layout
	end
	local taken: { [number]: boolean } = {}
	local rawSlots = (raw :: any).slots
	if typeof(rawSlots) == "table" then
		local keys = {}
		for key in rawSlots do
			if goodKey(key) then
				table.insert(keys, key)
			end
		end
		table.sort(keys) -- a fixed order, so a clash keeps the same one every time
		for _, key in keys do
			local slot = rawSlots[key]
			if
				typeof(slot) == "number"
				and slot % 1 == 0
				and slot >= 1
				and slot <= HotbarLayout.Slots
				and not taken[slot]
			then
				taken[slot] = true
				layout.slots[key] = slot
			end
		end
	end
	local rawBenched = (raw :: any).benched
	if typeof(rawBenched) == "table" then
		for _, key in rawBenched do
			if goodKey(key) and not table.find(layout.benched, key) and not layout.slots[key] then
				table.insert(layout.benched, key)
			end
		end
		while #layout.benched > HotbarLayout.MaxBenched do
			table.remove(layout.benched, 1)
		end
	end
	return layout
end

-- `key` now sits in `slot`; whatever was remembered there before isn't any more.
function HotbarLayout.remember(layout: Layout, key: string, slot: number)
	for other, at in layout.slots do
		if at == slot and other ~= key then
			layout.slots[other] = nil
		end
	end
	layout.slots[key] = slot
	local index = table.find(layout.benched, key)
	if index then
		table.remove(layout.benched, index)
	end
end

-- `key` was taken off the bar (Backpack only).
function HotbarLayout.bench(layout: Layout, key: string)
	layout.slots[key] = nil
	if not table.find(layout.benched, key) then
		table.insert(layout.benched, key)
	end
	while #layout.benched > HotbarLayout.MaxBenched do
		table.remove(layout.benched, 1)
	end
end

function HotbarLayout.isBenched(layout: Layout, key: string): boolean
	return table.find(layout.benched, key) ~= nil
end

return HotbarLayout
