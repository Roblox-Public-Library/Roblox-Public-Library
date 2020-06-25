-- TODO I request we use lower case to start private variables (like "favoriteBooks") - we still have :GetFavoriteBooks(). --chess123mate
local Profile = {}
Profile.__index = Profile
function Profile.new()
    return setmetatable(
        {
            FavoriteBooks = {},
            LikedBooks = {},
            DislikedBooks = {},
            BooksRead = {}
        },
        Profile
    )
end
function Profile:GetFavoriteBooks()
    return self.FavoriteBooks
end
function Profile:GetLikedBooks()
    return self.LikedBooks
end
function Profile:GetDislikedBooks()
    return self.DislikedBooks
end
function Profile:GetBooksRead()
    return self.BooksRead
end
return Profile