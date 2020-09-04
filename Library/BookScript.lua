--[[
	Modifying the book's colors:

	BookColor: Modify the book color by changing the book's part color.
	TitleColor Modify the title'cs color on the cover and book by changing the TitleCoor property .
	TitleOutlineColor: Modify the title outline color on the cover by changing the TitleOutlineColor property.
]]--

local title = "" -- String; Simple enough, the book's title. Example: "BookTemplate"
local authorIds = {} -- List; The user ID/s of the author/s. Use false for anonymous users or if the author elects for a custom author name. Example: {false, 1}
local authorNames = {} -- List; The username/s of the author/s. Example: {"ROBLOX"}
local customAuthorLine = "" -- String; You may leave this blank if the author/s doesn't/don't want a custom author line. Example: "author1, author2 (random comment author wants here), etc.."
local authorsNote = [[]] -- Multi-line String; The author's note is a way for the author to convey important notes about their book. You may leave this blank if the author/s doesn't/don't want a note. Example: [[This is my cool book!]]
local genres = {} -- List; The genres of the book. Example: {"Roblox Groups", "History"}

local cover = "" -- String; The book's cover. Leaving this blank will result in a transparent cover. Example: "http://www.roblox.com/asset/?id=428733812"
local librarian = "" -- String; Your username/nickname! Example: "ROBLOX".
local publishDate = "" -- String; The date you made this book in your workshop.

local image1 = "" -- Must have a space after the image URL. Example: "rbxassetid://5230133461 "
local image2 = ""
local image3 = ""
local image4 = ""
local image5 = ""
local image6 = ""
local image7 = ""
local image8 = ""
local image9 = ""
local image10 = ""

--[=[
    Commands which can be used in the "paragraphs" object.

    /line: Moves to the next line. Example: hello /line.
    /dline: Skips a line. Example: hello /dline.
    /page: Moves to the next page. Example: hello /page.
    /turn: Moves to the next left page. Example: hello /turn
	/image: Creates an image.
		It must be followed by the numbers of lines the image will take up - this must always be a two digit number that does not exceed 20.
		This must then be followed by the imageId.
		Example:
local paragraphs =
	{[[text before the image (if any) /image05]]..image2..[[text after the image]],
	[[/image12]]..image2,
	[[etc]]}

	Note: you may copy/paste the "[[]]," below as many times as you need to.
]=]--

local paragraphs = {
	[[]],
}

-- Never modify this line:
require(game:GetService("ServerScriptService").Books):Register(script.Parent, genres, cover, title, customAuthorLine, authorNames, authorIds, authorsNote, publishDate, paragraphs, librarian)