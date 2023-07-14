local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BooksProfile = require(ReplicatedStorage.Library.BooksProfile)
local Event = require(ReplicatedStorage.Utilities.Event)
local List = require(ReplicatedStorage.Utilities.List)

local ServerScriptService = game:GetService("ServerScriptService")
local Books = require(ServerScriptService.Library.Books)
local Genres = require(ServerScriptService.Library.Genres)
local Update = require(ServerScriptService.Library.BookMetricsUpdater).Update
local ChangedTracker = require(ServerScriptService.Library.ChangedTracker)

for _, key in BooksProfile.recordChangesFor do
	local base = BooksProfile[key]
	BooksProfile[key] = function(self, ...)
		if base(self, ...) then return true end
		self.otherChanged:RecordChanged()
		self.Changed:Fire()
	end
end

-- Public replication handling
function BooksProfile:getERead(id)
	return if self:GetRead(id) or self:GetLike(id) then true else false
end
local function genHandlePublicChanges(name, afterChange)
	local base = BooksProfile[name]
	BooksProfile[name] = function(self, id, value)
		local eReadBefore = self:getERead(id)
		local seenBefore = self:GetSeen(id)
		if base(self, id, value) then return true end
		local eReadNow = self:getERead(id)
		if eReadBefore ~= eReadNow then
			self:recordPublicChange("EReads", id, eReadNow)
		end
		if value and not seenBefore then
			self:RecordSeen(id, true)
		end
		if afterChange then
			afterChange(self, id, value)
		end
		self.Changed:Fire()
	end
end
genHandlePublicChanges("SetLike", function(self, id, value)
	self:recordPublicChange("Likes", id, value)
end)
genHandlePublicChanges("SetRead")
local base = BooksProfile.RecordSeen
function BooksProfile:RecordSeen(id)
	if base(self, id) then return true end
	self:recordPublicChange("Seen", id, true)
	self.Changed:Fire()
end
local base = BooksProfile.RecordSeenPage
function BooksProfile:RecordSeenPage(id, page)
	local num = self:NumPagesSeen(id)
	if base(self, id, page) then return true end
	local now = self:NumPagesSeen(id)
	if num ~= now then
		self:recordPublicChange("Pages", id, now - num)
	else
		self.otherChanged:RecordChanged()
	end
	self.Changed:Fire()
end
local base = BooksProfile.SetLastSeenPage
function BooksProfile:SetLastSeenPage(id, value)
	local numBefore = self:NumPagesSeen(id)
	if base(self, id, value) then return true end
	if numBefore == 1 and value then -- opened past first page pair
		self:recordPublicChange("Open", id, true)
		-- We don't need to call self.Changed:Fire() because we know that RecordSeenPage will run with changes
	end
	self:RecordSeenPage(id, value)
end
-- End of public replication handling

local getTracker do -- RateTracker used to prevent players from interacting with more than a few books in a limited period of time
	local max = 5
	local period = 30
	local RateTracker = {}
	RateTracker.__index = RateTracker
	function RateTracker.new()
		return setmetatable({
			numUsed = 0,
			ids = {},
			NotAtRateLimitEvent = Event.new(),
		}, RateTracker)
	end
	function RateTracker:TryUse(id)
		local ids = self.ids
		if not ids[id] then
			if self.numUsed >= max then return false end
			ids[id] = 0
		end
		ids[id] += 1
		task.delay(period, function()
			ids[id] -= 1
			if ids[id] == 0 then
				ids[id] = nil
				self.numUsed -= 1
				self.NotAtRateLimitEvent:Fire()
			end
		end)
		return true
	end
	function RateTracker:AtRateLimit()
		return self.numUsed >= max and self.ids
	end
	local Players = game:GetService("Players")
	local rateTrackers = {}
	Players.PlayerAdded:Connect(function(player)
		rateTrackers[player] = RateTracker.new()
	end)
	Players.PlayerRemoving:Connect(function(player)
		rateTrackers[player] = nil
	end)
	getTracker = function(player) return rateTrackers[player] end
end

local function isBookId(v)
	return type(v) == "number" and Books:GetBook(v) -- note that if a book doesn't have an id, its name is used instead (and we want to disable that)
end
local function isBool(v) return v == true or v == false end
local function isString(v) return type(v) == "string" end
local function isPageIndex(v) return type(v) == "number" and v % 1 == 0 and v > 0 end
local rateLimitedActions = BooksProfile.rateLimitedActions
local remoteDescs = {
	{"SetLike", isBookId, isBool},
	{"SetRead", isBookId, isBool},
	{"SetInList", isString, isBookId, isBool},
	{"DeleteList", isString},
	{"SetLastSeenPage", isBookId, isPageIndex},
	{"SetBookmark", isBookId, isPageIndex, isBool},
	{"RecordSeen", isBookId},
}
local TextService = game:GetService("TextService")
local function filter(player, text)
	local filtered
	local id = player.UserId
	local success, msg = pcall(function()
		local result = TextService:FilterStringAsync(text, id, Enum.TextFilterContext.PrivateChat)
		filtered = result:GetNonChatStringForUserAsync(id)
	end)
	if not success then
		print("TextService failed:", msg)
	end
	return filtered
