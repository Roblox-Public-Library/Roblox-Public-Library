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

local setToEventName = {
	SetEnabled = "EnabledChanged",
	SetActivePlaylist = "ActivePlaylistChanged",
}
local handleArgsDefault = function(...) return ... end
local setToHandleRemoteArgs = {
	SetActivePlaylist = function(playlist)
		return playlist.Id
	end,
	RemoveCustomPlaylistTrack = function(playlist, index)
		return playlist.Id, index
	end,
}
for _, setName in ipairs({"SetEnabled", "SetActivePlaylist", "RemoveCustomPlaylistTrack"}) do
	local eventName = setToEventName[setName]
	if eventName then
		local event = Event()
		music[eventName] = event
		local base = music[setName]
		music[setName] = function(self, ...)
			if base(self, ...) then return true end -- no change
			event:Fire(...)
		end
	end
	local remote = remotes[setName]
	local argsHandler = setToHandleRemoteArgs[setName] or handleArgsDefault
	local base = music[setName]
	music["Invoke" .. setName] = function(self, ...)
		if base(self, ...) then return true end -- no change
		remote:FireServer(argsHandler(...))
	end
end
local curSongIndexChanged = Instance.new("BindableEvent")
music.CurSongIndexChanged = curSongIndexChanged.Event

local playlistCreated = Event()
local playlistRemoved = Event()
local playlistRenamed = Event()
music.PlaylistCreated = playlistCreated
music.PlaylistRemoved = playlistRemoved
music.PlaylistRenamed = playlistRenamed

local base = music.addNewPlaylist
function music:addNewPlaylist(...)
	local playlist = base(self, ...)
	playlistCreated:Fire(playlist)
	return playlist
end
local base = music.RemoveCustomPlaylist
function music:RemoveCustomPlaylist(playlist)
	base(self, playlist)
	playlistRemoved:Fire(playlist)
end

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
		playlistRenamed:Fire(playlist)
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
function music:InvokeRemoveCustomPlaylist(playlist)
	remotes.RemoveCustomPlaylist:FireServer(playlist.Id)
	self:RemoveCustomPlaylist(playlist)
end

local rnd = Random.new()
local function shuffleAvoidFirst(list, avoidAsFirstItem)
	--	shuffle the list but avoid putting as the first element whatever avoidAsFirstItem(item) returns true for
	local n = #list
	if n == 1 then return list end
	local index
	for i = 1, 10 do -- Try up to 10x to avoid whatever it is that should be avoided (could filter list to not include whatToAvoidInFirstSpot, but it's of small benefit)
		index = rnd:NextInteger(1, n)
		if not avoidAsFirstItem(list[index]) then break end
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
local curTrackIndex, nextTrackIndex -- index of song in current playlist
local curTrackId, nextTrackId -- numeric form
local curTrack = Instance.new("Sound")
local nextTrack = Instance.new("Sound") -- what will be played once the current track is finished
-- Idea is that nextTrack loads while curTrack plays
curTrack.Parent = localPlayer
nextTrack.Parent = localPlayer
local curMusic = {} -- shuffled list of *indices* to curSongList
local curMusicIndex = 0 -- essentially the next index into curMusic

local defaultVolume = 0.3
local function getMusicVolume()
	return (music:GetEnabled() and defaultVolume or 0)
end
local function musicVolumeChanged()
	curTrack.Volume = getMusicVolume()
end
music.EnabledChanged:Connect(function(enabled)
	musicVolumeChanged()
	if enabled then
		curTrack:Resume()
	else
		curTrack:Pause()
	end
end)

function Music:GetCurSongDesc()
	return getDesc(curTrackId)
end
function Music:GetCurSongIndex() return curTrackIndex end -- index in current playlist
function Music:GetCurSongId() return curTrackId end -- integer form
function Music:GetCurSong() return curTrack end -- returns the Sound instance

local function idToSoundId(id)
	return "rbxassetid://" .. id
end
local function getNextSong(forceReshuffle) -- returns index, id, SoundId
	curMusicIndex = curMusicIndex + 1
	if forceReshuffle or not curMusic[curMusicIndex] then
		curMusic = {}
		for i = 1, #curSongList do curMusic[i] = i end
		curMusic = shuffleAvoidFirst(curMusic, function(index)
			return curSongList[index] == curTrackId
		end)
		curMusicIndex = 1
	end
	local index = curMusic[curMusicIndex]
	local id = curSongList[index]
	return index, id, idToSoundId(id)
end
local function changeSong(modifyFunc)
	curTrack:Stop()
	modifyFunc()
	curTrack.Volume = getMusicVolume()
	curTrack:Play()
	curSongIndexChanged:Fire(curTrackIndex)
end
local function playNextSong(startingNewPlaylist)
	changeSong(function()
		if startingNewPlaylist then
			nextTrackIndex, nextTrackId, nextTrack.SoundId = getNextSong(true)
		end
		curTrack, nextTrack = nextTrack, curTrack
		curTrackId, curTrackIndex = nextTrackId, nextTrackIndex
		nextTrackIndex, nextTrackId, nextTrack.SoundId = getNextSong()
	end)
end
local function playPrevSong()
	local n = #curMusic
	if n == 1 then return end
	changeSong(function()
		-- curMusicIndex is more like nextMusicIndex
		-- So we -2 to get the index that cur should be
		-- Then we +1 later to so that playNextSong will work correctly
		curMusicIndex -= 2
		if curMusicIndex <= 0 then curMusicIndex += #curMusic end
		nextTrack, nextTrackId, nextTrackIndex = curTrack, curTrackId, curTrackIndex
		curTrackIndex = curMusic[curMusicIndex]
		curTrackId = curSongList[curTrackIndex]
		curTrack.SoundId = idToSoundId(curTrackId)
		curMusicIndex = curMusicIndex % n + 1
	end)
end
curTrack.Ended:Connect(playNextSong)
nextTrack.Ended:Connect(playNextSong)
function Music:PrevSong()
	playPrevSong()
end
function Music:NextSong()
	playNextSong()
end
function Music:TogglePause()
	if curTrack.Playing then
		curTrack:Pause()
	else
		curTrack:Resume()
	end
end
function Music:IsPaused()
	return not curTrack.Playing
end
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
function Music:GoCrazy(initialSilenceDuration)
	curTrack:Pause()
	wait(initialSilenceDuration)
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
playlistCreated:Connect(updateSortedPlaylists)
playlistRenamed:Connect(updateSortedPlaylists)
playlistRemoved:Connect(updateSortedPlaylists)
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