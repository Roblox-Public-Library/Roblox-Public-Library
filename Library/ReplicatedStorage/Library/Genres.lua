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
	"Events",
	"Facts",
	"Fan Fiction",
	"Fantasy",
	"Fiction",
	"Folklore",
	"Foods",
	"Games",
	"Geography",
	"Health",
	"Historical Fiction",
	"History",
	"Horror",
	"Languages",
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
	"Roblox Learn",
	"Roblox Legends",
	"Roblox Lua",
	"Roblox People",
	"Romance",
	"Science Fiction",
	"Science",
	"Secret",
	"Short Story",
	"Social",
	"Sports",
	"Technology",
	"Travel",
}

-- Categories
local fiction = {
	"Action",
	"Adventure",
	"Children's",
	"Comedy",
	"Comics",
	"Fan Fiction",
	"Fantasy",
	"Fiction",
	"Folklore",
	"Horror",
	"Miscellaneous",
	"Mystery",
	"Mythology",
	"Poetry",
	"Romance",
	"Science Fiction",
	"Short Story",
}
local roblox = {}
for _, genre in ipairs(Genres) do
	if genre:match("Roblox") then
		table.insert(roblox, genre)
	end
end
local nonFiction = {}
for _, genre in ipairs(Genres) do
	if not table.find(fiction, genre) and not table.find(roblox, genre) and genre ~= "Secret" then
		table.insert(nonFiction, genre)
	end
end
Genres.Categories = {
	Fiction = fiction,
	["Non-Fiction"] = nonFiction,
	Roblox = roblox,
}
function Genres.IsGenre(genre) -- this function replaced with a better version server-side
	return table.find(Genres, genre)
end

return Genres