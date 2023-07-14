local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookViewingSettings = require(ReplicatedStorage.Library.BookViewingSettings)

local remotes = ReplicatedStorage.Remotes.BookViewingSettings

local base = BookViewingSettings.new
function BookViewingSettings.new(...)
	local self = base(...)
	for key in BookViewingSettings.keyToValidate do
		local obj = self[key]
		local base = obj.Set
		local remote = remotes["Set" .. key]
		function obj.Set(obj, value)
			if base(obj, value) then return true end
			remote:FireServer(value)
		end
	end
	return self
end

return BookViewingSettings