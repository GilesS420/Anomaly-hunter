--!strict
-- Global leaderboards in the hub (thread "Add fresh content to match the market", 2026-11-11):
-- "Richest Hunters" ranks worth (cash plus what every monster would sell for, like the daily
-- missions) and "Top Collectors" ranks Codex finds (every monster and colour caught once).
-- Both are across every server, kept in OrderedDataStores. Spots in Config/Layout.Leaderboards.
--
-- Each player's score is written when they join, every WriteSeconds and when they leave (only
-- if it changed); the top TopCount are read every ReadSeconds. Studio uses its own stores, so
-- test saves never show on the real boards. Without DataStore access (Studio with API access
-- off) the boards say so and the game carries on.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Leaderboard = require(ReplicatedStorage.Shared.Util.Leaderboard)
local DataService = require(script.Parent.DataService)
local MissionService = require(script.Parent.MissionService)
local World = require(script.Parent.Parent.World)

local LeaderboardService = {}

local TopCount = 10
local WriteSeconds = 120
local ReadSeconds = 90
local GroundTop = 0.1 -- the hub floor's top (WorldBuilder)

local Paper = Color3.fromRGB(28, 26, 36)
local Wood = Color3.fromRGB(70, 52, 40)
local Gold = Color3.fromRGB(255, 211, 107)
local Text = Color3.fromRGB(235, 235, 240)
local Muted = Color3.fromRGB(160, 155, 175)

type Board = {
	id: string,
	store: OrderedDataStore?,
	score: (DataService.Data) -> number,
	show: (number) -> string,
	rows: { { name: TextLabel, value: TextLabel } },
	status: TextLabel,
}

local boards: { Board } = {}
local written: { [Player]: { [string]: number } } = {}
local names: { [number]: string } = {}

local Scores: { [string]: { score: (DataService.Data) -> number, show: (number) -> string } } = {
	Worth = {
		score = function(data)
			return MissionService.worth(data)
		end,
		show = Format.money,
	},
	Finds = {
		score = function(data)
			return Leaderboard.finds(data.codex)
		end,
		show = function(value)
			return `{value} found`
		end,
	},
}

local function label(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Size = size
	item.Position = position
	item.Font = Enum.Font.FredokaOne
	item.Text = text
	item.TextColor3 = color
	item.TextScaled = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Parent = parent
	return item
end

-- The board itself: two posts and a flat dark board, its front facing +z (the landing spot).
local function build(parent: Instance, spot: { id: string, title: string, x: number, z: number }): Board
	local size = Layout.LeaderboardSize
	local model = Instance.new("Model")
	model.Name = spot.id
	local turn = CFrame.Angles(0, math.pi, 0) -- a part's Front is -z; turned, it faces +z
	local function block(name: string, partSize: Vector3, y: number, x: number, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = partSize
		part.CFrame = CFrame.new(spot.x + x, GroundTop + y, spot.z) * turn
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end
	for i, side in { -1, 1 } do
		block(
			`Post{i}`,
			Vector3.new(0.8, size.post + size.height, 0.8),
			(size.post + size.height) / 2,
			side * (size.width / 2 + 0.4), -- just outside the board, so they don't cover the names
			Wood
		)
	end
	local board =
		block("Board", Vector3.new(size.width, size.height, 0.6), size.post + size.height / 2, 0, Paper)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = board
	label(gui, spot.title, UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.03), Gold).TextXAlignment =
		Enum.TextXAlignment.Center
	local status = label(gui, "", UDim2.fromScale(0.9, 0.06), UDim2.fromScale(0.05, 0.16), Muted)
	status.TextXAlignment = Enum.TextXAlignment.Center
	local rows = {}
	local top, step = 0.24, 0.074
	for rank = 1, TopCount do
		local y = top + (rank - 1) * step
		local color = if rank <= 3 then Gold else Text
		label(gui, `{rank}`, UDim2.fromScale(0.08, step * 0.8), UDim2.fromScale(0.05, y), color)
		local name = label(gui, "", UDim2.fromScale(0.5, step * 0.8), UDim2.fromScale(0.14, y), Text)
		local value = label(gui, "", UDim2.fromScale(0.3, step * 0.8), UDim2.fromScale(0.65, y), color)
		value.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(rows, { name = name, value = value })
	end
	model.Parent = parent

	local store: OrderedDataStore? = nil
	local storeName = `Leaderboard{spot.id}_{if RunService:IsStudio() then "Studio" else "v1"}`
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName)
	end)
	if ok then
		store = result
	end
	local score = Scores[spot.id]
	return {
		id = spot.id,
		store = store,
		score = score.score,
		show = score.show,
		rows = rows,
		status = status,
	}
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and typeof(name) == "string" then
		names[userId] = name
		return name
	end
	return "Hunter"
end

local function read(board: Board)
	local store = board.store
	if not store then
		board.status.Text = "Offline"
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, TopCount):GetCurrentPage()
	end)
	if not ok or typeof(page) ~= "table" then
		board.status.Text = "Offline"
		return
	end
	board.status.Text = "All servers"
	for rank, row in board.rows do
		local entry = page[rank]
		local userId = entry and tonumber(entry.key)
		if userId and typeof(entry.value) == "number" then
			row.name.Text = nameOf(userId)
			row.value.Text = board.show(entry.value)
		else
			row.name.Text = ""
			row.value.Text = ""
		end
	end
end

local function write(player: Player)
	local data = DataService.get(player)
	if not data or data.tutorial ~= "Done" then
		return -- new players show up once they've finished the tutorial
	end
	local mine = written[player]
	if not mine then
		mine = {}
		written[player] = mine
	end
	for _, board in boards do
		local store = board.store
		local okScore, raw = pcall(board.score, data)
		local value = if okScore then Leaderboard.clean(raw) else 0
		if store and value > 0 and mine[board.id] ~= value then
			local ok, err = pcall(function()
				store:SetAsync(tostring(player.UserId), value)
			end)
			if ok then
				mine[board.id] = value
			else
				warn(`LeaderboardService: {board.id} {player.Name}: {err}`)
			end
		end
	end
end

function LeaderboardService.start()
	local hub = World.find(workspace, "Hub") or workspace
	local old = World.find(hub, "Leaderboards")
	if old then
		old:Destroy() -- built fresh every server start
	end
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = hub
	for _, spot in Layout.Leaderboards do
		if Scores[spot.id] then
			table.insert(boards, build(folder, spot))
		end
	end

	DataService.onLoaded(function(player)
		task.delay(10, write, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		write(player)
		written[player] = nil
	end)

	task.spawn(function()
		while true do
			for _, board in boards do
				read(board)
			end
			task.wait(ReadSeconds)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(WriteSeconds)
			for _, player in Players:GetPlayers() do
				write(player)
			end
		end
	end)
end

return LeaderboardService
