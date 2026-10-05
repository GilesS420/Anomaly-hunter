--!strict
-- Wandering maths for monsters in zones and mansions: random free spots inside floor
-- rectangles, keeping every orb clear of the others. Pure functions on plain numbers so
-- they can be tested outside Roblox. Roaming is flat: each rectangle has one floor height.

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number, y: number }
export type Body = { x: number, z: number, radius: number }
export type Point = { x: number, y: number, z: number }

local Roam = {}

Roam.Gap = 1 -- studs of empty space kept between two orbs

function Roam.rect(centerX: number, centerZ: number, width: number, depth: number, y: number): Rect
	return {
		minX = centerX - width / 2,
		maxX = centerX + width / 2,
		minZ = centerZ - depth / 2,
		maxZ = centerZ + depth / 2,
		y = y,
	}
end

local function nextNumber(random: Random?): number
	return if random then random:NextNumber() else math.random()
end

-- A random point at least margin studs inside one of the rectangles (bigger rectangles are
-- picked more often). Nil if no rectangle is big enough.
function Roam.randomPoint(rects: { Rect }, margin: number, random: Random?): Point?
	local usable = {}
	local total = 0
	for _, r in rects do
		local w = (r.maxX - r.minX) - 2 * margin
		local d = (r.maxZ - r.minZ) - 2 * margin
		if w >= 0 and d >= 0 then
			local area = math.max(w * d, 1e-6)
			total += area
			table.insert(usable, { rect = r, area = area })
		end
	end
	if #usable == 0 then
		return nil
	end
	local roll = nextNumber(random) * total
	local chosen = usable[#usable].rect
	for _, entry in usable do
		roll -= entry.area
		if roll < 0 then
			chosen = entry.rect
			break
		end
	end
	return {
		x = chosen.minX + margin + nextNumber(random) * ((chosen.maxX - chosen.minX) - 2 * margin),
		y = chosen.y,
		z = chosen.minZ + margin + nextNumber(random) * ((chosen.maxZ - chosen.minZ) - 2 * margin),
	}
end

-- True if an orb of this radius at (x, z) keeps Gap studs clear of every other orb.
function Roam.isFree(x: number, z: number, radius: number, others: { Body }): boolean
	for _, other in others do
		local dx, dz = x - other.x, z - other.z
		local minDistance = radius + other.radius + Roam.Gap
		if dx * dx + dz * dz < minDistance * minDistance then
			return false
		end
	end
	return true
end

-- A random spot where an orb of this radius fits without touching any other. Nil if none
-- was found in `tries` attempts (the area is too crowded).
function Roam.findFreePoint(
	rects: { Rect },
	radius: number,
	others: { Body },
	random: Random?,
	tries: number?
): Point?
	for _ = 1, tries or 30 do
		local point = Roam.randomPoint(rects, radius, random)
		if not point then
			return nil
		end
		if Roam.isFree(point.x, point.z, radius, others) then
			return point
		end
	end
	return nil
end

-- Shortest distance from point p to the segment a-b (all on the floor plane).
function Roam.segmentDistance(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local abx, abz = bx - ax, bz - az
	local lengthSq = abx * abx + abz * abz
	local t = 0
	if lengthSq > 0 then
		t = math.clamp(((px - ax) * abx + (pz - az) * abz) / lengthSq, 0, 1)
	end
	local cx, cz = ax + abx * t, az + abz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- True if an orb can glide from a to b without passing through any other orb.
function Roam.pathClear(
	ax: number,
	az: number,
	bx: number,
	bz: number,
	radius: number,
	others: { Body }
): boolean
	for _, other in others do
		if Roam.segmentDistance(other.x, other.z, ax, az, bx, bz) < radius + other.radius + Roam.Gap then
			return false
		end
	end
	return true
end

-- How far along a move is, from 0 (at startTime) to 1 (at endTime).
function Roam.alpha(startTime: number, endTime: number, now: number): number
	if endTime <= startTime then
		return 1
	end
	return math.clamp((now - startTime) / (endTime - startTime), 0, 1)
end

-- True if the point lies inside any rectangle (with the given margin).
function Roam.inside(rects: { Rect }, x: number, z: number, margin: number): boolean
	for _, r in rects do
		if
			x >= r.minX + margin
			and x <= r.maxX - margin
			and z >= r.minZ + margin
			and z <= r.maxZ - margin
		then
			return true
		end
	end
	return false
end

return Roam
