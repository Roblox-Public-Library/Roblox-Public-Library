local RunService = game:GetService("RunService")

if RunService:IsStudio() or game.PrivateServerOwnerId ~= 0 then
	return
end

local GROUP_ID = 2735192
local RANKS_TO_TRACK = {
	100,
	101,
	102,
	103,
	200,
	250,
	252,
	253,
	254,
	255
}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local playerInfo = {}

Players.PlayerAdded:Connect(function(player)
	if not table.find(RANKS_TO_TRACK, player:GetRankInGroup(GROUP_ID)) then return end
	playerInfo[player.UserId] = os.time()
end)

Players.PlayerRemoving:Connect(function(player)
	local info = playerInfo[player.UserId]
	if not info then return end
	playerInfo[player.UserId] = nil
	local payload = {
		["PlayerId"] = tostring(player.UserId),
		["JoinTime"] = tostring(info),
		["LeaveTime"] = tostring(os.time()),
		["Username"] = tostring(player.Name),
		["DisplayName"] = tostring(player.DisplayName),
		["Rank"] = tostring(player:GetRoleInGroup(GROUP_ID))
	}
	local payloadJson = HttpService:JSONEncode(payload)
	local success, err = pcall(function()
		return HttpService:RequestAsync(
			{
				["Url"] = "https://dyga35t7cc.execute-api.us-west-2.amazonaws.com/dev/activity-logs",
				["Method"] = "POST",
				["Headers"] = {
					["Content-Type"] = "application/json"
				},
				["Body"] = payloadJson
			}
		)
	end)
end)