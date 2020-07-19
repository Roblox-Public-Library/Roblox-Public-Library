--[[Music
Handles playing music and keeping the server up-to-date with the user's musical preferences
]]
local Marketplace = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Music = require(ReplicatedStorage.Music)
local remotes = ReplicatedStorage.Remotes.Music
local Assert = require(ReplicatedStorage.Utilities.Assert)
local Event = require(ReplicatedStorage.Utilities.Event)
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local music = require(script.Parent.ProfileClient).Music

local Playlist = Music.Playlist

local defaultBaseFunc = function(setName) return music[setName] end
local setToBaseFunc = {
	RemoveCustomPlaylistTrack = function(setName)
		return function(self, playlist, index)
			playlist:RemoveSong(index)
		end
	end
}
local setToEventName = {
	SetEnabled = "EnabledChanged",
	SetActivePlaylist = "ActivePlaylistChanged",
}
local handleArgsDefault = function(...) return ... end
local setToHandleRemoteArgs = {
	SetActivePlaylist = function(playlist, index, songId)
		return playlist.Id, index, songId
	end,
	RemoveCustomPlaylistTrack = function(playlist, index)
		return playlist.Id, index
	end,
	RemoveCustomPlaylist = function(playlist)
		return playlist.Id
	end,
}
for _, setName in ipairs({"SetEnabled", "SetActivePlaylist", "RemoveCustomPlaylistTrack", "RemoveCustomPlaylist"}) do
	local base = (setToBaseFunc[setName] or defaultBaseFunc)(setName)
	local remote = remotes[setName]
	local eventName = setToEventName[setName]
	local argsHandler = setToHandleRemoteArgs[setName] or handleArgsDefault
	if eventName then
		local event = Event()
		music[eventName] = event
		music[setName] = function(self, ...)
			if base(self, ...) then return true end -- no change
			remote:FireServer(argsHandler(...))
			event:Fire(...)
		end
	else
		music[setName] = function(self, ...)
			if base(self, ...) then return true end -- no change
			remote:FireServer(argsHandler(...))
		end
	end
end
music.CustomPlaylistsChanged = Event() -- fires when a custom playlist is created, removed, or renamed

function music:InvokeCreateCustomPlaylist(data)
	--	Returns the new playlist if successful, otherwise notifies the user of the problem
	local success, data = remotes.CreateCustomPlaylist:InvokeServer(data)
	if success then
		return self:addNewPlaylist(Playlist.Deserialize(data))
	else
		StarterGui:SetCore("SendNotification", {
			Title = "Create New Playlist Failed",
			Text = data,
			Duration = 4,
		})
		return false
	end
end
function music:InvokeRenameCustomPlaylist(playlist, newName)
	--	Yields. Notifies the player if something goes wrong.
	local oldName = playlist.Name
	if newName == oldName then return end
	if self:GetCustomPlaylistByName(newName) then
		StarterGui:SetCore("SendNotification", {
			Title = ("'%s' Rename Failed"):format(oldName),
			Text = ("You already have a playlist named '%s'"):format(newName),
			Duration = 5,
		})
	end
	local success, tryAgain = remotes.RenameCustomPlaylist:InvokeServer(playlist.Id, newName)
	if not success then
		StarterGui:SetCore("SendNotification", {
			Title = ("'%s' Rename Failed"):format(oldName),
			Text = tryAgain
				and "Roblox encountered a problem; try the name again later"
				or "That name was filtered",
			Duration = 4,
		})
	else
		playlist:SetName(newName)
		self.CustomPlaylistsChanged:Fire()
	end
end
function music:InvokeSetCustomPlaylistTrack(playlist, index, songId)
	local problem = Music.AnyProblemWithSongId(songId)
		or remotes.SetCustomPlaylistTrack:InvokeServer(playlist.Id, index, songId)
	if problem then
		StarterGui:SetCore("SendNotification", {
			Title = "Song ID " .. songId,
			Text = problem,
			Duration = 4,
		})
	else
		playlist:SetSong(index, songId)
	end
end

