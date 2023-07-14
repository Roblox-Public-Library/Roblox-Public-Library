local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SearchProfile = require(ReplicatedStorage.Library.SearchProfile)

local ServerScriptService = game:GetService("ServerScriptService")
local ChangedTracker = require(ServerScriptService.Library.ChangedTracker)
local Genres = require(ServerScriptService.Library.Genres)
local RateLimiter = require(ServerScriptService.Utilities.RateLimiter)

ChangedTracker.ApplyToClassWithEvent(SearchProfile)

local knownConfigFields = SearchProfile.knownConfigFields
local function cleanConfig(config)
	local changed = false
	for k, v in config do
		local validate = knownConfigFields[k]
		if not validate then
			config[k] = nil
			changed = true
		else
			local new = validate(v)
			if config[k] ~= new then
				config[k] = new
				changed = true
			end
		end
	end
	return changed
end
function SearchProfile:cleanOutOldRefs()
	local changed = false
	local config = self.Config
	local genres = config.Genres
	if genres then
		for k, v in genres do
			if not Genres.IsGenre(k) then
				genres[k] = nil
				changed = true
			end
		end
	end
	local booksData = self.profile.Books
	local lists = config.Lists
	if lists then
		for k, v in lists do
			if not booksData:HasList(k) then
				lists[k] = nil
				changed = true
			end
		end
	end
	return true
end

local base = SearchProfile.new
function SearchProfile.new(data, profile)
	local changed = cleanConfig(data.Config)
	local self = base(data)
	self.profile = profile
	task.defer(function()
		if self:cleanOutOldRefs() or changed then
			self:RecordChanged()
		end
	end)
	return self
end

function SearchProfile.InitRemotes(newRemote)
	newRemote:Event("Config", RateLimiter.new(2, 10):Wrap(function(player, self, config)
		if type(config) ~= "table" then return end
		cleanConfig(config)
		self.data.Config = config
		self.Config = config
		self:cleanOutOldRefs()
		self:RecordChanged()
	end))
	newRemote:Event("SetResultsViewList", function(player, self, value)
		if value ~= not not value then return end
		if self.data.ResultsViewList == value then return end
		self.data.ResultsViewList = value
		self:RecordChanged()
	end)
end
return SearchProfile