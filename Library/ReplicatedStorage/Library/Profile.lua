local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local Functions = require(Utilities.Functions)
local Music = require(ReplicatedStorage.Library.Music)
local Tutorial = require(ReplicatedStorage.Library.Tutorial)
local BookPouch = require(ReplicatedStorage.Library.BookPouch)
local BooksProfile = require(ReplicatedStorage.Library.BooksProfile)
local BookViewingSettings = require(ReplicatedStorage.Library.BookViewingSettings)
local SearchProfile = require(ReplicatedStorage.Library.SearchProfile)
local Table = require(ReplicatedStorage.Utilities.Table)

local Profile = {}
Profile.__index = Profile
--[[To create a new component:
- Create these versions:
	RS/Library/Component
		contains the common code
	RS/Library/ComponentClient
		must use remotes
	SSS/Library/Component
		must InitRemotes
- Optionally create a Gui script for it
- Add to one of the components classes below
- Add to nameOverrides if required
]]
-- Note: ideally components_serializers would be rewritten into components_asIs
--[[All component classes below must (on server versions) have:
	:HasChanges() -- true if data should be autosaved
	:RecordSaved(saveTime)
	.Changed -- fires when HasChanges becomes true
]]
local components_serializers = {
	--[[field -> component Class that uses Serialize/Deserialize
		.new()
		.Deserialize(data)
		Server versions must also have...
		:Serialize() -> data for data store / replication
		.DeserializeDataStore(data) [optional]
	]]
	Music = Music,
}
local components_asIs = {
	--[[field -> Class that maintains data-store-ready data
		.new(data) -- 'data' from the data stores. This data can be sent to the data store, so it must be kept in a ready-to-replicate state at all times.
		.DefaultData -- the 'data' passed to 'new' will have these values by default (with any tables being deep cloned). Existing data will have these fields merged in (to allow for updates to the data).
	]]
	Books = BooksProfile,
	BookViewingSettings = BookViewingSettings,
	BookPouch = BookPouch,
	Search = SearchProfile,
	Tutorial = Tutorial,
}
Profile.components_serializers = components_serializers
Profile.components_asIs = components_asIs
do -- moduleToKey
	local nameOverrides = {
		Books = "BooksProfile",
		Search = "SearchProfile",
	}
	local mtk = {}
	Profile.moduleToKey = mtk -- [module] = profileKey
	for k in components_asIs do
		mtk[nameOverrides[k] or k] = k
	end
	for k in components_serializers do
		mtk[nameOverrides[k] or k] = k
	end
end
function Profile.new(player)
	local data = {}
	local self = setmetatable({
		data = data,
		player = player,
	}, Profile)
	for k, class in components_asIs do
		data[k] = Table.DeepClone(class.DefaultData)
		self[k] = class.new(data[k], self)
	end
	for k, class in components_serializers do
		self[k] = class.new(self)
	end
	return self
end
function Profile.Deserialize(data, player)
	if not data then return Profile.new(player) end
	local self = setmetatable({
		data = data,
		player = player,
	}, Profile)
	for k, class in components_asIs do
		self[k] = class.new(data[k], self)
	end
	for k, class in components_serializers do
		local v = data[k]
		if v ~= nil then
			self[k] = class.Deserialize(v, self)
		else
			self[k] = class.new(self)
		end
	end
	return self
end
function Profile:Destroy()
	for k, v in self do
		if type(v) == "table" and v.Destroy then
			v:Destroy()
		end
	end
end
function Profile:MarkTemporary(reason)
	self.data.Temporary = reason or true
end
function Profile:IsTemporary() -- returns reason or false. If truthy, the profile will not be saved to the data store
	return self.data.Temporary
end
return Profile