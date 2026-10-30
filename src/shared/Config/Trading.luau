--!strict
-- Trading and gifting monsters (Giles 2026-10-30). Only monsters ever change hands: items,
-- cash and passes stay with whoever bought them, so Roblox's regional prices can't be gamed
-- by passing on things bought cheaply in another country (server/PriceLevels has the
-- price-level check for Robux gifts later).
--   Trading  at the Trading Booth: both players stand at the booth, put any number of Backpack
--            monsters in, both press Ready, a short countdown, then they swap.
--   Gifting  anywhere: hold a monster from your Backpack and hold E on another player. They
--            have to accept it.
-- A traded or gifted monster loses its name tag and its heart.

local Trading = {}

Trading.TradeCooldown = 30 -- seconds after a finished trade before the same player can trade again
Trading.GiftCooldown = 10 -- seconds between gifts from one player
Trading.RequestCooldown = 5 -- seconds between trade requests from one player
Trading.AnswerSeconds = 20 -- how long a trade request or a gift waits for an answer
Trading.CountdownSeconds = 5 -- both Ready -> swap; any change stops it
Trading.GiftReach = 10 -- studs: how close you stand to someone to gift them a monster
Trading.GiftHoldSeconds = 1 -- how long E is held to offer a gift
Trading.LogKept = 20 -- trades and gifts remembered in each save (for checking scam reports)

return Trading
