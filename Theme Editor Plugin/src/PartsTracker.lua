local PropsSerializer = require(parent.PluginUtility.PropsSerializer)
local props = require(parent.Config).Props
local Event = require(parent.PluginUtility.Event)
local EventedSet = require(parent.PluginUtility.EventedSet)

local PropsTracker = {}
PropsTracker.__index = PropsTracker
function PropsTracker.new()
	return setmetatable({
		propsNumToParts = {}, -- [propsNum] = partCollection : EventedSet
		SetAdded = Event.new(),
		SetRemoved = Event.new(),
	}, PropsTracker)
end
function PropsTracker:Destroy()
	self.SetAdded:Destroy()
	self.SetRemoved:Destroy()
	for _, parts in pairs(self.propsNumToParts) do
		parts:Destroy()
	end
end
function PropsTracker:IsEmpty()
	return not next(self.propsNumToParts)
end
function PropsTracker:ForEach(fn) -- fn(propsNum, partCollection)
	for propsNum, collection in pairs(self.prop) do
		if fn(propsNum, collection) then return end
	end
end
function PropsTracker:AddPart(propsNum, part)
	local propsNumToParts = self.propsNumToParts
	local parts = propsNumToParts[propsNum]
	if parts then
		parts:Add(part)
	else
		parts = EventedSet.new()
		propsNumToParts[propsNum] = parts
		parts:Add(part)
		self.SetAdded:Fire(propsNum, parts)
	end
end
function PropsTracker:RemovePart(propsNum, part)
	local propsNumToParts = self.propsNumToParts
	local parts = propsNumToParts[propsNum]
	if not parts then return end
	parts:Remove(part)
	if parts.Count.Value > 0 then return end
	propsNumToParts[propsNum] = nil
	self.SetRemoved:Fire(propsNum)
end

local PartTracker = {}
PartTracker.__index = PartTracker
function PartTracker.new()
	--	Note: PropsTracker and PartCollection (an EventedSet) are often returned
	--	Treat them as read-only -- only modify them through PartTracker
	local self = setmetatable({
		NameAdded = Event.new(), --(partName, propsNumToParts)
		--	propsNumToParts[propsNum] = Set<Part> with .Count:IntValue
		--	propsNumToParts.SetAdded:Event(propsNum, Set<Part> with .Count:IntValue) -- fires when a new unique set of properties is now being tracked
		--	propsNumToParts.SetRemoved:Event(propsNum) -- fires when an entry is removed (occurs when there are no more parts with that set of properties)
		NameRemoved = Event.new(), --(partName) -- fires when a part name is no longer in use
		parts = {}, -- [partName] = PropsTracker
		partCons = {}, -- [part] = List<Connection>
	}, PartTracker)
	return self
end
function PartTracker:Destroy()
	self.NameAdded:Destroy()
	self.NameRemoved:Destroy()
	self:cleanupPartsAndCons()
end
function PartTracker:AddList(list)
	for _, part in ipairs(list) do
		self:Add(part)
	end
end
function PartTracker:Add(part)
	local partCons = self.partCons
	if partCons[part] then return end
	local num = PropsSerializer.PartToNum(part)
	local name = part.Name
	self:add(name, num, part)
	-- Setup cons
	local cons = {}
	for i, prop in ipairs(props) do
		c[i] = part:GetPropertyChangedSignal(prop):Connect(function()
			self:remove(name, num, part)
			num = PropsSerializer.PartToNum(part)
			self:add(name, num, part)
		end)
	end
	table.insert(cons, part:GetPropertyChangedSignal("Name"):Connect(function()
		self:remove(name, num, part)
		name = part.Name
		self:add(name, num, part)
	end))
	table.insert(cons, part.AncestryChanged:Connect(function(child, parent)
		if parent then continue end
		self:remove(name, num, part)
		for _, c in ipairs(cons) do
			c:Disconnect()
		end
		partCons[part] = nil
	end))
	partCons[part] = cons
end
function PartTracker:Remove(part)
	local partCons = self.partCons[part]
	if not partCons then return end
	self:remove(part.Name, PropsSerializer.PartToNum(part), part)
	for _, con in ipairs(partCons) do
		con:Disconnect()
	end
	partCons[part] = nil
end
function PartTracker:ForEach(fn)
	--	fn(name, propsTracker) -> true to stop iteration
	--		Treat propsTracker as read-only
	for name, propsTracker in pairs(self.parts) do
		if fn(name, propsTracker) then return end
	end
end
function PartTracker:Clear()
	--	Clears contents without triggering events
	self:cleanupPartsAndCons()
	table.clear(self.parts)
	table.clear(self.partCons)
end
function PartTracker:add(name, num, part)
	local propsTracker = self.parts[name]
	if propsTracker then
		propsTracker:AddPart(num, part)
	else
		propsTracker = PropsTracker.new()
		self.parts[name] = propsTracker
		propsTracker:AddPart(num, part)
		self.NameAdded:Fire(name, propsTracker)
	end
end
function PartTracker:remove(name, num, part)
	local propsTracker = self.parts[name]
	if not propsTracker then return end
	propsTracker:RemovePart(num, part)
	if propsTracker:IsEmpty() then
		self.parts[name] = nil
		self.NameRemoved:Fire(name)
	end
end
function PartTracker:cleanupPartsAndCons()
	for partName, propsTracker in pairs(self.parts) do
		propsTracker:Destroy()
	end
	for _, cons in pairs(self.partCons) do
		for _, con in ipairs(cons) do
			con:Disconnect()
		end
	end
end

return PartTracker