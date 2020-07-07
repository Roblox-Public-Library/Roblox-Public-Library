local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ListSet = require(ReplicatedStorage.ListSet)

local SaveableSet = setmetatable({}, ListSet)
SaveableSet.__index = SaveableSet

local function toSet(list)
	local set = {}
	for _, v in ipairs(list) do
		set[v] = true
	end
	return set
end
-- local function merge(lastRead, cur, newRead)
-- 	local new = {}
-- 	for k, v in pairs(cur) do
-- 		-- If it's in lastRead, only keep it if it's still in newRead
-- 		-- If it isn't in lastRead, it's been added so it doesn't matter if it's in newRead or not
-- 		if (not lastRead[k]) or newRead[k] then
-- 			new[k] = true
-- 		end
-- 	end
-- 	for k, v in pairs(newRead) do
-- 		-- Note: we don't need to check cur[k] because it would already have been dealt with if it existed
-- 		if not lastRead[k] then -- added
-- 			new[k] = true
-- 		end
-- 	end
-- 	return new
-- end

for _, name in ipairs({"new", "FromList"}) do
	local base = SaveableSet[name]
	SaveableSet[name] = function(...)
		local self = base(...)
		setmetatable(self, SaveableSet)
		self.lastSet = toSet(self.List)
		return self
	end
end
function SaveableSet:Serialize()
	return self.List
end
SaveableSet.Deserialize = SaveableSet.FromList
function SaveableSet:MergeData(newData)
	--	Meant for UpdateAsync calls. Merges the latest information read from the data store with the existing information.
	--	Be sure to call UpdateLastData once the save is confirmed (with the data saved).
	-- for each thing in lastRead, delete it from cur if not in newData
	-- for each thing in newData, add it to cur if not in lastRead
	local newSet = toSet(newData)
	local lastSet = self.lastSet
	for k, v in pairs(lastSet) do
		if not newSet[k] then
			self:Remove(k)
		end
	end
	for k, v in pairs(newSet) do
		if not lastSet[k] then
			self:Add(k)
		end
	end
	-- Note: Merge can be called in UpdateAsync, which can fail, so we can't update lastSet here
end
function SaveableSet:UpdateLastData(savedData)
	self.lastSet = toSet(savedData)
end
return SaveableSet