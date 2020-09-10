local title = "John's Great Adventure"
local authorIds = {2, false}
local authorNames = {"John Doe", "Anonymous"}
local customAuthorLine = "John Doe (writer) & Anonymous (illustrator)"
local authorsNote = [[Learn about John's great adventure!]]
local genres = {"Adventure", "Horror"}

local cover = "http://www.roblox.com/asset/?id=428733812"
local librarian = "LibraryDrone"
local publishDate = "6/15/2020"

local image1 = "rbxassetid://5230133461 "

local content = {
	[[
		John Doe is an adventurous boy. /line
		One day John decided to go hiking. An illustration of John hiking is below. /dline
	]],
	[[
		/image09]]..image1..[[
	]]
}

-- Never modify this line:
require(game:GetService("ServerScriptService"):WaitForChild("Books")):Register(script.Parent, genres, cover, title, customAuthorLine, authorNames, authorIds, authorsNote, publishDate, content, librarian)