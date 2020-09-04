--[[Book Maintenance Plugin
Responsibilities:
-Assign Ids to any books that don't have them
-Update cover label gui (via BookChildren.UpdateGuis)
-Remove unnecessary children (via BookChildren.RemoveFrom)
-Auto-detect book's genre and auto-add to list of genres
-Make sure all other genres are valid ones (compile a report of violations)
-Replace all fancy quotation marks with simple equivalents (in both script source and part name)
-Compile list of books with title, author, and all other available data into an output script
-Remove unnecessary welds
]]
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BookChildren = require(ServerScriptService.BookChildren)
local Genres = require(ServerScriptService.Genres)
local Utilities = game:GetService("ReplicatedStorage").Utilities
local String = require(Utilities.String)
local List = require(Utilities.List)

-- In this script, a "model" is the BasePart of a book. A "book" refers to a table with fields including Title, Author, Models, and Source.

local sourceToData, dataKeyList do
	local function genGetData(key)
		local find = "local%s+" .. key .. '%s*=?%s*"([^"\n])"'
		return function(source)
			local _, _, data = source:find(find)
			return data ~= "" and data or nil
		end
	end
	local getAuthorLine = genGetData("customAuthorLine")
	local function genGetListData(key)
		-- todo: wrong format (need var = {"a", "b", "c", false})
		--local find = "local " .. key .. '%s*=?%s*"([^"\n])"'
		local find = "local%s+" .. key .. '%s*=?%s*%{([^}]*)%}'
		return function(source, model)
			local _, _, data = source:find(find)
			if not data or data == "" then return nil end
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
	sourceToData = function(source, models)
		local data = {
			Models = models,
			Source = source,
		}
		local model = models[1]
		for k, v in pairs(dataProps) do
			data[k] = v(source, model)
		end
		data.Authors = data.CustomAuthorLine or List.ToEnglish(data.AuthorNames)
		return data
	end
	dataKeyList = {"Title", "Authors", "PublishDate"} -- different books with these fields identical are not allowed
end

-- local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local function getUsername(userId)
	local success, username = pcall(Players:GetNameFromUserIdAsync(userId))
	if success then
		return username
	else
		local isBanned = username:find("HTTP 400") -- thatll work too loool
		-- I still want to know: what do we want to do if we find out they're banned?
		-- I guess we could invalidate their id (turn them into anonymous)
		-- smart
		-- hmm
		-- oh yea thats what i said before make it false
		-- if they're banned, then we can do something useful (though idk what?)
		-- we might as well use the proxy to check for banned users too
		--occurs for id 4 (banned user):
		--			Players:GetNameFromUserId() failed because HTTP 400 (BadRequest)
		-- if the service is down, we need to "cool down" and try again later
		return pcall(Players:GetNameFromUserIdAsync(userId))
	end
