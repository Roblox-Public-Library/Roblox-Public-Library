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
-- todo all script dependencies must be added to plugin (or at least don't error if they aren't available and explain to user what to do)
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RemoveAllComments = require(ServerStorage.RemoveAllComments)
local ServerScriptService = game:GetService("ServerScriptService")
local BookChildren = require(ServerScriptService.BookChildren)
local Genres = require(ServerScriptService.Genres)
local Utilities = game:GetService("ReplicatedStorage").Utilities
local String = require(Utilities.String)
local List = require(Utilities.List)

local RunService = game:GetService("RunService")
local heartbeat = RunService.Heartbeat
local isEditMode = RunService:IsEdit()

-- In this script, a "model" is the BasePart of a book. A "book" refers to a table with fields including Title, Author, Models, and Source.

local sourceToBook, dataKeyList, updateBookSource, allFieldsAffected do
	local function genGetData(key)
		local first = "local%s+" .. key
		local second = "[ \t]-\n?[ \t]-="
		local finds = {
			'[ \t]-\n?[ \t]-"([^"\n]*)"',
			'[ \t]-\n?[ \t]-%s-%[(=-)%[([^\n]-)%]%1%]',
			"[ \t]-\n?[ \t]-'([^'\n]*)'",
		}
		local useSecondData = {false, true, false}
		return function(source)
			local _, start = source:find(first)
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
		local find = "local%s+" .. key .. '%s*=?%s*%{([^}]*)%}'
		return function(source, model)
			local _, _, data = source:find(find)
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
						warn(("Unexpected value '%s' in %s in %s"):format(v, key, model:GetFullName()))
					end
				end
			end
			return new
		end
	end
	local dataProps = {
		Title = genGetData("title"),
		CustomAuthorLine = getAuthorLine,
		AuthorNames = genGetListData("authorNames"),
		AuthorIds = genGetListData("authorIds"),
		PublishDate = genGetData("publishDate"),
		Librarian = genGetData("librarian"),
		Genres = genGetListData("genres"),
	}
	local mandatoryFields = {"Title", "Authors", "PublishDate", "Librarian", "Genres"}
	local allFieldsAffected = {}
	for k, _ in pairs(dataProps) do allFieldsAffected[#allFieldsAffected + 1] = k end
	sourceToBook = function(source, models)
		local book = {
			Models = models,
			Source = source,
		}
		local model = models[1]
		for k, v in pairs(dataProps) do
			book[k] = v(source, model)
		end
		if book.AuthorNames[1] == nil then print(models[1]:GetFullName(), "has a nil 1st AuthorName") end
		book.Authors = book.CustomAuthorLine or List.ToEnglish(book.AuthorNames)
		for _, field in ipairs(mandatoryFields) do
			if not book[field] then
				warn(("%s is missing '%s'!"):format(models[1]:GetFullName(), field))
				return nil
			end
		end
		return book
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
			book.Authors = book.CustomAuthorLine or List.ToEnglish(book.AuthorNames)
		end
	end
	dataKeyList = {"Title", "Authors", "PublishDate"} -- different books with these fields identical are not allowed
end
local function listToTableContents(list)
	--	ex the list {false, "hi"} -> the string 'false, "hi"' (suitable for storing in a script)
	local new = {}
	for i, item in ipairs(list) do
		new[i] = type(item) == "string" and ('"%s"'):format(item) or tostring(item)
	end
	return table.concat(new, ", ")
end
local function modifySourceVarList(source, var, newValue, model) -- newValue:list
	--	returns success, source; warns if fails to find 'var'
	local _, lastCharToKeep = source:find("local%s+" .. var .. "%s*=%s*%{")
	if not lastCharToKeep then
		warn(("Failed to find variable '%s' in %s"):format(var, model:GetFullName()))
		return false, source
	end
	local _, firstCharToKeep = source:find("}", lastCharToKeep, true)
	if not firstCharToKeep then
		warn(("Failed to find variable '%s' in %s"):format(var, model:GetFullName()))
		return false, source
	end
	return true, ("%s%s%s"):format(
		source:sub(1, lastCharToKeep),
		listToTableContents(newValue),
		source:sub(firstCharToKeep))
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
local function storageExists()
	storage = storage or ServerStorage:FindFirstChild("Book Data Storage")
	return storage
end
local function getStorage()
	if not storage then
		storage = getOrCreate(ServerStorage, "Book Data Storage", "Folder")
	end
	return storage
end
local settingsFolder
local function getSettings()
	if not settingsFolder then
		settingsFolder = getOrCreate(storage, "Settings", "Configuration")
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
		if not storageExists() then return default end
		return getOrCreateWithDefault(getSettings(), name, typeOverride or valueToType(default), default).Value
	end
end

local GenLock do
	function GenLock(name)
		--	Returns the 'tryLock' function
		--	Note: name defaults to Lock, but don't let 2 different locks share the same name if they might lock the same object
		name = name or "Lock"
		local lock
		if isEditMode and #Players:GetPlayers() >= 1 then -- need lock
			lock = Instance.new("ObjectValue")
			lock.Name = name
			lock.Value = Players.LocalPlayer
			lock.Archivable = false -- if everyone leaves the team create, this is removed
		end
		local function tryLock(obj, func, onYield) -- attempt to get an exclusive lock on an object (if needed) and run func(obj) if successful
			--	If this function yields, it will call onYield (if provided) after
			if not lock then -- no need
				func(obj)
				return true
			end
			local other
			while true do
				other = obj:FindFirstChild(name)
				if other then
					if not other.Value or not other.Value.Parent or (other.Value == lock.Value and other ~= lock) then
						other:Destroy()
					else
						return false
					end
				else
					break
				end
			end
			lock.Parent = obj
			local success = true
			if #Players:GetPlayers() > 1 then -- wait for a moment
				local con = obj.ChildAdded:Connect(function(child)
					if child.Name == name and child.Value.UserId < Players.LocalPlayer.UserId then
						success = false
					end
				end)
				wait()
				con:Disconnect()
				if onYield then pcall(onYield) end
			end
			if success then
				local co = coroutine.running()
				coroutine.resume(coroutine.create(function()
					-- Automatically remove the lock if something goes wrong
					local timeLeft = 60 -- In case the function call to 'tryLock' was in a pcall and keeps running indefinitely
					while lock.Parent do
						timeLeft -= wait()
						if coroutine.status(co) == "dead" or timeLeft <= 0 then
							lock.Parent = nil
							break
						end
					end
				end))
				func(obj)
			end
			lock.Parent = nil
			return success
		end
		return tryLock
	end
end
local tryAuthorLock = GenLock()

local onMaintenanceFinished, getAuthorDatabase do
	local getCheckAuthorsEvery = getSetting("Check authors every # seconds", 7 * 24 * 3600)
	local getAuthorCheckingEnabled = getSetting("Automatic author name updating enabled", true)
	local authorDatabase
	function getAuthorDatabase()
		if not authorDatabase then
			authorDatabase = getOrCreate(storage, "Authors", "Folder")
		end
		return authorDatabase
	end
	local authorCheckRunning = false
	local usernameRetrievalWarnings = {}
	local warnings = 0
	local printedReportBefore = false
	local lastNumPendingChanges = 0
	local function scanAuthors()
		-- This routine should not attempt to make changes to scripts because this requires scanning all books for the old author ids.
		-- The maintenance script can do it all at once more efficiently and on demand instead of while the user may be working.
		--print("[Automatic Book Maintenance] Author database detected - commencing automatic author scanning.")
		coroutine.wrap(function()
			local lastYieldTime = os.clock()
			local function updateLastYieldTime()
				lastYieldTime = os.clock()
			end
			-- Based on my performance calculations, even though this algorithm throttles itself to only consume 25% of the time per frame, it should be able to check the NextTime on 2400+ authors/sec
			local numBannedDiscovered, numUpdated = 0, 0 -- since last print
			while authorDatabase and authorDatabase.Parent do
				local smallestFutureCheck = math.huge
				-- find an entry that isn't banned, whose NextCheck is <= os.clock(), and that we can get a lock on
				local numScanned, numAlreadyBanned, numErrors = 0, 0, 0
				local children = getAuthorDatabase():GetChildren()
				local total = 0
				for _, entry in ipairs(children) do
					local userId = tonumber(entry.Name)
					if not userId then -- invalid entry
						entry.Parent = nil
						continue
					end
					if not entry.Parent then continue end -- deleted by something else
					total += 1
					if entry:FindFirstChild("Banned") then
						numAlreadyBanned += 1
						continue
					end
					local nextCheck = entry.NextCheck.Value
					if nextCheck <= os.time() then
						tryAuthorLock(entry, function()
							numScanned += 1
							lastYieldTime = os.clock()
							local success, username = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
							if not success then
								if username:find("HTTP 400") then
									local obj = Instance.new("BoolValue")
									obj.Name = "Banned"
									obj.Value = true
									obj.Parent = entry
									numBannedDiscovered += 1
								else
									if not usernameRetrievalWarnings[username] then
										warn("Error retrieving username from author", userId .. ":", username)
										usernameRetrievalWarnings[username] = true
									end
									warnings += 1
									numErrors += 1
									if warnings >= 60 then
										warnings = 0
										wait(15 * 60)
									end
								end
							else
								if entry.Value ~= username then
									entry.Name = username
									numUpdated += 1
								end
								entry.NextCheck.Value = os.time() + getCheckAuthorsEvery()
							end
						end, updateLastYieldTime)
					elseif nextCheck < smallestFutureCheck then
						smallestFutureCheck = nextCheck
					end
					if os.clock() - lastYieldTime >= 1/60/4 then -- take up max 25% of a frame (assuming 60fps)
						heartbeat:Wait()
						lastYieldTime = os.clock()
					end
				end
				local timeLeft = smallestFutureCheck - os.time()
				if timeLeft >= 60 or (timeLeft > 0 and not printedReportBefore) then -- everything up to date
					--local numBannedDiscovered, numBanned, numUpdated, numErrors = 0, 0, 0, 0
					-- 5 of the 12/15 unbanned authors scanned: 2 bans & 3 name changes discovered (4 unknown errors occurred). Sleeping. authors checked (3 already banned, 4 bans discovered, ); author checker dormant
					local nothingDiscovered = numBannedDiscovered == 0 and numUpdated == 0
					if not printedReportBefore or not nothingDiscovered then
						local numPending = numAlreadyBanned + numBannedDiscovered + numUpdated
						local pendingString = numPending > 0 and (" (%d pending changes - run maintenance to update)"):format(numPending) or ""
						if total == 0 then
							print("[Author Updater] No authors detected. Run maintenance to detect authors.")
						elseif numScanned == 0 then
							print(("[Author Updater] All %d authors are up to date.%s"):format(total, pendingString))
						else
							print(("[Author Updater] %d/%d authors scanned: %d bans & %d name changes discovered%s%s"):format(
								numScanned, total,
								numBannedDiscovered, numUpdated,
								numErrors > 0 and (" (%d unknown errors)"):format(numErrors) or ""),
								pendingString)
						end
						printedReportBefore = true
						lastNumPendingChanges = numPending
						numBannedDiscovered, numUpdated = 0, 0
					end
				end
				if timeLeft > 0 then
					wait(math.min(timeLeft, 300))
				end
			end
			authorCheckRunning = false
		end)()
	end
	local function considerScanAuthors()
		if not isEditMode or authorCheckRunning or not storageExists() or not getAuthorCheckingEnabled() then return end
		authorCheckRunning = true
		coroutine.wrap(scanAuthors)()
	end
	considerScanAuthors()
	function onMaintenanceFinished()
		if lastNumPendingChanges > 0 then
			printedReportBefore = false
		end
		considerScanAuthors()
	end
end

local function updateAuthorInformation(report, books)
	--[[
		Scan through database
		If an entry has a Banned child, remove the entry and record the change (authorId must be set to 'false')
		If an entry has a NewName child, remove that child and record the change (authorName must be set to the new value)
		Modify all relevant scripts regardless of id/configuration problems
		Update author database
	]]
	local authorIdBanned = {} --[id] = true if banned
	local authorIdToName = {}
	 --[OLD] for non-anonymous authors. These names are only to be used as "defaults" in case the database doesn't already have an entry for this author.
	local authorDatabase = getAuthorDatabase()
	for _, entry in ipairs(authorDatabase:GetChildren()) do
		local id = tonumber(entry.Name)
		if not id then
			entry.Parent = nil
		elseif entry:FindFirstChild("Banned") then
			authorIdBanned[id] = true
			entry.Parent = nil
		else
			authorIdToName[id] = entry.Value
		end
	end
	for _, book in ipairs(books) do
		local madeChange = false
		for i, authorId in pairs(book.AuthorIds) do -- using pairs in case there are holes in the list
			if not authorId then continue end -- ex if it's false
			if authorIdBanned[authorId] then
				book.AuthorIds[i] = false
				madeChange = true
			else
				local curName, correctName = book.AuthorNames[i], authorIdToName[authorId]
				if correctName and curName ~= correctName then
					book.AuthorNames[i] = correctName
					madeChange = true
				elseif not correctName then -- new entry in the database
					if curName then
						authorIdToName[authorId] = curName

						local newEntry = Instance.new("StringValue")
						newEntry.Name = tostring(authorId)
						newEntry.Value = curName
						local nextCheck = Instance.new("IntValue")
						nextCheck.Name = "NextCheck"
						-- Default value of 0 is fine
						nextCheck.Parent = newEntry
						newEntry.Parent = authorDatabase
					else
						warn(book.Models[1]:GetFullName(), "has authorId", authorId, "but no corresponding author name")
					end
				end
			end
		end
		if madeChange then -- Update source
			local model = book.Models[1]
			local success, source = modifySourceVarList(book.Source, "authorIds", book.AuthorIds, model)
			if success then
				success, source = modifySourceVarList(source, "authorNames", book.AuthorNames, model)
				if success then
					updateBookSource(book, source)
				end
			end
		end
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
		local n = #s
		return n >= width
			and s:sub(1, width - 4) .. "... | "
			or s .. string.rep(" ", width - #s - 1) .. " | "
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
	local function bookToReportLine(s, book)
		--	s: report string so far (table)
		for i, report in ipairs(reportTable) do
			s[#s + 1] = smartLeftAlign(tostring(report[3](book)), report[2], i)
		end
		s[#s + 1] = "\n"
	end
	local function generateReportString(books)
		local s = {"--[===[\n"}
		addHeaderLine(s)
		for _, book in ipairs(books) do
			bookToReportLine(s, book)
		end
		s[#s + 1] = "\n]===]"
		return table.concat(s)
	end
	generateReportToScript = function(report, books)
		--	compiles a report of all books in the system into an output script
		--	report is the report on the plugin's actions so far
		getOrCreate(ServerStorage, "Book List Report", "Script").Source = generateReportString(books)
		report[#report + 1] = ("%d unique books compiled into ServerStorage.Book List Report"):format(#books)
	end
end

local function isBook(obj)
	if obj:IsA("BasePart") and obj:FindFirstChild("BookNameFront") then
		local script = obj:FindFirstChildOfClass("Script")
		return script
	end
	return false
end
local function findAllBooks()
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
	for _, folder in ipairs({workspace.Books, workspace["Post Books"]}) do
		for _, c in ipairs(folder:GetDescendants()) do
			if isBook(c) then
				addToList(c)
			end
		end
	end
	for _, c in ipairs(workspace.BookOfTheMonth:GetDescendants()) do
		if isBook(c) then
			local source = c:FindFirstChildOfClass("Script").Source
			if not sourceToModels[source] then
				warn("No book script is the same as the one in", c:GetFullName())
			end
			addToList(c, source)
		end
	end
	local books = {}
	local n = 0
	for source, models in pairs(sourceToModels) do
		local book = sourceToBook(source, models)
		if book then
			n = n + 1
			books[n] = book
		end
	end
	return books
end

local storeReturnSame do
	local fields = {}
	-- fields["someAuthor"] = {["someTitle"] = {etc}} -- in order of dataKeyList
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

local getRidOfSpecialCharactersAndCommentsFor do
	local ReplaceInStrings = require(ServerStorage.ReplaceInStrings)
	local specials = {
		['‘'] = "'",
		['’'] = "'",
		['“'] = '"',
		['”'] = '"',
	}
	local function replaceSpecials(s, stringOpening)
		for k, v in pairs(specials) do
			local replace = v == stringOpening and "\\" .. v or v
			s = s:gsub(k, replace)
		end
		return s
	end
	local function getRidOfSpecialCharacters(s)
		return ReplaceInStrings(s, replaceSpecials)
	end
	function getRidOfSpecialCharactersAndCommentsFor(book)
		for _, model in ipairs(book.Models) do
			model.Name = getRidOfSpecialCharacters(model.Name)
		end
		local newSource = RemoveAllComments(getRidOfSpecialCharacters(book.Source), true)
		if newSource ~= book.Source then
			updateBookSource(book, newSource, allFieldsAffected)
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
local function readIdsFolder(report)
	--	stores results in idToModels, idToFolder (and also returns them)
	if idToModels then return end -- already cached (this is broken by updateIdsFolder)
	getIdsFolder()
	idToModels = {}
	idToFolder = {}
	local invalid = 0
	for _, obj in ipairs(idsFolder:GetChildren()) do
		if obj.ClassName ~= "ObjectValue" then
			warn(("Invalid value in %s: %s (a %s instead of an ObjectValue"):format(idsFolder:GetFullName(), obj.Name, obj.ClassName))
			invalid += 1
		else
			local id = tonumber(obj.Name)
			if not id then
				warn("Incorrectly named entry:", obj:GetFullName())
				invalid += 1
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
	if invalid > 0 then
		local msg = ("Detected %d invalid id entries - see warnings above for objects to remove/deal with"):format(invalid)
		if report then
			report[#report + 1] = msg
		else
			warn(msg)
		end
	end
end
local function updateIdsFolder(report, books, invalidIds)
	for _, book in ipairs(books) do
		if not book.Id or invalidIds[book.Ids] then continue end
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
		report[#report + 1] = ("Removed %d unused id entries"):format(n)
	end
	idToModels = nil
	idToFolder = nil
end
local function verifyExistingBooksHaveSameId(idToModels, invalidIds, invalidSources)
	--	invalidIds[id] = true is performed for any id that has this problem
	--	invalidSources[source] = true is also performed for all sources affected
	for id, models in pairs(idToModels) do
		if #models > 1 then
			local first = models[1]:FindFirstChildOfClass("Script").Source
			for i = 2, #models do
				local other = models[i]:FindFirstChildOfClass("Script").Source
				if first ~= other then
					warn(("%s's source is different than %s's! Select the newer book and click \"Update Copies\" to fix, then run maintenance again."):format(
						models[1]:GetFullName(),
						models[i]:GetFullName()))
					invalidSources[first] = true
					invalidSources[other] = true
					invalidIds[id] = true
				end
			end
		end
	end
end

local function assignIds(report, books, pauseIfNeeded)
	--[[Ids folder
	Contents: ObjectValue with .Name = id for the first model with 0+ ObjectValue children (nameless) for each extra model
	Purposes:
		Keeps track of the ids for each book in a place that can't easily be modified by people moving/editing books
		If we kept ids in books, then using this plugin on a book in a different place would mess things up if someone then transfers that book to this place
	]]
	readIdsFolder(report)
	local maxId = getOrCreate(getStorage(), "MaxId", "IntValue")

	local invalidIds, invalidSources = {}, {} -- id/source->true if there is an id problem and books relating to this id/source should not be given ids
	verifyExistingBooksHaveSameId(idToModels, invalidIds, invalidSources)
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
			elseif existingId ~= id then -- same source has multiple ids
				warn("CRITICAL: Same book source has multiple ids! If the books haven't been published to the live game, carefully delete the invalid ids from ServerStorage.Book Data Storage.Ids")
				warn("\tOtherwise, notify the scripting team immediately to implement an id upgrader to handle this situation! Affected books:")
				local entries = {}
				for i, model in ipairs(models) do
					local id = modelToId[model]
					entries[i] = ("\t(%s) %s"):format(id and "Id " .. id or "No id", model:GetFullName())
				end
				warn(table.concat(entries, "\n"))
				invalid = true
				break
			end
			if id and invalidIds[id] then -- already warned about
				invalid = true
				break
			end
		end
		if invalid then
			invalidSources[book.Source] = true
			for _, model in ipairs(models) do
				local id = modelToId[model]
				if id then
					invalidIds[id] = true
				end
			end
		elseif existingId then -- either they're all old or there are new copies but no inconsistencies; accept the id either way
			book.Id = existingId
		else --allNew. if it doesn't share fields with another book, add to 'new' list so it can get a new id if its source doesn't end up on the invalid list
			-- First step for new books: get rid of all special characters. We do that before storeReturnSame since we may be modifying the fields.
			--	We don't do this for all books because the operation takes ~0.01 sec per book.
			getRidOfSpecialCharactersAndCommentsFor(book)
			pauseIfNeeded()
			local other = storeReturnSame(book)
			if other then -- Same fields
				if not (invalidIfNew[other] and invalidIfNew[book]) then
					invalidIfNew[other] = true
					invalidIfNew[book] = true
					warn(other.Models[1]:GetFullName(), "has a different source but the same fields as", book.Models[1]:GetFullName() .. ". Either change the fields or make the sources the same.")
					if #other.Models > 1 then
						local entries = {}
						for i, model in ipairs(other.Models) do
							entries[i] = ("\t> %s"):format(model:GetFullName())
						end
						warn("\tCopies of first:")
						warn(table.concat(entries, "\n"))
					end
					if #book.Models > 1 then
						local entries = {}
						for i, model in ipairs(book.Models) do
							entries[i] = ("\t> %s"):format(model:GetFullName())
						end
						warn("\tCopies of second:")
						warn(table.concat(entries, "\n"))
					end
				end -- else otherwise warned already (not likely to happen, but could if 3 different variants all share same fields)
			else
				new[#new + 1] = book
			end
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
	report[#report + 1] = (numNew == 0 and "No new books detected" or numNew .. " new book ids assigned") .. (skipped > 0 and (" (%d skipped)"):format(skipped) or "")
	maxId.Value = nextId - 1
	updateIdsFolder(report, books, invalidIds)
end

local function deleteUnneededChildren(books)
	for _, book in ipairs(books) do
		for _, model in ipairs(book.Models) do
			BookChildren.RemoveFrom(model)
		end
	end
end
local function updateCoverGuis(books)
	for _, book in ipairs(books) do
		local title = book.Title
		for _, model in ipairs(book.Models) do
			BookChildren.UpdateGuis(model, title)
		end
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
		print(shelf:GetFullName(), bookModel:GetFullName(), relCF, desiredFace)
		warn("Error: Didn't find genreText with desired face")
		return nil
	end
end
local getSupportMultiShelfBooks = getSetting("Allow the same book on different shelf genres", true)
local function verifyGenres(report, books)
	local noShelfBooks = {}
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
			warn(("%s's genres contain invalid entries: %s"):format(book.Models[1]:GetFullName(), table.concat(invalid, ", ")))
		end
		-- Find genre from shelf (if any)
		local genreInput
		local supportMultiShelfBooks = getSupportMultiShelfBooks()
		local multiShelf = supportMultiShelfBooks or {} -- if not supportMultiShelfBooks, [genre input] = model
		local multiShelfDetected = false -- only true if supportMultiShelfBooks
		local shelfBookModel -- the model that the shelf genreInput was found on
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
			noShelfBooks[#noShelfBooks + 1] = book
		else
			if multiShelfDetected then
				local list = {"A book's copies are located on multiple shelves of different genres:"}
				for input, model in pairs(multiShelf) do
					list[#list + 1] = ("%s: %s"):format(input, model:GetFullName())
				end
				warn(table.concat(list, "\n\t"))
			end
			local genre = Genres.InputToGenre(genreInput)
			if not genre and not shelfGenreWarnings[genreInput] then
				warn(("Shelf (near %s) was labelled with unknown genre '%s'"):format(shelfBookModel:GetFullName(), genreInput))
				shelfGenreWarnings[genreInput] = true
			end
			if genre and not table.find(genres, genre) then
				warn(("%s is on shelf %s (genre %s) but is lacking that genre!"):format(
					book.Models[1]:GetFullName(),
					genreInput,
					genre))
			end
		end
		if modified then -- Update script with modified genres
			local success, source = modifySourceVarList(book.Source, "genres", genres, book.Models[1])
			if success then
				updateBookSource(book, source)
			end
		end
	end
	if genreFixes > 0 then
		report[#report + 1] = ("%d genre tags fixed"):format(genreFixes)
	end
	if #noShelfBooks > 0 then
		local compiled = {("The %d following books have no copies on any shelf:"):format(#noShelfBooks)}
		for i, book in ipairs(noShelfBooks) do
			compiled[i + 1] = book.Models[1]:GetFullName()
		end
		report[#report + 1] = table.concat(compiled, "\n\t")
	end
end

local function removeUnnecessaryWelds(report)
	local n = 0
	local locations = {workspace, game:GetService("ServerScriptService"), game:GetService("ServerStorage"), game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage"), game:GetService("Lighting"), game:GetService("StarterGui"), game:GetService("StarterPack")}
	for _, location in ipairs(locations) do
		for _, obj in ipairs(location:GetDescendants()) do
			if obj:IsA("Weld") or obj:IsA("ManualWeld") then
				if not obj.Part0 or not obj.Part1 or (obj.Part0.Anchored and obj.Part1.Anchored) then
					n = n + 1
					obj.Parent = nil
				end
			end
		end
	end
	if n > 0 then
		report[#report + 1] = ("%d unnecessary welds removed"):format(n)
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
local tryMaintenanceLock = GenLock()
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

	tryMaintenanceLock(getStorage(), function()
		local pauseIfNeeded = genPauseIfNeeded(1)
		local books = findAllBooks()
		local report = {}
		assignIds(report, books, pauseIfNeeded)
		-- note: books don't have .Id until after assignIds, and invalid books never get an id
		updateAuthorInformation(report, books); pauseIfNeeded()
		verifyGenres(report, books); pauseIfNeeded()
		deleteUnneededChildren(books); pauseIfNeeded()
		updateCoverGuis(books); pauseIfNeeded()
		removeUnnecessaryWelds(report); pauseIfNeeded()
		generateReportToScript(report, books)
		print(table.concat(report, "\n"))
		onMaintenanceFinished()
	end)


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
run() -- debug

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
				print("(That's the only copy of that book)")
			else
				print("Updated", #models - 1, "copies")
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