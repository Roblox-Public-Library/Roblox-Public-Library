local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.localPlayer

ReplicatedStorage.RemotesBookOpen:OnClientEvent(function (book)
    local bookName = book.Name
    local authorName = book.Author
    local BookPouchGui = localPlayer.PlayerGui.BookPouchGui
    local TextButton = Instance.new("TextButton")
    TextButton.Parent = BookPouchGui.ScrollingFrame
    TextButton.Text = bookName + " by " + authorName
    TextButton.BackgroundColor = Color3.fromRGB(255, 170, 12)
    TextButton.Font = Enum.Font.SourceSansItalic
    TextButton.TextScaled = true
end)
