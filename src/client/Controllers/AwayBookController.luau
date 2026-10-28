--!strict
-- The "while you were away" book. When you join after being away, your mansion monsters
-- have kept growing and may have picked up roaming effects; the server plays that back and
-- sends what changed (ReplicatedStorage.Remotes.AwayBook, server/Services/MansionService).
-- This shows it as a small window: one line per monster with its weight gain, size change
-- and new effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Weight = require(Shared:WaitForChild("Util"):WaitForChild("Weight"))
local Loading = require(script.Parent.Parent:WaitForChild("Loading"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local AwayBookController = {}

type Change = {
	monsterId: string,
	kgBefore: number?,
	kgAfter: number?,
	sizeBefore: string,
	sizeAfter: string,
	effects: { string },
}

local EffectColor = Color3.fromRGB(205, 150, 255)

-- "3 h 12 min", "2 days 4 h", "45 min".
local function awayText(seconds: number): string
	local minutes = seconds // 60
	local hours = minutes // 60
	local days = hours // 24
	if days > 0 then
		return `{days} {if days == 1 then "day" else "days"} {hours % 24} h`
	elseif hours > 0 then
		return `{hours} h {minutes % 60} min`
	end
	return `{math.max(minutes, 1)} min`
end

-- "+12 kg (20 kg to 32 kg) · Big to Huge"
local function growthText(change: Change): string
	local parts: { string } = {}
	local before, after = change.kgBefore, change.kgAfter
	if before and after and after > before then
		table.insert(parts, `+{Weight.text(after - before)} ({Weight.text(before)} to {Weight.text(after)})`)
	end
	if change.sizeAfter ~= change.sizeBefore then
		table.insert(parts, `{change.sizeBefore} to {change.sizeAfter}`)
	end
	return if #parts > 0 then table.concat(parts, " · ") else "Didn't grow"
end

function AwayBookController.start()
	local window = Ui.window("AwayBookUi", "While you were away")
	window.gui.DisplayOrder = 7 -- over the HUD and the Backpack
	local ok = Ui.button(window.footer, "Nice!", Ui.Colors.buy, UDim2.new(0.5, 0, 1, -8))
	ok.AnchorPoint = Vector2.new(0.5, 0)
	ok.Position = UDim2.new(0.5, 0, 0, 4)
	ok.Activated:Connect(window.close)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:WaitForChild("AwayBook") :: RemoteEvent
	remote.OnClientEvent:Connect(function(changes: { Change }, seconds: number)
		if typeof(changes) ~= "table" or #changes == 0 then
			return
		end
		Loading.wait() -- not under the loading screen
		Ui.clear(window.list)
		local effects = 0
		for _, change in changes do
			effects += #change.effects
		end
		window.status.Text = `Away {awayText(seconds)} · {#changes} {if #changes == 1
			then "monster"
			else "monsters"} changed · {effects} new {if effects == 1 then "effect" else "effects"}`
		for i, change in changes do
			local _, side =
				Ui.row(window.list, i, Format.name(change.monsterId), Ui.Colors.text, growthText(change))
			if #change.effects > 0 then
				local names: { string } = {}
				for _, id in change.effects do
					table.insert(names, Format.name(id))
				end
				local label = Ui.text(
					side,
					`+ {table.concat(names, ", ")}`,
					UDim2.fromScale(1, 1),
					EffectColor,
					true,
					16
				)
				label.TextWrapped = true
				label.TextXAlignment = Enum.TextXAlignment.Right
			end
		end
		window.open()
	end)
end

return AwayBookController
