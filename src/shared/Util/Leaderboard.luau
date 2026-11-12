--!strict
-- What the hub leaderboards rank (server/Services/LeaderboardService). Pure so it can be
-- tested outside Roblox.

local Leaderboard = {}

-- OrderedDataStore values must be whole numbers that fit; anything else becomes 0.
local MaxValue = 2 ^ 53

function Leaderboard.clean(value: number): number
	if typeof(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.floor(math.min(value, MaxValue))
end

-- Codex finds: every monster and colour (variant) caught at least once.
function Leaderboard.finds(codex: { [string]: any }): number
	local monsters = codex.monsters
	if typeof(monsters) ~= "table" then
		return 0
	end
	local count = 0
	for _, variants in monsters do
		if typeof(variants) == "table" then
			for _, seen in variants do
				if seen then
					count += 1
				end
			end
		end
	end
	return count
end

return Leaderboard
