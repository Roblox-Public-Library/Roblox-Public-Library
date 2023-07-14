local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage.Remotes

local ServerScriptService = game:GetService("ServerScriptService")
local ProfileLoader = require(ServerScriptService.Library.ProfileLoader)

local Players = game:GetService("Players")
local playerReadingBook = Instance.new("RemoteEvent")
--	Client -> Server : (id / nil if not reading, pageNum)
--	Server -> Client : (player, id / nil if not reading / false for private, pageNum)
--	Server will also pass ({[player] = id/false}, playerToPageNum, playerToViewDist) for initialization (this is the first thing sent)
playerReadingBook.Name = "PlayerReadingBook"
playerReadingBook.Parent = remotes

local playerPageNum = Instance.new("RemoteEvent")
--	Same idea as PlayerReadingBook
playerPageNum.Name = "PlayerBookPageNum"
playerPageNum.Parent = remotes

local RateLimiter = require(ServerScriptService.Utilities.RateLimiter)
local rateLimiter = RateLimiter.new(3, 3)

local Throttler = {}
Throttler.__index = Throttler
function Throttler.new(rateLimiter, player, onAllow)
	return setmetatable({
		rateLimiter = rateLimiter,
		player = player,
		onAllow = onAllow,
		queued = false,
	}, Throttler)
end
function Throttler:Trigger()
	local rateLimiter = self.rateLimiter
	local player = self.player
	if rateLimiter:TryUse(player) then
		self.onAllow(player)
	elseif not self.queued then
		self.queued = true
		-- Ideally we'd use a class that has an event so we don't have to check periodically
		task.delay(1, function()
			while rateLimiter:AtRateLimit(player) do
				task.wait(1)
			end
			self.onAllow(player)
			self.queued = false
		end)
	end
end

local playerToPrevId = {}
local playerToBookId = {}
local playerToPageNum = {}
local playerToViewDist = {}
local playerToThrottler = {}
Players.PlayerRemoving:Connect(function(player)
	playerToBookId[player] = nil
	playerToPageNum[player] = nil
	playerToPrevId[player] = nil
	playerToViewDist[player] = nil
	playerToThrottler[player] = nil
end)
local function getIdToReplicate(player)
	local profile = ProfileLoader.GetProfile(player)
	local public = profile and profile.BookViewingSettings.Public:Get()
	if public then
		return playerToBookId[player]
	elseif playerToBookId[player] then
		return false
	else
		return nil
	end
end
local function considerReplicatePlayerBook(player)
	local prev = playerToPrevId[player]
	local cur = getIdToReplicate(player)
	local pageNum = if cur then playerToPageNum[player] else nil
	-- if cur then either id and/or pageNum has changed
	-- if cur ~= prev, then transitioning to/from no book or private book
	if cur or cur ~= prev then
		playerToPrevId[player] = cur
		for _, p in Players:GetPlayers() do
			if p == player then continue end
			playerReadingBook:FireClient(p, player, cur, pageNum)
		end
	end
end
local defaultDist = require(ReplicatedStorage.Library.BookViewingSettings).DefaultData.ViewDistance / 10
Players.PlayerAdded:Connect(function(p)
	playerToViewDist[p] = defaultDist
	playerToThrottler[p] = Throttler.new(rateLimiter, p, considerReplicatePlayerBook)
	local data = {}
	local pageNum = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if p == player then continue end
		local value = getIdToReplicate(player)
		data[player] = value
		pageNum[player] = playerToPageNum[player]
	end
	playerReadingBook:FireClient(p, data, pageNum, playerToViewDist)
end)

playerReadingBook.OnServerEvent:Connect(function(player, id, pageNum)
	if playerToBookId[player] == id and playerToPageNum[player] == pageNum then return end
	playerToBookId[player] = id
	playerToPageNum[player] = pageNum
	playerToThrottler[player]:Trigger()
end)
ProfileLoader.ProfileLoaded:Connect(function(player, profile)
	local bvs = profile.BookViewingSettings
	bvs.Public.Changed:Connect(function(v)
		playerToThrottler[player]:Trigger()
	end)
end)

local pageTurnSound = Instance.new("RemoteEvent")
pageTurnSound.Name = "PageTurnSound"
pageTurnSound.Parent = remotes
pageTurnSound.OnServerEvent:Connect(function(player)
	for _, p in Players:GetPlayers() do
		if p ~= player then
			pageTurnSound:FireClient(p, player)
		end
	end
end)