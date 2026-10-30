--!strict
-- Stealing monsters (Sprint E, Giles 2026-10-30: "more like GAG"; rules in Util/Heists,
-- numbers in Config/Heists). Every monster roaming another player's mansion has a Steal
-- prompt (client/Controllers/StealController). Holding E on it asks RobuxRemotes.Buy("Steal",
-- { owner, uid }); the server checks the steal is allowed and opens the Robux prompt for the
-- monster's Steal product (by its value, a step more when hearted). Once paid
-- (RobuxService's ProcessReceipt) the monster moves straight into the thief's mansion (or
-- Storage), with its Familiarity back at 0 and its name tag and heart taken off. If it can't
-- be stolen any more by then (the owner left, sold it, or it was stolen first), the payment
-- becomes a credit: the next steal of the same price uses it instead of asking for Robux.
-- Nobody is robbed in the tutorial or their first 2 hours, more than twice a day, or twice a
-- day by the same thief (Util/Heists.blocked). Owners are always online: an offline player's
-- mansion isn't in the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Heists)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Heists = require(ReplicatedStorage.Shared.Util.Heists)
local Missions = require(ReplicatedStorage.Shared.Util.Missions)
local Robux = require(ReplicatedStorage.Shared.Util.Robux)
local Value = require(ReplicatedStorage.Shared.Util.Value)
local DataService = require(script.Parent.DataService)
local MansionService = require(script.Parent.MansionService)
local Notify = require(script.Parent.Parent.Notify)
local RoamService = require(script.Parent.RoamService)

local HeistService = {}

export type Result = { ok: boolean, message: string }
type Prompt = (Player, DataService.Data, string, any) -> Result

local PlaySeconds = 30 -- how often play time is counted
local ReachSlack = 6 -- studs of lag allowance on Config.Reach

-- A steal that may go ahead: the owner, the monster and the product it costs.
type Target = { owner: Player, caught: Value.CaughtMonster, key: string }

-- The monster `uid` roaming `ownerId`'s mansion, if `thief` may steal it. `near`: the thief
-- must be standing next to it (when asking; not when the payment comes in). Returns the target,
-- or nil and what to tell the thief.
local function check(thief: Player, ownerId: unknown, uid: unknown, near: boolean): (Target?, string?)
	local owner = if typeof(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
	if not owner or owner == thief or typeof(uid) ~= "string" then
		return nil, "That monster is gone."
	end
	local ownerData = DataService.get(owner)
	if not ownerData then
		return nil, "That monster is gone."
	end
	local caught = nil
	for _, monster in ownerData.monsters do
		if monster.uid == uid then
			caught = monster
		end
	end
	local model = MansionService.monsterModels(owner)[uid]
	if not caught or not model then
		return nil, "That monster is gone."
	end
	if near then
		local character = thief.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local position = RoamService.position(model) or model:GetPivot().Position
		if
			not root
			or not root:IsA("BasePart")
			or (root.Position - position).Magnitude > Config.Reach + ReachSlack
		then
			return nil, "Get closer to it!"
		end
	end
	Heists.rollDay(ownerData.heist, Missions.day(os.time()))
	local reason = Heists.blocked({
		tutorial = owner:GetAttribute("Tutorial") ~= nil,
		playSeconds = ownerData.heist.playSeconds,
		shield = Config.ShieldInStudio or not RunService:IsStudio(),
		record = ownerData.heist,
	}, {
		userId = thief.UserId,
		tutorial = thief:GetAttribute("Tutorial") ~= nil,
		hasRoom = MansionService.hasRoom(thief),
	})
	if reason then
		return nil, Heists.message(reason, owner.DisplayName)
	end
	local ok, value = pcall(Value.sellValue, caught, ownerData.wingsOwned)
	local key = Heists.productFor(if ok then value else 0, caught.locked == true)
	return { owner = owner, caught = caught, key = key }, nil
end

-- Moves the monster from the owner's save into the thief's. False (nothing changed) if it
-- didn't fit after all.
local function steal(thief: Player, target: Target): boolean
	local owner, caught = target.owner, target.caught
	local uid = caught.uid :: string
	local ownerData = DataService.get(owner)
	local thiefData = DataService.get(thief)
	if not ownerData or not thiefData or not MansionService.hasRoom(thief) then
		return false
	end
	MansionService.removeMonsters(owner, { [uid] = true })
	local name = Format.monsterName(caught) -- with its name tag, as the owner knew it
	Heists.handOver(caught, os.time())
	local where = MansionService.addMonster(thief, caught)
	if not where then
		MansionService.addMonster(owner, caught) -- room went in between: it stays home
		return false
	end
	Heists.noteLoss(ownerData.heist, thief.UserId)
	thiefData.heist.stolen += 1
	local place = if where == "Storage" then "your Storage" else "your mansion"
	Notify.toast(thief, `You stole {owner.DisplayName}'s {name}! It's in {place} now.`)
	Notify.toast(owner, `{thief.DisplayName} stole your {name}!`)
	task.spawn(DataService.saveNow, owner) -- the thief's save is written by the purchase
	return true
end

-- RobuxService: the thief held E on a monster. Steals it with a credit of the right price, or
-- opens the Robux prompt (through `prompt`, which notes what was asked for).
function HeistService.request(
	thief: Player,
	data: DataService.Data,
	ownerId: unknown,
	uid: unknown,
	prompt: Prompt
): Result
	local target, why = check(thief, ownerId, uid, true)
	if not target then
		return { ok = false, message = why or "You can't steal that right now." }
	end
	if Robux.takeCredit(data.robux, target.key) then
		if steal(thief, target) then
			DataService.saveSoon(thief)
			return { ok = true, message = "Used your steal credit!" }
		end
		Robux.addCredit(data.robux, target.key)
		return { ok = false, message = "Your mansion and Storage are full! Make room first." }
	end
	return prompt(thief, data, target.key, { owner = target.owner.UserId, uid = uid })
end

-- RobuxService: a Steal product was paid for. `pending` is what the thief asked for.
function HeistService.paid(thief: Player, data: DataService.Data, key: string, pending: any)
	local asked = if typeof(pending) == "table" then pending else {}
	local target = check(thief, asked.owner, asked.uid, false)
	if target and steal(thief, target) then
		return
	end
	Robux.addCredit(data.robux, key)
	Notify.toast(
		thief,
		"That monster couldn't be stolen any more, so your steal is saved: hold E on another monster of the same price to use it."
	)
end

function HeistService.start()
	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited >= PlaySeconds then
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					data.heist.playSeconds += waited
				end
			end
			waited = 0
		end
	end)
end

return HeistService
