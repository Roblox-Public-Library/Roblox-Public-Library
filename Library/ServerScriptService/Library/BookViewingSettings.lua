local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookViewingSettings = require(ReplicatedStorage.Library.BookViewingSettings)

local ServerScriptService = game:GetService("ServerScriptService")
local ChangedTracker = require(ServerScriptService.Library.ChangedTracker)

ChangedTracker.ApplyToClassWithEvent(BookViewingSettings)
local base = BookViewingSettings.new
function BookViewingSettings.new(...)
	local self = base(...)
	for key in BookViewingSettings.keyToValidate do
		local obj = self[key]
		local base = obj.Set
		function obj.Set(...)
			if base(...) then return true end
			self:RecordChanged()
		end
	end
	return self
end

function BookViewingSettings.InitRemotes(newRemote)
	for key, validate in BookViewingSettings.keyToValidate do
		local name = "Set" .. key
		local fn = BookViewingSettings[name]
		newRemote:Event(name, function(player, self, value)
			if validate(value) == nil then return end
			fn(self, value)
		end)
	end
end

return BookViewingSettings