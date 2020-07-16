local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.localPlayer
local bookPouchGui = localPlayer.PlayerGui.BookPouchGui

local profile = require(ReplicatedStorage.ProfileClient)
local bookPouch = profile.BookPouch

local rowTemplate = bookPouchGui.Books.Row
rowTemplate.Parent = nil

ReplicatedStorage.BookOpen:OnClientEvent(function (book)
    local bookName = book.Name
    local authorName = book.Author
    local newRow = rowTemplate:Clone()
    newRow.Parent = bookPouchGui.ScrollingFrame
    newRow.Book.Text = bookName.." by "..authorName
end)

for c in bookPouchGui.ScrollingFrame:GetChildren() do
    c.Activated:Connect(function(book)
        book = workspace.Books:FindFirstChild(book.Name)
        book.BookClick:FireServer(localPlayer)
    end)
end