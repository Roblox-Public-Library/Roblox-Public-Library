local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AuthorDirectory = require(ReplicatedStorage.AuthorDirectory)
local Books = require(ReplicatedStorage.Library.BooksClient)
local BookMetrics = require(ReplicatedStorage.Library.BookMetricsClient)

local Functions = require(ReplicatedStorage.Utilities.Functions)
local List = require(ReplicatedStorage.Utilities.List)
local String = require(ReplicatedStorage.Utilities.String)

local Players = game:GetService("Players")

local BookSearch = require(ReplicatedStorage.Library.BookSearchBasics)
local	typeToSortData = BookSearch.typeToSortData
local	Always, Never = BookSearch.Always, BookSearch.Never

local function neverFindBook(book)
	return table.find(book.Genres, "Secret") -- todo make customizable without changing this script
end
local books = table.clone(Books:GetBooks())
for i = #books, 1, -1 do
	if neverFindBook(books[i]) then
		table.remove(books, i)
	end
end

local monthToNum = {
	jan = 1,
	january = 1,
	feb = 2,
	february = 2,
	mar = 3,
	march = 3,
	apr = 4,
	april = 4,
	may = 5,
	jun = 6,
	june = 6,
	jul = 7,
	july = 7,
	aug = 8,
	august = 8,
	sep = 9,
	september = 9,
	oct = 10,
	october = 10,
	nov = 11,
	november = 11,
	dec = 12,
	december = 12,
}
local DAY_SECONDS = 3600 * 24
local curYear = os.date("*t", os.time()).year
local curYearHundreds = math.floor(curYear / 100) * 100
local curYearThousands = math.floor(curYear / 1000) * 1000
local function adjustYear(year)
	if year < 100 then
		year += curYearHundreds
	elseif year < 1000 then
		year += curYearThousands
	end
	return year
end
local slash = "[-/]"
local getDateTime = function(s)
	-- Jan 2, '05
	local month, day, year
	month = s:match("[A-Za-z]+")
	if month then
		month = monthToNum[month:lower()]
		if not month then return nil end
		day, year = s:match("(%d+)%D+(%d+)")
		if not year then -- Jan '05
			local n = tonumber(s:match("%d+"))
			if n and n <= 31 then
				day = n
			else
				year = n
			end
		end
	else
		-- 1/2/05
		month, day, year = s:match("(%d+)%s*"..slash.."%s*(%d+)%s*"..slash.."%s*(%d+)")
		if not month then
			month, year = s:match("(%d+)%s*"..slash.."%s*(%d+)")
			-- 1/2005
			if not year then
				year = s:match("%d+")
			end
		end
	end
	day, month, year = tonumber(day), tonumber(month), tonumber(year)
	local t = os.time({
		year = if year then adjustYear(year) else curYear,
		month = month or 1,
		day = day or 1,
	})
	return t - t % DAY_SECONDS -- round down to nearest day (otherwise os.time fills it in with current hour/day/sec)
