--!strict
-- The Rebirth card (server RebirthService, rules in Util/Rebirth). Opens when the owner
-- presses the Rebirth sign (the expand sign once every wing is owned). Flat and short: the
-- bonus, what resets, what stays, one button that needs two taps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local ToastController = require(script.Parent.ToastController)
local Ui = require(script.Parent.Parent.Ui)

local RebirthController = {}

type View = { done: number, cost: number, money: number, bonusNow: number, bonusNext: number, ready: boolean }
type Result = { ok: boolean, message: string, view: View? }

local Word = "Rebirth"

local window: Ui.Window
local remote: RemoteFunction
local bonusLabel: TextLabel
local footerButton: TextButton? = nil
local asking = false

local function line(order: number, title: string, color: Color3, icons: string)
	local row, actions = Ui.row(window.list, order, title, color, icons)
	actions:Destroy() -- no buttons here, so the icons get the whole width
	for _, child in row:GetChildren() do
		if child:IsA("TextLabel") then
			child.Size = UDim2.new(1, 0, child.Size.Y.Scale, child.Size.Y.Offset)
		end
	end
end

local doRebirth: () -> ()

local function render(view: View)
	bonusLabel.Text = `Sell +{view.bonusNow}%  →  +{view.bonusNext}%`
	window.status.Text = if view.done > 0 then `Rebirths: {view.done}` else ""
	local old = footerButton
	if old then
		old:Destroy()
	end
	local button: TextButton
	if view.ready then
		button = Ui.button(window.footer, "Rebirth", Ui.Colors.buy, UDim2.fromScale(1, 1))
		Ui.confirmButton(button, "Sure? Tap again", doRebirth)
	else
		button =
			Ui.button(window.footer, `Need {Format.money(view.cost)}`, Ui.Colors.off, UDim2.fromScale(1, 1))
		button.AutoButtonColor = false
	end
	footerButton = button
end

doRebirth = function()
	if asking then
		return
	end
	asking = true
	local ok, result = pcall(function(): Result
		return remote:InvokeServer(Word)
	end)
	asking = false
	if not ok or typeof(result) ~= "table" then
		ToastController.show("Something went wrong, try again.")
		return
	end
	local answer = result :: Result
	if answer.message ~= "" then
		ToastController.show(answer.message)
	end
	if answer.ok then
		window.close()
	elseif answer.view then
		render(answer.view)
	end
end

local function build()
	window = Ui.window("RebirthUi", "Rebirth")
	local limit = window.panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(440, 400)
	end
	bonusLabel = Ui.text(window.list, "", UDim2.new(1, -8, 0, 44), Ui.Colors.money, true, 32)
	bonusLabel.Font = Ui.TitleFont
	bonusLabel.TextXAlignment = Enum.TextXAlignment.Center
	bonusLabel.LayoutOrder = 1
	line(2, "Resets", Ui.Colors.confirm, "💰 Money   🏚️ Wings   👻 Monsters")
	line(3, "Keeps", Ui.Colors.money, "🌀 Tools   🎂 Cakes   📖 Codex   R$ Robux")
end

function RebirthController.start()
	local remotes = ReplicatedStorage:WaitForChild("RebirthRemotes")
	remote = remotes:WaitForChild("Rebirth") :: RemoteFunction
	local offer = remotes:WaitForChild("Offer") :: RemoteEvent
	build()
	offer.OnClientEvent:Connect(function(view: unknown)
		if typeof(view) ~= "table" then
			return
		end
		render(view :: View)
		window.open()
	end)
end

return RebirthController
