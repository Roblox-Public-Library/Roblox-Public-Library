local Profile = {}
Profile.__index = Profile
function Profile.new()
    return setmetatable({
		musicEnabled = true,
		activePlaylistName = "Default",
		customPlaylist = {},
		-- FavoriteBooks = {},
		-- LikedBooks = {},
		-- DislikedBooks = {},
		-- BooksRead = {},
    }, Profile)
end
function Profile:GetMusicEnabled()
	return self.musicEnabled
end
function Profile:SetMusicEnabled(value)
	value = not not value
	if self.musicEnabled == value then return true end -- no change
	self.musicEnabled = value
end
function Profile:GetActivePlaylistName()
	return self.activePlaylistName
end
function Profile:SetActivePlaylistName(value)
	if self.activePlaylistName == value then return true end -- no change
	self.activePlaylistName = value
end
function Profile:GetCustomPlaylist() -- treat as read-only. Returned value will be modified by calling :SetCustomPlaylistTrack
	return self.customPlaylist
end
function Profile:SetCustomPlaylistTrack(index, id)
	if self.customPlaylist[index] == id then return true end -- no change
	assert(index >= 1 and index <= #self.customPlaylist + 1, "Index is out of range")
	self.customPlaylist[index] = id
end
function Profile:Serialize()
	-- todo if storing favorites as a dictionary, consider transmitting as a list insted
	return self
end
function Profile.Deserialize(profile)
	return setmetatable(profile, Profile)
end
-- for _, var in ipairs({"favoriteBooks", "likedBooks", "dislikedBooks", "booksRead"}) do
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
-- function Profile:GetLikedBooks()
--     return self.likedBooks
-- end
-- function Profile:GetDislikedBooks()
--     return self.dislikedBooks
-- end
-- function Profile:GetBooksRead()
--     return self.booksRead
-- end
return Profile