wait() -- todo this can be removed after books register with this script (it gives them a chance to create Author value)
local Books = {}

--local modelToBook = {}
local books = {} -- List<Book> where each book is {.Id .Title .Author .Models} note: everything in books can be replicated as-is to clients
local idToBook = {}
local bookToContent = {} -- content stored here so it is not replicated to clients automatically

local function isBook(obj)
	if obj:IsA("BasePart") and obj:FindFirstChild("ClickDetector") then
		local script = obj:FindFirstChildOfClass("Script")
		return script and script:FindFirstChild("BookColor")
	end
	return false
end
for _, folder in ipairs({workspace.Books, workspace["Post Books"], workspace.BookOfTheMonth}) do
	for _, c in ipairs(folder:GetDescendants()) do
		if isBook(c) then
			local idObj = c:FindFirstChild("Id")
			local id
			if idObj then
				id = idObj.Value
				idObj:Destroy()
			else
				print("No id found for", c:GetFullName())
			end
			local authorObj = c:FindFirstChild("Author", true)
			if not authorObj then -- todo destroy Author value since if it exists (do this after client updated to not need it)
				print("No author found for", c:GetFullName())
			end

			local book = id and idToBook[id]
			if book then
				book.Models[#book.Models + 1] = c
			else
				book = {
					Id = id,
					Title = c.Name, -- todo this is not always the title
					Author = authorObj and authorObj.Value or "?",
					Models = {c},
				}
				books[#books + 1] = book
			end
			-- modelToBook[c] = book
			-- todo get content and add to bookToContent
		end
	end
end

-- local numBooks = #books
-- function Books:GetCount() return numBooks end
-- function Books:Search(s)
-- 	--	return all books with 's' in their title/author
-- 	local list = {}
-- 	for _, book in ipairs(books) do
-- 		if book.Title:find(s) or book.Author:find(s) then
-- 			list[#list + 1] = book
-- 		end
-- 	end
-- 	return list
-- end
function Books:FromId(id)
	return idToBook[id]
end

local getBooks = Instance.new("RemoteFunction")
getBooks.Name = "GetBooks"
getBooks.Parent = game:GetService("ReplicatedStorage")
getBooks.OnServerInvoke = function(player) return books end

return Books