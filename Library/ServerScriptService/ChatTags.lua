local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local TagsList = {
    ["Helper"] = {{
        TagText = "Helper",
        TagColor = Color3.fromRGB(126, 112, 255)
    }},
    ["Veteran"] = {{
        TagText = "Veteran",
        TagColor = Color3.fromRGB(218, 0, 78)
    }},
    ["Intern"] = {{
        TagText = "Intern",
        TagColor = Color3.fromRGB(153, 45, 34)
    }},
    ["Secretary"] = {{
        TagText = "Secretary",
        TagColor = Color3.fromRGB(219, 42, 42)
    }},
    ["Librarian"] = {{
        TagText = "Librarian",
        TagColor = Color3.fromRGB(255, 136, 0)
    }},
    ["Administrative Staff"] = {{
        TagText = "Administrative Staff",
        TagColor = Color3.fromRGB(151, 0, 69)
    }},
    ["Retired Management"] = {{
        TagText = "Retired Management",
        TagColor = Color3.fromRGB(158, 105, 180)
    }},
    ["Manager Apprentice"] = {{
        TagText = "Manager Apprentice",
        TagColor = Color3.fromRGB(36, 209, 165)
    }},
    ["Library Manager"] = {{
        TagText = "Library Manager",
        TagColor = Color3.fromRGB(46, 204, 113)
    }},
    ["The Ancients"] = {{
        TagText = "The Ancients",
        TagColor = Color3.fromRGB(143, 191, 255)
    }},
    ["Master Librarian"] = {{
        TagText = "Master Librarian",
        TagColor = Color3.fromRGB(173, 27, 255)
    }},
    ["Library Overseer"] = {{
        TagText = "Library Overseer",
        TagColor = Color3.fromRGB(173, 27, 255)
    }}
}

local ChatService = require(ServerScriptService:WaitForChild("ChatServiceRunner"):WaitForChild("ChatService"))
ChatService.SpeakerAdded:Connect(function(speakerName)
    local player = Players:FindFirstChild(speakerName)
    if not player then return end
    local role = player:GetRoleInGroup(2735192)
    local tags = TagsList[role]
    if tags then
        local speaker = ChatService:GetSpeaker(speakerName)
        speaker:SetExtraData("Tags", tags)
    end
end)