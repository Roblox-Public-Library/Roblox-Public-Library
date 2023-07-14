local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Class = require(Utilities.Class)
local Table = require(Utilities.Table)
local Sizes = require(script.Parent.Sizes)
local LightColors = require(script.Parent.Colors).Light

local Format = Class.New("Format")
local validKeys = {
	"Bold", --:bool
	"Italics", --:bool
	"Underline", --:bool
	"Strikethrough", --:bool
	"Font", --:Enum.Font or nil for default
	"Size", --:string that could index Sizes (ie "Small" or "Large") or nil for default
	"Color", --:string that could index Colors.Light/Dark OR a color code like "rgb(255,125,0)" OR nil for default
	"Stroke", -- {.Color, .Thickness, .Transparency} or nil for no stroke
	"SubOrSuperScript", --:string "Sub" / "Super" / nil
}
local sizeAffectingKeys = {"Bold", "Italics", "Font", "Size", "SubOrSuperScript"}
local sizeAffectingKeysExceptSize = {"Bold", "Italics"}
Format.SizeAffectingKeys = sizeAffectingKeys
local isBool = {
	Bold = true,
	Italics = true,
	Underline = true,
	Strikethrough = true,
}
local function isInvalidColor(value)
	return value and not LightColors[value] and not (type(value) == "string" and value:match("%(%d+ %d+ %d+%)"))
end
local function transformColor(value)
	return if value and value:sub(1, 1) == "("
		then "rgb" .. value:gsub(" ", ",")
		else value
end
local function check(key, value) -- verify values and normalize to ensure __eq will consistently work
	if isBool[key] then
		value = if value then true else nil
	elseif key == "SubOrSuperScript" then
		if value and value ~= "Sub" and value ~= "Super" then error("Invalid SubOrSuperScript value: " .. tostring(value), 3) end
	elseif key == "Size" then
		if value and (value == "Sub" or value == "Super" or not Sizes[value]) then error("Invalid size: " .. tostring(value), 3) end
		if value == "Normal" then return nil end
	elseif key == "Color" then
		if isInvalidColor(value) then error("Invalid color: " .. tostring(value), 3) end
		if LightColors[value] == LightColors.Default then return nil end
		return transformColor(value)
	elseif key == "Stroke" then
		if value then
			if type(value) ~= "table" then error("Invalid stroke value: " .. tostring(value), 3) end
			if value.Color then
				if isInvalidColor(value.Color) then error("Invalid stroke color: " .. tostring(value.Color), 3) end
				if value.Color == "Black" then
					value.Color = nil
				else
					value.Color = transformColor(value.Color)
				end
			end
			if value.Thickness then
				if type(value.Thickness) ~= "number" or value.Thickness < 1 then error("Invalid stroke thickness: " .. tostring(value.Thickness), 3) end
				if value.Thickness == 1 then
					value.Thickness = nil
				end
			end
			if value.Transparency then
				if type(value.Transparency) ~= "number" or value.Transparency < 0 or value.Transparency >= 1 then error("Invalid stroke transparency: " .. tostring(value.Transparency), 3) end
				if value.Transparency == 0 then
					value.Transparency = nil
				end
			end
		end
	end
	return value
end
function Format.new(t) -- Warning: Tables passed in for format.Stroke may have defaults added to them (in both .new and :With)
	t = t or {}
	for k, v in pairs(t) do
		t[k] = check(k, v)
	end
	return setmetatable(t, Format)
end
function Format:Set(key, value)
	self[key] = check(key, value)
end
function Format:With(key, value)
	value = check(key, value)
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
function Format:WithSizeMult(sizeKey)
	--	Returns a new format that is the same as this one but with its size multiplied by Sizes[sizeKey] (or as close to that size as possible, given that it must still be a valid size)
	local mult = Sizes[sizeKey] or error("Invalid sizeKey '" .. tostring(sizeKey) .. "'", 2)
	local targetSize = mult * (Sizes[self.Size] or 1)
	if targetSize == mult then
		return self:With("Size", sizeKey)
	end
	local bestKey, bestDist
	for key, size in Sizes do
		local dist = math.abs(size - targetSize)
		if not bestDist or dist < bestDist then
			bestDist = dist
			bestKey = key
		end
	end
	return self:With("Size", bestKey)
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
	for _, k in ipairs(validKeys) do
		local va = a[k]
		local vb = b[k]
		if va ~= vb and not (type(va) == "table" and type(vb) == "table" and Table.Equals(va, vb)) then
			return false
		end
	end
	return true
end
function Format:SizeEquals(other) -- returns true if size-affecting keys of 'self' and 'other' are the same
	for _, k in sizeAffectingKeys do
		local va = self[k]
		local vb = other[k]
		if va ~= vb and not (type(va) == "table" and type(vb) == "table" and Table.Equals(va, vb)) then
			return false
		end
	end
	return true
end
function Format:SizeEqualsBesidesSize(other) -- returns true if size-affecting keys of 'self' and 'other' are the same, but ignores keys related to TextService:GetTextSize: Font, Size, and SubOrSuperScript
	for _, k in sizeAffectingKeysExceptSize do
		local va = self[k]
		local vb = other[k]
		if va ~= vb and not (type(va) == "table" and type(vb) == "table" and Table.Equals(va, vb)) then
			return false
		end
	end
	return true
end
Format.__tostring = function(self)
	local s = {}
	for k, v in pairs(self) do
		table.insert(s,
			if isBool[k] then k
			elseif k == "SubOrSuperScript" then tostring(v) .. "script"
			elseif k == "Stroke" then string.format("Stroke:{%s,%d,%.01f}", v.Color, v.Thickness or 1, v.Transparency or 0)
			else k .. ":" .. tostring(v))
	end
	return "{" .. table.concat(s, ",") .. "}"
end
Format.Plain = table.freeze(Format.new())
return Format