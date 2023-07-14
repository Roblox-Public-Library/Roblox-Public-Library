-- Data Store Efficient Serialization Module
--	Converts various values into a string that can be efficiently transmitted with JSON (for instance, into data stores)
local Assert = require(game:GetService("ReplicatedStorage").Utilities.Assert)

local Serialization = {}

local function ignoreChar(n)
	return n >= 0 and n <= 31 or n == 34 or n == 92
end
local byteToChar = {}
Serialization.ByteToChar = byteToChar
local charToByte = {}
Serialization.CharToByte = charToByte
local possibilitiesPerByte = 0
for i = 0, 127 do
	if not ignoreChar(i) then
		local char = string.char(i)
		byteToChar[possibilitiesPerByte] = char
		charToByte[char] = possibilitiesPerByte
		possibilitiesPerByte += 1
	end
end

function Serialization.SerializeByte(byte)
	return byteToChar[byte] or error("Invalid byte '" .. tostring(byte) .. "'", 2)
end
function Serialization.DeserializeByte(char)
	return charToByte[char] or error("Invalid char '" .. tostring(char) .. "'", 2)
end
local logPPB = math.log(possibilitiesPerByte)
--local sevenBytes = possibilitiesPerByte ^ 7
local eightBytes = possibilitiesPerByte ^ 7 -- that is, need 8 bytes for numbers >= this value
local nineBytes = possibilitiesPerByte ^ 8
assert(possibilitiesPerByte ^ 9 > 2^53, "need to adjust this algorithm") -- if this triggers, would need to extend the above 'nineBytes' (and its usage below) to 'tenBytes' and so on, or find a better algorithm
function Serialization.SerializeUInt(num, numBytes)
	Assert.Integer(num, 0, 2^53, "num")
	numBytes = if numBytes then Assert.Integer(numBytes, 1, 9, "numBytes")
		-- the math.log equation on the next line cannot properly differentiate with numbers close to eightBytes or large and incorrectly rounds up, which is why we limit the result to 7
		elseif num < eightBytes then math.min(math.ceil(math.log(num + 1) / logPPB), 7)
		elseif num >= nineBytes then 9
		else 8
	if numBytes <= 1 then -- num == 0 -> numBytes of 0
		return Serialization.SerializeByte(num)
	end
	local s = table.create(numBytes)
	local pI = 1 -- that is, possibilitiesPerByte ^ i
	for i = 0, numBytes - 1 do
		local nextPI = pI * possibilitiesPerByte
		s[i + 1] = Serialization.SerializeByte((num % nextPI - num % pI) / pI)
		pI = nextPI
	end
	return table.concat(s)
end
function Serialization.DeserializeUInt(s)
	Assert.String(s)
	local num = 0
	for i = 1, #s do
		local n = Serialization.DeserializeByte(s:sub(i, i))
		num += n * possibilitiesPerByte ^ (i - 1)
	end
	return num
end

-- jobId (from game.JobId) is a 36 character string made up of 32 hexadecimal digits with 4 dashes at particular locations (identical format to UUID)
local t = table.create(5)
local serializeUInt = Serialization.SerializeUInt
local function serializeUUID(uuid)
	t[1] = uuid:sub(1, 8)
	t[2] = uuid:sub(10, 13)
	t[3] = uuid:sub(15, 18)
	t[4] = uuid:sub(20, 23)
	t[5] = uuid:sub(25)
	local s = table.concat(t)
	t[1] = serializeUInt(tonumber(s:sub(1, 13), 16), 8)
	t[2] = serializeUInt(tonumber(s:sub(14, 26), 16), 8)
	t[3] = serializeUInt(tonumber(s:sub(27), 16), 4)
	return table.concat(t, nil, 1, 3)
end
function Serialization.SerializeJobId(jobId) -- This can be used to condense the jobId to 20 characters instead of the original 36
	return serializeUUID(Assert.String(jobId, 36, 36, "jobId"))
end
Serialization.SerializedJobId = if game.JobId == "" then "" else Serialization.SerializeJobId(game.JobId)

local HttpService = game:GetService("HttpService")
function Serialization.GenerateGUID()
	return serializeUUID(HttpService:GenerateGUID(false))
end

do
	local jobId = if game.JobId == "" then HttpService:GenerateGUID(false) else game.JobId
	t[1] = jobId:sub(1, 8)
	t[2] = jobId:sub(10, 13)
	t[3] = jobId:sub(15, 18)
	t[4] = jobId:sub(20, 23)
	t[5] = jobId:sub(25)
	local s = table.concat(t)
	local num1 = tonumber(s:sub(1, 13), 16)
	local num2 = tonumber(s:sub(14, 26), 16)
	local num3 = tonumber(s:sub(27), 16)
	local max = possibilitiesPerByte ^ 8
	local num3Max = possibilitiesPerByte ^ 4
	local fast = {serializeUInt(num1, 8), serializeUInt(num2, 8), ""}
	function Serialization.GenerateFastGUID()
		--	Performance: Serialization.GenerateGUID() takes ~5.2x as long
		--	It works by sort of incrementing the JobId, and so should be suitable even if used across different servers (since each server should have a random JobId)
		--	Note: this can generate ids that cannot be mapped back into a GUID
		--	(If this is unacceptable, set max to 16 ^ 13 and change possibilitiesPerByte ^ 4 below to 16 ^ 6)
		num3 += 1
		if num3 == num3Max then
			num3 = 0
			num2 += 1
			if num2 == max then
				num2 = 0
				num1 = (num1 + 1) % max
				fast[1] = serializeUInt(num1, 8)
			end
			fast[2] = serializeUInt(num2, 8)
		end
		fast[3] = serializeUInt(num3, 4)
		return table.concat(fast)
	end
end

return Serialization