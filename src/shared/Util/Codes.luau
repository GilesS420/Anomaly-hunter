--!strict
-- Reward code rules (the codes are in Config/Codes). Pure so they can be tested outside
-- Roblox; server/Services/CodesService keeps the used ones in the save (data.codes).

local Config = require("../Config/Codes")
local Playtime = require("./Playtime")
local Shop = require("../Config/Shop")

local Codes = {}

export type Reward = { cash: number, items: { { id: string, name: string, kind: string, count: number } } }

local MaxLength = 32

local items: { [string]: Shop.Item } = {}
for _, list in { Shop.Workshop, Shop.Bakery } do
	for _, item in list do
		items[item.id] = item
	end
end

local byCode: { [string]: Config.Code } = {}
for _, entry in Config do
	byCode[entry.code] = entry
end

-- What a typed code is matched as: capitals and digits only. Nil for anything that isn't a
-- short string.
function Codes.clean(typed: unknown): string?
	if typeof(typed) ~= "string" or #typed == 0 or #typed > MaxLength then
		return nil
	end
	local clean = string.upper((string.gsub(typed, "[^%w]", "")))
	return if #clean > 0 then clean else nil
end

function Codes.find(clean: string): Config.Code?
	return byCode[clean]
end

-- "ok", "used", "ended" or "unknown" for this typed code and the save's used codes.
function Codes.check(used: { [string]: boolean }, typed: unknown): (string, Config.Code?)
	local clean = Codes.clean(typed)
	local entry = if clean then byCode[clean] else nil
	if not entry then
		return "unknown", nil
	end
	if entry.ended then
		return "ended", entry
	end
	if used[entry.code] then
		return "used", entry
	end
	return "ok", entry
end

-- What a code pays a player with this base (Util/Playtime.base).
function Codes.reward(entry: Config.Code, base: number): Reward
	local cash = 0
	if entry.share then
		cash = math.max(entry.floor or 0, math.floor(math.max(0, base) * entry.share))
	end
	local list = {}
	local ids: { string } = {}
	local counts: { [string]: number } = entry.items or {}
	for id in counts do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local item = items[id]
		local count = counts[id]
		if item and count > 0 then
			table.insert(list, { id = item.id, name = item.name, kind = item.kind :: string, count = count })
		end
	end
	if entry.pickCake then
		local cake = Playtime.cake(base)
		if cake then
			table.insert(list, { id = cake.id, name = cake.name, kind = cake.kind :: string, count = 1 })
		end
	end
	return { cash = cash, items = list }
end

-- A broken or missing record of used codes becomes an empty one.
function Codes.repair(used: any): { [string]: boolean }
	if typeof(used) ~= "table" then
		return {}
	end
	for key, value in used do
		if typeof(key) ~= "string" or value ~= true then
			used[key] = nil
		end
	end
	return used
end

return Codes
