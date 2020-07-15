local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.localPlayer
local bookPouchGui = localPlayer.PlayerGui.BookPouchGui

ReplicatedStorage.BookOpen:OnClientEvent(function (book)
    local bookName = book.Name
    local authorName = book.Author
    local textButton = Instance.new("textButton")
    textButton.Parent = bookPouchGui.ScrollingFrame
    textButton.Text = bookName + " by " + authorName
    textButton.BackgroundColor = Color3.fromRGB(255, 170, 12)
    textButton.Font = Enum.Font.SourceSansItalic
    textButton.TextScaled = true
end)

for c in bookPouchGui.ScrollingFrame:GetChildren() do
    c.Activated:Connect(function(book)

    end)
end