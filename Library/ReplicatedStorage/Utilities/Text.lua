local Text = {}
function Text.CountWords(text)
	-- We need to prepend a " " because ^%p%s includes control characters
	--	and the start and end of the string are considered control characters by the frontier pattern
	local _, num = (" " .. text):gsub("%f[^%p%s].", "")
	return num
end
function Text.IterWords(text)
	--	"for word, spacingAfterWord in IterWords(text) do"
	--	word can be "" if 'text' begins with whitespace
	-- spacingAfterWord can be "" if there is no whitespace after a word ("like!this")
	local i = 1
	local nextSpaceStart, nextSpaceEnd = string.find(text, "%s+", i)
	local nextWordStart, nextWordEnd = string.find(text, "[^%p%s]+", i)
	local nextPuncStart, nextPuncEnd = string.find(text, "%p+", i)
	return function()
		--[[Current character is either:
			whitespace (return "", whitespace)
			word (return word, any whitespace after that)
			punctuation (include as part of word)
		]]
		local word, space
		if i == nextWordStart then
			word = string.sub(text, nextWordStart, nextWordEnd)
			i = nextWordEnd + 1
			nextWordStart, nextWordEnd = string.find(text, "[^%p%s]+", i)
		end
		if i == nextPuncStart then
			word = (word or "") .. string.sub(text, nextPuncStart, nextPuncEnd)
			i = nextPuncEnd + 1
			nextPuncStart, nextPuncEnd = string.find(text, "%p+", i)
		end
		if i == nextSpaceStart then
			space = string.sub(text, nextSpaceStart, nextSpaceEnd)
			i = nextSpaceEnd + 1
			nextSpaceStart, nextSpaceEnd = string.find(text, "%s+", i)
		end
		if not word and not space then
			if i <= #text then
				local word = string.sub(text, i)
				i = #text + 1
				return word, ""
			else
				return nil
			end
		end
		return word or "", space or ""
	end
end
return Text