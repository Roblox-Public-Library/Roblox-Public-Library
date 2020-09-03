local Genres = {
	"Action",
	"Adventure",
	"Animals",
	"Astronomy",
	"Children's",
	"Comedy",
	"Comics",
	"Conduct",
	"Critiques",
	"Culture",
	"Economics & Money",
	"English Literature",
	"Events",
	"Facts",
	"Fan Fiction",
	"Fantasy",
	"Fiction",
	"Folklore",
	"Foods",
	"Foreign Languages",
	"Games",
	"Geography",
	"Health",
	"Historical Fiction",
	"History",
	"Horror",
	"Library Archives",
	"Library Post",
	"Life Learn",
	"Mathematics",
	"Media",
	"Miscellaneous",
	"Music",
	"Mystery",
	"Mythology",
	"Nature",
	"People",
	"Philosophy",
	"Poetry",
	"Politics",
	"Psychology",
	"Reference",
	"Relationships",
	"Religion",
	"Roblox Clans",
	"Roblox Development",
	"Roblox Economy",
	"Roblox Fiction",
	"Roblox Games",
	"Roblox Groups",
	"Roblox History",
	"Roblox Learning",
	"Roblox Legends",
	"Roblox Lua",
	"Roblox People",
	"Romance",
	"Science Fiction",
	"Science",
	"Short Story",
	"Social",
	"Sports",
	"Technology",
	"Travel",
}
local normalizedToGenre = {}
local function normalize(genre)
	return genre:gsub("%W+", ""):lower()
end
Genres.Normalize = normalize
for _, genre in ipairs(Genres) do
	normalizedToGenre[normalize(genre)] = genre
end
local aliases = {
	-- Note: "fic"/"fiction" will be optionally removed when comparing to aliases, so aliases don't need to mention them
	--	Also, "world" will always be removed
	["Astronomy"] = {"astrology"},
	["Children's"] = {"children", "child"},
	["Comics"] = {"comic"},
	["Critiques"] = {"bookcritics", "critics"},
	["Culture"] = {"art", "arts"},
	["Economics & Money"] = {"moneyeconomics", "moneyeconomy", "money", "economics", "economy", "econ", "moneyecon", "econmoney"},
	["English Literature"] = {"literature", "lit"},
	["Events"] = {"event"},
	["Facts"] = {"non"}, -- non == non-fiction
	["Fan Fiction"] = {"fan"},
	["Fantasy"] = {"fairytale"},
	["Foods"] = {"food"},
	["Foreign Languages"] = {"foreignlanguage", "foreignlang", "language", "languages", "lang"},
	["Geography"] = {"geo"},
	["Health"] = {"lifehealth"},
	["Historical Fiction"] = {"historical"},
	["Library Archives"] = {"libraryarchive"},
	["Life Learn"] = {"life"},
	["Mathematics"] = {"math"},
	["Miscellaneous"] = {"misc", ""}, -- empty string will catch "world"
	["Mythology"] = {"myth", "myths"},
	["People"] = {"biography", "autobiography"},
	["Roblox Clans"] = {"clans", "clan", "roblox clan"},
	["Roblox Games"] = {"obbies", "obby"},
	["Roblox Groups"] = {"groups"},
	["Roblox History"] = {"robloxhistory"},
	["Roblox Learning"] = {"robloxlearn", "robloxlearning", "learn"},
	["Roblox Legends"] = {"legends", "robloxmyths"}, -- todo in future 'legends' on own probably shouldn't alias to this (close to 'mythology')
	["Roblox Lua"] = {"lua"},
	["Science"] = {"sci"},
	["Science Fiction"] = {"scifi"},
	["Technology"] = {"tech"},
	["Fiction"] = {"fic"},
}
for genre, aliasList in pairs(aliases) do
	for _, alias in ipairs(aliasList) do
		normalizedToGenre[normalize(alias)] = genre
	end
end
function Genres.InputToGenre(input)
	input = normalize(input):gsub("world", "") -- world is never valid
	return normalizedToGenre[input]
		or normalizedToGenre[input:gsub("fiction", ""):gsub("fic", "")]
end
return Genres