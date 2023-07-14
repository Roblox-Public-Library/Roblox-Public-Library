local String = require(game:GetService("ReplicatedStorage").Utilities.String)

local BookVersionUpgrader = {}

local alphaNumeric = {}
for i = 48, 57 do alphaNumeric[string.char(i)] = true end
for i = 65, 90 do alphaNumeric[string.char(i)] = true end
for i = 97, 122 do alphaNumeric[string.char(i)] = true end

local isChapter, getChapterPieces do
	local MAX_CHAPTER_LINE_LENGTH = 100 -- There is at least one chapter of length 80
	local alphaNumericPuncSpaceChars = "a-zA-Z0-9.!?'\"`#$%%%^& \t" -- characters that are likely part of a chapter name (and not part of decoration)
	local contentClass = "[" .. alphaNumericPuncSpaceChars .. "]"
	local symbolClass = "[^" .. alphaNumericPuncSpaceChars .. "]"
	local trimMatch = "^" .. symbolClass .. "*(.*" .. contentClass .. ")"
	local chapterTerms = {"Chapter", "Article", "Section", "Introduction"}
	for i, term in ipairs(chapterTerms) do -- allow lowercase letters to be uppercase
		chapterTerms[i] = "^" .. term:gsub("[a-z]", function(char) return "[" .. char .. char:upper() .. "]" end)
	end
	function isChapter(line)
		--	If it is a chapter, returns the chapter term the line starts with (like "chapter" or "Article")
		if line == "" then return false end
		if #line > MAX_CHAPTER_LINE_LENGTH then return false end
		local trimmed = line:match(trimMatch)
		if not trimmed then return false end
		for _, term in ipairs(chapterTerms) do
			local match = trimmed:match(term)
			if match then
				return match
			end
		end
		return false
	end
	BookVersionUpgrader.IsChapter = isChapter
	local pattern = "^%s*(" .. contentClass .. "*)(%s*" .. symbolClass .. "*%s*)([%(%)%[%]%{%}" .. alphaNumericPuncSpaceChars .. "]*)"
	function getChapterPieces(line)
		local term = isChapter(line)
		if not term then return false end
		local a, b = line:find(term)
		local rest = line:sub(b + 1)
		local num, sep, title = rest:match(pattern)
		-- In "Chapter 1 - First", "num" picks up "1 " but we want that as part of the separator
		local start, stop = num:find("%s+$")
		if start then
			local sub = num:sub(start, stop)
			num = num:sub(1, start - 1)
			sep = sub .. sep
		end
		return term, num, sep, title
	end
	BookVersionUpgrader.GetChapterPieces = getChapterPieces
