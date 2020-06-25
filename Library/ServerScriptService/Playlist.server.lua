-- TODO Convert to profile, also containing preferences and other data
--	Perhaps design a more complex playlist editor, justifying moving everything to a Profiles data store
-- TODO Consider using UpdateAsync or calling GetAsync after 30 sec to see if data store changed (for if player was in another server that saved late, ex due to data stores being down)
-- TODO Use DataStores module

local DataStores = require(game.ServerScriptService.DataStores)
local DataStore = game:GetService("DataStoreService"):GetDataStore("Playlists")
local saveTimeMin = 60 -- can save once this many seconds (plus when the player leaves)
local maxPlaylistLength = 9
-- Data store config
local maxTries = 3
local timeBetweenTries = 5
local function GetAsync(key, shouldCancel)
	local success, msg
	for i = 1, maxTries do
		success, msg = pcall(DataStore.GetAsync, DataStore, key)
		if success then break end
		wait(timeBetweenTries)
		local cancel = shouldCancel()
		if cancel then return false, cancel end
	end
	return success, msg
end
local function SetAsync(key, getValue)
	local success, msg, value
	for i = 1, maxTries do
		value = getValue()
		success, msg = pcall(DataStore.SetAsync, DataStore, key, value)
		if success then return true, value end
		wait(timeBetweenTries)
	end
	return false, msg
end

local function tablesEqual(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

local playerProfile = {}
local function PlaylistProfile(player)
	local self = {}
	local key = "user_"..player.UserId
	local success, playlist = GetAsync(key, function() return not player.Parent end)
	if not player.Parent then return end -- player left
	if not success then
		playlist = false -- todo handle this on client
		return
	end
	playerProfile[player] = self
	function self:Get()
		return playlist
	end
	local nextSave = 0
	local playlistVersion = 0
	local saved = true
	local playerLeft
	local saving, waiting
	function self:Save()
		if saving or waiting then return end
		local timeLeft = nextSave - tick()
		if timeLeft > 0 then
			waiting = true
			wait(timeLeft)
			waiting = false
		end
		self:SaveNow()
	end
	function self:SaveNow()
		if saving then return end
		saving = true
		local success, value = SetAsync(key, self.Get)
		nextSave = tick() + saveTimeMin
		saving = false
		if success and value == playlist then
			saved = true
		elseif success then -- value changed while we were saving it
			if playerLeft then
				self:SaveNow()
			else
				self:Save()
			end
		end
	end
	function self:Set(value)
		if playlist and tablesEqual(playlist, value) then return end
		playlist = value
		playlistVersion = playlistVersion + 1
		saved = false
		assert(coroutine.resume(coroutine.create(self.Save), self))
	end
	function self:PlayerLeft()
		playerLeft = true
		playerProfile[self] = nil
		if saved then return end
		self:SaveNow()
	end
end

local getPlaylist = Instance.new("RemoteFunction")
getPlaylist.Name = "GetPlaylist"
getPlaylist.OnServerInvoke = function(player)
	while not playerProfile[player] do
		wait()
		if not player.Parent then return end
	end
	return playerProfile[player]:Get()
end
getPlaylist.Parent = game.ReplicatedStorage

local savePlaylist = Instance.new("RemoteEvent")
savePlaylist.Name = "SavePlaylist"
savePlaylist.OnServerEvent:Connect(function(player, playlist)
	if type(playlist) ~= "table" or (#playlist == 0 and next(playlist) ~= nil) then error("Must be a list") end
	if #playlist > maxPlaylistLength then error("List max length: " .. maxPlaylistLength) end
	for _, v in ipairs(playlist) do
		if type(v) ~= "number" then
			error("Must be list of numbers")
		end
	end
	local profile = playerProfile[player]
	profile:Set(playlist)
end)
game.Players.PlayerAdded:Connect(PlaylistProfile)
for _, player in ipairs(game.Players:GetPlayers()) do
	PlaylistProfile(player)
end
game.Players.PlayerRemoving:Connect(function(player)
	local profile = playerProfile[player]
	if profile then
		profile:PlayerLeft()
	end
end)