local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assert = require(ReplicatedStorage.Utilities.Assert)
local Class = require(ReplicatedStorage.Utilities.Class)
--[[Playlist:
.Name
.Id (0 or negative for default ones, 1+ for custom)
.Songs:List<Song Id>
.]]
local Playlist = Class.New("Playlist")
function Playlist.new(name, id, songs)
	return setmetatable({
		Name = Assert.String(name),
		Id = Assert.Integer(id),
		Songs = Assert.List(songs),
	}, Playlist)
end
function Playlist:Serialize()
	assert(self.Id > 0, "Can only serialize custom playlists")
	return self
end
function Playlist.Deserialize(data)
	return setmetatable(data, Playlist)
end

local defaultPlaylists = {} -- id -> playlist
local listOfDefaultPlaylists = {} -- List<playlist>
local function addDefaultPlaylist(name, id, list)
	local playlist = Playlist.new(name, id, list)
	for _, id in ipairs(list) do
		Assert.Integer(id)
	end
	defaultPlaylists[id] = playlist
	listOfDefaultPlaylists[#listOfDefaultPlaylists + 1] = name
	return playlist
end

local defaultSongs = {}
for i, s in ipairs(ReplicatedStorage.DefaultMusic:GetChildren()) do
	local id = tonumber(s.SoundId:match("%d+"))
	defaultSongs[i] = id
end
local defaultPlaylist = addDefaultPlaylist("Default", 0, defaultSongs)

local Music = {
	MAX_PLAYLIST_NAME_LENGTH = 30,
	DefaultPlaylists = defaultPlaylists, -- id -> playlist
	ListOfDefaultPlaylists = listOfDefaultPlaylists,
}
Music.__index = Music
function Music.new()
	return setmetatable({
		enabled = true,
		activePlaylist = defaultPlaylist, -- Playlist
		customPlaylists = {}, -- id -> Playlist
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
	for _, playlist in ipairs(data.customPlaylists) do
		customPlaylists[playlist.Id] = playlist
	end
	data.customPlaylists = customPlaylists
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
function Music:SetActivePlaylist(id)
	if self.activePlaylistId == id then return true end -- no change
	self.activePlaylist = self.DefaultPlaylists[id] or self.customPlaylists[id] or error("No playlist exists with id: " .. tostring(id))
	self.activePlaylistId = id
end
function Music:GetCustomPlaylists() -- treat as read-only. Returned value will be modified by calling :SetCustomPlaylistTrack
	return self.customPlaylists
end
function Music:GetCustomPlaylist(id) -- treat as read-only. Returned value will be modified by calling :SetCustomPlaylistTrack
	return self.customPlaylists[id]
end
function Music:makeNewPlaylist(songs) -- todo maybe call this not SetCustomPlaylistTrack
	local idsInUse = {}
	for _, playlist in ipairs(self.customPlaylists) do
		idsInUse[playlist.Id] = true
	end
	local newId = 1
	while idsInUse[newId] do
		newId = newId + 1
	end
	local playlist = Playlist.new(newName, newId, songs or {})
	-- todo add to playlists
	return playlist
end
function Music:removeCustomPlaylist(playlist)
	self.customPlaylists[playlist.Id] = nil
	self.CustomPlaylistsChanged:Fire()
end
function Music:SetCustomPlaylistTrack(id, index, songId)
	--	Returns true if no change
	Assert.Integer(id)
	Assert.Integer(index)
	if songId then Assert.Integer(songId) end
	local playlist = self.customPlaylists[id]
	if not playlist then
		if not songId then return true end
		playlist = self:makeNewPlaylist({songId})
		self.CustomPlaylistsChanged:Fire()
	elseif playlist.Songs[index] == id then
		return true
	else
		assert(index >= 1 and index <= #playlist.Songs + 1, "Index is out of range")
		playlist.Songs[index] = id
		self.CustomPlaylistChanged:Fire(playlist)
		if (not songId) and #playlist == 0 then
			self:removeCustomPlaylist(playlist)
		end
	end
end
function Music:RemoveCustomPlaylistTrack(id, index)
	--	Returns true if nothing changed
	return self:SetCustomPlaylistTrack(id, index, nil)
end
function Music:RenameCustomPlaylist(id, newName)
	Assert.Integer(id)
	Assert.String(newName)
	local customPlaylist = self.customPlaylists[id]
	if not customPlaylist then error("No playlist exists with id " .. tostring(id)) end
	if customPlaylist.Name == newName then return true end
	customPlaylist.Name = newName
end