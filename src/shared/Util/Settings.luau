--!strict
-- Player settings: what each one is, its choices and its default. The save keeps them in
-- data.settings (server/Services/SettingsService checks every change), the client reads them
-- from player attributes (client/Settings) and the Settings window draws them
-- (client/Controllers/SettingsController). Pure so it can be tested outside Roblox.

local Settings = {}

export type Kind = "Volume" | "Choice" | "Toggle"
export type Setting = {
	key: string,
	name: string,
	detail: string,
	kind: Kind,
	options: { string }?, -- Choice only
	default: any,
}

Settings.VolumeMax = 100 -- volumes are whole percents from 0 to this, set with a slider

Settings.List = {
	{
		key = "music",
		name = "Music",
		detail = "The songs everyone in the server hears.",
		kind = "Volume",
		default = 100,
	},
	{
		key = "sounds",
		name = "Sound effects",
		detail = "Event sounds, thunder and ambience.",
		kind = "Volume",
		default = 100,
	},
	{
		key = "weather",
		name = "Event weather",
		detail = "Snow, rain, coins and candy during events. Less or Off helps slower phones.",
		kind = "Choice",
		options = { "Full", "Less", "Off" },
		default = "Full",
	},
	{
		key = "flashes",
		name = "Lightning flashes",
		detail = "The bright screen flashes in stormy events.",
		kind = "Toggle",
		default = true,
	},
	{
		-- Was "glow" (on by default); a new key so every save starts with it off (Giles 2026-10-21).
		key = "edgeGlow",
		name = "Screen edge glow",
		detail = "The coloured glow round the screen during an event.",
		kind = "Toggle",
		default = false,
	},
} :: { Setting }

function Settings.find(key: string): Setting?
	for _, setting in Settings.List do
		if setting.key == key then
			return setting
		end
	end
	return nil
end

-- The player attribute that holds a setting ("music" -> "SettingMusic").
function Settings.attribute(key: string): string
	return `Setting{string.upper(string.sub(key, 1, 1))}{string.sub(key, 2)}`
end

-- Whether a value is allowed for that setting (anything from a client is checked with this).
function Settings.valid(key: string, value: any): boolean
	local setting = Settings.find(key)
	if not setting then
		return false
	end
	if setting.kind == "Volume" then
		return typeof(value) == "number"
			and value == math.floor(value)
			and value >= 0
			and value <= Settings.VolumeMax
	elseif setting.kind == "Choice" then
		return typeof(value) == "string" and table.find(setting.options :: { string }, value) ~= nil
	end
	return typeof(value) == "boolean"
end

-- A saved value if it's allowed, else the default (older or broken saves).
function Settings.value(key: string, saved: any): any
	local setting = Settings.find(key)
	if not setting then
		return nil
	end
	return if Settings.valid(key, saved) then saved else setting.default
end

-- How much of the event weather to draw: all of it, about a third, or none.
function Settings.weatherScale(choice: any): number
	if choice == "Off" then
		return 0
	elseif choice == "Less" then
		return 0.35
	end
	return 1
end

return Settings
