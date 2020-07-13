local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assert = require(ReplicatedStorage.Utilities.Assert)
local Music = {
	MAX_PLAYLIST_NAME_LENGTH = 30,
}
Music.__index = Music
local eventNames = { -- todo client side
	"ActivePlaylistChanged", --(id)
	"EnabledChanged", --(enabled)
	"CustomPlaylistsChanged", --() -- fires when a custom playlist is created, removed, or renamed
	"CustomPlaylistChanged", --(id, index, newValue)
}
function Music.new()
	return setmetatable({
		enabled = true,
		activePlaylist = 0, -- id
		customPlaylists = {}, -- name -> List<sound id>
	}, Music)
end
function Music:Serialize()
	return self
end
function Music.Deserialize(data)
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
function Music:GetActivePlaylistName()
	return self.activePlaylistName
end
function Music:SetActivePlaylistName(value)
	if self.activePlaylistName == value then return true end -- no change
	if not self.customPlaylists[value] then error("No playlist exists with the name: " .. tostring(value)) end
	self.activePlaylistName = value
	self.activePlaylistNameChanged:Fire(value)
end
function Music:GetCustomPlaylists() -- treat as read-only. Returned value will be modified by calling :SetCustomPlaylistTrack
	return self.customPlaylists
end
function Music:GetCustomPlaylist(name) -- treat as read-only. Returned value will be modified by calling :SetCustomPlaylistTrack
	return self.customPlaylists[name]
end
function Music:SetCustomPlaylistTrack(name, index, id)
	--	Returns true if no change
	Assert.String(name)
	Assert.Integer(index)
	if id then Assert.Integer(id) end
	local playlist = self.customPlaylists[name]
	local created
	if not playlist then
		if not id then return true end
		playlist = {}
		self.customPlaylists[name] = playlist
		created = true
	elseif playlist[index] == id then
		return true
	end
	assert(index >= 1 and index <= #playlist + 1, "Index is out of range")
	playlist[index] = id
	self.customPlaylistChanged:Fire(name, index, id)
	if created then
		self.customPlaylistsChanged:Fire()
	elseif (not id) and #playlist == 0 then
		self.customPlaylistsChanged:Fire()
		self.customPlaylists[name] = nil
	end
end
function Music:RemoveCustomPlaylistTrack(name, index)
	--	Returns true if nothing changed
	Assert.String(name)
	Assert.Integer(index)
	local playlist = self.customPlaylists[name]
	if not playlist or not playlist[index] then return true end
	table.remove(playlist, index)
end
function Music:RenameCustomPlaylist(oldName, newName)
	Assert.String(oldName)
	Assert.String(newName)
	local customPlaylists = self.customPlaylists
	assert(not customPlaylists[newName], "A playlist with that name already exists")
	customPlaylists[newName] = customPlaylists[oldName] or error("No playlist exists with that name")
	customPlaylists[oldName] = nil
end