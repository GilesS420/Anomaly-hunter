--!strict
-- Gets the menus ready while the loading screen is still up (Giles 2026-11-12: the Robux
-- Store and other menus took a while to open the first time). Downloads:
--   * the Robux Store's and the Missions window's pictures from the Creator Dashboard
--     (client/Robux asks Roblox for them and downloads them), and
--   * the meshes and textures of the preview models the menus draw their monsters, cakes and
--     tools from (PlayerGui.InventoryPreviews, see Ui.picture).
-- Then it sets the player attribute MenusReady (on this client only), which the loading
-- screen (ReplicatedFirst/LoadingScreen) waits for, never for long: a slow answer from Roblox
-- never keeps anyone out of the game.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")

local Robux = require(script.Parent.Parent:WaitForChild("Robux"))

local PreloadController = {}

local MaxWait = 12 -- seconds; after this the game opens anyway and the rest loads in the background

function PreloadController.start()
	local player = Players.LocalPlayer
	local started = os.clock()
	local function timeLeft(): number
		return math.max(0, MaxWait - (os.clock() - started))
	end

	-- The preview models: the server builds them once your save has loaded.
	local previews = player:WaitForChild("PlayerGui"):WaitForChild("InventoryPreviews", timeLeft())
	if previews then
		local done = false
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, { previews })
			done = true
		end)
		while not done and timeLeft() > 0 do
			task.wait(0.1)
		end
	end

	-- The dashboard pictures (client/Robux downloads them as soon as Roblox answers).
	while not Robux.isLoaded() and timeLeft() > 0 do
		task.wait(0.1)
	end

	player:SetAttribute("MenusReady", true)
end

return PreloadController
