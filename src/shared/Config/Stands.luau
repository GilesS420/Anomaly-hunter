--!strict
-- What the hub's stands say when you talk to them (client/Controllers/DialogueController).
-- Press E at a stand (or tap its prompt) and a Grow a Garden style dialogue opens at the
-- bottom of the screen: the stand's greeting, then three choices. "info" answers in the
-- dialogue, "enter" opens the stand's window (the shop or the sell window) and "quit" closes.
-- The ids are the landmark names (Counter.prompt); the Watcher's id is "Watcher".

export type Stand = {
	name: string, -- shown above the text
	greeting: string,
	info: { ask: string, answer: string },
	-- Opens the stand's window. With `live`, the Watcher answers in the dialogue instead
	-- (what's happening right now), since it has no window.
	enter: { ask: string, live: boolean? },
	quit: string,
}

local Stands: { [string]: Stand } = {
	Bakery = {
		name = "Haunted Bakery",
		greeting = "Welcome to the Haunted Bakery! Everything is fresh... mostly.",
		info = {
			ask = "What is this place?",
			answer = "I bake cakes for your mansion. Place one in a wing and it slowly gives the monsters there spooky effects, even while you're away. Each cake has its own effect and odds. New stock every 5 minutes, and Watcher events bring their own treats!",
		},
		enter = { ask = "I want to buy cakes!" },
		quit = "Never mind",
	},
	Workshop = {
		name = "Hunter's Workshop",
		greeting = "Hunter's Workshop. Mind the cables.",
		info = {
			ask = "What do you sell?",
			answer = "Tools for hunters. Bait Bells call a monster to you (Silver and Gold call rarer ones), a Return Charm brings you home from a zone, and a Name Tag lets you name a monster. New stock every 5 minutes. Vacuums are next door at the Vacuum Vault.",
		},
		enter = { ask = "Let me see your tools." },
		quit = "Never mind",
	},
	VacuumVault = {
		name = "Vacuum Vault",
		greeting = "Ah, a hunter! Looking for more suction?",
		info = {
			ask = "What is the Vacuum Vault?",
			answer = "Vacuums catch monsters. A better vacuum catches faster and can catch rarer monsters, and some monsters can only be caught with a strong one. Vacuums are always in stock.",
		},
		enter = { ask = "Show me the vacuums." },
		quit = "Never mind",
	},
	Collector = {
		name = "The Collector",
		greeting = "Ooh, what have you caught for me today?",
		info = {
			ask = "What do you do here?",
			answer = "I buy monsters from your Backpack. Heavier monsters and ones with more effects are worth more. Monsters roaming your mansion stay put, and ones you hearted (♥) are never sold.",
		},
		enter = { ask = "I want to sell my monsters." },
		quit = "Never mind",
	},
	Merger = {
		name = "The Merger",
		greeting = "Two in, one out! Hehehe... usually.",
		info = {
			ask = "What does the Merger do?",
			answer = "Bring me two of the same monster from your Backpack: one to keep and one to give. If it works, the one you keep gets heavier and takes every effect of the other, and combos can form! If it fails, the one you gave is gone. Rarer monsters are harder to merge. I show you the odds and my fee first.",
		},
		enter = { ask = "Let's merge!" },
		quit = "Never mind",
	},
	GrowthChamber = {
		name = "Growth Chamber",
		greeting = "Step right up! Bigger monsters, bigger prices.",
		info = {
			ask = "How does the chamber work?",
			answer = "Put a monster from your Backpack in and pick how hard to push it. Gentle is safe but grows a little. Strong and Reckless grow a lot more, but fail more often, and then your monster shrinks. It bubbles for about 20 minutes, even while you're away, then come back to see how it went. Every monster can go in 5 times.",
		},
		enter = { ask = "Let's grow a monster!" },
		quit = "Never mind",
	},
	Watcher = {
		name = "The Watcher",
		greeting = "...I see you.",
		info = {
			ask = "What are you?",
			answer = "Every 5 to 10 minutes I stir, and an event changes the sky for every server. While it lasts, mansion monsters can get its effect, rare monsters may appear in the hub and the Bakery sells a special treat. You get a 30 second warning first.",
		},
		enter = { ask = "What's happening now?", live = true },
		quit = "Goodbye",
	},
}

return Stands
