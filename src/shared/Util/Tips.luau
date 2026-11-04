--!strict
-- One-time "unlock tutorials" (Giles 2026-11-04): the first time a player unlocks something
-- that adds a new kind of thing to do, a card on the right explains it once. Plain
-- progression (a new wing, a new zone, a better vacuum) gets no card. They only start once
-- the first-timer tutorial is done (Util/Tutorial), come one at a time with a short gap, and
-- each is saved as seen in the save's `tips` field when the player presses Got it.
-- The server decides when one is due (server/Services/TipService, which builds the Facts),
-- the client draws it in the tutorial's card (client/Controllers/TutorialController).
-- Pure functions so they can be tested outside Roblox.

local GoldenGhost = require("../Config/GoldenGhost")
local Heists = require("../Config/Heists")
local VariantMachine = require("../Config/VariantMachine")

local Tips = {}

-- What the server knows about a player when it looks for a due tip.
export type Facts = {
	wings: number, -- wings owned, the Foyer counts as one
	owns: { [string]: boolean }, -- shop item kinds they have at least one of (Config/Shop kind)
	pair: boolean, -- two of the same monster in their Backpack
	combo: boolean, -- they've made at least one combo (the Codex)
	playSeconds: number, -- time played, for the stealing shield (Config/Heists)
	event: boolean, -- a Watcher event is on right now
	ghost: boolean, -- a Golden Ghost is out right now
	inHub: boolean, -- in the hub (not in a zone)
}

export type Tip = {
	id: string,
	title: string,
	text: string, -- with a keyboard
	touch: string?, -- on a phone or tablet without one, where the words differ
	landmark: string?, -- Hub.Landmarks child the trail points at while the card is up (in the hub)
	-- Only while it's happening (an event, the Golden Ghost): once it's over before Got it,
	-- the card goes away unseen and comes back next time.
	live: boolean?,
	due: (Facts) -> boolean,
}

