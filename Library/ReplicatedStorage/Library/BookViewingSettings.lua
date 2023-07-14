local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assert = require(ReplicatedStorage.Utilities.Assert)
local Class = require(ReplicatedStorage.Utilities.Class)
local List = require(ReplicatedStorage.Utilities.List)
local ValuePointer = require(ReplicatedStorage.Utilities.ValuePointer)

local BookViewingSettings = Class.New("BookViewingSettings")
local default3D = false
BookViewingSettings.DefaultData = {
	-- ThreeD = true,
	-- TwoPage = true,
	ViewDistance = 30, -- to avoid decimals, this is stored as 10x actual value
	Public = true,
	LightMode = true,
}
BookViewingSettings.MinViewDistance = 1
BookViewingSettings.MaxViewDistance = 5

local keyToClass = {
	ThreeD = ValuePointer.Override({get = function(v) return if v == nil then default3D else v end}),
	-- TwoPage = ValuePointer,
	ViewDistance = ValuePointer.Override({
		get = function(v) return v / 10 end,
		set = function(v)
			v = math.clamp(v, BookViewingSettings.MinViewDistance, BookViewingSettings.MaxViewDistance)
			return math.floor(v * 10 + 0.5)
		end}),
	Public = ValuePointer,
	LightMode = ValuePointer,
}
local v = Assert.Validate
BookViewingSettings.keyToValidate = {
	ThreeD = v.Boolean,
	-- TwoPage = v.Boolean,
	ViewDistance = v.Number,
	Public = v.Boolean,
	LightMode = v.Boolean,
}
function BookViewingSettings.new(data)
	local self = setmetatable({
		data = data,
	}, BookViewingSettings)
	for key, class in keyToClass do
		self[key] = class.new(data, key)
	end
	return self
end
for key in keyToClass do
	BookViewingSettings["Get" .. key] = function(self)
		return self[key]:Get()
	end
	BookViewingSettings["Set" .. key] = function(self, value)
		return self[key]:Set(value)
	end
end
-- Note: client/server versions should override the instance's ValuePointer Get/Set, not BVS's Get/Set

return BookViewingSettings