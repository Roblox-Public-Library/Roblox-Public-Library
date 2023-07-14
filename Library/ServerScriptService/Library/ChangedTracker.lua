local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Class = require(ReplicatedStorage.Utilities.Class)
local ChangedTracker = Class.New("ChangedTracker")
function ChangedTracker.new()
	return setmetatable({
		lastModified = 0, -- os.clock()
		lastSaved = 0, -- os.clock()
	}, ChangedTracker)
end
function ChangedTracker:HasChanges()
	return self.lastSaved < self.lastModified
end
function ChangedTracker:RecordChanged()
	self.lastModified = os.clock()
end
function ChangedTracker:RecordSaved(saveTime)
	self.lastSaved = saveTime or error("saveTime mandatory (from os.clock() at time save data was submitted)", 2)
end

local Event = require(ReplicatedStorage.Utilities.Event)
function ChangedTracker.ApplyToClassWithEvent(class, fnNamesForChange)
	--	If you need to mark something as changed, use class:RecordChanged()
	--	Call this *before* overriding new/Deserialize/DeserializeDataStore if you may wish to use :RecordChanged or .Changed in the function
	--	fnNamesForChange: list of functions; each must return true to indicate "no change"
	-- No matter how it's constructed, make sure it gets a 'changes' variable and Changed event
	for _, name in {"new", "Deserialize", "DeserializeDataStore"} do
		local base = class[name]
		if not base then continue end
		class[name] = function(...)
			local self = base(...)
			self.changes = ChangedTracker.new()
			self.Changed = Event.new()
			return self
		end
	end
	local base = class.Destroy
	function class:Destroy()
		if base then
			base(self)
		end
		self.Changed:Destroy()
	end
	function class:HasChanges()
		return self.changes:HasChanges()
	end
	function class:RecordSaved(saveTime)
		self.changes:RecordSaved(saveTime)
	end
	function class:RecordChanged()
		self.changes:RecordChanged()
		self.Changed:Fire()
	end
	if fnNamesForChange then
		for _, name in fnNamesForChange do
			local base = class[name]
			class[name] = function(self, ...)
				if base(self, ...) then return true end
				self:RecordChanged()
			end
		end
	end
	return class
end

return ChangedTracker