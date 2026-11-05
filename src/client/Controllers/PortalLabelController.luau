--!strict
-- The names floating over portals (zone gates in the hub, the "Exit / Bring your catch home"
-- sign in each zone) are BillboardGuis sized in screen pixels, and they draw on top of
-- everything. On a phone 260 pixels is a third of the screen, so in a zone the exit sign sat
-- right over the HUD (Giles 2026-11-05). This shrinks them by the same factor as the HUD
-- (client/Scale), so they keep the size they have on a computer screen relative to the view.
-- WorldBuilder tags them "PortalLabel".

local CollectionService = game:GetService("CollectionService")

local Scale = require(script.Parent.Parent:WaitForChild("Scale"))

local PortalLabelController = {}

local Tag = "PortalLabel"
local base: { [BillboardGui]: UDim2 } = {}

local function fit(billboard: BillboardGui)
	local size = base[billboard]
	if not size then
		return
	end
	local factor = Scale.factor()
	billboard.Size = UDim2.new(size.X.Scale, size.X.Offset * factor, size.Y.Scale, size.Y.Offset * factor)
end

local function add(instance: Instance)
	if not instance:IsA("BillboardGui") or base[instance] then
		return
	end
	base[instance] = instance.Size
	fit(instance)
end

function PortalLabelController.start()
	CollectionService:GetInstanceAddedSignal(Tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tag):Connect(function(instance)
		if instance:IsA("BillboardGui") then
			base[instance] = nil
		end
	end)
	for _, instance in CollectionService:GetTagged(Tag) do
		add(instance)
	end
	Scale.changed:Connect(function()
		for billboard in base do
			fit(billboard)
		end
	end)
end

return PortalLabelController
