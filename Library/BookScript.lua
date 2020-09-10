-- Example values are to the side.

local title = "" -- "BookTemplate"
local authorIds = {} -- {false, 1} -- Use false for anonymous users or if the author elects for an author name other than their username.
local authorNames = {} -- {"Anonymous", "ROBLOX"}
local customAuthorLine = "" -- "Mystery Person (author) & Roblox (editor)" will show up on the cover page as "By: Mystery Person (author) & Roblox (editor)"
--		If left blank, in this example, the cover page would display "By: Anonymous and ROBLOX"
--		Note: always list the authorNames, regardless of if you have a customAuthorLine.
local authorsNote = [[]] -- [[This is my cool book!]] -- Can be left blank or use multiple lines.
local genres = {} -- {"Roblox Groups", "History"}

local cover = "" -- "http://www.roblox.com/asset/?id=428733812" -- Leaving this blank will result in a transparent cover.
local librarian = "" -- "ClanDrone" -- Your username/nickname.
local publishDate = "" -- "01/30/2020" -- Always in MM/DD/YYYY format.

-- You can also customize the book's part color and TitleColor & TitleOutlineColor values.

local image1 = "" -- "rbxassetid://5230133461 " --  Note: must always have a space after the image URL. Can also do "http://www.roblox.com/asset/?id=428733812 "
local image2 = ""
-- Can add more images as needed.

--[=[
    Commands which can be used in the "content" object.

    /line: Moves to the next line. Example: hello /line
    /dline: Skips a line. Example: hello /dline
    /page: Moves to the next page. Example: hello /page
    /turn: Moves to the next left page. Example: hello /turn
	/image: Creates an image.
		It must be followed by the numbers of lines the image will take up - this must always be a two digit number that does not exceed 20.
		This must then be followed by the imageId.
		Example:
local content = {
	[[text before the image (if any) /image05]]..image2..[[text after the image]],
	[[/image12]]..image2,
	[[etc]],
}

	Note: you may copy/paste the "[[]]," below as many times as you like to organize the content.
	It makes no difference whether you put all the content in a single [[]] or several.
]=]--

local content = {
	[[]],
}

-- Never modify this line:
require(game:GetService("ServerScriptService"):WaitForChild("Books")):Register(script.Parent, genres, cover, title, customAuthorLine, authorNames, authorIds, authorsNote, publishDate, content, librarian)