-- In the order they're offered when several are due at once (an older save, say).
Tips.List = {
	{
		id = "VariantMachine",
		title = "Variant Machine unlocked!",
		text = 'The Merger fired up the Variant Machine. Press E at the Merger and pick "Try the Variant Machine". Put in a monster from your Backpack: the machine eats one of its effects, picked at random, for one try at a better colour (Silver 15%, Gold 7%, Shiny 3%, Rainbow 1%). Your monster always comes back.',
		touch = 'The Merger fired up the Variant Machine. Tap Talk at the Merger and pick "Try the Variant Machine". Put in a monster from your Backpack: the machine eats one of its effects, picked at random, for one try at a better colour (Silver 15%, Gold 7%, Shiny 3%, Rainbow 1%). Your monster always comes back.',
		landmark = "Merger",
		due = function(facts: Facts): boolean
			return facts.wings >= VariantMachine.UnlockWings
		end,
	},
	{
		id = "Slapper",
		title = "You can slap now!",
		text = "Hold your slapper from the hotbar and walk up to another hunter in a zone or the open hub. When the Slap sign shows bottom right, click to slap. A slap knocks them back, makes the monster they're catching break loose, and stops a thief from stealing for a while.",
		touch = "Hold your slapper from the hotbar and walk up to another hunter in a zone or the open hub. When the Slap sign shows bottom right, tap to slap. A slap knocks them back, makes the monster they're catching break loose, and stops a thief from stealing for a while.",
		due = function(facts: Facts): boolean
			return facts.owns.Slapper == true
		end,
	},
	{
		id = "BaitBell",
		title = "Bait Bells",
		text = "In a zone, press the Bait Bell button on the left (or B) to call a monster straight to you, so you don't have to look for one. Silver and Gold Bells call rarer monsters. Each bell rings once.",
		touch = "In a zone, tap the Bait Bell button on the left to call a monster straight to you, so you don't have to look for one. Silver and Gold Bells call rarer monsters. Each bell rings once.",
		due = function(facts: Facts): boolean
			return facts.owns.Lure == true
		end,
	},
	{
		id = "Cake",
		title = "Your first cake",
		text = "Hold the cake from your hotbar and click the floor in one of your wings to set it out. Monsters near it come over for bites and can pick up its effect, even while you're offline. Point at a placed cake to see how far it reaches. You can have 5 cakes out for every wing you own.",
		touch = "Hold the cake from your hotbar and tap the floor in one of your wings to set it out. Monsters near it come over for bites and can pick up its effect, even while you're offline. Tap a placed cake to see how far it reaches. You can have 5 cakes out for every wing you own.",
		due = function(facts: Facts): boolean
			return facts.owns.Food == true
		end,
	},
	{
		id = "NameTag",
		title = "Name Tags",
		text = "Hold the Name Tag from your hotbar and click one of your mansion monsters to give it a name of your own. A traded or gifted monster loses its name.",
		touch = "Hold the Name Tag from your hotbar and tap one of your mansion monsters to give it a name of your own. A traded or gifted monster loses its name.",
		due = function(facts: Facts): boolean
			return facts.owns.Tag == true
		end,
	},
	{
		id = "Potion",
		title = "Luck potions",
		text = "Hold the potion from your hotbar and click to drink it. While it lasts, Silver, Gold, Shiny and Rainbow catches are more likely. The flask bottom right shows the time left, which only runs while you're in the game. A stronger potion replaces a weaker one.",
		touch = "Hold the potion from your hotbar and tap to drink it. While it lasts, Silver, Gold, Shiny and Rainbow catches are more likely. The flask bottom right shows the time left, which only runs while you're in the game. A stronger potion replaces a weaker one.",
		due = function(facts: Facts): boolean
			return facts.owns.Potion == true
		end,
	},
	{
		id = "Merger",
		title = "Two of a kind!",
		text = 'You have two of the same monster in your Backpack. Press E at the Merger and pick "Let\'s merge!": one goes into the other, which gets heavier and keeps the effects of both, and combos can form. It can fail, and then the one you gave is gone. You see the odds and the fee first.',
		touch = 'You have two of the same monster in your Backpack. Tap Talk at the Merger and pick "Let\'s merge!": one goes into the other, which gets heavier and keeps the effects of both, and combos can form. It can fail, and then the one you gave is gone. You see the odds and the fee first.',
		landmark = "Merger",
		due = function(facts: Facts): boolean
			return facts.pair
		end,
	},
	{
		id = "Combo",
		title = "Your first combo!",
		text = "Two effects on one monster just made a combo, and combos are worth a lot more. The recipes are secret: each combo you make is written in your Codex (C, the book button), and it gives clues for the ones you haven't found yet.",
		touch = "Two effects on one monster just made a combo, and combos are worth a lot more. The recipes are secret: each combo you make is written in your Codex (the book button), and it gives clues for the ones you haven't found yet.",
		due = function(facts: Facts): boolean
			return facts.combo
		end,
	},
	{
		id = "Event",
		title = "A Watcher event!",
		text = "The Watcher woke an event in every server: the sky changes, your mansion monsters can get its effect, rare monsters may show up in the hub and the Bakery sells a special treat. Its icon is bottom right. A new one comes every 5 to 10 minutes, with a 30 second warning.",
		live = true,
		due = function(facts: Facts): boolean
			return facts.event
		end,
	},
	{
		id = "GoldenGhost",
		title = "A Golden Ghost!",
		text = `Quick! A Golden Ghost is zipping through the hub. Click it {GoldenGhost.Taps} times before anyone else does to win a prize.`,
		touch = `Quick! A Golden Ghost is zipping through the hub. Tap it {GoldenGhost.Taps} times before anyone else does to win a prize.`,
		live = true,
		due = function(facts: Facts): boolean
			return facts.ghost and facts.inHub
		end,
	},
	{
		id = "Stealing",
		title = "Your new-hunter shield is over",
		text = `For your first {Heists.NewPlayerSeconds // 3600} hours nobody could steal from you. Now other hunters can walk into your mansion and buy one of your monsters with Robux, at most {Heists.MaxLossesPerDay} a day and only while you're in the game. Heart (♥) your best monsters so they cost more to steal, and slap a thief to stop them.`,
		due = function(facts: Facts): boolean
			return facts.playSeconds >= Heists.NewPlayerSeconds
		end,
	},
} :: { Tip }

Tips.GapSeconds = 8 -- after Got it, the next due tip waits this long
Tips.FirstSeconds = 5 -- after joining (or finishing the tutorial), before the first one

local byId: { [string]: Tip } = {}
for _, tip in Tips.List do
	byId[tip.id] = tip
end

function Tips.get(id: string): Tip?
	return byId[id]
end

-- The words for a tip on this device: the touch version when there's no keyboard.
function Tips.textFor(id: string, touch: boolean): string
	local tip = byId[id]
	if not tip then
		return ""
	end
	return if touch and tip.touch then tip.touch else tip.text
end

-- The first tip that is due and not seen yet, or nil.
function Tips.next(facts: Facts, seen: { [string]: any }): string?
	for _, tip in Tips.List do
		if not seen[tip.id] and tip.due(facts) then
			return tip.id
		end
	end
	return nil
end

-- Whether a tip on screen should be taken away unseen: a live one whose moment is over.
function Tips.expired(id: string, facts: Facts): boolean
	local tip = byId[id]
	return tip ~= nil and tip.live == true and not tip.due(facts)
end

-- Two monsters of the same kind in a list of caught monsters (the Backpack).
function Tips.hasPair(monsters: { any }): boolean -- Value.CaughtMonster, with monsterId
	local seen: { [string]: boolean } = {}
	for _, caught in monsters do
		if seen[caught.monsterId] then
			return true
		end
		seen[caught.monsterId] = true
	end
	return false
end

return Tips