end
BookSearch.GetDateTime = getDateTime
local getDateTimeCached = Functions.Cache(getDateTime)
local excludeFilters = {
	--key = genFilterFn(v) -> filterFn(book from BooksClient, booksProfile) -> true to exclude
	--	it is assumed that if v == nil or v == "", never exclude
	Title = function(v)
		v = String.Trim(v):lower()
		local hasWords = v:match("%w+%W+%w+")
		local totalWords = 0
		local totalChars = 0
		local words = {}
		if hasWords then
			for word in v:gmatch("%w+") do
				totalWords += 1
				totalChars += #word
				table.insert(words, word)
			end
		end
		return function(book)
			if Books:BookTitleEquals(book, v) then
				return false, 200
			elseif Books:BookTitleContains(book, v) then
				return false, 100
			elseif hasWords then -- check for individual word matches
				local titleLength = #book.Title
				if titleLength < totalChars then return true end
				local found, partial = 0, 0
				for _, word in words do
					if Books:BookTitleContainsWholeWord(book, word) then
						found += 1
					elseif Books:BookTitleContains(book, word) then -- less points for a partial match
						partial += 1
					else
						return true
					end
				end
				return false, 80
					* (found + partial / 2) / totalWords
					* titleLength / totalChars

				---- Older version that accepts not finding all words:
				-- local found, foundChars, partial = 0, 0, 0
				-- for _, word in words do
				-- 	if Books:BookTitleContainsWholeWord(book, word) then
				-- 		found += 1
				-- 		foundChars += #word
				-- 	elseif Books:BookTitleContains(book, word) then -- less points for a partial match
				-- 		partial += 1
				-- 		foundChars += #word / 2
				-- 	end
				-- end
				-- if found + partial == 0 then
				-- 	return true
				-- end
				-- local penalty = if found + partial < totalWords then 80 else 0
				-- return false, 40 * ((found + partial / 2) / totalWords + foundChars / totalChars) - penalty -- up to 80 points if all words found
			else
				return true
			end
		end
	end,
	Author = function(value)
		--[[
		If 'value' refers to a player in the server, use their UserId, otherwise find all UserIds that this may refer to
		Go through all books and see if any of the UserIds are found
		After this, if insufficient results, see if any partial matches for 'value' exist in any book
		After this, if insufficient results, see if any partial matches for past usernames turn up any more ids.
		]]
		value = value:lower()
		local authorId = tonumber(value)
		if not authorId then -- see if the specified username is a player in the server
			for _, player in ipairs(Players:GetPlayers()) do
				if player.Name:lower() == value then
					authorId = player.UserId
					break
				end
			end
		end
		local authorIds = if authorId then {authorId} else AuthorDirectory.ExactMatches(value)
		local partialAuthorIds = AuthorDirectory.PartialMatches(authorId or value)
		if partialAuthorIds and authorIds then
			for i = #partialAuthorIds, 1, -1 do
				if table.find(authorIds, partialAuthorIds[i]) then
					table.remove(partialAuthorIds, i)
				end
			end
		end
		if partialAuthorIds and not partialAuthorIds[1] then
			partialAuthorIds = nil
		end
		return function(book)
			-- Look for exact match
			local lookup
			if authorIds then
				lookup = Books:GetAuthorIdLookup(book)
				for _, authorId in ipairs(authorIds) do
					if lookup[authorId] then
						return false, 200
					end
				end
			end

			-- Look for partial match
			if Books:AuthorNamesContainFullWord(book, value) then
				return false, 100
			elseif book.AuthorLine:match(value) then
				return false, 50
			end
			if partialAuthorIds then
				lookup = lookup or Books:GetAuthorIdLookup(book)
				for _, authorId in ipairs(partialAuthorIds) do
					if lookup[authorId] then
						return false, 0 -- author has past name that at least partially matches
					end
				end
			end

			-- No match
			return true
		end
	end,
	PublishedMin = function(v)
		return function(book)
			local publishTime = book.PublishDate and getDateTimeCached(book.PublishDate)
			return publishTime and publishTime < v - DAY_SECONDS / 2
		end
	end,
	PublishedMax = function(v)
		return function(book)
			local publishTime = book.PublishDate and getDateTimeCached(book.PublishDate)
			return publishTime and publishTime > v + DAY_SECONDS * 1.5 -- we want to add a full day of seconds since we want the end of the day (plus half a day buffer)
		end
	end,

	PagesMin = function(v) return function(book)
		return book.PageCount and book.PageCount < v
	end end,
	PagesMax = function(v) return function(book)
		return book.PageCount and book.PageCount > v
	end end,

	-- Note: booksProfile:Get__ functions need normalization so they must have a 'not' in front of them
	-- General logic is to exclude if:
	--	(v == Always) == not (has the condition talked about)
	MarkedRead = function(v)
		v = v == Always
		return function(book, booksProfile)
			return v == not booksProfile:GetRead(book.Id)
		end
	end,
	Liked = function(v)
		v = v == Always
		return function(book, booksProfile)
			return v == not booksProfile:GetLike(book.Id)
		end
	end,
	Bookmarked = function(v)
		v = v == Always
		return function(book, booksProfile)
			local list = booksProfile:GetBookmarks(book.Id)
			local hasAny = list and list[1]
			return v == not hasAny
		end
	end,
	InBookPouch = function(v)
		v = v == Always
		return function(book, booksProfile, bookPouch)
			return v == not bookPouch:Contains(book.Id)
		end
	end,
	Audio = function(v)
		v = v == Always
		return function(book)
			return v == not book.HasAudio
		end
	end,

	Genres = function(t)
		local n = {}
		for genre, v in t do
			n[genre] = v == Always
		end
		return function(book)
			for genre, required in n do
				if required == not table.find(book.Genres, genre) then
					return true
				end
			end
		end
	end,
	Lists = function(t)
		local n = {}
		for name, v in t do
			n[name] = v == Always
		end
		return function(book, booksProfile)
			--print("all lists:", booksProfile:GetAllLists())
			for name, required in n do
				if booksProfile:HasList(name) and required == not booksProfile:ListHasBook(name, book.Id) then
					return true
				end
			end
		end
	end,
}

