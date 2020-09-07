-- TODO Refactor ReplaceInStrings and RemoveAllComments to share string start and end detection
--	The 'start' detection needs to return the starting index of the next string found (and the opening string characters at that location)
--	The 'end' detection needs to return the ending index given an index to start searching at and the opening string characters
local function replaceInStrings(s, func)
	--	func(stringContent, stringOpening) -- stringOpening can be ' " [[ [=[ etc
	--	if 'func' returns nil, no change will be made
	local new = {}
	local newI = 0
	local i = 1 -- character index (of s) that we haven't saved into 'new'
	local n = #s
	local nPlus1 = n + 1
	local function saveTo(lastChar)
		newI += 1
		new[newI] = s:sub(i, lastChar)
		i = lastChar + 1
	end
	local function stringTo(lastContentChar, stringOpening)
		newI += 1
		local sub = s:sub(i, lastContentChar)
		new[newI] = func(sub, stringOpening) or sub
		i = lastContentChar + 1
	end
	while i < n do -- cannot have a full string at i == n
		local nextQuote, _, quote = s:find("(['\"])", i)
		local nextBlock, nextBlock2, minusSigns, equals = s:find("(%-?%-?)%[(=-)%[", i)
		local nextLineComment = s:find("%-%-", i)
		local min = math.min(nextQuote or nPlus1, nextBlock or nPlus1, nextLineComment or nPlus1)
		if nextQuote == min then
			saveTo(nextQuote)
			local pattern = "(\\*)" .. quote
			local cur = i
			while true do
				local _, stopQuote, backslashes = s:find(pattern, cur)
				if not stopQuote then -- save to end of string
					saveTo(n)
					break
				elseif #backslashes % 2 == 0 then -- end of string
					stringTo(stopQuote - 1, quote)
					saveTo(stopQuote)
					break
				else -- this was escaped; keep searching past this point
					cur = stopQuote + 1
				end
			end
		elseif nextBlock == min then
			local isComment = #minusSigns == 2
			local stopBlock, stopBlock2 = s:find("%]" .. equals .. "%]", nextBlock2 + 1)
			if not stopBlock then
				saveTo(n)
				break
			elseif isComment then
				saveTo(stopBlock2)
			else
				saveTo(nextBlock2)
				stringTo(stopBlock - 1, "[" .. equals .. "[")
				saveTo(stopBlock2)
			end
		elseif nextLineComment == min then -- note: nextLineComment might equal nextBlock so we check it after (since --[[ is a block comment not a line comment)
			local stopLine = s:find("\n", nextLineComment + 2)
			if stopLine then
				saveTo(stopLine)
			else
				saveTo(n)
				break
			end
		else
			break
		end
	end
	if i <= n then
		newI += 1
		new[newI] = s:sub(i, n)
	end
	return table.concat(new)
end
return replaceInStrings