--!strict
-- Monster info (price, name, details, familiarity) shows as a small card right next to the
-- mouse while you point at a monster. On phones and tablets (no mouse) it shows for the
-- monster you're looking at (the middle of the screen), just above it, or for a few seconds
-- for one you tapped.
-- The labels MonsterModel builds over each monster stay hidden; the card copies their text.
--
-- A monster is found by its press orb (Body) first. Big monsters (Titans) are drawn much
-- bigger than their orb, so pointing at their blocks also counts: the pointer ray is checked
-- against each monster's bounding box, unless a wall is closer.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local MonsterLabelController = {}

local TapSeconds = 4
local Reach = 400 -- studs

local function monsterOf(instance: Instance?): Model?
	local at = instance
	while at and at ~= workspace do
		if at:IsA("Model") and at:GetAttribute("MonsterId") ~= nil then
			return at
		end
		at = at.Parent
	end
	return nil
end

local function labelOf(model: Model): BillboardGui?
	local body = model.PrimaryPart
	local label = if body then body:FindFirstChild("Label") else nil
	return if label and label:IsA("BillboardGui") then label else nil
end

-- Distance along the ray to where it enters the box, or nil if it misses.
local function hitBox(origin: Vector3, direction: Vector3, frame: CFrame, size: Vector3): number?
	local o = frame:PointToObjectSpace(origin)
	local d = frame:VectorToObjectSpace(direction)
	local half = size / 2
	local near, far = -math.huge, math.huge
	for _, axis in { "X", "Y", "Z" } do
		local oa, da, h = (o :: any)[axis], (d :: any)[axis], (half :: any)[axis]
		if math.abs(da) < 1e-6 then
			if oa < -h or oa > h then
				return nil
			end
		else
			local t1, t2 = (-h - oa) / da, (h - oa) / da
			near = math.max(near, math.min(t1, t2))
			far = math.min(far, math.max(t1, t2))
			if near > far then
				return nil
			end
		end
	end
	return if far >= 0 then math.max(near, 0) else nil
end

