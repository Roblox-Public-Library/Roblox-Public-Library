local Assert = require(script.Parent.Assert)
local ObjectPool = {}
ObjectPool.__index = ObjectPool
local function none() end
local function destroy(obj) obj:Destroy() end
function ObjectPool.new(args)
	return setmetatable({
		create = Assert.Function(args.create, "function"),
		max = Assert.Integer(args.max, "number"),
		release = Assert.Function(args.release or none), -- called if keeping
		destroy = Assert.Function(args.destroy or destroy, "function?"), -- default is to destroy the object
		n = 0,
		list = {},
	}, ObjectPool)
end
function ObjectPool.ForInstance(template, max)
	return ObjectPool.new({
		create = function() return template:Clone() end,
		max = max or 5,
		release = function(obj) obj.Parent = nil end,
	})
end
function ObjectPool:Get()
	local n = self.n
	if n > 0 then
		local obj = self.list[n]
		self.list[n] = nil
		self.n = n - 1
		return obj
	end
	return self.create()
end
function ObjectPool:Release(obj)
	local n = self.n + 1
	if n <= self.max then
		self.n = n
		self.release(obj)
		self.list[n] = obj
	else
		self.destroy(obj)
	end
end
function ObjectPool:Destroy()
	local destroy = self.destroy
	for _, obj in ipairs(self.list) do
		destroy(obj)
	end
end
return ObjectPool