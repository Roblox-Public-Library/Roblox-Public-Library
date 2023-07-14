local Genres = require(game:GetService("ReplicatedStorage").Library.Genres)

local normalizedToGenre = {}
local function normalize(genre)
	return genre:gsub("%W+", ""):lower()
end
Genres.Normalize = normalize
for _, genre in ipairs(Genres) do
	local normalized = normalize(genre)
	normalizedToGenre[normalized] = genre
	if normalized:sub(-1, -1) == "s" then -- also store non-pluralized form (this is not correct for Miscellaneous, but it doesn't hurt to allow 'Miscellaneou')
		normalizedToGenre[normalized:sub(1, -2)] = genre
	end
end
local aliases = {
	-- Note: also see commonExtras for things that will optionally be removed when comparing to aliases, so aliases don't need to mention them
	--	ex "fic"/"fiction" are in the list, so (for instance) "Fan Fiction" doesn't need "fanfic", only "fan"
	--	Also note: "world" will always be removed
	["Astronomy"] = {"astrology"},
	["Children's"] = {"child"},
	["Comedy"] = {"humor", "humour"},
	["Critiques"] = {"bookcritics", "critics"},
	["Culture"] = {"art", "arts"},
	["Economics & Money"] = {"moneyeconomics", "moneyeconomy", "money", "economics", "economy", "econ", "moneyecon", "econmoney"},
	["Facts"] = {"non"}, -- non == non-fiction
	["Fan Fiction"] = {"fan"},
	["Fantasy"] = {"fairytale"},
	["Fiction"] = {"fic", "literature", "lit", "englishliterature", "englishlit"},
	["Geography"] = {"geo"},
	["Health"] = {"lifehealth"},
	["Historical Fiction"] = {"historical"},
	["Horror"] = {"scary"},
	["Languages"] = {"foreignlang", "foreignlanguage", "foreignlanguages", "lang"},
	["Life Learn"] = {"life"},
	["Mathematics"] = {"math", "maths"},
	["Miscellaneous"] = {"misc", ""}, -- empty string will catch "world"
	["Mythology"] = {"myth", "myths"}, -- in future include: "legends" (remove from Roblox Legends)
	["People"] = {"biography", "autobiography"},
	["Poetry"] = {"poem", "poems"},
	["Reference"] = {"grammar", "information"},
	["Roblox Clans"] = {"clans", "clan"},
	["Roblox Economy"] = {"robloxeconomymoney", "robloxmoney"},
	["Roblox Games"] = {"obbies", "obby"},
	["Roblox Groups"] = {"groups"},
	["Roblox Legends"] = {"legends", "robloxmyths"}, -- todo in future 'legends' on own probably shouldn't alias to this (close to 'mythology')
	["Roblox Lua"] = {"lua", "developers", "develop", "dev", "devs", "developing"}, -- todo all the aliases related to "Roblox Development" should not be an alias of Roblox Lua
	["Science"] = {"sci"},
	["Science Fiction"] = {"scifi"},
	["Technology"] = {"tech", "techs", "technologies"},
}
local commonMispellings = {
	-- spellingMistake = correct spelling (in normalized form)
	-- Be careful not to add a substring of a legitimate string (ex 'ppl' below would be bad if we had an 'apple' genre)
	learning = "learn", -- not a spelling mistake but simplifies aliases
	rbx = "Roblox",
	rblx = "Roblox",
	ficiton = "fiction",
	ficton = "fiction",
	languege = "language",
	ppl = "people",
	refrence = "reference",
}
local commonExtras = {
	-- List of words that are often tacked on that can likely be removed
	-- These strings will be removed from the input one at a time if the input doesn't match any genres/aliases, after considering mispellings
	-- When one extra is a substring of another, put the longer version first
	"learn",
	"fiction",
	"fic",
	"literature",
	"lit",
	-- "world" is always removed first so needn't be here
}
for genre, aliasList in pairs(aliases) do
	for _, alias in ipairs(aliasList) do
		local normalized = normalize(alias)
		if normalizedToGenre[normalized] == genre then
			print("Alias", alias, "->", genre, "is unnecessary")
		elseif normalizedToGenre[normalized] then
			warn(("Alias '%s' -> '%s', but its normalized form '%s' already -> '%s'!"):format(alias, genre, normalized, normalizedToGenre[normalized]))
		else
			normalizedToGenre[normalize(alias)] = genre
		end
	end
end
local function applyMispellings(input)
	for incorrect, correct in pairs(commonMispellings) do
		input = input:gsub(incorrect, correct)
	end
	return input
end
function Genres.InputToGenre(input)
	input = normalize(input):gsub("world", "") -- 'world' is never valid
	local genre = normalizedToGenre[input]
	if not genre then
		input = applyMispellings(input)
		genre = normalizedToGenre[input]
		if not genre then
			for _, extra in ipairs(commonExtras) do
				input = input:gsub(extra, "")
				genre = normalizedToGenre[input]
				if genre then break end
			end
		end
	end
	return genre
end
function Genres.IsGenre(genre)
	return normalizedToGenre[normalize(genre)]
end

return Genres