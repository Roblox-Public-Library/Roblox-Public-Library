local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local Functions = require(Utilities.Functions)

local Profile = {}
Profile.__index = Profile
local vars = {
	-- field -> Class with .new and .Deserialize
	Music = Music, -- Public read-only field
	-- favoriteBooks = SaveableSet,
	-- readBooks = SaveableSet,
}
function Profile.new()
	local self = {}
	for k, v in pairs(vars) do
		self[k] = v.new()
	end
    return setmetatable(self, Profile)
end
function Profile:Serialize()
	local t = {}
	for k, v in pairs(self) do
		t[k] = v:Serialize()
	end
	return t
end
function Profile.Deserialize(profile)
	for k, class in pairs(vars) do
		profile[k] = class.Deserialize(profile[k])
	end
	return setmetatable(profile, Profile)
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