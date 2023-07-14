local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profile = require(ReplicatedStorage.Library.Profile)
local Event = require(ReplicatedStorage.Utilities.Event)
local Table = require(ReplicatedStorage.Utilities.Table)

local components_serializers = Profile.components_serializers
local components_asIs = Profile.components_asIs
local components_all = {}
for k, v in components_serializers do components_all[k] = v end
for k, v in components_asIs do components_all[k] = v end
function Profile:HasChanges()
	for k in components_all do
		if self[k]:HasChanges() then return true end
	end
end
function Profile:RecordSaved(saveTime) -- saveTime from os.clock
	for k in components_all do
		self[k]:RecordSaved(saveTime)
	end
end
function Profile:Serialize()
	local data = self.data
	-- components_asIs have kept 'data' up-to-date
	for k in components_serializers do
		data[k] = self[k]:Serialize()
	end
	return data
end
function Profile.DeserializeDataStore(data, player)
	if not data then return Profile.new(player) end
	local self = setmetatable({
		data = data,
		player = player,
	}, Profile)
	for k, class in components_asIs do
		data[k] = Table.ApplyClonedDefaults(data[k], class.DefaultData)
		self[k] = class.new(data[k], self)
	end
	for k, class in components_serializers do
		local v = data[k]
		if v ~= nil then
			self[k] = (class.DeserializeDataStore or class.Deserialize)(v, self)
		else
			self[k] = class.new(self)
		end
	end
	return self
end
-- Ensure what whenever a Profile's component changes, it'll fire a Changed event
for _, name in {"new", "Deserialize", "DeserializeDataStore"} do
	local base = Profile[name]
	Profile[name] = function(...)
		local self = base(...)
		self.Changed = Event.new()
		local function fire()
			self.Changed:Fire()
		end
		for k in components_all do
			local e = self[k].Changed
			if e then
				e:Connect(fire)
			end
		end
		return self
	end
end
return Profile