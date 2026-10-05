--!strict
-- Text formatting shared by server messages and client UI.

local Format = {}

local suffixes: { { size: number, letter: string } } = {
	{ size = 1e12, letter = "T" },
	{ size = 1e9, letter = "B" },
	{ size = 1e6, letter = "M" },
	{ size = 1e3, letter = "K" },
}

-- $1,500 -> "$1.5K", 1000000 -> "$1M", 2500000 -> "$2.5M". Below 1,000 it's exact.
function Format.money(amount: number): string
	local sign = if amount < 0 then "-" else ""
	local value = math.abs(amount)
	for _, suffix in suffixes do
		local size, letter = suffix.size, suffix.letter
		if value >= size then
			local short = math.floor(value / size * 10) / 10
			local text = if short == math.floor(short) then tostring(math.floor(short)) else tostring(short)
			return `{sign}${text}{letter}`
		end
	end
	return `{sign}${math.floor(value)}`
end

-- "TheGroundskeeper" -> "The Groundskeeper", "WispJack" -> "Wisp Jack".
function Format.name(id: string): string
	local spaced = string.gsub(id, "(%l)(%u)", "%1 %2")
	return spaced
end

return Format
