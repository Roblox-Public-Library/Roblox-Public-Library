--[[Analytics - wrapper for AnalyticsService
Supports the same functions as AnalyticsService, except:
	- customData must be a table or nil (it cannot be a string/number)
	- customData will always have SessionId added to it
		(the specified player's session id, or the server's if no player was specified)
Additional API:
.PlayerAdded:Event(player)
.PlayerRemoving:Event(player)

If you intend to use Analytics, be sure to use the events above instead of Players.PlayerAdded/PlayerRemoving to ensure that the session id exists.
]]

local PRINT_STUDIO_ANALYTICS = true

local HttpService = game:GetService("HttpService")
local function newGuid()
	return HttpService:GenerateGUID(false):gsub("-", "")
end

local serverSessionId = newGuid()
local playerSessionId = {} --[player] = guid

local Analytics = {}

local Players = game:GetService("Players")

local playerAdded = Instance.new("BindableEvent")
Analytics.PlayerAdded = playerAdded.Event
Players.PlayerAdded:Connect(function(player)
	playerSessionId[player] = newGuid()
	playerAdded:Fire(player)
end)

local playerRemoving = Instance.new("BindableEvent")
Analytics.PlayerRemoving = playerRemoving.Event
Players.PlayerRemoving:Connect(function(player)
	playerRemoving:Fire(player)
	playerSessionId[player] = nil
end)

local isStudio = game:GetService("RunService"):IsStudio()
Analytics.Enabled = not isStudio
local genHandler
if false and isStudio then
	genHandler = PRINT_STUDIO_ANALYTICS
		and function(name) return function(...) print("Analytics." .. name, ...) end end
		or function() return function() end end
else
	local AnalyticsService = game:GetService("AnalyticsService")
	genHandler = function(name)
		local action = AnalyticsService[name]
		return function(...)
			action(AnalyticsService, ...)
		end
	end
end
-- Wrap each AnalyticsService function so that custom data can be mutated to automatically include the relevant session id
local handle = {}
for _, name in ipairs({"FireCustomEvent", "FireInGameEconomyEvent", "FireLogEvent", "FirePlayerProgressionEvent"}) do
	handle[name] = genHandler(name)
end
local function setup(name, mutateArgs)
	local handler = genHandler(name)
	Analytics[name] = function(self, ...)
		handler(mutateArgs(...))
	end
end
local function handleCustomData(player, customData)
	customData = customData or {}
	if type(customData) ~= "table" then error("customData must be a table", 4) end
	customData.SessionId = player and playerSessionId[player] or serverSessionId
	return customData
end
setup("FireCustomEvent", function(player, eventCategory, customData)
	return player, eventCategory, handleCustomData(player, customData)
end)
setup("FireInGameEconomyEvent", function(player, itemName, economyAction, itemCategory, amount, currency, location, customData)
	return player, itemName, economyAction, itemCategory, amount, currency, location, handleCustomData(player, customData)
end)
setup("FireLogEvent", function(player, logLevel, message, debugInfo, customData)
	return player, logLevel, message, debugInfo, handleCustomData(customData)
end)
setup("FirePlayerProgressionEvent", function(player, category, progressionStatus, location, statistics, customData)
	return player, category, progressionStatus, location, statistics, handleCustomData(customData)
end)
return Analytics