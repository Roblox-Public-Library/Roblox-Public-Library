local ObjectPool = {}
ObjectPool.__index = ObjectPool
function ObjectPool.new(generator, max)
	return setmetatable({
		generator = generator,
		max = max,
		n = 0,
		list = {},
	}, ObjectPool)
end
function ObjectPool:Get()
	local n = self.n
	if n > 0 then
		local obj = self.list[n]
		self.list[n] = nil
		self.n = n - 1
		return obj
	end
	return self.generator()
end
function ObjectPool:Release(obj)
	local n = self.n + 1
	if n <= self.max then
		self.n = n
		self.list[n] = obj
	else
		obj:Destroy()
	end
end
function ObjectPool:Destroy()
	for _, obj in ipairs(self.list) do
		obj:Destroy()
	end
end
return ObjectPool