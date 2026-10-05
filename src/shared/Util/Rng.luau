--!strict
-- Weighted random picks. Pass a Random so tests (and server seeds) are reproducible.

local Rng = {}

-- Picks one entry from a list using each entry's weight (from getWeight).
function Rng.pickWeighted<T>(list: { T }, getWeight: (T) -> number, random: Random?): T
	local rng = random or Random.new()
	local total = 0
	for _, entry in list do
		total += getWeight(entry)
	end
	assert(total > 0, "pickWeighted needs a positive total weight")

	local roll = rng:NextNumber() * total
	for _, entry in list do
		roll -= getWeight(entry)
		if roll < 0 then
			return entry
		end
	end
	return list[#list]
end

-- True with the given chance in percent (0 to 100).
function Rng.chance(percent: number, random: Random?): boolean
	local rng = random or Random.new()
	return rng:NextNumber() * 100 < percent
end

return Rng
