local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Class = require(ReplicatedStorage.Utilities.Class)
local Event = require(ReplicatedStorage.Utilities.Event)

local CancellationToken = Class.New("CancellationToken")
function CancellationToken.new()
	return setmetatable({
		Cancelled = Event.new(), -- note: can be nil if alredy cancelled. If unsure, use OnCancelled.
	}, CancellationToken)
end
function CancellationToken.ShouldCancel() return false end -- (overridden when cancelled) -- can be used to pass to a function expecting a 'shouldCancel' argument
local function returnTrue() return true end
function CancellationToken:IsCancelled() return not self.Cancelled end
function CancellationToken:Cancel()
	if not self.Cancelled then return end -- already cancelled
	local cancelled = self.Cancelled
	self.Cancelled = nil
	self.ShouldCancel = returnTrue
	cancelled:Fire()
	cancelled:Destroy()
end
function CancellationToken:Destroy()
	if self.Cancelled then
		self.Cancelled:Destroy()
	end
end
function CancellationToken:OnCancelled(fn)
	if self.Cancelled then
		self.Cancelled:Connect(fn)
	else
		task.spawn(fn)
	end
end

return CancellationToken