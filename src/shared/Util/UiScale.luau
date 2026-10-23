--!strict
-- How big to draw the HUD and windows on a screen. They are laid out in pixels for a computer
-- screen (about 1000 x 600 or more); a phone held sideways is only about 850 x 390, so there
-- everything is drawn smaller (client/Scale). The "UI size" setting (Shared.Util.Settings)
-- makes it a bit smaller or bigger on top of that. Pure so it can be tested outside Roblox.

local UiScale = {}

UiScale.Reference = { width = 1000, height = 600 } -- a screen this big or bigger draws at 1
UiScale.Smallest = 0.55 -- never smaller than this from the screen size alone
UiScale.Choices = { Small = 0.85, Normal = 1, Large = 1.15 } :: { [string]: number }

-- How much to shrink for a screen of this size (in Roblox's screen pixels), from Smallest to 1.
function UiScale.fit(width: number, height: number): number
	if width <= 0 or height <= 0 then
		return 1
	end
	local fit = math.min(width / UiScale.Reference.width, height / UiScale.Reference.height)
	return math.clamp(fit, UiScale.Smallest, 1)
end

-- The factor to draw at: the screen's fit times the player's UI size choice.
function UiScale.factor(width: number, height: number, choice: any): number
	local extra = if typeof(choice) == "string" then UiScale.Choices[choice] else nil
	return UiScale.fit(width, height) * (extra or 1)
end

-- A phone-sized screen, where the HUD is drawn noticeably smaller.
function UiScale.isSmall(width: number, height: number): boolean
	return UiScale.fit(width, height) < 0.9
end

return UiScale
