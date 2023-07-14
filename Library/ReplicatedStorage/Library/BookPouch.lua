local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Class = require(ReplicatedStorage.Utilities.Class)
local Event = require(ReplicatedStorage.Utilities.Event)
local List = require(ReplicatedStorage.Utilities.List)
local	setListContains = List.SetContains

local BookPouch = Class.New("BookPouch")
BookPouch.DefaultData = {}
BookPouch.MAX_IN_POUCH = 50

function BookPouch.new(data)
	return setmetatable({
		data = data,
		other = {}, -- books that have no ids are stored here
		count = #data,
		ListChanged = Event.new(), -- (id, true if added) fires whenever a book is added or removed
	}, BookPouch)
end
function BookPouch:Count() return self.count end
function BookPouch:Contains(id)
	local list = if type(id) == "number" then self.data else self.other
	return table.find(list, id)
end
function BookPouch:SetInPouch(id, value)
	local list = if type(id) == "number" then self.data else self.other
	if setListContains(list, id, value) then return true end
	self.count += if value then 1 else -1
	self.ListChanged:Fire(id, value)
end
function BookPouch:ForEachBookId(fn)
	for _, id in self.data do
		if fn(id) then break end
	end
	for _, id in self.other do
		if fn(id) then break end
	end
end
function BookPouch:IsFull()
	return self.count >= BookPouch.MAX_IN_POUCH
end

return BookPouch