--!strict
-- The small box that asks for a monster's name when you use a Name Tag (Config/Shop NameTag).
-- The Backpack and the mansion list both open it. Saving calls InventoryRemotes.Rename, which
-- uses up one Name Tag; "Remove name" is free. `done` gets the server's answer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent:WaitForChild("Ui"))

local NamePrompt = {}

local MaxLength = 20 -- Util/Nickname.MaxLength; the server checks it again

local gui: ScreenGui? = nil

function NamePrompt.close()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

-- species: "Gravepup". current: its name now, if it has one. tags: Name Tags owned.
function NamePrompt.open(uid: string, species: string, current: string?, tags: number, done: (any) -> ())
	NamePrompt.close()
	local Rename = ReplicatedStorage:WaitForChild("InventoryRemotes"):WaitForChild("Rename") :: RemoteFunction

	local screen = Instance.new("ScreenGui")
	screen.Name = "NamePromptUi"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 8 -- over the Backpack and the mansion list
	gui = screen

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.45)
	box.Size = UDim2.fromOffset(320, if current then 196 else 156)
	box.BackgroundColor3 = Ui.Colors.panel
	box.Parent = screen
	Ui.corner(box, 12)
	Ui.rim(box, Ui.Colors.lamp, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.Parent = box

	local title = Ui.text(box, `Name your {species}`, UDim2.new(1, 0, 0, 26), Ui.Colors.lamp, true, 22)
	title.Font = Ui.TitleFont
	local hint = Ui.text(
		box,
		if tags > 0 then `Uses 1 Name Tag (you have {tags})` else "You need a Name Tag from the Workshop",
		UDim2.new(1, 0, 0, 16),
		Ui.Colors.muted,
		false,
		14
	)
	hint.Position = UDim2.fromOffset(0, 28)

	local input = Instance.new("TextBox")
	input.Position = UDim2.fromOffset(0, 50)
	input.Size = UDim2.new(1, 0, 0, 36)
	input.BackgroundColor3 = Ui.Colors.row
	input.Font = Enum.Font.FredokaOne
	input.PlaceholderText = "Type a name"
	input.PlaceholderColor3 = Ui.Colors.muted
	input.Text = current or ""
	input.TextColor3 = Ui.Colors.text
	input.TextSize = 20
	input.ClearTextOnFocus = false
	input.Parent = box
	Ui.corner(input, 8)
	input:GetPropertyChangedSignal("Text"):Connect(function()
		local length = utf8.len(input.Text)
		local cut = utf8.offset(input.Text, MaxLength + 1)
		if length and length > MaxLength and cut then
			input.Text = string.sub(input.Text, 1, cut - 1)
		end
	end)

	local busy = false
	local function send(name: string)
		if busy then
			return
		end
		busy = true
		local ok, result = pcall(Rename.InvokeServer, Rename, uid, name)
		busy = false
		if ok and typeof(result) == "table" then
			if result.ok then
				NamePrompt.close()
			else
				hint.Text = result.message
				hint.TextColor3 = Ui.Colors.confirm
			end
			done(result)
		end
	end

	local save = Ui.button(box, "Save", Ui.Colors.buy, UDim2.new(0.5, -4, 0, 36))
	save.Position = UDim2.fromOffset(0, 96)
	save.Activated:Connect(function()
		send(input.Text)
	end)
	local cancel = Ui.button(box, "Cancel", Ui.Colors.off, UDim2.new(0.5, -4, 0, 36))
	cancel.Position = UDim2.new(0.5, 4, 0, 96)
	cancel.Activated:Connect(NamePrompt.close)
	if current then
		local remove = Ui.button(box, "Remove name", Ui.Colors.confirm, UDim2.new(1, 0, 0, 32))
		remove.Position = UDim2.fromOffset(0, 140)
		remove.Activated:Connect(function()
			send("")
		end)
	end
	input.FocusLost:Connect(function(enter)
		if enter then
			send(input.Text)
		end
	end)

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	input:CaptureFocus()
end

return NamePrompt
