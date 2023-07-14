local Utilities = require(script.Parent.Utilities)

local Functions = {}
function Functions.DoNothing() end
function Functions.GenExport(module)
	return function(key, value, ...)
		module[key] = value
		return value, ...
	end
end
function Functions.Cache(fn, cache)
	cache = cache or {}
	return function(arg)
		local value = cache[arg]
		if not value then
			value = fn(arg)
			cache[arg] = value
		end
		return value
	end
end
function Functions.Cache2(fn, cache)
	cache = cache or {}
	return function(arg1, arg2)
		local t = cache[arg1]
		if not t then
			t = {}
			cache[arg1] = t
		end
		local value = t[arg2]
		if not value then
			value = fn(arg1, arg2)
			t[arg2] = value
		end
		return value
	end
end
function Functions.Debounce(fn, waitTime)
	local db = false
	return function(...)
		if db then return end
		db = true
		Utilities.xpcall(fn, ...)
		if waitTime then
			task.wait(waitTime)
		end
		db = false
	end
end
function Functions.DeferWithDebounce(fn)
	local db = false
	return function(...)
		if db then return end
		db = true
		task.defer(coroutine.running())
		coroutine.yield()
		Utilities.xpcall(fn, ...)
		db = false
	end
end
function Functions.Defer(fn)
	return function(...)
		task.defer(coroutine.running())
		coroutine.yield()
		fn(...)
	end
end
return Functions