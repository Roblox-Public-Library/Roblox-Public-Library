local Books = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local List = require(ReplicatedStorage.Utilities.List)
local ServerScriptService = game:GetService("ServerScriptService")
local BookChildren = require(ServerScriptService.BookChildren)
local Genres = require(ServerScriptService.Genres)

local books = {} -- List<Book> where each book is {.Id .Title .Author .Models} note: everything in books can be replicated as-is to clients
local idToBook = {}
local bookModelToContent = {} -- content stored here so it is not replicated to clients automatically
local defaultCover = "http://www.roblox.com/asset/?id=428733812"
local ServerStorage = game:GetService("ServerStorage")
local storage = ServerStorage:FindFirstChild("Book Data Storage")
local modelToId = {}
local warnOutdated
if storage then
	warnOutdated = function()
		warn("Books missing ids - Book Maintenance required.")
		warnOutdated = function() end
	end
else
	warnOutdated = function() end
end
if storage then
	local idsFolder = storage:FindFirstChild("Ids")
	for _, obj in ipairs(idsFolder:GetChildren()) do
		local id = tonumber(obj.Name)
		if id then
			if obj.Value then
				modelToId[obj.Value] = id
			else
				warn("Improperly configured Ids:", obj:GetFullName())
			end
			for _, c in ipairs(obj:GetChildren()) do
				if c.Value then
					modelToId[c.Value] = id
				else
					warn("Improperly configured Ids in:", obj:GetFullName())
				end
			end
		else
			warn("Improperly configured Ids:", obj:GetFullName())
		end
	end
end

local getData = Instance.new("RemoteFunction")
getData.Name = "GetBookData"
getData.Parent = ReplicatedStorage
getData.OnServerInvoke = function(player, bookModel)
	local response = bookModelToContent[bookModel] or error(tostring(bookModel:GetFullName()) .. " has no data")
	return response[1], response[2], response[3] -- cover, authorsNote, words
end
local getBooks = Instance.new("RemoteFunction")
getBooks.Name = "GetBooks"
getBooks.Parent = ReplicatedStorage
getBooks.OnServerInvoke = function(player) return books end
local function convertEmptyToAnonymous(authorNames)
	for _, name in ipairs(authorNames) do -- Check to see if generating a new list is necessary
		if name == "" then
			local new = {}
			for i, name in ipairs(authorNames) do
				new[i] = name == "" and "Anonymous" or ""
			end
			return new
		end
	end
	return authorNames
end
function Books:Register(book, genres, cover, title, customAuthorLine, authorNames, authorIds, authorsNote, publishDate, words, librarian)
	BookChildren.AddTo(book)

	-- BookScript specific startup code
	if customAuthorLine == "" then customAuthorLine = nil end
	if not cover or cover == "" then cover = defaultCover end
	local orig = genres
	genres = {}
	for _, raw in ipairs(orig) do
		local genre = Genres.InputToGenre(raw)
		if genre then
			genres[#genres + 1] = genre
		else
			warn("Unrecognized genre '" .. tostring(raw) .. "' in", book:GetFullName())
		end
	end

	local coverDecal = book:FindFirstChild("Cover")
	if coverDecal then
		coverDecal.Texture = cover
	end
	if not storage then -- if storage exists, maintenance plugin takes care of this
		BookChildren.UpdateGuis(book, title)
	end

	local authorLine = customAuthorLine or List.ToEnglish(convertEmptyToAnonymous(authorNames))

	-- Register book into system

	local id = modelToId[book]
	if not id and not book.Name:find("Example Book") and not book.Name:find("The Secret Book") then -- todo generalize exceptions
		warnOutdated()
	end
	local bookData = id and idToBook[id]
	if bookData then
		bookData.Models[#bookData.Models + 1] = book
		local copyModel = bookData.Models[1]
		bookModelToContent[book] = bookModelToContent[copyModel]
	else
		bookData = {
			Id = id,
			Title = title,
			AuthorLine = authorLine == "" and "Anonymous" or authorLine,
			Authors = authorNames,
			AuthorIds = authorIds, -- todo use this for players who are in-game in case they changed their name recently
			PublishDate = publishDate,
			Librarian = librarian,
			Models = {book},
			Genres = genres,
		}
		if id then
			idToBook[id] = bookData
		end
		books[#books + 1] = bookData
		bookModelToContent[book] = {cover, authorsNote, words}
	end
end
function Books:GetCount() return #books end
function Books:GetBooks() return books end

return Books