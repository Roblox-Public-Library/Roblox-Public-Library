local MAKE_CHANGES = false -- false for debugging

-- Run this in the command bar to modify all book scripts to store the id of all authors instead of just their usernames

--[[Plan
local authorName = "someone, BakedPot8to"
local autho:rID = "anything"l
->
local authors = {123, "BakedPot8to"} -- assuming 2 authors. The 2nd author not wanting their real name to be known.

(BakedPot8to would remain with no Id if the lookup fails)

Note: some books will have "local authors =" already (ex we will go through edge cases before running this script)

And in future we'll need an AuthorDisplayName module script:
return {
    [15] = "Y",
    -- other users here
}

WAIT A MOMENT
If the end result is
    local authors = {123, 456}
then the scripts won't know who the authors are!
Alternatives...
    local authors = {"user1", "user2"}
    local authorIds = {123, false} -- false for "anonymous"/unknown

Problem:
    Often the name lookup will fail, but the authorId will be made up. Maybe we just skip those for now (put it in output the list of failures)?
Huh..

GET /users/{userId}
http://api.roblox.com/users/USERId -- must be performed outside Roblox Studio
]]
--[[More special cases (maybe).. search for scripts with these author "ids":
Anthony T. Hayes,N/A,Sidartha Septim,SuperMarkU1,http://www.roblox.com/asset/?id=428733812,unknown
99570107 and 41904357 -- maybe just replace " and " with ", "
]]

local RemoveAllComments = require(game:GetService("ServerStorage").RemoveAllComments)
local userIdToName, userNameToId = unpack(require(game.ServerStorage.AuthorDataTmp2))
--[[The following functions have
    s:list of new source
    source: original
    start: index to start searching at (must be at least 1)
    They must return the new 'start' index (for any future sections)
]]
local numAuthorsNoId = 0
local function dealWithAuthors(s, source, start, genres)
    local authorStart, authorStop, authorField = source:find('local authorName = "([^"]*)"')
    if not authorStart then return start end -- If authorName = not found then this has already had its authors updated
    local _, stop, authorIdField = source:find('local authorID = "([^"]*)"') --, authorStop) [1 book has them out of order]
    authorIdField = authorIdField:gsub(" and", ","):gsub("/", "") -- one book each
	local authors = authorField:split(", ")
    local authorIds = authorIdField:split(", ") -- will normally just be one; some won't even be numbers
    for i, author in ipairs(authors) do
        local id = userNameToId[author]
        -- If someone has username "X" and we can't find their Id, what do we want to do?
        -- We wanted to use the Id stored and see if it might be a valid account (using the table above)
        -- If their Id comes up with username "Y", then we assume that they changed their account name to "Y"
        if not id then
            numAuthorsNoId += 1
            -- see if the Id is any good (if it even exists)
            id = authorIds[i]
            local name = userIdToName[id]
            -- If their Id points to a valid account, use it, otherwise stick with the declared name
            if name then
                -- Note: this case doesn't actually happen
                print("Replacing", authors[i], "with", name)
                authors[i] = ('"%s"'):format(name)
                authorIds[i] = tostring(id)
            else
                authors[i] = ('"%s"'):format(author)
                authorIds[i] = "false"
            end
        else
            authors[i] = ('"%s"'):format(author)
            authorIds[i] = tostring(id)
        end
	end
	local genreString = ""
	if genres then
		for i, genre in ipairs(genres) do
			genres[i] = ('"%s"'):format(genre)
		end
	end
    genreString = ('local genres = {%s}'):format(genres and table.concat(genres, ", ") or "")
    s[#s + 1] = ('%slocal customAuthorLine = "" --ex, "The Community" would have "By: The Community" on the cover page\nlocal authorNames = {%s}\nlocal authorIds = {%s} --One for each author. Use false for anonymous or pen names\n%s\n'):format(
        source:sub(start, authorStart - 1),
        table.concat(authors, ", "),
		table.concat(authorIds, ", "),
		genreString)
    return stop + 1
