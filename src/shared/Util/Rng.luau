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

-- 32-bit FNV-1a hash of a string. The multiply is split in two so it stays exact in a double.
function Rng.hash(text: string): number
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296 -- h * 16777619, mod 2^32
	end
	return h
end

-- A stand-in for Random whose rolls come only from `key`: the same key gives the same rolls
-- in every server (and outside Roblox), unlike Random.new().
function Rng.seeded(key: string): Random
	local count = 0
	local seeded = {}
	function seeded.NextNumber(_self: any, min: number?, max: number?): number
		count += 1
		local x = Rng.hash(`{key}:{count}`) / 4294967296
		local low = min or 0
		return low + ((max or 1) - low) * x
	end
	return seeded :: any
end

-- True with the given chance in percent (0 to 100).
function Rng.chance(percent: number, random: Random?): boolean
	local rng = random or Random.new()
	return rng:NextNumber() * 100 < percent
end

return Rng
