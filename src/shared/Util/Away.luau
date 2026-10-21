--!strict
-- The "while you were away" book: what changed for each mansion monster between leaving
-- and coming back (weight, size and new effects). Take a snapshot before playing back the
-- time away, then compare. Pure functions so they can be tested outside Roblox.

local Value = require("./Value")

local Away = {}

export type Snapshot = { [string]: { kg: number?, size: string, effects: { string } } }

-- One monster's changes, sent to the client (server/Services/MansionService).
export type Change = {
	monsterId: string,
	kgBefore: number?,
	kgAfter: number?,
	sizeBefore: string,
	sizeAfter: string,
	effects: { string }, -- new effects (combos as their combo id)
}

Away.MinSeconds = 60 -- shorter than this away and no book is shown

function Away.snapshot(monsters: { Value.CaughtMonster }): Snapshot
	local snapshot: Snapshot = {}
	for _, caught in monsters do
		if caught.uid then
			snapshot[caught.uid] =
				{ kg = caught.kg, size = caught.size, effects = table.clone(caught.effects) }
		end
	end
	return snapshot
end

-- The monsters that changed since the snapshot, biggest weight gain first.
function Away.changes(snapshot: Snapshot, monsters: { Value.CaughtMonster }): { Change }
	local changes: { Change } = {}
	for _, caught in monsters do
		local before = if caught.uid then snapshot[caught.uid] else nil
		if not before then
			continue
		end
		local had = Value.resolveEffects(before.effects)
		local new: { string } = {}
		for _, id in Value.resolveEffects(caught.effects) do
			if not table.find(had, id) then
				table.insert(new, id)
			end
		end
		local grew = (caught.kg or 0) > (before.kg or 0) + 1e-6
		if grew or caught.size ~= before.size or #new > 0 then
			table.insert(changes, {
				monsterId = caught.monsterId,
				kgBefore = before.kg,
				kgAfter = caught.kg,
				sizeBefore = before.size,
				sizeAfter = caught.size,
				effects = new,
			})
		end
	end
	table.sort(changes, function(a, b)
		local ga = (a.kgAfter or 0) - (a.kgBefore or 0)
		local gb = (b.kgAfter or 0) - (b.kgBefore or 0)
		if ga ~= gb then
			return ga > gb
		end
		return #a.effects > #b.effects
	end)
	return changes
end

return Away
