local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Class = require(ReplicatedStorage.Utilities.Class)

local Tutorial = Class.New("Tutorial")

local latestVersions = {
	-- First version should be 1; versions can be incremented if the tutorial is updated and should be shown to players again
	firstTimeTour = 1, -- shows book search and FAQ buttons
	-- todo add more UI explanations when you open them
	BookGui = 1,
	BookSearch = 1,
	BookViewingSettings = 1,
}
local defaultData = {
	lastVisit = 0, -- os.time()
	-- All other fields are version numbers
}
for k, version in latestVersions do
	defaultData[k] = 0
end
Tutorial.DefaultData = defaultData

function Tutorial.new(data, profile)
	return setmetatable({
		data = data,
		lastVisit = data.lastVisit, -- save this locally since data.lastVisit is updated after a bit
		profile = profile,
	}, Tutorial)
end
function Tutorial:ShouldShow(action)
	local v = self.data[action]
	return not v or v < latestVersions[action]
end
function Tutorial:RecordShown(action)
	self.data[action] = latestVersions[action]
end
function Tutorial:ResetAll()
	local data = self.data
	for k in data do
		data[k] = 0
	end
end

return Tutorial