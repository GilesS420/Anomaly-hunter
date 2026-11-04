--!strict
-- The Hunter's Guild (Giles 2026-11-04): the game's Roblox group. Players join it at the
-- Guild stand by Watcher Square (press E, "Join the Guild!") or from Settings, never from a
-- pop-up. Roblox shows its own Join Group window; the first time a player is in the group
-- they get a one-time gift, and while they're in it the Collector pays them a little more and
-- a purple "Guild" tag floats over their head (server/Services/CommunityService).
--
-- Roblox has no way for a game to open the like or favourite button, or to see who liked the
-- game, so the stand only asks players to like it, with no reward (rewarding likes would be
-- bait Roblox doesn't allow).

local Community = {}

-- The group's id: the number in the group's web address,
-- roblox.com/communities/<this number>/... While it's 0 the stand says the Guild isn't open yet.
Community.GroupId = 0

-- The one-time gift for joining, as shop item ids -> how many (Config/Shop).
Community.Gift = { GoldBell = 1 } :: { [string]: number }
Community.GiftText = "a Gold Bait Bell"

-- The Collector pays Guild members this much more (stacks with VIP).
Community.SellBoost = 1.05

-- Seconds between two gift checks per player (each one asks Roblox's group list).
Community.ClaimCooldown = 5

return Community
