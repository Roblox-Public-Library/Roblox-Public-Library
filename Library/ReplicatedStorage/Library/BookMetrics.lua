local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = require(ReplicatedStorage.Utilities)
local Event = Utilities.Event
local Serialization = require(ReplicatedStorage.Utilities.Serialization)
local	DeserializeUInt = Serialization.DeserializeUInt

local BookMetrics = {}
local dataFields = {
	"EReads", -- number of people who have Marked as Read or rated
	"Likes",
	"Pages", -- sum of number of page-pairs opened at least once for all readers
	"Open", -- number of people who have opened this book beyond the first page (since people might only open the first page in order to add the book to a list)
	"Seen", -- number of people who have opened this book and/or been shown it in a general ranking list for sufficient time
}
BookMetrics.DataFields = dataFields

local empty = {}
for _, field in dataFields do
	empty[field] = 0
end
table.freeze(empty)
local emptyByDefault = {__index = function() return empty end}
function BookMetrics.GetFromData(data)
	local processed = {}
	if data then
		for index, sId in ipairs(data.Id) do
			local id = DeserializeUInt(sId)
			local t = processed[id]
			if not t then
				t = {}
				processed[id] = t
			end
			for _, field in dataFields do
				t[field] = data[field][index]
			end
		end
	end
	return setmetatable(processed, emptyByDefault)
end
return BookMetrics