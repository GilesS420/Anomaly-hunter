--!strict
-- Trading and gifting rules (numbers in Config/Trading). Pure functions so they can be tested
-- outside Roblox; server/Services/TradeService does the rest.

local Value = require("./Value")

local Trading = {}

export type Problem = "Missing" | "Hearted" | "Twice"

-- Why this Backpack can't give these monsters, or nil if it can. `storage` is the giver's
-- Backpack (data.storage); only monsters in it can be traded or gifted.
function Trading.problem(storage: { Value.CaughtMonster }, uids: { string }): Problem?
	local byUid: { [string]: Value.CaughtMonster } = {}
	for _, caught in storage do
		if caught.uid then
			byUid[caught.uid] = caught
		end
	end
	local seen: { [string]: boolean } = {}
	for _, uid in uids do
		if seen[uid] then
			return "Twice"
		end
		seen[uid] = true
		local caught = byUid[uid]
		if not caught then
			return "Missing"
		end
		if caught.locked then
			return "Hearted"
		end
	end
	return nil
end

-- True if a Backpack with `count` monsters still fits after giving `giving` and getting
-- `getting` (a trade can't push anyone over their Storage size).
function Trading.fits(count: number, giving: number, getting: number, slots: number): boolean
	return getting <= giving or count - giving + getting <= slots
end

-- What changes when a monster gets a new owner: its name tag and heart come off (Giles
-- 2026-10-30). Everything else (weight, effects, variant, familiarity) goes with it.
function Trading.handOver(caught: Value.CaughtMonster)
	caught.nickname = nil
	caught.locked = nil
end

-- One line for the trade log in a save.
export type LogEntry = {
	at: number, -- os.time()
	kind: string, -- "Trade", "GiftSent" or "GiftGot"
	with: number, -- the other player's UserId
	gave: { string }, -- monster names
	got: { string },
}

-- Adds an entry to a save's log, keeping only the newest `kept`.
function Trading.log(list: { LogEntry }, entry: LogEntry, kept: number)
	table.insert(list, entry)
	while #list > kept do
		table.remove(list, 1)
	end
end

return Trading
