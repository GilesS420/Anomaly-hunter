--!strict
-- How zone monsters fight back (#6). Every monster has one readable attack, picked from a
-- few shared kinds so the AI stays one piece of code (Util/Attacks, server MonsterAiService).
-- The words come from the concept doc's "Fights back by" column.
--
-- Every attack is telegraphed: the monster stops, a warning shape lights up on the ground
-- for WindupSeconds, then it hits whoever is still inside. So you can always dodge by
-- walking out of the shape.
--   Charge     dashes in a straight line toward you (the warning is a lane)
--   Shockwave  hits everyone in a ring around itself and knocks them back
--   Throw      lobs something at the spot you stood on (a circle at your feet)
--   Slow       like Throw, but it slows you instead of costing a heart
--   Blind      a burst of darkness around itself that blacks out your screen for a moment
--   Blink      vanishes and pops up somewhere close by (harmless, but it breaks your aim)
-- Any hit that costs a heart also breaks a catch you are in the middle of.

export type Kind = "Charge" | "Shockwave" | "Throw" | "Slow" | "Blind" | "Blink"

export type KindInfo = {
	range: number, -- studs: it attacks once you are this close (it chases you until then)
	radius: number, -- studs: size of the warning shape (half the lane's width for Charge)
	damage: number, -- hearts
	effectSeconds: number, -- how long a Slow or Blind lasts
}

export type MonsterAttack = {
	kind: Kind,
	text: string, -- finishes "<Name> ...!" in the hit message
	damage: number?, -- overrides the kind's damage
}

local Kinds: { [Kind]: KindInfo } = {
	Charge = { range = 22, radius = 3, damage = 1, effectSeconds = 0 },
	Shockwave = { range = 10, radius = 12, damage = 1, effectSeconds = 0 },
	Throw = { range = 26, radius = 5, damage = 1, effectSeconds = 0 },
	Slow = { range = 26, radius = 6, damage = 0, effectSeconds = 3 },
	Blind = { range = 12, radius = 14, damage = 0, effectSeconds = 2 },
	Blink = { range = 14, radius = 0, damage = 0, effectSeconds = 0 },
}

-- Zones 1-5. Harmless kinds (Slow, Blind, Blink) also cost a heart from Legendary up.
local Monsters: { [string]: MonsterAttack } = {
	-- Zone 1: Pumpkin Graveyard
	Gloomlet = { kind = "Blink", text = "vanished for a second" },
	Skittercrow = { kind = "Blind", text = "flapped a dust cloud in your face" },
	Mossbones = { kind = "Throw", text = "threw a bone at you" },
	WispJack = { kind = "Blind", text = "blinded you with a burst of darkness" },
	Gravepup = { kind = "Charge", text = "charged at you" },
	Tombgrin = { kind = "Shockwave", text = "stopped pretending to be a tombstone and bit you" },
	TheGroundskeeper = { kind = "Shockwave", text = "screamed you backwards" },
	TheHeadlessRider = { kind = "Charge", text = "charged you on its ghost horse" },
	LadyOfLanterns = { kind = "Blind", text = "blinded you with its halo", damage = 1 },

	-- Zone 2: Murky Bayou
	Bogbub = { kind = "Slow", text = "spat mud that slows you" },
	Croakling = { kind = "Throw", text = "grabbed your vacuum with its tongue" },
	WillowWisp = { kind = "Blink", text = "teleported away" },
	Reedwitch = { kind = "Slow", text = "hexed your legs" },
	Gatorghast = { kind = "Charge", text = "charged at you" },
	SunkenBell = { kind = "Shockwave", text = "rang out a shockwave" },
	TheBogKing = { kind = "Shockwave", text = "ground-pounded the swamp" },
	MireSerpent = { kind = "Slow", text = "coiled around you", damage = 1 },
	MoonlitHeron = { kind = "Blink", text = "vanished into the moonlight" },

	-- Zone 3: Abandoned Carnival
	Poplet = { kind = "Throw", text = "threw popcorn at you" },
	BalloonBoo = { kind = "Shockwave", text = "popped loudly and scared you" },
	TicketGremlin = { kind = "Blind", text = "snatched your flashlight for a moment" },
	CarouselColt = { kind = "Charge", text = "charged at you" },
	JesterJinx = { kind = "Blink", text = "teleported behind you" },
	MirrorGrin = { kind = "Blind", text = "dazzled you with mirror copies" },
	TheRingmaster = { kind = "Throw", text = "cracked its whip at you" },
	BigTopTerror = { kind = "Shockwave", text = "swallowed you for a moment" },
	GoldenCarousel = { kind = "Shockwave", text = "spun up a whirlwind" },

	-- Zone 4: Spooky School (not in the launch)
	Chalkling = { kind = "Blind", text = "puffed a chalk dust cloud" },
	Paperbat = { kind = "Charge", text = "swooped at you" },
	LunchGhoul = { kind = "Slow", text = "spat jello that slows you" },
	LockerLurker = { kind = "Shockwave", text = "jump scared you out of a locker" },
	HallMonitor = { kind = "Shockwave", text = "blew its whistle at you" },
	DetentionShade = { kind = "Blind", text = "turned off the lights" },
	ThePrincipal = { kind = "Shockwave", text = "screamed you backwards" },
	BellTowerBat = { kind = "Shockwave", text = "rang its bell" },
	StarlightScholar = { kind = "Throw", text = "shot a star bolt at you" },

	-- Zone 5: Ghost Ship (not in the launch)
	BarnacleBoo = { kind = "Slow", text = "stuck to you" },
	Gullghast = { kind = "Charge", text = "dived at you" },
	BottleSpirit = { kind = "Blink", text = "hid in its bottle" },
	AnchorCrab = { kind = "Throw", text = "pinched your vacuum" },
	Kraklet = { kind = "Blind", text = "squirted ink in your eyes" },
	SirenShade = { kind = "Slow", text = "sang a song that holds you" },
	CaptainDreadwake = { kind = "Throw", text = "fired a ghost cannon at you" },
	TheKraken = { kind = "Shockwave", text = "swept you away with a tentacle" },
	SeraphOfTheDeep = { kind = "Shockwave", text = "sent out an electric pulse" },
}

return {
	Kinds = Kinds,
	Monsters = Monsters,

	NoticeRadius = 36, -- studs: a monster notices hunters this close and comes for them
	MaxAttackersPerHunter = 2, -- monsters going after one hunter at a time, so it stays readable
	WindupSeconds = 1, -- how long the warning shows before the hit
	ChargeSeconds = 0.35, -- how long the dash itself takes
	ChaseSpeed = 1.6, -- x the monster's wander speed while it closes in
	HitGraceSeconds = 2, -- after a hit you can't be hit again for this long
	ArrivalGraceSeconds = 4, -- nothing attacks you this soon after entering a zone
	FirstAttackDelay = 3, -- a monster waits this long after it spawns or gets let go
	SlowWalkSpeed = 8, -- WalkSpeed while slowed (the default is 16)
	KnockbackSpeed = 55, -- studs per second you fly back from a Charge or Shockwave
	HarmfulFromRarity = 5, -- Legendary and up: every attack costs a heart

	-- Seconds between two attacks by the same monster: rarer ones attack more often.
	-- Common 10, Uncommon 9, ... Legendary 6, Mythic and Divine 5.
	CooldownBase = 11,
	CooldownMin = 5,
}
