local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Class = require(ReplicatedStorage.Utilities.Class)
local Assert = require(ReplicatedStorage.Utilities.Assert)
local ObjectList = Class.New("ObjectList") -- A list of reusable objects that may contain connections.
function ObjectList.new(init, maxItemsToStore, storeFunc)
	--	init:function(i):object, con/List<con> to be disconnected when the object is destroyed
	--	maxItemsToStore:int = 0. If the list to adapt to has no elements, will call 'storeFunc' on this many items instead of destroying them.
	--	storeFunc:function(obj) -- what to do to get rid of 'obj' without destroying it. Defaults to deparenting 'obj'.
	maxItemsToStore = maxItemsToStore or 0
	return setmetatable({
		init = init,
		list = {},
		cons = {},
		maxItemsToStore = Assert.Integer(maxItemsToStore, 0),
		storeFunc = storeFunc or function(obj) obj.Parent = nil end,
	}, ObjectList)
end
function ObjectList:get(i)
	local list = self.list
	local value = list[i]
	if not value then
		value, self.cons[i] = self.init(i)
		list[i] = value
	end
	return value
end
function ObjectList:destroy(i)
	self.list[i]:Destroy()
	self.list[i] = nil
	local cons = self.cons[i]
	self.cons[i] = nil
	if cons then
		if cons.Disconnect then
			cons:Disconnect()
		else
			for _, con in ipairs(cons) do
				con:Disconnect()
			end
		end
	end
end
function ObjectList:destroyRest(startIndex)
	for i = startIndex, #self.list do
		self:destroy(i)
	end
end
function ObjectList:Count() return #self.list end
function ObjectList:SetAdaptFunc(adaptObject)
	self.adaptObject = Assert.Function(adaptObject)
end
function ObjectList:AdaptToList(newList, adaptObjectOverride)
	--	Create or reuse an object for each item in newList using adaptObject(object, item) to adapt them
	--	Will store or destroy the remaining objects based on the maxItemsToStore from the constructor
	local numNewList = newList and #newList or 0
	if numNewList > 0 then
		local adaptObject = Assert.Function(adaptObjectOverride or self.adaptObject)
		for i, item in ipairs(newList) do
			adaptObject(self:get(i), item)
		end
	end
	local list = self.list
	for i = numNewList + 1, math.min(self.maxItemsToStore, #list) do
		self.storeFunc(list[i])
	end
	self:destroyRest(math.max(self.maxItemsToStore + 1, numNewList + 1))
end
function ObjectList:EmptyList()
	self:AdaptToList()
end
function ObjectList:ForEach(func, startIndex)
	local list = self.list
	for i = startIndex or 1, #list do
		if func(i, list[i]) then break end
	end
end
function ObjectList:Destroy()
	self:destroyRest(1)
end
return ObjectList