--!strict
-- Movement anti-cheat (Giles 2026-11-03). A hunter's own computer moves their character, so a
-- hacked one can walk at any speed, teleport or fly. The server checks every hunter a few
-- times a second (rules in Util/Movement, numbers in Config/Movement):
--   speed / teleport  further sideways than they could have walked
--   super jump        higher above the floor they left than a jump goes
--   fly               staying up in the air without falling
-- Breaking a rule puts them back on the last spot they stood on (and Output says why).
-- Pulled back again and again (Config.KickStrikes within StrikeWindow seconds): kicked.
--
-- Everything the game moves on purpose calls MovementService.excuse first, so it never counts:
-- PlotService.teleport (portals, Return Charm, fast travel, spawning), FallService (rescue
-- after falling off), SlapService and MonsterAiService (knockbacks).
--
-- Studio only: ReplicatedStorage.TestRemotes.PauseMovement (client -> server, on: boolean)
-- pauses the checks for that player for up to PauseSeconds, so the client cheat tests
-- (Tests/ExploitChecks) can jump between the shops; false starts checking again and forgets
-- their pull-backs. It doesn't exist in a live game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Movement)
local Movement = require(ReplicatedStorage.Shared.Util.Movement)
local TravelConfig = require(ReplicatedStorage.Shared.Config.Travel)
local Perks = require(script.Parent.Parent.Perks)
local Perf = require(script.Parent.Parent.Perf)

local MovementService = {}

local PauseSeconds = 120
local StrikeGap = 1 -- seconds: pulls closer together than this count as one strike (a bounce)

type Watch = {
	character: Model,
	state: Movement.State?,
	strikes: { number },
	lastStrike: number,
	excusedUntil: number,
	pausedUntil: number,
}

local watched: { [Player]: Watch } = {}

local function watchOf(player: Player): Watch?
	local character = player.Character
	if not character then
		return nil
	end
	local watch = watched[player]
	if not watch then
		watch = {
			character = character,
			state = nil,
			strikes = {},
			lastStrike = -math.huge,
			excusedUntil = 0,
			pausedUntil = 0,
		}
		watched[player] = watch
	elseif watch.character ~= character then
		-- A new body: start again where it is (it's excused while it spawns anyway).
		watch.character = character
		watch.state = nil
	end
	return watch
end

-- The game is about to move this player (or push them) on purpose: look away for `seconds`.
function MovementService.excuse(player: Player, seconds: number)
	local watch = watched[player]
	local untilTime = os.clock() + seconds
	if watch then
		watch.excusedUntil = math.max(watch.excusedUntil, untilTime)
		watch.state = nil
	else
		watched[player] = {
			character = player.Character :: Model,
			state = nil,
			strikes = {},
			lastStrike = -math.huge,
			excusedUntil = untilTime,
			pausedUntil = 0,
		}
	end
end

-- How high this humanoid can jump, in studs.
local function jumpHeight(humanoid: Humanoid): number
	if humanoid.UseJumpPower then
		return humanoid.JumpPower ^ 2 / (2 * workspace.Gravity)
	end
	return humanoid.JumpHeight
end

local function limitsFor(player: Player, humanoid: Humanoid): Movement.Limits
	return {
		maxSpeed = Movement.maxSpeed(
			humanoid.WalkSpeed,
			TravelConfig.HubWalkSpeed,
			Perks.walkMultiplier(player)
		),
		jumpHeight = jumpHeight(humanoid),
	}
end

-- Standing on (or just above) something solid: a ball dropped from the middle of the body
-- hits something within GroundReach studs below the feet. Water counts too.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
params.IgnoreWater = false

local function grounded(character: Model, root: BasePart, humanoid: Humanoid): boolean
	params.FilterDescendantsInstances = { character }
	local down = humanoid.HipHeight + root.Size.Y / 2 + Config.GroundReach
	return workspace:Spherecast(root.Position, 1.5, Vector3.new(0, -down, 0), params) ~= nil
end

local function pullBack(player: Player, watch: Watch, root: BasePart, why: string, limits: Movement.Limits)
	local state = watch.state :: Movement.State
	local character = watch.character
	character:PivotTo(CFrame.new(state.safeX, state.safeY, state.safeZ) * root.CFrame.Rotation)
	root.AssemblyLinearVelocity = Vector3.zero
	Movement.pulledBack(state, limits)

	local now = os.clock()
	if now - watch.lastStrike < StrikeGap then
		return
	end
	watch.lastStrike = now
	local count, kick = Movement.strike(watch.strikes, now)
	player:SetAttribute("MoveStrikes", count)
	warn(`MovementService: pulled {player.Name} back ({why}), {count} in the last {Config.StrikeWindow} s`)
	if kick then
		warn(`MovementService: kicked {player.Name} ({count} pull-backs in {Config.StrikeWindow} s)`)
		player:Kick(Config.KickMessage)
	end
end

local function check(player: Player, dt: number)
	local watch = watchOf(player)
	if not watch then
		return
	end
	local character = watch.character
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 or root.Anchored then
		watch.state = nil
		return
	end
	local now = os.clock()
	local position = root.Position
	local limits = limitsFor(player, humanoid)
	if now < watch.excusedUntil or now < watch.pausedUntil or not watch.state then
		-- Excused (or just started): wherever they are now is fine.
		watch.state = Movement.new(position.X, position.Y, position.Z, limits)
		return
	end
	local state = watch.state :: Movement.State
	local why = Movement.step(
		state,
		position.X,
		position.Y,
		position.Z,
		dt,
		grounded(character, root, humanoid),
		limits
	)
	if why then
		pullBack(player, watch, root, why, limits)
	end
end

local function makeTestRemote()
	local folder = Instance.new("Folder")
	folder.Name = "TestRemotes"
	local pause = Instance.new("RemoteEvent")
	pause.Name = "PauseMovement"
	pause.Parent = folder
	pause.OnServerEvent:Connect(function(player, on)
		if typeof(on) ~= "boolean" then
			return
		end
		local watch = watchOf(player)
		if watch then
			watch.pausedUntil = if on then os.clock() + PauseSeconds else 0
			watch.state = nil
			if not on then
				-- Looking again: a fresh start, so test cheats don't add up to a kick.
				table.clear(watch.strikes)
				watch.lastStrike = -math.huge
				player:SetAttribute("MoveStrikes", nil)
			end
		end
	end)
	folder.Parent = ReplicatedStorage
end

function MovementService.start()
	if RunService:IsStudio() then
		makeTestRemote()
	end

	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited < Config.CheckSeconds then
			return
		end
		local elapsed = waited
		waited = 0
		for _, player in Players:GetPlayers() do
			Perf.run("MovementChecks", check, player, elapsed)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		watched[player] = nil
	end)
end

return MovementService
