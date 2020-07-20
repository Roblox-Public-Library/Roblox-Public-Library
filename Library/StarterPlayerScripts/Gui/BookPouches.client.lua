local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.localPlayer
local bookPouchGui = localPlayer.PlayerGui.BookPouchGui
local profile = require(ReplicatedStorage.ProfileClient)
local bookPouch = profile.BookPouch

--[[TODO
bookPouch may have several books in it (from data stores); update the gui to reflect this
When something's added to the book pouch, consider updating its LayoutOrder
    (or let it use alphabetical sorting, but then change the name to be the same as the text)
Handle removing a book from the pouch - it must update the server and the 'bookPouch' object
Server side, when a book is opened, this should be automatically recorded as added to the user's pouch
We should cap the number of books you can have in the pouch (even if it's to 1000)
The arrow button should toggle visibility.
    If the player has closed it, adding new books to the pouch should not re-open it.
]]

local rowTemplate = bookPouchGui.Books.Row
rowTemplate.Parent = nil

-- Automatically add opened books to the pouch
ReplicatedStorage.BookOpen:OnClientEvent(function(book)
    bookPouchGui.Enabled = true
    local bookName = book.Name
    local authorName = book.Author
    local newRow = rowTemplate:Clone()
    newRow.Parent = bookPouchGui.ScrollingFrame
    newRow.Book.Text = bookName.." by "..authorName
end)

for a in bookPouchGui.ScrollingFrame:GetChildren() do
    a.Activated:Connect(function(book)
        book = workspace.Books:FindFirstChild(book.Name)
        book.BookClick:FireServer(localPlayer)
    end)
end

for b in bookPouchGui:GetDescendants() do
    if b.Name == "Delete" then
        b.Activated:Connect(function()
            b.Parent:Destroy()
        end)
    end
end