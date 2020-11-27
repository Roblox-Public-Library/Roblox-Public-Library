-- todo delete this & tests and just use ObjectPool?
local Category = {
	Limit = 10, -- limit of # objects in a pool
}
Category.__index = Category
function Category.new(init, limit, onRelease)
	--	init: either the class name of the instance to create or a creation function
	--	limit (optional): use this to override the maximum number of objects in the pool
	--	onRelease (optional): what to do when the object is released (default is to deparent the object)
	--	Note that an object is destroyed if it's no longer needed
	return setmetatable({
		Init = type(init) == "string" and function() return Instance.new(init) end or init,
		Limit = limit or Category.Limit,
		OnRelease = onRelease or function(obj) obj.Parent = nil end,
	}, Category)
end

local ObjManager = {
	Category = Category,
}
ObjManager.__index = ObjManager
function ObjManager.new()
	--	Maintains object pools for categories of objects
	return setmetatable({
		pools = {}, --[category] = List
		objToCategory = {},
		categoryToObjs = {}, --[category] = List of all created objects, even when not stored here
	}, ObjManager)
end
function ObjManager:Get(category)
	--	Get or create a new object for the specified category
	--	NOTE: DO NOT CALL DESTROY ON THE RETURNED OBJECT unless you call :DestroyCategory first
	--	It is expected that you :Release the object when you are done with it
	local pool = self.pools[category]
	if not pool then
		pool = {}
		self.pools[category] = pool
	end
	local n = #pool
	if n > 0 then
		local obj = pool[n]
		pool[n] = nil
		return obj
	else
		local obj = category.Init()
		self.objToCategory[obj] = category
		return obj
	end
end
function ObjManager:Release(obj)
	local category = self.objToCategory[obj] or error("obj was not created from this ObjManager", 2)
	local pool = self.pools[category]
	local n = #pool
	if n >= category.Limit then
		obj:Destroy()
		self.objToCategory[obj] = nil
	else
		category.OnRelease(obj)
		pool[n + 1] = obj
	end
end
function ObjManager:DestroyCategory(category, destroyExternalAsWell)
	--	Destroys all stored objects for a particular category
	--	Only if destroyExternalAsWell will this also destroy objects retrieved from :Get that haven't been returned by :Release
	local objs = self.categoryToObjs[category]
	self.categoryToObjs[category] = nil
	for _, obj in ipairs(self.pools[category]) do
		obj:Destroy()
		self.objToCategory[obj] = nil
		objs[obj] = nil
	end
	self.pools[category] = nil
	if destroyExternalAsWell then
		for obj in pairs(objs) do
			obj:Destroy()
		end
	end
end
function ObjManager:Destroy()
	for category, pool in pairs(pools) do
		self:DestroyCategory(category)
	end
end
return ObjManager