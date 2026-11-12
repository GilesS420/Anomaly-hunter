--!strict
-- Rare catch moments (thread "Add patterns from top Roblox games", 2026-11-11). Top games
-- (Steal a Brainrot, Fisch, Grow a Garden) light up the chat when someone finds something
-- rare; we do the same, plus a short reveal card for the catcher. Rules in Util/RareCatch.
--
-- Each catch gets one level, the highest that fits:
--   "Reveal"  only the catcher sees a reveal card in the rarity's colour
--   "Server"  reveal + a banner and a chat line for everyone in this server
--   "Global"  as Server, plus a chat line in every other server

local RareCatch = {}

-- By rarity (Config/Rarities ids). Missing = nothing special.
RareCatch.ByRarity = {
	Epic = "Reveal",
	Legendary = "Reveal",
	Phantom = "Reveal",
	Mythic = "Server",
	Nightmare = "Server",
	Divine = "Global",
	Eldritch = "Global",
} :: { [string]: string }

-- By catch variant (Config/Variants ids): at least this level, whatever the rarity.
RareCatch.ByVariant = {
	Gold = "Reveal",
	Shiny = "Reveal",
	Rainbow = "Server",
} :: { [string]: string }

-- A Rainbow on a monster that is already Server level or higher goes Global.
RareCatch.RainbowStepsUp = true

-- Reveal card colour per rarity (RGB). Same colours as the monsters' orbs (MonsterModel).
RareCatch.Colors = {
	Common = { 170, 170, 170 },
	Uncommon = { 80, 210, 90 },
	Rare = { 60, 140, 255 },
	Epic = { 170, 80, 255 },
	Legendary = { 255, 150, 30 },
	Mythic = { 255, 55, 55 },
	Divine = { 255, 245, 170 },
	Phantom = { 200, 215, 255 },
	Nightmare = { 230, 40, 150 },
	Eldritch = { 40, 255, 200 },
} :: { [string]: { number } }

RareCatch.RainbowColor = { 255, 120, 220 }

-- At most this many cross-server shout-outs sent per server per minute (MessagingService
-- has a budget; Divines are rare, so this only matters in a burst).
RareCatch.GlobalPerMinute = 6

return RareCatch
