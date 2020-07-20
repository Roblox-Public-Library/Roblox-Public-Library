local GROUP_ID = 2735192
local MIN_ROLE_TO_TRACK = 13
local WebhookURL = ""

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local playerInfo = {}

if RunService:IsStudio() then
    return
end

local function getTimestamp(epochTime)
    local currentTime = os.date("!*t", epochTime)
    return ("%.2d-%.2d-%.2dT%.2d:%.2d:%.2dZ"):format(currentTime.year, currentTime.month, currentTime.day, currentTime.hour, currentTime.min, currentTime.sec)
end

local function secondsToClock(seconds)
    if seconds <= 0 then
        return "00h 00m 00s"
    else
        local hours = string.format("%.2d", math.floor(seconds / 3600))
        local mins = string.format("%.2d", math.floor(seconds / 60 - (hours * 60)))
        local secs = string.format("%.2d", math.floor(seconds - hours * 3600 - mins * 60))
        return ("%sh %sm %ss"):format(hours, mins, secs)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player:GetRankInGroup(GROUP_ID) < MIN_ROLE_TO_TRACK then return end
    playerInfo[player] = {
        joined = os.time(),
        role = player:GetRoleInGroup(GROUP_ID),
    }
end)

Players.PlayerRemoving:Connect(function(player)
    local info = playerInfo[player]
    if not info then return end
    playerInfo[player] = nil
    local data = {
        ["embeds"] = {
            {
                ["fields"] = {
                    {
                        ["name"] = "Username",
                        ["value"] = player.Name
                    },
                    {
                        ["name"] = "Rank",
                        ["value"] = info.role
                    },
                    {
                        ["name"] = "Time Stayed",
                        ["value"] = secondsToClock(os.time() - info.joined)
                    }
                },
                ["footer"] = {
                    ["text"] = "Roblox Library 2020"
                },
                ["timestamp"] = getTimestamp()
            }
        }
    }
    local finalData = HttpService:JSONEncode(data)
    HttpService:PostAsync(WebhookURL, finalData)
end)