--!strict
-- Makes the HUD and windows fit any screen. They are laid out in pixels for a computer screen,
-- so on a phone everything came out far too big. Scale.canvas puts a full-screen Canvas frame
-- with a UIScale in a ScreenGui: whatever goes inside is laid out on a screen 1/factor as big
-- and then shrunk by factor. Things placed by scale (the middle of the screen, half its width)
-- stay where they were; things sized in pixels get smaller on small screens. The factor comes
-- from the screen size and the "UI size" setting (Shared.Util.UiScale) and follows both when
-- they change (turning a tablet, resizing the window, picking another size).
--
-- Inside a canvas, AbsoluteSize and AbsolutePosition are still real screen pixels: divide by
-- Scale.factor() (or use Scale.toCanvas) before using them as offsets.

local GuiService = game:GetService("GuiService")

local Settings = require(script.Parent:WaitForChild("Settings"))
local UiScale = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("UiScale")
)

local Scale = {}

local factor = 1
local small = false
local canvases: { { frame: Frame, scale: UIScale } } = {}
local changed = Instance.new("BindableEvent")
-- Fires when the factor or the top bar changes, so hand-placed things can move.
Scale.changed = changed.Event

local function screenSize(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1920, 1080)
end

local function apply(canvas: { frame: Frame, scale: UIScale })
	canvas.frame.Size = UDim2.fromScale(1 / factor, 1 / factor)
	canvas.scale.Scale = factor
end

local function update()
	local size = screenSize()
	local new = UiScale.factor(size.X, size.Y, Settings.get("uiSize"))
	small = UiScale.isSmall(size.X, size.Y)
	if math.abs(new - factor) < 0.005 then
		return
	end
	factor = new
	for _, canvas in canvases do
		if canvas.frame.Parent then
			apply(canvas)
		end
	end
	changed:Fire()
end

-- The factor everything in a canvas is drawn at (1 on a computer, about 0.65 on a phone).
function Scale.factor(): number
	return factor
end

-- True on a phone-sized screen.
function Scale.isSmall(): boolean
	return small
end

-- A full-screen frame in gui that draws everything inside it at Scale.factor(). Put the
-- gui's pieces in this instead of in the gui itself.
function Scale.canvas(gui: ScreenGui): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Canvas"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromScale(0, 0)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local canvas = { frame = frame, scale = scale }
	apply(canvas)
	frame.Parent = gui
	table.insert(canvases, canvas)
	return frame
end

-- A point in screen pixels (AbsolutePosition, a tap) as an offset inside canvas.
function Scale.toCanvas(canvas: GuiObject, point: Vector2): Vector2
	return (point - canvas.AbsolutePosition) / factor
end

-- The strip along the top of the screen that Roblox's own buttons share (screen pixels):
-- free from Min.X to Max.X, from the very top down to Max.Y.
function Scale.topBar(): Rect
	return GuiService.TopbarInset
end

local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	update()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
Settings.changed(function(key)
	if key == "uiSize" then
		update()
	end
end)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
	changed:Fire()
end)

return Scale
