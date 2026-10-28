--!strict
-- The loading screen (ReplicatedFirst/LoadingScreen) covers everything while a player joins.
-- Pop-ups that would open under it, like the "while you were away" book, wait for it here.

local Players = game:GetService("Players")

local Loading = {}

local MaxWait = 60 -- never wait longer than this, even if the loading screen broke

-- True once the loading screen has gone.
function Loading.isDone(): boolean
	return Players.LocalPlayer:GetAttribute("Loaded") == true
end

-- Yields until the loading screen has gone (returns at once if it already has).
function Loading.wait()
	local started = os.clock()
	while not Loading.isDone() and os.clock() - started < MaxWait do
		task.wait(0.2)
	end
end

return Loading
