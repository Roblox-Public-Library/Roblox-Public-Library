local Books = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event = require(ReplicatedStorage.Utilities.Event)
local List = require(ReplicatedStorage.Utilities.List)
local ServerScriptService = game:GetService("ServerScriptService")
local BookChildren = require(ServerScriptService.Library.BookChildren)
local BookVersionUpgrader = require(ServerScriptService.Library.BookVersionUpgrader)
local Genres = require(ServerScriptService.Library.Genres)
local ParallelTasks = require(ServerScriptService.ParallelTasks)
local Writer = require(ReplicatedStorage.Writer)
local	CustomMarkdown = Writer.CustomMarkdown
local	PreRenderPageCounter = Writer.PreRender
local	PageCounter = Writer.PageCounter
local	RichText = Writer.RichText

local Players = game:GetService("Players")

task.spawn(function()
	ParallelTasks.SetDesiredFPS(2)
	if #Players:GetPlayers() == 0 then
		if game:GetService("RunService"):IsStudio() then
			-- In case someone is testing in Run mode, switch to a more reasonable fps if still no players
			task.delay(4, function()
				if #Players:GetPlayers() == 0 then
					ParallelTasks.SetDesiredFPS(30)
				end
			end)
		end
		Players.PlayerAdded:Wait()
	end
	ParallelTasks.SetDesiredFPS(15)
end)

local TestService = game:GetService("TestService")

local summaries = {} -- List<Summary> where each summary is {.Id .Title .Author .Models .PageCount and more, see 'summary' creation}
	-- Note: everything in summaries can be replicated as-is to clients
	-- Note: PageCount might not exist yet, in which case it will be transmitted via the remote PageCountReady
local allSummaries = {} -- List<Summary>, which has everything 'summaries' has and also private (non-workspace) books
local idToSummary = {}
local bookIdToContent = {} -- content stored here so it is not replicated to clients automatically
local transparentCover = 428733812
local ServerStorage = game:GetService("ServerStorage")
local storage = ServerStorage:FindFirstChild("Book Data Storage")
local modelToId = {}
local warnOutdated
if storage then
	warnOutdated = function()
		warn("Books missing ids - Book Maintenance required.")
		warnOutdated = function() end
	end
else
	warnOutdated = function() end
end
if storage then
	local idsFolder = storage:FindFirstChild("Ids")
	for _, obj in ipairs(idsFolder:GetChildren()) do
		local id = tonumber(obj.Name)
		if id then
			if obj.Value then
				modelToId[obj.Value] = id
			else
				warn("Improperly configured Ids:", obj:GetFullName())
			end
			for _, c in ipairs(obj:GetChildren()) do
				if c.Value then
					modelToId[c.Value] = id
				else
					warn("Improperly configured Ids in:", obj:GetFullName())
				end
			end
		else
			warn("Improperly configured Ids:", obj:GetFullName())
		end
	end
end

local getContent = Instance.new("RemoteFunction")
getContent.Name = "GetBookContent"
getContent.Parent = ReplicatedStorage
getContent.OnServerInvoke = function(player, id)
	--	returns false if the book errored, else data:
	--		.Content -- to be fed to CustomMarkdown, PreRender, and then Render
	--		.Images -- nil or a list of image ids
	--		.Audio -- nil or a list of audio ids
	--		.UseLineCommands -- boolean
	local data = bookIdToContent[id]
	-- note: data == false is a valid value
	if data == nil then error("No book with id " .. tostring(id) .. " exists") end
	return data
end

local pageCountReady = Instance.new("RemoteEvent")
pageCountReady.Name = "PageCountReady"
pageCountReady.Parent = ReplicatedStorage

local pageCountInit = {}
local pageCountQueue = {}
Players.PlayerAdded:Connect(function(player)
	pageCountQueue[player] = {}
end)
Players.PlayerRemoving:Connect(function(player)
	pageCountInit[player] = nil
	pageCountQueue[player] = nil
end)

pageCountReady.OnServerEvent:Connect(function(player)
	if pageCountInit[player] then return end
	pageCountInit[player] = true
	for _, data in ipairs(pageCountQueue[player]) do
		pageCountReady:FireClient(player, unpack(data))
	end
	pageCountQueue[player] = nil
end)

