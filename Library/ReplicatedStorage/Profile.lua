local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local Functions = require(Utilities.Functions)

local Profile = {
	MAX_PLAYLIST_NAME_LENGTH = 30,
}
Profile.__index = Profile
function Profile.new()
    return setmetatable({
		musicEnabled = true,
		activePlaylistName = "Default",
		customPlaylists = {}, -- name -> List<sound id>
		-- favoriteBooks = SaveableSet.new(),
		-- readBooks = SaveableSet.new(),
    }, Profile):init()
end
local eventNames = {
	"ActivePlaylistNameChanged", --(name)
	"MusicEnabledChanged", --(enabled)
	"CustomPlaylistsChanged", --() -- fires when a custom playlist is created, removed, or renamed
	"CustomPlaylistChanged", --(name, index, newValue)
}
local getLowerName = Functions.Cache(function(name)
	return name:sub(1, 1):lower() .. name:sub(2)
end)
for _, name in ipairs(eventNames) do
	eventNames[name] = true
	eventNames[getLowerName(name)] = true
end
function Profile:init()
	for _, name in ipairs(eventNames) do
		local lowerName = getLowerName(name)
		local event = Instance.new("BindableEvent")
		self[lowerName] = event
		self[name] = event.Event
	end
	return self
end
function Profile:GetMusicEnabled()
	return self.musicEnabled
end
function Profile:SetMusicEnabled(value)
	value = not not value
	if self.musicEnabled == value then return true end -- no change
	self.musicEnabled = value
	self.musicEnabledChanged:Fire(value)
end
function Profile:GetActivePlaylistName()
	return self.activePlaylistName
end
function Profile:SetActivePlaylistName(value)
	if self.activePlaylistName == value then return true end -- no change
	if not self.customPlaylists[value] then error("No playlist exists with the name: " .. tostring(value)) end
	self.activePlaylistName = value
	self.activePlaylistNameChanged:Fire(value)
end
function Profile:GetCustomPlaylists() -- treat as read-only. Returned value will be modified by calling :SetCustomPlaylistTrack
	return self.customPlaylists
end
function Profile:GetCustomPlaylist(name) -- treat as read-only. Returned value will be modified by calling :SetCustomPlaylistTrack
	return self.customPlaylists[name]
end
function Profile:SetCustomPlaylistTrack(name, index, id)
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
function Profile:RemoveCustomPlaylistTrack(name, index)
	--	Returns true if nothing changed
	Assert.String(name)
	Assert.Integer(index)
	local playlist = self.customPlaylists[name]
	if not playlist or not playlist[index] then return true end
	table.remove(playlist, index)
end
function Profile:RenameCustomPlaylist(oldName, newName)
	Assert.String(oldName)
	Assert.String(newName)
	local customPlaylists = self.customPlaylists
	assert(not customPlaylists[newName], "A playlist with that name already exists")
	customPlaylists[newName] = customPlaylists[oldName] or error("No playlist exists with that name")
	customPlaylists[oldName] = nil
end
function Profile:Serialize()
	local t = {}
	-- todo consider storing content as a list instead of a dictionary
	-- todo for data store serialization, consider a more compact form (and include versions & a way of upgrading)
	for k, v in pairs(self) do
		if not eventNames[k] then
			t[k] = v
		end
	end
	return self
end
function Profile.Deserialize(profile)
	return setmetatable(profile, Profile):init()
end
function Profile:Destroy()
	for _, name in ipairs(eventNames) do -- Clean up events
		self[getLowerName(name)]:Destroy()
	end
end
-- for _, var in ipairs({"favoriteBooks", "readBooks"}) do
--     --[[Options...
--     profile.FavoriteBooks...
--     :Contains(bookId)
--     :Add(bookId)
--     :Remove(bookId)
--     :GetList()
--     ]]
-- end
-- function Profile:GetFavoriteBooks()
--     return self.favoriteBooks
-- end
-- function Profile:GetReadBooks()
--     return self.readBooks
-- end
return Profile