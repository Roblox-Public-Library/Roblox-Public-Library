local ServerScriptService = game:GetService("ServerScriptService")
local Genres = require(ServerScriptService.Library.Genres)
local floors = {"Floor 1", "Floor 2", "Floor 3"}

local conversions = {
    ["Money/Economy"] = "Economy",
}

for _, floor in ipairs(floors) do
    for _, shelf in ipairs(workspace["Hall D"][floor].Shelves:GetChildren()) do
        for _, genreTextLabel in ipairs(shelf:GetDescendants()) do
            if genreTextLabel:IsA("TextLabel") then
                local genreLabel = ("%s %s"):format("Roblox", conversions[genreTextLabel.Text] or genreTextLabel.Text)
                local newGenreLabel = Genres.InputToGenre(genreLabel)
                if newGenreLabel and newGenreLabel ~= genreTextLabel.Text then
                    genreTextLabel.Text = genreLabel
                end
            end
        end
    end
end