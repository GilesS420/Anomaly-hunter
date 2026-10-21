--!strict
-- Switches off the lights and particles in the mansions that are too far away to matter.
-- A full server has eight mansions with dozens of lamps each, plus a light on every monster
-- and cake and particles on monsters with effects: hundreds of lights in view at once, which
-- costs a lot of frames. Only the ones near the camera stay on; the rest come back on as you
-- walk up to them. Nothing the server does is changed, this only happens on your screen.
--
-- A few hundred of them are checked every frame, round and round, so the whole list is gone
-- through a few times a second without any frame doing all the work.

local RunService = game:GetService("RunService")

local DetailController = {}

local LampDistance = 170 -- the rooms' lamps: far enough that the next mansion stays lit
local GlowDistance = 90 -- the small glows on monsters and cakes
local ParticleDistance = 80
local PerFrame = 250

type Entry = { thing: Instance, range: number, on: boolean }

function DetailController.start()
	local entries: { Entry } = {}
	local indexOf: { [Instance]: number } = {}

	local function rangeOf(instance: Instance): number?
		if instance:IsA("ParticleEmitter") then
			return ParticleDistance
		elseif instance:IsA("Light") then
			-- Monsters and cakes are Models; the rooms' lamps sit straight in a wing folder.
			local part = instance.Parent
			local model = if part then part.Parent else nil
			return if model and model:IsA("Model") then GlowDistance else LampDistance
		end
		return nil
	end

	local function add(instance: Instance)
		local range = rangeOf(instance)
		if range and not indexOf[instance] then
			table.insert(entries, { thing = instance, range = range, on = true })
			indexOf[instance] = #entries
		end
	end

	local function remove(instance: Instance)
		local index = indexOf[instance]
		if not index then
			return
		end
		-- Swap with the last one so the list stays packed.
		local last = entries[#entries]
		entries[index] = last
		indexOf[last.thing] = index
		entries[#entries] = nil
		indexOf[instance] = nil
	end

	local mansions = workspace:WaitForChild("Mansions", math.huge) :: Instance
	mansions.DescendantAdded:Connect(add)
	mansions.DescendantRemoving:Connect(remove)
	for _, instance in mansions:GetDescendants() do
		add(instance)
	end

	local cursor = 0
	RunService.Heartbeat:Connect(function()
		local count = #entries
		if count == 0 then
			return
		end
		local eye = workspace.CurrentCamera.CFrame.Position
		for _ = 1, math.min(PerFrame, count) do
			cursor = cursor % count + 1
			local entry = entries[cursor]
			local part = entry.thing.Parent
			if part and part:IsA("BasePart") then
				local on = (part.Position - eye).Magnitude < entry.range
				if on ~= entry.on then
					entry.on = on
					local thing: any = entry.thing -- a Light or a ParticleEmitter
					thing.Enabled = on
				end
			end
		end
	end)
end

return DetailController