function MonsterLabelController.start()
	local player = Players.LocalPlayer

	-- Every monster's own label stays hidden.
	local monsters: { [Model]: boolean } = {}
	local function track(instance: Instance)
		if instance:IsA("BillboardGui") and instance.Name == "Label" then
			local model = monsterOf(instance)
			if model then
				instance.Enabled = false
				monsters[model] = true
			end
		end
	end
	workspace.DescendantAdded:Connect(track)
	for _, instance in workspace:GetDescendants() do
		track(instance)
	end

	-- The card.
	local gui = Instance.new("ScreenGui")
	gui.Name = "MonsterInfoUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- placed in the same space as GetMouseLocation
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Visible = false
	card.AutomaticSize = Enum.AutomaticSize.XY
	card.Size = UDim2.fromOffset(0, 0)
	card.BackgroundColor3 = Ui.Colors.panel
	card.BackgroundTransparency = 0.08
	card.Parent = gui
	Ui.corner(card, 10)
	local rim = Ui.rim(card, Ui.Colors.rim, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = card
	local function line(order: number, font: Enum.Font, size: number): TextLabel
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.Size = UDim2.fromOffset(0, 0)
		label.Font = font
		label.TextSize = size
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Ui.Colors.text
		label.Parent = card
		return label
	end
	local price = line(1, Enum.Font.GothamBlack, 18)
	price.TextColor3 = Ui.Colors.lamp
	local name = line(2, Enum.Font.GothamBold, 18)
	local details = line(3, Enum.Font.GothamMedium, 14)
	local status = line(4, Enum.Font.GothamMedium, 14)

	local function textOf(label: BillboardGui, path: { string }): TextLabel?
		local at: Instance? = label
		for _, step in path do
			at = if at then at:FindFirstChild(step) else nil
		end
		return if at and at:IsA("TextLabel") then at else nil
	end

	local function fill(label: BillboardGui)
		local p = textOf(label, { "Value", "Price" })
		local n = textOf(label, { "Name" })
		local d = textOf(label, { "Details" })
		local s = textOf(label, { "Status" })
		price.Text = if p then p.Text else ""
		price.Visible = price.Text ~= ""
		name.Text = if n then n.Text else ""
		details.Text = if d then d.Text else ""
		details.TextColor3 = if d then d.TextColor3 else Ui.Colors.muted
		details.Visible = details.Text ~= ""
		status.Text = if s then s.Text else ""
		status.TextColor3 = if s then s.TextColor3 else Ui.Colors.muted
		status.Visible = status.Text ~= ""
		rim.Color = if d then d.TextColor3 else Ui.Colors.rim
	end

	-- The monster under a screen point (GetMouseLocation space).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local function monsterAt(at: Vector2): Model?
		local camera = workspace.CurrentCamera
		local ray = camera:ViewportPointToRay(at.X, at.Y)
		params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
		local hit = workspace:Raycast(ray.Origin, ray.Direction * Reach, params)
		local direct = monsterOf(if hit then hit.Instance else nil)
		if direct then
			return direct
		end
		local wall = if hit then hit.Distance else Reach
		local best: Model? = nil
		local bestDistance = wall
		for model in monsters do
			if model.Parent and model:IsDescendantOf(workspace) then
				local frame, size = model:GetBoundingBox()
				local distance = hitBox(ray.Origin, ray.Direction, frame, size)
				if distance and distance < bestDistance then
					best, bestDistance = model, distance
				end
			else
				monsters[model] = nil
			end
		end
		return best
	end

	local tapped: Model? = nil
	local tapAt = Vector2.zero
	local tappedUntil = 0
	UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processed: boolean)
		if processed then
			return
		end
		local inset = GuiService:GetGuiInset()
		tapAt = position + inset -- TouchTapInWorld is below the top bar; the card isn't
		tapped = monsterAt(tapAt)
		tappedUntil = os.clock() + TapSeconds
	end)

	local frameCount = 0
	local current: Model? = nil
	RunService.RenderStepped:Connect(function()
		local model: Model? = nil
		local at = Vector2.zero
		if tapped and os.clock() < tappedUntil and tapped.Parent then
			model, at = tapped, tapAt
		elseif UserInputService.MouseEnabled then
			at = UserInputService:GetMouseLocation()
			-- the bounding-box search is the costly part, so look again every other frame
			frameCount += 1
			if frameCount % 2 == 0 or (current and not current.Parent) then
				current = monsterAt(at)
			end
			model = current
		else
			-- what you're looking at: the middle of the screen
			local camera = workspace.CurrentCamera
			frameCount += 1
			if frameCount % 2 == 0 or (current and not current.Parent) then
				current = monsterAt(camera.ViewportSize / 2)
			end
			model = current
			if model then
				-- just above the monster, centred on it
				local frame, size = model:GetBoundingBox()
				local top, onScreen =
					camera:WorldToViewportPoint(frame.Position + Vector3.new(0, size.Y / 2, 0))
				if onScreen then
					at = Vector2.new(top.X - card.AbsoluteSize.X / 2 - 18, top.Y - card.AbsoluteSize.Y - 24)
				else
					model = nil
				end
			end
		end
		local label = if model then labelOf(model) else nil
		if label then
			fill(label)
			local view = workspace.CurrentCamera.ViewportSize
			local size = card.AbsoluteSize
			-- beside the pointer, kept on screen
			local x = math.clamp(at.X + 18, 4, math.max(4, view.X - size.X - 4))
			local y = math.clamp(at.Y + 18, 4, math.max(4, view.Y - size.Y - 4))
			card.Position = UDim2.fromOffset(x, y)
			card.Visible = true
		elseif card.Visible then
			card.Visible = false
		end
	end)
end

return MonsterLabelController
