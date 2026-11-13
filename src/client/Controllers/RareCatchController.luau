--!strict
-- Rare catch moments (server RareCatchService, rules in Util/RareCatch):
--   Reveal  our own Epic-or-better catch: a short card in the rarity's colour
--   Shout   someone else in this server caught a Mythic, Divine or Rainbow: a thin banner
--   Far     the same from another server: chat only
-- Every Shout and every Far, and our own shouted catches, also go in the chat.
-- Flat style (Ui.Style): solid panel, one colour bar, two lines of text.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Scale = require(script.Parent.Parent.Scale)
local Ui = require(script.Parent.Parent.Ui)

local RareCatchController = {}

local player = Players.LocalPlayer

local REVEAL_SECONDS = 2.4
local SHOUT_SECONDS = 4
local SHOUT_TOP = 200 -- below the admin announcement banner

type Payload = { kind: string, title: string, monster: string, color: { number }, line: string, chat: boolean? }

local canvas: Frame
local shownReveal = 0
local shownShout = 0

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1] or 255, color[2] or 255, color[3] or 255)
end

local function hex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function escape(text: string): string
	return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function addToChat(text: string, color: Color3, far: boolean)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local channel = channels
			and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
		if channel and channel:IsA("TextChannel") then
			local mark = if far then "🌐 " else "⭐ "
			channel:DisplaySystemMessage(`<font color="{hex(color)}">{mark}{escape(text)}</font>`)
		end
	end)
end

local function fadeOut(frame: GuiObject, seconds: number, after: () -> ())
	local tween = TweenService:Create(frame, TweenInfo.new(seconds), { GroupTransparency = 1 } :: any)
	tween:Play()
	tween.Completed:Connect(after)
end

-- A CanvasGroup with a colour bar on top, a big title and the monster's name.
local function card(name: string, size: UDim2, position: UDim2): (CanvasGroup, Frame, TextLabel, TextLabel)
	local group = Instance.new("CanvasGroup")
	group.Name = name
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = position
	group.Size = size
	group.BackgroundColor3 = Ui.Colors.panel
	group.BackgroundTransparency = 0.05
	group.Visible = false
	group.Parent = canvas
	Ui.corner(group, Ui.Style.panelRadius)
	Ui.rim(group, Ui.Style.line, 1)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.BorderSizePixel = 0
	bar.Parent = group
	local big = Ui.text(group, "", UDim2.new(1, -24, 0.5, 0), Ui.Colors.text, true, 40)
	big.Font = Ui.TitleFont
	big.TextXAlignment = Enum.TextXAlignment.Center
	big.Position = UDim2.new(0, 12, 0, 10)
	local small = Ui.text(group, "", UDim2.new(1, -24, 0.32, 0), Ui.Colors.text, false, 24)
	small.TextXAlignment = Enum.TextXAlignment.Center
	small.Position = UDim2.new(0, 12, 0.56, 0)
	return group, bar, big, small
end

local reveal: CanvasGroup
local revealBar: Frame
local revealTitle: TextLabel
local revealName: TextLabel
local revealScale: UIScale
local shout: CanvasGroup
local shoutBar: Frame
local shoutLine: TextLabel

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RareCatchUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.IgnoreGuiInset = true
	canvas = Scale.canvas(gui)

	reveal, revealBar, revealTitle, revealName =
		card("Reveal", UDim2.fromOffset(360, 110), UDim2.fromScale(0.5, 0.32))
	revealScale = Instance.new("UIScale")
	revealScale.Parent = reveal

	local spare: TextLabel
	shout, shoutBar, shoutLine, spare =
		card("Shout", UDim2.fromOffset(520, 46), UDim2.new(0.5, 0, 0, SHOUT_TOP))
	shoutLine.Size = UDim2.new(1, -24, 1, -12)
	shoutLine.Position = UDim2.new(0, 12, 0, 8)
	shoutLine.Font = Enum.Font.FredokaOne
	spare:Destroy() -- one line is enough for a banner

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function showReveal(payload: Payload)
	shownReveal += 1
	local mine = shownReveal
	local color = rgb(payload.color)
	revealBar.BackgroundColor3 = color
	revealTitle.TextColor3 = color
	revealTitle.Text = string.upper(payload.title) .. "!"
	revealName.Text = payload.monster
	reveal.GroupTransparency = 0
	reveal.Visible = true
	revealScale.Scale = 0.6
	TweenService:Create(revealScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	task.delay(REVEAL_SECONDS, function()
		if mine ~= shownReveal then
			return
		end
		fadeOut(reveal, 0.4, function()
			if mine == shownReveal then
				reveal.Visible = false
			end
		end)
	end)
end

local function showShout(payload: Payload)
	shownShout += 1
	local mine = shownShout
	local color = rgb(payload.color)
	shoutBar.BackgroundColor3 = color
	shoutLine.TextColor3 = color
	shoutLine.Text = payload.line
	shout.GroupTransparency = 0
	shout.Visible = true
	task.delay(SHOUT_SECONDS, function()
		if mine ~= shownShout then
			return
		end
		fadeOut(shout, 0.5, function()
			if mine == shownShout then
				shout.Visible = false
			end
		end)
	end)
end

local function valid(payload: unknown): Payload?
	if typeof(payload) ~= "table" then
		return nil
	end
	local p = payload :: any
	if typeof(p.kind) ~= "string" or typeof(p.line) ~= "string" or typeof(p.color) ~= "table" then
		return nil
	end
	if typeof(p.title) ~= "string" or typeof(p.monster) ~= "string" then
		return nil
	end
	return p :: Payload
end

function RareCatchController.start()
	build()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:WaitForChild("RareCatch") :: RemoteEvent
	remote.OnClientEvent:Connect(function(raw: unknown)
		local payload = valid(raw)
		if not payload then
			return
		end
		local color = rgb(payload.color)
		if payload.kind == "Reveal" then
			showReveal(payload)
			-- Our own shouted catch goes in our chat too, like everyone else sees it.
			if payload.chat then
				addToChat(payload.line, color, false)
			end
		elseif payload.kind == "Shout" then
			showShout(payload)
			addToChat(payload.line, color, false)
		elseif payload.kind == "Far" then
			addToChat(payload.line, color, true)
		end
	end)
end

return RareCatchController
