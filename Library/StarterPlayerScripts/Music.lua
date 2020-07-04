--[[Music
Handles playing music and keeping the profile up-to-date with the user's musical preferences
]]
local Music = {}
local Marketplace = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local profile = require(script.Parent.Profile)

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
		if id <= 0 then return false, "That is not a valid sound id" end
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
		if data.AssetTypeId ~= Enum.AssetType.Audio then
			return false, "That is not a valid sound id"
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
local curPlaylist -- list of song IDs to play
local curTrackId, nextTrackId -- numeric form
local curTrack = Instance.new("Sound")
local nextTrack = Instance.new("Sound") -- what will be played once the current track is finished
-- Idea is that nextTrack loads while curTrack plays
curTrack.Parent = localPlayer
nextTrack.Parent = localPlayer
local curMusic = {} -- shuffled version of curPlaylist
local curMusicIndex = 1
local nextTrackStarted = Instance.new("BindableEvent")
Music.NextTrackStarted = nextTrackStarted.Event

local defaultVolume = .3
local function getMusicVolume()
	return (profile:GetMusicEnabled() and defaultVolume or 0)
end
local function musicVolumeChanged() -- todo if user changes music volume, ensure this is run
	curMusic.Volume = getMusicVolume()
end
local base = profile.SetMusicEnabled
function profile:SetMusicEnabled(value)
	if base(self, value) then return true end
	musicVolumeChanged()
end
function Music:GetEnabled() return profile:GetMusicEnabled() end
function Music:SetEnabled(value) return profile:SetMusicEnabled(value) end

function Music:GetCurSongDesc() -- todo use from gui?
	return getDesc(curMusic[curMusicIndex])
end

local function getNextSong(forceReshuffle) -- returns id, SoundId
	if forceReshuffle or not curMusic[curMusicIndex] then
		curMusic = shuffleAvoidFirst({unpack(curPlaylist)}, curTrackId)
		curMusicIndex = 1
	end
	local id = curMusic[curMusicIndex]
	local soundId = "rbxassetid://" .. id
	curMusicIndex = curMusicIndex + 1
	return id, soundId
end
local playlistModified
local function playNextSong()
	curTrack:Stop()
	if playlistModified then
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
local function setPlaylist(playlist)
	if #playlist == 0 then error("Playlist cannot be empty") end
	curPlaylist = playlist
	playNextSong()
end
local defaultPlaylist -- initialized below
local customPlaylist = profile:GetCustomPlaylist() -- treat as read-only; can be modified through profile:SetCustomPlaylistTrack
local function activePlaylistNameChanged(name)
	setPlaylist(name == "Default" and defaultPlaylist or customPlaylist)
end
local base = profile.SetActivePlaylistName
function profile:SetActivePlaylistName(value)
	if base(value) then return true end
	activePlaylistNameChanged(value)
end

function Music:Enable()
	profile:SetMusicEnabled(true)
end
function Music:Disable()
	profile:SetMusicEnabled(false)
end

local crazyMusic = ReplicatedStorage.DefaultMusic:GetChildren()
defaultPlaylist = {}
for i, s in ipairs(crazyMusic) do
	local id = tonumber(s.SoundId:match("%d+"))
	defaultPlaylist[i] = id
	addRef(id)
end
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
activePlaylistNameChanged(profile:GetActivePlaylistName())
function Music:GetActivePlaylistName() return profile:GetActivePlaylistName() end
function Music:SetActivePlaylistName(value) return profile:SetActivePlaylistName(value) end

for _, id in ipairs(customPlaylist) do
	addRef(id)
end
function Music:CustomPlaylistHasContent()
	return #customPlaylist > 0
end
local customNowExists = Instance.new("BindableEvent")
local customNowEmpty = Instance.new("BindableEvent")
Music.CustomPlaylistNowExists = customNowExists.Event
Music.CustomPlaylistNowEmpty = customNowEmpty.Event
function Music:TrySetCustomPlaylistTrack(index, id)
	assert(index >= 1 and index <= #customPlaylist + 1, "Index is out of range")
	local prev = customPlaylist[index]
	if prev == id then return true end
	local desc, problem = getDesc(id)
	if problem then
		return false, problem
	end
	if prev then
		removeRef(prev)
	end
	profile:SetCustomPlaylistTrack(index, id)
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

return Music