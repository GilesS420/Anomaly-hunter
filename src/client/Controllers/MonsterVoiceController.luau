--!strict
-- Monsters call out now and then: a giggle, a growl, a moan (Config/Sounds.MonsterVoices).
-- Every few seconds (Sounds.MonsterCalls) one monster near you, picked at random, makes its
-- call from where it stands, so you hear it in 3D and fade away with distance. Only one call
-- at a time and each monster waits a while before it calls again, so a full mansion stays
-- spooky instead of noisy. A bigger monster calls lower, and every call is a little higher
-- or lower than the last, so a family of monsters doesn't sound copied.
-- The calls play in SoundController's "Monsters" group, which follows the Sound effects
-- volume setting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sizes = require(ReplicatedStorage.Shared.Config.Sizes)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local MonsterVoiceController = {}

local Calls = Sounds.MonsterCalls

local random = Random.new()

local scaleOf: { [string]: number } = {}
for _, size in Sizes do
	scaleOf[size.id] = size.scale
end

local function callOf(model: Model): string
	local monsterId = model:GetAttribute("MonsterId")
	local call = if type(monsterId) == "string" then Sounds.MonsterVoices[monsterId] else nil
	if call then
		return call
	end
	local gait = model:GetAttribute("Gait")
	return Sounds.DefaultCall[if type(gait) == "string" then gait else "walk"] or Sounds.DefaultCall.walk
end

local function play(model: Model, body: BasePart, soundId: string, group: SoundGroup)
	local region = Sounds.Sheets.MonsterVoices[callOf(model)]
	if not region then
		return
	end
	local size = model:GetAttribute("Size")
	local scale = if type(size) == "string" then scaleOf[size] or 1 else 1
	local speed = scale ^ -Calls.pitchPerSize * (1 + random:NextNumber(-1, 1) * Calls.pitchSpread)

	local sound = Instance.new("Sound")
	sound.Name = "Call"
	sound.SoundId = soundId
	sound.SoundGroup = group
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = NumberRange.new(region.start, region.start + region.length)
	sound.TimePosition = region.start
	sound.PlaybackSpeed = speed
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = Calls.fullVolumeWithin
	sound.RollOffMaxDistance = Calls.reach
	sound.Parent = body
	sound:Play()
	task.delay(region.length / speed + 1, function()
		sound:Destroy()
	end)
end

function MonsterVoiceController.start()
	local soundId = Sounds.assetId(Sounds.Files.MonsterVoices)
	if soundId == "" then
		return -- not uploaded yet (SoundController says so in Studio's Output)
	end
	local group = SoundService:WaitForChild("Monsters") :: SoundGroup
	local player = Players.LocalPlayer

	-- Every monster in the world: wild ones in zones, roaming ones in mansions, event ones.
	local monsters: { [Model]: number } = {} -- when it last called
	local function track(instance: Instance)
		if instance:IsA("Model") and instance:GetAttribute("MonsterId") ~= nil then
			monsters[instance] = monsters[instance] or -math.huge
		end
	end
	workspace.DescendantAdded:Connect(track)
	for _, instance in workspace:GetDescendants() do
		track(instance)
	end

	while true do
		task.wait(random:NextNumber(Calls.gapMin, Calls.gapMax))
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if not root then
			continue
		end
		local now = os.clock()
		local near: { Model } = {}
		for model, last in monsters do
			if not model:IsDescendantOf(workspace) then
				monsters[model] = nil
			elseif now - last >= Calls.cooldown then
				local body = model.PrimaryPart
				if body and (body.Position - root.Position).Magnitude <= Calls.reach then
					table.insert(near, model)
				end
			end
		end
		if #near > 0 then
			local model = near[random:NextInteger(1, #near)]
			monsters[model] = now
			play(model, model.PrimaryPart :: BasePart, soundId, group)
		end
	end
end

return MonsterVoiceController
