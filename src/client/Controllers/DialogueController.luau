--!strict
-- Talking to a stand in the hub, like the NPCs in Grow a Garden: press E at the Bakery,
-- the Workshop, the Vacuum Vault, the Collector or the Watcher (or tap the prompt) and a
-- plain dialogue box opens at the bottom of the screen. The stand's name, its line typed out
-- letter by letter (click or tap the box to skip), then three choices: ask about the stand,
-- enter it (opens its shop or sell window) or quit. Some stands have a second window too
-- (`extra`, like the Merger's Variant Machine). Walking away closes it.
-- The lines are in Shared.Config.Stands; the prompts and the Enter check in server/Counter.
-- While the dialogue or a shop window is open the stands' Talk prompts are hidden, so a click
-- that falls between the shop's cards can't hit the prompt behind the window and talk again.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Config.Events)
local Stands = require(ReplicatedStorage.Shared.Config.Stands)
local Watcher = require(ReplicatedStorage.Shared.Util.Watcher)
local Scale = require(script.Parent.Parent:WaitForChild("Scale"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local DialogueController = {}

local WalkAwayDistance = 22 -- studs from the stand before the dialogue closes by itself
local LettersPerSecond = 60

-- What the Watcher says to "What's happening now?": the live event, the one about to
-- start, or when the next one comes (the schedule is the same in every server).
local function watcherNow(): string
	local now = workspace:GetServerTimeNow()
	local live = Events.find(workspace:GetAttribute("WatcherEvent"))
	if live then
		local ends = tonumber(workspace:GetAttribute("WatcherEventEnd")) or now
		local lines = Watcher.effectLines(live)
		table.remove(lines) -- the Familiarity note
		local effect = if #lines > 0 then ` {table.concat(lines, ". ")}.` else ""
		return `{live.name} is happening right now!{effect} It ends in {Watcher.clock(ends - now)}.`
	end
	local coming = Events.find(workspace:GetAttribute("WatcherNext"))
	if coming then
		local starts = tonumber(workspace:GetAttribute("WatcherSkyAt")) or now
		return `Look at the sky... {coming.name} starts in {Watcher.clock(starts - now)}.`
	end
	local slot = Watcher.slotAt(now)
	return `All is quiet. I will stir again in {Watcher.clock(slot.warnAt - now)}.`
end

function DialogueController.start()
	local remotes = ReplicatedStorage:WaitForChild("StandRemotes")
	local Talk = remotes:WaitForChild("Talk") :: RemoteEvent
	local Enter = remotes:WaitForChild("Enter") :: RemoteEvent
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	local canvas = Scale.canvas(gui) -- shrinks everything to fit a phone (client/Scale)
	gui.Name = "DialogueUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Just above the hotbar.
	local box = Instance.new("TextButton")
	box.Name = "Box"
	box.AutoButtonColor = false
	box.Text = ""
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -84)
	box.Size = UDim2.fromOffset(560, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.BackgroundColor3 = Color3.new(0, 0, 0)
	box.BackgroundTransparency = 0.35
	box.BorderSizePixel = 0
	box.Parent = canvas
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = box
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = box
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = box

	local function label(order: number, size: number): TextLabel
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, 0, 0, 0)
		text.AutomaticSize = Enum.AutomaticSize.Y
		text.Font = Enum.Font.FredokaOne
		text.TextSize = size
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextWrapped = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.LayoutOrder = order
		text.Parent = box
		return text
	end
	local name = label(1, 22)
	local line = label(2, 20)

	local choices = Instance.new("Frame")
	choices.Name = "Choices"
	choices.BackgroundTransparency = 1
	choices.Size = UDim2.new(1, 0, 0, 0)
	choices.AutomaticSize = Enum.AutomaticSize.Y
	choices.LayoutOrder = 3
	choices.Parent = box
	local choiceLayout = Instance.new("UIListLayout")
	choiceLayout.SortOrder = Enum.SortOrder.LayoutOrder
	choiceLayout.Padding = UDim.new(0, 4)
	choiceLayout.Parent = choices

	local standId: string? = nil
	local standAt: Vector3? = nil
	local typing: RBXScriptConnection? = nil

	local function close()
		if typing then
			typing:Disconnect()
			typing = nil
		end
		standId = nil
		standAt = nil
		gui.Enabled = false
	end

	local function clearChoices()
		for _, child in choices:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
	end

	local function choice(order: number, text: string, picked: () -> ())
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.BackgroundColor3 = Color3.new(1, 1, 1)
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Size = UDim2.new(1, 0, 0, 30)
		button.Font = Enum.Font.FredokaOne
		button.TextSize = 19
		button.TextColor3 = Color3.fromRGB(255, 220, 120)
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = `{order}. {text}`
		button.LayoutOrder = order
		button.MouseEnter:Connect(function()
			button.BackgroundTransparency = 0.85
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundTransparency = 1
		end)
		button.Activated:Connect(picked)
		button.Parent = choices
	end

	-- Types out what the stand says, then shows the choices.
	local say: (text: string) -> ()
	local function showChoices()
		clearChoices()
		local stand = standId and Stands[standId]
		if not stand then
			return
		end
		choice(1, stand.info.ask, function()
			say(stand.info.answer)
		end)
		choice(2, stand.enter.ask, function()
			if stand.enter.live then
				say(watcherNow())
			else
				Enter:FireServer(standId)
				close()
			end
		end)
		local extra = stand.extra
		if extra then
			choice(3, extra.ask, function()
				Enter:FireServer(standId, extra.option)
				close()
			end)
		end
		choice(if extra then 4 else 3, stand.quit, close)
	end

	say = function(text: string)
		clearChoices()
		if typing then
			typing:Disconnect()
		end
		line.Text = text
		line.MaxVisibleGraphemes = 0
		local total = utf8.len(text) or #text
		local shown = 0
		typing = RunService.Heartbeat:Connect(function(dt: number)
			shown += dt * LettersPerSecond
			line.MaxVisibleGraphemes = math.floor(shown)
			if shown >= total then
				line.MaxVisibleGraphemes = -1
				if typing then
					typing:Disconnect()
					typing = nil
				end
				showChoices()
			end
		end)
	end

	-- Click or tap the box to skip the typing.
	box.Activated:Connect(function()
		if typing then
			typing:Disconnect()
			typing = nil
			line.MaxVisibleGraphemes = -1
			showChoices()
		end
	end)

	Talk.OnClientEvent:Connect(function(id: unknown, at: unknown)
		if typeof(id) ~= "string" or typeof(at) ~= "Vector3" then
			return
		end
		local stand = Stands[id]
		if not stand or Ui.anyWindowOpen("BackpackUi") then
			return
		end
		standId = id
		standAt = at
		name.Text = stand.name
		gui.Enabled = true
		say(stand.greeting)
	end)

	-- Hide the stands' prompts (on this screen only) while talking or shopping.
	local function busy(): boolean
		return gui.Enabled or Ui.anyWindowOpen("BackpackUi")
	end
	local function showPrompt(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = not busy()
		end
	end
	local function showPrompts()
		for _, prompt in CollectionService:GetTagged("StandPrompt") do
			showPrompt(prompt)
		end
	end
	CollectionService:GetInstanceAddedSignal("StandPrompt"):Connect(showPrompt)
	gui:GetPropertyChangedSignal("Enabled"):Connect(showPrompts)
	Ui.windowsChanged:Connect(showPrompts)
	showPrompts()

	-- Walking away (or travelling) closes it.
	RunService.Heartbeat:Connect(function()
		if not gui.Enabled or not standAt then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - standAt).Magnitude > WalkAwayDistance then
			close()
		end
	end)
end

return DialogueController
