--!strict
-- Which server jobs cost the most time (Giles 2026-11-06: "can I see what takes a lot of the
-- resources?"). Every server script is a ModuleScript under one Script, so the Developer
-- Console's Scripts tab only shows one line for the whole server. The busy loops run their
-- work through Perf.run instead, which times it; in Studio, Output gets a short list every
-- ReportSeconds:
--   [Perf] server work, ms per second: RoamService 1.8, InventorySync 0.9, ...
-- 1000 ms per second would be a server doing nothing else, so anything above ~5 is worth a
-- look. Set ReportInLiveGames to also print it in live servers (F9 > Server > Log).
--
-- Only for work that doesn't wait (no task.wait or ...Async inside): time spent waiting would
-- count as work.

local RunService = game:GetService("RunService")

local Perf = {}

local ReportSeconds = 30
local ReportInLiveGames = false
local Shown = 8 -- how many jobs the report lists

local totals: { [string]: number } = {}
local since = os.clock()

-- Runs fn(...) and adds the time it took to `name`. An error is warned with its traceback
-- (so one bad tick never stops the loop that called it) instead of being thrown.
function Perf.run(name: string, fn: (...any) -> (), ...: any)
	local started = os.clock()
	local ok, err = xpcall(fn, debug.traceback, ...)
	totals[name] = (totals[name] or 0) + (os.clock() - started)
	if not ok then
		warn(`{name}: {err}`)
	end
end

-- fn, wrapped so every call goes through Perf.run (for Heartbeat:Connect and the like).
function Perf.wrap(name: string, fn: (...any) -> ()): (...any) -> ()
	return function(...)
		Perf.run(name, fn, ...)
	end
end

-- The totals so far as "ms per second" since the last report, busiest first.
function Perf.report(): string
	local elapsed = math.max(os.clock() - since, 1e-3)
	local rows = {}
	for name, seconds in totals do
		table.insert(rows, { name = name, ms = seconds * 1000 / elapsed })
	end
	table.sort(rows, function(a, b)
		return a.ms > b.ms
	end)
	local parts = {}
	local all = 0
	for index, row in rows do
		all += row.ms
		if index <= Shown then
			table.insert(parts, `{row.name} {string.format("%.1f", row.ms)}`)
		end
	end
	return `[Perf] server work, ms per second (total {string.format("%.1f", all)}): {table.concat(
		parts,
		", "
	)}`
end

function Perf.start()
	if not RunService:IsStudio() and not ReportInLiveGames then
		return
	end
	task.spawn(function()
		while true do
			task.wait(ReportSeconds)
			print(Perf.report())
			table.clear(totals)
			since = os.clock()
		end
	end)
end

return Perf
