local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BooksProfile = require(ReplicatedStorage.Library.BooksProfile)
local Event = require(ReplicatedStorage.Utilities.Event)

local StarterGui = game:GetService("StarterGui")

local remotes = ReplicatedStorage.Remotes.BooksProfile

local atRateLimit -- Set<id> books can be sent to or nil
remotes.AtRateLimit.OnClientEvent:Connect(function(ids)
	atRateLimit = ids
end)
local rateLimitedActions = BooksProfile.rateLimitedActions
for _, name in BooksProfile.simpleReplication do
	local base = BooksProfile[name]
	local remote = remotes[name]
	if rateLimitedActions[name] then
		BooksProfile[name] = function(self, id, ...)
			if atRateLimit and not atRateLimit[id] then
				StarterGui:SetCore("SendNotification", {
					Title = "Too many requests",
					Text = "Please wait a few seconds and try again",
					Duration = 4,
				})
				return true
			end
			if base(self, id, ...) then return true end -- nothing to change
			remote:FireServer(id, ...)
		end
	else
		BooksProfile[name] = function(self, ...)
			if base(self, ...) then return true end -- nothing to change
			remote:FireServer(...)
		end
	end
end

local filteredNames = {}
local filteredNameAdded = Event.new()
local base = BooksProfile.new
function BooksProfile.new(...)
	local self = base(...)
	self.FilteredNameAdded = filteredNameAdded
	self.ListsChanged = Event.new() -- fires whenever a list is created, renamed, or deleted
	return self
end
function BooksProfile:GetFilteredListName(raw)
	--	If it returns nil, it hasn't come in yet
	return filteredNames[raw]
end
remotes.ListFilteredName.OnClientEvent:Connect(function(raw, filtered)
	filteredNames[raw] = filtered or false
	filteredNameAdded:Fire(raw, filtered)
end)

function BooksProfile:checkName(name)
	if #name > BooksProfile.MAX_LIST_NAME_LENGTH then
		return "Name too long"
	end
	if self:NumLists() >= BooksProfile.MAX_LISTS then
		return "Too many lists"
	end
	if self:HasList(name) then
		return "Already have a list with that name"
	end
end
function BooksProfile:TryCreateList(name)
	local problem = self:checkName(name)
	if problem then return false, problem end
	name = remotes.TryCreateList:InvokeServer(name)
	if name == false then
		return false, "Filtering isn't working right now. Please try again later."
	elseif not name then
		return false, "Something went wrong"
	end
	filteredNames[name] = name
	self:CreateList(name)
	return name
end
function BooksProfile:TryRenameList(before, after)
	local problem = self:checkName(after)
	if problem then return false, problem end
	after = remotes.TryRenameList:InvokeServer(before, after)
	if after == false then
		return false, "Filtering isn't working right now. Please try again later."
	elseif not after then
		return false, "Something went wrong"
	end
	filteredNames[after] = after
	self:RenameList(before, after)
	return after
end
for _, name in {"CreateList", "RenameList", "DeleteList"} do
	local base = BooksProfile[name]
	BooksProfile[name] = function(self, ...)
		if base(self, ...) then return true end
		self.ListsChanged:Fire()
	end
end

return BooksProfile