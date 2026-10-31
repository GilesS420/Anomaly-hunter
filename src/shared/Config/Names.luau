--!strict
-- Names players see for monsters and zones that were renamed (Giles 2026-10-31). Saves, the
-- Codex, missions and Studio folders keep using the old id (Workspace > Zones > MurkyBayou
-- stays), so nothing has to be migrated: only the text players read changes. Format.name
-- looks here first.

return {
	-- Monsters
	Gloomlet = "Shiverling",
	Skittercrow = "Rotraven",
	WispJack = "Hollowflame",
	WillowWisp = "Weepwillow",
	MireSerpent = "The Drowned Coil",
	MoonlitHeron = "The Bone Wader",
	Poplet = "Gorecorn",
	CarouselColt = "Merry-Go-Gore",

	-- Zones
	MurkyBayou = "Drowned Swamp",
} :: { [string]: string }
