--!strict
-- The first-timer tutorial: the steps in order, what each one unlocks, and the words shown
-- for each. Kept short (Giles 2026-11-05, after the funnel showed most new players never
-- finished the long one): a new player walks into Pumpkin Graveyard, catches a Gloomlet,
-- runs back out (it turns Cobwebbed and lands straight in the Backpack), sells it and buys the
-- Phantom Vac. Until the tutorial is done every button that isn't unlocked yet is greyed out.
-- The card says as little as possible (Giles 2026-11-05: less text popping up).
--
-- After it, an optional quest, "Baker's first cake" (QuestSteps): buy a Pumpkin Candy with
-- the Baker's gift, set it out at home, catch a second monster (a Skittercrow, shown as Grave
-- Raven), bring it home and watch it eat the cake and turn Pumpkin Head, for QuestReward.
-- Nothing is locked during it and it can be skipped.
--
-- The server runs both (server/Services/TutorialService), the client draws them
-- (client/Controllers/TutorialController). Pure functions so they can be tested outside Roblox.
-- The current step is the player attribute Tutorial (nil once it's done) and the save's
-- `tutorial` field ("Done" once it's done); the quest's is the attribute Quest and the save's
-- `quest` field.

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

-- Pickup was a step before 2026-11-05; old saves at it pick up at Sell (resumeAt), so its
-- name stays in the type.
-- The button tour that ended it until 2026-11-05 is gone (Giles: players don't need every
-- button explained); saves at "Tour" count as done (resumeAt).
Tutorial.Steps = { "Gate", "Catch", "Home", "Sell", "Buy" } :: { Step }

-- The optional Bakery quest after the tutorial, in order.
Tutorial.QuestSteps = { "Bake", "Place", "Hunt", "Return", "Feed" } :: { Step }
Tutorial.QuestName = "Baker's first cake"
Tutorial.QuestReward = 75_000 -- money when the cake gives its effect

Tutorial.Zone = "PumpkinGraveyard" -- where the first hunt goes
Tutorial.Monster = "Gloomlet" -- the tutorial's own monster, only the player can catch it
local Monster = Names[Tutorial.Monster] -- what the guide card calls it
Tutorial.Effect = "Cobwebbed" -- the cheapest effect, shown off as soon as it's home
Tutorial.FirstVacuum = "PhantomVac" -- the first thing bought in the shop (Giles 2026-10-21)
Tutorial.Cake = "PumpkinCandy" -- the first cake, bought with the Baker's gift
Tutorial.CakeEffect = "PumpkinHead" -- what the Pumpkin Candy gives
Tutorial.SecondMonster = "Skittercrow" -- the second catch, the one that eats the cake
local Second = Names[Tutorial.SecondMonster] or Tutorial.SecondMonster -- shown as Grave Raven
Tutorial.FeedSeconds = 15 -- no bite by then (it got stuck, say): it gets Pumpkin Head anyway
Tutorial.RespawnSeconds = 5 -- a tutorial monster that vanished comes back after this long
Tutorial.HintSeconds = 120 -- stuck on one step this long: a bigger hint shows

-- Buttons and keys that stay greyed out until their step: feature -> first step it works.
-- The fast-travel features match Config/Travel's destination ids. Anything not listed is
-- locked until the tutorial is done.
Tutorial.Unlocks = {
	Home = "Gate", -- the Mansion fast-travel button
	Portals = "Gate",
	Hotbar = "Catch",
	Backpack = "Sell",
	MansionList = "Sell", -- the arrow tab on the right edge, with a Pick up button per monster
	Sell = "Sell",
	Shops = "Buy",
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
	Gate = "Walk to the Pumpkin Graveyard gate.",
	Catch = `Press 1 for your vacuum and click the {Monster}. Click when the needle is in the green!`,
	Home = "Got it! Walk back out, or press R.",
	Sell = `Your {Monster} is in your Backpack. Sell it at the Collector.`,
	Buy = "Here's a gift! Buy the Phantom Vac at the Vacuum Vault.",
	Bake = "The Baker paid for a Pumpkin Candy. Buy it at the Bakery!",
	Place = "Hold the Pumpkin Candy and click your mansion floor.",
	Hunt = `Catch the {Second} in the Pumpkin Graveyard.`,
	Return = "Got it! Bring it home.",
	Feed = "Watch it eat the cake!",
} :: { [Step]: string }

Tutorial.TouchText = {
	Catch = `Tap slot 1 for your vacuum and tap the {Monster}. Tap when the needle is in the green!`,
	Home = "Got it! Walk back out, or tap Return Charm.",
	Place = "Hold the Pumpkin Candy and tap your mansion floor.",
} :: { [Step]: string }

-- Shown under the guide card after HintSeconds on one step.
Tutorial.Hints = {
	Gate = "The Zone Gates are at the far end of the hub. Press Portals to jump there.",
	Catch = "Hold your vacuum (the first hotbar slot) and stay close. Each struggle is one click, tap or F while the needle crosses the green zone; miss and it breaks free for a moment, so just try again.",
	Home = "Walk back through the exit arch you came in by.",
	Sell = `Talk to the Collector (E or tap Talk) and pick "I want to sell my monsters.", then press Sell on your {Monster}.`,
	Buy = 'Talk to the Vacuum Vault (between the Bakery and the Workshop) and pick "Show me the vacuums.", then press the Phantom Vac card and Buy.',
	Bake = 'Press Shops and talk to the Haunted Bakery (the pink striped shop). Pick "I want to buy cakes!", then press the Pumpkin Candy card and Buy.',
	Place = "Stand inside your mansion, hold the Pumpkin Candy (it's in your hotbar) and click or tap the floor in front of you.",
	Hunt = `Press Portals to jump to the Zone Gates, walk into the Pumpkin Graveyard and follow the trail to the {Second}.`,
	Return = "Walk back through the exit arch you came in by.",
	Feed = `Leave the {Second} in your mansion (don't pick it up). It gets Pumpkin Head in a few seconds.`,
} :: { [Step]: string }

-- The words for a step on this device: the touch version when there's no keyboard.
function Tutorial.textFor(step: string, touch: boolean): string
	local text = if touch then Tutorial.TouchText[step :: Step] else nil
	return text or Tutorial.Text[step :: Step] or ""
end

-- Where a step is in a list (0 for an unknown step).
local function indexIn(list: { Step }, step: string?): number
	for index, candidate in list do
		if candidate == step then
			return index
		end
	end
	return 0
end

-- Where a step is in the tutorial (0 for an unknown step).
function Tutorial.index(step: string?): number
	return indexIn(Tutorial.Steps, step)
end

-- Where a step is in the Bakery quest (0 for an unknown step).
function Tutorial.questIndex(step: string?): number
	return indexIn(Tutorial.QuestSteps, step)
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

-- The quest step after this one ("Done" after Feed).
function Tutorial.nextQuestStep(step: string): string
	local index = Tutorial.questIndex(step)
	return Tutorial.QuestSteps[index + 1] or "Done"
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
-- catch is lost), so the hunting steps start over at the gate. Saves from the longer
-- tutorial: Pickup goes on at the sell step.
function Tutorial.resumeAt(step: string): string
	if step == "Catch" or step == "Home" then
		return "Gate"
	elseif step == "Pickup" then
		return "Sell"
	elseif step == "Tour" then
		return "Done"
	end
	return step
end

-- The quest step a returning player picks up at: a lost second hunt starts over at Hunt.
function Tutorial.resumeQuestAt(step: string): string
	return if step == "Return" then "Hunt" else step
end

-- A save from the longer tutorial that was in its Bakery part: that part is the quest now,
-- so the tutorial counts as done and the quest goes on from here. Nil for any other step.
function Tutorial.questFor(oldStep: string): string?
	if Tutorial.questIndex(oldStep) == 0 then
		return nil
	end
	return Tutorial.resumeQuestAt(oldStep)
end

-- A one-time gift: enough to afford the first vacuum (the Collector) or the first cake (the
-- Baker), never negative.
function Tutorial.gift(money: number, price: number): number
	return math.max(price - money, 0)
end

return Tutorial
