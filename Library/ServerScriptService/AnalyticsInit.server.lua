local serverStartTime = os.clock()
local Analytics = require(script.Parent.Analytics)
Analytics:FireCustomEvent(nil, "ServerStart", {Time = os.time()})

local joinTime = {} --[player] = os.clock
Analytics.PlayerAdded:Connect(function(player)
	local startTime = os.clock()
	joinTime[player] = startTime
	player.Chatted:Connect(function(msg)
		Analytics:FireCustomEvent(player, "PlayerChatted", {
			Time = os.time(),
			RelTime = os.clock() - startTime,
		})
	end)
end)
Analytics.PlayerRemoving:Connect(function(player)
	Analytics:FireCustomEvent(player, "PlayerLeft", {
		OnlineFor = os.clock() - joinTime[player],
	})
	joinTime[player] = nil
end)
game:BindToClose(function()
	Analytics:FireCustomEvent(nil, "ServerOffline", {
		OnlineFor = os.clock() - serverStartTime,
	})
end)