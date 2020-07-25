local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Books = {}
local books = ReplicatedStorage:WaitForChild("GetBooks"):InvokeServer()
function Books:GetBooks()
	--	returns list of {.Id .Title .Author .Models}
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