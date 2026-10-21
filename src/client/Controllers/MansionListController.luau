--!strict
-- "Your mansion": a list of every monster in your mansion with a Pick up button, so you
-- don't have to walk round the wings to find one. Opened from the "Mansion" button in the
-- HUD on the left (M on a keyboard). Rows come from InventoryRemotes.GetView and picking up
-- uses InventoryRemotes.Move, the same as E on the monster itself (server/Services/InventoryService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Locks = require(script.Parent.Parent:WaitForChild("Locks"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local MansionListController = {}

type MonsterRow = {
	uid: string,
	name: string,
	details: string,
	color: Color3,
	value: string,
	stored: boolean,
}
type View = {
	monsters: { MonsterRow },
	mansionCount: number,
	mansionCapacity: number,
}
type Result = { ok: boolean, message: string, view: View? }

function MansionListController.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("InventoryRemotes")
	local GetView = remotes:WaitForChild("GetView") :: RemoteFunction
	local Move = remotes:WaitForChild("Move") :: RemoteFunction

	local window = Ui.window("MansionListUi", "Your mansion")
	local busy = false

	local function render(view: View?, message: string?)
		Ui.clear(window.list)
		if not view then
			window.status.Text = "Your save is still loading. Try again in a moment!"
			return
		end
		local status = `{view.mansionCount}/{view.mansionCapacity} monsters in your mansion`
		window.status.Text = if message then `{message}\n{status}` else status
		local order = 0
		for _, row in view.monsters do
			if row.stored then
				continue
			end
			order += 1
			local _, actions = Ui.row(window.list, order, row.name, row.color, `{row.value} · {row.details}`)
			local pick = Ui.button(actions, "Pick up", Ui.Colors.buy, UDim2.fromScale(1, 1))
			pick.Activated:Connect(function()
				if busy then
					return
				end
				busy = true
				local ok, result = pcall(Move.InvokeServer, Move, row.uid)
				busy = false
				local answer: Result? = if ok then result else nil
				if answer and window.isOpen() then
					render(answer.view, answer.message)
				end
			end)
		end
		if order == 0 then
			Ui.row(
				window.list,
				1,
				"No monsters yet",
				Ui.Colors.muted,
				"Catch some and place them in your mansion."
			)
		end
	end

	local function toggle()
		if window.isOpen() then
			window.close()
			return
		end
		window.status.Text = "Loading..."
		Ui.clear(window.list)
		window.open(nil)
		local ok, result = pcall(GetView.InvokeServer, GetView)
		if window.isOpen() then
			render(if ok then result else nil)
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M and not Locks.isLocked("Backpack") then
			toggle()
		end
	end)

	local hud = player:WaitForChild("PlayerGui"):WaitForChild("HuntUi"):WaitForChild("Hud")
	local button = hud:WaitForChild("Mansion") :: TextButton
	button.Activated:Connect(toggle)
	Locks.guard(button, "Backpack") -- unlocks together with the Backpack
end

return MansionListController
