--!strict
-- An admin restock in this server (DevService's /restock, the admin panel's Restock tab;
-- Util/Restock reads the command). For a few minutes the picked items are in stock with the
-- picked amount per player, instead of the normal 5-minute stock; everything else stays as it
-- was. What each player buys counts from the admin restock, not against their normal limit.
-- Starting a new one replaces the old one and everyone can buy the full amounts again.
-- Kept in memory only: it's gone when the server closes, and other servers don't have it.
--
-- Workspace attributes, so clients can follow it:
--   AdminRestockEnd  number (os.time) when it ends, nil when there's none
--   ShopRestock      number that goes up each time one starts or ends: open shop windows
--                    fetch their stock again

local Players = game:GetService("Players")

local AdminRestock = {}

type Current = { items: { [string]: number }, endsAt: number }

local current: Current? = nil
local bought: { [number]: { [string]: number } } = {} -- UserId -> item id -> how many
local changes = 0

local function changed()
	changes += 1
	workspace:SetAttribute("AdminRestockEnd", if current then current.endsAt else nil)
	workspace:SetAttribute("ShopRestock", changes)
end

local function live(): Current?
	local restock = current
	if restock and os.time() >= restock.endsAt then
		current = nil
		bought = {}
		changed()
		return nil
	end
	return restock
end

-- Starts one: `items` is item id -> how many each player can buy (0 = sold out).
function AdminRestock.start(items: { [string]: number }, seconds: number)
	current = { items = table.clone(items), endsAt = os.time() + math.floor(seconds) }
	bought = {}
	changed()
	local mine = current
	task.delay(seconds + 0.5, function()
		if current == mine then
			live() -- tell the clients it's over
		end
	end)
end

-- Ends the one that's on. False if there wasn't one.
function AdminRestock.stop(): boolean
	if not live() then
		return false
	end
	current = nil
	bought = {}
	changed()
	return true
end

-- How many of an item each player can buy in the admin restock, or nil if it's not in one.
function AdminRestock.stock(itemId: string): number?
	local restock = live()
	return if restock then restock.items[itemId] else nil
end

-- What a player bought since the admin restock started (item id -> how many). Add to it.
function AdminRestock.bought(player: Player): { [string]: number }
	local mine = bought[player.UserId]
	if not mine then
		mine = {}
		bought[player.UserId] = mine
	end
	return mine
end

-- Seconds until it ends, or nil if there's none.
function AdminRestock.secondsLeft(): number?
	local restock = live()
	return if restock then restock.endsAt - os.time() else nil
end

-- Shop windows count down to whichever comes first: the next normal restock or the end of
-- the admin one.
function AdminRestock.countdown(normalSeconds: number): number
	local left = AdminRestock.secondsLeft()
	return if left then math.min(left, normalSeconds) else normalSeconds
end

Players.PlayerRemoving:Connect(function(player)
	-- Kept while the restock lasts, so leaving and rejoining doesn't refill anyone's stock.
	if not current then
		bought[player.UserId] = nil
	end
end)

return AdminRestock
