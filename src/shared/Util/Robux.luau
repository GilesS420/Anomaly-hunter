--!strict
-- Robux purchase bookkeeping (products in Config/Robux). The save keeps a Record in
-- data.robux: which purchases were already paid out (so a receipt Roblox sends again never
-- pays twice), what the player tapped before the purchase prompt, and credits for anything
-- that was paid for but couldn't be handed out right away. Pure functions so they can be
-- tested outside Roblox; server/Services/RobuxService does the buying.

local Config = require("../Config/Robux")

local Robux = {}

export type Record = {
	receipts: { string }, -- purchase ids already paid out, newest last
	credits: { [string]: number }, -- product key -> paid for, not handed out yet
	pending: { [string]: any }, -- product key -> what the player tapped (item id, mission number)
	starter: boolean, -- bought the Starter Pack
	passes: { [string]: boolean }, -- Game Passes seen owned (in case Roblox can't be asked)
	reroll: { slot: number, salt: number }, -- the shop stock rerolled for this restock slot
	missionRerolls: { day: number, count: number }, -- Mission Rerolls bought today
	spent: number, -- Robux spent in all
}

function Robux.empty(): Record
	return {
		receipts = {},
		credits = {},
		pending = {},
		starter = false,
		passes = {},
		reroll = { slot = -1, salt = 0 },
		missionRerolls = { day = -1, count = 0 },
		spent = 0,
	}
end

-- Mends a record from a save (missing or broken parts back to empty) and returns it.
function Robux.repair(record: any): Record
	local fresh = Robux.empty()
	if typeof(record) ~= "table" then
		return fresh
	end
	for key, value in fresh :: any do
		if typeof(record[key]) ~= typeof(value) then
			record[key] = value
		end
	end
	return record :: Record
end

-- The item product key for a shop item that costs `cash`, or nil if it isn't sold (free).
function Robux.tierFor(cash: number): string?
	if not (cash > 0) then
		return nil
	end
	for _, tier in Config.ItemTiers do
		if cash <= tier.maxCash then
			return tier.product
		end
	end
	return nil
end

-- The product key a dashboard id belongs to, or nil (0, the not-set-up id, never matches).
function Robux.productKey(id: number): string?
	if id == 0 then
		return nil
	end
	for key, product in Config.Products do
		if product.id == id then
			return key
		end
	end
	return nil
end

-- The pass key a dashboard id belongs to, or nil.
function Robux.passKey(id: number): string?
	if id == 0 then
		return nil
	end
	for key, pass in Config.Passes do
		if pass.id == id then
			return key
		end
	end
	return nil
end

function Robux.hasReceipt(record: Record, purchaseId: string): boolean
	return table.find(record.receipts, purchaseId) ~= nil
end

-- Remembers a paid-out purchase, forgetting the oldest past Config.ReceiptsKept.
function Robux.addReceipt(record: Record, purchaseId: string)
	table.insert(record.receipts, purchaseId)
	while #record.receipts > Config.ReceiptsKept do
		table.remove(record.receipts, 1)
	end
end

function Robux.addCredit(record: Record, key: string)
	record.credits[key] = (record.credits[key] or 0) + 1
end

-- Uses up one credit for `key`. False if there was none.
function Robux.takeCredit(record: Record, key: string): boolean
	local count = record.credits[key] or 0
	if count <= 0 then
		return false
	end
	record.credits[key] = if count > 1 then count - 1 else nil
	return true
end

-- The salt for this restock slot's stock if the player rerolled it, else nil (normal stock).
function Robux.stockSalt(record: Record, slot: number): number?
	return if record.reroll.slot == slot then record.reroll.salt else nil
end

-- How many Mission Rerolls the player bought on `day`.
function Robux.rerollsBought(record: Record, day: number): number
	return if record.missionRerolls.day == day then record.missionRerolls.count else 0
end

function Robux.countReroll(record: Record, day: number)
	record.missionRerolls = { day = day, count = Robux.rerollsBought(record, day) + 1 }
end

return Robux
