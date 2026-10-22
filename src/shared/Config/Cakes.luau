--!strict
-- Cakes: every Bakery treat is a cake you set out in your mansion (hold it from the Roblox
-- hotbar and click while standing in one of your wings). Monsters come for a bite, and a bite
-- may give them a mutation (the treat's effect, Config/Shop.Bakery).
--
-- A cake is out for Minutes minutes and gets its bites (Bites, more for pricier cakes) spread
-- over that time: each bite lands at a random moment within its own share of the time, so
-- cakes set out together don't all get eaten at once. For each bite a monster that hasn't had one yet
-- comes over: one within the cake's Reach if there is one, else any (monsters the effect can
-- still land on first). A bite rolls BiteEffectChance, then the treat's own odds
-- (Util/Cakes.pickEffect). The last bite always gives an effect if the cake hasn't yet, so
-- every cake gives at least one (if a monster it fits is there).
--
-- Cakes are saved and keep going while you're offline, with the same odds (Util/Cakes.catchUp
-- plays the missed checks back when you return). Placeholders, tune in playtesting.

local Cakes = {}

Cakes.Minutes = 15
Cakes.Bites = 3 -- a cake not listed in BitesById
Cakes.BitesById = {
	MoldyMuffin = 3,
	PumpkinCandy = 3,
	FangFudge = 3,
	StaticCupcake = 4,
	EctoplasmPie = 4,
	FrostTart = 4,
	WebWaffle = 3,
	PumpkinSpiceRoll = 4,
	BoneBiscuit = 4,
	CauldronCupcake = 5,
	GildedTruffle = 5,
	SpiderStrudel = 5,
	StitchCupcake = 5,
	CursedCake = 6,
	BloodMoonPie = 6,
	RiftRoll = 6,
	BoneMarrowMousse = 6,
	GraveGateau = 6,
	MimicMacaron = 7,
	WitchsBrewTart = 7,
	PhantomPavlova = 7,
	EclipseEclair = 8,
	VoidVelvet = 9,
} :: { [string]: number }
Cakes.CheckSeconds = 5 -- how often a cake looks whether its next bite is due (online)
Cakes.PerWing = 5 -- cakes out at once per owned wing (the Foyer counts): 5 to start, 30 with every wing
Cakes.BiteEffectChance = 30 -- percent a bite rolls for the effect at all (Giles 2026-10-21: rarer)

-- How far each cake reaches (studs, a circle round it on the floor): monsters inside it come
-- for a bite first. Better cakes reach further. A wing is 40 x 40 studs. Hover over (or tap)
-- a placed cake to see its circle.
Cakes.Reach = {
	MoldyMuffin = 8,
	PumpkinCandy = 8,
	FangFudge = 9,
	StaticCupcake = 10,
	EctoplasmPie = 10,
	FrostTart = 11,
	WebWaffle = 9,
	PumpkinSpiceRoll = 11,
	BoneBiscuit = 11,
	CauldronCupcake = 12,
	GildedTruffle = 12,
	SpiderStrudel = 12,
	StitchCupcake = 12,
	CursedCake = 14,
	BloodMoonPie = 14,
	RiftRoll = 14,
	BoneMarrowMousse = 15,
	GraveGateau = 16,
	MimicMacaron = 16,
	WitchsBrewTart = 18,
	PhantomPavlova = 20,
	EclipseEclair = 22,
	VoidVelvet = 26,
} :: { [string]: number }
Cakes.DefaultReach = 8

export type Topping = "Candy" | "Fangs" | "Drips" | "Stitches" | "Runes" | "Bones" | "Bubbles" | "Moon"

-- How each cake looks, in your hand and on the floor (server/CakeModel). Colours are RGB.
export type Look = {
	tiers: number, -- 1 to 3 layers, each a bit smaller than the one below
	sponge: { number },
	icing: { number },
	topping: Topping,
	toppingColor: { number },
	glow: { number }?, -- a soft light, for the rarer cakes
}

