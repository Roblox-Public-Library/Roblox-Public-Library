--[[NewRemote is to be used on the server to create remote events/functions
It uses 'getArg' - ex, a Profile class would retrieve the profile for a given player
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local NewRemote = {}
NewRemote.__index = NewRemote
function NewRemote.new(folder, getArg)
	return setmetatable({
		folder = folder,
		getArg = Assert.Function(getArg), --(player):arg to send to event/function handlers after player
	}, NewRemote)
end
function NewRemote.newFolder(parent, name, ...)
	--	Create a folder for a NewRemote object
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return NewRemote.new(folder, ...)
end
function NewRemote:Event(name, func)
	--	func(player, arg from getArg, ... from remote)
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = self.folder
	if func then
		local getArg = self.getArg
		e.OnServerEvent:Connect(function(player, ...)
			local arg = getArg(player)
			if not arg then return end -- player left
			func(player, arg, ...)
		end)
	end
	return e
end
function NewRemote:Function(name, func)
	--	func(player, arg from getArg, ... from remote):... to return to the remote
	local e = Instance.new("RemoteFunction")
	e.Name = name
	e.Parent = self.folder
	local getArg = self.getArg
	function e.OnServerInvoke(player, ...)
		local arg = getArg(player)
		if not arg then return end -- player left
		return func(player, arg, ...)
	end
	return e
end
return NewRemote