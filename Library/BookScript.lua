-- Examples and explanations start with '--'
local title = ""
-- local title = "Book Template"
local authorIds = {}
-- local authorIds = {false, 1}
-- The list of Roblox user ids for each author.
-- Use false for anonymous users or if the author elects for an author name other than their username.
local authorNames = {}
-- local authorNames = {"Anonymous", "ROBLOX"}
-- This must be in the same order as authorIds.
local customAuthorLine = ""
-- local customAuthorLine = "Mystery Person (author) & Roblox (editor)"
-- This example would show up on the cover page as "By: Mystery Person (author) & Roblox (editor)".
-- If left blank, the cover page would (in this example) display "By: Anonymous and ROBLOX"
-- Note: always list the authorNames, regardless of if you have a customAuthorLine.
local authorsNote = [[]]
-- local authorsNote = [[This is my cool book!]]
-- Can be left blank or use multiple lines.
local genres = {}
-- local genres = {"Roblox Groups", "History"}
-- Refer to the Genre Catalog script for a list of available genres

local cover = ""
-- local cover = "http://www.roblox.com/asset/?id=428733812"
-- Leaving this blank will result in a transparent cover.
local librarian = ""
-- local librarian = "ClanDrone"
-- Your username/nickname
local publishDate = ""
-- local publishDate = "01/30/2020"
-- Always in MM/DD/YYYY format.

-- You can also customize the book's Part Color (or BrickColor), as well as the TitleColor and TitleOutlineColor Color3Values.

local image1 = ""
-- local image1 = "rbxassetid://5230133461 " --  Note: must always have a space after the image URL. Can also do:
-- local image1 = "http://www.roblox.com/asset/?id=428733812 "
local image2 = ""
-- Can add more images as needed

--[=[
    Commands which can be used in the "content" object below.

    /line: Moves to the next line. Example: hello /line
    /dline: Skips a line. Example: hello /dline
    /page: Moves to the next page. Example: hello /page
    /turn: Moves to the next left page. Example: hello /turn
	/image: Creates an image.
		It must be followed by the numbers of lines the image will take up - this must always be a two digit number that does not exceed 20.
		This must then be followed by the imageId.
		Example:
local content =
	{[[text before the image (if any) /image05]]..image2..[[text after the image]],
	[[/image12]]..image2,
	[[etc]]}

	/retainImage: Creates a square shaped image. Note that the i in image must be capital.
		This follows the same structure as the /image command, the only difference being that line count must not exceed 16.

	Note: you may copy/paste the "[[]]," below as many times as you like to organize the content.
	It makes no difference whether you put all the content in a single [[]] or several.

	You may find it helpful to enable the auto text-wrap feature in Studio; this allows you to write one long line, and have Studio
	automatically create line breaks for you. Note that you will still need to add the /line command to add line breaks for the reader.

	To enable word wrap in Studio, go to File > Studio Settings > Type 'Wrap' in the search bar > Check the "Text Wrapping" box.
]=]--

local content = {
	[[]],
}





-- Never modify this line:
require(game:GetService("ServerScriptService"):WaitForChild("Books")):Register(script.Parent, genres, cover, title, customAuthorLine, authorNames, authorIds, authorsNote, publishDate, content, librarian)