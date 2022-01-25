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
local booksReadyEvent = Instance.new("BindableEvent") -- set to nil when books have finished registering (Roblox only resumes a finite number of threads per frame when returning from most Async functions, including WaitForChild)
local getBooks = Instance.new("RemoteFunction")
getBooks.Name = "GetBooks"
getBooks.Parent = ReplicatedStorage
getBooks.OnServerInvoke = function(player)
	if booksReadyEvent then
		booksReadyEvent.Event:Wait()
	end
	return books
end
local function convertEmptyToAnonymous(authorNames)
	for _, name in ipairs(authorNames) do -- Check to see if generating a new list is necessary
		if name == "" or not name then
			local new = {}
			for i, name in ipairs(authorNames) do
				new[i] = (name == "" or not name) and "Anonymous" or name
			end
			return new
		end
	end
	return authorNames
end
local lineBreakCommands = {
	["/line"] = true,
	["/dline"] = true,
	["/page"] = true,
	["/turn"] = true,
}
local alphaNumeric = {}
for i = 48, 57 do alphaNumeric[string.char(i)] = true end
for i = 65, 90 do alphaNumeric[string.char(i)] = true end
for i = 97, 122 do alphaNumeric[string.char(i)] = true end
local function processWords(words)
	local new = {}
	local secondPrevWasLineBreak = true
	local prevWasLineBreak = true
	local prevRepeatedChar
	for _, v in ipairs(words) do
		if v == "" then continue end
		for word in string.gmatch(v, "%S+") do
			local isLineBreak = lineBreakCommands[word]
			local firstChar = string.sub(word, 1, 1)
			local repeatedChar = #word >= 5 and string.match(word, (alphaNumeric[firstChar] and "^" or "^%") .. firstChar .. "+$") and firstChar
			if prevRepeatedChar and isLineBreak and secondPrevWasLineBreak then
				new[#new] = "/hline" .. prevRepeatedChar
			end
			table.insert(new, word)
			secondPrevWasLineBreak, prevWasLineBreak, prevRepeatedChar = prevWasLineBreak, isLineBreak, repeatedChar
		end
	end
	if prevRepeatedChar and secondPrevWasLineBreak then -- last word is a repeated character
		words[#words] = "/hline" .. prevRepeatedChar
	end
	return new
end
local lastRegisterTime
function Books:Register(book, genres, cover, title, customAuthorLine, authorNames, authorIds, authorsNote, publishDate, words, librarian)
	if not booksReadyEvent then
		warn("Books:Register called after book list assumed to have finished initializing")
	else
		local now = workspace.DistributedGameTime
		if lastRegisterTime ~= now then
			lastRegisterTime = now
			task.delay(0.5, function()
				if now == lastRegisterTime then
					booksReadyEvent:Fire()
					booksReadyEvent:Destroy()
					booksReadyEvent = nil
				end
			end)
		end
	end
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

	authorNames = convertEmptyToAnonymous(authorNames)
	local authorLine = customAuthorLine or List.ToEnglish(authorNames)

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
		bookModelToContent[book] = {cover, authorsNote, processWords(words)}
	end
end
function Books:GetCount() return #books end
function Books:GetBooks() return books end

return Books