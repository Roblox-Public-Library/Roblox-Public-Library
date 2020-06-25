--[[TODO
Data store should be a list of IDs for each list
    Perhaps lists should have names (so we can easily add more lists later)
Profile could have preferences (ex Music On/Off)
Profile should have custom playlist(s)
Profile should convert lists to dictionaries for fast lookup (and vice versa when saving)

Player needs to be able to do the following to a book (ignoring the gui/input):
    -Favourite
    -Like
    -Dislike
    -Mark as read
    -Mark as unread
    -Add to a custom list (in the future if not now)
    To support that functionality, we need client side functions that signal remotes that the server side is listening to.
]]
local DataStoreService = game:GetService("DataStoreService")
local DataStores = require(game.ServerScriptService.DataStores)
local ProfilesStore = DataStores.new(DataStoreService:GetDataStore("Profiles"))
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(
    function(player)
        local PlayerData = ProfilesStore:Get(player.UserId)
        if PlayerData == nil then
            ProfilesStore:Set(
                player.UserId,
                {
                    FavoriteBooks = {},
                    LikedBooks = {},
                    DislikedBooks = {},
                    BooksRead = {}
                }
            )
        end
    end
)