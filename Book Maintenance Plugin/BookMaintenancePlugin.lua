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

-- In this script, a "book" is its BasePart
--	It is expected to have a script child (any name; the script must have a BookColor child) and also a ClickDetector child
--	(These are searched for in isBook)

local sourceToData do
	local function genGetData(var)
		local find = "local " .. key .. '%s*=?%s*"([^"\n])"'
		return function(source)
			local _, _, data = source:find(find)
			return data ~= "" and data or nil
		end
	end
	local getAuthorLine = genGetData("customAuthorLine")
	local function genGetListData(var)
		local find = "local " .. key .. '%s*=?%s*"([^"\n])"'
		return function(source)
			local _, _, data = source:find(find)
			if not data or data == "" then return nil end
			-- data will be in format '"a", "b", "c"', but we want "a, b, and c"
			local new = {}
			for _, v in ipairs(data:gsub('"', ""):split(",")) do
				v = String.Trim(v)
				if v ~= "" then
					new[#new + 1] = v
				end
			end
			return #new > 0 and List.ToEnglish(new) or nil
		end
	end
	local getAuthorNames = genGetListData("authorNames")
	local dataProps = {
		Title = genGetData("title"),
		Authors = function(source) return getAuthorLine(source) or getAuthorNames(source) end,
		PublishDate = genGetData("PublishDate"),
		Librarian = genGetData("Librarian"),
		Genres = genGetListData("Genres"),
	}
	sourceToData = function(source, models)
		local data = {Models = models}
		for k, v in pairs(dataProps) do
			data[k] = v(source)
		end
		return data
	end
end

local generateReportToScript do
	local reportTable = {
		-- Header, width, data key (defaults to header)
		{"Title", 40},
		{"Author(s)", 30, "Authors"},
		{"Published On", 14, "PublishDate"},
		{"Librarian", 20},
		{"Copies", 10, function(book) return #book.Models end}
		{"Genres", 200},
	}
	for _, report in ipairs(reportTable) do
		local key = report[3] or report[1]
		if type(key) == "string" then
		report[3] = function(book) return book[key] end
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
		addHeaderLine(s, books)
		for _, book in ipairs(books) do
			bookToReportLine(s, books)
		end
		s[#s + 1] = "\n]===]")
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
	if obj:IsA("BasePart") and obj:FindFirstChild("ClickDetector") then
		local script = obj:FindFirstChildOfClass("Script")
		return script and script:FindFirstChild("BookColor")
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

local function readIdsFolder(report, idsFolder)
	--	returns idToModels, idToFolder
	local idToModels = {}
	local idToFolder = {}
	local invalid = 0
	for _, obj in ipairs(idsFolder:GetChildren()) do
		if obj.ClassName ~= "ObjectValue" then
			warn(("Invalid value in %s: %s (a %s instead of an ObjectValue"))
			invalid += 1
		else
			local id = tonumber(obj.Name)
			if not id then
				warn("Incorrectly named entry:", idsFolder:GetFullName())
				invalid += 1
			else
				local models = {}
				local function considerAdd(value)
					if value and workspace:IsAncestorOf(value) then
						models[#models + 1] = value
					end
				end
				considerAdd(obj.Value)
				local _, c in ipairs(obj:GetChildren()) do
					considerAdd(c.Value)
				end
				idToModels[id] = models
				idToFolder[id] = obj
			end
		end
	end
	if invalid > 0 then
		report[#report + 1] = ("Detected %d invalid id entries - see warnings above for objects to remove/deal with"):format(invalid)
	end
end
local function updateIdsFolder(report, idsFolder, idToFolder, books)
	for _, book in ipairs(books) do
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
		for i = #models - 1, #children do
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
end
--[[Thoughts

To handle someone changing one source:
	There should be a button to say "Update Copies" - based on selected
	(It should run maintenance if there is no id for the selected book.)

	If someone doesn't press the button, the plugin will see two different sources with the same id
		If the fields are almost all the same, it might be the same book
		But there's never a way to tell for sure

	Unless we store the source (or a hash of it, which would be more processing)

The question is if someone changes the source of one book but not its copies, what to do?
um so like for BOTM and post (the copies)
Right, and I think on some displays the same book might be in workspace.Books 2x or more
Ok but they won't have the same part name only the title (most of the time)

The process is this:
	-They transfer the book and optionally make copies
	-This plugin runs and assigns the book an ID. It detects copies based on scripts having the same source
	-If someone changes the source of only 1 of those copies,
	we're left with 2+ books that have the same ID but we're not sure if it's a new book or someone failed to update them
oh then  you should just compare by title since we don't change it much

	what if the title is what they changed/updated?
	uh

1. Books have an id as a child
	If discrepency, we don't know if the odd book out is new (moved from other place) or incorrectly updated
	> but ObjectValues will refer to the book!* <-- TODO act on this
		> this is the case regardless of if books have an id
2. Books don't have an id as child
	If discrepency,

* the plan is to have
ServerStorage.Book Data Storage.Ids
	[id#]:ObjectValue = 1st copy
		[""]:ObjectValue = 2nd copy <-- repeat this as many times as needed


Books will read from storage whenever a book registers (to determine its id)
Books:
	Server scripts can figure out the id of a reference and store it in 'books' (repl'd to client)

Do the ids even need to be there? No!
SelectScript could ask via book ref



]]

local function assignIds(report, books)
	local new = {} -- list of new books (each entry is the list of models)
	local storage = getOrCreate(ServerStorage, "Book Data Storage", "Folder")
	local idsFolder = getOrCreate(storage, "Ids", "Folder")
	--[[Ids folder
	Contents: ObjectValue with .Name = id for the first model with 0+ ObjectValue children (nameless) for each extra model
	Purpose: protect against possibility that a book was already given an id (manually or by this plugin in a different place)
	Each book that does not have an id in this folder can have its id removed if there's anything wrong with it
	]]
	local idToModels, idToFolder = readIdsFolder(report, idsFolder)
	local maxId = getOrCreate(storage, "MaxId", "IntValue")
	local maxIdExisted = maxId.Value ~= 0
	--[[
	can we just update the ids based on the internal?
		*or* we could even generate the ids at runtime rather than at edit time


	for each set of models
		if the list has inconsistent ids:
			if it's a new book according to idToModels, delete the id
			else if it used to have a different id, revert
		if the list is consistent but some lack, clone to the ones that lack
		if the list has none, add to new
	]]
	for _, book in ipairs(books) do
		local models = book.Models
		-- Check to see if there are any inconsistencies and verify id values
		local id
		local inconsistent, invalid = false, false
		for _, model in ipairs(models) do
			local curId = model:FindFirstChild("Id")
			if curId then
				if curId.Value <= 0 or curId.Value % 1 ~= 0 then
					warn("Ids must be positive integers, not", curId.Value, model:GetFullName())
					invalid = true
					break
				elseif curId.Value > maxId.Value and maxId.Value > 0 then
					warn("Id likely edited manually (it is larger than expected):", curId.Value, model:GetFullName())
					invalid = true -- a way-too-large ID would mean that all IDs have to be at least that large from now on, so we skip this
					break
				end
				if id then
					if id.Value ~= curId.Value then
						inconsistent = true
						break
					end
				else
					id = curId
				end
			end
		end
		if invalid then
			continue
		elseif inconsistent then
			local t = {}
			for i, model in ipairs(models) do
				local id = model:FindFirstChild("Id")
				t[i] = ("%s (%s)"):format(model:GetFullName(), id and id.Value or "nil")
			end
			warn("Book duplicates have inconsistent ids:", table.concat(t, ", "))
			continue
		end
		if id then -- Fill in any missing ids
			book.Id = id
			for _, model in ipairs(models) do
				if not model:FindFirstChild("Id") then
					id:Clone().Parent = model
				end
			end
		else -- Add to new list
			new[#new + 1] = book
		end
	end
	local nextId = maxId.Value + 1
	for _, book in ipairs(new) do
		local id = Instance.new("IntValue")
		id.Name = "Id"
		id.Value = nextId
		book.Id = nextId
		nextId = nextId + 1
		local models = book.Models
		id.Parent = models[1]
		for i = 2, #models do
			id:Clone().Parent = models[i]
		end
	end
	report[#report + 1] = ("%d new book IDs assigned"):format(nextId - 1 - maxId.Value)
	maxId.Value = nextId - 1
	updateIdsFolder(report, idsFolder, idToFolder, books)
end

local function deleteUnneededChildren(books)
	for _, book in ipairs(books) do
		for _, model in ipairs(books.Models) do
			BookChildren.RemoveFrom(model)
		end
	end
end
local function updateCovers(books)
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
	for _, book in ipairs(books) do
		local newSource
		for _, model in ipairs(books.Models) do
			local s = model:FindFirstChildOfClass("Script")
			newSource = newSource or getRidOfSpecialCharacters(s.Source)
			s.Source = newSource
			book.Name = getRidOfSpecialCharacters(book.Name)
		end
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
local bookMaintenanceButton = toolbar:CreateButton("Book Maintenance", "Run book maintenance", "")
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
	assignIds(report, books) -- note: books don't have .Id until after this
	deleteUnneededChildren(books)
	updateCovers(books)
	getRidOfAllSpecialCharacters(books)
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