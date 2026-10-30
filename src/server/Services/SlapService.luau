--!strict
-- Slapping (Config/Slap, rules in Util/Slap): with a slapper from the Workshop in your hand,
-- click next to another hunter in a zone or in the open hub. Your best slapper sets
-- how far you reach, how hard you push and how long a slapped thief can't steal. They're
-- knocked back, and if they were catching a monster it breaks loose, dazed for a moment, so
-- whoever is quickest can catch it. A slapped
-- hunter is guarded for a few seconds so nobody can keep them pinned. Mansion plots and the
-- tutorial are safe, except for a thief on a Monster Heist (HeistService): slap them anywhere.
--
-- Remotes in ReplicatedStorage.SlapRemotes:
--   Slap     client -> server (target: Player)
--   Slapped  server -> all clients (slapper: Player, target: Player, pushX, pushZ, speed)
--            everyone sees the "SLAP!", the target's own client applies the push
-- Player attributes:
--   Slapper          the best slapper they own (set by HuntService.refreshItems); nil = none
--   SlapGuardUntil   server time: nobody can slap them until then
--   Stealing         true while they're on a Monster Heist (set by HeistService)
--   StealLockedUntil server time: a slap stopped their stealing, and they can't steal again
--                    until then (HeistService checks it)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlapConfig = require(ReplicatedStorage.Shared.Config.Slap)
local Slap = require(ReplicatedStorage.Shared.Util.Slap)
local CatchService = require(script.Parent.CatchService)
local HeistService = require(script.Parent.HeistService)
local Notify = require(script.Parent.Parent.Notify)

local SlapService = {}

local readyAt: { [Player]: number } = {}

local remotes = Instance.new("Folder")
remotes.Name = "SlapRemotes"
local SlapRemote = Instance.new("RemoteEvent")
SlapRemote.Name = "Slap"
SlapRemote.Parent = remotes
local Slapped = Instance.new("RemoteEvent")
Slapped.Name = "Slapped"
Slapped.Parent = remotes

-- The rules' view of a player, or nil without a character.
local function hunter(player: Player): (Slap.Hunter?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	local zone = player:GetAttribute("Zone")
	return {
		alive = humanoid.Health > 0,
		zone = if typeof(zone) == "string" then zone else nil,
		tutorial = player:GetAttribute("Tutorial") ~= nil,
		stealing = player:GetAttribute("Stealing") == true,
		x = root.Position.X,
		z = root.Position.Z,
	},
		root
end

local function onSlap(player: Player, target: unknown)
	if typeof(target) ~= "Instance" or not target:IsA("Player") then
		return
	end
	if target == player or target.Parent ~= Players then
		return
	end
	local tool = Slap.get(player:GetAttribute("Slapper") :: string?)
	if not tool then
		Notify.toast(player, "You need a slapper first! The Hunter's Workshop sells them.")
		return
	end
	-- Only with the slapper in your hand (Giles 2026-10-30): hold it from the hotbar first.
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if not held or held:GetAttribute("ToolId") ~= tool.id then
		return
	end
	local slapper = hunter(player)
	local victim = hunter(target)
	if not slapper or not victim then
		return
	end
	local now = workspace:GetServerTimeNow()
	local guard = target:GetAttribute("SlapGuardUntil")
	local reason = Slap.blocked(
		slapper,
		victim,
		now,
		readyAt[player] or 0,
		if typeof(guard) == "number" then guard else 0,
		tool.reach + SlapConfig.RangeSlack
	)
	if reason == "Guarded" then
		Notify.toast(player, `{target.DisplayName} was just slapped. Give them a second!`)
		return
	elseif reason then
		return -- the button only shows when a slap would land, so this is lag or a cheat
	end

	readyAt[player] = now + SlapConfig.CooldownSeconds - 0.25 -- a little lag allowance
	target:SetAttribute("SlapGuardUntil", now + SlapConfig.GuardSeconds)
	local pushX, pushZ = Slap.push(slapper.x, slapper.z, victim.x, victim.z)
	Slapped:FireAllClients(player, target, pushX, pushZ, tool.push)

	-- Caught stealing: they can't steal again for a while (longer for a better slapper).
	if target:GetAttribute("Stealing") == true then
		local locked = target:GetAttribute("StealLockedUntil")
		local untilTime = Slap.stealLockUntil(tool, now, if typeof(locked) == "number" then locked else nil)
		target:SetAttribute("StealLockedUntil", untilTime)
		local seconds = math.ceil(untilTime - now)
		CatchService.interrupt(target, `{player.DisplayName} slapped you!`)
		HeistService.slapped(target, player) -- whatever they stole flies back home
		Notify.toast(target, `{player.DisplayName} slapped you! You can't steal for {seconds} seconds.`)
		Notify.toast(player, `SLAP! {target.DisplayName} can't steal for {seconds} seconds.`)
		return
	end

	local monster = CatchService.catching(target)
	if monster then
		CatchService.interrupt(
			target,
			`{player.DisplayName} slapped you and your {monster} broke loose! Grab it!`
		)
		Notify.toast(player, `SLAP! {target.DisplayName}'s {monster} broke loose. Catch it first!`)
	else
		Notify.toast(target, `{player.DisplayName} slapped you!`)
	end
end

function SlapService.start()
	remotes.Parent = ReplicatedStorage
	SlapRemote.OnServerEvent:Connect(onSlap)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return SlapService
