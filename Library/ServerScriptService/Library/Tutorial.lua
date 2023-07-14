local debuggingTutorials = false -- Controls whether you'll see the tutorials in studio (you'll either always see them or never)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tutorial = require(ReplicatedStorage.Library.Tutorial)

local ChangedTracker = require(game:GetService("ServerScriptService").Library.ChangedTracker)

local MIN_SEC_TO_COUNT_AS_VISIT = 30
local DAY = 24 * 3600
local TIME_TO_RESET_TUTORIALS = 90 * DAY

local isStudio = game:GetService("RunService"):IsStudio()

ChangedTracker.ApplyToClassWithEvent(Tutorial, {"RecordShown"})

local base = Tutorial.new
function Tutorial.new(data, profile)
	-- Delete any data from old versions
	for k, v in data do
		if Tutorial.DefaultData[k] == nil then
			data[k] = nil
		end
	end
	if isStudio then
		local value = if debuggingTutorials then 0 else os.time()
		for k in data do
			data[k] = value
		end
	end

	local self = base(data, profile)

	-- If user hasn't been here in a while, reset entire tutorial
	if data.lastVisit then
		local dt = os.time() - data.lastVisit
		if dt >= TIME_TO_RESET_TUTORIALS then
			for k, v in Tutorial.DefaultData do
				data[k] = v
			end
			self:RecordChanged()
		end
	end

	-- Automatically update lastVisit if player stays long enough
	task.delay(MIN_SEC_TO_COUNT_AS_VISIT, function()
		if self.profile.player.Parent then
			self.data.lastVisit = os.time()
			self:RecordChanged()
		end
	end)

	return self
end

function Tutorial.InitRemotes(newRemote)
	newRemote:Event("Shown", function(player, tutorial, action)
		if type(action) == "string" then
			tutorial:RecordShown(action)
		end
	end)
	newRemote:Event("ResetAll", function(player, tutorial)
		tutorial:ResetAll()
	end)
end

return Tutorial