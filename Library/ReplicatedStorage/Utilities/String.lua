local String = {}
function String.Trim(s) -- Is trim6 from http://lua-users.org/wiki/StringTrim.
	return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end
function String.LTrim(s)
	return s:match'^%s*(.*)'
end
function String.RTrim(s)
	return s:match'^()%s*$' and '' or s:match'^(.*%S)'
end
function String.Split(s, char)
	--	char is a string with 1+ delimiter(s) (each delimiter must be 1 character long)
	--	Note: Roblox's string.split looks for a single delimeter of length 1+, whereas this function looks for 1+ delimiters of length 1
	--	ex:
	--		("abc,def|ghi"):split(",|") -> {"abc,def|ghi"} -- it sees no ',' followed by '|'
	--		String.Split("abc,def|ghi", ",|") -> {"abc", "def", "ghi"}
	--		Also, ("abc"):split("") -> {"a", "b", "c"}
	local t = {}
	local n = 0
	for str in s:gmatch("([^" .. char .. "]+)") do
		n = n + 1
		t[n] = str
	end
	return t
end
function String.SplitReturnDelimiters(s, char)
	--	char is a string with 1+ delimiter(s) (each delimiter must be 1 character long)
	--	See String.Split for comparison to string.split
	--	This function returns the delimiter (delimiter[1] was whatever was after the 1st string in the table returned)
	local t = {}
	local delims = {}
	local n = 0
	for str, delim in s:gmatch("([^" .. char .. "]+)([" .. char .. "]*)") do
		n = n + 1
		t[n] = str
		delims[n] = delim
	end
	return t, delims
end
return String