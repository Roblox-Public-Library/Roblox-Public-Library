local MAKE_CHANGES = true -- false for debugging
local PRINT_LIBRARIAN_REPORT = false
local SCAN_FOR_AUTHORS = false -- should be false normally; if this is true, MAKE_CHANGES will be set to false
local CONVERT_AUTHORS = false -- if true, the above options will be set to false
--local ALLOW_REPLACING_AUTHOR_NAMES = true -- for when MAKE_CHANGES is active

if SCAN_FOR_AUTHORS or CONVERT_AUTHORS then MAKE_CHANGES = false end
if CONVERT_AUTHORS then SCAN_FOR_AUTHORS = false end

local ServerScriptService = game:GetService("ServerScriptService")
local Genres = require(ServerScriptService.Genres:Clone()) -- clone allows us to keep modifying Genres
local Utilities = game:GetService("ReplicatedStorage").Utilities
local String = require(Utilities.String)
local List = require(Utilities.List)

local ServerStorage = game:GetService("ServerStorage")
local userIdToName = (not CONVERT_AUTHORS and not SCAN_FOR_AUTHORS) and require(ServerStorage.AuthorDataFiltered) or {}
local userNameToId = {}
for id, name in pairs(userIdToName) do
	userNameToId[name] = id
end

local function desc(obj)
	return obj:GetFullName():gsub("Workspace%.", ""):gsub("BookEventScript%(This is what you edit%. Edit nothing else%.%)", "BookScript")
end

local wordStartBorder = "%f[%w_]"
local wordEndBorder = "%f[^%w_]"
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
		local trueStart, firstEnd = source:find(first)
		if not trueStart then
			trueStart, firstEnd = source:find(firstAlt)
		end
		if not trueStart then return nil end
		local _, start = source:find(second, firstEnd + 1)
		if not start then return trueStart, firstEnd, nil end
		start += 1
		for i, find in ipairs(finds) do
			local _, trueEnd, data, data2 = source:find(find, start)
			if data then
				data = useSecondData[i] and data2 or data
				return trueStart, trueEnd, data ~= "" and data or nil
			end
		end
		return nil
	end
end
local function genGetLineData(key)
	local first = "^local%s+" .. key .. wordEndBorder
	local firstAlt = "\nlocal%s+" .. key .. wordEndBorder
	local second = "^[ \t]*\n?[ \t]*=[ \t]*\n?[ \t]*([^\n]*)"
	return function(source)
		local startIndex, firstEnd = source:find(first)
		if not firstEnd then
			startIndex, firstEnd = source:find(firstAlt)
		end
		if not startIndex then return nil end
		local _, finalIndex, data = source:find(second, firstEnd + 1)
		if not finalIndex then
			return startIndex, firstEnd
		end
		if data == "" then
			data = nil
		end
		return startIndex, finalIndex, data
	end
end
local getAuthorId = genGetData("authorID")
local getAuthorName = genGetData("authorName")
local getOther = {} -- things we add to this but don't use in modifySource will be deleted
local getLibrarian = genGetData("librarian")
local getEditor = genGetData("editor")
for _, var in ipairs({"customAuthorLine", "title", "cover", "publishDate"}) do
	getOther[var] = genGetData(var)
end
getOther.librarian = function(source)
	local a, b, c = getLibrarian(source)
	if a then return a, b, c end
	return getEditor(source)
end
for _, var in ipairs({"authorIDs", "authorNames", "authorsNote", "bookColor", "titleTextColor", "titleStrokeColor"}) do
	getOther[var] = genGetLineData(var)
end

