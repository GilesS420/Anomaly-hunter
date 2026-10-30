--!strict
-- Client side of Robux buying (server/Services/RobuxService): what a product costs and the
-- one call every Robux button makes. Roblox can charge less in some countries (regional
-- pricing), and the price on our buttons has to match the purchase prompt, so each player's
-- own game asks Roblox what *they* pay. Until that answer is in (or if Roblox can't be asked)
-- the server's price in ReplicatedStorage.RobuxPrices shows. Only products and passes that
-- are set up on the Creator Dashboard (id not 0) have a price.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Robux"))

local ToastController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("ToastController"))

local Robux = {}

Robux.Symbol = utf8.char(0xE002) -- Roblox's fonts draw this as the Robux icon
Robux.Color = Color3.fromRGB(0, 140, 90)

-- What this player pays, by product or pass key, as Roblox told this client.
local mine: { [string]: number } = {}

local function ask(key: string, id: number, infoType: Enum.InfoType)
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(id, infoType)
	end)
	if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
		mine[key] = info.PriceInRobux
	end
end

task.spawn(function()
	for key, product in Config.Products do
		if product.id ~= 0 then
			ask(key, product.id, Enum.InfoType.Product)
		end
	end
	for key, pass in Config.Passes do
		if pass.id ~= 0 then
			ask(key, pass.id, Enum.InfoType.GamePass)
		end
	end
end)

-- The Robux price of a product or pass key ("ItemTier2", "VIP"), or nil if it isn't set up.
function Robux.price(key: string): number?
	local folder = ReplicatedStorage:FindFirstChild("RobuxPrices")
	local price = if folder then folder:GetAttribute(key) else nil
	if typeof(price) ~= "number" then
		return nil -- not set up
	end
	return mine[key] or price
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