local rnd = Random.new()
local function shuffleAvoidFirst(list, whatToAvoidInFirstSpot)
	--	shuffle the list but avoid putting as the first element 'whatToAvoidInFirstSpot'
	local n = #list
	if n == 1 then return list end
	local index
	for i = 1, 10 do -- Try up to 10x to avoid the 'whatToAvoidInFirstSpot' (could filter list to not include whatToAvoidInFirstSpot, but it's of small benefit)
		index = rnd:NextInteger(1, n)
		if list[index] ~= whatToAvoidInFirstSpot then break end
	end
	list[1], list[index] = list[index], list[1]
	for i = 2, n - 1 do
		index = rnd:NextInteger(i, n)
		list[i], list[index] = list[index], list[i]
	end
	return list
end

local idToDesc = {}
local function getDesc(id) -- id can be input from user (but is expected to be a number)
	--	returns desc OR false, reasonForUser
	local desc = idToDesc[id]
	if not desc then
		if id <= 0 then return false, "That is not a valid sound id (id must be positive)" end
		local success, data = pcall(function()
			return Marketplace:GetProductInfo(id)
		end)
		if not success then
			if data:find("HTTP 400") then
				return false, "That is not a valid sound id"
			else
				-- todo log this?
				return false, "Attempt to retrieve data failed: " .. data
			end
		end
		if data.AssetTypeId ~= Enum.AssetType.Audio.Value then
			return false, "That id does not point to a sound"
		end
		local name = data.Name
		if data.Creator.Name == "ROBLOX" and data.Description:find("Courtesy of APM Music") then
			return false, "APM Music not permitted"
		end
		desc = ("%s by %s"):format(name, data.Creator.Name)
		idToDesc[id] = desc
	end
	return desc
end
function Music:GetDescForId(id)
	return getDesc(id)
end

music.NoRefsLeft:Connect(function(id)
	idToDesc[id] = nil
end)

local localPlayer = game:GetService("Players").LocalPlayer
local curSongList -- list of song IDs to play
local curTrackId, nextTrackId -- numeric form
local curTrack = Instance.new("Sound")
local nextTrack = Instance.new("Sound") -- what will be played once the current track is finished
-- Idea is that nextTrack loads while curTrack plays
curTrack.Parent = localPlayer
nextTrack.Parent = localPlayer
local curMusic = {} -- shuffled version of curSongList
local curMusicIndex = 1
local nextTrackStarted = Instance.new("BindableEvent")
Music.NextTrackStarted = nextTrackStarted.Event -- todo if not when gui is done, delete

local defaultVolume = 0.3
local function getMusicVolume()
	return (music:GetEnabled() and defaultVolume or 0)
end
local function musicVolumeChanged()
	curTrack.Volume = getMusicVolume()
end
music.EnabledChanged:Connect(musicVolumeChanged)
music.EnabledChanged:Connect(function(enabled)
	if enabled then
		curTrack:Resume()
	else
		curTrack:Pause()
	end
end)

function Music:GetCurSongDesc()
	return getDesc(curMusic[curMusicIndex])
end
function Music:GetCurSongId() return curTrackId end
function Music:GetCurSong() return curTrack end

local function getNextSong(forceReshuffle) -- returns id, SoundId
	if forceReshuffle or not curMusic[curMusicIndex] then
		curMusic = shuffleAvoidFirst({unpack(curSongList)}, curTrackId)
		curMusicIndex = 1
	end
	local id = curMusic[curMusicIndex]
	local soundId = "rbxassetid://" .. id
	curMusicIndex = curMusicIndex + 1
	return id, soundId
end
local playlistModified
local function playNextSong(startingNewPlaylist)
	curTrack:Stop()
	if playlistModified or startingNewPlaylist then
		playlistModified = false
		nextTrackId, nextTrack.SoundId = getNextSong(true)
	end
	curTrack, nextTrack = nextTrack, curTrack
	curTrackId = nextTrackId
	curTrack.Volume = getMusicVolume()
	curTrack:Play()
	nextTrackId, nextTrack.SoundId = getNextSong()
	nextTrackStarted:Fire()
end
curTrack.Ended:Connect(playNextSong)
nextTrack.Ended:Connect(playNextSong)
local function setSongList(songList)
	if #songList == 0 then error("Song list cannot be empty") end
	curSongList = songList
	playNextSong(true)
end
local defaultPlaylist -- initialized below
local customPlaylists = music:GetCustomPlaylists() -- treat as read-only; can be modified through music:SetCustomPlaylistTrack
local defaultPlaylists = music.DefaultPlaylists -- id -> defaultPlaylist
local function activePlaylistChanged(playlist)
	setSongList(playlist.Songs)
end
activePlaylistChanged(music:GetActivePlaylist())
music.ActivePlaylistChanged:Connect(activePlaylistChanged)

local crazyMusic = ReplicatedStorage.DefaultMusic:GetChildren()
function Music:GoCrazy()
	curTrack:Pause()
	for _, s in ipairs(crazyMusic) do
		s.Volume = getMusicVolume()
		s:Play()
	end
	local con
	con = localPlayer.CharacterAdded:Connect(function()
		con:Disconnect()
		for _, s in ipairs(crazyMusic) do
			s:Stop()
		end
		wait(2)
		curTrack.Volume = 0
		curTrack:Play()
		TweenService:CreateTween(curTrack, TweenInfo.new(2, Enum.EasingStyle.Linear), {Volume = getMusicVolume()})
	end)
end

local sortedPlaylists
local playlistComparer = function(a, b) return a.Name < b.Name end
local function updateSortedPlaylists()
	sortedPlaylists = {}
	for name, playlist in pairs(customPlaylists) do
		sortedPlaylists[#sortedPlaylists + 1] = playlist
	end
	table.sort(sortedPlaylists, playlistComparer)
end
updateSortedPlaylists()
music.CustomPlaylistsChanged:Connect(updateSortedPlaylists)
function Music:GetSortedCustomPlaylists()
	return sortedPlaylists
end
function Music:GetSortedCustomPlaylistsWithContent()
	local t = {}
	for _, playlist in ipairs(sortedPlaylists) do
		if #playlist.Songs > 0 then
			t[#t + 1] = playlist
		end
	end
	return t
end
return music