-- TODO see what happens when we have metrics & see if any numbers need to change!
local likedMg = 5
local function likedScore(metrics)
	local eReads = math.max(metrics.EReads, 0)
	local likes = math.max(metrics.Likes, 0)
	return -(eReads + 10) / (likes + 1.5) / 5 * likedMg -- magnitude of this is estimated to be 1 -> 5 for good books and 6 -> 20 for lesser books (though can go arbitrarily high)
	-- Thus, the likes have an effect size of +/-5 before the "/ 5 * likedMg"
end

local readPercentMg = 5
local function lengthMult(n)
	return 1 + math.min(n / 40, 1)
end
local function readPercentScore(book, metrics)
	local numPages = book.PageCount
	if numPages and metrics.Open >= 2 then
		local pagePairs = math.ceil(numPages / 2)
		return (metrics.Pages / metrics.Open / pagePairs * lengthMult(book.PageCount) * 20 - 6) / 8 * readPercentMg
		-- metrics.Pages / metrics.Open / pagePairs is avg read %
		-- avg read % might be 10%->50%
		-- it is likely to be lower for longer books, which is the purpose of lengthMult
		-- so 0.1 -> 0.5 is the score, then we * 20 to get 2 -> 10, then - 6 so that a book without a calculated page count is considered "average"
		--	before the final multiplication, effect size is ~8
		--	(8 * 0.6 = 4.8)
	end
	return 0
end

local unseenMg = 20 -- effect size for major part of the unseen bonus
local unseenRate = 15 -- the larger this is, the longer it takes for the unseen bonus to wear off
--	after unseenRate * 1 people have seen the book, the sigmoid curve gets to 45% of its maximum value
--	after unseenRate * 2, 76%
--	after unseenRate * 3, 90%
local function unseenScore(metrics)
	local seen = metrics.Seen
	return -(2 * unseenMg / (1 + math.exp(-seen / unseenRate)) - unseenMg) - seen / 50
end

local unreadMg = 6
local unreadRate = 0.5 -- loss in bonus per read
local function unreadScore(metrics)
	local eReads = math.max(metrics.EReads, 0)
	return math.max(0, unreadMg - eReads * unreadRate)
end

-- The "calculate" functions are with particular sorts in mind
local function calculateRecommendedNewScore(book, metrics)
	-- TODO print these values out per book after some metrics have come in and see how the books are doing -- how are the relative effect sizes in practice?
	return likedScore(metrics)
		+ readPercentScore(book, metrics)
		+ unseenScore(metrics)
		+ unreadScore(metrics)
end
local function calculateLikedScore(book, metrics)
	--	"Liked" and read at least a little bit
	-- We subtract the unreadScore to lower the score of any book that happens to have a good ratio but hasn't had much readership
	return likedScore(metrics) * 2 + readPercentScore(book, metrics) - unreadScore(metrics)
end
-- local function calculateLikeRatioScore(book, metrics)
-- 	local eReads = math.max(metrics.EReads, 0)
-- 	local likes = math.max(metrics.Likes, 0)
-- 	return if eReads > 0 then likes / eReads else 0
-- end
-- BTS is BookToScore
local function genBTS(calc)
	return function(results, allMetrics, bookToScore)
		local bts = {}
		for _, book in ipairs(results) do
			bts[book] = bookToScore[book] + calc(book, allMetrics[book.Id])
		end
		return bts
	end
end
local getBTSRec = genBTS(calculateRecommendedNewScore)
local getBTSLiked = genBTS(calculateLikedScore)
local btsToSort = function(bts) -- returns a results table sort function
	return function(a, b) return bts[a] > bts[b] end
