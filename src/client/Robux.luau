--!strict
-- Client side of Robux buying (server/Services/RobuxService): what a product costs and the
-- one call every Robux button makes. Prices come from ReplicatedStorage.RobuxPrices, which
-- only has the products and passes that are set up on the Creator Dashboard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToastController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("ToastController"))

local Robux = {}

Robux.Symbol = utf8.char(0xE002) -- Roblox's fonts draw this as the Robux icon
Robux.Color = Color3.fromRGB(0, 140, 90)

-- The Robux price of a product or pass key ("ItemTier2", "VIP"), or nil if it isn't set up.
function Robux.price(key: string): number?
	local folder = ReplicatedStorage:FindFirstChild("RobuxPrices")
	local price = if folder then folder:GetAttribute(key) else nil
	return if typeof(price) == "number" then price else nil
end

-- "R 49" with the Robux icon, or "soon" if it isn't set up yet.
function Robux.label(key: string): string
	local price = Robux.price(key)
	return if price then `{Robux.Symbol} {price}` else "Robux · soon"
end

local asking = false

-- Asks the server to buy `kind` (see RobuxService); Roblox's purchase prompt opens if it
-- agrees. Anything it says no to shows as a toast.
function Robux.buy(kind: string, arg: any?)
	if asking then
		return
	end
	local remotes = ReplicatedStorage:FindFirstChild("RobuxRemotes")
	local remote = remotes and remotes:FindFirstChild("Buy")
	if not remote or not remote:IsA("RemoteFunction") then
		return
	end
	asking = true
	local ok, result = pcall(remote.InvokeServer, remote, kind, arg)
	asking = false
	if ok and typeof(result) == "table" and not result.ok and typeof(result.message) == "string" then
		ToastController.show(result.message)
	end
end

-- Runs `callback(kind)` whenever a Robux purchase is paid out, so open windows can refresh.
function Robux.onGranted(callback: (string) -> ())
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("RobuxRemotes")
		local granted = remotes:WaitForChild("Granted") :: RemoteEvent
		granted.OnClientEvent:Connect(callback)
	end)
end

return Robux
