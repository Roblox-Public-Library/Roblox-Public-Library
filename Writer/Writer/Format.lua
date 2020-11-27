local Format = {}
Format.__index = Format
function Format.new(t)
	--[[Valid keys:
	Bold:bool
	Italics:bool
	Underline:bool
	Strikethrough:bool
	Face:string that could index Enum.Font or nil for default
	Size:string that could index Sizes (ie "Small" or "Large") or nil for default
	Color:string that could index Colors.Light/Dark or nil for default
	]]
	t = t or {}
	for _, bool in ipairs({"Bold", "Italics", "Underline", "Strikethrough"}) do
		t[bool] = t[bool] or false
	end
	return setmetatable(t, Format)
end
function Format:With(key, value)
	if self[key] == value then return self end
	local new = {[key] = value}
	for k, v in pairs(self) do
		if k ~= key then
			if typeof(v) == "table" and v.Clone then
				new[k] = v:Clone()
			else
				new[k] = v
			end
		end
	end
	return setmetatable(new, getmetatable(self))
end
function Format:Clone()
	local new = {}
	for k, v in pairs(self) do
		if typeof(v) == "table" and v.Clone then
			new[k] = v:Clone()
		else
			new[k] = v
		end
	end
	return setmetatable(new, getmetatable(self))
end
Format.__eq = function(a, b)
	for k, v in pairs(a) do
		if v ~= b[k] then
			return false
		end
	end
	return true
end
return Format