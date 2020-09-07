local String = require(game:GetService("ReplicatedStorage").Utilities.String)
local function removeAllComments(source, removeBlankLines)
	--	Note: only supports removing line comments (but does properly respect block strings)
	--	removeBlankLines: if true, the resulting string will have all blank lines removed, except it allows 1 line between code
	local s = {} -- new source
	local index = 1
	local length = #source
	local lengthPlusOne = length + 1
	--[[ex
	abc--\ndef
	123456 789	<-- index in string
	index = 1, we want to save the first 3 characters, nextCommentStart will be 4
	so we save 'abc' and set index = 4
	then \n will be a non-comment, index 6
	so we skip 45 and set index to 6

	Newline handling eulre: keep the newline if next line has content or no comment
	Equivalently: throw away the newline if the next line has no content but does have a comment
	ex:
	abc\ndef\nghi\n--c

	so comment is at '--'
	so if we look backwards, we want to consume up to 1 newline (along with any spaces/tabs that are in the way)
	]]
	local function startComment(atIndex)
		if atIndex > index then
			s[#s + 1] = source:sub(index, atIndex - 1)
		end
		index = atIndex
	end
	local function endOfSource()
		if lengthPlusOne > index then
			s[#s + 1] = source:sub(index, length)
		end
	end
	local function endComment(atIndex)
		--	atIndex: newline character that ends the comment (or this can be the end of the source, ie lengthPlusOne)
		-- First, look back at last string. If it has a newline followed by spaces/tabs followed by this comment we're ending, remove the newline
		--	If it just has spaces/tabs before the comment, remove those also
		local sIndex = #s
		if sIndex > 0 then
			local last = s[sIndex]
			local n = #last
			local i = n -- 'i' becomes the index of the character we intend to keep
			while i > 0 do
				local c = last:sub(i, i)
				if c == "\n" then -- get rid of the newline because there's nothing else on this line
					i -= 1
					break
				elseif c ~= "\t" and c ~= " " then -- there's something else on this line, so get rid of any spaces/tabs we've seen so far
					break
				end
				i -= 1
			end
			if i < n then
				local new = last:sub(1, i)
				if new == "" then new = nil end
				s[sIndex] = new
				-- we want to ignore next newline if we haven't stored anything for output yet
				if sIndex == 1 and not new and source:sub(atIndex, atIndex) == "\n" then
					atIndex += 1
				end
			end
		end
		index = atIndex
	end
	while index < length do
		local nextCommentStart, _ = source:find("%-%-", index)
		local nextStringStart, _, quotationMark = source:find("(['\"])", index)
		local nextBlockStart, _, equals = source:find("%[(=*)%[", index)
		local nextIndex = math.min(nextCommentStart or lengthPlusOne, nextStringStart or lengthPlusOne, nextBlockStart or lengthPlusOne)
		if nextIndex == nextCommentStart then
			startComment(nextIndex)
			endComment(source:find("\n", index) or lengthPlusOne)
		elseif nextIndex == nextStringStart then
			-- look for another quotationMark that *isn't* escaped
			local i = nextIndex + 1
			while i < length do
				-- it's escaped if there is an odd number of \s behind it
				local _, stringEnd, slashes = source:find("(\\*)" .. quotationMark, i)
				if not stringEnd then
					i = lengthPlusOne
					break
				end
				if #slashes % 2 == 0 then
					i = stringEnd + 1
					break
				end
				i = stringEnd + 1
			end
			s[#s + 1] = source:sub(index, i - 1)
			index = i
		elseif nextIndex == nextBlockStart then
			-- look for ending block
			local _, blockEnd = source:find("%]" .. equals .. "%]", index)
			local i = blockEnd and blockEnd + 1 or lengthPlusOne
			s[#s + 1] = source:sub(index, i - 1)
			index = i
		else
			assert(nextIndex == lengthPlusOne) -- pretty sure this is the case
			break
		end
	end
	endOfSource()
	return removeBlankLines and
		String.Trim(table.concat(s)):gsub("\n\n+", "\n\n")
		or table.concat(s)
end
return removeAllComments