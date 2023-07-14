local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SearchProfile = require(ReplicatedStorage.Library.SearchProfile)

local StarterGui = game:GetService("StarterGui")

local remotes = ReplicatedStorage.Remotes.SearchProfile

local function detectChange(t, fn, newT) -- returns a new table
	--	Due to nature of metatables, anything in newT will not be tracked (unless it is later removed)
	newT = newT or {}
	return setmetatable(newT, {
		__index = t,
		__newindex = function(_, k, v)
			if t[k] ~= v then
				t[k] = v
				fn()
			end
		end,
		__iter = function()
			return coroutine.wrap(function()
				for k, v in pairs(newT) do
					coroutine.yield(k, v)
				end
				for k, v in t do
					if rawget(newT, k) == nil then -- usually will, but for config.Genres and config.Lists, newT is meant to override those
						coroutine.yield(k, v)
					end
				end
			end)
		end,
	})
end

local base = SearchProfile.new
function SearchProfile.new(data, ...)
	local self = base(data, ...)

	-- Set it up so that modifying self.Config will automatically send changes to server (after 10 seconds of no further changes)
	local num = 0
	local function considerSend()
		num += 1
		local cur = num
		task.delay(10, function()
			if cur == num then
				remotes.Config:FireServer(data.Config) -- not self.Config because we change that below
			end
		end)
	end
	local config = self.Config
	config.Lists = config.Lists or {}
	config.Genres = config.Genres or {}
	self.Config = detectChange(config, considerSend, {
		Lists = detectChange(config.Lists, considerSend),
		Genres = detectChange(config.Genres, considerSend)
	})
	return self
end
function SearchProfile:GetResultsViewList(value)
	return self.data.ResultsViewList
end
function SearchProfile:SetResultsViewList(value)
	value = not not value
	if self.data.ResultsViewList == value then return true end
	self.data.ResultsViewList = value
	remotes.SetResultsViewList:FireServer(value)
end

return SearchProfile