end
local function convertWordToMarkdown(word, isLastWord)
	-- Note: In the if/elseif branches below, related commands are grouped together and otherwise sorted based on approximate usage frequency (but with quick-to-check commands like "/line" first, except for "/kill", which is put last as that's only used in one book).
	if word == "/line" then
		return "\n"
	elseif word == "/dline" then
		return "\n\n"
	elseif word == "/page" then
		return "<page>"
	elseif word == "/turn" then
		return "<turn>"
	elseif string.sub(word, 2, 6) == "image" then
		local n = tonumber(string.sub(word, 7, 8))
		if not n then return nil end
		local imageHeight = math.min(20, n) * 5
		local imageId = string.sub(word, 9):match("(%d+)/?$")
		if not imageId then return nil, "no image id" end
		return string.format("<image,%s,%dh>", imageId, imageHeight)
	elseif string.sub(word, 2, 12) == "retainImage" then
		local n = tonumber(string.sub(word, 13, 14))
		if not n then return nil, "no image height" end
		local imageHeight = math.min(15, n) * 5
		local imageId = string.sub(word, 15):match("(%d+)/?$")
		if not imageId then return nil, "no image id" end
		return string.format("<image,%s,%dh>", imageId, imageHeight)
	else
		local i
		local cmd
		if string.sub(word, 2, 9) == "endImage" then
			i = 10
			cmd = "endImage"
		elseif string.sub(word, 2, 10) == "fillImage" then
			i = 11
			cmd = "fillImage"
		end
		if i then
			local n = tonumber(string.sub(word, i, i + 1))
			if not n then return nil, "no image height" end
			local imageHeight = math.min(20, n) * 5
			local imageId = string.sub(word, i + 2):match("(%d+)/?$")
			if not imageId then return nil, "no image id" end
			local image = string.format("<image,%s,%dh>", imageId, imageHeight)
			if isLastWord or (imageHeight < 20 and cmd ~= "fillImage") then
				return image
			else
				return image .. "<page>"
			end
		elseif string.sub(word, 1, 6) == "/hline" then
			local char = string.sub(word, 7, 7)
			if char == "-" or char == "_" then
				return "<bar>"
			else
				return "<bar," .. char .. ">"
			end
		elseif word == "/kill" then
			return "<flag,kill>"
		end
	end
	return word
end
local function convertLastWordToMarkdown(word) return convertWordToMarkdown(word, true) end

local MIN_CHARS_FOR_BAR = 5
local MIN_CHARS_FOR_LINE_ANALYSIS = math.min(#("Section 1"), MIN_CHARS_FOR_BAR)
local function escape(txt)
	return txt:gsub("[,\\>_~]", "\\%1"):gsub("<", "&lt;")
		:gsub("[^\n]+", function(line) -- find lines with *s and consider escaping them
			local a, b = line:find("%*+")
			if not a then return nil end
			-- Find pairs of * or **. Any other order or if there's a length of 3+ *s in a row, escape them.
			local count = 1
			local prevN
			while true do
				local n = b - a + 1
				if n > 2 or (prevN and prevN ~= n and count % 2 == 0) then -- not using it for formatting so escape entire line
					return line:gsub("%*", "\\*")
				end
				prevN = n
				local c, d = line:find("%*+", b + 1)
				if not c then
					if count % 2 == 1 then -- escape last intance of it
						return line:sub(1, a - 1)
							.. string.rep("\\*", n)
							.. line:sub(b + 1)
					else
						return line -- no escaping required
					end
				end
				count += 1
				a, b = c, d
			end
		end)
end
BookVersionUpgrader.Escape = escape
local function analyzeLine(line)
	if #line < MIN_CHARS_FOR_LINE_ANALYSIS then return end
	-- Bar detection followed by section detection
	local firstChar = line:sub(1, 1)
	local repeatedChar = #line >= MIN_CHARS_FOR_BAR and string.match(line, (if alphaNumeric[firstChar] then "^" else "^%") .. firstChar .. "+$") and firstChar
	if repeatedChar then
		if alphaNumeric[repeatedChar] then
			return "<bar," .. repeatedChar .. ">"
		else
			return "<bar,\\" .. repeatedChar .. ">"
		end
	else
		local chapterTerm = isChapter(line)
		local term, num, sep, title = getChapterPieces(line)
		if term then
			local name = string.format("**%s %s**%s%s", term, num, sep, title)
			return string.format("<section2,%s,%s>", escape(name), escape(line))
		end
	end
end
local function breakDownAndAnalyzeLine(line) -- line may be multiple lines if it has page/turn commands in it
	local before, mid, after = line:match("^%s*(.-)%s*(<%s*[pt][au][gr][en]%s*>)%s*(.-)%s*$") -- the [pt] part is detecting <page/turn>; before/after are trimmed
	if not before then -- just one line
		local trimmedLine = String.Trim(line)
		local new = analyzeLine(trimmedLine)
		return new or if trimmedLine == line then nil else trimmedLine
	else
		local newBefore, newAfter
		if before ~= "" then
			newBefore = analyzeLine(before)
		end
		if after ~= "" then
			newAfter = breakDownAndAnalyzeLine(after)
		end
		if newBefore or newAfter then
			return (newBefore or before) .. mid .. (newAfter or after)
		end
	end
end
function BookVersionUpgrader.UpgradeV1(data) -- converts to markdown
	data.Content = escape(table.concat(data.Words, " "))
		:gsub("%s+", " ") -- original treats strings of whitespace as 1 space
		:gsub("/%S+$", convertLastWordToMarkdown)
		:gsub("(/%S+)", function(command)
			local new, issue = convertWordToMarkdown(command)
			if issue then
				print(data.Title, "by", table.concat(data.AuthorNames, ", "), "upgrade issue:", issue)
			end
			if new and new ~= command then
				return new
			end
		end)
		:gsub("[^\n]+", breakDownAndAnalyzeLine)
	data.Words = nil
	return data
end
return BookVersionUpgrader