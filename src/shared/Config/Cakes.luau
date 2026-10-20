--!strict
-- Cakes: every Bakery treat is a cake you set out in your mansion (hold it from the Roblox
-- hotbar and click while standing in one of your wings). Monsters come for a bite, and a bite
-- may give them a mutation (the treat's effect, Config/Shop.Bakery). Cakes don't feed
-- monsters: feeding is Feed all (Config/Care).
--
-- Every CheckSeconds each cake rolls BiteChance. On a hit, a monster in the mansion that
-- hasn't had a bite of it yet comes over (monsters the effect can still land on first). A
-- bite rolls BiteEffectChance, then the treat's own odds (Util/Care.pickEffect). A cake is
-- gone after Bites bites or Minutes minutes, whichever comes first.
--
-- Cakes are saved and keep going while you're offline, with the same odds (Util/Cakes.catchUp
-- plays the missed checks back when you return). Placeholders, tune in playtesting.

local Cakes = {}

Cakes.Minutes = 15
Cakes.Bites = 3
Cakes.BiteChance = 10 -- percent per check
Cakes.CheckSeconds = 30
Cakes.PerWing = 1 -- cakes out at once per owned wing (the Foyer counts)
Cakes.BiteEffectChance = 50 -- percent a bite rolls for the effect at all

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
} :: { [string]: Look }

return Cakes
