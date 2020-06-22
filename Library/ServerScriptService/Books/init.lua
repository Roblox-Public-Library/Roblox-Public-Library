wait() -- todo this can be removed after books register with this script (it gives them a chance to create Author value)
local Books = {}

local bookModels = {}
local books = {} -- note: everything in books can be replicated as-is to clients
local bookToContent = {} -- content stored here so it is not replicated to clients automatically

local function isBook(obj)
	if obj:FindFirstChild("ClickDetector") then
		local script = obj:FindFirstChildOfClass("Script")
		return script and script:FindFirstChild("BookColor")
	end
	return false
end
for _, c in ipairs(workspace:GetDescendants()) do
	if isBook(c) then
		local author = c:FindFirstChild("Author", true)
		if not author then
			print("No author found for", c:GetFullName())
		end
		bookModels[#bookModels + 1] = c
		books[#books + 1] = {
			Title = c.Name,
			Author = author and author.Value or "?",
			Model = c,
		}
	end
end
local numBooks = #books

function Books:GetModels() return bookModels end
function Books:GetCount() return numBooks end
function Books:Search(s)
	--	return all books with 's' in their title/author
	local list = {}
	for _, book in ipairs(books) do
		if book.Title:find(s) or book.Author:find(s) then
			list[#list + 1] = book
		end
	end
	return list
end

local getBooks = Instance.new("RemoteFunction")
getBooks.Name = "GetBooks"
getBooks.Parent = game:GetService("ReplicatedStorage")
getBooks.OnServerInvoke = function(player) return books end

return Books