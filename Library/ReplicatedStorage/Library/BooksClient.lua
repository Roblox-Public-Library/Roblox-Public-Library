local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event = require(ReplicatedStorage.Utilities.Event)
local List = require(ReplicatedStorage.Utilities.List)

local Books = {}

local books = ReplicatedStorage:WaitForChild("GetBooks"):InvokeServer()

local bookToAuthorNames = {} --[book][authorName:lower()] = true
local bookToAuthorLine = {} --[book] = authorLine:lower()
local bookToAuthorIds = {} --[book][authorId] = true
local bookToTitle = {} --[book] = title:lower()
local function lowerEachValue(t, anonymousValue) -- if anonymousValue provided, ensure it is all lowercase
	anonymousValue = anonymousValue or ""
	local new = {}
	for i, v in ipairs(t) do
		new[i] = if v == "" then anonymousValue
			elseif type(v) == "string" then v:lower()
			else v
	end
	return new
end
local modelToBook = {}
local idToBook = {}
for _, book in ipairs(books) do
	book.GenreLine = table.concat(book.Genres, ", ")

	bookToAuthorNames[book] = List.ToSet(lowerEachValue(book.Authors), "anonymous")
	bookToAuthorIds[book] = List.ToSet(lowerEachValue(book.AuthorIds))
	bookToAuthorLine[book] = book.AuthorLine:lower()
	local lowerTitle = book.Title:lower()
	bookToTitle[book] = lowerTitle

	local id = book.Id
	if id then
		idToBook[id] = book
	end
	for _, model in ipairs(book.Models) do
		modelToBook[model] = book
	end
end
ReplicatedStorage:WaitForChild("PageCountReady").OnClientEvent:Connect(function(id, pageCount)
	local book = idToBook[id]
	book.PageCount = pageCount
	local ready = book.PageCountReady
	if ready then
		ready:Fire()
		ready:Destroy()
		book.PageCountReady = nil
	end
end)
ReplicatedStorage:WaitForChild("PageCountReady"):FireServer()

function Books:GetBooks()
	--[[Returns a list of book summaries:
	{
		Id = number (The book's unique ID),
		Title = string (The book's name),
		AuthorLine = string (An author line. Example: "author1, author2, and author3"),
		Authors = List of authors,
		AuthorIds = List of author ids,
		PublishDate = string (The date on which the book was published),
		Librarian = string (The librarian's username),
		Genres = List of string,
		GenreLine = string
		Models = list of BookModel (The models of the book),
		PageCount = number of pages (may be nil if not yet calculated!),
		HasAudio = boolean,
	}
	]]
	return books
end
function Books:OnPageCountReady(book, fn)
	if book.PageCount then
		task.spawn(fn)
		return
	end
	if not book.PageCountReady then
		book.PageCountReady = Event.new()
	end
	book.PageCountReady:Connect(fn)
end
function Books:FromObj(obj)
	return modelToBook[obj]
end
function Books:FromId(id)
	return idToBook[id]
end
function Books:BookTitleContains(book, value) -- value must be lowercase
	return bookToTitle[book]:find(value, 1, true)
end
local wordStartBorder = "%f[%w_]"
local wordEndBorder = "%f[^%w_]"
function Books:BookTitleContainsWholeWord(book, value) -- value must be lowercase
	return bookToTitle[book]:find(wordStartBorder .. value .. wordEndBorder)
end
function Books:BookTitleEquals(book, value) -- value must be lowercase
	return bookToTitle[book] == value
end
local function escape(s)
	return s:gsub("([%%%[%]()%.%+%-%*%?%^%$])", "%%%1")
end
function Books:AuthorNamesContainFullWord(book, value) -- value must be :lower()'d
	local safeValue = escape(value)
	return bookToAuthorNames[book][value] or bookToAuthorLine[book]:find("%f[%w_]" .. safeValue .. "%f[^%w_]")
end
function Books:AuthorNamesContain(book, value) -- value must be :lower()'d
	for author, _ in pairs(bookToAuthorNames[book]) do
		if author:find(value, 1, true) then return true end
	end
	return bookToAuthorLine[book]:find(value, 1, true)
end
function Books:AuthorIdsContain(book, userId)
	return bookToAuthorIds[book][userId]
end
function Books:GetAuthorIdLookup(book)
	return bookToAuthorIds[book]
end

return Books