--!strict
-- Keeps a monster hidden on your screen until all of its blocks have arrived. A big monster
-- (a Titan) is a hundred-odd blocks spread over a lot of space, and they can reach your
-- client one by one as you walk up to it or after it's rebuilt (a new effect, a growth spurt),
-- so you'd see bits of it pop in. The server tags every block with the look's version and
-- says how many there are (MonsterModel: Look, LookVersion, LookParts); until that many have
-- arrived the blocks stay see-through here. Nothing the server does is changed.

local LookLoadController = {}

local GiveUpSeconds = 3 -- show it anyway if some blocks never come (streamed out again)

type State = { hidden: boolean, since: number }

local function blocks(model: Model, version: any): ({ BasePart }, number)
	local all = {}
	local current = 0
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Look") ~= nil then
			table.insert(all, child)
			if child:GetAttribute("Look") == version then
				current += 1
			end
		end
	end
	return all, current
end

function LookLoadController.start()
	local states: { [Model]: State } = {}

	local function show(model: Model, visible: boolean)
		local all = blocks(model, nil)
		for _, part in all do
			part.LocalTransparencyModifier = if visible then 0 else 1
		end
	end

	local function check(model: Model)
		local state = states[model]
		if not state then
			return
		end
		local want = model:GetAttribute("LookParts")
		local _, have = blocks(model, model:GetAttribute("LookVersion"))
		local done = typeof(want) ~= "number" or have >= want
		if not done and not state.hidden then
			state.hidden = true
			state.since = os.clock()
			show(model, false)
			local hiddenSince = state.since
			task.delay(GiveUpSeconds, function()
				if states[model] == state and state.hidden and state.since == hiddenSince then
					state.hidden = false
					show(model, true)
				end
			end)
		elseif not done then
			show(model, false) -- a block that just came in stays hidden with the rest
		elseif state.hidden then
			state.hidden = false
			show(model, true)
		end
	end

	local function track(instance: Instance)
		if not instance:IsA("Model") or instance:GetAttribute("MonsterId") == nil then
			return
		end
		local model = instance :: Model
		if states[model] then
			return
		end
		states[model] = { hidden = false, since = 0 }
		model.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") then
				check(model)
			end
		end)
		model:GetAttributeChangedSignal("LookParts"):Connect(function()
			check(model)
		end)
		model:GetAttributeChangedSignal("LookVersion"):Connect(function()
			check(model)
		end)
		model.AncestryChanged:Connect(function(_, parent)
			if not parent then
				states[model] = nil
			end
		end)
		check(model)
	end

	workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("Model") then
			-- the MonsterId attribute comes with the model; defer so its first blocks are in too
			task.defer(track, instance)
		end
	end)
	for _, instance in workspace:GetDescendants() do
		track(instance)
	end
end

return LookLoadController
