local Format = {}
Format.__index = Format
function Format.new(t)
	return setmetatable(t or {}, Format)
end
local function valuesEqualIgnoreFalse(a, b)
	return a == b or (not a and not b)
end
function Format:With(key, value)
	if valuesEqualIgnoreFalse(self[key], value) then return self end
	local new = self:Clone()
	new[key] = value
	return new
end
function Format:Clone()
	local new = {}
	for k, v in pairs(self) do
		new[k] = v
	end
	return Format.new(new)
end
Format.__eq = function(a, b)
	for k, v in pairs(a) do
		if not valuesEqualIgnoreFalse(v, b[k]) then
			return false
		end
	end
	return true
end
return Format