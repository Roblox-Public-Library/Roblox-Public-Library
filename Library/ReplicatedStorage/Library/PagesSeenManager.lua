local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Serialization = require(ReplicatedStorage.Utilities.Serialization:Clone())
local	SerializeUInt = Serialization.SerializeUInt
local	DeserializeUInt = Serialization.DeserializeUInt

local PagesSeenManager = {}
PagesSeenManager.__index = PagesSeenManager
function PagesSeenManager.new(s)
	local self = setmetatable({
		s = s,
		num = 0,
	}, PagesSeenManager)
	if s then
		local n = 0
		for i = 1, #s do
			local charNum = DeserializeUInt(s:sub(i, i))
			for j = 0, 5 do
				if bit32.btest(charNum, 2 ^ j) then
					n += 1
				end
			end
		end
		self.num = n
	end
	return self
end
function PagesSeenManager:GetNum()
	return self.num
end
function PagesSeenManager:RecordSeenPage(i)
	local s = self.s
	local index = math.floor((i - 1) / 6) + 1
	local oldNum
	if s then
		local oldChar = s:sub(index, index)
		oldNum = if oldChar == "" then 0 else DeserializeUInt(oldChar)
	else
		oldNum = 0
	end
	local subIndex = (i - 1) % 6
	local n = 2 ^ subIndex
	local wasSeen = bit32.btest(oldNum, n)
	if wasSeen then return true end
	s = s or ""
	if #s < index then
		s ..= string.rep(SerializeUInt(0), index - #s)
	end
	s = s:sub(1, index - 1) .. SerializeUInt(oldNum + n) .. s:sub(index + 1)
	self.s = s
	self.num = (self.num or 0) + 1
end
function PagesSeenManager:GetString()
	return self.s
end
return PagesSeenManager