local booksReadyEvent = Event.new() -- set to nil when books have finished registering (Roblox only resumes a finite number of threads per frame when returning from most Async functions, including WaitForChild, so not all scripts will Register right away, hence the functionality in updateBooksReadyOnNewBook)
local getBooks = Instance.new("RemoteFunction")
getBooks.Name = "GetBooks"
getBooks.Parent = ReplicatedStorage
getBooks.OnServerInvoke = function(player)
	if booksReadyEvent then
		booksReadyEvent:Wait()
	end
	return summaries
end

local function convertEmptyToAnonymous(authorNames)
	for _, name in ipairs(authorNames) do -- Check to see if generating a new list is necessary
		if name == "" or not name then
			local new = {}
			for i, name in ipairs(authorNames) do
				new[i] = if name == "" or not name then "Anonymous" else name
			end
			return new
		end
	end
	return authorNames
end

local parseTime = 0
local numPageCountInit = 0
local firstRegisterTime, lastRegisterTime
local lastRegisterDistributedTime
local function cleanupAndPrintReport()
	print(string.format("Parse issue check time: %.3fms", parseTime * 1000))
	print(string.format("Done registering books & counting all pages in %.3fs (it took %.3fs for all books to start registering)", os.clock() - firstRegisterTime, lastRegisterTime - firstRegisterTime))
	ParallelTasks.SetDesiredFPS(30)
	RichText.Desync.ClearMemory()
	cleanupAndPrintReport = function() end
end
local function updateBooksReadyOnNewBook()
	firstRegisterTime = firstRegisterTime or os.clock()
	lastRegisterTime = os.clock()
	if not booksReadyEvent then
		warn("Books:Register called after book list assumed to have finished initializing") -- If this happens, increase the task.delay time below
	else
		local now = workspace.DistributedGameTime
		if lastRegisterDistributedTime ~= now then
			lastRegisterDistributedTime = now
			task.delay(0.5, function()
				if now == lastRegisterDistributedTime then
					local event = booksReadyEvent
					booksReadyEvent = nil
					event:Fire()
					event:Destroy()
					if numPageCountInit == #summaries then
						cleanupAndPrintReport()
					end
				end
			end)
		end
	end
end

local function updateBookModel(model, cover, title, id)
	BookChildren.AddTo(model)
	local coverDecal = model:FindFirstChild("Cover")
	if coverDecal then
		if cover and cover ~= transparentCover then
			coverDecal.Texture = "http://www.roblox.com/asset/?id=" .. cover
		else
			coverDecal:Destroy()
		end
	end
	if not storage or typeof(id) == "Instance" then -- if storage exists, maintenance plugin takes care of this, unless 'id' is an Instance, in which case maintenance hasn't been run for this
		BookChildren.UpdateGuis(model, title)
	end
end

local function colorsSimilar(a, b)
	return math.abs(a.R - b.R) < 0.2
		and math.abs(a.G - b.G) < 0.2
		and math.abs(a.B - b.B) < 0.2
end
local black = Color3.new()
local white = Color3.new(1, 1, 1)
local function oppositeBlackWhite(c)
	return if (c.R > 0.5 or c.G > 0.5 or c.B > 0.5) then black else white
end
local function handleStrokeColor(textColor, strokeColor)
	return if colorsSimilar(textColor, strokeColor)
		then oppositeBlackWhite(textColor)
		else strokeColor
end
local function formatColor(c)
	return string.format("(%d %d %d)", c.R*255, c.G*255, c.B*255)
end

local useLineCommandsTitlePage = [[
<indent><pagenumbering,roman,invisible2><image,%d>
<center><stroke,%s,2,0><color,%s><header,large,%s>
By: %s</stroke></color><dline>

<large>Roblox Library Community</large><line>
<left>Librarian: %s<line>
Published On: %s<dline>

%s%s<turn><pagenumbering,number,1>
]]
local titlePage = [[
<indent><pagenumbering,roman,invisible2><image,%d>
<center><stroke,%s,2,0><color,%s><header,large,%s>
By: %s</stroke></color>

<large>Roblox Library Community</large>
<left>Librarian: %s
Published On: %s

%s%s
<turn><pagenumbering,number,1>]]

