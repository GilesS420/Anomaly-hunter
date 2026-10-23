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
	MansionList = "Pickup", -- the arrow tab on the right edge, with a Pick up button per monster
	Sell = "Sell",
	Shops = "Buy",
	Codex = "Tour",
	Settings = "Gate", -- sound and weather settings always work
} :: { [string]: Step }

-- What the guide card says for each step, with a keyboard (Text) or on a phone or tablet
-- without one (TouchText, where it differs).
Tutorial.Text = {
	Gate = "Follow the glowing trail to the Pumpkin Graveyard gate, or press Portals at the top.",
	Catch = "Press 1 to hold your vacuum, then click the Gloomlet. When it struggles, click or press F while the needle is in the green.",
	Home = "Got it! Follow the trail back to the exit, or press R to use your free Return Charm.",
	Pickup = "Your Gloomlet is home and turned Cobwebbed: effects make monsters worth more! Press E next to it, or open the mansion list (the arrow on the right edge) and press Pick up.",
	Sell = "The Collector only buys monsters from your Backpack. Press Sell at the top, then press E at the Collector, pick \"I want to sell my monsters.\" and sell your Gloomlet.",
	Buy = "The Collector gave you a welcome gift! Press Shops and buy the Phantom Vac at the Vacuum Vault, the middle shop.",
	Tour = "You're ready! Here's what the buttons do.",
} :: { [Step]: string }

Tutorial.TouchText = {
	Gate = "Follow the glowing trail to the Pumpkin Graveyard gate, or tap Portals at the top.",
	Catch = "Tap the first hotbar slot to hold your vacuum, then tap the Gloomlet. When it struggles, tap while the needle is in the green.",
	Home = "Got it! Follow the trail back to the exit, or tap Return Charm to jump home.",
	Pickup = "Your Gloomlet is home and turned Cobwebbed: effects make monsters worth more! Tap the prompt next to it, or open the mansion list (the arrow on the right edge) and tap Pick up.",
	Sell = "The Collector only buys monsters from your Backpack. Tap Sell at the top, then tap Talk at the Collector, pick \"I want to sell my monsters.\" and sell your Gloomlet.",
	Buy = "The Collector gave you a welcome gift! Tap Shops and buy the Phantom Vac at the Vacuum Vault, the middle shop.",
} :: { [Step]: string }

-- Shown under the guide card after HintSeconds on one step.
Tutorial.Hints = {
	Gate = "The Zone Gates are at the far end of the hub. Press Portals to jump there.",
	Catch = "Hold your vacuum (the first hotbar slot) and stay close. Each struggle is one click, tap or F while the needle crosses the green zone; miss and it breaks free for a moment, so just try again.",
	Home = "Walk back through the exit arch you came in by.",
	Pickup = "Press Mansion at the top to go home, then stand next to the Gloomlet and press E (or tap the prompt).",
	Sell = "Talk to the Collector (E or tap Talk) and pick \"I want to sell my monsters.\", then press Sell on your Gloomlet.",
	Buy = "Talk to the Vacuum Vault (between the Bakery and the Workshop) and pick \"Show me the vacuums.\", then press the Phantom Vac card and Buy.",
	Tour = "Press Next to see the next button.",
} :: { [Step]: string }

-- The tour at the end: one card per button, in this order. `feature` makes that button glow.
Tutorial.Tour = {
	{
		feature = "Home",
		text = "Mansion takes you straight home. Your monsters roam every wing, and each wing you buy opens a new zone.",
	},
	{
		feature = "Portals",
		text = "Portals takes you to the gate of the newest zone you've opened.",
	},
	{
		feature = "Shops",
		text = "Shops takes you to the Haunted Bakery (cakes), the Vacuum Vault (vacuums) and the Hunter's Workshop (Bait Bells, Return Charms, Name Tags and more).",
	},
	{
		feature = "Hotbar",
		text = "Cakes give effects. Hold one from your hotbar and click (or tap) the floor in one of your wings: monsters come over for bites and change, even while you're offline.",
	},
	{
		feature = "Sell",
		text = "Sell takes you to the Collector. Only monsters in your Backpack can be sold.",
	},
	{
		feature = "Backpack",
		text = "Your Backpack holds your monsters, cakes and tools. Drag a card onto the hotbar to hold it, and tap the heart on a monster to keep it safe.",
	},
	{
		feature = "MansionList",
		text = "The arrow on the right edge lists the monsters in your mansion, sorted by price, rarity or name, each with a Pick up button.",
	},
	{
		feature = "Codex",
		text = "Your Codex lists every monster you've caught. Catch each one in Silver, Gold, Shiny and Rainbow too, for money rewards!",
	},
	{
		feature = "Events",
		text = "Every few minutes the Watcher wakes an event for the whole game: the sky changes and monsters get its effect. Its icon shows bottom right.",
	},
	{
		feature = "Settings",
		text = "Settings has music and sound volume, weather, and UI size if the buttons look too big or small on your screen.",
	},
} :: { { feature: string, text: string } }

-- The words for a step on this device: the touch version when there's no keyboard.
function Tutorial.textFor(step: string, touch: boolean): string
	local text = if touch then Tutorial.TouchText[step :: Step] else nil
	return text or Tutorial.Text[step :: Step] or ""
end

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
