--!strict
-- The first-timer tutorial: the steps in order, what each one unlocks, and the words shown
-- for each. A new player walks into Pumpkin Graveyard, catches a Gloomlet, takes it home
-- where it turns Cobwebbed, picks it up, sells it, buys the Phantom Vac and gets a short tour
-- of the buttons. Until the tutorial is done every button that isn't unlocked yet is greyed
-- out. The server runs the steps (server/Services/TutorialService), the client draws them
-- (client/Controllers/TutorialController). Pure functions so they can be tested outside Roblox.
--
-- The current step is the player attribute Tutorial (nil once it's done) and the save's
-- `tutorial` field ("Done" once it's done).

local Tutorial = {}

export type Step = "Gate" | "Catch" | "Home" | "Pickup" | "Sell" | "Buy" | "Tour"

Tutorial.Steps = { "Gate", "Catch", "Home", "Pickup", "Sell", "Buy", "Tour" } :: { Step }

Tutorial.Zone = "PumpkinGraveyard" -- where the first hunt goes
Tutorial.Monster = "Gloomlet" -- the tutorial's own monster, only the player can catch it
Tutorial.Effect = "Cobwebbed" -- the cheapest effect, shown off as soon as it's home
Tutorial.FirstVacuum = "PhantomVac" -- the first thing bought in the shop (Giles 2026-10-21)
Tutorial.RespawnSeconds = 5 -- a tutorial monster that vanished comes back after this long
Tutorial.HintSeconds = 120 -- stuck on one step this long: a bigger hint shows

-- Buttons and keys that stay greyed out until their step: feature -> first step it works.
-- The fast-travel features match Config/Travel's destination ids. Anything not listed is
-- locked until the tutorial is done.
Tutorial.Unlocks = {
	Home = "Gate", -- the Mansion fast-travel button
	Portals = "Gate",
	Hotbar = "Catch",
	Backpack = "Pickup",
	Sell = "Sell",
	Shops = "Buy",
	Codex = "Tour",
	Settings = "Gate", -- sound and weather settings always work
} :: { [string]: Step }

-- What the guide card says for each step.
Tutorial.Text = {
	Gate = "Follow the glowing trail to the Pumpkin Graveyard gate, or tap Portals at the top.",
	Catch = "Press 1 to hold your vacuum, then click the Gloomlet to catch it.",
	Home = "Got it! Follow the trail to the exit, or use your free Return Charm (R).",
	Pickup = "Your Gloomlet turned Cobwebbed: effects make monsters worth more! Press E next to it to put it in your Backpack.",
	Sell = "The Collector buys monsters from your Backpack. Tap Sell at the top and sell your Gloomlet.",
	Buy = "The Collector gave you a welcome gift! Tap Shops and buy the Phantom Vac at the Vacuum Vault.",
	Tour = "You're ready! Here's what the buttons do.",
} :: { [Step]: string }

-- Shown under the guide card after HintSeconds on one step.
Tutorial.Hints = {
	Gate = "The Zone Gates are at the far end of the hub. Tap Portals to jump there.",
	Catch = "When it struggles, click or tap as the needle crosses the green zone. Stay close until the meter is full.",
	Home = "Walk back through the exit arch you came in by.",
	Pickup = "Go into your mansion and stand right next to the Gloomlet, then press E or tap the prompt.",
	Sell = "Press E at the Collector (or tap the prompt), pick \"I want to sell my monsters.\", then tap Sell.",
	Buy = "Press E at the Vacuum Vault (between the other two shops), pick \"Show me the vacuums.\", tap the Phantom Vac card, then Buy.",
	Tour = "Tap Next to see the next button.",
} :: { [Step]: string }

-- The tour at the end: one card per button, in this order. `feature` makes that button glow.
Tutorial.Tour = {
	{
		feature = "Portals",
		text = "Portals takes you to the Zone Gates. Each wing you buy opens a new zone.",
	},
	{
		feature = "Shops",
		text = "Shops takes you to the Haunted Bakery (cakes that give effects), the Vacuum Vault (vacuums) and the Hunter's Workshop (bells, charms and more).",
	},
	{
		feature = "Sell",
		text = "Sell takes you to the Collector. Only monsters in your Backpack can be sold.",
	},
	{
		feature = "Backpack",
		text = "Your Backpack (G) holds your monsters, cakes and tools. Tap the heart on a monster to keep it safe.",
	},
	{
		feature = "Codex",
		text = "Your Codex (C) lists every monster you've caught. Then catch each one in Silver, Gold, Shiny and Rainbow too!",
	},
	{
		feature = "Events",
		text = "Every few minutes the Watcher wakes an event. Its icon shows bottom right, and some events bring rare Phantoms to the hub!",
	},
} :: { { feature: string, text: string } }

-- Where a step is in the list (0 for an unknown step).
function Tutorial.index(step: string?): number
	for index, candidate in Tutorial.Steps do
		if candidate == step then
			return index
		end
	end
	return 0
end

-- Whether a button or key works during this step. No step (nil or "Done") means everything works.
function Tutorial.isUnlocked(step: string?, feature: string): boolean
	if step == nil or step == "Done" or Tutorial.index(step) == 0 then
		return true
	end
	local from = Tutorial.Unlocks[feature]
	return from ~= nil and Tutorial.index(step) >= Tutorial.index(from)
end

-- The step after this one ("Done" after the tour).
function Tutorial.nextStep(step: string): string
	local index = Tutorial.index(step)
	return Tutorial.Steps[index + 1] or "Done"
end

-- A brand-new save (nothing earned, caught or bought yet) gets the tutorial; any older save
-- counts as done, so existing players never see it.
function Tutorial.isFresh(
	money: number,
	monsters: number,
	stored: number,
	wingsOwned: number,
	items: number
): boolean
	return money <= 0 and monsters == 0 and stored == 0 and wingsOwned <= 1 and items == 0
end

-- The step a returning player picks up at. A hunt can't survive leaving the game (the
-- catch is lost), so the hunting steps start over at the gate.
function Tutorial.resumeAt(step: string): string
	if step == "Catch" or step == "Home" then
		return "Gate"
	end
	return step
end

-- The Collector's one-time welcome gift: enough to afford the first vacuum, never negative.
function Tutorial.gift(money: number, price: number): number
	return math.max(price - money, 0)
end

return Tutorial
