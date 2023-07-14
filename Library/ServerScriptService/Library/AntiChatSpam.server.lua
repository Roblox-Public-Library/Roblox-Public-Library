--[[Ideas for improvement:
-We could notify the user that their message was filtered out entirely instead of just removing it
-We should keep track of how often a message has been said by anyone (for long messages at least)
-Theoretically you can use non-ascii text to display messages; perhaps we should check for the same substring being repeated as well
-If we are confident that someone's spamming, we could go back and delete their messages from the chat history
]]
local longMessageLength = 20 -- characters
local maxLongMsgs = 3 -- max you can send before getting muted
local maxShortMsgs = 5
local timeWindow = 30 -- in seconds
local muteLength = {30, 90, math.huge} -- in seconds

local ServerScriptService = game:GetService("ServerScriptService")
--local Analytics = require(ServerScriptService.Library.Analytics)
local AntiSpamFunctions = require(ServerScriptService.Library.AntiSpamFunctions)

local AntiSpamEvent = Instance.new("RemoteEvent")
AntiSpamEvent.Name = "AntiSpamEvent"
AntiSpamEvent.Parent = game.ReplicatedStorage.Remotes

local MsgTracker = {} -- Keeps track of how many times a message was sent within the last timeWindow seconds
MsgTracker.__index = MsgTracker
function MsgTracker.new(onReset)
	return setmetatable({
		msgsSent = 0,
		onReset = onReset, -- function to run when msgsSent returns to 0
	}, MsgTracker)
end
function MsgTracker:MsgSent()
	self.msgsSent += 1
	delay(timeWindow, function()
		self.msgsSent -= 1
		if self.msgsSent == 0 then
			self.onReset()
		end
	end)
end
function MsgTracker:NumMsgsSent()
	return self.msgsSent
end

local MuteData = {}
MuteData.__index = MuteData
function MuteData.new(player)
	return setmetatable({
		player = player,
		muteCount = 0, -- number of times muted
		numMutes = 0, -- mutes that are currently active (ex could be muted by multiple sources)
		lastMsgs = {},
	}, MuteData)
end
function MuteData:IsMuted()
	return self.numMutes > 0
end
function MuteData:Mute()
	AntiSpamEvent:FireClient(self.player, true)
	if self.muteCount < #muteLength then
		self.muteCount += 1
	end
	local length = muteLength[self.muteCount]
	self.numMutes += 1
	if length < math.huge then
		delay(length, function()
			self.numMutes -= 1
			if self.player.Parent then
				AntiSpamEvent:FireClient(self.player, false)
			end
		end)
	end
end
function MuteData:CheckRepeatedMessage(message)
	local msg = message:lower():gsub("[ \t\n]", "")
	local msgTracker = self.lastMsgs[msg]
	if not msgTracker then
		msgTracker = MsgTracker.new(function()
			self.lastMsgs[msg] = nil
		end)
		self.lastMsgs[msg] = msgTracker
	end
	msgTracker:MsgSent()
	if msgTracker:NumMsgsSent() > (#msg >= longMessageLength and maxLongMsgs or maxShortMsgs) then
		self:Mute()
		--Analytics:FireCustomEvent(self.player, "MuteFromRepeatedMessage", {Time = os.time(), Message = message})
	end
end
local playerData = {} --[player] = MuteData
local Players = game:GetService("Players")
Players.PlayerAdded:Connect(function(player)
	playerData[player] = MuteData.new(player)
end)
Players.PlayerRemoving:Connect(function(player)
	playerData[player] = nil
end)

-- Override Speaker:SayMessage to prevent suspicious messages from being sent
-- Note that doing it this way may break if they update the chat scripts, but on the plus side we'll receive any chat updates automatically
local Speaker = require(game:GetService("ServerScriptService"):WaitForChild("ChatServiceRunner"):WaitForChild("Speaker"))
local methods = getmetatable(Speaker.new())
function methods:SayMessage(message, channelName, extraData)
	if self.ChatService:InternalDoProcessCommands(self.Name, message, channelName) then
		return
	end
	if not channelName then
		return
	end

	local channel = self.Channels[channelName:lower()]
	if not channel then
		return
	end

	-- Our change:
	local player = self:GetPlayer()
	if player then
		local muteData = playerData[player]
		if not muteData then return end
		if muteData:CheckRepeatedMessage(message) or muteData:IsMuted() then
			return
		end
		if AntiSpamFunctions.MsgIsSuspicious(message) then
			--Analytics:FireCustomEvent(player, "SuspiciousMessage", {Time = os.time(), Message = message})
			return
		end
	end
	-- End of our change

	local messageObj = channel:InternalPostMessage(self, message, extraData)
	if messageObj then
		pcall(function()
			self:LazyFire("eSaidMessage", messageObj, channelName)
		end)
	end

	return messageObj
end