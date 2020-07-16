--[[Music
Handles playing music and keeping the server up-to-date with the user's musical preferences
]]
local Marketplace = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Music = require(ReplicatedStorage.Music)
local remotes = ReplicatedStorage.Remotes
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
for _, setName in ipairs({"SetEnabled", "SetActivePlaylist", "SetCustomPlaylistTrack", "RemoveCustomPlaylistTrack"}) do
	local base = music[setName]
	local remote = remotes[setName]
	local eventName = setToEventName[setName]
	if eventName then
		local event = Event()
		music[eventName] = event
		music[setName] = function(self, ...)
			if base(self, ...) then return true end -- no change
			remote:FireServer(...)
			event:Fire(...)
		end
	else
		music[setName] = function(self, ...)
			if base(self, ...) then return true end -- no change
			remote:FireServer(...)
		end
	end
end
music.CustomPlaylistsChanged = Event() -- fires when a custom playlist is created, removed, or renamed
local base = music.RenameCustomPlaylist
function music:RenameCustomPlaylist(id, newName) -- Do not call with unfiltered name (use InvokeRenameCustomPlaylist instead)
	if base(id, newName) then return true end
	self.CustomPlaylistsChanged:Fire()
end

function music:InvokeRenameCustomPlaylist(oldName, newName)
	--	returns true if rename was successful (yields)
	local success, tryAgain = remotes.RenameCustomPlaylist:InvokeServer(oldName, newName)
	if not success then
		StarterGui:SetCore("SendNotification", {
			Title = ("'%s' Rename Failed"):format(oldName),
			Text = tryAgain
				and "Roblox encountered a problem; try the name again later"
				or "That name was filtered",
			Duration = 4,
		})
		return false
	else
		music:RenameCustomPlaylist(oldName, newName)
		return true
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
local idToNumRefs = {}
local function addRef(id)
	idToNumRefs[id] = (idToNumRefs[id] or 0) + 1
end
local function removeRef(id)
	local num = idToNumRefs[id]
	if num == 1 then
		idToNumRefs[id] = nil
		idToDesc[id] = nil
	else
		idToNumRefs[id] = num - 1
	end
end

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
Music.NextTrackStarted = nextTrackStarted.Event

local defaultVolume = 0.3
local function getMusicVolume()
	return (music:GetEnabled() and defaultVolume or 0)
end
local function musicVolumeChanged()
	curTrack.Volume = getMusicVolume()
end
music.EnabledChanged:Connect(musicVolumeChanged)

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

for _, playlist in ipairs(music.ListOfDefaultPlaylists) do -- add refs to default playlists
	for _, songId in ipairs(playlist.Songs) do
		addRef(songId)
	end
end

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

function Music:GetPlaylist(name)
	return defaultPlaylists[name] or customPlaylists[name]
end
local sortedPlaylistNames
local function updateSortedPlaylistNames()
	sortedPlaylistNames = {}
	for name, list in pairs(customPlaylists) do
		sortedPlaylistNames[#sortedPlaylistNames + 1] = name
	end
	table.sort(sortedPlaylistNames)
end
updateSortedPlaylistNames()
music.CustomPlaylistsChanged:Connect(updateSortedPlaylistNames)
function Music:GetSortedCustomPlaylistNames()
	return sortedPlaylistNames
end

for name, playlist in pairs(customPlaylists) do
	for _, id in ipairs(playlist) do
		addRef(id)
	end
end
-- TODO rewrite below
function Music:CustomPlaylistHasContent()
	return #customPlaylist > 0
end
local customNowExists = Instance.new("BindableEvent")
local customNowEmpty = Instance.new("BindableEvent")
Music.CustomPlaylistNowExists = customNowExists.Event
Music.CustomPlaylistNowEmpty = customNowEmpty.Event
function Music:TrySetCustomPlaylistTrack(name, index, id)
	Assert.String(name)
	local customPlaylist = customPlaylists[name]
	if not customPlaylist then
		if not id then return true end
		customPlaylist = {}
		customPlaylists[name] = customPlaylist
	end
	Assert.Integer(index, 1, #customPlaylist + 1)
	local prev = customPlaylist[index]
	if prev == id then return true end
	local desc, problem = getDesc(id)
	if problem then
		return false, problem
	end
	if prev then
		removeRef(prev)
	end
	music:SetCustomPlaylistTrack(index, id)
	if id then
		addRef(id)
		if #customPlaylist == 1 then
			customNowExists:Fire()
		end
	elseif #customPlaylist == 0 then
		customNowEmpty:Fire()
	end
	if self:GetActivePlaylistName() == "Custom" then
		if #customPlaylist == 0 then
			self:SetActivePlaylistName("Default")
		else
			playlistModified = true
			if curTrackId == prev then
				playNextSong()
			end
		end
	end
	return true
end
function Music:RemoveCustomPlaylistTrack(name, index)
	Assert.String(name)
	Assert.Integer(index, 1, #customPlaylist)
end

return Music