end
local function removeDoubleHeader(s, source, start, header)
	local hStart, hEnd = source:find(header, start, true)
	if not hStart then return start end
    local h2Start, h2End = source:find(header, hEnd + 1, true)
    if h2Start then
        s[#s + 1] = source:sub(start, h2Start - 1)
        return h2End + 1
    else
        return start
    end
end
local function removeColors(s, source, start)
    local cStart, _ = source:find("local bookColor")
    if not cStart then return start end -- section already removed
    local _, cEnd = source:find('"TitleOutlineColor"%).Value')
    s[#s + 1] = source:sub(start, cStart - 1)
    return cEnd + 2 -- + 2 to also skip the newline
end
local function handleEnding(s, source, start)
    local cStart, cEnd = source:find([[---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
---!!!EDIT NOTHING PAST THIS POINT!!!---
---__________________________________---
]]) -- Note: will leave precisely 1 set of "don't edit past this point"
    if cStart then
        s[#s + 1] = source:sub(start, cStart - 1)
        start = cEnd + 1
    end
	local eStart = source:find("local words = paragraphs") -- finds where it starts and doesn't include it in 's', the new source
	if eStart then
		s[#s + 1] = source:sub(start, eStart - 1)
	end
	s[#s + 1] = 'require(game:GetService("ServerScriptService").Books):Register(script.Parent, genres, cover, title, customAuthorLine, authorNames, authorIds, authorsNote, publishDate, paragraphs, librarian)'
end
local unknownGenres = {} -- pre-normalized genre -> true
local ServerScriptService = game:GetService("ServerScriptService")
local Genres = require(ServerScriptService.Genres:Clone()) -- clone allows us to keep modifying Genres
local Utilities = game:GetService("ReplicatedStorage").Utilities
local String = require(Utilities.String)
local List = require(Utilities.List)
local tmpAliases = {
	foreignlangueges = "Foreign Languages",
	ficton = "Fiction",
	game = "Games",
	fictionhorror = "Horror",
	robloxppl = "Roblox People",
	humor = "Comedy",
	refrence = "Reference",
	englishlit = "English Literature",
	literature = "English Literature",
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
	litfict = "English Literature",
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
	--print(part.Name, "->", newName)
	if MAKE_CHANGES then
		part.Name = newName
	end
end
local function getRidOfSpecials(s)
	return s:gsub("[‘’]", "'"):gsub("[“”]", '"')
end
local function removeBookColor(bookScript)
	bookScript.Parent.BrickColor = bookScript.BookColor.Value
	bookScript.BookColor:Destroy()
end
local function updateTitleColors(bookScript)
	bookScript.TitleColor.Parent = bookScript.Parent
	bookScript.TitleOutlineColor.Parent = bookScript.Parent
end

local bookNameToGenre = {}
local function handleBookScript(obj, genresOverride)
	local source = getRidOfSpecials(obj.Source)
	if MAKE_CHANGES then
		obj.Name = getRidOfSpecials(obj.Name)
	end
	local new = {}
	local start = 1
	local bookName = getBookName(obj)
	local genres = genresOverride or (bookName and bookNameToGenre[bookName])
	local nameWithoutGenres, tagsNotIdentified
	if not genres then
		genres, nameWithoutGenres, tagsNotIdentified = getGenresFromBook(obj.Parent)
		if bookName then
			bookNameToGenre[bookName] = bookNameToGenre
		end
	end
	if nameWithoutGenres then
		stripGenresFromPartName(obj.Parent, nameWithoutGenres, tagsNotIdentified)
	end
	start = dealWithAuthors(new, source, start, genres)
	start = removeColors(new, source, start)
	start = removeDoubleHeader(new, source, start, "---===Images===---")
	start = removeDoubleHeader(new, source, start, "---===Story===---")
	start = handleEnding(new, source, start)
	if MAKE_CHANGES then
		obj.Source = table.concat(new)
	else -- debug
		return table.concat(new)
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

local output = MAKE_CHANGES or getOrCreate(game.ServerStorage, "Book Revamp Test Output", "Script") -- debug output
print("OUTPUT:", output)
local postBookGenres = {"Library Post"}
for _, args in ipairs({{workspace.Books}, {workspace.BookOfTheMonth}, {workspace.NewBooks}, {workspace["Post Books"], postBookGenres}}) do
	local container, genresOverride = args[1], args[2]
	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("Script") and obj.Name == "BookEventScript(This is what you edit. Edit nothing else.)" then
			if MAKE_CHANGES then
				removeBookColor(obj)
				updateTitleColors(obj)
				handleBookScript(obj, genresOverride)
			else -- debug
				output.Source = RemoveAllComments(handleBookScript(obj, genresOverride), true)
				break
			end
		end
	end
end
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

if MAKE_CHANGES then
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Script") and (obj.Name == "BookEventScript(This is what you edit. Edit nothing else.)" or obj.Name == "BookScript") then -- 'or' part is debug!
			obj.Name = "BookScript"
			obj.Source = RemoveAllComments(obj.Source, true)
		end
	end
end

--[[Output

AND

local bookColor = script:WaitForChild("BookColor").Value.Color
local titleTextColor = script:WaitForChild("TitleColor").Value
local titleStrokeColor = script:WaitForChild("TitleOutlineColor").Value
--> delete

AND

local words = paragraphs
[to end of script]
-->
require(game:GetService("ServerScriptService").Books):Register(script, cover, title, customAuthorLine, authorNames, authorIds, authorsNote, publishDate, paragraphs, librarian)
]]

--[[Some other cases:
Regex find in all scripts: authorName =.*,
local authorName = "EpicNerd5678, LostSouth, Galaga31656, Jwarrior999, and AE_FIRE (listed as LostArt)"

local authorName = "The Imperial Lexicanium, published by ZuiuCenturion"
local authorID = "17950085"

local authorName = "ryan900fan (author), GoodDysAlt (coauthor)"

local authorName = "ravioli_formioli, proofread by TahoqMacLeod"

local authorName = "SushiSanPedrik, A.K.A BestAccountEverBois"
]]