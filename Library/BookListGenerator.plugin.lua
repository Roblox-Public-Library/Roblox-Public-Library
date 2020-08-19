local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local toolbar = plugin:CreateToolbar("Book List Generator")
local generateListButton =
    toolbar:CreateButton(
    "Generate Book List",
    "Generate's the book list for the current place.",
    "rbxassetid://450550796"
)

function generateBookList()
    local function startsWith(str, find)
        return str:find("^" .. find) ~= nil
    end

    local function trim(str)
        return (str:gsub("^%s*(.-)%s*$", "%1"))
    end

    local bookListScript = ServerStorage:FindFirstChild("BookList")

    if not bookListScript then
        local bookListScript = Instance.new("Script")
        bookListScript.Name = "BookList"
        bookListScript.Parent = ServerStorage
    end

    bookListScript = ServerStorage.BookList

    ChangeHistoryService:SetWaypoint("Started writing to BookList.lua")

    bookListScript.Source = "--[[\n"

    local output = {"--[[\n"}
    local n = 1

    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Script") and obj.Name == "BookEventScript(This is what you edit. Edit nothing else.)" then
            local title
            local author

            local source = obj.Source:split("\n")

            for i, v in pairs(source) do
                if startsWith(v, "local title =") then
                    title = v:split("local title =")
                else
                    if startsWith(v, "local authorName =") then
                        author = v:split("local authorName =")
                    end
                end
            end

            local skipIteration = false

            for i, v in pairs(output) do
                if v == ("%s by %s\n"):format(trim(title[2]), trim(author[2])) then
                    skipIteration = true
                end
            end

            if skipIteration then
                continue
            end

            n = n + 1
            output[n] = ("%s by %s\n"):format(trim(title[2]), trim(author[2]))
        end
    end

    n = n + 1
    output[n] = "]]--"
    bookListScript.Source = table.concat(output)

    ChangeHistoryService:SetWaypoint("Finished writing to BookList.lua")
end

generateListButton.Click:Connect(generateBookList)