Cakes.Looks = {
	PumpkinCandy = {
		tiers = 1,
		sponge = { 230, 120, 40 },
		icing = { 255, 190, 90 },
		topping = "Candy",
		toppingColor = { 40, 30, 30 },
	},
	FangFudge = {
		tiers = 1,
		sponge = { 70, 40, 30 },
		icing = { 120, 20, 30 },
		topping = "Fangs",
		toppingColor = { 245, 240, 225 },
	},
	EctoplasmPie = {
		tiers = 1,
		sponge = { 190, 150, 100 },
		icing = { 110, 230, 90 },
		topping = "Drips",
		toppingColor = { 140, 255, 110 },
		glow = { 120, 255, 100 },
	},
	StitchCupcake = {
		tiers = 2,
		sponge = { 120, 150, 110 },
		icing = { 170, 130, 170 },
		topping = "Stitches",
		toppingColor = { 30, 25, 25 },
	},
	CursedCake = {
		tiers = 2,
		sponge = { 40, 25, 45 },
		icing = { 120, 40, 160 },
		topping = "Runes",
		toppingColor = { 200, 90, 255 },
		glow = { 170, 60, 255 },
	},
	BoneMarrowMousse = {
		tiers = 2,
		sponge = { 225, 215, 190 },
		icing = { 150, 30, 40 },
		topping = "Bones",
		toppingColor = { 240, 235, 215 },
	},
	WitchsBrewTart = {
		tiers = 2,
		sponge = { 60, 40, 70 },
		icing = { 60, 200, 120 },
		topping = "Bubbles",
		toppingColor = { 150, 255, 180 },
		glow = { 80, 255, 150 },
	},
	EclipseEclair = {
		tiers = 3,
		sponge = { 20, 20, 30 },
		icing = { 255, 170, 60 },
		topping = "Moon",
		toppingColor = { 255, 230, 150 },
		glow = { 255, 180, 80 },
	},
	MoldyMuffin = {
		tiers = 1,
		sponge = { 150, 130, 90 },
		icing = { 120, 150, 90 },
		topping = "Drips",
		toppingColor = { 160, 200, 110 },
	},
	SpiderStrudel = {
		tiers = 1,
		sponge = { 200, 160, 100 },
		icing = { 235, 235, 240 },
		topping = "Stitches",
		toppingColor = { 40, 30, 40 },
	},
	GraveGateau = {
		tiers = 2,
		sponge = { 70, 55, 45 },
		icing = { 110, 115, 110 },
		topping = "Bones",
		toppingColor = { 220, 210, 190 },
	},
	PhantomPavlova = {
		tiers = 3,
		sponge = { 235, 240, 255 },
		icing = { 200, 225, 255 },
		topping = "Bubbles",
		toppingColor = { 170, 220, 255 },
		glow = { 170, 220, 255 },
	},
	VoidVelvet = {
		tiers = 3,
		sponge = { 30, 10, 45 },
		icing = { 70, 20, 110 },
		topping = "Moon",
		toppingColor = { 200, 120, 255 },
		glow = { 160, 60, 255 },
	},
	-- Event treats (only sold while their Watcher event is live).
	StaticCupcake = {
		tiers = 1,
		sponge = { 150, 160, 190 },
		icing = { 190, 210, 255 },
		topping = "Drips",
		toppingColor = { 170, 220, 255 },
		glow = { 170, 220, 255 },
	},
	FrostTart = {
		tiers = 1,
		sponge = { 200, 220, 240 },
		icing = { 235, 248, 255 },
		topping = "Candy",
		toppingColor = { 140, 210, 255 },
		glow = { 180, 235, 255 },
	},
	GildedTruffle = {
		tiers = 1,
		sponge = { 60, 40, 25 },
		icing = { 255, 205, 30 },
		topping = "Runes",
		toppingColor = { 255, 230, 120 },
		glow = { 255, 200, 60 },
	},
	WebWaffle = {
		tiers = 1,
		sponge = { 215, 170, 100 },
		icing = { 235, 235, 240 },
		topping = "Drips",
		toppingColor = { 245, 245, 250 },
	},
	PumpkinSpiceRoll = {
		tiers = 1,
		sponge = { 200, 120, 50 },
		icing = { 245, 225, 190 },
		topping = "Candy",
		toppingColor = { 255, 150, 40 },
	},
	BoneBiscuit = {
		tiers = 1,
		sponge = { 225, 215, 185 },
		icing = { 240, 235, 220 },
		topping = "Bones",
		toppingColor = { 245, 240, 225 },
	},
	CauldronCupcake = {
		tiers = 1,
		sponge = { 50, 30, 60 },
		icing = { 80, 210, 110 },
		topping = "Bubbles",
		toppingColor = { 150, 255, 170 },
		glow = { 100, 255, 140 },
	},
	BloodMoonPie = {
		tiers = 2,
		sponge = { 90, 20, 25 },
		icing = { 180, 20, 30 },
		topping = "Moon",
		toppingColor = { 255, 70, 55 },
		glow = { 255, 40, 40 },
	},
	RiftRoll = {
		tiers = 2,
		sponge = { 40, 30, 80 },
		icing = { 120, 150, 255 },
		topping = "Runes",
		toppingColor = { 210, 225, 255 },
		glow = { 130, 160, 255 },
	},
	MimicMacaron = {
		tiers = 2,
		sponge = { 120, 78, 40 },
		icing = { 255, 200, 60 },
		topping = "Fangs",
		toppingColor = { 245, 245, 255 },
		glow = { 255, 200, 60 },
	},
} :: { [string]: Look }

return Cakes
