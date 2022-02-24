local doNothing = require(script.Parent.Functions).DoNothing
local Event = require(script.Parent.Event)
local function getLowerName(name)
	return name:sub(1, 1):lower() .. name:sub(2)
end
local AddEventsToSerializable = {}
function AddEventsToSerializable.Bindable(class, eventNames)
	--	For each "Event" in eventNames, makes it so you can call class.event:Fire and class.Event:Connect
	--	This extends the .new and .Deserialize functions to create the events and extends Destroy to clean them up
	--	Call this *after* you have defined the class's new, Deserialize, and (optionally) Destroy functions
	local lowerEventNames = {}
	for i, name in ipairs(eventNames) do
		lowerEventNames[i] = getLowerName(name)
	end
	-- Note: init must not be part of the class
	--	Otherwise an inheriting class could would accidentally call this function before it's ready
	--	(by calling the base class's .new) and would then call it again a 2nd time to finish its own constructor
	local function init(self)
		for i, name in ipairs(eventNames) do
			local lowerName = lowerEventNames[i]
			local event = Instance.new("BindableEvent")
			self[lowerName] = event
			self[name] = event.Event
		end
		return self
	end
	local base = class.new or error("Call this function after creating new")
	function class.new(...)
		return init(base(...))
	end
	local base = class.Deserialize or error("Call this function after creating Deserialize")
	function class.Deserialize(...)
		return init(base(...))
	end
	local base = class.Destroy or doNothing
	function class:Destroy()
		base(self)
		-- Clean up events
		for _, name in ipairs(lowerEventNames) do
			self[name]:Destroy()
		end
	end
	return class
end
function AddEventsToSerializable.Event(class, eventNames)
	--	For each "Event" in eventNames, makes it so you can call class.Event:Fire and class.Event:Connect
	--	This extends the .new and .Deserialize functions to create the events and extends Destroy to clean them up
	--	Call this *after* you have defined the class's new, Deserialize, and (optionally) Destroy functions
	-- Note: init must not be part of the class
	--	Otherwise an inheriting class could would accidentally call this function before it's ready
	--	(by calling the base class's .new) and would then call it again a 2nd time to finish its own constructor
	local function init(self)
		for i, name in ipairs(eventNames) do
			self[name] = Event.new()
		end
		return self
	end
	local base = class.new or error("Call this function after creating new")
	function class.new(...)
		return init(base(...))
	end
	local base = class.Deserialize or error("Call this function after creating Deserialize")
	function class.Deserialize(...)
		return init(base(...))
	end
	local base = class.Destroy or doNothing
	function class:Destroy()
		base(self)
		-- Clean up events
		for _, name in ipairs(eventNames) do
			self[name]:Destroy()
		end
	end
	return class
end
return AddEventsToSerializable