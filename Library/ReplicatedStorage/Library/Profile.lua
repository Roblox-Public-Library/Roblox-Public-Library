local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local Functions = require(Utilities.Functions)
local Music = require(ReplicatedStorage.Library.Music)
local Tutorial = require(ReplicatedStorage.Library.Tutorial)
--local BookPouch = require(ReplicatedStorage.Library.BookPouch)

local Profile = {}
Profile.__index = Profile
local vars = {
	Tutorial = Tutorial,
	-- field -> Class with .new and .Deserialize (returned value should have :Serialize); may also have .DeserializeDataStore
	-- The following capitalized fields are public but should be treated as read-only
	Music = Music,
	-- BookPouch = BookPouch,
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
		local v = profile[k]
		if v ~= nil then
			profile[k] = class.Deserialize(profile[k])
		else
			profile[k] = class.new()
		end
	end
	return setmetatable(profile, Profile)
end
function Profile.DeserializeDataStore(profile)
	for k, class in pairs(vars) do
		profile[k] = (class.DeserializeDataStore or class.Deserialize)(profile[k])
	end
	return setmetatable(profile, Profile)
end
function Profile:Destroy()
	for k, class in pairs(vars) do
		local v = self[k]
		if v.Destroy then
			v:Destroy()
		end
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