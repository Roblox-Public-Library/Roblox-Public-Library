local Functions = {}
function Functions.DoNothing() end
function Functions.GenExport(module)
	return function(key, value, ...)
		module[key] = value
		return value, ...
	end
end
function Functions.Cache(func, cache)
	cache = cache or {}
	return function(arg)
		local value = cache[arg]
		if not value then
			value = func(arg)
			cache[arg] = value
		end
		return value
	end
end
function Functions.Cache2(func, cache)
	cache = cache or {}
	return function(arg1, arg2)
		local t = cache[arg1]
		if not t then
			t = {}
			cache[arg1] = t
		end
		local value = t[arg2]
		if not value then
			value = func(arg1, arg2)
			t[arg2] = value
		end
		return value
	end
end
function Functions.Debounce(f, waitTime)
	local db = false
	return function(...)
		if db then return end
		db = true
		f(...)
		wait(waitTime)
		db = false
	end
end
return Functions