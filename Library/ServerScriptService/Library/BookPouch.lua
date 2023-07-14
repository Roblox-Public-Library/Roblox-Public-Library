local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookPouch = require(ReplicatedStorage.Library.BookPouch)

local ServerScriptService = game:GetService("ServerScriptService")
local Books = require(ServerScriptService.Library.Books)
local ChangedTracker = require(ServerScriptService.Library.ChangedTracker)

ChangedTracker.ApplyToClassWithEvent(BookPouch)

local base = BookPouch.new
function BookPouch.new(data)
	local self = base(data)
	self:ForEachBookId(function(id)
		if not Books.GetBook(id) then
			self:SetInPouch(id, false)
		end
	end)
	return self
end
local base = BookPouch.SetInPouch
function BookPouch:SetInPouch(id, value)
	if base(self, id, value) then return true end
	if type(id) == "number" then
		self:RecordChanged()
	end
end
function BookPouch.InitRemotes(newRemote)
	newRemote:Event("SetInPouch", function(player, self, id, value)
		if type(value) ~= "boolean" or not Books:GetBook(id) then return end
		self:SetInPouch(id, value)
	end)
end

return BookPouch