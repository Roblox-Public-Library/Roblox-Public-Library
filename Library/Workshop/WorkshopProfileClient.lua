local function doNothing() end
local doNothingMt = {__index = function() return doNothing end}
local doNothingObj = setmetatable({}, doNothingMt)
local function V(v) return {Get = function() return v end, Changed = doNothingObj} end
return {
	Books = setmetatable({
		MAX_BOOKMARKS = 10,
		GetAllLists = function() return {} end,
	}, doNothingMt),
	BookViewingSettings = {
		ThreeD = V(false),
		LightMode = V(true),
	},
	BookPouch = setmetatable({ListChanged = doNothingObj}, doNothingMt)
}