--!strict
-- Where the faster hub walk applies. Pure, so tests/run.luau can check it.

local Layout = require("../Config/Layout")

local Travel = {}

-- True if (x, z) is on one of the 8 mansion plots (Layout.Plots, Layout.PlotSize).
function Travel.inPlot(x: number, z: number): boolean
	local halfX, halfZ = Layout.PlotSize.x / 2, Layout.PlotSize.z / 2
	for _, plot in Layout.Plots do
		if math.abs(x - plot.x) <= halfX and math.abs(z - plot.z) <= halfZ then
			return true
		end
	end
	return false
end

-- The WalkSpeed a hunter should have: hubSpeed in the open hub, normal in a zone or on a plot.
function Travel.walkSpeed(inZone: boolean, x: number, z: number, normal: number, hubSpeed: number): number
	if inZone or Travel.inPlot(x, z) then
		return normal
	end
	return hubSpeed
end

return Travel
