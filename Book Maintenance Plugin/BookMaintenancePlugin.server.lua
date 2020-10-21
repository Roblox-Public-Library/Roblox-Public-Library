--[[Book Maintenance Plugin
Responsibilities:
-Assign Ids to any books that don't have them
-Update cover label gui (via BookChildren.UpdateGuis)
-Remove unnecessary children (via BookChildren.RemoveFrom)
-Keep author names up-to-date over time
-Automatically transform genres when possible
-Warn if a book's genres are completely invalid
-Auto-detect a book's genre based on the shelf it is on and warn if that genre isn't listed
-Replace all fancy quotation marks with simple equivalents (in both script source and part name)
-Compile list of books with title, author, and all other available data into an output script
-Remove unnecessary welds
]]
--[[Helpful command bar debugging functions:
function findId(objList) -- Select 1+ books and this will print the id assigned to each (if any)
	objList = objList or game.Selection:Get()
	if type(objList) ~= "table" then objList = {objList} end
	if #objList == 0 then print("Select objects for id retrieval") return end
	for _, obj in ipairs(objList) do
		local found -- becomes string version of id
		for _, idObj in ipairs(game.ServerStorage["Book Data Storage"].Ids:GetChildren()) do
			found = idObj.Value == obj and idObj.Name
			if found then break end
			for _, c in ipairs(idObj:GetChildren()) do
				found = c.Value == obj and idObj.Name
				break
			end
			if found then break end
		end
		if found then
			print("Id:", found, ("(%s)"):format(obj.Name))
		else
			print("No id for", obj.Name)
		end
	end
end
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local function isInstalled()
	return ServerStorage:FindFirstChild("Book Data Storage")
end
local failed = false
local function get(parent, child)
	local obj = not failed and parent:FindFirstChild(child)
	if not obj and not failed then
		failed = ("%s.%s"):format(parent:GetFullName(), child)
	end
	return obj
end
local function tryRequire(obj)
	return not failed and require(obj)
end
local BookChildren = tryRequire(get(ServerScriptService, "BookChildren"))
local Genres = tryRequire(get(ServerScriptService, "Genres"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = get(ReplicatedStorage, "Utilities")
local String = tryRequire(get(Utilities, "String"))
local List = tryRequire(get(Utilities, "List"))
local RemoveAllComments = tryRequire(script.Parent.RemoveAllComments)
local ReplaceInStrings = tryRequire(script.Parent.ReplaceInStrings)
local Report = tryRequire(script.Parent.Report)
if failed then
	if isInstalled() then
		warn(("Book Maintenance Plugin is missing %s - this plugin is meant to be used with other library code."):format(failed))
	end
	return
end
-- Report order constants
local IMPORTANT = 10
local FINAL_SUMMARY = 20

local RunService = game:GetService("RunService")
local heartbeat = RunService.Heartbeat
local isEditMode = RunService:IsEdit()

-- In this script, a "model" is the BasePart of a book. A "book" refers to a table with fields including Title, Author, Models, and Source.

local function path(obj)
	return obj:GetFullName():gsub("Workspace.", "")
end
local function bookPath(book)
	return path(book.Models[1])
end

-- Note: Maximum instance name length of 100 characters
local lengthRestrictions = {
	-- Available space: 76 (100 - 15 (botm possibility) - 2 (for title's "") - 4 (for " by ") - 3 (for genre " ()"))
	-- Order here matters: first entry is given any bonus space first
	{"Title", 40},
	{"Author", 18},
	{"Genre", 18},
	-- Botm expected to fit in 15
}
local function getBookTitleByAuthorLine(book)
	local fields = {
		Title = ("%s"):format(book.Title or "?"),
		Author = #book.AuthorNames > 0 and List.ToEnglish(book.AuthorNames) or "Anonymous",
		Genre = #book.Genres > 0 and book.Genres[1]
	}
	local bonusSpace = 0
	local spaceBalance = 0 -- used to determine whether we need to shorten at all
	for _, r in ipairs(lengthRestrictions) do
		local value = fields[r[1]]
		local dif = r[2] - (value and #value or 0)
		spaceBalance += dif
		bonusSpace += math.max(0, dif)
	end
	if spaceBalance < 0 then
		for _, r in ipairs(lengthRestrictions) do
			local field, length = r[1], r[2]
			local value = fields[field]
			if value then
				local n = #fields[field]
				local limit = length + bonusSpace
				if n > length + bonusSpace then -- shorten
					local goodLastIndex = 0
					limit -= 3 -- allow room for '...'
					for first, last in utf8.graphemes(fields[field]) do
						if last <= limit then
							goodLastIndex = last
						else
							break
						end
					end
					fields[field] = fields[field]:sub(1, goodLastIndex) .. "..."
					bonusSpace = 0
				elseif n > length then -- use up some bonus space
					-- ex if length is 40, bonusSpace is 10,
					-- if we use 45 (n), then we use 5 bonusSpace
					bonusSpace -= n - length
				end
			end
		end
	end
	return ('"%s" by %s%s'):format(fields.Title, fields.Author, fields.Genre and (" (%s)"):format(fields.Genre) or "")
end

local wordStartBorder = "%f[%w_]"
local wordEndBorder = "%f[^%w_]"
local sourceToBook, dataKeyList, updateBookSource, allFieldsAffected do
	local function genGetData(key)
		local first = "^local%s+" .. key .. wordEndBorder
		local firstAlt = "\nlocal%s+" .. key .. wordEndBorder
		-- Note: "^" means "at start of where we're looking" based on the index we provide to string.find
		local second = "^[ \t]-\n?[ \t]-="
		local finds = {
			'^[ \t]-\n?[ \t]-"([^"\n]*)"',
			'^[ \t]-\n?[ \t]-%s-%[(=-)%[([^\n]-)%]%1%]',
			"^[ \t]-\n?[ \t]-'([^'\n]*)'",
		}
		local useSecondData = {false, true, false}
		return function(source)
			local _, start = source:find(first)
			if not start then
				_, start = source:find(firstAlt)
			end
			if not start then return nil end
			_, start = source:find(second, start + 1)
			if not start then return nil end
			start += 1
			for i, find in ipairs(finds) do
				local data, data2 = source:match(find, start)
				if data then
					data = useSecondData[i] and data2 or data
					return data ~= "" and data or nil
				end
			end
			return nil
		end
	end
	local getAuthorLine = genGetData("customAuthorLine")
	local function genGetListData(key)
		local first = "^local%s+" .. key .. wordEndBorder
		local firstAlt = "\nlocal%s+" .. key .. wordEndBorder
		local second = "^[ \t]*\n?[ \t]*=[ \t]*\n?[ \t]*%{([^}]*)%}"
		return function(source, model)
			local _, index = source:find(first)
			if not index then
				_, index = source:find(firstAlt)
			end
			if not index then return {} end
			local _, _, data = source:find(second, index + 1)
			if not data or data == "" then return {} end
			-- data will be in format '"a", "b", "c"' but we want it in table format
			local new = {}
			for _, v in ipairs(data:split(",")) do
				v = String.Trim(v)
				if v == "" then continue end
				-- try and interpret its type
				if v:sub(1, 1) == '"' or v:sub(1, 1) == "'" then
					new[#new + 1] = v:sub(2, -2)
				elseif v:sub(1, 2) == "[[" then
					new[#new + 1] = v:sub(3, -3)
				elseif v == "true" then
					new[#new + 1] = true
				elseif v == "false" then
					new[#new + 1] = false
				else
					local n = tonumber(v)
					if n then
						new[#new + 1] = n
					else
						warn(("Unexpected value '%s' in %s in %s"):format(v, key, path(model)))
					end
				end
			end
			return new
		end
	end
	local baseGetAuthorNames = genGetListData("authorNames")
	local dataProps = {
		Title = genGetData("title"),
		CustomAuthorLine = getAuthorLine,
		AuthorNames = function(source)
			local authorNames = baseGetAuthorNames(source)
			if authorNames then
				for i = 1, #authorNames do
					if authorNames[i] == "" or not authorNames[i] then
						authorNames[i] = "Anonymous"
					end
				end
			end
			return authorNames
		end,
		AuthorIds = genGetListData("authorIds"),
		PublishDate = genGetData("publishDate"),
		Librarian = genGetData("librarian"),
		Genres = genGetListData("genres"),
	}
	local mandatoryFields = {"Title", "Authors", "PublishDate", "Librarian", "Genres"}
	local allFieldsAffected = {}
	for k, _ in pairs(dataProps) do allFieldsAffected[#allFieldsAffected + 1] = k end
	local function calculateBookAuthors(book)
		return book.CustomAuthorLine or #book.AuthorNames > 0 and List.ToEnglish(book.AuthorNames) or "Anonymous"
	end
	local noAuthor = Report.NewListCollector("1 book has no authors:", "%d books have no authors:")
	local noGenres = Report.NewListCollector("1 book has no genres:", "%d books have no genres:")
	local bookMissingField = Report.PreventDuplicates(
		Report.NewCategoryCollector("1 book is missing fields:", "%d books are missing fields:"),
		function(data) data.fieldSeenSource = {} end,
		function(data, field, _, source)
			local seen = data.fieldSeenSource[field]
			if not seen then
				seen = {}
				data.fieldSeenSource[field] = seen
			end
			if not seen[source] then
				seen[source] = true
				return false
			else
				return true
			end
		end)
	sourceToBook = function(report, source, models)
		local book = {
			Models = models,
			Source = source,
		}
		local model = models[1]
		for k, v in pairs(dataProps) do
			book[k] = v(source, model)
		end
		if book.AuthorNames[1] == nil then
			report(noAuthor, ("%s.%s"):format(path(models[1].Parent), getBookTitleByAuthorLine(book)))
		end
		if #book.Genres == 0 then
			report(noGenres, ("%s.%s"):format(path(models[1].Parent), getBookTitleByAuthorLine(book)))
		end
		book.Authors = calculateBookAuthors(book)
		local invalid = false
		for _, field in ipairs(mandatoryFields) do
			if not book[field] then
				report(bookMissingField, field, path(models[1]), source)
				invalid = true
			end
		end
		return not invalid and book or nil
	end
	updateBookSource = function(book, newSource, affectedFields) -- in affectedFields, do not include Authors. If all may have been changed, provide allFieldsAffected. If none changed, omit it.
		local updateAuthors = false
		book.Source = newSource
		for _, model in ipairs(book.Models) do
			model:FindFirstChildOfClass("Script").Source = newSource
		end
		local model = book.Models[1]
		if affectedFields then
			for _, field in ipairs(affectedFields) do
				updateAuthors = updateAuthors or field == "CustomAuthorLine" or field == "AuthorNames"
				local func = dataProps[field] or error(tostring(field) .. " is not a valid field")
				book[field] = func(newSource, model)
			end
		else
			updateAuthors = true
			for k, v in pairs(dataProps) do
				book[k] = v(newSource, model)
			end
		end
		if updateAuthors then
			book.Authors = calculateBookAuthors(book)
		end
	end
	dataKeyList = {"Title", "Authors", "PublishDate"} -- different books with these fields identical are not allowed
end
local function listToTableContents(list, suppressSpace)
	--	ex the list {false, "hi"} -> the string 'false, "hi"' (suitable for storing in a script)
	local new = {}
	for i, item in ipairs(list) do
		new[i] = type(item) == "string" and ('"%s"'):format(item) or tostring(item)
	end
	return table.concat(new, suppressSpace and "," or ", ")
end
local failedToFindVar = Report.NewListCollector("Failed to find variables for the following books:")
local function modifySourceVarList(report, source, var, newValue, model) -- newValue:list
	--	returns success, source; warns if fails to find 'var'
	local _, lastCharToKeep = source:find("local%s+" .. var .. "%s*=%s*%{")
	if not lastCharToKeep then
		report(failedToFindVar, ("'%s' in %s"):format(var, path(model)))
		return false, source
	end
	local _, firstCharToKeep = source:find("}", lastCharToKeep, true)
	if not firstCharToKeep then
		report(failedToFindVar, ("'%s' in %s"):format(var, path(model)))
		return false, source
	end
	return true, ("%s%s%s"):format(source:sub(1, lastCharToKeep), listToTableContents(newValue), source:sub(firstCharToKeep))
end

local function getOrCreate(parent, name, type)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(type)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end
local function getOrCreateWithDefault(parent, name, type, default)
	--	This is only valid for Values (ex IntValue)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(type)
		obj.Name = name
		obj.Value = default
		obj.Parent = parent
	end
	return obj
end

local storage
local function getStorage()
	if not storage then
		storage = getOrCreate(ServerStorage, "Book Data Storage", "Folder")
	end
	return storage
end
local settingsFolder
local function getSettings()
	if not settingsFolder then
		settingsFolder = getOrCreate(getStorage(), "Settings", "Configuration")
	end
	return settingsFolder
end
local typesToType = {
	boolean = "BoolValue",
	string = "StringValue",
}
local function valueToType(var)
	local varType = type(var)
	local t = typesToType[varType]
	if t then return t end
	if type(var) ~= "number" then error("Unsupported type: " .. varType) end
	return var % 1 == 0 and "IntValue" or "NumberValue"
end
local function getSetting(name, default, typeOverride)
	--	Returns a function that retrieves the value (automatically switching to a concrete setting object if the maintenance is run for the first time)
	--	supports strings, booleans, integers, and numbers. ex, typeOverride could be "NumberValue" if default is 0.
	return function()
		if not isInstalled() then return default end
		return getOrCreateWithDefault(getSettings(), name, typeOverride or valueToType(default), default).Value
	end
end

local GenLock do
	function GenLock(name, waitTimeToGuarantee)
		--	Returns a lock object
		--	Note: name defaults to Lock, but don't let 2 different locks share the same name if they might lock the same object
		name = name or "Lock"
		local fullyLocked = true -- only read from this if lock.Parent
		-- Note: since two threads on one client might both want to lock the same thing, we don't skip making a lock just because this client is alone
		local lock = Instance.new("ObjectValue")
		lock.Name = name
		lock.Value = Players.LocalPlayer
		lock.Archivable = false -- if everyone leaves the team create, this is removed
		--end
		local self = {Name = name}
		function self:HasLock(obj)
			return not lock or (fullyLocked and lock.Parent == obj)
		end
		function self:OtherHasLock(obj)
			while true do
				local other = obj:FindFirstChild(name)
				if other then
					if other == lock then
						return false
					elseif not other.Value or not other.Value.Parent or other.Value == lock.Value then
						other:Destroy()
					else
						return other
					end
				else
					return false
				end
			end
		end
		function self:NotifyOtherToRelease(obj)
			--	Will yield until the other one has released (waits up to 2 seconds, then forcefully releases it)
			local other = self:OtherHasLock(obj)
			if not other then return end
			local released = false
			local releasedEvent
			obj.AncestryChanged:Connect(function(child, parent)
				if child == other and parent ~= obj then
					released = true
					if releasedEvent then
						releasedEvent:Fire()
					end
				end
			end)
			lock.Archivable = true
			local lockOverride = lock:Clone()
			lock.Archivable = false
			lockOverride.Archivable = false
			lockOverride.Parent = other
			if not released then
				releasedEvent = Instance.new("BindableEvent")
				delay(2, function()
					if releasedEvent then
						releasedEvent:Fire()
						if other.Parent then
							other.Parent = nil
						end
					end
				end)
				releasedEvent.Event:Wait()
				releasedEvent:Destroy()
				releasedEvent = nil
			end
			lockOverride:Destroy()
		end
		local releaseDesired = Instance.new("BindableEvent")
		self.ReleaseDesired = releaseDesired.Event
		lock.ChildAdded:Connect(function()
			releaseDesired:Fire()
		end)
		function self:IsReleaseDesired()
			return #lock:GetChildren() > 0 or not lock.Parent -- not lock.Parent implies forceful release occurred
		end
		function self:TryLock(obj, func, onYield) -- attempt to get an exclusive lock on an object (if needed) and run func(lock, obj) if successful
			--	If this function yields, it will call onYield (if provided) after
			if not lock or lock.Parent == obj then -- no need or already have it
				func(obj)
				return true
			end
			if self:OtherHasLock(obj) then return false end
			if not pcall(function() lock.Parent = obj end) then return false end -- typically occurs when loading a new version of the plugin
			local success = true
			if #Players:GetPlayers() > 1 then -- wait for a moment
				fullyLocked = false
				local con = obj.ChildAdded:Connect(function(child)
					if child.Name == name and child.Value.UserId < Players.LocalPlayer.UserId then
						success = false
					end
				end)
				wait(waitTimeToGuarantee or 0)
				con:Disconnect()
				fullyLocked = success
				if onYield then pcall(onYield) end
			end
			if success then
				fullyLocked = true
				local co = coroutine.running()
				coroutine.resume(coroutine.create(function()
					-- Automatically remove the lock if something goes wrong
					while lock.Parent do
						wait()
						if coroutine.status(co) == "dead" then
							lock.Parent = nil
							break
						end
					end
					-- local timeLeft = 60 -- In case the function call to 'tryLock' was in a pcall and keeps running indefinitely
					-- while lock.Parent do
					-- 	timeLeft -= wait()
					-- 	if coroutine.status(co) == "dead" or timeLeft <= 0 then
					-- 		lock.Parent = nil
					-- 		break
					-- 	end
					-- end
				end))
				func(obj)
			end
			lock.Parent = nil
			return success
		end
		return self
	end
end

local MAX_SCRIPT_LENGTH = 199999
local function WriteMultiPageScript(parent, intro, outro, baseName, scriptType, disableIt)
	baseName = baseName or "Pg"
	intro = intro or ""
	outro = outro or ""
	scriptType = scriptType or "ModuleScript"
	local baseLength = #intro + #outro
	return function(func) -- func(write:function(content)) -- func must write all content. This function will return the number of pages written.
		--	Note: Script changes will not occur until after 'write' returns, so it is safe for write to yield or error.
		local s, length
		local numPages = 0
		local pages = {} -- source for each page
		local function finishPg()
			s[#s + 1] = outro
			numPages += 1
			pages[numPages] = table.concat(s)
			s = nil
		end
		local function startNewPg()
			s = table.create(1000)
			s[1] = intro
			length = baseLength
		end
		local function write(content)
			local contentLength = #content
			if length + contentLength > MAX_SCRIPT_LENGTH then
				finishPg()
				startNewPg()
			end
			s[#s + 1] = content
			length += contentLength
		end
		local function finish()
			if #s > 1 then
				finishPg()
			else -- was just the intro, so abandon
				s = nil
			end
			for i, page in ipairs(pages) do
				local name = baseName .. i
				local obj = parent:FindFirstChild(name)
				if obj and obj.ClassName ~= scriptType then
					obj.Parent = nil
					obj = nil
				end
				if not obj then
					obj = Instance.new(scriptType)
					obj.Name = name
					obj.Parent = parent
					if disableIt then
						obj.Disabled = true
					end
				end
				obj.Source = page
			end
			local i = numPages + 1
			while true do
				local obj = parent:FindFirstChild(baseName .. i)
				if obj then
					obj.Parent = nil
				else
					break
				end
				i += 1
			end
		end
		startNewPg()
		func(write)
		finish()
		return numPages
	end
end
local function MapMultiPageScript(parent, baseName, mapFunc)
	local i = 1
	local list = {}
	baseName = baseName or "Pg"
	while true do
		local obj = parent:FindFirstChild(baseName .. i)
		if obj then
			list[i] = mapFunc(obj)
		else
			break
		end
		i += 1
	end
	return list
end
local function RequireMultiPageScript(parent, baseName)
	--	Returns the list of requires
	return MapMultiPageScript(parent, baseName, function(obj) return require(obj:Clone()) end)
end
local function ReadMultiPageScript(parent, baseName)
	--	Returns the list of sources
	return MapMultiPageScript(parent, baseName, function(obj) return obj.Source end)
end

local readAuthorDirectory, writeAuthorDirectory do
	-- Storing an id (10 chars), author name (10 chars), LastUpdated time (10 digits), and a few control characters (4)
	-- means we can store 199999/34 = ~5882 authors in a single script
	-- Since we already have 3k books, we want to allow for multiple pages of authors
	local authorDir
	local function getAuthorDirectory()
		if not authorDir then
			authorDir = getOrCreate(getStorage(), "AuthorDirectory", "Folder")
		end
		return authorDir
	end
	function readAuthorDirectory()
		--[[Only call if plugin installed. Returns idToEntry: {
			[id] = {
				Names = {[name1] = true, [name2] = true},
				Banned = true/nil,
				LastUpdated=os.time()/nil},
		}]]
		local idToEntry = {}
		-- Expected raw format: {id, "name1", "name2", true for Banned or # for LastUpdated},
		for _, raw in ipairs(RequireMultiPageScript(getAuthorDirectory())) do
			for _, list in ipairs(raw) do
				local names = {}
				local entry = {Names = names}
				local id = list[1]
				idToEntry[id] = entry
				for i = 2, #list do
					local v = list[i]
					if type(v) == "string" then
						names[v] = true
					elseif v == true then
						entry.Banned = true
					else
						entry.LastUpdated = v
					end
				end
			end
		end
		return idToEntry
	end
	local function setToList(set)
		local list = {}
		for k, _ in pairs(set) do
			list[#list + 1] = k
		end
		return list
	end
	local writeMPSAuthorDirectory
	local function getWriteMPSAuthorDirectory()
		if not writeMPSAuthorDirectory then
			writeMPSAuthorDirectory = WriteMultiPageScript(getAuthorDirectory(), "return {\n", "}")
		end
		return writeMPSAuthorDirectory
	end
	function writeAuthorDirectory(idToEntry, considerYield)
		local clientDir = getOrCreate(ReplicatedStorage, "AuthorDirectory", "ModuleScript")
		considerYield = considerYield or function() end
		--[[
		Client data: {[id] = {name1, name2}}
		Plugin data: {{id, name1, name2, true for banned or # for LastUpdated}}
		]]
		local idToList = {}
		local idToExtra = {}
		local i = 0 -- using 'i' to only occasionally call considerYield() is 5x faster (not measuring the rest of the loop)
		for id, entry in pairs(idToEntry) do
			idToList[id] = listToTableContents(setToList(entry.Names))
			idToExtra[id] = entry.Banned or entry.LastUpdated
			i += 1
			if i == 100 then
				i = 0
				considerYield()
			end
		end
		local numPages = WriteMultiPageScript(clientDir, "return {\n", "}")(function(write)
			for id, list in pairs(idToList) do
				write(("\t[%d] = {%s},\n"):format(id, list))
				i += 1
				if i == 100 then
					i = 0
					considerYield()
				end
			end
		end)
		clientDir.Source = ([[
local idToNames = {}
for i = 1, %d do
	for k, v in pairs(require(script["Pg" .. i])) do
		local new = #v > 0 and {} or v
		for j, name in ipairs(v) do
			new[j] = name:lower()
		end
		idToNames[k] = new
	end
end

-- Add in those from BookClient
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Books = require(ReplicatedStorage.BooksClient)
local books = Books:GetBooks()
for _, book in ipairs(books) do
	for i, authorId in ipairs(book.AuthorIds) do
		if authorId then
			local author = book.Authors[i]
			if author then
				local list = idToNames[authorId]
				if not list then
					list = {}
					idToNames[authorId] = list
				end
				list[#list + 1] = author:lower()
			end
		end
	end
end

local nameToIds = {}
for id, names in pairs(idToNames) do
	for _, name in ipairs(names) do
		local list = nameToIds[name]
		if not list then
			list = {}
			nameToIds[name] = list
		end
		list[#list + 1] = id
	end
end

local AuthorDirectory = {
	IdToNames = idToNames,
	NamesToIds = nameToIds,
}

function AuthorDirectory.ExactMatches(value)
	--	if value is a number, returns the list of usernames (all lowercase) associated with that id
	--	if value is a string (must be lowercase), returns the list of ids associated with that username
	return idToNames[value] or nameToIds[value]
end
function AuthorDirectory.PartialMatches(value)
	--	if value is a number, this is exactly like ExactMatches (it returns the list of usernames (all lowercase) associated with that id)
	--	if value is a string (must be lowercase), returns the list of all user ids who have ever had a username containing that substring
	if type(value) == "number" then
		return idToNames[value]
	end
	local ids = {}
	for name, idList in pairs(nameToIds) do
		if name:find(value, 1, true) then
			for _, id in ipairs(idList) do
				ids[#ids + 1] = id
			end
		end
	end
	return ids
end
return AuthorDirectory]]):format(numPages)
		getWriteMPSAuthorDirectory()(function(write)
			for id, list in pairs(idToList) do
				write(("\t{%d%s%s,%s},\n"):format(id, list == "" and "" or ",", list, tostring(idToExtra[id] or 0)))
			end
		end)
	end
end

local authorLock, onMaintenanceFinished do
	authorLock = GenLock("AuthorScanLock", 1)
	local getCheckAuthorsEvery = getSetting("Check authors every # seconds", 7 * 24 * 3600)
	local getAuthorCheckingEnabled = getSetting("Automatic author name updating enabled", true)
	local authorCheckRunning = false
	local usernameRetrievalWarnings = {}
	local warnings = 0
	local printedReportUpToDate = false
	local function scanAuthors()
		--print("[Automatic Book Maintenance] Author database detected - commencing automatic author scanning.")
		-- [Old note when we were using IntValues] Based on my performance calculations, even though this algorithm throttles itself to only consume 25% of the time per frame, it should be able to check the NextTime on 2400+ authors/sec
		--[[
		Go through entire database
		table.sort author ids based on LastUpdated so first entry is the one to update first
		maintain index # and go through list until interrupted or run out of things to update
		write every...
			200 successful updates
			if we run out of authors to update for at least 10 seconds
			if another thread asks this one to release lock]]
		authorLock:TryLock(getStorage(), function()
			local released = false
			local lastYieldTime = os.clock()
			local function considerYieldUnlessReleasing()
				if not authorLock:IsReleaseDesired() and os.clock() - lastYieldTime >= 1/60/4 then -- take up max 25% of a frame (assuming 60fps)
					heartbeat:Wait()
					lastYieldTime = os.clock()
				end
			end
			local yielding = false -- true if yielding AND can safely release the lock at this time if we writeIfProgressMade
			local function considerSafeYield()
				if os.clock() - lastYieldTime >= 1/60/4 then -- take up max 25% of a frame (assuming 60fps)
					yielding = true
					heartbeat:Wait()
					yielding = false
					lastYieldTime = os.clock()
				end
			end
			local function yield(dur)
				yielding = true
				wait(dur)
				yielding = false
				lastYieldTime = os.clock()
			end
			local function getTimeLeft(lastUpdated)
				return lastUpdated + getCheckAuthorsEvery() - os.time()
			end
			local idToEntry = readAuthorDirectory()
			local authorIds
			local printWelcomeBefore = false
			local authorsDetected
			local function refreshIds()
				--	returns true if should exit early
				authorIds = {}
				authorsDetected = 0
				local unbannedAuthorsDetected = 0
				local upToDate = 0
				for id, entry in pairs(idToEntry) do
					authorsDetected += 1
					if entry.LastUpdated then
						unbannedAuthorsDetected += 1
						authorIds[unbannedAuthorsDetected] = id
						if getTimeLeft(entry.LastUpdated) > 0 then
							upToDate += 1
						end
					else
						upToDate += 1
					end
				end
				table.sort(authorIds, function(a, b) return idToEntry[a].LastUpdated < idToEntry[b].LastUpdated end)
				-- the ones updated longest ago will now be first
				if not printWelcomeBefore then
					if authorsDetected > 0 then
						local authorsDesc = unbannedAuthorsDetected == authorsDetected
							and ("%d authors"):format(authorsDetected)
							or ("authors (%d/%d not banned)"):format(unbannedAuthorsDetected, authorsDetected)
						if upToDate == authorsDetected then
							print(("[Author Updater] All %s up to date"):format(authorsDesc))
							printedReportUpToDate = true -- report will only say the same thing
						else
							print(("[Author Updater] Commencing scanning of %s%s"):format(
								authorsDesc,
								upToDate == 0 and "" or (" (%d up to date)"):format(upToDate)))
						end
						printWelcomeBefore = true
					else
						print("[Author Updater] No authors detected. Run maintenance to detect authors.")
						return true
					end
				end
			end
			if refreshIds() then return end
			local unwrittenChanges = 0
			local function writeIfProgressMade(noYield)
				if unwrittenChanges > 0 then
					writeAuthorDirectory(idToEntry, not noYield and considerYieldUnlessReleasing or nil)
					unwrittenChanges = 0
				end
			end
			local nextCheckIndex = 1
			local numBannedDiscovered, numUpdated, numInit, numConfirmed, numErrors = 0, 0, 0, 0, 0 -- since last print
			local function printReport()
				--local numBannedDiscovered, numBanned, numUpdated, numErrors = 0, 0, 0, 0
				-- 5 of the 12/15 unbanned authors scanned: 2 bans & 3 name changes discovered (4 unknown errors occurred). Sleeping. authors checked (3 already banned, 4 bans discovered, ); author checker dormant
				local list = {}
				if numInit > 0 then list[#list + 1] = ("%d author names initialized"):format(numInit) end
				if numUpdated > 0 then list[#list + 1] = ("%d name changes detected"):format(numUpdated) end
				if numBannedDiscovered > 0 then list[#list + 1] = ("%d bans detected"):format(numBannedDiscovered) end
				if numConfirmed > 0 then list[#list + 1] = ("%d author names unchanged"):format(numConfirmed) end
				if #list > 0 or numErrors > 0 then
					print(("[Author Updater] %s%s"):format(
						List.ToEnglish(list),
						numErrors > 0 and (" (%d unknown errors)"):format(numErrors) or ""))
					numBannedDiscovered, numUpdated, numInit, numConfirmed, numErrors = 0, 0, 0, 0, 0
				else
					print("[Author Updater] All authors up to date")
				end
			end
			while not released do
				considerSafeYield()
				if authorLock:IsReleaseDesired() then
					writeIfProgressMade(true)
					released = true
					break
				end
				if unwrittenChanges >= 500 then
					writeIfProgressMade()
					continue
				end
				local userId = authorIds[nextCheckIndex]
				if not userId then
					if refreshIds() then
						writeIfProgressMade()
						break
					end
					continue
				end
				local curEntry = idToEntry[userId]
				local lastUpdated = curEntry.LastUpdated
				local timeLeft = getTimeLeft(lastUpdated)
				if timeLeft > 0 then
					writeIfProgressMade()
					if not printedReportUpToDate then
						printReport()
						printedReportUpToDate = true
					end
					yield(timeLeft)
				else -- Update this id
					printedReportUpToDate = false
					nextCheckIndex += 1
					local success, username = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
					if not success then
						if username:find("HTTP 400") then
							curEntry.Banned = true
							curEntry.LastUpdated = nil
							numBannedDiscovered += 1
							unwrittenChanges += 1
						elseif username:find("HTTP 429") then -- too many requests
							nextCheckIndex -= 1 -- retry this author
							yield(10)
						else
							if not usernameRetrievalWarnings[username] then
								warn("Error retrieving username from author", userId .. ":", username)
								usernameRetrievalWarnings[username] = true
							end
							warnings += 1
							numErrors += 1
							if warnings >= 60 then
								warnings = 0
								warn("Automatic author name change detection paused for 15 minutes due to excessive warnings")
								yield(15 * 60)
							end
						end
					else
						if not curEntry.Names[username] then
							if not next(curEntry.Names) then
								numInit += 1
							else
								numUpdated += 1
							end
							curEntry.Names[username] = true
						else
							numConfirmed += 1
						end
						curEntry.LastUpdated = os.time()
						unwrittenChanges += 1
					end
				end
			end
		end)
		authorCheckRunning = false
	end
	local function considerScanAuthors()
		if not isEditMode or authorCheckRunning or not isInstalled() or not getAuthorCheckingEnabled() then return end
		authorCheckRunning = true
		coroutine.resume(coroutine.create(function()
			heartbeat:Wait() -- keep stack trace for debugging
			scanAuthors()
		end))
	end
	considerScanAuthors()
	function onMaintenanceFinished()
		considerScanAuthors()
	end
end

local noAuthorName = Report.NewListCollector("%d book%s have an authorId but no corresponding author name:")
local function updateAuthorInformation(report, books)
	--[[
		Read database
		Add missing entries (don't fill in the username)
		Remove authors that no longer exist
		Update author database
	]]
	local idToEntry = readAuthorDirectory()
	local idsFound = {}
	local numNew, numRemoved = 0, 0
	for _, book in ipairs(books) do
		for i, authorId in pairs(book.AuthorIds) do -- using pairs in case there are holes in the list
			if type(authorId) ~= "number" then continue end -- ex if it's false
			idsFound[authorId] = true
			local authorName = book.AuthorNames[i]
			if not authorName then
				report(noAuthorName, ("%s (id %d)"):format(bookPath(book), authorId))
				continue
			end
			local entry = idToEntry[authorId]
			if not entry then
				entry = {Names = {}}
				idToEntry[authorId] = entry
				numNew += 1
			end
		end
	end
	for id, entry in pairs(idToEntry) do
		if not idsFound[id] then
			idToEntry[id] = nil
			numRemoved += 1
		end
	end
	if numNew > 0 or numRemoved > 0 then
		writeAuthorDirectory(idToEntry)
		local list = {}
		if numNew > 0 then list[#list + 1] = ("%d new authors"):format(numNew) end
		if numRemoved > 0 then list[#list + 1] = ("%d authors no longer published"):format(numRemoved) end
		report(FINAL_SUMMARY, ("Author database updated: %s"):format(List.ToEnglish(list)))
	end
end

local generateReportToScript do
	local reportTable = {
		-- Header, width, data key (defaults to header)
		{"Title", 35},
		{"Author(s)", 25, "Authors"},
		{"Published On", 13, "PublishDate"},
		{"Librarian", 16},
		{"Copies", 7, function(book) return #book.Models end},
		{"Genres", 200, function(book) return table.concat(book.Genres, ", ") end},
	}
	for _, report in ipairs(reportTable) do
		local key = report[3] or report[1]
		if type(key) == "string" then
			report[3] = function(book) return book[key] end
		end
	end
	local function leftAlign(s, width)
		--	s: string
		--	will ensure there is a space on character number 'width'
		local n = utf8.len(s)
		return n >= width
			and s:sub(1, width - 4) .. "... | "
			or s .. string.rep(" ", width - n - 1) .. " | "
	end
	local n = #reportTable
	local function smartLeftAlign(s, width, i)
		return i == n and s or leftAlign(s, width)
	end
	local function addHeaderLine(s)
		for i, report in ipairs(reportTable) do
			s[#s + 1] = smartLeftAlign(report[1], report[2], i)
		end
		s[#s + 1] = "\n"
		for i, report in ipairs(reportTable) do
			s[#s + 1] = i == n and string.rep("-", #report[1]) or string.rep("-", report[2]) .. "+-"
		end
		s[#s + 1] = "\n"
	end
	local function bookToReportLine(book)
		-- Objective: modify this function to return # of characters added to 's' -- note: s is a table that has pre-existing content
		-- OR we could keep that in generateReportString by keeping track of #s and counting it ourselves
		local s = {}
		for i, report in ipairs(reportTable) do
			s[#s + 1] = smartLeftAlign(tostring(report[3](book)), report[2], i)
		end
		s[#s + 1] = "\n"
		return table.concat(s)
	end
	local commentOpen = "--[===[\n"
	local commentClose = "\n]===]"
	local startLength
	local commentAndHeaderOpen
	do
		local s = {commentOpen}
		addHeaderLine(s)
		commentAndHeaderOpen = table.concat(s)
		startLength = #commentAndHeaderOpen + #commentClose
	end
	local writeReport = WriteMultiPageScript(ServerStorage, commentAndHeaderOpen, commentClose, "Book List Report Pg", "Script", true)
	local function generateReport(books)
		return writeReport(function(write)
			for _, book in ipairs(books) do
				write(bookToReportLine(book))
			end
		end)
	end
	generateReportToScript = function(report, books)
		local numPages = generateReport(books)
		report(FINAL_SUMMARY, ("%d unique books compiled into %d ServerStorage.Book List Report page%s"):format(#books, numPages, numPages == 1 and "" or "s"))
	end
end

local function isBook(obj)
	if obj:IsA("BasePart") and obj:FindFirstChild("BookNameFront") then
		local script = obj:FindFirstChildOfClass("Script")
		return script
	end
	return false
end
local noBookCopy = Report.NewListCollector("1 book lacks a copy in the main shelving", "%d books lack a copy in the main shelving:")
local function findAllBooks(report)
	-- returns books (list of data with .Models)
	local sourceToModels = {}
	local function addToList(model, source)
		source = source or model:FindFirstChildOfClass("Script").Source
		local list = sourceToModels[source]
		if not list then
			list = {}
			sourceToModels[source] = list
		end
		list[#list + 1] = model
	end
	local foldersConsidered = {}
	for _, folder in ipairs({workspace.Books, workspace["Post Books"]}) do
		foldersConsidered[folder] = true
		for _, c in ipairs(folder:GetDescendants()) do
			if isBook(c) then
				addToList(c)
			end
		end
	end
	for _, folder in ipairs({workspace.BookOfTheMonth, workspace.NewBooks, workspace["Staff Recs"]}) do
		foldersConsidered[folder] = true
		for _, c in ipairs(folder:GetDescendants()) do
			if isBook(c) then
				local source = c:FindFirstChildOfClass("Script").Source
				if not sourceToModels[source] then
					report(noBookCopy, path(c))
				end
				addToList(c, source)
			end
		end
	end
	for _, folder in ipairs(workspace:GetChildren()) do
		if isBook(folder) then
			addToList(folder)
		end
		if not foldersConsidered[folder] then
			for _, c in ipairs(folder:GetDescendants()) do
				if isBook(c) then
					addToList(c)
				end
			end
		end
	end
	local books = {}
	local n = 0
	for source, models in pairs(sourceToModels) do
		local book = sourceToBook(report, source, models)
		if book then
			n = n + 1
			books[n] = book
		end
	end
	return books
end

local storeReturnSame, storeReturnSameReset do
	local fields = {}
	-- fields["someAuthor"] = {["someTitle"] = {etc}} -- in order of dataKeyList
	function storeReturnSameReset() fields = {} end
	local function getOrCreateTable(t, k)
		local v = t[k]
		if not v then
			v = {}
			t[k] = v
		end
		return v
	end
	-- local function valueToString(v)
	-- 	return type(v) == "table" and table.concat(v, "\127") or tostring(v)
	-- end
	local numDataKeyList = #dataKeyList
	storeReturnSame = function(book)
		--	Store book in 'fields', unless another book is found that has the same fields (in which case it is returned)
		local t = fields
		for i = 1, numDataKeyList - 1 do
			t = getOrCreateTable(t, book[dataKeyList[i]])
		end
		local key = dataKeyList[numDataKeyList]
		local other = t[key]
		if other then
			return other
		else
			t[key] = book
		end
	end
end

local getRidOfSpecialCharactersAndCommentsAndWaitForChildFor do
	local specials = {
		['‘'] = "'",
		['’'] = "'",
		['“'] = '"',
		['”'] = '"',
		["…"] = "...",
	}
	local function replaceSpecials(s, stringOpening)
		for k, v in pairs(specials) do
			local replace = v == stringOpening and "\\" .. v or v
			s = s:gsub(k, replace)
		end
		return s
	end
	local function getRidOfSpecialCharacters(s)
		return replaceSpecials(s, nil)
	end
	local function getRidOfSpecialCharactersInScript(s)
		return ReplaceInStrings(s, replaceSpecials)
	end
	function getRidOfSpecialCharactersAndCommentsAndWaitForChildFor(book)
		for _, model in ipairs(book.Models) do
			model.Name = getRidOfSpecialCharacters(model.Name)
		end
		local newSource = RemoveAllComments(getRidOfSpecialCharactersInScript(book.Source), true)
			:gsub(':WaitForChild%("Books"%)', ".Books")
		if newSource ~= book.Source then
			updateBookSource(book, newSource, allFieldsAffected)
		end
	end
end

local trimFieldToVar = {
	title = "Title",
	customAuthorLine = "CustomAuthorLine",
	authorsNote = false,
	cover = false,
	librarian = "Librarian",
	publishDate = "PublishDate",
}
local function trimFields(book)
	local source = book.Source
	for field, var in pairs(trimFieldToVar) do
		local start, final = source:find("local%s+" .. field .. "%s*=%s*")
		if start then
			local char = source:sub(final + 1, final + 1)
			if char == "[" then
				local _
				_, _, char = source:find("^(%[=*%[)", final + 1)
			end
			local nChar = #char
			local valueStart = final + 1 + nChar
			local endOfLine = source:find("\n", valueStart)
			if not endOfLine then endOfLine = #source + 1 end
			local valueEnd
			local i = endOfLine - nChar
			local endChar = char:gsub("%[", "]")
			while i >= valueStart do
				if source:sub(i, i + nChar - 1) == endChar then
					valueEnd = i - 1
					break
				end
				i -= 1
			end
			if valueEnd and valueEnd > valueStart then
				local value = source:sub(valueStart, valueEnd)
				local trimmed = String.Trim(value)
				if value ~= trimmed then
					source = ("%s%s%s"):format(source:sub(1, valueStart - 1), trimmed, source:sub(valueEnd + 1))
					if var then
						book[var] = trimmed
					end
				end
			end
		end
	end
	if source ~= book.Source then
		updateBookSource(book, source)
	end
end

local numNamesUpdated = Report.NewCountCollector("%d book model name%s updated")
numNamesUpdated.Order = FINAL_SUMMARY
local function updateModelName(report, book)
	local name = getBookTitleByAuthorLine(book)
	for _, model in ipairs(book.Models) do
		local botmTag = model.Name:match(" %- BOTM.*") -- preserve BOTM tag
--[[
new name
reserve 40 chars for title
20 for author
20 for genre
Botm can be limited to 15 chars

Possible algorithm:
1. Try to allow everything regardless of size
2. If it goes past max size, reduce anything that exceeds its limit until it all fits

Complication:
max size is 100 bytes, but titles can have utf8 characters (ie 2+ bytes ohh), and we ideally don't split up a utf8 character


]]

		local newName = botmTag and name .. botmTag or name
		if model.Name ~= newName then
			model.Name = newName
			report(numNamesUpdated, 1)
		end
	end
end

local idsFolder
local function getIdsFolder()
	if not idsFolder then
		idsFolder = getOrCreate(getStorage(), "Ids", "Folder")
	end
	return idsFolder
end
local idToModels, idToFolder -- can read from these after calling readIdsFolder
local invalidValues = Report.NewListCollector("The following %d value%s in the Book Data Storage.Ids folder are not ObjectValues:")
local incorrectlyNamedEntries = Report.NewListCollector("The following %d name%s in the Book Data Storage.Ids folder are not integers.")
local function readIdsFolder(report)
	--	stores results in idToModels, idToFolder (and also returns them)
	--	'report' is optional (for the sake of the Update Copies button)
	if idToModels then return end -- already cached (this is broken by updateIdsFolder)
	local madeReport = not report
	report = report or Report.new()
	getIdsFolder()
	idToModels = {}
	idToFolder = {}
	local invalid
	for _, obj in ipairs(idsFolder:GetChildren()) do
		if obj.ClassName ~= "ObjectValue" then
			report(invalidValues, ("%s:%s"):format(obj.Name, obj.ClassName))
			invalid = true
		else
			local id = tonumber(obj.Name)
			if not id or id % 1 ~= 0 or id <= 0 then
				report(incorrectlyNamedEntries, obj.Name)
				invalid = true
			else
				local models = {}
				local function considerAdd(value)
					if value and workspace:IsAncestorOf(value) then
						models[#models + 1] = value
					end
				end
				considerAdd(obj.Value)
				for _, c in ipairs(obj:GetChildren()) do
					considerAdd(c.Value)
				end
				idToModels[id] = models
				idToFolder[id] = obj
			end
		end
	end
	if invalid and madeReport then
		warn(report:Compile())
	end
end
local function updateIdsFolder(report, books, invalidIds)
	-- Note: any ids remaining in invalidIds after the for loop will be deleted
	for _, book in ipairs(books) do
		if not book.Id then
			continue
		elseif invalidIds[book.Id] then
			idToFolder[book.Id] = nil -- don't let it get deleted just because there's a configuration problem
			continue
		end
		local folder = idToFolder[book.Id]
		if folder then
			idToFolder[book.Id] = nil
		else
			folder = Instance.new("ObjectValue")
			folder.Name = tostring(book.Id)
			folder.Parent = idsFolder
		end
		local models = book.Models
		folder.Value = models[1]
		local children = folder:GetChildren()
		-- Add required children
		for i = #children + 1, #models - 1 do
			local obj = Instance.new("ObjectValue")
			obj.Name = ""
			obj.Parent = folder
			children[i] = obj
		end
		-- Update existing/new children
		for i = 2, #models do
			children[i - 1].Value = models[i]
		end
		-- Remove excess children
		for i = #models, #children do -- ex if there are 2 models, we want to delete child #2+ (should be left with 1 child)
			children[i].Parent = nil
		end
	end
	-- Remove unused entries
	local n = 0
	for id, folder in pairs(idToFolder) do
		folder.Parent = nil
		n += 1
	end
	if n > 0 then
		report(FINAL_SUMMARY, ("Removed %d unused id entries"):format(n))
	end
	idToModels = nil
	idToFolder = nil
end
local sameIdDifSource = {
	Order = IMPORTANT,
	Init = function(data)
		data.idToSet = {}
	end,
	Collect = function(data, id, model1, model2)
		local entry = data.idToSet[id]
		if not entry then
			entry = {}
			data.idToSet[entry] = entry
		end
		entry[model1] = true
		entry[model2] = true
	end,
	Compile = function(data)
		local s = {"The following books have same ids but different sources! For each set, select the newer book and click \"Update Copies\" to fix, then run maintenance again."}
		for id, set in pairs(data.idToSet) do
			local t = {}
			for model, _ in pairs(set) do
				t[#t + 1] = path(model)
			end
			s[#s + 1] = List.ToEnglish(t)
		end
		return table.concat(s, "\n\t")
	end,
}
local function verifyExistingBooksHaveSameId(report, idToModels, invalidIds, invalidSources)
	--	invalidIds[id] = true is performed for any id that has this problem
	--	invalidSources[source] = true is also performed for all sources affected
	for id, models in pairs(idToModels) do
		if #models > 1 then
			local first = models[1]:FindFirstChildOfClass("Script").Source
			for i = 2, #models do
				local other = models[i]:FindFirstChildOfClass("Script").Source
				if first ~= other then
					report(sameIdDifSource, id, models[1], models[i])
					invalidSources[first] = true
					invalidSources[other] = true
					invalidIds[id] = true
				end
			end
		end
	end
end

local sameSourceDifIds = {
	Order = IMPORTANT + 1,
	Init = function(data)
		data.seenSource = {}
		data[1] = "CRITICAL: Same book source has multiple ids! If the books haven't been published to the live game, carefully delete the invalid ids from ServerStorage.Book Data Storage.Ids"
		data[2] = "Otherwise, notify the scripting team immediately to implement an id upgrader to handle this situation! Affected books:"
	end,
	Collect = function(data, book, modelToId)
		if data.seenSource[book.Source] then return end
		data.seenSource[book.Source] = true
		local s = {("%s:"):format(book.Models[1].Name)}
		for i, model in ipairs(book.Models) do
			local id = modelToId[model]
			s[i] = ("(%s) %s"):format(id and "Id " .. id or "No id", path(model))
		end
		data[#data + 1] = table.concat(s, "\n\t\t")
	end,
	Compile = function(data)
		return table.concat(data, "\n\t")
	end,
}
local difSourceSameFields = Report.NewListCollector("The following %d pair%s of books have different sources but the same fields! Make the sources identical if they're the same book, otherwise change the fields.")
difSourceSameFields.Order = IMPORTANT
local base = difSourceSameFields.Collect
difSourceSameFields.Collect = function(data, other, book)
	base(data, ("%s and %s"):format(bookPath(other), bookPath(book)))
	if #other.Models > 1 then
		local entries = {"Copies of first:"}
		for i, model in ipairs(other.Models) do
			entries[i + 1] = ("%s"):format(path(model))
		end
		base(data, table.concat(entries, "\n\t\t"))
	end
	if #book.Models > 1 then
		local entries = {"Copies of second:"}
		for i, model in ipairs(book.Models) do
			entries[i + 1] = ("%s"):format(path(model))
		end
		base(data, table.concat(entries, "\n\t\t"))
	end
end
local function assignIds(report, books, pauseIfNeeded)
	--[[Ids folder
	Contents: ObjectValue with .Name = id for the first model with 0+ ObjectValue children (nameless) for each extra model
	Purposes:
		Keeps track of the ids for each book in a place that can't easily be modified by people moving/editing books
		If we kept ids in books, then using this plugin on a book in a different place would mess things up if someone then transfers that book to this place
	]]
	storeReturnSameReset()
	readIdsFolder(report)
	local maxId = getOrCreate(getStorage(), "MaxId", "IntValue")

	local invalidIds, invalidSources = {}, {} -- id/source->true if there is an id problem and books relating to this id/source should not be given ids
	verifyExistingBooksHaveSameId(report, idToModels, invalidIds, invalidSources)
	--[[
	for each book in books ('new' == no id record in ids):
		if 2+ old & they have inconsistent ids
			how would this happen if they have the identical source?
			maybe if it was configured incorrectly earlier
			problem: they'll now have different ids and this may have been put in the data store
				theoretically we *could* have some sort of id updater

		if 1+ old & 1+ new, give the new ones the same id (ie don't remove them from 'books', since all assumed to share the same id)
		if all old, do nothing
		if all new:
			if it shares the same fields as a different book (use dataKeyList)
				warn
				if the other book is fully new, add it to the "invalid" table
				add this book to "invalid" table
				(do not register ids for anything in the "invalid" table)
	]]
	local modelToId = {}
	for id, models in pairs(idToModels) do
		for _, model in ipairs(models) do
			modelToId[model] = id
		end
	end
	local new = {} -- List<book>
	local invalidIfNew = {} --[book] = true; used to ignore new books if they don't share the source but do share the fields
	for _, book in ipairs(books) do
		local models = book.Models
		-- Check to see if there are any inconsistencies
		local existingId
		local invalid -- becomes true if this book uses an invalid source or id
		for _, model in ipairs(models) do
			local id = modelToId[model]
			if not existingId then
				existingId = id
			elseif existingId ~= id and id then -- same source has multiple ids
				report(sameSourceDifIds, book, modelToId)
				invalid = true
				break
			end
			if id and invalidIds[id] then -- already warned about
				invalid = true
				break
			end
		end
		if existingId then
			book.Id = existingId
		end
		if invalid then
			invalidSources[book.Source] = true
			for _, model in ipairs(models) do
				local id = modelToId[model]
				if id then
					invalidIds[id] = true
				end
			end
		elseif existingId then -- either they're all old or there are new copies but no inconsistencies; do quick maintenance only
			updateModelName(report, book) -- just in case it's been changed (we assume that any editing will not introduce a need to trim/get rid of special characters/will not invalidate the book)
		else --allNew. if it doesn't share fields with another book, add to 'new' list (done further down) so it can get a new id if its source doesn't end up on the invalid list
			-- Note: we only get rid of special characters (etc) for new books because it takes at least several seconds to perform this for a few thousand books.
			trimFields(book)
			getRidOfSpecialCharactersAndCommentsAndWaitForChildFor(book)
			updateModelName(report, book)
			pauseIfNeeded()
		end
		local other = storeReturnSame(book)
		if other then -- todo this comes from below - refactor
			if not (invalidIfNew[other] and invalidIfNew[book]) then
				invalidIfNew[other] = true
				invalidIfNew[book] = true
				report(difSourceSameFields, other, book)
			end -- else otherwise warned already (not likely to happen, but could if 3 different variants all share same fields)
		end
		if not invalid and not invalidIfNew[book] and not existingId then -- New book that is still valid
			new[#new + 1] = book
		end
	end
	local nextId = maxId.Value + 1
	local skipped = 0
	for _, book in ipairs(new) do
		if invalidIfNew[book] or invalidSources[book.Source] then
			skipped += 1
			continue
		end
		book.Id = nextId
		nextId += 1
	end
	local numNew = nextId - 1 - maxId.Value
	report(FINAL_SUMMARY, (numNew == 0 and "No new books detected" or numNew .. " new book ids assigned") .. (skipped > 0 and (" (%d skipped)"):format(skipped) or ""))
	maxId.Value = nextId - 1
	updateIdsFolder(report, books, invalidIds)
end

local function deleteUnneededChildren(report, books)
	local n = 0
	for _, book in ipairs(books) do
		for _, model in ipairs(book.Models) do
			n += BookChildren.RemoveFrom(model)
		end
	end
	if n > 0 then
		report(FINAL_SUMMARY, ("%d unnecessary instances have been removed from books"):format(n))
	end
end
local function updateCoverGuis(report, books)
	local num, total = 0, 0
	for _, book in ipairs(books) do
		local title = book.Title
		for _, model in ipairs(book.Models) do
			local n = BookChildren.UpdateGuis(model, title)
			if n > 0 then
				num += 1
				total += n
			end
		end
	end
	if total > 0 then
		report(FINAL_SUMMARY, ("%d book models have had a combined %d SurfaceGui updates"):format(num, total))
	end
end

local getGenreInputFromShelf do
	local neonList = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		-- Note: some shelves called "Shelfette"
		if d.Name == "Neon" and d:FindFirstChild("GenreText") then
			neonList[#neonList + 1] = d
		end
	end
	local up = Vector3.new(0, 2.2, 0) -- theoretically 1.2 should suffice
	local down = Vector3.new(0, -2, 0) -- theoretically -1 should suffice
	local dirs = {up, down}
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
	raycastParams.FilterDescendantsInstances = neonList
	local function getShelfFromBook(bookModel)
		for _, dir in ipairs(dirs) do
			local raycastResult = workspace:Raycast(bookModel.Position, dir, raycastParams)
			if raycastResult and raycastResult.Instance then
				return raycastResult.Instance
			end
		end
	end
	function getGenreInputFromShelf(bookModel)
		local shelf = getShelfFromBook(bookModel)
		if not shelf then return nil end
		local relCF = shelf.CFrame:ToObjectSpace(bookModel.CFrame)
		local desiredFace = relCF.Z > 0 and Enum.NormalId.Back or Enum.NormalId.Front
		for _, genreText in ipairs(shelf:GetChildren()) do
			if genreText.Face == desiredFace then
				return genreText.TextLabel.Text, shelf
			end
		end
		print(path(shelf), path(bookModel), relCF, desiredFace)
		warn("Error: Didn't find genreText with desired face")
		return nil
	end
end

local getSupportMultiShelfBooks = getSetting("Allow the same book on different shelf genres", false)
local invalidGenreEntry = Report.NewListCollector("%d book%s have invalid genre entries:")
local bookNotOnShelf = Report.NewListCollector("%d book%s have no copies on any shelf:")
local onShelfLackingGenre = {
	Init = function(data)
		-- "shelf" being "genreInput"
		data.shelfToGenre = {}
		data.shelfToBooks = {}
	end,
	Collect = function(data, genreInput, genre, book)
		local list = data.shelfToBooks[genreInput]
		if not list then
			list = {}
			data.shelfToGenre[genreInput] = genre
			data.shelfToBooks[genreInput] = list
		end
		list[#list + 1] = book
	end,
	Compile = function(data)
		local s = {"The following shelves contain books lacking that shelf's genre:"}
		local shelfToGenre = data.shelfToGenre
		for shelf, books in pairs(data.shelfToBooks) do
			s[#s + 1] = ("\t%s%s:"):format(shelf, shelf == shelfToGenre[shelf] and "" or (" (genre %s)"):format(shelfToGenre[shelf]))
			for _, book in ipairs(books) do
				s[#s + 1] = ("\t\t%s"):format(bookPath(book))
			end
		end
		return table.concat(s, "\n")
	end,
}
local multiShelfBooks = Report.NewListCollector("%d books have copies on shelves of different genres:")
local base = multiShelfBooks.Collect
function multiShelfBooks.Collect(data, shelfModel, book, shelfToModel)
	local list = {book.Models[1].Name}
	for shelf, model in pairs(shelfToModel) do
		list[#list + 1] = ("\n\t\t%s: %s"):format(shelf, path(model))
	end
	base(data, table.concat(list))
end

local unknownShelfGenre = Report.NewListCollector("1 shelf refers to unknown genres:", "%d shelves refer to unknown genres:")
local getIgnoreShelfGenres do
	local getRaw = getSetting("Ignore shelving for genres (separated by ';')", "Library Post; Secret; Library Archives")
	local prevRaw, prevValue
	function getIgnoreShelfGenres()
		local raw = getRaw()
		if prevRaw == raw then
			return prevValue
		end
		local entries = {}
		for _, genre in ipairs(raw:split(";")) do
			genre = String.Trim(genre)
			if #genre > 0 then
				entries[genre] = true
			end
		end
		prevRaw = raw
		prevValue = entries
		return entries
	end
end
local function verifyGenres(report, books)
	local shelfGenreWarnings = {}
	local genreFixes = 0
	for _, book in ipairs(books) do
		if not book.Id then continue end -- validation issue
		local modified = false
		local invalid = {}
		local genres = book.Genres
		for i, input in ipairs(genres) do
			local genre = Genres.InputToGenre(input)
			if genre and genre ~= input then
				modified = true
				genreFixes += 1
				genres[i] = genre
			elseif not genre then
				invalid[#invalid + 1] = input
			end -- else genre == input so no change to make
		end
		if #invalid > 0 then
			report(invalidGenreEntry, ("%s: %s"):format(bookPath(book), table.concat(invalid, ", ")))
		end
		-- Find genre from shelf (if any)
		local genreInput
		local supportMultiShelfBooks = getSupportMultiShelfBooks()
		local multiShelf = supportMultiShelfBooks or {} -- if not supportMultiShelfBooks, [genre input] = model
		local multiShelfDetected = false -- only true if supportMultiShelfBooks
		local shelfBookModel -- the book model for which the shelf genreInput was found
		for _, model in ipairs(book.Models) do
			local input = getGenreInputFromShelf(model)
			if input then
				if genreInput and genreInput ~= input then
					-- Note: this will only occur if supportMultiShelfBooks because we would have hit the 'break' below otherwise
					multiShelfDetected = true
				else
					genreInput = input
					shelfBookModel = model
					if supportMultiShelfBooks then
						break
					end
				end
				if not supportMultiShelfBooks then
					multiShelf[input] = model
				end
			end
		end
		if not genreInput then
			local ignoreShelf
			local ignoreShelfGenres = getIgnoreShelfGenres()
			for _, genre in ipairs(book.Genres) do
				if ignoreShelfGenres[genre] then
					ignoreShelf = true
					break
				end
			end
			if not ignoreShelf then
				report(bookNotOnShelf, bookPath(book))
			end
		else
			if multiShelfDetected then
				report(multiShelfBooks, shelfBookModel, book, multiShelf)
			end
			local genre = Genres.InputToGenre(genreInput)
			if not genre and not shelfGenreWarnings[genreInput] then
				report(unknownShelfGenre, ("%s (near %s)"):format(genreInput, path(shelfBookModel)))
				shelfGenreWarnings[genreInput] = true
			end
			if genre and not table.find(genres, genre) then
				report(onShelfLackingGenre, genreInput, genre, book)
			end
		end
		if modified then -- Update script with modified genres
			local success, source = modifySourceVarList(report, book.Source, "genres", genres, book.Models[1])
			if success then
				updateBookSource(book, source)
			end
		end
	end
	if genreFixes > 0 then
		report(FINAL_SUMMARY, ("%d genre tags fixed"):format(genreFixes))
	end
end
local function removeUnnecessaryWelds(report)
	local n = 0
	local locations = {workspace, game:GetService("ServerScriptService"), game:GetService("ServerStorage"), game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage"), game:GetService("Lighting"), game:GetService("StarterGui"), game:GetService("StarterPack")}
	for _, location in ipairs(locations) do
		for _, obj in ipairs(location:GetDescendants()) do
			if obj:IsA("Weld") or obj:IsA("ManualWeld") or obj:IsA("Snap") then
				if not obj.Part0 or not obj.Part1 or (obj.Part0.Anchored and obj.Part1.Anchored) then
					n = n + 1
					obj.Parent = nil
				end
			end
		end
	end
	if n > 0 then
		report(FINAL_SUMMARY, ("%d unnecessary welds removed"):format(n))
	end
end

local function genPauseIfNeeded(maxProcessingTime)
	local last = os.clock()
	return function()
		if os.clock() - last >= maxProcessingTime then
			heartbeat:Wait()
			last = os.clock()
		end
	end
end

-- local scanningCons
-- local analysisRunning
local maintenanceLock = GenLock()
local authorScanOverrideLock = GenLock(authorLock.Name)
local function run()
	-- todo let this toggle scanning?
	-- if scanningCons then
	-- 	for _, con in ipairs(scanningCons) do
	-- 		con:Disconnect()
	-- 	end
	-- 	scanningCons = nil
	-- 	print("Book Maintenance Scanning Stopped")
	-- else
	-- 	analysisRunning = true
	local gotLock = maintenanceLock:TryLock(getStorage(), function(storage)
		local pauseIfNeeded = genPauseIfNeeded(1)
		local report = Report.new()
		report:OrderHeader(IMPORTANT, "IMPORTANT")
		local books = findAllBooks(report)
		local ready = Instance.new("BindableEvent")
		coroutine.wrap(function() authorScanOverrideLock:NotifyOtherToRelease(storage) ready:Fire() ready:Destroy() ready = nil end)()
		assignIds(report, books, pauseIfNeeded); pauseIfNeeded()
		-- note: books don't have .Id until after assignIds, and invalid books never get an id
		verifyGenres(report, books); pauseIfNeeded()
		deleteUnneededChildren(report, books); pauseIfNeeded()
		updateCoverGuis(report, books); pauseIfNeeded()
		removeUnnecessaryWelds(report); pauseIfNeeded()
		generateReportToScript(report, books)
		local success = false
		if ready then
			ready.Event:Wait()
		end
		if not authorScanOverrideLock:TryLock(storage, function()
			updateAuthorInformation(report, books)
		end) then
			warn("Failed to acquire lock to update author database")
		end
		print(report:Compile())
		onMaintenanceFinished()
	end)
	if not gotLock then
		print("Someone else is already running Book Maintenance")
	end

	-- 	analysisRunning = false
	-- 	scanningCons = {
	-- 		workspace.DescendantAdded:Connect(function(obj)
	-- 			if analysisRunning or not isBook(obj) then return end
	-- 		end),
	-- 		workspace.DescendantRemoving:Connect(function(obj)
	-- 			if analysisRunning or not isBook(obj) then return end
	-- 			-- todo remove obj from book model (and if it's the last model, remove from other collections)
	-- 		end)
	-- 	}
	-- end
end

local toolbar = plugin:CreateToolbar("Book Maintenance")
local updateCopiesButton = toolbar:CreateButton("Update\nCopies", "Update other copies of the selected book to reflect new script changes", "")
local Selection = game:GetService("Selection")
updateCopiesButton.Click:Connect(function()
	local selected = Selection:Get()
	if #selected ~= 1 then
		warn("Please select only the book script or model of the updated book before clicking this button.")
		return
	end
	selected = selected[1]
	local bookModel = isBook(selected) and selected
		or isBook(selected.Parent) and selected.Parent
	if not bookModel then
		warn("Please select the book script or model of the updated book before clicking this button.")
		return
	end
	updateCopiesButton:SetActive(true)
	readIdsFolder()
	for id, models in pairs(idToModels) do
		local source, foundIndex
		for i, model in ipairs(models) do
			if model == bookModel then
				source = model:FindFirstChildOfClass("Script").Source
				foundIndex = i
				break
			end
		end
		if source then
			for i, model in ipairs(models) do
				if foundIndex ~= i then
					model:FindFirstChildOfClass("Script").Source = source
				end
			end
			if #models == 1 then
				print("(That's the only copy of that book.)")
			else
				print("Updated", #models - 1, "other", #models == 2 and "copy." or "copies.")
			end
			updateCopiesButton:SetActive(false)
			return
		end
	end
	warn("The selected book does not have an id. Run the maintenance plugin to assign new ids.")
	updateCopiesButton:SetActive(false)
end)
local bookMaintenanceButton = toolbar:CreateButton("Run", "Run book maintenance", "")
bookMaintenanceButton.Click:Connect(function()
	bookMaintenanceButton:SetActive(true)
	run()
	bookMaintenanceButton:SetActive(false)
end)