--	return HttpService:GetAsync("https://get-username.glitch.me/" .. userId)
end
--[[
get username
if 400, banned, so add a "banned" tag as a child. Maintenance must notice this and set author id to false in source and remove from data base
if any other error, warn (we need to deal with it at that time) and don't try again for that user for 1 minute
	if the warning has already occurred, don't repeat it
	if it has occurred 60x in this session, stop for 15 minutes and reset the count
if username different, add a "new" username StringValue as a child. Maintenance must notice this and update the author names for all scripts that have that author id.
except for unknown errors, advance the time to check this username/id pair by 1 week (7*24*3600)
]]
-- trying something:
-- local banned = {}
-- for i = 1234567, 1234567 + 100 do
-- 	local a, b = pcall(function() Players:GetNameFromUserIdAsync(i) end)
-- 	if not a then
-- 		if b ~= "Players:GetNameFromUserId() failed because HTTP 400 (BadRequest)" then
-- 			print(i, b)
-- 		end
-- 		banned[#banned + 1] = tostring(i)
-- 	end
-- end
-- print(#banned, "banned", table.concat(banned, ", "))
--12 banned 4, 5, 7, 9, 10, 11, 12, 13, 14, 15, 19, 20

-- I tried a bunch more #s and none of them came back with a different error message
--	I still wonder if a temporarily banned/suspended person would yield a different one - I have seen Roblox's website do 2 dif things for that, so idk if the function acts any differently

--[[We need a plan for how we can avoid asking Roblox for 3k author ids at once
Ideas:
-In ServerStorage, have a database of when we last checked a username/id connection and only check it periodically
-If we get a '429' in an error msg, we know we need to not make any more requests for a while (even if none have been made)
	-If we get a different error message, warn in Output
-What do we do if we get a different error message? Probably also do nothing for like 5 minutes?
-Yea and inform the book mover (person who moved the books and pressed the book maintanence button)

Idea:
-We could start up this routine that gradually checks for ids/usernames when the plugin loads without any user input at all
	(but only if there is book storage data)
oh ya
Does that seem okay to do?
	you need someone in studio tho (I think)
	o lol
	Yes, but I don't think someone has to *stay* in studio - I mean, we should make it so that it spreads things out while you're in there
	not so slow that you'd have to stay in there 24/7 for things to get updated xD

Another idea:
-Maybe this routine should mark things as "needs to be changed" but doesn't try to make the changes?
	(Not sure if that's a good idea?)
	oh
	The maintenance script would update it when it's explicitly run by the user
	I think it might be a good idea to not change book sources automatically, especially because I don't want a script source changed if it doesn't have an id
		or if it's configured poorly and needs manual fixing before the maintenance script is happy
		the routine wouldn't know without running the whole analysis whether a script is valid or not
		ok
cool, that makes the routine simpler
it's job is to not-too-fast ask Roblox for ids that haven't been checked in... a week?
yes
and to update the "database" with what it finds

the maintenance script must record all author ids and their usernames (ignoring anonymous ones) so the routine knows what to look for
Book Data Storage
	.ErrorCooldown:time when the routine may resume due to an error
	.Authors
		IntValue authorId whose name is the username
			IntValue NextCheck time (based on os.time()). We just add the proper # of seconds when a check has been made.
			ObjectValue that points to the player whose plugin is looking it up (ObjectValue is not archivable and normally doesn't exist)
			> A plugin should set the parent of its ObjectValue to the thing it wants to look up, then wait a moment and make sure it's the only ObjectValue in that child
			> It shouldn't have to wait at all if you're the only client connected (based on Players)

			We should check - what happens if you ask for a banned user?
			uhm just delete the id and put false

I meant what happens to the proxy/app you setup -- but that's a good point too
         #2 == "John Doe" with 502k followers
lol - id #3 == "Jane Doe"
ah, #4 is 404, so let's see...

the routine must leave the list of "these have changed" somewhere for the maintenance script to find
	could just be a child of the entries above

also, if 2+ people have the plugin and are in the place at the same time, they must be careful not to do the same work! yes


]]

local generateReportToScript do
	local reportTable = {
		-- Header, width, data key (defaults to header)
		{"Title", 40},
		{"Author(s)", 30, "Authors"},
		{"Published On", 14, "PublishDate"},
		{"Librarian", 20},
		{"Copies", 10, function(book) return #book.Models end},
		{"Genres", 200},
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
			and s:sub(1, width - 4) .. "... "
			or s .. string.rep(" ", width - #s)
	end
	local function addHeaderLine(s)
		for _, report in ipairs(reportTable) do
			s[#s + 1] = leftAlign(report[1], report[2])
		end
		s[#s + 1] = "\n"
	end
	local function bookToReportLine(s, book)
		--	s: report string so far (table)
		for _, report in ipairs(reportTable) do
			s[#s + 1] = leftAlign(report[3](book), report[2])
		end
		s[#s + 1] = "\n"
	end
	local function generateReportString(books)
		local s = {"--[===[\n"}
		addHeaderLine(s)
		for _, book in ipairs(books) do
			bookToReportLine(s, books)
		end
		s[#s + 1] = "\n]===]"
		return table.concat(s)
	end
	generateReportToScript = function(report, books)
		--	compiles a report of all books in the system into an output script
		--	report is the report on the plugin's actions so far
		local s = ServerStorage:FindFirstChild("Book List Report")
		if not s then
			s = Instance.new("Script")
			s.Parent = ServerStorage
		end
		s.Source = generateReportString(books)
		report[#report + 1] = ("%d unique books compiled into ServerStorage.Book List Report"):format(#books)
	end
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
		n = n + 1
		books[n] = sourceToData(source, models)
	end
	return books
end

local storeReturnSame do
	local fields = {}
	-- fields["someAuthor"] = {["someTitle"] = {etc}} -- in order of dataKeyList
	local function getOrCreate(t, k)
		local v = t[k]
		if not v then
			v = {}
			t[k] = v
		end
		return v
	end
	local function valueToString(v)
		return type(v) == "table" and table.concat(v, "\127") or tostring(v)
	end
	local numDataKeyList = #dataKeyList
	storeReturnSame = function(book)
		--	Store book in 'fields', unless another book is found that has the same fields (in which case it is returned)
		local t = fields
		for i = 1, numDataKeyList - 1 do
			t = getOrCreate(book[dataKeyList[i]])
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

local storage
local function getStorage()
	if not storage then
		storage = getOrCreate(ServerStorage, "Book Data Storage", "Folder")
	end
	return storage
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
		if invalidIds[book.Ids] then continue end
		local sId = tostring(book.Id)
		local folder = idToFolder[sId]
		if folder then
			idToFolder[sId] = nil
		else
			folder = Instance.new("ObjectValue")
			folder.Name = sId
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
	report[#report + 1] = ("Removed %d unused id entries"):format(n)
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

local function assignIds(report, books)
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
		local allNew = true
		local allOld = true
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
			if id then
				allOld = false
				if invalidIds[id] then -- already warned about
					invalid = true
					break
				end
			else
				allNew = false
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
		elseif not allNew then -- either they're all old or there are new copies but no inconsistencies; accept the id either way
			book.Id = existingId
		else --allNew. if it doesn't share fields with another book, add to 'new' list so it can get a new id if its source doesn't end up on the invalid list
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
	report[#report + 1] = ("%d new book ids assigned%s"):format(
		nextId - 1 - maxId.Value,
		skipped > 0 and ("(%d skipped)"):format(skipped) or "")
	maxId.Value = nextId - 1
	updateIdsFolder(report, books, invalidIds)
end

local function deleteUnneededChildren(books)
	for _, book in ipairs(books) do
		for _, model in ipairs(books.Models) do
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
local function getRidOfSpecialCharacters(s)
	return s:gsub("[‘’]", "'"):gsub("[“”]", '"')
end
local function getRidOfAllSpecialCharacters(books)
	for i, book in ipairs(books) do
		local newSource = getRidOfSpecialCharacters(book.Source)
		if newSource == book.Source then
			newSource = false
		else
			books[i] = sourceToData(newSource, book.Models) -- recalculate fields (the transformation may have modified them)
		end
		for _, model in ipairs(books.Models) do
			if newSource then
				model:FindFirstChildOfClass("Script").Source = newSource
			end
			book.Name = getRidOfSpecialCharacters(book.Name)
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
	function getGenreInputFromShelf(book)
		local shelf = getShelfFromBook(book)
		if not shelf then return nil end
		local relCF = shelf.CFrame:ToObjectSpace(book.CFrame)
		local desiredFace = relCF.Z > 0 and Enum.NormalId.Back or Enum.NormalId.Front
		for _, genreText in ipairs(shelf:GetChildren()) do
			if genreText.Face == desiredFace then
				return genreText.TextLabel.Text, shelf
			end
		end
		print(shelf:GetFullName(), book:GetFullName(), relCF, desiredFace)
		warn("Error: Didn't find genreText with desired face")
		return nil
	end
end
local function updateBookSource(book, source)
	book.Source = source
	for _, model in ipairs(book.Models) do
		model:FindFirstChildOfClass("Script").Source = source
	end
end
local function listToTableContents(list)
	--	ex the list {false, "hi"} -> the string 'false, "hi"' (suitable for storing in a script)
	local new = {}
	for i, item in ipairs(list) do
		new[i] = type(item) == "string" and ('"%s"'):format(item) or tostring(item)
	end
	return table.concat(new, ", ")
end
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
		for _, model in ipairs(book.Models) do
			local input = getGenreInputFromShelf(book.Models)
			if input then
				if genreInput and genreInput ~= input then
					-- NOTE: Could warn about different copies being on different shelves
					-- However, theoretically this might be desired (ex due to the same book being in different genres)
				else
					genreInput = input
					break -- Note: if we want to warn about different copies on different shelves, delete this line
				end
			end
		end
		if not genreInput then
			noShelfBooks[#noShelfBooks + 1] = book
		else
			local genre = Genres.InputToGenre(genreInput)
			if not genre and not shelfGenreWarnings[genreInput] then
				warn("Shelf was labelled with unknown genre", genreInput)
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
			local source = book.Source
			local _, lastCharToKeep = source:find("local%s+genres%s*=%s*%{")
			if not lastCharToKeep then -- implies scripting bug
				warn("Attempt to update genres source failed for", book.Models[1]:GetFullName())
				continue
			end
			local _, lastCharToThrow = source:find("}", lastCharToKeep, true)
			if not lastCharToThrow then -- implies scripting bug
				warn("Attempt to update genres source failed for", book.Models[1]:GetFullName())
				continue
			end
			updateBookSource(book, ("%s%s%s"):format(
				source:sub(1, lastCharToKeep),
				listToTableContents(genres),
				source:sub(lastCharToThrow + 1)))
		end
	end
	if genreFixes > 0 then
		report[#report + 1] = ("%d genre tags fixed"):format(genreFixes)
	end
	if #noShelfBooks > 0 then
		local compiled = {}
		for i, book in ipairs(noShelfBooks) do
			compiled[i] = book.Models[1]:GetFullName()
		end
		report[#report + 1] = ("The %d following books have no copies on any shelf:\n\t%s"):format(#noShelfBooks, table.concat(compiled, "\n\t"))
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
	report[#report + 1] = ("%d useless welds removed"):format(n)
end

local toolbar = plugin:CreateToolbar("Book Maintenance")
local bookMaintenanceButtonSelection = toolbar:CreateButton("Update\nCopies", "Update other copies of the selected book to reflect new script changes", "")
local Selection = game:GetService("Selection")
bookMaintenanceButtonSelection.Click:Connect(function()
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
			return
		end
	end
	-- Due to above return, we only get here if no id found for selected book
	warn("The selected book does not have an id. Run the maintenance plugin to assign new ids.")
end)
local bookMaintenanceButton = toolbar:CreateButton("Run", "Run book maintenance", "")
-- local scanningCons
-- local analysisRunning
bookMaintenanceButton.Click:Connect(function()
	-- todo let this toggle scanning?
	-- if scanningCons then
	-- 	for _, con in ipairs(scanningCons) do
	-- 		con:Disconnect()
	-- 	end
	-- 	scanningCons = nil
	-- 	print("Book Maintenance Scanning Stopped")
	-- else
	-- 	analysisRunning = true

	local books = findAllBooks()
	local report = {}
	-- todo books below is supposed to be bookData with .Models .Title etc
	assignIds(report, books) -- note: books don't have .Id until after this, and invalid books never get an id
	getRidOfAllSpecialCharacters(books)
	verifyGenres(report, books)
	deleteUnneededChildren(books)
	updateCoverGuis(books)
	removeUnnecessaryWelds(report)
	generateReportToScript(report, books)
	print(table.concat(report, "\n"))

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
end)