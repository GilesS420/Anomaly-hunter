--!strict
-- Press-and-drag for inventory cards and hotbar slots, with a mouse or a finger. A press that
-- barely moves is a click; past a few pixels a small ghost follows the pointer and, on
-- release, `drop` gets where it was let go (screen pixels, the same space as AbsolutePosition).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Drag = {}

local Threshold = 8 -- pixels before a press becomes a drag

local layer: ScreenGui? = nil
local function ghostLayer(): ScreenGui
	if not layer then
		local gui = Instance.new("ScreenGui")
		gui.Name = "DragUi"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = false -- the same space as InputObject.Position
		gui.DisplayOrder = 50
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		layer = gui
	end
	return layer :: ScreenGui
end

-- True if the screen point is inside the gui object.
function Drag.over(object: GuiObject, at: Vector2): boolean
	local from, size = object.AbsolutePosition, object.AbsoluteSize
	return object.Visible
		and at.X >= from.X
		and at.Y >= from.Y
		and at.X <= from.X + size.X
		and at.Y <= from.Y + size.Y
end

-- Makes `button` draggable. `enabled` says whether a drag may start right now.
function Drag.attach(
	button: GuiButton,
	label: () -> string,
	click: () -> (),
	drop: (at: Vector2) -> (),
	enabled: (() -> boolean)?
)
	button.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local start = Vector2.new(input.Position.X, input.Position.Y)
		local ghost: TextLabel? = nil
		local moved: RBXScriptConnection
		local ended: RBXScriptConnection
		local function pointer(other: InputObject): Vector2?
			if kind == Enum.UserInputType.Touch then
				return if other == input then Vector2.new(other.Position.X, other.Position.Y) else nil
			end
			if other.UserInputType == Enum.UserInputType.MouseMovement then
				return Vector2.new(other.Position.X, other.Position.Y)
			end
			return nil
		end
		moved = UserInputService.InputChanged:Connect(function(other: InputObject)
			local at = pointer(other)
			if not at then
				return
			end
			if not ghost and (at - start).Magnitude >= Threshold and (not enabled or enabled()) then
				local made = Instance.new("TextLabel")
				made.Size = UDim2.fromOffset(110, 34)
				made.AnchorPoint = Vector2.new(0.5, 0.5)
				made.BackgroundColor3 = Color3.fromRGB(32, 26, 44)
				made.BackgroundTransparency = 0.1
				made.TextColor3 = Color3.new(1, 1, 1)
				made.Font = Enum.Font.GothamBold
				made.TextScaled = true
				made.Text = label()
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = made
				made.Parent = ghostLayer()
				ghost = made
			end
			if ghost then
				ghost.Position = UDim2.fromOffset(at.X, at.Y)
			end
		end)
		ended = UserInputService.InputEnded:Connect(function(other: InputObject)
			local done = if kind == Enum.UserInputType.Touch
				then other == input
				else other.UserInputType == Enum.UserInputType.MouseButton1
			if not done then
				return
			end
			moved:Disconnect()
			ended:Disconnect()
			if ghost then
				ghost:Destroy()
				drop(Vector2.new(other.Position.X, other.Position.Y))
			else
				click()
			end
		end)
	end)
end

return Drag
