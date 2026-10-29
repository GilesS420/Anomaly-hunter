--!strict
-- What a player's Game Passes change (Config/Robux). RobuxService sets the player attribute
-- Pass<Key> (PassVIP, PassBigStorage...) once it knows they own one, and the other services
-- ask here, so none of them has to require RobuxService. Attributes set by a client never
-- reach the server, so they can't be faked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CakeConfig = require(ReplicatedStorage.Shared.Config.Cakes)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.Inventory)
local Robux = require(ReplicatedStorage.Shared.Config.Robux)

local Perks = {}

function Perks.has(player: Player, pass: string): boolean
	return player:GetAttribute(`Pass{pass}`) == true
end

-- How many monsters fit in the player's Storage.
function Perks.storageSlots(player: Player): number
	return if Perks.has(player, "BigStorage") then Robux.BigStorageSlots else InventoryConfig.StorageSlots
end

-- How many cakes can stand out per owned wing.
function Perks.cakesPerWing(player: Player): number
	return if Perks.has(player, "CakePlate") then Robux.CakePlatePerWing else CakeConfig.PerWing
end

-- Multiplies the chance of a Silver, Gold, Shiny or Rainbow catch (Lucky Hunter and VIP stack).
function Perks.variantBoost(player: Player): number
	local boost = 1
	if Perks.has(player, "LuckyHunter") then
		boost *= Robux.LuckyHunterBoost
	end
	if Perks.has(player, "VIP") then
		boost *= Robux.VipLuckBoost
	end
	return boost
end

-- What the Collector's prices are multiplied by for this player.
function Perks.sellBoost(player: Player): number
	return if Perks.has(player, "VIP") then Robux.VipSellBoost else 1
end

-- What the player's walking speed is multiplied by (Faster walking speed pass).
function Perks.walkMultiplier(player: Player): number
	return if Perks.has(player, "FastWalk") then Robux.FastWalkMultiplier else 1
end

-- Extra free mission rerolls a day.
function Perks.extraRerolls(player: Player): number
	return if Perks.has(player, "VIP") then Robux.VipRerolls else 0
end

return Perks
