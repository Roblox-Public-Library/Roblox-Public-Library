local Marketplace = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assert = require(ReplicatedStorage.Utilities.Assert)
local Class = require(ReplicatedStorage.Utilities.Class)
local AddEventsToSerializable = require(ReplicatedStorage.Utilities.AddEventsToSerializable)
--[[Playlist:
.Name
.Id (0 or negative for default ones, 1+ for custom)
.Songs:List<Song Id>
.]]
local function anyProblemWithSongId(id)
	--	Returns a string representing the problem with 'id', or nil if it's a valid id
	id = tonumber(id)
	if not id or not Assert.Check.Integer(id, 1) then return "That is not a valid song id" end
	local success, data = pcall(function()
		return Marketplace:GetProductInfo(id)
	end)
	if not success then
		if data:find("HTTP 400") then
			return "That is not a valid sound id"
		else
			return "Attempt to retrieve data failed: " .. data
		end
	end
	if data.AssetTypeId ~= Enum.AssetType.Audio.Value then
		return "That id does not point to a sound"
	end
	if data.Creator.Name == "ROBLOX" and data.Description:find("Courtesy of APM Music") then
		return "APM Music not permitted"
	end
	return nil
end

local noRefsLeft = Instance.new("BindableEvent")
local idToNumRefs = {}
local function addRef(id)
	idToNumRefs[id] = (idToNumRefs[id] or 0) + 1
end
local function removeRef(id)
	local num = idToNumRefs[id]
	if num == 1 then
		idToNumRefs[id] = nil
		noRefsLeft:Fire(id)
	else
		idToNumRefs[id] = num - 1
	end
end

local Playlist = Class.New("Playlist")
function Playlist.new(id, name, songs)
	for _, songId in ipairs(Assert.List(songs)) do
		addRef(songId)
	end
	return setmetatable({
		Id = Assert.Integer(id),
		Name = Assert.String(name),
		Songs = songs,
	}, Playlist)
end
function Playlist:SetName(name)
	--	Returns true if nothing changed
	Assert.String(name)
	if self.Name == name then return true end
	self.Name = name
	self.nameChanged:Fire(name)
