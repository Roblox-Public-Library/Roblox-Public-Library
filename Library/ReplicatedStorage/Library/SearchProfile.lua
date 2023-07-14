local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookSearch = require(ReplicatedStorage.Library.BookSearchBasics)
local Genres = require(ReplicatedStorage.Library.Genres)
local Assert = require(ReplicatedStorage.Utilities.Assert)
local	Validate = Assert.Validate
local Class = require(ReplicatedStorage.Utilities.Class)

local SearchProfile = Class.New("SearchProfile")

local isOption = BookSearch.ValidateIsOption
local isTable = BookSearch.ValidateIsTableOfOptions
local knownConfigFields = {
	PublishedMin = Validate.Number,
	PublishedMax = Validate.Number,
	PagesMin = Validate.Integer,
	PagesMax = Validate.Integer,
	MarkedRead = isOption,
	Liked = isOption,
	Bookmarked = isOption,
	Audio = isOption,
	Genres = isTable,
	Lists = isTable,
	SortType = Validate.String,
	SortAscending = Validate.Boolean,
}
SearchProfile.knownConfigFields = knownConfigFields
SearchProfile.DefaultData = {
	ResultsViewList = true,
	Config = {
		Genres = {}, -- [genre] = always/never/optional
		Lists = {}, -- [listName] = always/never/optional
		SortType = "Recommended",
		-- SortAscending = nil (for default) or true/false
	},
}

function SearchProfile.new(data)
	data.Config.SortType = BookSearch.ValidateSortType(data.Config.SortType)
	local genres = data.Config.Genres
	for genre in genres do
		if not Genres.IsGenre(genre) then
			genres[genre] = nil
		end
	end
	return setmetatable({
		data = data,
		Config = data.Config,
	}, SearchProfile)
end
local function getFromKeyPath(t, keyPath)
	local prevKey
	for key in keyPath:gmatch("[^.]+") do
		if prevKey then
			t = t[prevKey] or error("No path: " .. keyPath, 2)
		end
		prevKey = key
	end
	return t, prevKey
end
function SearchProfile:Set(keyPath, value)
	local t, key = getFromKeyPath(self.Config, keyPath)
	t[key] = value
end

return SearchProfile