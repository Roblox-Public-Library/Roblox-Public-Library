local ReplicatedStorage = game:GetService("ReplicatedStorage")
local List = require(ReplicatedStorage.Utilities.List)
local Books = {}
local books = ReplicatedStorage:WaitForChild("GetBooks"):InvokeServer()
local bookToAuthorNames = {}
local bookToAuthorIds = {}
for _, book in ipairs(books) do
	bookToAuthorNames[book] = List.ToSet(book.Authors)
	bookToAuthorIds[book] = List.ToSet(book.AuthorIds)
end
function Books:GetBooks()
	--[[Returns a list of books:
	{
		Id = number (The book's unique ID),
		Title = string (The book's name),
		AuthorLine = string (An author line. Example: "author1, author2, and author3"),
		Authors = dictionary (A dict of author usernames),
		AuthorIds = dictionary (A dict of author ID's),
		PublishDate = string (The date on which the book was published),
		Librarian = string (The librarian's username),
		Genres = List of string
		Models = list of BookModel (The models of the book),
	}
	]]
	return books
end
local modelToBook = {}
local idToBook = {}
function Books:FromObj(obj)
	return modelToBook[obj]
end
function Books:FromId(id)
	return idToBook[id]
end
function Books:AuthorNamesContains(book, value)
	return bookToAuthorNames[book][value] or book.AuthorLine:find(value, 1, true)
end
function Books:AuthorIdContains(book, userId)
	return bookToAuthorIds[book][userId]
end

for _, book in ipairs(books) do
	local id = book.Id
	if id then
		idToBook[id] = book
	end
	for _, model in ipairs(book.Models) do
		modelToBook[model] = book
	end
end

return Books