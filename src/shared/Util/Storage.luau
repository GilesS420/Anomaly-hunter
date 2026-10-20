--!strict
-- Monster Storage rules (size in Config/Inventory). A stored monster is paused: storing it
-- brings it up to date and notes the time; taking it out moves its feeding, growing and weight clocks
-- forward by the time it spent stored, so it comes back exactly as it went in.
-- Pure functions so they can be tested outside Roblox.

local InventoryConfig = require("../Config/Inventory")
local Care = require("./Care")
local Value = require("./Value")
local Weight = require("./Weight")

local Storage = {}

function Storage.hasRoom(storedCount: number): boolean
	return storedCount < InventoryConfig.StorageSlots
end

-- Call when a monster goes into Storage.
function Storage.store(caught: Value.CaughtMonster, now: number)
	Care.settle(caught, now)
	if caught.kg then
		Weight.settle(caught, now) -- (one without a weight gets it in the mansion)
	end
	caught.storedAt = now
end

-- Call when a monster comes out of Storage, before it goes back into the mansion.
function Storage.unstore(caught: Value.CaughtMonster, now: number)
	local paused = math.max(0, now - (caught.storedAt or now))
	if caught.grownAt then
		caught.grownAt = math.min(caught.grownAt + paused, now)
	end
	if caught.kgAt then
		caught.kgAt = math.min(caught.kgAt + paused, now)
	end
	caught.storedAt = nil
	Care.settle(caught, now)
end

return Storage
