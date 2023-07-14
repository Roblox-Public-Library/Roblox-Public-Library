local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tutorial = require(ReplicatedStorage.Library.Tutorial)
local Event = require(ReplicatedStorage.Utilities.Event)
local remotes = ReplicatedStorage.Remotes.Tutorial

function Tutorial:ConsiderShow(action, fn)
	if self:ShouldShow(action) then
		fn()
		self:RecordShown(action)
		remotes.Shown:FireServer(action)
	end
end
local base = Tutorial.new
function Tutorial.new(...)
	local self = base(...)
	self.AllReset = Event.new()
	return self
end
local base = Tutorial.ResetAll
function Tutorial:ResetAll()
	base(self)
	remotes.ResetAll:FireServer()
	self.AllReset:Fire()
end

return Tutorial