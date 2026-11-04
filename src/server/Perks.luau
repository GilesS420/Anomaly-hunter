--!strict
-- What a player's Game Passes change (Config/Robux). RobuxService sets the player attribute
-- Pass<Key> (PassVIP, PassBigStorage...) once it knows they own one, and the other services
-- ask here, so none of them has to require RobuxService. Attributes set by a client never
-- reach the server, so they can't be faked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CakeConfig = require(ReplicatedStorage.Shared.Config.Cakes)
local Community = require(ReplicatedStorage.Shared.Config.Community)
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

export type Bonus = { label: string, percent: number }

-- The player's own Collector bonuses, in whole percents (the Collector adds a live Watcher
-- event's on top and shows them all at the top of the sell window): Roblox friends in this
-- server, VIP and the Hunter's Guild (CommunityService sets FriendsHere and InGuild).
function Perks.sellBonuses(player: Player): { Bonus }
	local list: { Bonus } = {}
	local friends = tonumber(player:GetAttribute("FriendsHere")) or 0
	if friends > 0 then
		table.insert(list, {
			label = if friends == 1 then "friend bonus (1 friend)" else `friend bonus ({friends} friends)`,
			percent = math.floor(friends * Community.FriendSellBonus * 100 + 0.5),
		})
	end
	if Perks.has(player, "VIP") then
		table.insert(list, { label = "VIP", percent = math.floor((Robux.VipSellBoost - 1) * 100 + 0.5) })
	end
	if player:GetAttribute("InGuild") == true then
		table.insert(list, { label = "Guild", percent = math.floor(Community.GuildSellBonus * 100 + 0.5) })
	end
	return list
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