end
local whitelistedNames = List.ToSet({
	"fav", "favs", "favorite", "favorites",
	"read later",
	"useful", "interesting",
	"best", "top", "good", "amazing", "nice"
})
local function isWhitelistedName(name)
	if whitelistedNames[name:lower()] or Genres.InputToGenre(name) then return true end
	local a, b = name:match("^(%w+)%s+(.*)")
	return a and whitelistedNames[a] and Genres.InputToGenre(b)
end
local listFilteredEvent
function BooksProfile.InitRemotes(newRemote)
	local atRateLimitEvent = newRemote:Event("AtRateLimit") -- set of ids you can keep sending events for | false if not at limit
	for _, desc in remoteDescs do
		local name = table.remove(desc, 1)
		local base = BooksProfile[name]
		local expectedArgs = #desc
		newRemote:Event(name, function(player, self, ...)
			local n = select("#", ...)
			if n ~= expectedArgs then return end
			for i = 1, n do
				local arg = select(i, ...)
				if not desc[i](arg) then return end
			end
			if rateLimitedActions[name] then
				local tracker = getTracker(player)
				if not tracker:TryUse((...)) then return end
				local ids = tracker:AtRateLimit()
				if ids then
					atRateLimitEvent:FireClient(player, ids)
					tracker.NotAtRateLimitEvent:Once(function()
						atRateLimitEvent:FireClient(player, false)
					end)
				end
			end
			base(self, ...)
		end)
	end
	local function checkName(player, self, name)
		if not isString(name) or #name > BooksProfile.MAX_LIST_NAME_LENGTH then return end
		if self:HasList(name) then return end
		if not isWhitelistedName(name) then
			local filtered = filter(player, name)
			if not filtered then return false end
			if self:HasList(filtered) then return end
			return filtered
		end
		return name
	end
	newRemote:Function("TryCreateList", function(player, self, name) -- returns filtered name or false if something went wrong with filtering
		if self:NumLists() >= BooksProfile.MAX_LISTS then return end
		name = checkName(player, self, name)
		if not name then return name end
		self:CreateList(name)
		return name
	end)
	newRemote:Function("TryRenameList", function(player, self, before, name) -- returns filtered name or false if something went wrong with filtering
		if not self:HasList(before) then return end
		name = checkName(player, self, name)
		if not name then return name end
		self:RenameList(before, name)
		return name
	end)
	listFilteredEvent = newRemote:Event("ListFilteredName")
	newRemote:Event("DeleteList", function(player, self, name)
		self:DeleteList(name)
	end)
end

local base = BooksProfile.new
function BooksProfile.new(data, profile)
	local self = base(data)
	self.changes = Update.new()
	-- same format as Data except instead of a List<id> it's {[id] = 1 for added, -1 for removed}; only for public counts
	self.Changed = Event.new()
	self.otherChanged = ChangedTracker.new()
	if Books:AreReady() then -- Remove any ids that no longer exist
		local function check(list)
			for i = #list, 1, -1 do
				if not Books:GetBook(list[i]) then
					table.remove(list, i)
				end
			end
		end
		check(data.Like)
		check(data.Read)
		for name, list in data.Lists do
			check(list)
		end
		for _, t in {data.LastPageSeen, data.Bookmarks} do
			for sId in t do
				if not Books:GetBook(tonumber(sId)) then
					t[sId] = nil
				end
			end
		end
	end
	local player = profile.player
	for name in data.Lists do
		if isWhitelistedName(name) then
			listFilteredEvent:FireClient(player, name, name)
		else
			task.spawn(function()
				listFilteredEvent:FireClient(player, name, filter(player, name))
			end)
		end
	end
	return self
end
function BooksProfile:Destroy()
	self.Changed:Destroy()
end
function BooksProfile:HasChanges()
	return self.otherChanged:HasChanges() or self:HasPublicChanges()
end
function BooksProfile:HasPublicChanges()
	return self.changes:HasChanges()
end
function BooksProfile:CollectPublicUpdate()
	-- Returns BookMetricsUpdater.Update
	--	You *must* call PublicChangesSubmitted or PublicChangesFailed after calling this function
	if self.pausedChanges then
		error("Cannot CollectPublicUpdate until previous call finishes (including call to PublicChangesSubmitted or PublicChangesFailed)", 2)
	end
	self.pausedChanges = {}
	return self.changes
end
function BooksProfile:PublicChangesSubmitted()
	self.changes = Update.new()
	self:afterPublicChanges()
end
function BooksProfile:PublicChangesFailed()
	self:afterPublicChanges()
end
function BooksProfile:afterPublicChanges()
	local paused = self.pausedChanges
	self.pausedChanges = nil
	for _, change in paused do
		change()
	end
end
function BooksProfile:RecordSaved(saveTime) -- record that the data has been saved to data store
	self.otherChanged:RecordSaved(saveTime)
end
function BooksProfile:recordPublicChange(name, id, added)
	local paused = self.pausedChanges
	if paused then
		table.insert(paused, function() self:recordPublicChange(name, id, added) end)
		return
	end
	if type(added) ~= "number" then
		added = if added then 1 else -1
	end
	self.changes:Add(id, name, added)
end

return BooksProfile