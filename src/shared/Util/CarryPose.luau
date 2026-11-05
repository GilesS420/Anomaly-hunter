--!strict
-- The "monster over your head" pose, shared by the server (where the monster is welded) and
-- every client (which raises the arms, CarryController).
--
-- Both arms point straight up: each shoulder's rest pose is turned 180 degrees round the
-- torso's sideways axis, about the shoulder itself. Elbows and wrists are kept straight.
-- Everything is worked out from the rig's own joints, so it fits R6, R15, scaled avatars
-- and odd shoulder attachments alike, and the monster's bottom lands right on the hands.

local CarryPose = {}

-- Half a turn round the torso's sideways (X) axis: an arm hanging down points up.
local Up = CFrame.Angles(math.pi, 0, 0)
-- How far above the hands the monster's bottom sits (just a hair, so it doesn't flicker
-- into the hand blocks).
CarryPose.Gap = 0.05

local UpperArms = { RightUpperArm = true, LeftUpperArm = true, ["Right Arm"] = true, ["Left Arm"] = true }
local LowerArms = { RightLowerArm = true, LeftLowerArm = true, RightHand = true, LeftHand = true }

export type Joint = {
	joint: Instance, -- a Motor6D, or an AnimationConstraint (Roblox's newer avatar joints)
	part0: BasePart,
	part1: BasePart,
	c0: CFrame, -- where the joint sits on part0
	c1: CFrame, -- where the joint sits on part1
}

-- The joint's two halves, whichever kind of joint it is (nil when it isn't put together).
function CarryPose.read(joint: Instance): Joint?
	if joint:IsA("Motor6D") then
		local part0, part1 = joint.Part0, joint.Part1
		if part0 and part1 then
			return { joint = joint, part0 = part0, part1 = part1, c0 = joint.C0, c1 = joint.C1 }
		end
	elseif joint:IsA("AnimationConstraint") then
		local a0, a1 = joint.Attachment0, joint.Attachment1
		local part0 = if a0 then a0.Parent else nil
		local part1 = if a1 then a1.Parent else nil
		if a0 and a1 and part0 and part1 and part0:IsA("BasePart") and part1:IsA("BasePart") then
			return { joint = joint, part0 = part0, part1 = part1, c0 = a0.CFrame, c1 = a1.CFrame }
		end
	end
	return nil
end

-- The Transform that holds this arm joint in the pose (nil: not an arm joint).
function CarryPose.transform(j: Joint): CFrame?
	local name = j.part1.Name
	if UpperArms[name] then
		-- C0 * T = the shoulder frame turned by Up about the shoulder, in the torso's axes.
		return j.c0:Inverse() * CFrame.new(j.c0.Position) * Up * j.c0.Rotation
	elseif LowerArms[name] then
		return CFrame.identity -- straight elbow, straight wrist
	end
	return nil
end

-- Every joint of the character, read once.
function CarryPose.joints(character: Model): { Joint }
	local found = {}
	for _, child in character:GetDescendants() do
		if child:IsA("Motor6D") or child:IsA("AnimationConstraint") then
			local j = CarryPose.read(child)
			if j then
				table.insert(found, j)
			end
		end
	end
	return found
end

-- The highest point of a part (its box at that place), in the space the place is given in.
local function top(place: CFrame, size: Vector3): number
	local half = size / 2
	local best = -math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				best = math.max(best, (place * Vector3.new(half.X * x, half.Y * y, half.Z * z)).Y)
			end
		end
	end
	return best
end

-- Where the bottom middle of the carried monster goes, relative to the torso: on top of the
-- raised hands (or the head, if that's higher), centred over the head. Worked out from the
-- rest pose, not from wherever an animation has the limbs right now, so the server and every
-- client agree. Returns the torso to weld to and that spot, or nil if the rig isn't whole.
function CarryPose.seat(character: Model): (BasePart?, CFrame?)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local head = character:FindFirstChild("Head")
	if not torso or not torso:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return nil, nil
	end
	local joints = CarryPose.joints(character)
	-- The rest place of each part relative to the torso, following the joints out from it.
	-- `raised` is the same with the arms up.
	local rest: { [BasePart]: CFrame } = { [torso] = CFrame.identity }
	local raised: { [BasePart]: CFrame } = { [torso] = CFrame.identity }
	for _ = 1, 6 do -- a handful of passes reaches the hands from the torso
		for _, j in joints do
			local from = rest[j.part0]
			if from and not rest[j.part1] then
				local t = CarryPose.transform(j)
				rest[j.part1] = from * j.c0 * j.c1:Inverse()
				raised[j.part1] = raised[j.part0] * j.c0 * (t or CFrame.identity) * j.c1:Inverse()
			end
		end
	end
	local headRest = rest[head]
	if not headRest then
		return nil, nil
	end
	local height = top(headRest, head.Size)
	local hands = 0
	for part, place in raised do
		if UpperArms[part.Name] or LowerArms[part.Name] then
			height = math.max(height, top(place, part.Size))
			hands += 1
		end
	end
	if hands == 0 then
		return nil, nil
	end
	return torso, CFrame.new(headRest.Position.X, height + CarryPose.Gap, headRest.Position.Z)
end

-- The bottom middle of what you see of a monster, relative to its Body part, in Body's axes.
-- Only visible parts count, so an invisible press ball doesn't leave a gap under its feet.
function CarryPose.bottomOf(body: BasePart, parts: { BasePart }): CFrame
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	local any = false
	for _, part in parts do
		if part.Transparency < 1 then
			any = true
			local place = body.CFrame:ToObjectSpace(part.CFrame)
			local half = part.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local p = place * Vector3.new(half.X * x, half.Y * y, half.Z * z)
						lo = lo:Min(p)
						hi = hi:Max(p)
					end
				end
			end
		end
	end
	if not any then
		return CFrame.new(0, -body.Size.Y / 2, 0)
	end
	return CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
end

return CarryPose
