--!strict
-- The first-timer tutorial: the steps in order, what each one unlocks, and the words shown
-- for each. A new player walks into Pumpkin Graveyard, catches a Gloomlet, takes it home
-- where it turns Cobwebbed, picks it up, sells it and buys the Phantom Vac. Then the Bakery
-- (Giles 2026-11-05): buy a Pumpkin Candy, set it out at home, catch a second monster (a
-- Skittercrow), bring it home and watch it eat the cake and turn Pumpkin Head. Last, a short
-- tour of the buttons. Until the tutorial is done every button that isn't unlocked yet is greyed
-- out. The server runs the steps (server/Services/TutorialService), the client draws them
-- (client/Controllers/TutorialController). Pure functions so they can be tested outside Roblox.
--
-- The current step is the player attribute Tutorial (nil once it's done) and the save's
-- `tutorial` field ("Done" once it's done).

local Community = require("../Config/Community")
local Names = require("../Config/Names")

local Tutorial = {}

export type Step =
	"Gate"
	| "Catch"
	| "Home"
	| "Pickup"
	| "Sell"
	| "Buy"
	| "Bake"
	| "Place"
	| "Hunt"
	| "Return"
	| "Feed"
	| "Tour"

Tutorial.Steps = {
	"Gate",
	"Catch",
	"Home",
	"Pickup",
	"Sell",
	"Buy",
	"Bake",
	"Place",
	"Hunt",
	"Return",
	"Feed",
	"Tour",
} :: { Step }

Tutorial.Zone = "PumpkinGraveyard" -- where the first hunt goes
Tutorial.Monster = "Gloomlet" -- the tutorial's own monster, only the player can catch it
local Monster = Names[Tutorial.Monster] -- what the guide card calls it
Tutorial.Effect = "Cobwebbed" -- the cheapest effect, shown off as soon as it's home
Tutorial.FirstVacuum = "PhantomVac" -- the first thing bought in the shop (Giles 2026-10-21)
Tutorial.Cake = "PumpkinCandy" -- the first cake, bought with the Baker's gift
Tutorial.CakeEffect = "PumpkinHead" -- what the Pumpkin Candy gives
Tutorial.SecondMonster = "Skittercrow" -- the second catch, the one that eats the cake
Tutorial.FeedSeconds = 45 -- no bite by then (it got stuck, say): it gets Pumpkin Head anyway
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
	Missions = "Tour",
	Store = "Tour", -- the Robux Store button
	Settings = "Gate", -- sound and weather settings always work
} :: { [string]: Step }

-- The exact cards and buttons that pulse during a step (client/Locks.point), on top of the
-- top-bar button: the stand's "buy" or "sell" choice in the dialogue, then the card to buy
-- (and its Buy button once opened) or the Sell button (Giles 2026-11-05).
Tutorial.Point = {
	Sell = { "Enter:Collector", "SellButton" },
	Buy = { "Enter:VacuumVault", `Card:{Tutorial.FirstVacuum}` },
	Bake = { "Enter:Bakery", `Card:{Tutorial.Cake}` },
} :: { [Step]: { string } }

-- What the guide card says for each step, with a keyboard (Text) or on a phone or tablet
-- without one (TouchText, where it differs).
Tutorial.Text = {
	Gate = "Follow the glowing trail to the Pumpkin Graveyard gate, or press Portals at the top.",
	Catch = `Press 1 to hold your vacuum, then click the {Monster}. When it struggles, click or press F while the needle is in the green.`,
	Home = "Got it! Follow the trail back to the exit, or press R to use your free Return Charm.",
	Pickup = `Your {Monster} is home and turned Cobwebbed: effects make monsters worth more! Press E next to it, or open the mansion list (the arrow on the right edge) and press Pick up.`,
	Sell = `The Collector only buys monsters from your Backpack. Press Sell at the top, then press E at the Collector, pick "I want to sell my monsters." and sell your {Monster}.`,
	Buy = 'The Collector gave you a welcome gift! Press Shops, then press E at the Vacuum Vault (the middle shop), pick "Show me the vacuums." and buy the Phantom Vac.',
	Bake = 'Cakes give monsters effects! The Baker gave you money for a Pumpkin Candy. Follow the trail to the Haunted Bakery, press E, pick "I want to buy cakes!" and buy the Pumpkin Candy.',
	Place = "Press Mansion at the top to go home. Hold the Pumpkin Candy from your hotbar and click the floor inside your mansion to set it out.",
	Hunt = "Your cake needs a hungry monster! Press Portals, go back to the Pumpkin Graveyard and catch the Skittercrow.",
	Return = "Got it! Bring it home: follow the trail to the exit, or press R if you still have a Return Charm.",
	Feed = "Your Skittercrow smells the cake! Watch it walk over, take a bite and turn Pumpkin Head.",
	Tour = "You're ready! Here's what the buttons do.",
} :: { [Step]: string }

Tutorial.TouchText = {
	Gate = "Follow the glowing trail to the Pumpkin Graveyard gate, or tap Portals at the top.",
	Catch = `Tap the first hotbar slot to hold your vacuum, then tap the {Monster}. When it struggles, tap while the needle is in the green.`,
	Home = "Got it! Follow the trail back to the exit, or tap Return Charm to jump home.",
	Pickup = `Your {Monster} is home and turned Cobwebbed: effects make monsters worth more! Tap the prompt next to it, or open the mansion list (the arrow on the right edge) and tap Pick up.`,
	Sell = `The Collector only buys monsters from your Backpack. Tap Sell at the top, then tap Talk at the Collector, pick "I want to sell my monsters." and sell your {Monster}.`,
	Buy = 'The Collector gave you a welcome gift! Tap Shops, then tap Talk at the Vacuum Vault (the middle shop), pick "Show me the vacuums." and buy the Phantom Vac.',
	Bake = 'Cakes give monsters effects! The Baker gave you money for a Pumpkin Candy. Follow the trail to the Haunted Bakery, tap Talk, pick "I want to buy cakes!" and buy the Pumpkin Candy.',
	Place = "Tap Mansion at the top to go home. Tap the Pumpkin Candy in your hotbar, then tap the floor inside your mansion to set it out.",
	Hunt = "Your cake needs a hungry monster! Tap Portals, go back to the Pumpkin Graveyard and catch the Skittercrow.",
	Return = "Got it! Bring it home: follow the trail to the exit, or tap Return Charm if you still have one.",
} :: { [Step]: string }

-- Shown under the guide card after HintSeconds on one step.
Tutorial.Hints = {
	Gate = "The Zone Gates are at the far end of the hub. Press Portals to jump there.",
	Catch = "Hold your vacuum (the first hotbar slot) and stay close. Each struggle is one click, tap or F while the needle crosses the green zone; miss and it breaks free for a moment, so just try again.",
	Home = "Walk back through the exit arch you came in by.",
	Pickup = `Press Mansion at the top to go home, then stand next to the {Monster} and press E (or tap the prompt).`,
	Sell = `Talk to the Collector (E or tap Talk) and pick "I want to sell my monsters.", then press Sell on your {Monster}.`,
	Buy = 'Talk to the Vacuum Vault (between the Bakery and the Workshop) and pick "Show me the vacuums.", then press the Phantom Vac card and Buy.',
	Bake = 'Press Shops and talk to the Haunted Bakery (the pink striped shop). Pick "I want to buy cakes!", then press the Pumpkin Candy card and Buy.',
	Place = "Stand inside your mansion, hold the Pumpkin Candy (it's in your hotbar) and click or tap the floor in front of you.",
	Hunt = "Press Portals to jump to the Zone Gates, walk into the Pumpkin Graveyard and follow the trail to the Skittercrow.",
	Return = "Walk back through the exit arch you came in by.",
	Feed = "Leave the Skittercrow in your mansion (don't pick it up) and stay close to the cake.",
	Tour = "Press Next to see the next button.",
} :: { [Step]: string }

-- The tour at the end: one card per button, in this order. `feature` makes that button glow
-- (none: nothing to point at), `touch` is the phone wording where it differs. Things a player
-- only gets later (cakes, bells, slappers, events...) are explained once when they first get
-- them instead (Util/Tips).
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
		text = "Shops takes you to the Haunted Bakery (cakes), the Vacuum Vault (vacuums) and the Hunter's Workshop (Bait Bells, Return Charms, Name Tags, luck potions and slappers).",
	},
	{
		feature = "Sell",
		text = `Sell takes you to the Collector. Only monsters in your Backpack can be sold. Every Roblox friend in your server makes the Collector pay you {math.round(Community.FriendSellBonus * 100)}% more.`,
	},
	{
		feature = "Backpack",
		text = "The backpack button on the left opens your Backpack: your monsters, cakes and tools. Drag a card onto the hotbar to hold it, and tap the heart on a monster to keep it safe. Hold a monster and hold E next to another hunter to give it to them.",
		touch = "The backpack button on the left opens your Backpack: your monsters, cakes and tools. Drag a card onto the hotbar to hold it, and tap the heart on a monster to keep it safe. Hold a monster and hold the Give button next to another hunter to give it to them.",
	},
	{
		feature = "MansionList",
		text = "The arrow on the right edge lists the monsters in your mansion, sorted by price, rarity or name, each with a Pick up button.",
	},
	{
		text = "Around the hub are more stands: the Merger (two monsters into one), the Growth Chamber (makes monsters bigger), the Trading Booth (swap with other hunters) and the Hunter's Guild. Press E at any stand to talk to it.",
		touch = "Around the hub are more stands: the Merger (two monsters into one), the Growth Chamber (makes monsters bigger), the Trading Booth (swap with other hunters) and the Hunter's Guild. Tap Talk at any stand to talk to it.",
	},
	{
		feature = "Codex",
		text = "The book button opens your Codex: it lists every monster you've caught. Catch each one in Silver, Gold, Shiny and Rainbow too, for money rewards!",
	},
	{
		feature = "Missions",
		text = "The scroll button opens your Missions: three new missions every day. Finish them for money that grows with your mansion, and come back each day for a streak bonus.",
	},
	{
		feature = "Store",
		text = "The coin button opens the Store, with game passes and Robux items.",
	},
	{
		feature = "Settings",
		text = "The gear button opens Settings: music and sound volume, weather, UI size if the buttons look too big or small, and Feedback to tell us what you think.",
	},
} :: { { feature: string?, text: string, touch: string? } }

-- The words for a tour card on this device.
function Tutorial.tourText(index: number, touch: boolean): string
	local stop = Tutorial.Tour[index]
	if not stop then
		return Tutorial.Text.Tour
	end
	return if touch and stop.touch then stop.touch else stop.text
end

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
	elseif step == "Return" then
		return "Hunt"
	end
	return step
end

-- A one-time gift: enough to afford the first vacuum (the Collector) or the first cake (the
-- Baker), never negative.
function Tutorial.gift(money: number, price: number): number
	return math.max(price - money, 0)
end

return Tutorial
