--!strict
-- How wild monsters fight back in the zones (#6). Every attack is announced first: the
-- monster glows red with a "!" above it for windup seconds, and a hunter who walks away in
-- time dodges it. Nothing is a real death; at 0 hearts you drop your catch and go home.
--
-- Kinds:
--   Charge  dashes to where you stood when it got angry; hits if you're still near that spot
--   Scream  a shriek that knocks back everyone close to the monster
--   Flash   a blinding flash: the screen goes white for a moment (no damage)
--   Slime   throws slime at where you stood; hits slow you down for a while (no damage)
--   Vanish  disappears, pops up next to you and shouts "Boo!" (step away to dodge)

export type Kind = "Charge" | "Scream" | "Flash" | "Slime" | "Vanish"

export type AttackKind = {
	damage: number, -- hearts lost on a hit
	hitRadius: number, -- studs around the attack spot that count as a hit
	knockback: number?, -- push on a hit (studs per second)
	blindSeconds: number?,
	slowSeconds: number?,
	slowFactor: number?, -- walk speed is multiplied by this while slowed
	verb: string, -- for the message on a hit: "<Name> <verb>!"
}

-- Per rarity: how far a monster notices hunters, how long it waits between attacks and how
-- long its warning lasts. Rarer monsters notice you sooner and warn you for less time.
export type Aggression = { notice: number, cooldown: number, windup: number }

local Kinds: { [Kind]: AttackKind } = {
	Charge = { damage = 1, hitRadius = 4, knockback = 40, verb = "charged into you" },
	Scream = { damage = 1, hitRadius = 11, knockback = 60, verb = "screamed at you" },
	Flash = { damage = 0, hitRadius = 18, blindSeconds = 2, verb = "flashed you" },
	Slime = { damage = 0, hitRadius = 6, slowSeconds = 4, slowFactor = 0.5, verb = "slimed you" },
	Vanish = { damage = 1, hitRadius = 6, verb = "spooked you" },
}

local Aggression: { [string]: Aggression } = {
	Common = { notice = 14, cooldown = 10, windup = 1.3 },
	Uncommon = { notice = 16, cooldown = 9, windup = 1.2 },
	Rare = { notice = 18, cooldown = 8, windup = 1.1 },
	Epic = { notice = 20, cooldown = 7, windup = 1.0 },
	Legendary = { notice = 22, cooldown = 6, windup = 0.95 },
	Mythic = { notice = 24, cooldown = 5, windup = 0.9 },
	Divine = { notice = 26, cooldown = 4.5, windup = 0.85 },
}

-- Each zone monster's attack. A monster missing here uses Charge.
local ByMonster: { [string]: Kind } = {
	-- Zone 1: Pumpkin Graveyard
	Gloomlet = "Slime",
	Skittercrow = "Charge",
	Mossbones = "Slime",
	WispJack = "Flash",
	Gravepup = "Charge",
	Tombgrin = "Scream",
	TheGroundskeeper = "Charge",
	TheHeadlessRider = "Charge",
	LadyOfLanterns = "Flash",
	-- Zone 2: Murky Bayou
	Bogbub = "Slime",
	Croakling = "Charge",
	WillowWisp = "Flash",
	Reedwitch = "Vanish",
	Gatorghast = "Charge",
	SunkenBell = "Scream",
	TheBogKing = "Slime",
	MireSerpent = "Charge",
	MoonlitHeron = "Flash",
	-- Zone 3: Abandoned Carnival
	Poplet = "Scream",
	BalloonBoo = "Vanish",
	TicketGremlin = "Charge",
	CarouselColt = "Charge",
	JesterJinx = "Vanish",
	MirrorGrin = "Flash",
	TheRingmaster = "Scream",
	BigTopTerror = "Scream",
	GoldenCarousel = "Flash",
	-- Zone 4: Spooky School
	Chalkling = "Slime",
	Paperbat = "Charge",
	LunchGhoul = "Slime",
	LockerLurker = "Vanish",
	HallMonitor = "Scream",
	DetentionShade = "Vanish",
	ThePrincipal = "Scream",
	BellTowerBat = "Scream",
	StarlightScholar = "Flash",
	-- Zone 5: Ghost Ship
	BarnacleBoo = "Slime",
	Gullghast = "Charge",
	BottleSpirit = "Vanish",
	AnchorCrab = "Charge",
	Kraklet = "Slime",
	SirenShade = "Scream",
	CaptainDreadwake = "Charge",
	TheKraken = "Slime",
	SeraphOfTheDeep = "Flash",
}

return {
	Kinds = Kinds,
	Aggression = Aggression,
	ByMonster = ByMonster,
	Default = "Charge" :: Kind,
	ChargeSpeed = 45, -- studs per second while charging
	VanishPopDistance = 4, -- studs from the hunter where a Vanish monster pops up
	VanishWindup = 0.7, -- seconds between popping up and "Boo!"
	HitGraceSeconds = 3, -- after being hit, nothing attacks you for this long
	ArrivalGraceSeconds = 5, -- nothing attacks you this long after entering a zone
	FirstAttackDelay = 3, -- a monster waits this long after spawning before it may attack
}
