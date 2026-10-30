--!strict
-- Roblox's regional prices (create.roblox.com/docs/production/monetization/regional-pricing):
-- Roblox can sell passes and products cheaper in some countries, and gives every player a
-- price level from 1 to 1000 (1000 pays the full price). Anything bought with Robux may only
-- go from one player to another when the levels allow it:
--   a gift  only when the giver's level is the same or higher than the receiver's
--   a trade only when both levels are the same
-- Roblox asks for the levels when a player joins and never keeps them past their visit, so
-- they live in memory here and are asked again right before a transfer.
-- Monsters are never sold for Robux, so monster trades and gifts don't need this; it's ready
-- for Robux gifts (after launch), and Roblox wants it in place before managed pricing can be
-- turned on for Developer Products.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PriceLevels = {}

local levels: { [Player]: number } = {}
local warned = false

-- The levels of these players straight from Roblox, or nil if Roblox can't be asked.
local function fetch(players: { Player }): { [Player]: number }?
	local ids = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	local ok, result = pcall(function()
		return (MarketplaceService :: any):GetUsersPriceLevelsAsync(ids)
	end)
	if not ok or typeof(result) ~= "table" then
		if not warned then -- once is enough (Studio play tests often can't ask)
			warned = true
			warn(`PriceLevels: couldn't get price levels: {result}`)
		end
		return nil
	end
	local byId: { [number]: number } = {}
	for _, info in result do
		if typeof(info) == "table" and typeof(info.UserId) == "number" and typeof(info.PriceLevel) == "number" then
			byId[info.UserId] = info.PriceLevel
		end
	end
	local found: { [Player]: number } = {}
	for _, player in players do
		local level = byId[player.UserId]
		if not level then
			return nil
		end
		found[player] = level
		if player.Parent == Players then
			levels[player] = level
		end
	end
	return found
end

-- The player's level as of when they joined (or the last check), nil if it isn't known.
function PriceLevels.get(player: Player): number?
	return levels[player]
end

-- May `giver` give `receiver` something bought with Robux? Asks Roblox again first; says no
-- when Roblox can't be asked.
function PriceLevels.canGift(giver: Player, receiver: Player): boolean
	local found = fetch({ giver, receiver })
	return found ~= nil and found[giver] >= found[receiver]
end

-- May these two trade things bought with Robux? Same rule as canGift: no when unknown.
function PriceLevels.canTrade(a: Player, b: Player): boolean
	local found = fetch({ a, b })
	return found ~= nil and found[a] == found[b]
end

function PriceLevels.start()
	local function joined(player: Player)
		fetch({ player })
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		task.spawn(joined, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		levels[player] = nil
	end)
end

return PriceLevels