end
function Playlist:SetSong(index, id)
	--	Returns true if nothing changed
	Assert.Integer(index, 1, #self.Songs + 1)
	Assert.Integer(id)
	if self.Songs[index] == id then return true end
	local prev = self.Songs[index]
	if prev then removeRef(prev) end
	self.Songs[index] = id
	addRef(id)
	self.songsChanged:Fire()
end
function Playlist:RemoveSong(index)
	Assert.Integer(index, 1, #self.Songs)
	removeRef(table.remove(self.Songs, index))
	self.songsChanged:Fire()
end
function Playlist:Serialize()
	assert(self.Id > 0, "Can only serialize custom playlists")
	return {Id = self.Id, Name = self.Name, Songs = self.Songs}
end
function Playlist.Deserialize(data)
	return setmetatable({
		Id = data.Id,
		Name = data.Name,
		Songs = data.Songs,
	}, Playlist)
end
AddEventsToSerializable.Bindable(Playlist, {"NameChanged", "SongsChanged"})

local defaultPlaylists = {} -- id -> playlist
local listOfDefaultPlaylists = {} -- List<playlist>
local function addDefaultPlaylist(id, name, list)
	local playlist = Playlist.new(id, name, list)
	for _, id in ipairs(list) do
		Assert.Integer(id)
	end
	defaultPlaylists[id] = playlist
	listOfDefaultPlaylists[#listOfDefaultPlaylists + 1] = playlist
	return playlist
end

local defaultSongs = {}
for i, s in ipairs(ReplicatedStorage.DefaultMusic:GetChildren()) do
	local id = tonumber(s.SoundId:match("%d+"))
	defaultSongs[i] = id
end
local defaultPlaylist = addDefaultPlaylist(0, "Default", defaultSongs)

local Music = {
	MAX_PLAYLIST_NAME_LENGTH = 30,
	MAX_PLAYLISTS = 20,
	MAX_SONGS_PER_PLAYLIST = 100,
	-- Note: encoding a playlist in JSON takes ~70 chars + #chars for each id
	-- 	100 songs in a playlist, if each id is 9 chars long, would be 970 chars
	--	Total max size: ~20k (out of 260k limit)
	--	This allows the profile to have space for everything else
	-- Size estimate per playlist with JSON Encoding
	-- {"Id"= = self.Id, Name = self.Name, Songs = self.Songs}
	DefaultPlaylists = defaultPlaylists, -- id -> playlist
	ListOfDefaultPlaylists = listOfDefaultPlaylists,
	AnyProblemWithSongId = anyProblemWithSongId,
	NoRefsLeft = noRefsLeft.Event, --(songId) -- triggered when a song is removed from all playlists
	-- AddSongIdRef = addRef, -- should be used to temporarily add a song id (ex when caching info before you know if you'll keep it)
	-- RemoveSongIdRef = removeRef, -- todo are these 2 needed?
	Playlist = Playlist
}
Music.__index = Music
function Music.new()
	return setmetatable({
		enabled = true,
		activePlaylist = defaultPlaylist or error("defaultPlaylist nil"), -- Playlist
		customPlaylists = {}, -- id -> Playlist
		nameToPlaylist = {},
	}, Music)
end
function Music:Serialize()
	local customList = {}
	for id, playlist in pairs(self.customPlaylists) do
		customList[#customList + 1] = playlist:Serialize()
	end
	return {
		enabled = self.enabled,
		activePlaylistId = self.activePlaylist and self.activePlaylist.Id or 0,
		customPlaylists = customList,
	}
end
function Music.Deserialize(data)
	local customPlaylists = {}
	local nameToPlaylist = {}
	for _, playlist in ipairs(data.customPlaylists) do
		customPlaylists[playlist.Id] = playlist
		nameToPlaylist[playlist.Name] = playlist
	end
	data.activePlaylist = defaultPlaylists[data.activePlaylistId] or customPlaylists[data.activePlaylistId] or defaultPlaylists[next(defaultPlaylists)]
	data.activePlaylistId = nil
	data.customPlaylists = customPlaylists
	data.nameToPlaylist = nameToPlaylist
	return setmetatable(data, Music)
end
function Music:GetEnabled()
	return self.enabled
end
function Music:SetEnabled(value)
	value = not not value
	if self.enabled == value then return true end -- no change
	self.enabled = value
end
function Music:GetActivePlaylist()
	return self.activePlaylist
end
function Music:SetActivePlaylist(playlist)
	if self.activePlaylist == playlist then return true end -- no change
	self.activePlaylist = playlist or error("playlist nil")
end
function Music:GetPlaylist(id)
	return self.DefaultPlaylists[id] or self.customPlaylists[id]
end
function Music:GetCustomPlaylists() -- treat as read-only. Returned value will be modified by creating/modifying/removing playlists
	return self.customPlaylists
end
function Music:GetCustomPlaylist(id) -- treat as read-only. Returned value will be modified by calling :SetCustomPlaylistTrack
	return self.customPlaylists[id]
end
function Music:GetCustomPlaylistByName(name)
	return self.nameToPlaylist[name]
end
function Music:newPlaylistId()
	local idsInUse = {}
	for _, playlist in ipairs(self.customPlaylists) do
		idsInUse[playlist.Id] = true
	end
	local newId = 1
	while idsInUse[newId] do
		newId = newId + 1
	end
	return newId
end
local customNameFormat = "Custom #%d"
function Music:getNewPlaylistName()
	local i = 1
	while true do
		local name = customNameFormat:format(i)
		if not self:GetCustomPlaylistByName(name) then
			return name
		end
		i = i + 1
	end
end
function Music:addNewPlaylist(playlist)
	self.customPlaylists[playlist.Id] = playlist
	self.nameToPlaylist[playlist.Name] = playlist
	self.CustomPlaylistsChanged:Fire()
	return playlist
end
function Music:CreateNewPlaylist(name, songs)
	--	name:string = default
	--	songs:List<song id> = {}
	--	returns successful, playlist/problem
	local num = 0
	for k, v in pairs(self.customPlaylists) do
		num = num + 1
	end
	if num >= self.MAX_PLAYLISTS then
		return false, "You are at the playlist limit"
	end
	return true, self:addNewPlaylist(Playlist.new(self:newPlaylistId(), name or self:getNewPlaylistName(), songs or {}))
end
function Music:RemoveCustomPlaylist(playlist)
	self.customPlaylists[playlist.Id] = nil
	self.nameToPlaylist[playlist.Name] = nil
	self.CustomPlaylistsChanged:Fire()
end
AddEventsToSerializable.Event(Music, {"CustomPlaylistsChanged"})
return Music