--!strict
-- The Hunter's Guild (Giles 2026-11-04): the game's Roblox group. Players join it at the
-- Guild stand in front of the shops (press E, "Join the Guild!") or from Settings: Roblox's
-- own Join Group window opens right there in the game. The first time a player is in the
-- group they get a one-time gift, and while they're in it the Collector pays them a little
-- more and a purple "Guild" tag floats over their head (server/Services/CommunityService).
--
-- The stand and Settings also open Roblox's Favourite window for the game. Roblox has no
-- window for the like (thumbs up) button, so the stand can only ask players to like it on the
-- game page. Neither gives a reward: Roblox can't tell the game who liked it, and paying for
-- likes is bait Roblox doesn't allow.

local Community = {}

-- The group's id: the number in the group's web address,
-- roblox.com/communities/<this number>/... While it's 0 the stand says the Guild isn't open yet.
Community.GroupId = 314237203 -- Hunt a Monster Hunters (Giles 2026-11-04)

-- The one-time gift for joining, as shop item ids -> how many (Config/Shop).
Community.Gift = { GoldBell = 1 } :: { [string]: number }
Community.GiftText = "a Gold Bait Bell"

-- The Collector pays Guild members this much more (stacks with VIP).
Community.SellBoost = 1.05

-- Seconds between two gift checks per player (each one asks Roblox's group list).
Community.ClaimCooldown = 5

return Community