end
local recommendedPopular = 2
local recommendedNew = 1
local rnd = Random.new()
local sorts = {
	Recommended = function(results, bookToScore)
		-- Note: we can't just use 1 single score for all books since we want a mix of top liked books and untested ones
		--	If we try to use just a single score, then regardless of how we balance them, when a set of 20 new books are published, we'll just end up with a blob of 20 new books somewhere in the list (whether at the top or further down)
		local allMetrics = BookMetrics.Get()
		local btsRec = getBTSRec(results, allMetrics, bookToScore)
		local btsLike = getBTSLiked(results, allMetrics, bookToScore)

		local resultsRec = results
		table.sort(resultsRec, btsToSort(btsRec))
		local resultsLike = table.clone(results)
		table.sort(resultsLike, btsToSort(btsLike))
		local seen = {}
		local nResults = #resultsRec
		local results = table.create(nResults)
		-- now merge them
		local function genGet(results)
			local i = 0
			return function()
				local result
				repeat
					i += 1
					result = results[i]
				until not seen[result] -- will break if result is nil
				if result then
					seen[result] = true
					return result
				end
			end
		end
		local getRec = genGet(resultsRec)
		local getLike = genGet(resultsLike)
		local n = 0
		while n < nResults do
			for i = 1, recommendedPopular do
				n += 1
				results[n] = getRec()
			end
			if n >= nResults then break end
			for i = 1, recommendedNew do
				n += 1
				results[n] = getRec()
			end
		end
		return results
	end,
	WellLiked = function(results, bookToScore)
		table.sort(results, btsToSort(getBTSLiked(results, BookMetrics.Get(), bookToScore)))
		return results
	end,
	Random = function(results, bookToScore)
		local bts = {}
		for _, result in ipairs(results) do
			bts[result] = bookToScore[result] + rnd:NextNumber(0, 10)
		end
		table.sort(results, btsToSort(bts))
		return results
	end,
}
local sortTypeToMetricsKey = {
	Reads = "EReads",
	Likes = "Likes",
}
local sortTypeToBookKey = {
	Author = "AuthorLine",
	Genre = "GenreLine",
}
local function isEmptyTable(t) -- Works even if 't' has a custom iterator ('next(t)' doesn't use the custom iterator)
	for k, v in t do
		return false
	end
	return true
end
local function getFilters(config)
	local filters = {}
	for k, gen in excludeFilters do
		local v = config[k]
		if v == nil or v == "" or (type(v) == "table" and isEmptyTable(v)) then continue end
		table.insert(filters, gen(v))
	end
	return filters
end
local function getResults(config, booksProfile, bookPouch) -- unsorted
	local filters = getFilters(config)
	if not filters[1] then
		local results = table.clone(books)
		local bookToScore = {}
		for _, book in ipairs(results) do
			bookToScore[book] = 0
		end
		return results, bookToScore
	end
	local results = table.create(250)
	local bookToScore = {}
	local n = 0
	for _, book in ipairs(books) do
		local keep = true
		local score = 0
		for _, filter in filters do
			local exclude, delta = filter(book, booksProfile, bookPouch)
			if exclude then
				keep = false
				break
			end
			if delta then
				score += delta
			end
		end
		if keep then
			n += 1
			results[n] = book
			bookToScore[book] = score
		end
	end
	return results, bookToScore
end
local function sortResults(config, results, bookToScore)
	local sortType = config.SortType or "Recommended"
	local sortFn = sorts[sortType]
	if sortFn then
		return sortFn(results, bookToScore)
	end
	local ascending = config.SortAscending
	if ascending == nil then
		local ascendingData = BookSearch.GetAscendingDataForSortType(sortType)
		ascending = if ascendingData then ascendingData.Default else false -- if ascending/descending toggle not allowed, always sort descending (best value first)
	end
	local metricsKey = sortTypeToMetricsKey[sortType]
	local compare
	if metricsKey then
		local allMetrics = BookMetrics.Get()
		compare = if ascending
			then function(a, b)
				return allMetrics[a.Id][metricsKey] < allMetrics[b.Id][metricsKey]
			end
			else function(a, b)
				return allMetrics[a.Id][metricsKey] > allMetrics[b.Id][metricsKey]
			end
	elseif sortType == "Pages" then
		compare = if ascending
			then function(a, b) return (a.PageCount or 0) < (b.PageCount or 0) end
			else function(a, b) return (a.PageCount or 0) > (b.PageCount or 0) end
	elseif sortType == "Published" then
		compare = if ascending
			then function(a, b) return (getDateTimeCached(a.PublishDate) or 0) < (getDateTimeCached(b.PublishDate) or 0) end
			else function(a, b) return (getDateTimeCached(a.PublishDate) or 0) > (getDateTimeCached(b.PublishDate) or 0) end
	else
		local key = sortTypeToBookKey[sortType] or sortType
		compare = if ascending
			then function(a, b) return a[key] < b[key] end
			else function(a, b) return a[key] > b[key] end
	end
	table.sort(results, function(a, b)
		local baseA, baseB = bookToScore[a], bookToScore[b]
		if baseA == baseB then
			return compare(a, b)
		else -- we always want highest (most relevant) results first
			return baseA > baseB
		end
	end)
	return results
end
function BookSearch.GetAscendingDataForSortType(sortType)
	return (typeToSortData[sortType] or error("'" .. tostring(sortType) .. "' is not a valid sort type", 2)).AscendingAllowed
end
function BookSearch.NewSearch(config, booksProfile, bookPouch)
	--	returns a function that will return the list of results in sorted order
	local results, bookToScore = getResults(
		config or error("config missing", 2),
		booksProfile or error("booksProfile missing", 2),
		bookPouch or error("bookPouch is missing", 2))
	return function()
		return sortResults(config, results, bookToScore)
	end
end

return BookSearch