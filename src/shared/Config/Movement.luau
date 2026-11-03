--!strict
-- Movement anti-cheat (Giles 2026-11-03): the server checks every hunter's position a few
-- times a second and pulls them back if they move faster than they can walk (speed hack,
-- teleport hack), rise higher than a jump (super jump) or stay up in the air (fly hack).
-- Rules in Util/Movement, server MovementService. Everything the game moves on purpose
-- (portals, the Return Charm, fast travel, spawning, falling off the world, slaps and monster
-- knockbacks) tells MovementService first, so those never count.
-- All numbers are on the safe side: a real cheat is far past them, a laggy player is not.

return {
	-- Seconds between two checks of a player.
	CheckSeconds = 0.25,

	-- Speed: the fastest anyone may walk is the hub speed (Config/Travel.HubWalkSpeed) times
	-- the Faster walking speed pass, times this, for lag and running downhill.
	SpeedTolerance = 1.35,
	-- How many seconds of walking a player may "save up" and catch up on at once, for a lag
	-- spike where the server hears nothing and then gets the whole walk in one go.
	BurstSeconds = 2.5,
	-- Extra studs always allowed on top, for a small step or a bump.
	SlackStuds = 12,

	-- Jumping: how many studs above the floor they left from a player may rise, on top of
	-- their real jump height.
	RiseSlack = 8,

	-- Flying: after this many seconds in the air a player must be dropping...
	HoverSeconds = 2,
	-- ...at least this many studs per HoverSeconds, or they're hovering.
	MinDrop = 4,

	-- How far below the feet still counts as standing on something (stairs, slopes, edges).
	GroundReach = 4,

	-- Pulled back this many times within StrikeWindow seconds: kicked from the server.
	-- Lag can cause one or two pulls; a cheat causes several a second. 0 = never kick.
	KickStrikes = 12,
	StrikeWindow = 30,
	KickMessage = "Kicked for moving impossibly fast or flying. If you weren't cheating, sorry! Please rejoin.",

	-- Seconds the checks look away after the game moves a player on purpose.
	TeleportGrace = 2, -- portals, Return Charm, fast travel, spawn, fall rescue (each resend restarts it)
	KnockbackGrace = 2.5, -- slaps and monster Charge / Shockwave hits
}
