--!strict
-- Draws wandering monsters smoothly. The server only says "glide from A to B between these
-- two times" (attributes RoamFrom, RoamTo, RoamStart, RoamEnd on every model tagged
-- "Roamer", see server/Services/RoamService.luau); every frame this works out where each orb
-- should be right now and moves it locally, with a gentle floating bob. An orb that is being
-- caught (HeldBy is set) trembles instead.
-- Only the model's PrimaryPart ("Body") is moved: a real monster model that replaces the orb
-- later should weld its other parts to Body (and leave them unanchored) so they follow.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Roam = require(Shared:WaitForChild("Util"):WaitForChild("Roam"))

local RoamController = {}

local TAG = "Roamer"
local BOB_HEIGHT = 0.35 -- studs up and down
local BOB_SPEED = 2
local SHAKE = 0.12 -- studs of trembling while someone is catching it

local random = Random.new()
local phases: { [Model]: number } = {} -- each orb bobs a little out of step with the others

local function track(instance: Instance)
	if instance:IsA("Model") then
		phases[instance] = random:NextNumber(0, math.pi * 2)
	end
end

local function untrack(instance: Instance)
	if instance:IsA("Model") then
		phases[instance] = nil
	end
end

-- Where the orb's centre should be this frame, or nil if the leg hasn't arrived yet.
local function legPosition(model: Model, serverNow: number): Vector3?
	local from = model:GetAttribute("RoamFrom")
	local to = model:GetAttribute("RoamTo")
	local startTime = model:GetAttribute("RoamStart")
	local endTime = model:GetAttribute("RoamEnd")
	if
		typeof(from) ~= "Vector3"
		or typeof(to) ~= "Vector3"
		or typeof(startTime) ~= "number"
		or typeof(endTime) ~= "number"
	then
		return nil
	end
	return from:Lerp(to, Roam.alpha(startTime, endTime, serverNow))
end

function RoamController.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)

	-- Reused every frame so moving lots of orbs doesn't make garbage.
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}

	RunService.RenderStepped:Connect(function()
		local serverNow = workspace:GetServerTimeNow()
		local clock = os.clock()
		table.clear(parts)
		table.clear(cframes)

		for model, phase in phases do
			local body = model.PrimaryPart -- nil while it hasn't streamed in yet
			if not body or not model.Parent then
				continue
			end
			local position = legPosition(model, serverNow)
			if not position then
				continue
			end
			if model:GetAttribute("HeldBy") ~= nil then
				position += Vector3.new(
					random:NextNumber(-SHAKE, SHAKE),
					random:NextNumber(-SHAKE, SHAKE),
					random:NextNumber(-SHAKE, SHAKE)
				)
			else
				position += Vector3.new(0, math.sin(clock * BOB_SPEED + phase) * BOB_HEIGHT, 0)
			end
			table.insert(parts, body)
			table.insert(cframes, CFrame.new(position) * body.CFrame.Rotation)
		end

		if #parts > 0 then
			-- One call for every orb; FireCFrameChanged keeps the name labels following them.
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return RoamController
