--!strict
-- Which catches are rare enough to show off, and the words for it (numbers in
-- Config/RareCatch). Pure, so tests/run.luau checks it.

local Config = require("../Config/RareCatch")

local RareCatch = {}

export type Level = "None" | "Reveal" | "Server" | "Global"

local Rank: { [string]: number } = { None = 0, Reveal = 1, Server = 2, Global = 3 }
local Names: { [number]: Level } = { [0] = "None", "Reveal", "Server", "Global" }

function RareCatch.rank(level: string): number
	return Rank[level] or 0
end

-- The level for a catch of this rarity and variant (nil variant = plain).
function RareCatch.level(rarityId: string, variant: string?): Level
	local rank = Rank[Config.ByRarity[rarityId] or "None"] or 0
	if variant then
		local byVariant = Rank[Config.ByVariant[variant] or "None"] or 0
		if variant == "Rainbow" and Config.RainbowStepsUp and rank >= Rank.Server then
			byVariant = Rank.Global
		end
		rank = math.max(rank, byVariant)
	end
	return Names[math.min(rank, 3)]
end

-- True when the whole server hears about it.
function RareCatch.shouts(level: string): boolean
	return RareCatch.rank(level) >= Rank.Server
end

-- The reveal card colour (RGB 0-255).
function RareCatch.color(rarityId: string, variant: string?): { number }
	if variant == "Rainbow" then
		return Config.RainbowColor
	end
	return Config.Colors[rarityId] or { 255, 255, 255 }
end

-- "Rainbow Divine" / "Mythic": the big word on the card.
function RareCatch.title(rarityId: string, variant: string?): string
	return if variant then `{variant} {rarityId}` else rarityId
end

-- The chat line: "Giles caught a Rainbow Divine Pale Stalker!" (displayName is the Roblox
-- display name, which Roblox has already filtered; monsterName is our own config text).
function RareCatch.line(displayName: string, monsterName: string, rarityId: string, variant: string?): string
	local what = RareCatch.title(rarityId, variant)
	local article = if string.match(what, "^[AEIOUaeiou]") then "an" else "a"
	return `{displayName} caught {article} {what} {monsterName}!`
end

return RareCatch
