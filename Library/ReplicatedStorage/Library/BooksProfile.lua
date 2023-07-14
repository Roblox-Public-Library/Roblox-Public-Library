local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Class = require(ReplicatedStorage.Utilities.Class)
local List = require(ReplicatedStorage.Utilities.List)
local	setListContains = List.SetContains
local Table = require(ReplicatedStorage.Utilities.Table)
local PagesSeenManager = require(ReplicatedStorage.Library.PagesSeenManager)

local BooksProfile = Class.New("BooksProfile")
local AUTO_DELETE_EMPTY_LISTS = false
BooksProfile.MAX_LISTS = 30
BooksProfile.MAX_LIST_NAME_LENGTH = 40
BooksProfile.MAX_BOOKMARKS = 10 -- per book

BooksProfile.DefaultData = {
	Like = {}, -- List<id>
	Read = {}, -- List<id>
	Seen = {}, -- List<id>
	PagesSeen = {}, -- [tostring(id)] = string representing which pages seen
	Lists = { -- [name] = List<id>
		Favorites = {},
		["Read Later"] = {},
	},
	LastPageSeen = {}, -- [tostring(id)] = lastPageSeen
	Bookmarks = {}, -- [tostring(id)] = List<pageIndex>
}

local function getList(parent, key)
	local list = parent[key]
	if not list then
		list = {}
		parent[key] = list
	end
	return list
end

function BooksProfile.new(data)
	return setmetatable({
		data = data,
		pagesSeenManagers = {},
	}, BooksProfile)
end

function BooksProfile:GetLike(id)
	return table.find(self.data.Like, id)
end
function BooksProfile:SetLike(id, value)
	return setListContains(self.data.Like, id, value)
end

function BooksProfile:GetRead(id)
	return table.find(self.data.Read, id)
end
function BooksProfile:SetRead(id, value)
	return setListContains(self.data.Read, id, value)
end

function BooksProfile:GetSeen(id)
	return table.find(self.data.Seen, id)
end
function BooksProfile:RecordSeen(id)
	return setListContains(self.data.Seen, id, true)
end

function BooksProfile:NumPagesSeen(id)
	local pagesSeenManagers = self.pagesSeenManagers
	local key = tostring(id)
	local psm = pagesSeenManagers[key]
	if not psm then
		local data = self.data.PagesSeen[key]
		if data then
			psm = PagesSeenManager.new(data)
			pagesSeenManagers[key] = psm
		else
			return 0
		end
	end
	return psm:GetNum()
end
function BooksProfile:RecordSeenPage(id, page)
	local psm = self.pagesSeenManagers[tostring(id)]
	if not psm then
		psm = PagesSeenManager.new()
		self.pagesSeenManagers[tostring(id)] = psm
	end
	if psm:RecordSeenPage(page) then return true end
	self.data.PagesSeen[tostring(id)] = psm:GetString()
end

function BooksProfile:GetAllLists()
	return self.data.Lists
end
function BooksProfile:NumLists()
	return Table.CountKeys(self.data.Lists)
end
function BooksProfile:GetList(name)
	return self.data.Lists[name]
end
function BooksProfile:SetInList(name, id, value)
	local list = getList(self.data.Lists, name)
	if setListContains(list, id, value) then return true end
	if AUTO_DELETE_EMPTY_LISTS and not next(list) then
		self.data.Lists[name] = nil
	end
end
function BooksProfile:HasList(name)
	return self.data.Lists[name]
end
function BooksProfile:ListHasBook(name, id)
	return table.find(self.data.Lists[name], id)
end
function BooksProfile:CreateList(name)
	if self:HasList(name) then return true end
	self.data.Lists[name] = {}
end
function BooksProfile:RenameList(before, after)
	if not self:HasList(before) or self:HasList(after) then return true end
	local dataList = self.data.Lists
	dataList[after] = dataList[before]
	dataList[before] = nil
end
function BooksProfile:DeleteList(name)
	if not self:HasList(name) then return true end
	self.data.Lists[name] = nil
end

function BooksProfile:GetLastSeenPage(id)
	return self.data.LastPageSeen[tostring(id)]
end
function BooksProfile:SetLastSeenPage(id, page)
	if self:GetLastSeenPage(id) == page then return true end
	self.data.LastPageSeen[tostring(id)] = page
end

function BooksProfile:GetBookmarks(id)
	return self.data.Bookmarks[tostring(id)]
end
function BooksProfile:setBookmarks(id, bookmarks)
	self.data.Bookmarks[tostring(id)] = bookmarks
end
function BooksProfile:IsBookmarked(id, pageIndex)
	local list = self:GetBookmarks(id)
	return list and table.find(list, pageIndex)
end
function BooksProfile:SetBookmark(id, pageIndex, value)
	local list = self:GetBookmarks(id)
	if not list then
		if not value then return true end
		list = {}
		self:setBookmarks(id, list)
	end
	if setListContains(list, pageIndex, value) then return true end
	if value then
		table.sort(list)
	elseif not next(list) then
		self:setBookmarks(id, nil)
	end
end

BooksProfile.recordChangesFor = {
	"SetInList", "CreateList", "DeleteList",
	"SetLastSeenPage",
	"SetBookmark",
}
BooksProfile.simpleReplication = { -- client -> server
	"SetLike", "SetRead",
	"SetInList", "DeleteList",
	"SetLastSeenPage",
	"SetBookmark",
	"RecordSeen",
}
BooksProfile.rateLimitedActions = {SetLike = true, SetRead = true}

return BooksProfile