local function register(model, data, upgradeIfNew)
	local private = not model:IsDescendantOf(workspace) -- don't replicate non-workspace books to the client, but keep a record of them
	if private then -- ignore it if it's part of a package
		local parent = model.Parent
		while parent do
			if parent:FindFirstChildOfClass("PackageLink") then
				return
			end
			parent = parent.Parent
		end
	end
	updateBooksReadyOnNewBook()

	-- Check to see if this book is already in the system
	local id = modelToId[model]
	if not id then
		if not model.Name:find("Example Book") and not model.Name:find("The Secret Book") then -- todo generalize exceptions
			warnOutdated()
		end
		id = model
	end
	local summary = idToSummary[id]
	if summary then
		table.insert(summary.Models, model)
		updateBookModel(model, summary.Cover, summary.Title, summary.Id)
		if summary.Private and not private then
			table.insert(summaries, summary)
			summary.Private = nil
		end
		return
	elseif summary == false then -- book errored so don't do anything
		return
	end

	if upgradeIfNew then
		upgradeIfNew(data)
	end

	-- Extract info from data, making sure they're the right type, and afterwards make sure there aren't any unknown keys left over
	data.BookModel = nil
	local errSoFar
	local errIsFatal
	local function wrn(msg)
		if not errSoFar then
			errSoFar = {}
		end
		table.insert(errSoFar, (msg:gsub("\n", "\n\t\t")))
	end
	local function err(msg)
		errIsFatal = true
		wrn(msg)
	end
	local function get(key, type, optional)
		local value = data[key]
		if value == nil then
			if not optional then
				err('missing "' .. key .. '"')
			end
		else
			data[key] = nil
			if type then
				local t = typeof(value)
				if t ~= type then
					err(key .. " should be a " .. type .. " but got a " .. t .. ": " .. tostring(value), 3)
					return nil
				end
			end
		end
		return value
	end
	local genres = get("Genres", "table")
	local cover = get("Cover", "number", true)
	local title = get("Title", "string")
	local customAuthorLine = get("CustomAuthorLine", "string", true)
	local authorNames = get("AuthorNames", "table")
	local authorIds = get("AuthorIds", "table")
	local authorsNote = get("AuthorsNote", "string", true)
	local publishDate = get("PublishDate", "string")
	local librarian = get("Librarian", "string")
	local content = get("Content", "string")
	local useLineCommands = get("UseLineCommands", "boolean", true)

	-- Of remaining keys, extract Image and Audio lists
	local function getList(pluralName, singleName)
		local list = get(pluralName, "table", true)
		if not list and next(data) then
			list = {}
			local max = 0
			local pattern = singleName .. "(%d+)"
			for key, value in data do
				local num = tonumber(key:match(pattern))
				if num then
					if value ~= 0 then
						if num > max then max = num end
						if type(value) ~= "number" then
							err(pluralName .. " should be numbers but got: " .. tostring(value))
						else
							list[num] = value
						end
					end -- 0 means the same thing as nil for these
					data[key] = nil
				end
			end
			for i = 1, max do
				list[i] = list[i] or false
			end
			return if max > 0 then list else nil
		end
		return list
	end
	local images = getList("Images", "Image")
	local audio = getList("Audio", "Audio")
	if not audio then -- check for Audio attribute on model
		local audioId = model:GetAttribute("Audio")
		if audioId then
			audio = {audioId}
		else
			local i = 1
			while true do
				local audioId = model:GetAttribute("Audio" .. i)
				if not audioId then break end
				audio = audio or {}
				table.insert(audio, audioId)
				i += 1
			end
		end
	end

	if next(data) then
		local unknownKeys = {}
		for k in data do
			table.insert(unknownKeys, k)
		end
		err("Unknown keys in " .. model:GetFullName() .. " data: " .. table.concat(unknownKeys, ", "))
	end

	-- Argument Normalizing
	if cover == 0 then cover = nil end
	if customAuthorLine == "" then customAuthorLine = nil end
	if genres then
		local orig = genres
		genres = {}
		for _, raw in ipairs(orig) do
			local genre = Genres.InputToGenre(raw)
			if genre then
				genres[#genres + 1] = genre
			else
				wrn("Unrecognized genre '" .. tostring(raw) .. "'")
			end
		end
	end
	if authorNames then
		authorNames = convertEmptyToAnonymous(authorNames)
	end
	local authorLine = customAuthorLine or (if authorNames then List.ToEnglish(authorNames) else "?")
	if authorLine == "" then authorLine = "Anonymous" end

	-- Add cover & title page
	local scr = BookChildren.GetBookScript(model)
	local titleTextColor = BookChildren.GetAttribute(scr, "TitleColor")
	local titleStrokeColor = handleStrokeColor(titleTextColor, BookChildren.GetAttribute(scr, "TitleOutlineColor"))

	local defaultIndent = if table.find(genres, "Poetry") then "<indent>" else "<indent,tab>"

	local titlePageContent = string.format(if useLineCommands then useLineCommandsTitlePage else titlePage,
		cover or transparentCover,
		formatColor(titleStrokeColor), formatColor(titleTextColor), RichText.HandleEscapes(title),
		RichText.HandleEscapes(authorLine),
		RichText.HandleEscapes(librarian),
		RichText.HandleEscapes(publishDate),
		authorsNote,
		defaultIndent)
	local content = titlePageContent .. content

	updateBookModel(model, cover, title, id)

	-- Register book into system
	local contentTable = {Images = images, UseLineCommands = useLineCommands, Audio = audio}
	local _, count = titlePageContent:gsub("\n", "")
	local now = os.clock()
	local issues = CustomMarkdown.CheckForIssues(content, contentTable, -count)
	parseTime += os.clock() - now
	if issues then
		for _, issue in ipairs(issues) do
			wrn(issue)
		end
	end
	if errSoFar then
		TestService:Error(model:GetFullName() .. " Script " .. (if errIsFatal then "Errors" else "Problems"))
		TestService:Message("List:\n\t- " .. table.concat(errSoFar, "\n\t- "))
		if errIsFatal then
			idToSummary[id] = false -- indicates an error
			bookIdToContent[id] = false
			return
		end
	end
	summary = {
		Id = id,
		Title = title,
		AuthorLine = authorLine,
		Authors = authorNames,
		AuthorIds = authorIds, -- todo use this for players who are in-game in case they changed their name recently
		PublishDate = publishDate,
		Librarian = librarian,
		Models = {model},
		Genres = genres,
		-- PageCount will be set when it's ready
	}
	if contentTable.Audio then
		summary.HasAudio = true
	end
	idToSummary[id] = summary
	if private then
		summary.Private = true
	else
		table.insert(summaries, summary)
	end
	table.insert(allSummaries, summary)
	contentTable.Content = content
	bookIdToContent[id] = contentTable
	ParallelTasks.OnInit(function()
		local pageCount = PageCounter.CountAsync(content, contentTable)
		summary.PageCount = pageCount
		if not summary.Private then
			for _, player in ipairs(Players:GetPlayers()) do
				if pageCountInit[player] then
					pageCountReady:FireClient(player, id, pageCount)
				else
					table.insert(pageCountQueue[player], {id, pageCount})
				end
			end
		end
		numPageCountInit += 1
		if not booksReadyEvent and numPageCountInit == #summaries then
			cleanupAndPrintReport()
		end
	end)
end
function Books:Register(model, data, ...)
	if select("#", ...) > 0 then
		self:RegisterV1(model, data, ...)
	else
		register(model, data)
	end
end
local escape = BookVersionUpgrader.Escape
function Books:RegisterV1(model, genres, cover, title, customAuthorLine, authorNames, authorIds, authorsNote, publishDate, words, librarian, audio)
	register(model, {
		Genres = genres,
		Cover = if cover then tonumber(cover:match("(%d+)/?$")) else nil,
		Title = title,
		CustomAuthorLine = customAuthorLine,
		AuthorNames = authorNames,
		AuthorIds = authorIds,
		AuthorsNote = escape(authorsNote),
		PublishDate = publishDate,
		Librarian = librarian,
		Words = words,
		Audio = if audio and type(audio) ~= "table" then {audio} else audio,
	}, BookVersionUpgrader.UpgradeV1)
end
function Books:GetCount() return #summaries end -- Get the count of public books
function Books:GetBooks() return allSummaries end -- Gets all books, including private ones
function Books:GetBook(id) return idToSummary[id] end
function Books:AreReady() return not booksReadyEvent end
function Books:WaitForReady()
	if booksReadyEvent then
		booksReadyEvent:Wait()
	end
end
function Books:OnReady(fn)
	if Books:AreReady() then
		fn()
	else
		booksReadyEvent:Connect(fn)
	end
end

return Books