local detectPublishDateFormat, getLibrarianPutsDayFirst, librarianDateReport do
	local librarianPutsDayNums = {} -- librarian -> [# day first, # day second, #ambig]
	local function addLibrarian(librarian)
		librarianPutsDayNums[librarian] = librarianPutsDayNums[librarian] or {0, 0, 0}
	end

	local function librarianPutsDayFirst(librarian, value)
		librarianPutsDayNums[librarian][1] += 1
	end
	local function librarianPutsDaySecond(librarian, value)
		librarianPutsDayNums[librarian][2] += 1
	end
	local function librarianPutsDayAmbig(librarian, value)
		librarianPutsDayNums[librarian][3] += 1
	end
	function getLibrarianPutsDayFirst(librarian)
		local values = librarianPutsDayNums[librarian]
		if not values then return false end
		return values[1] > values[2]
	end
	function detectPublishDateFormat(obj)
		local source = obj.Source
		local _, _, librarian = getOther.librarian(source)
		if not librarian then
			print(desc(obj), "does not have a librarian!")
			return
		end
		addLibrarian(librarian)
		local _, _, publishDate = getOther.publishDate(source)
		if not publishDate then
			print(desc(obj), "does not have a publish date!")
			return
		end
		local nums = publishDate:split("/")
		if #nums == 1 then nums = publishDate:split("-") end
		local success = false
		if #nums == 3 then
			local n1 = tonumber(nums[1])
			local n2 = tonumber(nums[2])
			local n3 = tonumber(nums[3])
			if n1 and n2 and n3 then
				success = true
				if n1 > 12 then
					librarianPutsDayFirst(librarian)
				elseif n2 > 12 then
					librarianPutsDaySecond(librarian)
				else
					librarianPutsDayAmbig(librarian)
				end
			end
		end
		if not success then
			print(desc(obj), "has non-standard date:", publishDate)
		end
	end
	function librarianDateReport()
		for librarian, nums in pairs(librarianPutsDayNums) do
			print(librarian, (nums[1] == 0 and nums[2] == 0 and (nums[3] == 0 and "no dates" or "!ambiguous!"))
				or (nums[1] > 0 and nums[2] == 0) and "first"
				or (nums[1] == 0 and nums[2] > 0) and "second" or "BOTH", unpack(nums))
		end
	end
end

local function trimEach(t)
	for i, v in ipairs(t) do
		t[i] = String.Trim(v)
	end
	return t
end
local function splitAuthorIdsField(authorIdsField)
	return trimEach(authorIdsField:gsub(" and", ","):gsub("/", ""):split(", ")) -- gsub cases are for one book each
end
local function splitAuthorNameField(authorNameField)
	return trimEach(authorNameField:gsub(" &", ","):split(", "))
end
local numAuthorsNoId = 0
local function modifySource(source, genres, model)
	--	Also deletes things added to getOther (most are transformed below, the rest we don't want to keep)
	local remove = {} -- List<{startIndex, endIndex}>
	local function get(func)
		local startIndex, endIndex, data = func(source)
		if startIndex then
			remove[#remove + 1] = {startIndex, endIndex}
		end
		return data
	end
	local authorIdsField = get(getAuthorId)
	local authorIds = authorIdsField and splitAuthorIdsField(authorIdsField)
	local authorNameField = get(getAuthorName)
	local authors = authorNameField and splitAuthorNameField(authorNameField)
	if authors or authorIds then
		authors = authors or {}
		authorIds = authorIds or {}
	end
	local data = {}
	for var, func in pairs(getOther) do
		data[var] = get(func)
	end
	if authors then
		for i, author in ipairs(authors) do
			local id = userNameToId[author]
			authors[i] = ('"%s"'):format(author)
			authorIds[i] = id and tostring(id) or "false"
			if not id then
				numAuthorsNoId += 1
			end
		end
	end
	if genres then
		for i, genre in ipairs(genres) do
			genres[i] = ('"%s"'):format(genre)
		end
	end
	local publishDate = data.publishDate
	if publishDate then
		local nums = publishDate:split("/")
		if #nums == 1 then nums = publishDate:split("-") end
		if #nums == 3 then
			local a, b = tonumber(nums[1]), tonumber(nums[2])
			-- We want month/day/year
			local switch = false
			if a and b then
				if a > 12 then
					switch = true
				elseif b <= 12 and data.librarian then -- b <= 12 means ambiguous case, so what does librarian normally do?
					switch = getLibrarianPutsDayFirst(data.librarian)
				end
			end
			if switch then
				nums[1], nums[2] = nums[2], nums[1]
			end
			if #nums[3] == 2 then nums[3] = "20" .. nums[3] end
			publishDate = ("%s/%s/%s"):format(unpack(nums))
		elseif publishDate == "21 October 2019" then -- 1 special case
			publishDate = "10/21/2019"
		end
	end
	local customAuthorLine = data.customAuthorLine
	if not customAuthorLine and authorNameField then
		local standardAuthorLine
		if authors then -- each author entry is wrapped in quotes
			local new = {}
			for i, author in ipairs(authors) do
				new[i] = author:sub(2, -2)
			end
			standardAuthorLine = List.ToEnglish(new)
		else
			-- if authorNames exists then it'll be the string '{"a", "b"}'
			standardAuthorLine = data.authorNames and List.ToEnglish(data.authorNames:gsub("[{}\"]+", ""):split(", ")) or ""
		end
		if standardAuthorLine ~= String.Trim(authorNameField) then
			customAuthorLine = authorNameField
		end
	end
	local s = {([=[
local title = "%s"
local authorNames = %s
local authorIds = %s
local customAuthorLine = "%s"
local authorsNote = %s
local genres = {%s}

local cover = "%s"
local librarian = "%s"
local publishDate = "%s"
]=]):format(
		data.title or "",
		authors and ("{%s}"):format(table.concat(authors, ", ")) or data.authorNames or "{}",
		authorIds and ("{%s}"):format(table.concat(authorIds, ", ")) or data.authorIDs or "{}",
		customAuthorLine or "",
		data.authorsNote or '""',
		genres and table.concat(genres, ", ") or "",

		data.cover or "",
		data.librarian or "",
		publishDate or "")}

	table.sort(remove, function(a, b) return a[1] < b[1] end)
	local i = 1
	for _, obj in ipairs(remove) do
		local start, final = obj[1], obj[2]
		if start > i then
			s[#s + 1] = source:sub(i, start - 1)
		end
		i = final + 1
	end
	s[#s + 1] = source:sub(i, #source)
	source = table.concat(s)
	-- Have to do this in 2 steps because sometimes there are vars to remove under 'local words = paragraphs' (but not always)
	local eStart = source:find("local words = paragraphs") -- find where it starts and don't include it in the new source
	s = {}
	if eStart then
		s[1] = source:sub(1, eStart - 1) -- includes a newline
	else
		-- local paragraphsStart, paragraphsEnd = source:find("local paragraphs = {[^\n]*}[ \t]*\n")
		-- if paragraphsStart and source:sub(paragraphsEnd + 1):find("^local words =")
		s[1] = source
		s[2] = "\n"
		print(desc(model), "does not have `local words = paragraphs`!")
	end
	s[#s + 1] = 'require(game:GetService("ServerScriptService"):WaitForChild("Books")):Register(script.Parent, genres, cover, title, customAuthorLine, authorNames, authorIds, authorsNote, publishDate, content, librarian)'
    return table.concat(s):gsub("\nlocal paragraphs =", "\nlocal content =")
end
local unknownGenres = {} -- pre-normalized genre -> true
local tmpAliases = {
	foreignlangueges = "Languages",
	ficton = "Fiction",
	game = "Games",
	fictionhorror = "Horror",
	robloxppl = "Roblox People",
	humor = "Comedy",
	refrence = "Reference",
	englishlit = "Fiction",
	literature = "Fiction",
	worldreligion = "Religion",
	worldsport = "Sports",
	worldsports = "Sports",
	sportscompetition = "Sports",
	worldnature = "Nature",
	robloxmystery = "Mystery",
	childrensfiction = "Children's",
	children = "Children's",
	childrenfiction = "Children's",
	fictionromance = "Romance",
	fictionfantasy = "Fantasy",
	historybook = "History",
	scary = "Horror",
	worldscifi = "Science Fiction",
	worldscience = "Science",
	literaturepoetry = "Poetry",
	poem = "Poetry",
	worldgame = "Games",
	gamesorgames = "Games",
	worldphilosophy = "Philosophy",
	moneyeconomy = "Economics & Money",
	moneyandeconomy = "Economics & Money",
	economics = "Economics & Money",
	money = "Economics & Money",
	scienceficiton = "Science Fiction",
	learning = "Roblox Learning",
	litfict = "Fiction",
	grammar = "Reference",
	information = "Reference",
	mathlearn = "Mathematics",
	scripting = "Lua",
	developerslearn = "Roblox Learning",
	devlearn = "Roblox Learning",
	dev = "Roblox Learning",
	genreroblox = "Roblox",
	ummnewsectioncalledroblox = "Roblox",
	robloxhorror = "Horror",
	charasbackstoryundertale = "Fan Fiction",
	afanfiction = "Fan Fiction",
	stevenuniversefanfiction = "Fan Fiction",
	filmsectionorrobloxlearning = "Learn",
	fanfictionhorror = "Horror",
	worldgamesorgames = "World Games",
	librarylearn = "Learn",
	developers = "Learn",
	historylearn = "History",
}
local hallToPrepend = {
	--[workspace["Hall C"]] = "World",
	[workspace["Hall D"]] = "Roblox",
}
local function getOptionalPrepend(shelf)
	for hall, prepend in pairs(hallToPrepend) do
		if shelf:IsDescendantOf(hall) then return prepend end
	end
end
local function getGenreConsideringShelf(shelf, input)
	-- Check prepend first. Thus, if input is "History" and it's in the Roblox section, it'll choose Roblox History.
	local prepend = shelf and getOptionalPrepend(shelf)
	local genre
	if prepend then
		genre = Genres.InputToGenre(prepend .. input)
	end
	return genre or Genres.InputToGenre(input)
end
local considerSubGenre
local function getGenre(shelf, genre, doNotRecurse)
	-- if it's a valid one, just return it
	local alt = Genres.Normalize(genre)
	return getGenreConsideringShelf(shelf, genre)
		or (tmpAliases[genre] and getGenreConsideringShelf(shelf, tmpAliases[genre]))
		or (tmpAliases[alt] and getGenreConsideringShelf(shelf, tmpAliases[alt]))
		or not doNotRecurse and (
			considerSubGenre(shelf, alt, "umm")
			or considerSubGenre(shelf, alt, "or ")
			or considerSubGenre(shelf, alt, "fiction")
			or considerSubGenre(shelf, alt, "fict")
			or considerSubGenre(shelf, alt, "fic")
			or considerSubGenre(shelf, alt, "genre")
			or considerSubGenre(shelf, alt, "lit")
			or considerSubGenre(shelf, alt, "literature")
			or considerSubGenre(shelf, alt, "world")
			or considerSubGenre(shelf, alt, "roblox")
			or considerSubGenre(shelf, alt, "nonfiction"))
end
function considerSubGenre(shelf, genre, sub) -- consider a substring
	return genre:find(sub) and getGenre(shelf, genre:gsub(sub, ""), true)
end
local getShelfFromBook do
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
	local cache = {}
	function getShelfFromBook(book)
		local result = cache[book]
		if result == nil then
			result = false
			for _, dir in ipairs(dirs) do
				local raycastResult = workspace:Raycast(book.Position, dir, raycastParams)
				if raycastResult and raycastResult.Instance then
					result = raycastResult.Instance
					break
				end
			end
			cache[book] = result
		end
		return result
	end
end
local function getGenreInputFromShelf(book)
	local shelf = getShelfFromBook(book)
	if not shelf then
		warn("No shelf found for book: " .. tostring(book:GetFullName()))
		return
	end
	local relCF = shelf.CFrame:ToObjectSpace(book.CFrame)
	local desiredFace = relCF.Z > 0 and Enum.NormalId.Back or Enum.NormalId.Front
	for _, genreText in ipairs(shelf:GetChildren()) do
		if genreText.Face == desiredFace then
			return genreText.TextLabel.Text, shelf
		end
	end
	print(shelf:GetFullName(), book:GetFullName(), relCF, desiredFace)
	error("Didn't find genreText with desired face")
end
local warned = {}
local function getGenresFromBook(book)
	local _, _, nameWithoutGenres, genres = book.Name:find("^(.*)%((.*)%)%s*$")
	local tagsNotIdentified = {}
	if genres then
		local shelf = getShelfFromBook(book)
		--local input = List.ToSet(String.Split(genres:lower():gsub("rblx", "roblox"):gsub("ficiton", "fiction"):gsub("robox", "roblox"), ",/?"))
		local inputList, delimList = String.SplitReturnDelimiters(genres, ",/?")
		for index, raw in ipairs(inputList) do tagsNotIdentified[raw] = {index, delimList[index]} end
		local input = List.ToSet(inputList)
		input[""] = nil
		genres = {}
		for raw, _ in pairs(input) do
			local genre = String.Trim(raw:lower():gsub("rblx", "roblox"):gsub("ficiton", "fiction"):gsub("robox", "roblox"):gsub("ficition", "fiction"):gsub("%.", ""))
			if genre == "" then continue end
			genre = getGenre(shelf, genre) or genre
			if Genres.InputToGenre(genre) then
				tagsNotIdentified[raw] = nil
				genres[genre] = true
			else
				unknownGenres[genre] = (unknownGenres[genre] or 0) + 1
			end
		end
	end
	local dict = genres or {}
	local input, shelf = getGenreInputFromShelf(book)
	local primary = shelf and getGenreConsideringShelf(shelf, input)
	-- Remove primary genre from the dictionary and add the rest to the list
	if primary then
		dict[primary] = nil
		genres = {primary}
	else
		if input and not warned[input] then
			warned[input] = true
			warn("No genre", input, "for shelf near book", book:GetFullName())
		end
		genres = {}
	end
	for genre, _ in pairs(dict) do
		genres[#genres + 1] = genre
	end
    return genres, nameWithoutGenres, tagsNotIdentified
end
local function getBookName(obj)
	local _, _, name = obj.Source:find('local title = "([^"]+)"')
	return name
end
local function stripGenresFromPartName(part, nameWithoutGenres, tagsNotIdentified)
	-- tagsNotIdentified[original tag] = {index, delimAfterIt}
	local name = part.Name
	if name == nameWithoutGenres then return end -- nothing to strip
	for tag, obj in pairs(tagsNotIdentified) do
		if String.Trim(tag) == "" then
			tagsNotIdentified[tag] = nil
		end
	end
	nameWithoutGenres = String.Trim(nameWithoutGenres)
	local newName
	if next(tagsNotIdentified) then
		local tagsLeft = {}
		for tag, obj in pairs(tagsNotIdentified) do
			tagsLeft[#tagsLeft + 1] = {obj[1], tag, obj[2]}
		end
		table.sort(tagsLeft, function(a, b) return a[1] < b[1] end)
		for i, obj in ipairs(tagsLeft) do
			tagsLeft[i] = String.Trim(i == #tagsLeft and obj[2] or (obj[2] .. obj[3]))
		end
		newName = ("%s (%s)"):format(nameWithoutGenres, table.concat(tagsLeft))
	else
		newName = nameWithoutGenres
	end
	if MAKE_CHANGES then
		part.Name = newName
	end
end
local function removeBookColor(bookScript)
	local bc = bookScript:FindFirstChild("BookColor")
	if bc then
		bookScript.Parent.BrickColor = bc.Value
		bc:Destroy()
	end
end
local function updateTitleColors(bookScript)
	for _, name in ipairs({"TitleColor", "TitleOutlineColor"}) do
		local obj = bookScript:FindFirstChild(name)
		if obj then
			obj.Parent = bookScript.Parent
		end
	end
end

local bookSourceToGenre = {}
local function handleBookScript(obj, genresOverride, newSourceFromDuplicate)
	local source = obj.Source
	local new = {}
	local start = 1
	local genres = genresOverride or bookSourceToGenre[source]
	local nameWithoutGenres, tagsNotIdentified
	if not genres then
		genres, nameWithoutGenres, tagsNotIdentified = getGenresFromBook(obj.Parent)
		bookSourceToGenre[source] = genres
	end
	if nameWithoutGenres then
		stripGenresFromPartName(obj.Parent, nameWithoutGenres, tagsNotIdentified)
	end
	source = newSourceFromDuplicate or modifySource(source, genres, obj)
	if MAKE_CHANGES then
		obj.Source = source
	else
		return source
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

local scanForAuthors, scanForAuthorsReport
if SCAN_FOR_AUTHORS then
	local authorIds = {}
	local authorNames = {}
	function scanForAuthors(obj)
		local source = obj.Source
		local _, _, authorIdsField = getAuthorId(source)
		if authorIdsField then
			for _, id in ipairs(splitAuthorIdsField(authorIdsField)) do
				id = id and tonumber(id)
				if id then
					authorIds[id] = true
				end
			end
		end
		local _, _, authorName = getAuthorName(source)
		if authorName then
			for _, name in ipairs(splitAuthorNameField(authorName)) do
				authorNames[name] = true
			end
		end
	end
	local function setToStringList1(set)
		local t = {}
		for k, _ in pairs(set) do
			t[#t + 1] = tostring(k)
		end
		return t
	end
	local function setToStringList2(set)
		local t = {}
		for k, _ in pairs(set) do
			t[#t + 1] = ('"%s"'):format(k)
		end
		return t
	end
	local o1 = getOrCreate(ServerStorage, "AuthorDataList", "ModuleScript")
	function scanForAuthorsReport()
		o1.Source = ([[
return {
	authorIds = {%s},
	authorNames = {%s},
}]]):format(
			table.concat(setToStringList1(authorIds), ","),
			table.concat(setToStringList2(authorNames), ","))
	end
elseif CONVERT_AUTHORS then
	local Players = game.Players
	local o1 = require(getOrCreate(ServerStorage, "AuthorDataList", "ModuleScript"))
	local o2 = getOrCreate(ServerStorage, "AuthorDataConversion", "ModuleScript")
	--local o3 = getOrCreate(ServerStorage, "AuthorDataConversion Results", "ModuleScript")
	local stopValue = getOrCreate(ServerStorage, "_AuthorDataConversion Cancel", "BoolValue")
	stopValue.Value = false
	local authorIds, authorNames = o1.authorIds, o1.authorNames
	local idToName = {}
	local nameToId = {}
	local e = Instance.new("BindableEvent")
	local idIndex = 0
	local function getId()
		idIndex += 1
		if idIndex % 100 == 0 then print("getId", idIndex) end
		return authorIds[idIndex]
	end
	local nameIndex = 0
	local function getName()
		nameIndex += 1
		if nameIndex % 100 == 0 then print("getName", nameIndex) end
		return authorNames[nameIndex]
	end
	local numWorkers = 3
	for worker = 1, numWorkers do
		coroutine.resume(coroutine.create(function()
			---[[
			while not stopValue.Value do
				local id = getId()
				if not id then break end
				--local ind = idIndex
				if idToName[id] then
				--	_id[ind] = ind .. ": repeat"
					continue
				end
				local success, name
				while true do
					success, name = pcall(function() return Players:GetNameFromUserIdAsync(id) end)
					if success then
						break
					else
						if name:find("HTTP 400") then
							name = nil
							break
						elseif name:find("HTTP 429") then -- too many requests
							print("429 error - waiting...")
							wait(10)
						else
							wait()
							print(name)
							error("Unknown error message")
						end
					end
				end
				name = success and name or nil
				if name then
					idToName[id] = name
					nameToId[name] = id
				end
			end
			--]]
			while not stopValue.Value do
				local name = getName()
				if not name then break end
				if nameToId[name] then continue end
				--local ind = nameIndex
				if nameToId[name] then
					--_name[ind] = ind .. ": repeat"
					continue
				end
				local success, id
				while true do
					success, id = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
					if success then
						break
					else
						if id:find("failed because the user does not exist") then
							name = nil
							break
						elseif id:find("HTTP 429") then
							wait(10)
						else
							wait()
							print(id)
							error("Unknown error message")
						end
					end
				end
				id = success and id or nil
				if id then
					idToName[id] = name
					nameToId[name] = id
				end
			end
			e:Fire()
		end))
	end
	for i = 1, numWorkers do e.Event:Wait() end
	if stopValue.Value == false then
		local entries = {}
		for id, name in pairs(idToName) do
			entries[#entries + 1] = ('\n\t[%s] = "%s",'):format(id, name)
		end
		o2.Source = ("return {%s\n}"):format(table.concat(entries))
	end
	--o3.Source = ("ID -> NAME\n%s\n\nNAME -> ID\n%s"):format(table.concat(_id, "\n"), table.concat(_name, "\n"))
	stopValue:Destroy()
	print("Done")
	return
end

local postBookGenres = {"Library Post"}
for _, args in ipairs({{workspace.Books}, {workspace.BookOfTheMonth}, {workspace.NewBooks}, {workspace["Staff Recs"]}, {workspace["Post Books"], postBookGenres}}) do
	local container, genresOverride = args[1], args[2]
	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("Script") and (obj.Name == "BookEventScript(This is what you edit. Edit nothing else.)" or obj.Name == "BookScript") then
			detectPublishDateFormat(obj)
		end
	end
end
if PRINT_LIBRARIAN_REPORT then
	librarianDateReport()
end

local copies = {} -- origBookSource -> book scripts

--local output = MAKE_CHANGES or getOrCreate(game.ServerStorage, "Book Revamp Test Output", "Script")
--for _, args in ipairs({{workspace.Books}, {workspace.NewBooks}, {workspace.BookOfTheMonth}, {workspace["Staff Recs"]}, {workspace["Post Books"], postBookGenres}}) do
for _, args in ipairs({{workspace["Staff Recs"]}}) do
	local container, genresOverride = args[1], args[2]
	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("Script") and (obj.Name == "BookEventScript(This is what you edit. Edit nothing else.)" or obj.Name == "BookScript") then
			local source = obj.Source
			local list = copies[source]
			local isDuplicate = list
			if not list then
				list = {}
				copies[source] = list
			end
			list[#list + 1] = obj
			if MAKE_CHANGES then
				removeBookColor(obj)
				updateTitleColors(obj)
				handleBookScript(obj, genresOverride, isDuplicate and list[1].Source) -- note: this means that only the first book found will have its shelf considered (but BOTM and NewBooks aren't on shelves so this should be okay)
			elseif SCAN_FOR_AUTHORS then
				if not isDuplicate then
					scanForAuthors(obj)
				end
			else
				handleBookScript(obj, genresOverride)
				--output.Source = RemoveAllComments(handleBookScript(obj, genresOverride), true)
				--break
			end
		end
	end
end
if SCAN_FOR_AUTHORS then
	scanForAuthorsReport()
else
	if not MAKE_CHANGES then
		local norms = {}
		for genre, t in pairs(unknownGenres) do
			local norm = Genres.Normalize(genre)
			norms[norm] = (norms[norm] or 0) + t
		end
		local list = {}
		for genre, t in pairs(norms) do
			list[#list + 1] = {genre, t}
		end
		table.sort(list, function(a, b) return a[2] > b[2] end)
		for _, obj in ipairs(list) do
			print(obj[1], ("\t(%d times)"):format(obj[2]))
		end
		print("\n*******************\n")
		for genre, t in pairs(unknownGenres) do
			local norm = Genres.Normalize(genre)
			print(genre, "\t", norm, ("\t(%d times)"):format(t))
		end
	end
	if numAuthorsNoId > 0 then
		warn("numAuthorsNoId", numAuthorsNoId)
	end
end

-- if MAKE_CHANGES then
--	local RemoveAllComments = require(ServerStorage.RemoveAllComments)
-- 	for _, obj in ipairs(workspace:GetDescendants()) do
-- 		if obj:IsA("Script") and (obj.Name == "BookEventScript(This is what you edit. Edit nothing else.)" or obj.Name == "BookScript") then
-- 			obj.Name = "BookScript"
-- 			obj.Source = RemoveAllComments(obj.Source, true)
-- 		end
-- 	end
-- end